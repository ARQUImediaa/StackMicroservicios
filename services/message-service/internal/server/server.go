// Package server implementa MessagingService y coordina los componentes:
// validación → membresía (community-service) → repositorio (Cassandra) → hub.
//
// El servidor depende de interfaces, no de gRPC ni de Cassandra: main.go le
// inyecta las implementaciones reales y las pruebas usan dobles en memoria.
package server

import (
	"context"
	"log/slog"
	"time"

	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/hub"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/logging"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/membership"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/storage"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/validation"
	"github.com/gocql/gocql"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Validator son las reglas de entrada.
type Validator interface {
	ValidateSend(*messagingv1.SendMessageRequest) (validation.Send, error)
	ValidateChannel(string) (gocql.UUID, error)
	ValidateLimit(int32) (int, error)
}

// MembershipChecker pregunta a community-service si el usuario es miembro.
type MembershipChecker interface {
	IsMember(ctx context.Context, userID, channelID gocql.UUID) (membership.Result, error)
}

// MessageRepository guarda y lee mensajes en el keyspace messaging.
type MessageRepository interface {
	Save(ctx context.Context, m storage.Message) error
	ListByChannelDay(ctx context.Context, channelID gocql.UUID, day time.Time, limit int) ([]storage.Message, error)
}

type Server struct {
	messagingv1.UnimplementedMessagingServiceServer
	validator Validator
	members   MembershipChecker
	repo      MessageRepository
	hub       *hub.Hub
	logger    *slog.Logger
	now       func() time.Time
}

func New(validator Validator, members MembershipChecker, repo MessageRepository, messageHub *hub.Hub, logger *slog.Logger) *Server {
	return &Server{validator: validator, members: members, repo: repo, hub: messageHub, logger: logger, now: time.Now}
}

// SendMessage es el caso de uso principal. Es el único RPC que valida la membresía.
func (s *Server) SendMessage(ctx context.Context, request *messagingv1.SendMessageRequest) (*messagingv1.Message, error) {
	log := s.logger.With("request_id", logging.RequestID(ctx))

	in, err := s.validator.ValidateSend(request)
	if err != nil {
		return nil, err
	}
	log.Info("message.validated", "channel_id", in.ChannelID.String(), "user_id", in.UserID.String(), "content_len", len([]rune(in.Content)))

	started := time.Now()
	member, err := s.members.IsMember(ctx, in.UserID, in.ChannelID)
	if err != nil {
		log.Warn("membership.unavailable", "duration_ms", time.Since(started).Milliseconds(), "error", status.Convert(err).Message())
		return nil, err
	}
	log.Info("membership.checked", "is_member", member.IsMember, "duration_ms", time.Since(started).Milliseconds())
	if !member.IsMember {
		return nil, status.Error(codes.PermissionDenied, "user is not a member of this channel")
	}

	createdAt := s.now().UTC()
	stored := storage.Message{
		ChannelID: in.ChannelID, Day: storage.Day(createdAt), MessageID: gocql.UUIDFromTime(createdAt),
		UserID: in.UserID, Username: member.Username, Content: in.Content, CreatedAt: createdAt,
	}
	if err := s.repo.Save(ctx, stored); err != nil {
		log.Warn("message.store_failed", "error", err.Error())
		return nil, status.Errorf(codes.Unavailable, "save message: %v", err)
	}
	log.Info("message.stored", "channel_id", in.ChannelID.String(), "day", stored.Day.Format("2006-01-02"), "message_id", stored.MessageID.String())

	message := toProto(stored)
	delivered := s.hub.Publish(message)
	log.Info("message.published", "channel_id", message.GetChannelId(), "subscribers", delivered)
	return message, nil
}

// GetHistory lee la partición del día actual. No consulta a community-service:
// si ese servicio cae, el historial sigue funcionando (fallo parcial, acto 2 de la demo).
// Sin autenticación real, la lectura es abierta.
func (s *Server) GetHistory(ctx context.Context, request *messagingv1.GetHistoryRequest) (*messagingv1.GetHistoryResponse, error) {
	channelID, err := s.validator.ValidateChannel(request.GetChannelId())
	if err != nil {
		return nil, err
	}
	limit, err := s.validator.ValidateLimit(request.GetLimit())
	if err != nil {
		return nil, err
	}
	day := storage.Day(s.now())
	stored, err := s.repo.ListByChannelDay(ctx, channelID, day, limit)
	if err != nil {
		return nil, status.Errorf(codes.Unavailable, "read message history: %v", err)
	}
	// La partición guarda de más nuevo a más viejo; la app muestra en orden cronológico.
	messages := make([]*messagingv1.Message, len(stored))
	for i, m := range stored {
		messages[len(stored)-1-i] = toProto(m)
	}
	s.logger.Info("history.read", "request_id", logging.RequestID(ctx), "channel_id", channelID.String(), "day", day.Format("2006-01-02"), "count", len(messages))
	return &messagingv1.GetHistoryResponse{Messages: messages}, nil
}

// Subscribe abre el stream en vivo del canal. Tampoco consulta a community-service.
func (s *Server) Subscribe(request *messagingv1.SubscribeRequest, stream messagingv1.MessagingService_SubscribeServer) error {
	ctx := stream.Context()
	channelID, err := s.validator.ValidateChannel(request.GetChannelId())
	if err != nil {
		return err
	}
	log := s.logger.With("request_id", logging.RequestID(ctx), "channel_id", channelID.String(), "user_id", request.GetUserId())
	messages, unsubscribe := s.hub.Subscribe(channelID.String())
	log.Info("subscriber.added")
	defer func() {
		unsubscribe()
		log.Info("subscriber.removed")
	}()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case message, open := <-messages:
			if !open {
				return nil
			}
			if err := stream.Send(message); err != nil {
				return err
			}
		}
	}
}

func toProto(m storage.Message) *messagingv1.Message {
	return &messagingv1.Message{
		ChannelId: m.ChannelID.String(), MessageId: m.MessageID.String(), UserId: m.UserID.String(),
		Username: m.Username, Content: m.Content, CreatedAtUnixMs: m.CreatedAt.UnixMilli(),
	}
}

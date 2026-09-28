package server

import (
	"context"
	"strings"
	"time"

	"github.com/gocql/gocql"
	communityv1 "github.com/arquimediaa/proyectomicro/proto/go/community/v1"
	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/hub"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Server struct {
	messagingv1.UnimplementedMessagingServiceServer
	session   *gocql.Session
	community communityv1.CommunityServiceClient
	hub       *hub.Hub
}

func New(session *gocql.Session, community communityv1.CommunityServiceClient, messageHub *hub.Hub) *Server {
	return &Server{session: session, community: community, hub: messageHub}
}

func (s *Server) SendMessage(ctx context.Context, request *messagingv1.SendMessageRequest) (*messagingv1.Message, error) {
	channelID, userID, err := s.validateMembership(ctx, request.GetChannelId(), request.GetUserId())
	if err != nil {
		return nil, err
	}
	content := strings.TrimSpace(request.GetContent())
	if content == "" || len([]byte(content)) > 4000 {
		return nil, status.Error(codes.InvalidArgument, "content must contain between 1 and 4000 bytes")
	}
	user, err := s.community.GetUser(ctx, &communityv1.GetUserRequest{UserId: userID.String()})
	if err != nil {
		return nil, status.Errorf(codes.Unavailable, "load sender: %v", err)
	}
	messageID := gocql.TimeUUID()
	createdAt := time.Now().UTC()
	if err := s.session.Query(`INSERT INTO messages_by_channel (channel_id, message_id, user_id, username, content, created_at) VALUES (?, ?, ?, ?, ?, ?)`, channelID, messageID, userID, user.GetUsername(), content, createdAt).WithContext(ctx).Exec(); err != nil {
		return nil, status.Errorf(codes.Unavailable, "save message: %v", err)
	}
	message := &messagingv1.Message{
		ChannelId: channelID.String(), MessageId: messageID.String(), UserId: userID.String(),
		Username: user.GetUsername(), Content: content, CreatedAtUnixMs: createdAt.UnixMilli(),
	}
	s.hub.Publish(message)
	return message, nil
}

func (s *Server) GetHistory(ctx context.Context, request *messagingv1.GetHistoryRequest) (*messagingv1.GetHistoryResponse, error) {
	channelID, _, err := s.validateMembership(ctx, request.GetChannelId(), request.GetUserId())
	if err != nil {
		return nil, err
	}
	limit := request.GetLimit()
	if limit == 0 {
		limit = 50
	}
	if limit < 1 || limit > 100 {
		return nil, status.Error(codes.InvalidArgument, "limit must be between 1 and 100")
	}
	iter := s.session.Query(`SELECT message_id, user_id, username, content, created_at FROM messages_by_channel WHERE channel_id = ? LIMIT ?`, channelID, limit).WithContext(ctx).Iter()
	messages := make([]*messagingv1.Message, 0, limit)
	var messageID, storedUserID gocql.UUID
	var username, content string
	var createdAt time.Time
	for iter.Scan(&messageID, &storedUserID, &username, &content, &createdAt) {
		messages = append(messages, &messagingv1.Message{
			ChannelId: channelID.String(), MessageId: messageID.String(), UserId: storedUserID.String(),
			Username: username, Content: content, CreatedAtUnixMs: createdAt.UnixMilli(),
		})
	}
	if err := iter.Close(); err != nil {
		return nil, status.Errorf(codes.Unavailable, "read message history: %v", err)
	}
	for left, right := 0, len(messages)-1; left < right; left, right = left+1, right-1 {
		messages[left], messages[right] = messages[right], messages[left]
	}
	return &messagingv1.GetHistoryResponse{Messages: messages}, nil
}

func (s *Server) Subscribe(request *messagingv1.SubscribeRequest, stream messagingv1.MessagingService_SubscribeServer) error {
	channelID, _, err := s.validateMembership(stream.Context(), request.GetChannelId(), request.GetUserId())
	if err != nil {
		return err
	}
	messages, unsubscribe := s.hub.Subscribe(channelID.String())
	defer unsubscribe()
	for {
		select {
		case <-stream.Context().Done():
			return stream.Context().Err()
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

func (s *Server) validateMembership(ctx context.Context, channelValue, userValue string) (gocql.UUID, gocql.UUID, error) {
	channelID, err := gocql.ParseUUID(strings.TrimSpace(channelValue))
	if err != nil {
		return nil, nil, status.Error(codes.InvalidArgument, "channel_id must be a valid UUID")
	}
	userID, err := gocql.ParseUUID(strings.TrimSpace(userValue))
	if err != nil {
		return nil, nil, status.Error(codes.InvalidArgument, "user_id must be a valid UUID")
	}
	result, err := s.community.IsMember(ctx, &communityv1.IsMemberRequest{UserId: userID.String(), ChannelId: channelID.String()})
	if err != nil {
		return nil, nil, status.Errorf(codes.Unavailable, "check channel membership: %v", err)
	}
	if !result.GetIsMember() {
		return nil, nil, status.Error(codes.PermissionDenied, "user is not a member of this channel")
	}
	return channelID, userID, nil
}
package server

import (
	"context"
	"regexp"
	"strings"
	"time"

	communityv1 "github.com/arquimediaa/proyectomicro/proto/go/community/v1"
	"github.com/gocql/gocql"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var (
	usernamePattern = regexp.MustCompile(`^[a-zA-Z0-9_]{3,32}$`)
	channelPattern  = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_-]{1,47}$`)
	emailPattern    = regexp.MustCompile(`^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`)
)

type Server struct {
	communityv1.UnimplementedCommunityServiceServer
	session *gocql.Session
}

func New(session *gocql.Session) *Server {
	return &Server{session: session}
}

func (s *Server) CreateUser(ctx context.Context, request *communityv1.CreateUserRequest) (*communityv1.User, error) {
	username := strings.ToLower(strings.TrimSpace(request.GetUsername()))
	email := strings.TrimSpace(request.GetEmail())
	if !usernamePattern.MatchString(username) || !emailPattern.MatchString(email) {
		return nil, status.Error(codes.InvalidArgument, "username or email is invalid")
	}
	userID, err := gocql.RandomUUID()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "generate user id: %v", err)
	}
	createdAt := time.Now().UTC()
	// Unicidad del nombre con una transacción ligera (LWT): Cassandra no tiene
	// restricciones UNIQUE, así que se reserva el nombre antes de crear el usuario.
	applied, err := s.session.Query(`INSERT INTO users_by_username (username, user_id, email, created_at) VALUES (?, ?, ?, ?) IF NOT EXISTS`, username, userID, email, createdAt).WithContext(ctx).MapScanCAS(map[string]interface{}{})
	if err != nil {
		return nil, status.Errorf(codes.Unavailable, "reserve username: %v", err)
	}
	if !applied {
		return nil, status.Error(codes.AlreadyExists, "username already exists")
	}
	if err := s.session.Query(`INSERT INTO users (user_id, username, email, created_at) VALUES (?, ?, ?, ?)`, userID, username, email, createdAt).WithContext(ctx).Exec(); err != nil {
		return nil, status.Errorf(codes.Unavailable, "save user: %v", err)
	}
	return &communityv1.User{UserId: userID.String(), Username: username, Email: email, CreatedAtUnixMs: createdAt.UnixMilli()}, nil
}

func (s *Server) GetUser(ctx context.Context, request *communityv1.GetUserRequest) (*communityv1.User, error) {
	userID, err := parseUUID(request.GetUserId(), "user_id")
	if err != nil {
		return nil, err
	}
	var username, email string
	var createdAt time.Time
	if err := s.session.Query(`SELECT username, email, created_at FROM users WHERE user_id = ?`, userID).WithContext(ctx).Scan(&username, &email, &createdAt); err != nil {
		return nil, queryError("user", err)
	}
	return &communityv1.User{UserId: userID.String(), Username: username, Email: email, CreatedAtUnixMs: createdAt.UnixMilli()}, nil
}

func (s *Server) CreateChannel(ctx context.Context, request *communityv1.CreateChannelRequest) (*communityv1.Channel, error) {
	name := strings.ToLower(strings.TrimSpace(request.GetName()))
	description := strings.TrimSpace(request.GetDescription())
	creatorID, err := parseUUID(request.GetCreatedBy(), "created_by")
	if err != nil {
		return nil, err
	}
	if !channelPattern.MatchString(name) || len(description) > 1000 {
		return nil, status.Error(codes.InvalidArgument, "channel name or description is invalid")
	}
	var username string
	if err := s.session.Query(`SELECT username FROM users WHERE user_id = ?`, creatorID).WithContext(ctx).Scan(&username); err != nil {
		return nil, queryError("creator", err)
	}
	channelID, err := gocql.RandomUUID()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "generate channel id: %v", err)
	}
	createdAt := time.Now().UTC()
	// Unicidad del nombre del canal con LWT, igual que en CreateUser.
	applied, err := s.session.Query(`INSERT INTO channels_by_name (name, channel_id, description, created_by, created_at) VALUES (?, ?, ?, ?, ?) IF NOT EXISTS`, name, channelID, description, creatorID, createdAt).WithContext(ctx).MapScanCAS(map[string]interface{}{})
	if err != nil {
		return nil, status.Errorf(codes.Unavailable, "reserve channel name: %v", err)
	}
	if !applied {
		return nil, status.Error(codes.AlreadyExists, "channel name already exists")
	}
	if err := s.session.Query(`INSERT INTO channels (channel_id, name, description, created_by, created_at) VALUES (?, ?, ?, ?, ?)`, channelID, name, description, creatorID, createdAt).WithContext(ctx).Exec(); err != nil {
		return nil, status.Errorf(codes.Unavailable, "save channel: %v", err)
	}
	return &communityv1.Channel{ChannelId: channelID.String(), Name: name, Description: description, CreatedBy: creatorID.String(), CreatedAtUnixMs: createdAt.UnixMilli()}, nil
}

func (s *Server) GetChannel(ctx context.Context, request *communityv1.GetChannelRequest) (*communityv1.Channel, error) {
	channelID, err := parseUUID(request.GetChannelId(), "channel_id")
	if err != nil {
		return nil, err
	}
	return s.loadChannel(ctx, channelID)
}

func (s *Server) JoinChannel(ctx context.Context, request *communityv1.JoinChannelRequest) (*communityv1.JoinChannelResponse, error) {
	userID, err := parseUUID(request.GetUserId(), "user_id")
	if err != nil {
		return nil, err
	}
	channelID, err := parseUUID(request.GetChannelId(), "channel_id")
	if err != nil {
		return nil, err
	}
	var username string
	if err := s.session.Query(`SELECT username FROM users WHERE user_id = ?`, userID).WithContext(ctx).Scan(&username); err != nil {
		return nil, queryError("user", err)
	}
	if _, err := s.loadChannel(ctx, channelID); err != nil {
		return nil, err
	}
	// ADR-06: la misma membresía se guarda en dos tablas (una por consulta).
	// El BATCH logged garantiza que ambas escrituras terminen aplicándose,
	// aunque sin aislamiento: por un instante una puede verse antes que la otra.
	joinedAt := time.Now().UTC()
	batch := s.session.NewBatch(gocql.LoggedBatch).WithContext(ctx)
	batch.Query(`INSERT INTO memberships_by_user (user_id, channel_id, joined_at) VALUES (?, ?, ?)`, userID, channelID, joinedAt)
	batch.Query(`INSERT INTO memberships_by_channel (channel_id, user_id, joined_at) VALUES (?, ?, ?)`, channelID, userID, joinedAt)
	if err := s.session.ExecuteBatch(batch); err != nil {
		return nil, status.Errorf(codes.Unavailable, "save membership: %v", err)
	}
	return &communityv1.JoinChannelResponse{Joined: true}, nil
}

func (s *Server) ListMyChannels(ctx context.Context, request *communityv1.ListMyChannelsRequest) (*communityv1.ListMyChannelsResponse, error) {
	userID, err := parseUUID(request.GetUserId(), "user_id")
	if err != nil {
		return nil, err
	}
	iter := s.session.Query(`SELECT channel_id FROM memberships_by_user WHERE user_id = ?`, userID).WithContext(ctx).Iter()
	channelIDs := make([]gocql.UUID, 0)
	var channelID gocql.UUID
	for iter.Scan(&channelID) {
		channelIDs = append(channelIDs, channelID)
	}
	if err := iter.Close(); err != nil {
		return nil, status.Errorf(codes.Unavailable, "list memberships: %v", err)
	}
	response := &communityv1.ListMyChannelsResponse{Channels: make([]*communityv1.Channel, 0, len(channelIDs))}
	for _, id := range channelIDs {
		channel, err := s.loadChannel(ctx, id)
		if status.Code(err) == codes.NotFound {
			continue
		}
		if err != nil {
			return nil, err
		}
		response.Channels = append(response.Channels, channel)
	}
	return response, nil
}

func (s *Server) IsMember(ctx context.Context, request *communityv1.IsMemberRequest) (*communityv1.IsMemberResponse, error) {
	userID, err := parseUUID(request.GetUserId(), "user_id")
	if err != nil {
		return nil, err
	}
	channelID, err := parseUUID(request.GetChannelId(), "channel_id")
	if err != nil {
		return nil, err
	}
	var storedID gocql.UUID
	err = s.session.Query(`SELECT user_id FROM memberships_by_channel WHERE channel_id = ? AND user_id = ?`, channelID, userID).WithContext(ctx).Scan(&storedID)
	if err == gocql.ErrNotFound {
		return &communityv1.IsMemberResponse{IsMember: false}, nil
	}
	if err != nil {
		return nil, status.Errorf(codes.Unavailable, "check membership: %v", err)
	}
	var username string
	if err := s.session.Query(`SELECT username FROM users WHERE user_id = ?`, userID).WithContext(ctx).Scan(&username); err != nil && err != gocql.ErrNotFound {
		return nil, status.Errorf(codes.Unavailable, "read username: %v", err)
	}
	return &communityv1.IsMemberResponse{IsMember: true, Username: username}, nil
}

// ListUsers lee toda la tabla users. Es aceptable porque la tabla es pequeña
// en la demo; con muchos usuarios habría que paginar.
func (s *Server) ListUsers(ctx context.Context, _ *communityv1.ListUsersRequest) (*communityv1.ListUsersResponse, error) {
	iter := s.session.Query(`SELECT user_id, username, email, created_at FROM users`).WithContext(ctx).Iter()
	response := &communityv1.ListUsersResponse{}
	var userID gocql.UUID
	var username, email string
	var createdAt time.Time
	for iter.Scan(&userID, &username, &email, &createdAt) {
		response.Users = append(response.Users, &communityv1.User{UserId: userID.String(), Username: username, Email: email, CreatedAtUnixMs: createdAt.UnixMilli()})
	}
	if err := iter.Close(); err != nil {
		return nil, status.Errorf(codes.Unavailable, "list users: %v", err)
	}
	return response, nil
}

// ListChannels lee toda la tabla channels (misma justificación que ListUsers).
func (s *Server) ListChannels(ctx context.Context, _ *communityv1.ListChannelsRequest) (*communityv1.ListChannelsResponse, error) {
	iter := s.session.Query(`SELECT channel_id, name, description, created_by, created_at FROM channels`).WithContext(ctx).Iter()
	response := &communityv1.ListChannelsResponse{}
	var channelID, creatorID gocql.UUID
	var name, description string
	var createdAt time.Time
	for iter.Scan(&channelID, &name, &description, &creatorID, &createdAt) {
		response.Channels = append(response.Channels, &communityv1.Channel{ChannelId: channelID.String(), Name: name, Description: description, CreatedBy: creatorID.String(), CreatedAtUnixMs: createdAt.UnixMilli()})
	}
	if err := iter.Close(); err != nil {
		return nil, status.Errorf(codes.Unavailable, "list channels: %v", err)
	}
	return response, nil
}

func (s *Server) loadChannel(ctx context.Context, channelID gocql.UUID) (*communityv1.Channel, error) {
	var name, description string
	var creatorID gocql.UUID
	var createdAt time.Time
	err := s.session.Query(`SELECT name, description, created_by, created_at FROM channels WHERE channel_id = ?`, channelID).WithContext(ctx).Scan(&name, &description, &creatorID, &createdAt)
	if err != nil {
		return nil, queryError("channel", err)
	}
	return &communityv1.Channel{ChannelId: channelID.String(), Name: name, Description: description, CreatedBy: creatorID.String(), CreatedAtUnixMs: createdAt.UnixMilli()}, nil
}

func parseUUID(value, field string) (gocql.UUID, error) {
	id, err := gocql.ParseUUID(strings.TrimSpace(value))
	if err != nil {
		return gocql.UUID{}, status.Errorf(codes.InvalidArgument, "%s must be a valid UUID", field)
	}
	return id, nil
}

func queryError(entity string, err error) error {
	if err == gocql.ErrNotFound {
		return status.Errorf(codes.NotFound, "%s not found", entity)
	}
	return status.Errorf(codes.Unavailable, "read %s: %v", entity, err)
}

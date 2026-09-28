package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/gocql/gocql"
	communityv1 "github.com/arquimediaa/proyectomicro/proto/go/community/v1"
	"github.com/arquimediaa/proyectomicro/services/community-service/internal/server"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
)

type requestIDKey struct{}

type wrappedServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (s *wrappedServerStream) Context() context.Context { return s.ctx }

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cluster := gocql.NewCluster(splitHosts(env("CASSANDRA_HOSTS", "cassandra"))...)
	cassandraPort, err := strconv.Atoi(env("CASSANDRA_PORT", "9042"))
	if err != nil {
		logger.Error("invalid Cassandra port", "error", err)
		os.Exit(1)
	}
	cluster.Port = cassandraPort
	cluster.Keyspace = "community"
	cluster.Consistency = gocql.LocalOne
	cluster.Timeout = 10 * time.Second
	cluster.ConnectTimeout = 10 * time.Second
	session, err := cluster.CreateSession()
	if err != nil {
		logger.Error("connect to Cassandra", "error", err)
		os.Exit(1)
	}
	defer session.Close()

	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(unaryRequestID(logger)),
		grpc.ChainStreamInterceptor(streamRequestID(logger)),
	)
	communityv1.RegisterCommunityServiceServer(grpcServer, server.New(session))
	healthServer := health.NewServer()
	healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(grpcServer, healthServer)
	reflection.Register(grpcServer)

	port := env("GRPC_PORT", "50051")
	listener, err := net.Listen("tcp", ":"+port)
	if err != nil {
		logger.Error("listen", "port", port, "error", err)
		os.Exit(1)
	}
	logger.Info("community service listening", "address", listener.Addr().String())

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	serveErr := make(chan error, 1)
	go func() { serveErr <- grpcServer.Serve(listener) }()
	select {
	case <-ctx.Done():
		grpcServer.GracefulStop()
	case err := <-serveErr:
		if err != nil && !errors.Is(err, grpc.ErrServerStopped) {
			logger.Error("gRPC server stopped", "error", err)
			os.Exit(1)
		}
	}
}

func unaryRequestID(logger *slog.Logger) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, request any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		requestID := incomingRequestID(ctx)
		ctx = context.WithValue(ctx, requestIDKey{}, requestID)
		_ = grpc.SetHeader(ctx, metadata.Pairs("x-request-id", requestID))
		started := time.Now()
		response, err := handler(ctx, request)
		logRequest(logger, requestID, info.FullMethod, started, err)
		return response, err
	}
}

func streamRequestID(logger *slog.Logger) grpc.StreamServerInterceptor {
	return func(server any, stream grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		requestID := incomingRequestID(stream.Context())
		ctx := context.WithValue(stream.Context(), requestIDKey{}, requestID)
		_ = grpc.SetHeader(ctx, metadata.Pairs("x-request-id", requestID))
		started := time.Now()
		err := handler(server, &wrappedServerStream{ServerStream: stream, ctx: ctx})
		logRequest(logger, requestID, info.FullMethod, started, err)
		return err
	}
}

func incomingRequestID(ctx context.Context) string {
	if values, ok := metadata.FromIncomingContext(ctx); ok {
		if ids := values.Get("x-request-id"); len(ids) > 0 && strings.TrimSpace(ids[0]) != "" {
			return strings.TrimSpace(ids[0])
		}
	}
	var value [16]byte
	if _, err := rand.Read(value[:]); err != nil {
		return time.Now().UTC().Format("20060102T150405.000000000")
	}
	return hex.EncodeToString(value[:])
}

func logRequest(logger *slog.Logger, requestID, method string, started time.Time, err error) {
	attributes := []any{"request_id", requestID, "method", method, "duration_ms", time.Since(started).Milliseconds()}
	if err != nil {
		attributes = append(attributes, "code", status.Code(err).String(), "error", err.Error())
		logger.Warn("gRPC request", attributes...)
		return
	}
	logger.Info("gRPC request", attributes...)
}

func env(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func splitHosts(value string) []string {
	hosts := strings.Split(value, ",")
	for index := range hosts {
		hosts[index] = strings.TrimSpace(hosts[index])
	}
	return hosts
}
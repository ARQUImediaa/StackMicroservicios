// Arranque de message-service: lee la configuración, conecta cada pieza y las
// inyecta en el servidor. Toda la lógica vive en internal/.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	communityv1 "github.com/arquimediaa/proyectomicro/proto/go/community/v1"
	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/hub"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/logging"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/membership"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/server"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/storage"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/validation"
	"github.com/gocql/gocql"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

func main() {
	logger := logging.New("message-service")

	session, err := connectCassandra(logger)
	if err != nil {
		logger.Error("cassandra.connect_failed", "error", err)
		os.Exit(1)
	}
	defer session.Close()

	communityConnection, err := grpc.NewClient(env("COMMUNITY_SERVICE_ADDR", "community-service:50051"), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		logger.Error("community.client_failed", "error", err)
		os.Exit(1)
	}
	defer communityConnection.Close()

	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(logging.UnaryServer(logger)),
		grpc.ChainStreamInterceptor(logging.StreamServer(logger)),
	)
	messagingv1.RegisterMessagingServiceServer(grpcServer, server.New(
		validation.Rules{},
		membership.New(communityv1.NewCommunityServiceClient(communityConnection), membership.DefaultTimeout),
		storage.New(session),
		hub.New(),
		logger,
	))
	healthServer := health.NewServer()
	healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(grpcServer, healthServer)
	reflection.Register(grpcServer)

	port := env("GRPC_PORT", "50052")
	listener, err := net.Listen("tcp", ":"+port)
	if err != nil {
		logger.Error("listen_failed", "port", port, "error", err)
		os.Exit(1)
	}
	logger.Info("service.listening", "address", listener.Addr().String())

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	serveErr := make(chan error, 1)
	go func() { serveErr <- grpcServer.Serve(listener) }()
	select {
	case <-ctx.Done():
		grpcServer.GracefulStop()
	case err := <-serveErr:
		if err != nil && !errors.Is(err, grpc.ErrServerStopped) {
			logger.Error("grpc.stopped", "error", err)
			os.Exit(1)
		}
	}
}

// connectCassandra reintenta con backoff: Cassandra tarda en quedar lista y el
// servicio no debe asumir que ya lo está.
func connectCassandra(logger *slog.Logger) (*gocql.Session, error) {
	port, err := strconv.Atoi(env("CASSANDRA_PORT", "9042"))
	if err != nil {
		return nil, err
	}
	cluster := gocql.NewCluster(splitHosts(env("CASSANDRA_HOSTS", "cassandra"))...)
	cluster.Port = port
	cluster.Keyspace = "messaging" // ADR-02: solo su propio keyspace
	cluster.Consistency = gocql.LocalOne
	cluster.Timeout = 10 * time.Second
	cluster.ConnectTimeout = 10 * time.Second

	wait := time.Second
	for attempt := 1; ; attempt++ {
		session, err := cluster.CreateSession()
		if err == nil {
			logger.Info("cassandra.connected", "keyspace", cluster.Keyspace, "attempt", attempt)
			return session, nil
		}
		if attempt == 10 {
			return nil, err
		}
		logger.Warn("cassandra.connect_retry", "attempt", attempt, "wait_ms", wait.Milliseconds(), "error", err.Error())
		time.Sleep(wait)
		if wait < 15*time.Second {
			wait *= 2
		}
	}
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

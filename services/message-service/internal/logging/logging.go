// Package logging centraliza el request_id y los interceptores gRPC.
//
// Envoy genera el metadato x-request-id en cada petición. Los interceptores lo
// leen (o generan uno si no viene), lo guardan en el context y registran el
// inicio y el fin de cada RPC. El cliente de membresía lo copia en la llamada a
// community-service, así que un mismo request_id recorre toda la arquitectura.
package logging

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"os"
	"strings"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

const requestIDHeader = "x-request-id"

type requestIDKey struct{}

// New crea el logger JSON del servicio. LOG_LEVEL=debug activa el nivel debug.
func New(service string) *slog.Logger {
	level := slog.LevelInfo
	if strings.EqualFold(os.Getenv("LOG_LEVEL"), "debug") {
		level = slog.LevelDebug
	}
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: level})
	return slog.New(handler).With("service", service)
}

// RequestID devuelve el request_id guardado en el context, o "" si no hay.
func RequestID(ctx context.Context) string {
	if id, ok := ctx.Value(requestIDKey{}).(string); ok {
		return id
	}
	return ""
}

// WithRequestID devuelve un context que ya lleva el request_id (útil en pruebas).
func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey{}, id)
}

// Outgoing copia el request_id en el metadato saliente de una llamada gRPC.
func Outgoing(ctx context.Context) context.Context {
	if id := RequestID(ctx); id != "" {
		return metadata.AppendToOutgoingContext(ctx, requestIDHeader, id)
	}
	return ctx
}

// UnaryServer registra rpc.start y rpc.end con el request_id, la duración y el código gRPC.
func UnaryServer(logger *slog.Logger) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, request any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		ctx, requestID := withIncomingRequestID(ctx)
		started := time.Now()
		logger.Info("rpc.start", "rpc", info.FullMethod, "request_id", requestID)
		response, err := handler(ctx, request)
		logEnd(logger, info.FullMethod, requestID, started, err)
		return response, err
	}
}

// StreamServer hace lo mismo para los RPC de streaming (Subscribe).
func StreamServer(logger *slog.Logger) grpc.StreamServerInterceptor {
	return func(service any, stream grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		ctx, requestID := withIncomingRequestID(stream.Context())
		started := time.Now()
		logger.Info("rpc.start", "rpc", info.FullMethod, "request_id", requestID)
		err := handler(service, &contextStream{ServerStream: stream, ctx: ctx})
		logEnd(logger, info.FullMethod, requestID, started, err)
		return err
	}
}

type contextStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (s *contextStream) Context() context.Context { return s.ctx }

func withIncomingRequestID(ctx context.Context) (context.Context, string) {
	requestID := ""
	if values, ok := metadata.FromIncomingContext(ctx); ok {
		if ids := values.Get(requestIDHeader); len(ids) > 0 {
			requestID = strings.TrimSpace(ids[0])
		}
	}
	if requestID == "" {
		requestID = newID()
	}
	_ = grpc.SetHeader(ctx, metadata.Pairs(requestIDHeader, requestID))
	return context.WithValue(ctx, requestIDKey{}, requestID), requestID
}

func logEnd(logger *slog.Logger, method, requestID string, started time.Time, err error) {
	attributes := []any{"rpc", method, "request_id", requestID, "code", status.Code(err).String(), "duration_ms", time.Since(started).Milliseconds()}
	if err != nil {
		logger.Warn("rpc.end", append(attributes, "error", status.Convert(err).Message())...)
		return
	}
	logger.Info("rpc.end", attributes...)
}

func newID() string {
	var value [16]byte
	if _, err := rand.Read(value[:]); err != nil {
		return time.Now().UTC().Format("20060102T150405.000000000")
	}
	return hex.EncodeToString(value[:])
}

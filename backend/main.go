package main

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"github.com/ARQUImediaa/StackMicroservicios/backend/pb"
	"github.com/improbable-eng/grpc-web/go/grpcweb"
	"google.golang.org/grpc"
)

type server struct {
	pb.UnimplementedPingServiceServer
}

func (s *server) Ping(ctx context.Context, req *pb.PingRequest) (*pb.PingResponse, error) {
	log.Printf("Mensaje recibido desde el cliente: %s", req.GetMessage())
	return &pb.PingResponse{
		Reply: "¡Hola desde Go gRPC! Tu mensaje fue: " + req.GetMessage(),
	}, nil
}

func main() {
	// 1. Crear el servidor gRPC estándar
	grpcServer := grpc.NewServer()
	pb.RegisterPingServiceServer(grpcServer, &server{})

	// 2. Envolver el servidor gRPC con soporte gRPC-Web y CORS para navegadores
	wrappedGrpc := grpcweb.WrapServer(
		grpcServer,
		grpcweb.WithOriginFunc(func(origin string) bool { return true }), // Permitir cualquier origen (CORS)
	)

	// 3. Crear el manejador HTTP
	httpHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if wrappedGrpc.IsGrpcWebRequest(r) || wrappedGrpc.IsAcceptableGrpcCorsRequest(r) {
			wrappedGrpc.ServeHTTP(w, r)
			return
		}
		// Si no es petición web-grpc, pasar al servidor gRPC nativo
		grpcServer.ServeHTTP(w, r)
	})

	// 4. Iniciar servidor HTTP/gRPC en el puerto 50051
	fmt.Println("Servidor gRPC + gRPC-Web corriendo en el puerto :50051...")
	if err := http.ListenAndServe(":50051", httpHandler); err != nil {
		log.Fatalf("Error al iniciar el servidor: %v", err)
	}
}
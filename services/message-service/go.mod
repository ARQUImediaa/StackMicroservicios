module github.com/arquimediaa/proyectomicro/services/message-service

go 1.23.0

require (
	github.com/gocql/gocql v1.7.0
	github.com/arquimediaa/proyectomicro/proto/go v0.0.0
	google.golang.org/grpc v1.72.1
)

replace github.com/arquimediaa/proyectomicro/proto/go => ../../proto/go
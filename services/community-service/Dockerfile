FROM golang:1.24-alpine AS builder

RUN apk add --no-cache protobuf
WORKDIR /src
COPY proto/go/go.mod ./proto/go/go.mod
COPY proto/community ./proto/community
COPY proto/messaging ./proto/messaging
COPY services/community-service/go.mod ./services/community-service/go.mod
WORKDIR /src/services/community-service
RUN go mod download

WORKDIR /src
COPY proto/go ./proto/go
COPY services/community-service ./services/community-service
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.6 \
	&& go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
ENV PATH="/go/bin:${PATH}"
RUN protoc -I /src/proto \
	--go_out=/src/proto/go --go_opt=module=github.com/arquimediaa/proyectomicro/proto/go \
	--go-grpc_out=/src/proto/go --go-grpc_opt=module=github.com/arquimediaa/proyectomicro/proto/go \
	/src/proto/community/v1/community.proto /src/proto/messaging/v1/messaging.proto
WORKDIR /src/services/community-service
RUN mkdir -p /out && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/community-service .

FROM alpine:3.21
RUN apk add --no-cache ca-certificates && adduser -D -u 10001 app
COPY --from=builder /out/community-service /usr/local/bin/community-service
USER app
EXPOSE 50051
ENTRYPOINT ["/usr/local/bin/community-service"]
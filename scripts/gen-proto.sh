#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="github.com/arquimediaa/proyectomicro/proto/go"
PROTOC_GEN_GO_VERSION="v1.36.6"
PROTOC_GEN_GO_GRPC_VERSION="v1.5.1"

command -v protoc >/dev/null || { echo "protoc is required" >&2; exit 1; }
command -v go >/dev/null || { echo "Go is required" >&2; exit 1; }

export GOBIN="$(go env GOPATH)/bin"
export PATH="$GOBIN:$PATH"
go install "google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VERSION}"
go install "google.golang.org/grpc/cmd/protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VERSION}"

mkdir -p "$ROOT/proto/go/community/v1" "$ROOT/proto/go/messaging/v1"
protoc -I "$ROOT/proto" \
  --go_out="$ROOT/proto/go" --go_opt="module=${MODULE}" \
  --go-grpc_out="$ROOT/proto/go" --go-grpc_opt="module=${MODULE}" \
  "$ROOT/proto/community/v1/community.proto" \
  "$ROOT/proto/messaging/v1/messaging.proto"
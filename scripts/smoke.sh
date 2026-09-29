#!/usr/bin/env bash
# Smoke test a través de Envoy (localhost:8080): recorre todos los RPC y
# comprueba cada código de error del flujo principal.
set -euo pipefail

TARGET="${GRPC_TARGET:-localhost:8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in grpcurl jq; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

# IDs del seed (infra/cassandra/seed.cql)
BOB="22222222-2222-4222-8222-222222222222"
BACKEND="bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

grpc() {
  grpcurl -plaintext -import-path "$ROOT/proto" \
    -proto community/v1/community.proto -proto messaging/v1/messaging.proto "$@"
}

ok() { echo "  ✓ $1"; }

# expect_code <Código> <descripción> <argumentos de grpcurl...>
expect_code() {
  local code="$1" label="$2"; shift 2
  local output
  if output="$(grpc "$@" 2>&1)"; then
    echo "  ✗ $label: se esperaba $code y respondió OK" >&2; exit 1
  fi
  grep -q "Code: $code" <<<"$output" || { echo "  ✗ $label: se esperaba $code" >&2; echo "$output" >&2; exit 1; }
  ok "$label → $code"
}

echo "Comunidad"
suffix="$(date +%s)_${RANDOM}"
user_json="$(grpc -d "{\"username\":\"smoke_${suffix}\",\"email\":\"smoke_${suffix}@example.test\"}" "$TARGET" community.v1.CommunityService/CreateUser)"
user_id="$(jq -r '.userId' <<<"$user_json")"; ok "CreateUser"
expect_code AlreadyExists "CreateUser duplicado" -d "{\"username\":\"smoke_${suffix}\",\"email\":\"otro@example.test\"}" "$TARGET" community.v1.CommunityService/CreateUser
grpc -d "{\"userId\":\"$user_id\"}" "$TARGET" community.v1.CommunityService/GetUser >/dev/null; ok "GetUser"
[[ "$(grpc "$TARGET" community.v1.CommunityService/ListUsers | jq '.users | length')" -ge 3 ]]; ok "ListUsers"

channel_json="$(grpc -d "{\"name\":\"smoke_${suffix}\",\"description\":\"Smoke test channel\",\"createdBy\":\"$user_id\"}" "$TARGET" community.v1.CommunityService/CreateChannel)"
channel_id="$(jq -r '.channelId' <<<"$channel_json")"; ok "CreateChannel"
grpc -d "{\"channelId\":\"$channel_id\"}" "$TARGET" community.v1.CommunityService/GetChannel >/dev/null; ok "GetChannel"
[[ "$(grpc "$TARGET" community.v1.CommunityService/ListChannels | jq '.channels | length')" -ge 3 ]]; ok "ListChannels"
grpc -d "{\"userId\":\"$user_id\",\"channelId\":\"$channel_id\"}" "$TARGET" community.v1.CommunityService/JoinChannel >/dev/null; ok "JoinChannel"
grpc -d "{\"userId\":\"$user_id\"}" "$TARGET" community.v1.CommunityService/ListMyChannels >/dev/null; ok "ListMyChannels"
[[ "$(grpc -d "{\"userId\":\"$user_id\",\"channelId\":\"$channel_id\"}" "$TARGET" community.v1.CommunityService/IsMember | jq -r '.username')" == "smoke_${suffix}" ]]; ok "IsMember devuelve el username"

echo "Mensajería"
stream_output="$(mktemp)"
stream_pid=""
cleanup() {
  if [[ -n "$stream_pid" ]]; then
    kill "$stream_pid" 2>/dev/null || true
    wait "$stream_pid" 2>/dev/null || true
  fi
  rm -f "$stream_output"
}
trap cleanup EXIT

grpc -d "{\"channelId\":\"$channel_id\",\"userId\":\"$user_id\"}" "$TARGET" messaging.v1.MessagingService/Subscribe >"$stream_output" 2>&1 &
stream_pid=$!
sleep 1
content="smoke-stream-${suffix}"
grpc -d "{\"channelId\":\"$channel_id\",\"userId\":\"$user_id\",\"content\":\"$content\"}" "$TARGET" messaging.v1.MessagingService/SendMessage >/dev/null; ok "SendMessage"
[[ "$(grpc -d "{\"channelId\":\"$channel_id\",\"limit\":10}" "$TARGET" messaging.v1.MessagingService/GetHistory | jq '.messages | length')" -ge 1 ]]; ok "GetHistory (partición de hoy)"

expect_code InvalidArgument "SendMessage vacío" -d "{\"channelId\":\"$channel_id\",\"userId\":\"$user_id\",\"content\":\"   \"}" "$TARGET" messaging.v1.MessagingService/SendMessage
expect_code PermissionDenied "bob escribe en backend" -d "{\"channelId\":\"$BACKEND\",\"userId\":\"$BOB\",\"content\":\"hola\"}" "$TARGET" messaging.v1.MessagingService/SendMessage

for attempt in {1..10}; do
  if grep -q "$content" "$stream_output"; then
    ok "Subscribe recibió el mensaje en vivo"
    echo "Smoke tests passed through $TARGET"
    exit 0
  fi
  sleep 0.5
done
echo "Subscribe stream did not receive the sent message" >&2
cat "$stream_output" >&2
exit 1

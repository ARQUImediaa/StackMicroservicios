#!/usr/bin/env bash
set -euo pipefail

TARGET="${GRPC_TARGET:-localhost:8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in grpcurl jq; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

grpc() {
  grpcurl -plaintext -import-path "$ROOT/proto" \
    -proto community/v1/community.proto -proto messaging/v1/messaging.proto "$@"
}

suffix="$(date +%s)_${RANDOM}"
user_json="$(grpc -d "{\"username\":\"smoke_${suffix}\",\"email\":\"smoke_${suffix}@example.test\"}" "$TARGET" community.v1.CommunityService/CreateUser)"
user_id="$(jq -r '.userId' <<<"$user_json")"
grpc -d "{\"userId\":\"$user_id\"}" "$TARGET" community.v1.CommunityService/GetUser >/dev/null

channel_json="$(grpc -d "{\"name\":\"smoke_${suffix}\",\"description\":\"Smoke test channel\",\"createdBy\":\"$user_id\"}" "$TARGET" community.v1.CommunityService/CreateChannel)"
channel_id="$(jq -r '.channelId' <<<"$channel_json")"
grpc -d "{\"channelId\":\"$channel_id\"}" "$TARGET" community.v1.CommunityService/GetChannel >/dev/null
grpc -d "{\"userId\":\"$user_id\",\"channelId\":\"$channel_id\"}" "$TARGET" community.v1.CommunityService/JoinChannel >/dev/null
grpc -d "{\"userId\":\"$user_id\"}" "$TARGET" community.v1.CommunityService/ListMyChannels >/dev/null
grpc -d "{\"userId\":\"$user_id\",\"channelId\":\"$channel_id\"}" "$TARGET" community.v1.CommunityService/IsMember >/dev/null

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
grpc -d "{\"channelId\":\"$channel_id\",\"userId\":\"$user_id\",\"content\":\"$content\"}" "$TARGET" messaging.v1.MessagingService/SendMessage >/dev/null
grpc -d "{\"channelId\":\"$channel_id\",\"userId\":\"$user_id\",\"limit\":10}" "$TARGET" messaging.v1.MessagingService/GetHistory >/dev/null

for attempt in {1..10}; do
  if grep -q "$content" "$stream_output"; then
    echo "Smoke tests passed through $TARGET"
    exit 0
  fi
  sleep 0.5
done
echo "Subscribe stream did not receive the sent message" >&2
cat "$stream_output" >&2
exit 1
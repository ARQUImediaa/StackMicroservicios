#!/usr/bin/env bash
# Acto 3 de la demo: escalar y romper (ADR-07).
# Se escala message-service a 2 réplicas. Envoy reparte las peticiones entre
# ellas, pero cada réplica tiene su propio hub en memoria: el suscriptor solo
# recibe los mensajes que llegaron a SU réplica. Por eso existen los brokers.
set -euo pipefail

TARGET="${GRPC_TARGET:-localhost:8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
ALICE="11111111-1111-4111-8111-111111111111"
BOB="22222222-2222-4222-8222-222222222222"
TOTAL="${TOTAL:-10}"

grpc() { grpcurl -plaintext -import-path "$ROOT/proto" -proto messaging/v1/messaging.proto "$@"; }

cd "$ROOT"
echo "1) Escalando message-service a 2 réplicas..."
docker compose up -d --scale message-service=2 --no-recreate message-service >/dev/null
sleep 5
docker compose ps message-service --format '   {{.Name}}  {{.Status}}'

received="$(mktemp)"
trap 'kill $sub 2>/dev/null || true; rm -f "$received"' EXIT
echo
echo "2) bob se suscribe a #general (queda conectado a UNA de las réplicas)"
grpc -d "{\"channelId\":\"$GENERAL\",\"userId\":\"$BOB\"}" "$TARGET" messaging.v1.MessagingService/Subscribe >"$received" 2>&1 &
sub=$!
sleep 2

echo "3) alice envía $TOTAL mensajes; Envoy los reparte entre las réplicas"
run="$(date +%s)"
for i in $(seq 1 "$TOTAL"); do
  grpc -d "{\"channelId\":\"$GENERAL\",\"userId\":\"$ALICE\",\"content\":\"acto3-$run-$i\"}" "$TARGET" messaging.v1.MessagingService/SendMessage >/dev/null
done
sleep 2

got="$(grep -c "acto3-$run-" "$received" || true)"
echo
echo "   Enviados: $TOTAL   Recibidos en vivo por bob: $got"
if [ "$got" -lt "$TOTAL" ]; then
  echo "   → Se perdieron $((TOTAL - got)) mensajes en vivo: llegaron a la otra réplica, cuyo hub no conoce a bob."
  echo "     (Siguen guardados en Cassandra: GetHistory los devuelve todos.)"
else
  echo "   → Esta vez todos cayeron en la misma réplica; repite el script."
fi

echo
echo "4) Volviendo a 1 réplica..."
docker compose up -d --scale message-service=1 --no-recreate message-service >/dev/null
echo "Conclusión: el estado en memoria no escala horizontalmente. La evolución es un broker (ADR-07)."

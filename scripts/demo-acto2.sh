#!/usr/bin/env bash
# Acto 2 de la demo: fallo parcial.
# Se apaga community-service. Enviar falla con UNAVAILABLE (IsMember no responde
# dentro del deadline de 2 s), pero el historial sigue funcionando porque no
# depende de community-service. Al final se vuelve a encender.
set -euo pipefail

TARGET="${GRPC_TARGET:-localhost:8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERAL="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
ALICE="11111111-1111-4111-8111-111111111111"

grpc() { grpcurl -plaintext -import-path "$ROOT/proto" -proto messaging/v1/messaging.proto "$@"; }

cd "$ROOT"
echo "1) Apagando community-service..."
docker compose stop community-service >/dev/null

echo
echo "2) alice envía un mensaje a #general (debe fallar con UNAVAILABLE):"
grpc -d "{\"channelId\":\"$GENERAL\",\"userId\":\"$ALICE\",\"content\":\"hola durante la caída\"}" "$TARGET" messaging.v1.MessagingService/SendMessage 2>&1 | sed 's/^/   /' || true

echo
echo "3) Se pide el historial de #general (debe funcionar):"
grpc -d "{\"channelId\":\"$GENERAL\",\"limit\":5}" "$TARGET" messaging.v1.MessagingService/GetHistory | grep '"content"' | sed 's/^/   /'

echo
echo "4) Logs de message-service durante la caída:"
docker compose logs --no-log-prefix --since 30s message-service | grep -E 'membership.unavailable|history.read' | sed 's/^/   /' || true

echo
echo "5) Encendiendo community-service de nuevo..."
docker compose start community-service >/dev/null
echo "Listo: un servicio caído no tumbó el sistema completo."

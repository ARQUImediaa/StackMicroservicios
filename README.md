# ProyectoMicro

Backend de chat basado en microservicios Go, gRPC, Apache Cassandra y Envoy. El repositorio conserva también la aplicación Flutter en `frontend/` y el backend Ping anterior en `backend/`; el Compose de este documento levanta la nueva arquitectura bajo `services/`.

## Arquitectura

| Componente | Responsabilidad | Puerto |
| --- | --- | --- |
| `community-service` | Usuarios, canales, membresías y consulta `IsMember`; keyspace `community` | gRPC interno `50051` |
| `message-service` | Envío e historial de mensajes, autorización consultando `community-service`; keyspace `messaging` | gRPC interno `50052` |
| Envoy | Proxy HTTP/2 hacia ambos servicios gRPC | `localhost:8080` |
| Cassandra | Persistencia de usuarios, canales, membresías y mensajes | `localhost:9042` |

`cassandra-init` espera a que Cassandra esté saludable y aplica el esquema y los datos iniciales. Las tablas están desnormalizadas para consultar membresías por usuario o canal y para obtener mensajes por canal ordenados por `timeuuid`.

El streaming entrega mensajes nuevos a suscriptores conectados a esa instancia. No conserva eventos del hub en memoria ni los reenvía después de una desconexión; para recuperar mensajes anteriores, usa `GetHistory`. Este proyecto de ejemplo valida pertenencia al canal, pero aún no incluye autenticación de identidad.

## Estructura

```text
proto/
	community/v1/community.proto
	messaging/v1/messaging.proto
	go/                         # módulo y stubs Go generados
services/
	community-service/          # servidor gRPC, validaciones y Cassandra
	message-service/            # servidor gRPC, cliente interno y hub
infra/
	cassandra/schema.cql
	cassandra/seed.cql
	envoy/envoy.yaml
scripts/
	gen-proto.sh
	smoke.sh
docker-compose.yml
```

## Requisitos

- Docker Engine y Docker Compose v2
- Bash, Go y `protoc` para regenerar los stubs localmente
- Bash, `grpcurl` y `jq` para ejecutar el smoke test

En Windows, ejecuta los scripts desde Git Bash o WSL. El arranque con Docker no requiere instalar Go, Flutter ni `protoc` en el host: los Dockerfiles generan los stubs durante la compilación.

## Arranque y operación

Desde la raíz del repositorio:

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f community-service message-service envoy
```

El primer inicio de Cassandra puede tardar unos minutos. Envoy es el único endpoint gRPC publicado para los servicios: `localhost:8080`. Para detener los contenedores conservando los datos:

```bash
docker compose down
```

Para borrar también el volumen de Cassandra y reiniciar desde cero:

```bash
docker compose down -v
docker compose up -d --build
```

El seed inicial crea a `alice` (`11111111-1111-4111-8111-111111111111`), a `bob` (`22222222-2222-4222-8222-222222222222`) y el canal `general` (`aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`), con ambos usuarios como miembros.

## Contratos y generación

Los contratos fuente están en `proto/community/v1/community.proto` y `proto/messaging/v1/messaging.proto`. Para generar o actualizar los stubs Go en `proto/go/`:

```bash
bash scripts/gen-proto.sh
```

El script instala versiones fijadas de `protoc-gen-go` y `protoc-gen-go-grpc`. Las imágenes repiten la generación dentro del build, así que no es necesario ejecutar este paso para usar Compose.

## API gRPC

`community.v1.CommunityService`:

- `CreateUser`, `GetUser`
- `CreateChannel`, `GetChannel`
- `JoinChannel`, `ListMyChannels`, `IsMember`

`messaging.v1.MessagingService`:

- `SendMessage`
- `GetHistory`: límite de 1 a 100; usa 50 si no se especifica y entrega el resultado en orden cronológico.
- `Subscribe`: server streaming de mensajes nuevos del canal.

Ejemplo de consulta a la usuaria seed a través de Envoy:

```bash
grpcurl -plaintext \
	-import-path proto \
	-proto community/v1/community.proto \
	-d '{"userId":"11111111-1111-4111-8111-111111111111"}' \
	localhost:8080 community.v1.CommunityService/GetUser
```

## Smoke test

Con los contenedores levantados:

```bash
bash scripts/smoke.sh
```

El script crea usuario y canal con nombres únicos, comprueba todos los métodos unary y verifica que `Subscribe` recibe el mensaje que acaba de enviar. El destino predeterminado es `localhost:8080`; se puede cambiar, por ejemplo, con `GRPC_TARGET=localhost:8080 bash scripts/smoke.sh`.

## Configuración y observabilidad

Las variables de los servicios son `CASSANDRA_HOSTS` (lista separada por comas), `CASSANDRA_PORT` (por defecto `9042`), `GRPC_PORT` y `COMMUNITY_SERVICE_ADDR` (por defecto `community-service:50051`). Compose asigna los valores necesarios automáticamente.

Los servidores exponen gRPC health checking y reflection, escriben logs JSON con `slog` y aceptan o generan el metadato `x-request-id`, que también aparece en los logs. Envoy enruta por nombre de servicio protobuf; los puertos `50051` y `50052` permanecen internos a la red de Compose.
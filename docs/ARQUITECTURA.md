# Arquitectura del proyecto — guía para entenderlo por dentro

Esta guía explica **cómo el estilo de microservicios se ve en el código**. Sirve para estudiar y para sustentar. Los diagramas están en [`docs/diagramas/`](diagramas/).

![Arquitectura de alto nivel](diagramas/01-hld.png)

---

## 1. Orden de todo

### 1.1 Orden de arranque

`docker compose up -d --build` levanta los contenedores en este orden, controlado con `depends_on` y healthchecks:

| # | Contenedor | Espera a | Por qué |
|---|---|---|---|
| 1 | `cassandra` | — | Arranca en unos 60–90 s. El healthcheck espera a que `cqlsh` responda |
| 2 | `cassandra-init` | `cassandra` sano | Ejecuta `schema.cql` y `seed.cql` una vez, y termina |
| 3 | `community-service` | `cassandra-init` completado | Necesita el keyspace `community` creado |
| 4 | `message-service` | `cassandra-init` y `community-service` | Necesita el keyspace `messaging` y a quién preguntarle `IsMember` |
| 5 | `envoy` | los dos servicios | Único punto de entrada: `localhost:8080` |

Además, los servicios reintentan la conexión a Cassandra con backoff (`cassandra.connect_retry` en los logs). Nunca asumen que la base de datos ya está lista.

### 1.2 Orden recomendado para leer el código

1. **`proto/`:** los contratos. Todo lo demás se genera o se implementa a partir de aquí.
2. **`infra/cassandra/schema.cql`:** un keyspace por servicio y las tablas modeladas por consulta.
3. **`services/community-service/`:** el servicio más simple (un servidor y sus consultas).
4. **`services/message-service/`,** en este orden:
   1. `internal/server`: coordina el flujo;
   2. `internal/validation`;
   3. `internal/membership`;
   4. `internal/storage`;
   5. `internal/hub`;
   6. `internal/logging`;
   7. `main.go`: conecta todo.
5. **`infra/envoy/envoy.yaml`:** las rutas del gateway.
6. **`frontend/lib/`:**
   1. `src/grpc/clients.dart`;
   2. `src/features/`: usuarios → canales → chat.

---

## 2. Componentes

### 2.1 Contenedores

| Contenedor | Qué hace | Depende de | Expone |
|---|---|---|---|
| App Flutter (`frontend/`) | Elegir usuario, ver canales, chatear en vivo | Envoy | — |
| `envoy` | API Gateway: enruta cada llamada gRPC por nombre de servicio y genera el `x-request-id` | los dos servicios | **`:8080` (único puerto publicado)** |
| `community-service` | Usuarios, canales, membresías; responde `IsMember` | keyspace `community` | `:50051` (solo red interna) |
| `message-service` | Enviar, historial y suscripción en vivo | keyspace `messaging`, `community-service` | `:50052` (solo red interna) |
| `cassandra` | Persistencia, un keyspace por servicio | — | `:9042` (solo red interna) |
| `cassandra-init` | Crea esquema y datos de demostración | `cassandra` | — |

### 2.2 Paquetes de `message-service` (diagrama C4 nivel 3)

![Componentes](diagramas/06-c4-componentes.png)

| Paquete | Responsabilidad | Depende de |
|---|---|---|
| `internal/server` | Implementa `MessagingService`. Coordina: validar → membresía → guardar → publicar | Interfaces `Validator`, `MembershipChecker`, `MessageRepository` y el `Hub` |
| `internal/validation` | Reglas de entrada: UUIDs válidos, contenido de 1 a 1000 caracteres → `INVALID_ARGUMENT` | — |
| `internal/membership` | Cliente de `IsMember`, con **deadline de 2 s** y propagación del `request_id`; cualquier fallo → `UNAVAILABLE` | `community-service` (gRPC) |
| `internal/storage` | Repositorio de Cassandra; calcula el bucket de día de la partición | keyspace `messaging` |
| `internal/hub` | Reparte en memoria los mensajes a los streams abiertos | — |
| `internal/logging` | `request_id`, interceptores `rpc.start` y `rpc.end`, logger JSON | — |
| `main.go` | Crea las implementaciones reales y se las inyecta al servidor | todo lo anterior |

`community-service` es más simple: un servidor (`internal/server`) con sus consultas a Cassandra.

---

## 3. Distribución arquitectónica

![Despliegue](diagramas/05-despliegue.png)

- **Una máquina con Docker y una red interna de Compose.** Los contenedores se encuentran por nombre gracias al DNS de Docker (`cassandra`, `community-service`, `message-service`).
- **Solo Envoy publica un puerto** (`8080:8080`). Los servicios y Cassandra no son accesibles desde fuera.
- **Volumen `cassandra_data`:** los datos sobreviven a `docker compose down` (se borran con `down -v`).
- **Réplicas:** una por servicio. `message-service` **no debe** escalarse sin un broker (ver el acto 3, sección 7).
- **Cómo llega cada cliente:**
  - app de escritorio Windows: `localhost:8080`;
  - emulador Android: `10.0.2.2:8080`;
  - celular físico: `--dart-define=HOST=<IP del portátil>`.

---

## 4. La arquitectura dentro del proyecto

Dónde vive cada decisión de arquitectura en el código:

| Carpeta o archivo | Componente | Decisión o patrón que materializa |
|---|---|---|
| `services/community-service/` y `services/message-service/` | Dos microservicios | **ADR-01:** separados por contexto de negocio (Comunidad / Mensajería), no uno por entidad |
| Un `go.mod` por servicio | Despliegue independiente | Cada servicio compila y se despliega solo |
| `internal/` en cada servicio | Encapsulamiento | El compilador de Go impide que otro módulo importe ese código: los servicios **no comparten código de dominio** |
| `proto/` | Contratos | **Contrato primero:** el `.proto` es la única fuente de verdad; Go y Dart se generan desde él |
| `schema.cql` (keyspaces `community` y `messaging`), `cluster.Keyspace` en cada `main.go` | Base de datos por servicio | **ADR-02:** cada servicio solo se conecta a su keyspace |
| `messages_by_channel ((channel_id, day), message_id)`, `storage.Day()` | Partición | **ADR-03:** un canal en un día (UTC) por partición |
| `SendMessage` unary y `Subscribe` con `stream` | Tipos de llamada gRPC | **ADR-04:** envío unario + recepción con server streaming |
| `infra/envoy/envoy.yaml` | API Gateway | **ADR-05:** único punto de entrada; enruta por prefijo `/community.v1…` y `/messaging.v1…` |
| `JoinChannel` con `NewBatch(gocql.LoggedBatch)` | Membresía duplicada | **ADR-06:** dos tablas (`memberships_by_user`, `memberships_by_channel`) escritas juntas, sin aislamiento |
| `internal/hub` | Suscripciones en memoria | **ADR-07:** estado local, una réplica; la evolución es un broker |
| `frontend/lib/src/grpc/clients.dart` (`ClientChannel`, sin grpc-web) | Cliente nativo | **ADR-08:** gRPC nativo sobre HTTP/2 en Windows y Android |
| `internal/membership` (`context.WithTimeout`) | Táctica de disponibilidad | **Timeout:** si `community-service` no responde en 2 s, falla rápido con `UNAVAILABLE` |
| `GetHistory` y `Subscribe` sin `IsMember` | Táctica de disponibilidad | **Degradación:** si cae `community-service`, leer sigue funcionando |
| `INSERT … IF NOT EXISTS` en `CreateUser` y `CreateChannel` | Unicidad en Cassandra | **Transacción ligera (LWT):** Cassandra no tiene restricciones `UNIQUE` |

**Cómo se ve el estilo en la estructura:**
- dos módulos independientes que solo comparten un contrato;
- cada uno dueño de sus datos;
- un gateway delante;
- y una sola llamada síncrona entre ellos (`IsMember`), protegida con deadline.

---

## 5. Flujo principal con logs

![Secuencia](diagramas/04-c4-dinamico.png)

Caso de uso: **bob escribe "hola" en #general** y los suscritos al canal lo reciben en vivo.

| Paso | Qué pasa | Dónde |
|---|---|---|
| 0 | La app de cada miembro abrió `Subscribe` al entrar al chat. El hub lo registra (`subscriber.added`) | `message-service`, `internal/hub` |
| 1–2 | La app llama `SendMessage`; Envoy genera el `x-request-id` y enruta a `message-service` | Envoy |
| 3 | Validación de la entrada | `internal/validation` |
| 4–5 | `IsMember` a `community-service`, con deadline de 2 s y el mismo `request_id` | `internal/membership` → `community-service` |
| 6–7 | `INSERT` en la partición `(general, 2026-09-29)` | `internal/storage` |
| 8 | Publicación en el hub | `internal/hub` |
| 9 | Respuesta a bob | `internal/server` |
| 10 | Los suscritos reciben el mensaje por su stream | `Subscribe` |

Logs **reales** de una ejecución, con el mismo `request_id` en todos los componentes (se omite el campo `time`):

```json
{"level":"INFO","msg":"rpc.start","service":"message-service","rpc":"/messaging.v1.MessagingService/SendMessage","request_id":"80d99637-48ac-43aa-90d3-c1efecbb2f57"}
{"level":"INFO","msg":"message.validated","service":"message-service","request_id":"80d99637-48ac-43aa-90d3-c1efecbb2f57","channel_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","user_id":"22222222-2222-4222-8222-222222222222","content_len":4}
{"level":"INFO","msg":"rpc.end","service":"community-service","rpc":"/community.v1.CommunityService/IsMember","request_id":"80d99637-48ac-43aa-90d3-c1efecbb2f57","duration_ms":3,"code":"OK"}
{"level":"INFO","msg":"membership.checked","service":"message-service","request_id":"80d99637-48ac-43aa-90d3-c1efecbb2f57","is_member":true,"duration_ms":4}
{"level":"INFO","msg":"message.stored","service":"message-service","request_id":"80d99637-48ac-43aa-90d3-c1efecbb2f57","channel_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","day":"2026-09-29"}
{"level":"INFO","msg":"message.published","service":"message-service","request_id":"80d99637-48ac-43aa-90d3-c1efecbb2f57","channel_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","subscribers":0}
{"level":"INFO","msg":"rpc.end","service":"message-service","rpc":"/messaging.v1.MessagingService/SendMessage","request_id":"80d99637-48ac-43aa-90d3-c1efecbb2f57","code":"OK","duration_ms":6}
{"service":"envoy","msg":"access","request_id":"…","path":"/messaging.v1.MessagingService/SendMessage","grpc_status":"OK","duration_ms":8}
```

`subscribers` indica a cuántos streams abiertos llegó el mensaje. Con dos apps abiertas en #general, vale 2.

**Cómo seguir un mensaje en los logs:**

```bash
# todos los logs en vivo
docker compose logs -f --no-log-prefix envoy community-service message-service

# el recorrido de una petición concreta
docker compose logs --no-log-prefix envoy community-service message-service | grep <request_id>
```

El `request_id` de cada respuesta también llega a la app en el header `x-request-id`.

---

## 6. Flujos de error con logs

Cada error ocurre en un paso distinto del flujo, y los logs muestran hasta dónde llegó la petición.

**`INVALID_ARGUMENT`: mensaje vacío.** Se rechaza en el paso 3, **sin llamar a `community-service`**:

```json
{"level":"INFO","msg":"rpc.start","service":"message-service","rpc":"/messaging.v1.MessagingService/SendMessage","request_id":"9f59aa7e-…"}
{"level":"WARN","msg":"rpc.end","service":"message-service","rpc":"/messaging.v1.MessagingService/SendMessage","request_id":"9f59aa7e-…","code":"InvalidArgument","duration_ms":0,"error":"content must contain between 1 and 1000 characters"}
```

**`PERMISSION_DENIED`: bob escribe en #backend, donde no es miembro.** `IsMember` responde `false` y no se guarda nada:

```json
{"level":"INFO","msg":"message.validated","service":"message-service","request_id":"0c967404-…","channel_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","user_id":"22222222-2222-4222-8222-222222222222","content_len":4}
{"level":"INFO","msg":"rpc.end","service":"community-service","rpc":"/community.v1.CommunityService/IsMember","request_id":"0c967404-…","duration_ms":2,"code":"OK"}
{"level":"INFO","msg":"membership.checked","service":"message-service","request_id":"0c967404-…","is_member":false,"duration_ms":2}
{"level":"WARN","msg":"rpc.end","service":"message-service","rpc":"/messaging.v1.MessagingService/SendMessage","request_id":"0c967404-…","code":"PermissionDenied","duration_ms":2,"error":"user is not a member of this channel"}
```

**`UNAVAILABLE`: `community-service` apagado.** El deadline corta la espera a los **2 s** (`duration_ms: 2001`):

```json
{"level":"INFO","msg":"message.validated","service":"message-service","request_id":"5509dc5f-…","channel_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","user_id":"22222222-2222-4222-8222-222222222222","content_len":4}
{"level":"WARN","msg":"membership.unavailable","service":"message-service","request_id":"5509dc5f-…","duration_ms":2001,"error":"community-service unavailable: context deadline exceeded while waiting for connections to become ready"}
{"level":"WARN","msg":"rpc.end","service":"message-service","rpc":"/messaging.v1.MessagingService/SendMessage","request_id":"5509dc5f-…","code":"Unavailable","duration_ms":2001,"error":"community-service unavailable: context deadline exceeded while waiting for connections to become ready"}
{"service":"envoy","msg":"access","request_id":"5509dc5f-…","path":"/messaging.v1.MessagingService/SendMessage","grpc_status":"UNAVAILABLE","duration_ms":2001}
```

La app traduce cada código a un mensaje en español (`frontend/lib/src/errors.dart`).

---

## 7. Demo en 3 actos

Requisitos: el sistema levantado (`docker compose up -d --build`), `grpcurl` y `jq`.

| Acto | Comando | Qué observar | Qué enseña |
|---|---|---|---|
| 1. Funciona | Dos apps abiertas en #general (por ejemplo alice en Windows y bob en Android); una escribe | El mensaje aparece en vivo en la otra; en los logs, `message.published` con `subscribers: 2` | El flujo completo y el server streaming |
| 2. Fallo parcial | `bash scripts/demo-acto2.sh` | Enviar da `UNAVAILABLE` tras 2 s; el historial sigue respondiendo | Aislamiento de fallos (deadline + degradación) y el costo del acoplamiento síncrono |
| 3. Escalar y romper | `bash scripts/demo-acto3.sh` | Con 2 réplicas de `message-service`, bob recibe en vivo solo parte de los mensajes (en la prueba: 5 de 10) | El estado en memoria no escala horizontalmente (ADR-07); por qué existen los brokers |

En el acto 3, los mensajes perdidos en vivo **sí quedaron guardados**: `GetHistory` los devuelve todos. Lo que no escala es el reparto en vivo, no la persistencia.

---

## 8. Desviaciones respecto al documento técnico

| Documento técnico y diagramas | Implementación | Por qué |
|---|---|---|
| IDs naturales (`user_id` = nombre de usuario) | **UUIDs** + tablas de búsqueda `users_by_username` y `channels_by_name` | Decisión del equipo. La unicidad del nombre se garantiza con LWT sobre la tabla de búsqueda |
| Tablas `members_by_channel` y `channels_by_user` | `memberships_by_channel` y `memberships_by_user` | Solo cambia el nombre; mismo modelo y mismo `BATCH` logged |
| El usuario tiene nombre visible | El usuario tiene `username` y `email` | Decisión del equipo |
| Consultas Q1–Q8 | Se agregan `GetUser`, `GetChannel`, `ListUsers` y `ListChannels` (Q9: listar canales) | La app necesita listar usuarios y canales para elegir y unirse |
| `ListMyChannels` devuelve IDs | Devuelve los canales completos | Evita una segunda llamada desde la app |
| Código generado versionado en cada servicio | El Go se genera en `proto/go` al compilar (no se versiona); el Dart sí se versiona en `frontend/lib/src/generated` | Decisión del equipo para Go; la app necesita el Dart para compilar sin `protoc` |
| Carpeta `app/` | Carpeta `frontend/` | Nombre elegido por el equipo |
| Límite de historial de 200 | Máximo 100, por defecto 50 | Suficiente para la demo |

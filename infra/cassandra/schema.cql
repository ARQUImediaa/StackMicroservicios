-- ADR-02: un keyspace por servicio. community es de community-service; messaging, de message-service.
CREATE KEYSPACE IF NOT EXISTS community
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

CREATE KEYSPACE IF NOT EXISTS messaging
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

CREATE TABLE IF NOT EXISTS community.users (
  user_id uuid PRIMARY KEY,
  username text,
  email text,
  created_at timestamp
);

CREATE TABLE IF NOT EXISTS community.users_by_username (
  username text PRIMARY KEY,
  user_id uuid,
  email text,
  created_at timestamp
);

CREATE TABLE IF NOT EXISTS community.channels (
  channel_id uuid PRIMARY KEY,
  name text,
  description text,
  created_by uuid,
  created_at timestamp
);

CREATE TABLE IF NOT EXISTS community.channels_by_name (
  name text PRIMARY KEY,
  channel_id uuid,
  description text,
  created_by uuid,
  created_at timestamp
);

CREATE TABLE IF NOT EXISTS community.memberships_by_user (
  user_id uuid,
  channel_id uuid,
  joined_at timestamp,
  PRIMARY KEY ((user_id), channel_id)
) WITH CLUSTERING ORDER BY (channel_id ASC);

CREATE TABLE IF NOT EXISTS community.memberships_by_channel (
  channel_id uuid,
  user_id uuid,
  joined_at timestamp,
  PRIMARY KEY ((channel_id), user_id)
) WITH CLUSTERING ORDER BY (user_id ASC);

-- ADR-03: la partición es un canal en un día (UTC). El día evita que un canal
-- activo acumule una partición sin límite; message_id (timeuuid) ordena las filas.
CREATE TABLE IF NOT EXISTS messaging.messages_by_channel (
  channel_id uuid,
  day date,
  message_id timeuuid,
  user_id uuid,
  username text,
  content text,
  created_at timestamp,
  PRIMARY KEY ((channel_id, day), message_id)
) WITH CLUSTERING ORDER BY (message_id DESC);
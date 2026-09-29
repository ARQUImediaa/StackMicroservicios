INSERT INTO community.users (user_id, username, email, created_at)
VALUES (11111111-1111-4111-8111-111111111111, 'alice', 'alice@example.test', toTimestamp(now()));
INSERT INTO community.users_by_username (username, user_id, email, created_at)
VALUES ('alice', 11111111-1111-4111-8111-111111111111, 'alice@example.test', toTimestamp(now()));

INSERT INTO community.users (user_id, username, email, created_at)
VALUES (22222222-2222-4222-8222-222222222222, 'bob', 'bob@example.test', toTimestamp(now()));
INSERT INTO community.users_by_username (username, user_id, email, created_at)
VALUES ('bob', 22222222-2222-4222-8222-222222222222, 'bob@example.test', toTimestamp(now()));

INSERT INTO community.channels (channel_id, name, description, created_by, created_at)
VALUES (aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa, 'general', 'Canal general de bienvenida', 11111111-1111-4111-8111-111111111111, toTimestamp(now()));
INSERT INTO community.channels_by_name (name, channel_id, description, created_by, created_at)
VALUES ('general', aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa, 'Canal general de bienvenida', 11111111-1111-4111-8111-111111111111, toTimestamp(now()));

INSERT INTO community.memberships_by_user (user_id, channel_id, joined_at)
VALUES (11111111-1111-4111-8111-111111111111, aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa, toTimestamp(now()));
INSERT INTO community.memberships_by_channel (channel_id, user_id, joined_at)
VALUES (aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa, 11111111-1111-4111-8111-111111111111, toTimestamp(now()));
INSERT INTO community.memberships_by_user (user_id, channel_id, joined_at)
VALUES (22222222-2222-4222-8222-222222222222, aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa, toTimestamp(now()));
INSERT INTO community.memberships_by_channel (channel_id, user_id, joined_at)
VALUES (aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa, 22222222-2222-4222-8222-222222222222, toTimestamp(now()));

-- Canal backend: solo alice es miembro. bob recibe PERMISSION_DENIED si escribe aquí.
INSERT INTO community.channels (channel_id, name, description, created_by, created_at)
VALUES (bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb, 'backend', 'Canal del equipo de backend', 11111111-1111-4111-8111-111111111111, toTimestamp(now()));
INSERT INTO community.channels_by_name (name, channel_id, description, created_by, created_at)
VALUES ('backend', bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb, 'Canal del equipo de backend', 11111111-1111-4111-8111-111111111111, toTimestamp(now()));
INSERT INTO community.memberships_by_user (user_id, channel_id, joined_at)
VALUES (11111111-1111-4111-8111-111111111111, bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb, toTimestamp(now()));
INSERT INTO community.memberships_by_channel (channel_id, user_id, joined_at)
VALUES (bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb, 11111111-1111-4111-8111-111111111111, toTimestamp(now()));

INSERT INTO messaging.messages_by_channel (channel_id, day, message_id, user_id, username, content, created_at)
VALUES (aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa, toDate(now()), now(), 11111111-1111-4111-8111-111111111111, 'alice', 'Bienvenidos al canal general', toTimestamp(now()));
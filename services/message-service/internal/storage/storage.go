// Package storage es el repositorio de mensajes en el keyspace messaging.
//
// ADR-03: la tabla messages_by_channel se particiona por (channel_id, day). Cada
// partición es un canal en un día (UTC) y las filas se ordenan por message_id
// (timeuuid) de más nuevo a más viejo.
package storage

import (
	"context"
	"time"

	"github.com/gocql/gocql"
)

// Message es una fila de messages_by_channel.
type Message struct {
	ChannelID gocql.UUID
	Day       time.Time
	MessageID gocql.UUID
	UserID    gocql.UUID
	Username  string
	Content   string
	CreatedAt time.Time
}

// Day devuelve el bucket de día (UTC) de un instante: la segunda parte de la partition key.
func Day(t time.Time) time.Time {
	t = t.UTC()
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// Cassandra implementa el repositorio con gocql.
type Cassandra struct {
	session *gocql.Session
}

// New crea el repositorio sobre una sesión ya conectada al keyspace messaging.
func New(session *gocql.Session) *Cassandra {
	return &Cassandra{session: session}
}

// Save guarda un mensaje en la partición (channel_id, day).
func (c *Cassandra) Save(ctx context.Context, m Message) error {
	return c.session.Query(
		`INSERT INTO messages_by_channel (channel_id, day, message_id, user_id, username, content, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		m.ChannelID, m.Day, m.MessageID, m.UserID, m.Username, m.Content, m.CreatedAt,
	).WithContext(ctx).Exec()
}

// ListByChannelDay lee una sola partición: la consulta da la partition key
// completa, así que Cassandra va directo al nodo que la tiene.
func (c *Cassandra) ListByChannelDay(ctx context.Context, channelID gocql.UUID, day time.Time, limit int) ([]Message, error) {
	iter := c.session.Query(
		`SELECT message_id, user_id, username, content, created_at FROM messages_by_channel WHERE channel_id = ? AND day = ? LIMIT ?`,
		channelID, day, limit,
	).WithContext(ctx).Iter()
	messages := make([]Message, 0, limit)
	var m Message
	for iter.Scan(&m.MessageID, &m.UserID, &m.Username, &m.Content, &m.CreatedAt) {
		m.ChannelID, m.Day = channelID, day
		messages = append(messages, m)
	}
	return messages, iter.Close()
}

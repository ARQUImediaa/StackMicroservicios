// Package membership es el cliente de la única llamada entre servicios:
// message-service le pregunta a community-service si un usuario es miembro de
// un canal (IsMember). message-service nunca lee las tablas de community (ADR-02).
package membership

import (
	"context"
	"time"

	communityv1 "github.com/arquimediaa/proyectomicro/proto/go/community/v1"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/logging"
	"github.com/gocql/gocql"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// DefaultTimeout es el deadline de IsMember. Si community-service no responde a
// tiempo, el envío falla con UNAVAILABLE en vez de dejar colgado al cliente.
const DefaultTimeout = 2 * time.Second

// Result es la respuesta de IsMember.
type Result struct {
	IsMember bool
	Username string
}

// Client consulta la membresía en community-service.
type Client struct {
	community communityv1.CommunityServiceClient
	timeout   time.Duration
}

// New crea el cliente. timeout <= 0 usa DefaultTimeout.
func New(community communityv1.CommunityServiceClient, timeout time.Duration) *Client {
	if timeout <= 0 {
		timeout = DefaultTimeout
	}
	return &Client{community: community, timeout: timeout}
}

// IsMember propaga el request_id y aplica el deadline. Cualquier fallo de
// comunicación se traduce a UNAVAILABLE: es un fallo parcial del sistema, no
// un error del usuario.
func (c *Client) IsMember(ctx context.Context, userID, channelID gocql.UUID) (Result, error) {
	ctx, cancel := context.WithTimeout(logging.Outgoing(ctx), c.timeout)
	defer cancel()
	response, err := c.community.IsMember(ctx, &communityv1.IsMemberRequest{UserId: userID.String(), ChannelId: channelID.String()})
	if err != nil {
		return Result{}, status.Errorf(codes.Unavailable, "community-service unavailable: %s", status.Convert(err).Message())
	}
	return Result{IsMember: response.GetIsMember(), Username: response.GetUsername()}, nil
}

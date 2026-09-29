// Package validation contiene las reglas de entrada de message-service.
// Toda violación se responde con INVALID_ARGUMENT antes de llamar a otro
// servicio o a la base de datos.
package validation

import (
	"strings"
	"unicode/utf8"

	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
	"github.com/gocql/gocql"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const (
	// MaxContentRunes es el largo máximo de un mensaje, en caracteres.
	MaxContentRunes = 1000
	// DefaultHistoryLimit y MaxHistoryLimit acotan GetHistory.
	DefaultHistoryLimit = 50
	MaxHistoryLimit     = 100
)

// Send es un SendMessageRequest ya validado.
type Send struct {
	ChannelID gocql.UUID
	UserID    gocql.UUID
	Content   string
}

// Rules implementa las reglas. Es un tipo (y no funciones sueltas) para que el
// servidor dependa de una interfaz y se pueda probar con otro validador.
type Rules struct{}

// ValidateSend revisa los IDs y el contenido de un mensaje.
func (Rules) ValidateSend(request *messagingv1.SendMessageRequest) (Send, error) {
	channelID, err := parseUUID(request.GetChannelId(), "channel_id")
	if err != nil {
		return Send{}, err
	}
	userID, err := parseUUID(request.GetUserId(), "user_id")
	if err != nil {
		return Send{}, err
	}
	content := strings.TrimSpace(request.GetContent())
	if content == "" || utf8.RuneCountInString(content) > MaxContentRunes {
		return Send{}, status.Errorf(codes.InvalidArgument, "content must contain between 1 and %d characters", MaxContentRunes)
	}
	return Send{ChannelID: channelID, UserID: userID, Content: content}, nil
}

// ValidateChannel revisa el channel_id de GetHistory y Subscribe.
func (Rules) ValidateChannel(value string) (gocql.UUID, error) {
	return parseUUID(value, "channel_id")
}

// ValidateLimit aplica el límite por defecto y el máximo del historial.
func (Rules) ValidateLimit(limit int32) (int, error) {
	if limit == 0 {
		return DefaultHistoryLimit, nil
	}
	if limit < 1 || limit > MaxHistoryLimit {
		return 0, status.Errorf(codes.InvalidArgument, "limit must be between 1 and %d", MaxHistoryLimit)
	}
	return int(limit), nil
}

func parseUUID(value, field string) (gocql.UUID, error) {
	id, err := gocql.ParseUUID(strings.TrimSpace(value))
	if err != nil {
		return gocql.UUID{}, status.Errorf(codes.InvalidArgument, "%s must be a valid UUID", field)
	}
	return id, nil
}

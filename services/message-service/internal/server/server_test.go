package server

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"testing"
	"time"

	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/hub"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/membership"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/storage"
	"github.com/arquimediaa/proyectomicro/services/message-service/internal/validation"
	"github.com/gocql/gocql"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Dobles en memoria: el servidor se prueba sin Cassandra ni community-service.

type fakeMembers struct {
	result membership.Result
	err    error
	calls  int
}

func (f *fakeMembers) IsMember(context.Context, gocql.UUID, gocql.UUID) (membership.Result, error) {
	f.calls++
	return f.result, f.err
}

type fakeRepo struct {
	saved   []storage.Message
	saveErr error
}

func (f *fakeRepo) Save(_ context.Context, m storage.Message) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	f.saved = append(f.saved, m)
	return nil
}

func (f *fakeRepo) ListByChannelDay(_ context.Context, channelID gocql.UUID, day time.Time, limit int) ([]storage.Message, error) {
	var out []storage.Message
	for i := len(f.saved) - 1; i >= 0 && len(out) < limit; i-- { // más nuevo primero, como la tabla
		if f.saved[i].ChannelID == channelID && f.saved[i].Day.Equal(day) {
			out = append(out, f.saved[i])
		}
	}
	return out, nil
}

const (
	channel = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	user    = "11111111-1111-4111-8111-111111111111"
)

func newServer(members *fakeMembers, repo *fakeRepo) (*Server, *hub.Hub) {
	h := hub.New()
	s := New(validation.Rules{}, members, repo, h, slog.New(slog.NewTextHandler(io.Discard, nil)))
	s.now = func() time.Time { return time.Date(2026, 9, 29, 15, 4, 5, 0, time.UTC) }
	return s, h
}

func TestSendMessageCodes(t *testing.T) {
	cases := []struct {
		name        string
		content     string
		members     *fakeMembers
		repo        *fakeRepo
		want        codes.Code
		memberCalls int
	}{
		{"ok", "hola", &fakeMembers{result: membership.Result{IsMember: true, Username: "alice"}}, &fakeRepo{}, codes.OK, 1},
		{"vacío no llama a community", " ", &fakeMembers{}, &fakeRepo{}, codes.InvalidArgument, 0},
		{"no es miembro", "hola", &fakeMembers{result: membership.Result{IsMember: false}}, &fakeRepo{}, codes.PermissionDenied, 1},
		{"community caído", "hola", &fakeMembers{err: status.Error(codes.Unavailable, "down")}, &fakeRepo{}, codes.Unavailable, 1},
		{"cassandra caída", "hola", &fakeMembers{result: membership.Result{IsMember: true}}, &fakeRepo{saveErr: errors.New("timeout")}, codes.Unavailable, 1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s, _ := newServer(tc.members, tc.repo)
			_, err := s.SendMessage(context.Background(), &messagingv1.SendMessageRequest{ChannelId: channel, UserId: user, Content: tc.content})
			if code := status.Code(err); code != tc.want {
				t.Fatalf("código = %v, se esperaba %v (err: %v)", code, tc.want, err)
			}
			if tc.members.calls != tc.memberCalls {
				t.Fatalf("llamadas a IsMember = %d, se esperaban %d", tc.members.calls, tc.memberCalls)
			}
		})
	}
}

func TestSendMessageStoresInDayPartitionAndPublishes(t *testing.T) {
	repo := &fakeRepo{}
	s, h := newServer(&fakeMembers{result: membership.Result{IsMember: true, Username: "alice"}}, repo)
	live, unsubscribe := h.Subscribe(channel)
	defer unsubscribe()

	message, err := s.SendMessage(context.Background(), &messagingv1.SendMessageRequest{ChannelId: channel, UserId: user, Content: "hola"})
	if err != nil {
		t.Fatal(err)
	}
	if len(repo.saved) != 1 || repo.saved[0].Day != time.Date(2026, 9, 29, 0, 0, 0, 0, time.UTC) {
		t.Fatalf("se esperaba 1 mensaje en la partición del 2026-09-29, hay %+v", repo.saved)
	}
	if message.GetUsername() != "alice" {
		t.Fatalf("username = %q, debería venir de IsMember", message.GetUsername())
	}
	select {
	case got := <-live:
		if got.GetMessageId() != message.GetMessageId() {
			t.Fatal("el suscriptor recibió otro mensaje")
		}
	case <-time.After(time.Second):
		t.Fatal("el suscriptor no recibió el mensaje")
	}
}

// Acto 2 de la demo: sin community-service, el historial sigue funcionando.
func TestGetHistoryDoesNotDependOnCommunity(t *testing.T) {
	members := &fakeMembers{result: membership.Result{IsMember: true}}
	repo := &fakeRepo{}
	s, _ := newServer(members, repo)
	for _, text := range []string{"uno", "dos"} {
		if _, err := s.SendMessage(context.Background(), &messagingv1.SendMessageRequest{ChannelId: channel, UserId: user, Content: text}); err != nil {
			t.Fatal(err)
		}
	}
	members.err = status.Error(codes.Unavailable, "down")
	callsBefore := members.calls

	response, err := s.GetHistory(context.Background(), &messagingv1.GetHistoryRequest{ChannelId: channel})
	if err != nil {
		t.Fatalf("GetHistory falló sin community-service: %v", err)
	}
	if members.calls != callsBefore {
		t.Fatal("GetHistory no debe llamar a IsMember")
	}
	if len(response.GetMessages()) != 2 || response.GetMessages()[0].GetContent() != "uno" {
		t.Fatalf("se esperaba el historial en orden cronológico, dio %v", response.GetMessages())
	}
}

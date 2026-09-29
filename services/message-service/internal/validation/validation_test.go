package validation

import (
	"strings"
	"testing"

	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const (
	channel = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	user    = "11111111-1111-4111-8111-111111111111"
)

func TestValidateSend(t *testing.T) {
	cases := []struct {
		name    string
		request *messagingv1.SendMessageRequest
		want    codes.Code
	}{
		{"válido", &messagingv1.SendMessageRequest{ChannelId: channel, UserId: user, Content: "hola"}, codes.OK},
		{"se recortan espacios", &messagingv1.SendMessageRequest{ChannelId: channel, UserId: user, Content: "  hola  "}, codes.OK},
		{"vacío", &messagingv1.SendMessageRequest{ChannelId: channel, UserId: user, Content: "   "}, codes.InvalidArgument},
		{"límite exacto", &messagingv1.SendMessageRequest{ChannelId: channel, UserId: user, Content: strings.Repeat("ñ", MaxContentRunes)}, codes.OK},
		{"demasiado largo", &messagingv1.SendMessageRequest{ChannelId: channel, UserId: user, Content: strings.Repeat("a", MaxContentRunes+1)}, codes.InvalidArgument},
		{"canal inválido", &messagingv1.SendMessageRequest{ChannelId: "general", UserId: user, Content: "hola"}, codes.InvalidArgument},
		{"usuario inválido", &messagingv1.SendMessageRequest{ChannelId: channel, UserId: "", Content: "hola"}, codes.InvalidArgument},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := Rules{}.ValidateSend(tc.request)
			if code := status.Code(err); code != tc.want {
				t.Fatalf("código = %v, se esperaba %v (err: %v)", code, tc.want, err)
			}
			if tc.want == codes.OK && got.Content != strings.TrimSpace(tc.request.GetContent()) {
				t.Fatalf("contenido = %q", got.Content)
			}
		})
	}
}

func TestValidateLimit(t *testing.T) {
	cases := map[int32]codes.Code{0: codes.OK, 1: codes.OK, MaxHistoryLimit: codes.OK, -1: codes.InvalidArgument, MaxHistoryLimit + 1: codes.InvalidArgument}
	for limit, want := range cases {
		got, err := Rules{}.ValidateLimit(limit)
		if code := status.Code(err); code != want {
			t.Fatalf("limit %d: código = %v, se esperaba %v", limit, code, want)
		}
		if limit == 0 && got != DefaultHistoryLimit {
			t.Fatalf("limit 0 debería usar %d, dio %d", DefaultHistoryLimit, got)
		}
	}
}

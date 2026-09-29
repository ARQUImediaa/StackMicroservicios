package hub

import (
	"sync"
	"testing"

	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
)

func TestPublishReachesOnlySubscribersOfTheChannel(t *testing.T) {
	h := New()
	a, unsubA := h.Subscribe("general")
	defer unsubA()
	b, unsubB := h.Subscribe("general")
	defer unsubB()
	other, unsubOther := h.Subscribe("backend")
	defer unsubOther()

	if delivered := h.Publish(&messagingv1.Message{ChannelId: "general", Content: "hola"}); delivered != 2 {
		t.Fatalf("delivered = %d, se esperaban 2", delivered)
	}
	for _, ch := range []<-chan *messagingv1.Message{a, b} {
		if got := <-ch; got.GetContent() != "hola" {
			t.Fatalf("contenido = %q", got.GetContent())
		}
	}
	select {
	case m := <-other:
		t.Fatalf("un suscriptor de otro canal recibió %v", m)
	default:
	}
}

func TestUnsubscribeClosesChannel(t *testing.T) {
	h := New()
	ch, unsubscribe := h.Subscribe("general")
	unsubscribe()
	if _, open := <-ch; open {
		t.Fatal("el channel debería quedar cerrado")
	}
	if delivered := h.Publish(&messagingv1.Message{ChannelId: "general"}); delivered != 0 {
		t.Fatalf("delivered = %d después de darse de baja", delivered)
	}
}

// Suscripciones, bajas y publicaciones concurrentes: correr con -race.
func TestConcurrentUse(t *testing.T) {
	h := New()
	var wg sync.WaitGroup
	for i := 0; i < 50; i++ {
		wg.Add(2)
		go func() {
			defer wg.Done()
			ch, unsubscribe := h.Subscribe("general")
			go func() {
				for range ch {
				}
			}()
			unsubscribe()
		}()
		go func() {
			defer wg.Done()
			h.Publish(&messagingv1.Message{ChannelId: "general"})
		}()
	}
	wg.Wait()
}

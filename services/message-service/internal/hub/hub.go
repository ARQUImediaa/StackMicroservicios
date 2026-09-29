// Package hub reparte en memoria los mensajes nuevos a los streams abiertos.
//
// ADR-07: las suscripciones viven en la memoria de ESTA instancia. Con una
// sola réplica de message-service funciona; con dos, un mensaje enviado a la
// réplica 1 no llega a quien está suscrito en la réplica 2. Es un límite
// intencional del taller: la evolución sería un broker (Redis, NATS, Kafka).
package hub

import (
	"sync"

	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
)

const subscriberBuffer = 64

// Hub mantiene, por canal, un channel de Go con buffer por cada suscriptor.
type Hub struct {
	mu          sync.Mutex
	nextID      uint64
	subscribers map[string]map[uint64]chan *messagingv1.Message
}

func New() *Hub {
	return &Hub{subscribers: make(map[string]map[uint64]chan *messagingv1.Message)}
}

// Subscribe registra un suscriptor y devuelve su channel y la función para darse de baja.
func (h *Hub) Subscribe(channelID string) (<-chan *messagingv1.Message, func()) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.nextID++
	subscriberID := h.nextID
	messages := make(chan *messagingv1.Message, subscriberBuffer)
	if h.subscribers[channelID] == nil {
		h.subscribers[channelID] = make(map[uint64]chan *messagingv1.Message)
	}
	h.subscribers[channelID][subscriberID] = messages
	return messages, func() {
		h.mu.Lock()
		defer h.mu.Unlock()
		if channelSubscribers := h.subscribers[channelID]; channelSubscribers != nil {
			if subscriber, ok := channelSubscribers[subscriberID]; ok {
				delete(channelSubscribers, subscriberID)
				close(subscriber)
			}
			if len(channelSubscribers) == 0 {
				delete(h.subscribers, channelID)
			}
		}
	}
}

// Publish entrega el mensaje a los suscriptores del canal y devuelve a cuántos.
// Nunca bloquea: si el buffer de un suscriptor lento está lleno, se descarta su
// mensaje más viejo para hacer espacio al nuevo.
func (h *Hub) Publish(message *messagingv1.Message) int {
	h.mu.Lock()
	defer h.mu.Unlock()
	delivered := 0
	for _, subscriber := range h.subscribers[message.GetChannelId()] {
		select {
		case subscriber <- message:
			delivered++
			continue
		default:
		}
		select {
		case <-subscriber:
		default:
		}
		select {
		case subscriber <- message:
			delivered++
		default:
		}
	}
	return delivered
}

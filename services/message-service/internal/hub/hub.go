package hub

import (
	"sync"

	messagingv1 "github.com/arquimediaa/proyectomicro/proto/go/messaging/v1"
)

const subscriberBuffer = 64

type Hub struct {
	mu          sync.Mutex
	nextID      uint64
	subscribers map[string]map[uint64]chan *messagingv1.Message
}

func New() *Hub {
	return &Hub{subscribers: make(map[string]map[uint64]chan *messagingv1.Message)}
}

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

func (h *Hub) Publish(message *messagingv1.Message) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, subscriber := range h.subscribers[message.GetChannelId()] {
		select {
		case subscriber <- message:
		default:
			select {
			case <-subscriber:
			default:
			}
			select {
			case subscriber <- message:
			default:
			}
		}
	}
}
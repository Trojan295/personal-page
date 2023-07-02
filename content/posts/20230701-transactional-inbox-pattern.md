+++
date = "2023-07-02"
title = "Transactional outbox pattern example in Golang and MongoDB"
tags = [
  "golang",
  "software architecture",
  "mongodb",
  "rabbitmq"
]
categories = [
  "Golang",
  "Software architecture"
]
+++

For a personal project, I was experimenting with DDD. I was sending domain events through RabbitMQ to run choreography-based sagas.
One problem I had was ensuring that the domain event got sent out after modifying aggregates. It's not possible to run an atomic transaction through MongoDB and RabbitMQ, so there can be a situation where the aggregate is modified successfully in the database, but we won't send an event because RabbitMQ is not available. You could use retries, but this won't withstand, for example, an application crash.

To solve this, I used the [transactional outbox pattern](https://microservices.io/patterns/data/transactional-outbox.html). The idea is to have an additional table in the database to save events that have to be sent. It must be in the same database where the aggregate is persisted, so you can run it in the same DB transaction. Then we have some other process that polls documents from this collection and sends them to the event bus or queue.

With this, we can modify the aggregate and dispatch the event in the same MongoDB transaction. The event will then be sent to the RabbitMQ when it's available. This pattern ensures that the event will be sent out at least once, but it could also be sent multiple times. So on the consumer side, you have to either be idempotent or check for duplicate events. One idea here is to add GUIDs to your events and use the inbox pattern, where you check for duplicate events.

# Golang implementation

I was able to find a lot of examples in C# and Java, but just a few for the Outbox pattern in Golang. My example here is not something you can copy-paste, but you should get an idea of how to implement it yourself.

I defined the following interfaces:
```go
package application

// EventPublisher publishes events to an event bus or queue.
type EventPublisher interface {
  PublishEvents(ctx context.Context, event ...*domain.Event) error
}

// EventOutbox dispatches events to the transactional outbox.
type EventOutbox interface {
	DispatchEvents(ctx context.Context, event ...*domain.Event) error
}

// UnitOfWork provides an interface for running operations on the persistance layer in a single transaction.
type UnitOfWork interface {
	OrderRepository() domain.OrderRepository
	EventOutbox() domain.EventOutbox

	Run(ctx context.Context, f func(ctx context.Context) (interface{}, error)) (interface{}, error)
}
```

I have all the interactions with MongoDB in a single Go struct.
My `MongoDBStore` implements the `EventOutbox` and `UnitOfWork` interfaces. It also has a method `RunOutbox` to run the process, which sends events from the outbox to the event bus.

```go
// Event is MongoDB event representation
type Event struct {
	ID   primitive.ObjectID `bson:"_id,omitempty"`
	Data bson.Raw           `bson:"data"`

	Published bool `bson:"published"`
}

// ToModel is used convert from MongoDB to domain event
func (dto *Event) ToModel() (*domain.Event, error) {
  // ...
}

// FromModel is used to convert domain event to MongoDB representation
func (dto *Event) FromModel(event *domain.Event) error {
  // ...
}

// Run runs f in a single MongoDB transaction.
func (s *MongoDBStore) Run(ctx context.Context, f func(ctx context.Context) (interface{}, error)) (interface{}, error) {
	session, err := s.client.StartSession()
	if err != nil {
		return nil, err
	}
	defer session.EndSession(ctx)

	result, err := session.WithTransaction(ctx, func(sessCtx mongo.SessionContext) (interface{}, error) {
		return f(sessCtx)
	})
	if err != nil {
		return nil, err
	}

	return result, nil
}

// DispatchEvent inserts an event in the outbox collection to send out.
func (store *MongoDBStore) DispatchEvent(ctx context.Context, event *domain.Event) error {
  collection := store.client.Database(store.database).Collection(outboxCollection)

	dto := &Event{}
	if err := dto.FromModel(event); err != nil {
		return fmt.Errorf("failed to convert from model: %w", err)
	}

	_, err := collection.InsertOne(ctx, dto)
	if err != nil {
		return fmt.Errorf("failed to insert event: %w", err)
	}

  return nil
}

// RunOutbox runs an infinite loop, which polls and sends events
func (store *MongoDBStore) RunOutbox(ctx context.Context, eventPublisher application.EventPublisher) error {
	ticker := time.NewTicker(1 * time.Second)

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := store.runOutbox(ctx, eventPublisher); err != nil {
				return err
			}
		}
	}
}

func (store *MongoDBStore) runOutbox(ctx context.Context, eventPublisher application.EventPublisher) error {
	events, err := store.getUnpublishedEvents(ctx)
	if err != nil {
		return fmt.Errorf("failed to get unpublished events: %w", err)
	}

	for _, dto := range events {
		event, err := dto.ToModel()
		if err != nil {
			return fmt.Errorf("failed to convert event to model: %w", err)
		}

		if err := eventPublisher.PublishEvents(ctx, event); err != nil {
			return fmt.Errorf("failed to publish event: %w", err)
		}

		if err := store.setEventAsPublished(ctx, dto.ID); err != nil {
			return fmt.Errorf("failed to set event as published: %w", err)
		}
	}

	return nil
}

func (store *MongoDBStore) getUnpublishedEvents(ctx context.Context) ([]Event, error) {
	collection := store.client.Database(store.database).Collection(outboxCollection)

	cursor, err := collection.Find(ctx, bson.M{"published": false})
	if err != nil {
		return nil, fmt.Errorf("failed to get unpublished events: %w", err)
	}

	var events []Event
	if err := cursor.All(ctx, &events); err != nil {
		return nil, fmt.Errorf("failed to decode unpublished events: %w", err)
	}

	return events, nil

}

func (store *MongoDBStore) setEventAsPublished(ctx context.Context, eventID primitive.ObjectID) error {
	collection := store.client.Database(store.database).Collection(outboxCollection)

	result := collection.FindOneAndUpdate(ctx, bson.M{"_id": eventID}, bson.M{"$set": bson.M{"published": true}})
	if result.Err() != nil {
		return fmt.Errorf("failed to set event as published: %w", result.Err())
	}

	return nil
}
```

In main, you have to run the `RunOutbox` method in a goroutine. You can then use this in your handlers to modify aggregates and send domain events:

```go
package application

type CreateOrderHandler struct {
	uow         UnitOfWork
}

func (h CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrder) (*domain.Order, error) {
  // this generates an OrderCreated event
	order := domain.CreateOrder()

	orderIface, err := h.uow.Run(ctx, func(ctx context.Context) (interface{}, error) {
		if err := h.uow.OrderRepository().CreateOrder(ctx, order); err != nil {
			return nil, fmt.Errorf("failed to create order: %w", err)
		}

    if err := h.uow.EventOutbox().DispatchEvents(order.Events()); err != nil {
			return nil, fmt.Errorf("failed to dispatch events: %w", err)
		}

		return order, nil
	})
	if err != nil {
		return nil, err 
	}

	return orderIface.(*domain.Order), nil
}
```

You could also use [MongoDB ChangeStreams](https://www.mongodb.com/docs/manual/changeStreams/) instead of polling to get information when a new event is in the outbox.

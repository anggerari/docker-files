// Connects to every docker-files service that is running and does one real
// operation on each. Services that aren't running are skipped.
//
//	go run .            (settings come from env vars - see `make urls`)
package main

import (
	"context"
	"errors"
	"fmt"
	"net/smtp"
	"os"
	"strings"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/redis/go-redis/v9"
	"github.com/twmb/franz-go/pkg/kgo"
)

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

var failed bool

func run(name string, fn func(ctx context.Context) (string, error)) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	msg, err := fn(ctx)
	switch {
	case err == nil:
		fmt.Printf("  ✓ %-9s %s\n", name, msg)
	case errors.Is(err, syscall.ECONNREFUSED) || strings.Contains(err.Error(), "connection refused"):
		fmt.Printf("  - %-9s not running, skipped\n", name)
	default:
		failed = true
		fmt.Printf("  ✗ %-9s %v\n", name, err)
	}
}

// silence go-redis's internal retry logging; errors are reported by run()
type quietLogger struct{}

func (quietLogger) Printf(context.Context, string, ...interface{}) {}

func main() {
	redis.SetLogger(quietLogger{})
	fmt.Println("docker-files Go example")

	run("postgres", func(ctx context.Context) (string, error) {
		conn, err := pgx.Connect(ctx, env("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/app?sslmode=disable"))
		if err != nil {
			return "", err
		}
		defer conn.Close(ctx)
		_, err = conn.Exec(ctx, `
			CREATE TEMP TABLE items (name text, embedding vector(3));
			INSERT INTO items VALUES ('cat','[1,0,0]'), ('dog','[0.9,0.1,0]'), ('car','[0,0,1]');
		`)
		if err != nil {
			return "", err
		}
		var nearest string
		err = conn.QueryRow(ctx, `SELECT name FROM items ORDER BY embedding <-> '[1,0.05,0]' LIMIT 1`).Scan(&nearest)
		return "pgvector nearest neighbour: " + nearest, err
	})

	run("redis", func(ctx context.Context) (string, error) {
		opt, err := redis.ParseURL(env("REDIS_URL", "redis://:redis@localhost:6379/0"))
		if err != nil {
			return "", err
		}
		rdb := redis.NewClient(opt)
		defer rdb.Close()
		n, err := rdb.Incr(ctx, "examples:go:counter").Result()
		return fmt.Sprintf("counter = %d", n), err
	})

	run("s3", func(ctx context.Context) (string, error) {
		endpoint := strings.TrimPrefix(env("S3_ENDPOINT", "http://localhost:9000"), "http://")
		mc, err := minio.New(endpoint, &minio.Options{
			Creds: credentials.NewStaticV4(env("S3_ACCESS_KEY", "rustfsadmin"), env("S3_SECRET_KEY", "rustfsadmin"), ""),
		})
		if err != nil {
			return "", err
		}
		bucket := "examples"
		if ok, err := mc.BucketExists(ctx, bucket); err != nil {
			return "", err
		} else if !ok {
			if err := mc.MakeBucket(ctx, bucket, minio.MakeBucketOptions{}); err != nil {
				return "", err
			}
		}
		body := "hello from Go"
		_, err = mc.PutObject(ctx, bucket, "go.txt", strings.NewReader(body), int64(len(body)), minio.PutObjectOptions{ContentType: "text/plain"})
		return "uploaded s3://examples/go.txt", err
	})

	run("smtp", func(ctx context.Context) (string, error) {
		addr := env("SMTP_HOST", "localhost") + ":" + env("SMTP_PORT", "1025")
		msg := "From: app@example.com\r\nTo: you@example.com\r\nSubject: Hello from the Go example\r\n\r\nIt works!\r\n"
		return "sent - check the Mailpit inbox", smtp.SendMail(addr, nil, "app@example.com", []string{"you@example.com"}, []byte(msg))
	})

	run("rabbitmq", func(ctx context.Context) (string, error) {
		conn, err := amqp.Dial(env("AMQP_URL", "amqp://rabbit:rabbit@localhost:5672/"))
		if err != nil {
			return "", err
		}
		defer conn.Close()
		ch, err := conn.Channel()
		if err != nil {
			return "", err
		}
		// RabbitMQ 4 requires shared queues to be durable
		q, err := ch.QueueDeclare("examples-go", true, false, false, false, nil)
		if err != nil {
			return "", err
		}
		if err := ch.PublishWithContext(ctx, "", q.Name, false, false, amqp.Publishing{Body: []byte("hello from Go")}); err != nil {
			return "", err
		}
		for range 50 {
			if m, ok, err := ch.Get(q.Name, true); err != nil {
				return "", err
			} else if ok {
				return "round-trip: " + string(m.Body), nil
			}
			time.Sleep(100 * time.Millisecond)
		}
		return "", errors.New("message not received")
	})

	run("kafka", func(ctx context.Context) (string, error) {
		topic := "examples-go"
		cl, err := kgo.NewClient(
			kgo.SeedBrokers(strings.Split(env("KAFKA_BROKERS", "localhost:9092"), ",")...),
			kgo.ConsumeTopics(topic),
			kgo.AllowAutoTopicCreation(),
			kgo.ConsumeResetOffset(kgo.NewOffset().AtStart()),
		)
		if err != nil {
			return "", err
		}
		defer cl.Close()
		if err := cl.Ping(ctx); err != nil {
			return "", err
		}
		if err := cl.ProduceSync(ctx, &kgo.Record{Topic: topic, Value: []byte("hello from Go")}).FirstErr(); err != nil {
			return "", err
		}
		fetches := cl.PollFetches(ctx)
		if errs := fetches.Errors(); len(errs) > 0 {
			return "", errs[0].Err
		}
		return fmt.Sprintf("round-trip: %d record(s) read back", fetches.NumRecords()), nil
	})

	if failed {
		os.Exit(1)
	}
}

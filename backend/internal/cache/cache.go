package cache

import (
	"context"
	"time"
)

type BytesCache interface {
	GetBytes(ctx context.Context, key string) ([]byte, bool, error)
	SetBytes(ctx context.Context, key string, value []byte, ttl time.Duration) error
}

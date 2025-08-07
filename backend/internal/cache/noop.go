package cache

import (
	"context"
	"time"
)

type NoopCache struct{}

func (n NoopCache) GetBytes(ctx context.Context, key string) ([]byte, bool, error) {
	return nil, false, nil
}

func (n NoopCache) SetBytes(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	return nil
}

package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"awapp/backend/internal/config"
	"awapp/backend/internal/httpserver"
	"awapp/backend/internal/telemetry"
)

func main() {
	cfg := config.FromEnv()
	logger := telemetry.NewLogger(cfg.LogLevel)

	srv := httpserver.New(cfg, logger)

	go func() {
		if err := srv.Start(); err != nil && err != http.ErrServerClosed {
			logger.Error("http server start failed", slog.String("error", err.Error()))
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("http server shutdown failed", slog.String("error", err.Error()))
		os.Exit(1)
	}
	logger.Info("stopped")
}

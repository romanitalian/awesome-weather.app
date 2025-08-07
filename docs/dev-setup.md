## Dev setup

### Requirements
- Go 1.22+
- Flutter 3.32+
- Docker (for Redis)

### Run Redis
```bash
make up
make ps
```

### Run backend
```bash
cd backend
cp .env.example .env
export REDIS_ADDR=127.0.0.1:6379
make run
```

### Test API
```bash
curl "http://127.0.0.1:8080/api/v1/weather?lat=59.93&lon=30.31"
```

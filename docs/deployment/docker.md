# Docker Deployment

This guide covers deploying Measure.js using Docker containers for consistent, scalable deployments across different environments.

## Overview

Docker deployment provides:
- **Consistency**: Same environment across development, staging, and production
- **Scalability**: Easy horizontal scaling with container orchestration
- **Isolation**: Secure, isolated application environments
- **Portability**: Deploy anywhere Docker is supported

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Docker Hub account (optional, for image registry)

## Quick Start

### 1. Build the Image

```bash
# Build the application image
docker build -t measure-js:latest .

# Or build with specific tag
docker build -t measure-js:v1.0.0 .
```

### 2. Run the Container

```bash
# Run with environment variables
docker run -d \
  --name measure-js \
  -p 3000:3000 \
  -e GCP_PROJECT_ID=your-project-id \
  -e GCP_DATASET_ID=analytics \
  -e GCP_TABLE_ID=events \
  -e GEO_ACCOUNT=your-maxmind-account \
  -e GEO_KEY=your-maxmind-key \
  -e DAILY_SALT=your-secure-salt \
  measure-js:latest
```

### 3. Verify Deployment

```bash
# Check container status
docker ps

# Check logs
docker logs measure-js

# Test health endpoint
curl http://localhost:3000/health
```

## Dockerfile

The application includes a production-ready Dockerfile:

```dockerfile
# Use Bun runtime
FROM oven/bun:1 as base

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json bun.lockb ./

# Install dependencies
RUN bun install --frozen-lockfile

# Copy source code
COPY . .

# Build the application
RUN bun run build

# Production stage
FROM oven/bun:1-slim

WORKDIR /app

# Copy built application
COPY --from=base /app/dist ./dist
COPY --from=base /app/package.json ./
COPY --from=base /app/bun.lockb ./

# Install production dependencies only
RUN bun install --frozen-lockfile --production

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S measurejs -u 1001

# Change ownership
RUN chown -R measurejs:nodejs /app
USER measurejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["bun", "run", "src/api/index.ts"]
```

## Docker Compose

### Basic Setup

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  measure-js:
    build: .
    container_name: measure-js
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - GCP_PROJECT_ID=${GCP_PROJECT_ID}
      - GCP_DATASET_ID=${GCP_DATASET_ID}
      - GCP_TABLE_ID=${GCP_TABLE_ID}
      - GEO_ACCOUNT=${GEO_ACCOUNT}
      - GEO_KEY=${GEO_KEY}
      - DAILY_SALT=${DAILY_SALT}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - measure-network

networks:
  measure-network:
    driver: bridge
```

### Production Setup

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  measure-js:
    build: .
    container_name: measure-js-prod
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - GCP_PROJECT_ID=${GCP_PROJECT_ID}
      - GCP_DATASET_ID=${GCP_DATASET_ID}
      - GCP_TABLE_ID=${GCP_TABLE_ID}
      - GEO_ACCOUNT=${GEO_ACCOUNT}
      - GEO_KEY=${GEO_KEY}
      - DAILY_SALT=${DAILY_SALT}
      - CORS_ORIGINS=${CORS_ORIGINS}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - measure-network
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    image: nginx:alpine
    container_name: measure-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - measure-js
    restart: unless-stopped
    networks:
      - measure-network

networks:
  measure-network:
    driver: bridge
```

### Environment Variables

Create `.env` file:

```env
# Application Settings
NODE_ENV=production
PORT=3000

# Google Cloud Platform
GCP_PROJECT_ID=your-project-id
GCP_DATASET_ID=analytics
GCP_TABLE_ID=events

# MaxMind GeoIP2
GEO_ACCOUNT=your-maxmind-account
GEO_KEY=your-maxmind-license-key

# Security
DAILY_SALT=your-super-secure-random-salt

# CORS
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

## Nginx Configuration

Create `nginx.conf` for reverse proxy:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream measure-js {
        server measure-js:3000;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    server {
        listen 80;
        server_name your-domain.com www.your-domain.com;

        # Redirect HTTP to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com www.your-domain.com;

        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

        # API endpoints
        location /events {
            limit_req zone=api burst=20 nodelay;

            proxy_pass http://measure-js;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # CORS headers
            add_header Access-Control-Allow-Origin $http_origin always;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
            add_header Access-Control-Allow-Credentials true always;

            # Handle preflight requests
            if ($request_method = 'OPTIONS') {
                add_header Access-Control-Allow-Origin $http_origin;
                add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
                add_header Access-Control-Allow-Headers "Content-Type, Authorization";
                add_header Access-Control-Allow-Credentials true;
                add_header Content-Length 0;
                add_header Content-Type text/plain;
                return 204;
            }
        }

        location /health {
            proxy_pass http://measure-js;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Static files (if serving measure.js)
        location /measure.js {
            alias /var/www/measure.js;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

## Deployment Commands

### Development

```bash
# Build and run
docker-compose up --build

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f measure-js

# Stop services
docker-compose down
```

### Production

```bash
# Deploy with production config
docker-compose -f docker-compose.prod.yml up -d

# Scale the service
docker-compose -f docker-compose.prod.yml up -d --scale measure-js=3

# Update deployment
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d

# Rollback
docker-compose -f docker-compose.prod.yml up -d --force-recreate
```

## Container Orchestration

### Docker Swarm

Create `docker-stack.yml`:

```yaml
version: '3.8'

services:
  measure-js:
    image: measure-js:latest
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    environment:
      - NODE_ENV=production
      - GCP_PROJECT_ID=${GCP_PROJECT_ID}
      - GCP_DATASET_ID=${GCP_DATASET_ID}
      - GCP_TABLE_ID=${GCP_TABLE_ID}
      - GEO_ACCOUNT=${GEO_ACCOUNT}
      - GEO_KEY=${GEO_KEY}
      - DAILY_SALT=${DAILY_SALT}
    networks:
      - measure-network

networks:
  measure-network:
    driver: overlay
```

Deploy to swarm:

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-stack.yml measure-js

# Check status
docker stack services measure-js

# Scale service
docker service scale measure-js_measure-js=5
```

### Kubernetes

Create `k8s-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: measure-js
  labels:
    app: measure-js
spec:
  replicas: 3
  selector:
    matchLabels:
      app: measure-js
  template:
    metadata:
      labels:
        app: measure-js
    spec:
      containers:
      - name: measure-js
        image: measure-js:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: GCP_PROJECT_ID
          valueFrom:
            secretKeyRef:
              name: measure-js-secrets
              key: gcp-project-id
        - name: GCP_DATASET_ID
          valueFrom:
            secretKeyRef:
              name: measure-js-secrets
              key: gcp-dataset-id
        - name: GCP_TABLE_ID
          valueFrom:
            secretKeyRef:
              name: measure-js-secrets
              key: gcp-table-id
        - name: GEO_ACCOUNT
          valueFrom:
            secretKeyRef:
              name: measure-js-secrets
              key: geo-account
        - name: GEO_KEY
          valueFrom:
            secretKeyRef:
              name: measure-js-secrets
              key: geo-key
        - name: DAILY_SALT
          valueFrom:
            secretKeyRef:
              name: measure-js-secrets
              key: daily-salt
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: measure-js-service
spec:
  selector:
    app: measure-js
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: LoadBalancer
```

## Monitoring and Logging

### Health Checks

```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

# View health check logs
docker inspect --format='{{json .State.Health}}' measure-js
```

### Logging

```bash
# View application logs
docker logs measure-js

# Follow logs in real-time
docker logs -f measure-js

# View logs with timestamps
docker logs -t measure-js

# View last 100 lines
docker logs --tail 100 measure-js
```

### Metrics

```bash
# Container resource usage
docker stats measure-js

# Detailed container info
docker inspect measure-js
```

## Security Best Practices

### 1. Image Security

```bash
# Scan for vulnerabilities
docker scan measure-js:latest

# Use specific base image tags
FROM oven/bun:1.0.35-slim
```

### 2. Runtime Security

```yaml
# Run as non-root user
USER measurejs

# Read-only root filesystem
security_opt:
  - no-new-privileges:true
read_only: true
tmpfs:
  - /tmp
```

### 3. Network Security

```yaml
# Use custom networks
networks:
  measure-network:
    driver: bridge
    internal: true  # No external access
```

### 4. Secrets Management

```bash
# Use Docker secrets
echo "your-secret" | docker secret create measure-js-secret -

# Or use environment files
docker run --env-file .env measure-js:latest
```

## Troubleshooting

### Common Issues

**Container won't start:**
```bash
# Check container logs
docker logs measure-js

# Check resource limits
docker stats measure-js

# Verify environment variables
docker exec measure-js env
```

**Health check failures:**
```bash
# Test health endpoint manually
docker exec measure-js curl -f http://localhost:3000/health

# Check application logs
docker logs measure-js
```

**Performance issues:**
```bash
# Monitor resource usage
docker stats measure-js

# Check container limits
docker inspect measure-js | grep -A 10 "HostConfig"
```

### Debug Commands

```bash
# Enter running container
docker exec -it measure-js /bin/sh

# Check application status
docker exec measure-js ps aux

# Test network connectivity
docker exec measure-js curl -I http://localhost:3000/health
```

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/docker-deploy.yml`:

```yaml
name: Docker Deploy

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Build Docker image
      run: docker build -t measure-js:${{ github.sha }} .

    - name: Push to registry
      run: |
        docker tag measure-js:${{ github.sha }} your-registry/measure-js:${{ github.sha }}
        docker push your-registry/measure-js:${{ github.sha }}

    - name: Deploy to production
      run: |
        docker-compose -f docker-compose.prod.yml pull
        docker-compose -f docker-compose.prod.yml up -d
```

---

**Need help?** Check the [Cloud Deployment](./cloud.md) guide or [contact support](mailto:support@9fwr.com).

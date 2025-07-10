# Production Deployment Guide

This guide covers deploying Measure.js to production environments with best practices for security, performance, and reliability.

## 🚀 Deployment Options

### 1. Docker Deployment (Recommended)

The most flexible and portable deployment option.

#### Prerequisites

- Docker installed on your server
- Environment variables configured
- Domain name and SSL certificate

#### Deployment Steps

```bash
# 1. Build the production image
docker build -t measure-js:latest .

# 2. Create a production .env file
cat > .env.prod << EOF
# Google Cloud Platform
GCP_PROJECT_ID=your-production-project
GCP_DATASET_ID=analytics
GCP_TABLE_ID=events

# MaxMind GeoIP2
GEO_ACCOUNT=your-maxmind-account
GEO_KEY=your-maxmind-license-key

# Security
DAILY_SALT=your-secure-production-salt

# CORS
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100

# Environment
NODE_ENV=production
PORT=3000
EOF

# 3. Run the container
docker run -d \
  --name measure-js \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file .env.prod \
  measure-js:latest
```

#### Docker Compose (Recommended for Production)

```yaml
# docker-compose.yml
version: '3.8'

services:
  measure-js:
    build: .
    container_name: measure-js
    restart: unless-stopped
    ports:
      - "3000:3000"
    env_file:
      - .env.prod
    environment:
      - NODE_ENV=production
    volumes:
      - ./logs:/app/logs
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

```bash
# Deploy with Docker Compose
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f measure-js
```

### 2. Google Cloud Platform

#### Cloud Run Deployment

```bash
# 1. Set up Google Cloud CLI
gcloud auth login
gcloud config set project your-project-id

# 2. Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# 3. Deploy to Cloud Run
gcloud run deploy measure-js \
  --source . \
  --platform managed \
  --region europe-west3 \
  --allow-unauthenticated \
  --set-env-vars="GCP_PROJECT_ID=your-project-id" \
  --set-env-vars="GCP_DATASET_ID=analytics" \
  --set-env-vars="GCP_TABLE_ID=events" \
  --set-env-vars="GEO_ACCOUNT=your-maxmind-account" \
  --set-env-vars="GEO_KEY=your-maxmind-license-key" \
  --set-env-vars="DAILY_SALT=your-secure-salt" \
  --set-env-vars="CORS_ORIGIN=https://yourdomain.com" \
  --set-env-vars="RATE_LIMIT_WINDOW_MS=60000" \
  --set-env-vars="RATE_LIMIT_MAX_REQUESTS=100" \
  --max-instances=10 \
  --memory=512Mi \
  --cpu=1 \
  --timeout=30 \
  --concurrency=80
```

#### Cloud Run with Custom Domain

```bash
# 1. Map custom domain
gcloud run domain-mappings create \
  --service measure-js \
  --domain analytics.yourdomain.com \
  --region europe-west3

# 2. Update DNS records
# Add CNAME record: analytics.yourdomain.com -> ghs.googlehosted.com
```

#### Cloud Run with Load Balancer

```bash
# 1. Create load balancer
gcloud compute backend-services create measure-js-backend \
  --global \
  --load-balancing-scheme=EXTERNAL_MANAGED

# 2. Add Cloud Run backend
gcloud compute backend-services add-backend measure-js-backend \
  --global \
  --service=measure-js \
  --region=europe-west3

# 3. Create URL map
gcloud compute url-maps create measure-js-lb \
  --default-service measure-js-backend

# 4. Create HTTPS proxy
gcloud compute target-https-proxies create measure-js-https-proxy \
  --url-map=measure-js-lb \
  --ssl-certificates=your-ssl-cert

# 5. Create forwarding rule
gcloud compute forwarding-rules create measure-js-https \
  --global \
  --target-https-proxy=measure-js-https-proxy \
  --ports=443
```

### 3. Kubernetes Deployment

#### Basic Kubernetes Deployment

```yaml
# k8s/deployment.yaml
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
        - name: GCP_PROJECT_ID
          value: "your-project-id"
        - name: GCP_DATASET_ID
          value: "analytics"
        - name: GCP_TABLE_ID
          value: "events"
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
        - name: CORS_ORIGIN
          value: "https://yourdomain.com"
        - name: RATE_LIMIT_WINDOW_MS
          value: "60000"
        - name: RATE_LIMIT_MAX_REQUESTS
          value: "100"
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
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
---
apiVersion: v1
kind: Secret
metadata:
  name: measure-js-secrets
type: Opaque
data:
  geo-account: <base64-encoded-account>
  geo-key: <base64-encoded-key>
  daily-salt: <base64-encoded-salt>
```

```bash
# Deploy to Kubernetes
kubectl apply -f k8s/deployment.yaml

# Check deployment status
kubectl get pods -l app=measure-js

# View logs
kubectl logs -l app=measure-js -f
```

### 4. Traditional Server Deployment

#### System Requirements

- Ubuntu 20.04+ or CentOS 8+
- Node.js 18+ or Bun 1.0+
- 2GB RAM minimum
- 10GB disk space

#### Installation Steps

```bash
# 1. Install Bun
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# 2. Clone repository
git clone https://github.com/your-repo/measure-js.git
cd measure-js

# 3. Install dependencies
bun install

# 4. Build application
bun run build

# 5. Set up environment
cp example.env .env
# Edit .env with production values

# 6. Set up PM2 for process management
npm install -g pm2

# 7. Create PM2 ecosystem file
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'measure-js',
    script: 'bun',
    args: 'run src/api/index.ts',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    env_file: '.env',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
EOF

# 8. Start application
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

#### Nginx Configuration

```nginx
# /etc/nginx/sites-available/measure-js
server {
    listen 80;
    server_name analytics.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name analytics.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/analytics.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/analytics.yourdomain.com/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 30s;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
    }

    # Static files
    location /static/ {
        alias /path/to/measure-js/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check
    location /health {
        access_log off;
        proxy_pass http://localhost:3000/health;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/measure-js /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 🔒 Security Configuration

### 1. Environment Variables

```bash
# Generate secure salt
openssl rand -hex 32

# Set up production environment
cat > .env.prod << EOF
# Google Cloud Platform
GCP_PROJECT_ID=your-production-project
GCP_DATASET_ID=analytics
GCP_TABLE_ID=events

# MaxMind GeoIP2
GEO_ACCOUNT=your-maxmind-account
GEO_KEY=your-maxmind-license-key

# Security
DAILY_SALT=your-generated-secure-salt
CLIENT_ID_COOKIE_NAME=_ms_cid
HASH_COOKIE_NAME=_ms_h
COOKIE_DOMAIN=.yourdomain.com

# CORS
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_SKIP_SUCCESS=false
RATE_LIMIT_SKIP_FAILED=false

# Environment
NODE_ENV=production
PORT=3000
REGION=europe-west3
SERVICE_NAME=measure-js-app
EOF
```

### 2. SSL/TLS Configuration

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d analytics.yourdomain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### 3. Firewall Configuration

```bash
# UFW firewall setup
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 4. Security Headers

```nginx
# Add to Nginx configuration
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';";
```

## 📊 Monitoring & Observability

### 1. Application Monitoring

#### Health Checks

```bash
# Basic health check
curl -f http://localhost:3000/health

# Detailed health check
curl -f http://localhost:3000/health | jq

# Automated monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
ENDPOINT="http://localhost:3000/health"
LOG_FILE="/var/log/measure-js-health.log"

while true; do
    if curl -f -s "$ENDPOINT" > /dev/null; then
        echo "$(date): OK" >> "$LOG_FILE"
    else
        echo "$(date): FAILED" >> "$LOG_FILE"
        # Send alert
        echo "Measure.js health check failed" | mail -s "Alert" admin@yourdomain.com
    fi
    sleep 60
done
EOF

chmod +x monitor.sh
nohup ./monitor.sh &
```

#### Logging

```bash
# Application logs
tail -f /var/log/measure-js/app.log

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# System logs
journalctl -u measure-js -f
```

### 2. Performance Monitoring

#### Resource Monitoring

```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Monitor system resources
htop
iotop
nethogs

# Monitor disk usage
df -h
du -sh /var/log/measure-js/
```

#### Application Metrics

```bash
# Monitor request rates
watch -n 1 "tail -n 100 /var/log/nginx/access.log | grep -c 'POST /events'"

# Monitor error rates
watch -n 1 "tail -n 100 /var/log/nginx/access.log | grep -c ' 5[0-9][0-9] '"

# Monitor response times
tail -f /var/log/nginx/access.log | awk '{print $10}' | sort -n
```

### 3. Data Pipeline Monitoring

```bash
# Check BigQuery data flow
bq query --use_legacy_sql=false "
  SELECT
    DATE(timestamp) as date,
    COUNT(*) as events,
    COUNT(DISTINCT client_id) as unique_users
  FROM \`your-project.analytics.events\`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  GROUP BY 1
  ORDER BY 1
"

# Monitor dbt pipeline
cd data/dbt/measure_js
dbt run --models core+
dbt test
dbt docs generate
```

## 🔄 Backup & Recovery

### 1. Application Backup

```bash
# Backup application files
tar -czf measure-js-backup-$(date +%Y%m%d).tar.gz \
  --exclude=node_modules \
  --exclude=.git \
  --exclude=logs \
  .

# Backup environment configuration
cp .env .env.backup-$(date +%Y%m%d)

# Backup logs
tar -czf logs-backup-$(date +%Y%m%d).tar.gz logs/
```

### 2. Database Backup

```bash
# Export BigQuery data (if needed)
bq extract your-project:analytics.events gs://your-backup-bucket/events-$(date +%Y%m%d).json

# Backup dbt models
tar -czf dbt-backup-$(date +%Y%m%d).tar.gz data/dbt/
```

### 3. Recovery Procedures

```bash
# Restore application
tar -xzf measure-js-backup-YYYYMMDD.tar.gz
cp .env.backup-YYYYMMDD .env

# Restart application
pm2 restart measure-js
# or
docker-compose restart measure-js
# or
kubectl rollout restart deployment/measure-js
```

## 🚨 Troubleshooting

### Common Issues

#### 1. High Memory Usage

```bash
# Check memory usage
free -h
ps aux --sort=-%mem | head -10

# Restart application
pm2 restart measure-js
```

#### 2. High CPU Usage

```bash
# Check CPU usage
top
htop

# Check for rate limiting issues
tail -f /var/log/nginx/access.log | grep " 429 "
```

#### 3. Database Connection Issues

```bash
# Test BigQuery connection
bq query --use_legacy_sql=false "SELECT 1"

# Check service account permissions
gcloud auth list
gcloud config get-value project
```

#### 4. SSL Certificate Issues

```bash
# Check certificate expiration
openssl x509 -in /etc/letsencrypt/live/analytics.yourdomain.com/cert.pem -text -noout | grep "Not After"

# Renew certificate
sudo certbot renew --dry-run
```

### Performance Optimization

#### 1. Application Optimization

```bash
# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=2048"

# Optimize Bun runtime
export BUN_OPTIONS="--max-old-space-size=2048"
```

#### 2. Nginx Optimization

```nginx
# Add to nginx.conf
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
gzip on;
gzip_types text/plain text/css application/json application/javascript;
```

#### 3. Database Optimization

```sql
-- Optimize BigQuery queries
SELECT
  DATE(timestamp) as date,
  COUNT(*) as events
FROM `your-project.analytics.events`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY 1
ORDER BY 1;
```

## 📈 Scaling

### 1. Horizontal Scaling

#### Docker Swarm

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml measure-js
```

#### Kubernetes Scaling

```bash
# Scale deployment
kubectl scale deployment measure-js --replicas=5

# Auto-scaling
kubectl autoscale deployment measure-js --cpu-percent=70 --min=2 --max=10
```

### 2. Load Balancing

```nginx
# Nginx upstream configuration
upstream measure-js {
    least_conn;
    server 127.0.0.1:3001;
    server 127.0.0.1:3002;
    server 127.0.0.1:3003;
    server 127.0.0.1:3004;
}
```

### 3. Database Scaling

```sql
-- Partition BigQuery table by date
CREATE TABLE `your-project.analytics.events_partitioned`
PARTITION BY DATE(timestamp)
AS SELECT * FROM `your-project.analytics.events`;
```

## 📋 Deployment Checklist

### Pre-Deployment

- [ ] Environment variables configured
- [ ] SSL certificate installed
- [ ] Firewall configured
- [ ] Monitoring set up
- [ ] Backup strategy in place
- [ ] DNS records updated
- [ ] Load testing completed

### Post-Deployment

- [ ] Health checks passing
- [ ] SSL certificate valid
- [ ] Rate limiting working
- [ ] CORS configuration correct
- [ ] Data flowing to BigQuery
- [ ] dbt pipeline running
- [ ] Monitoring alerts configured
- [ ] Documentation updated

### Ongoing Maintenance

- [ ] Regular security updates
- [ ] SSL certificate renewal
- [ ] Log rotation
- [ ] Performance monitoring
- [ ] Backup verification
- [ ] Dependency updates

---

**Need help with deployment?** Check the [deployment scripts](../infrastructure/scripts/) or [contact support](mailto:support@9fwr.com).

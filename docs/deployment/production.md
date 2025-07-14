# Production Deployment Guide

This guide covers deploying Measure.js to production environments on Google Cloud Platform with best practices for security, performance, and reliability.

## 🚀 Deployment Options

### 1. Google Cloud Platform (Recommended)

The most scalable and cost-effective deployment option using Google Cloud services.

#### Prerequisites

- Google Cloud Platform account with billing enabled
- Google Cloud CLI (`gcloud`) installed and authenticated
- MaxMind GeoIP2 account for geolocation
- Domain name (optional, for custom domain)

#### Quick Deployment

```bash
# 1. Clone and setup
git clone https://github.com/your-repo/measure-js.git
cd measure-js

# 2. Configure environment
cp example.env .env
# Edit .env with your production settings

# 3. Deploy to production
./deploy.sh
```

The `deploy.sh` script provides a convenient way to deploy Measure.js with comprehensive validation and error handling. It supports several deployment options:

```bash
# Deploy everything (recommended)
./deploy.sh

# Deploy only the main application
./deploy.sh --app-only

# Deploy only the dbt data pipeline
./deploy.sh --dbt-only

# Get help and usage information
./deploy.sh --help
```

**Features of the deployment script:**
- ✅ **Prerequisites validation** (gcloud, authentication, environment)
- ✅ **Environment validation** (required variables, configuration)
- ✅ **Flexible deployment** (app only, dbt only, or both)
- ✅ **Comprehensive logging** (all activity logged to `deploy.log`)
- ✅ **Error handling** (clear error messages with actionable steps)
- ✅ **Success guidance** (next steps after deployment)

#### Manual Cloud Run Deployment

```bash
# 1. Set up Google Cloud CLI
gcloud auth login
gcloud config set project your-project-id

# 2. Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable bigquery.googleapis.com

# 3. Deploy to Cloud Run
gcloud run deploy measure-js-app \
  --source . \
  --platform managed \
  --region europe-west3 \
  --allow-unauthenticated \
  --set-env-vars="GCP_PROJECT_ID=your-project-id" \
  --set-env-vars="GCP_DATASET_ID=measure_js_analytics" \
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
  --service measure-js-app \
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
  --service=measure-js-app \
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

### 2. Docker Deployment

For containerized deployment on any platform.

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
GCP_DATASET_ID=measure_js_analytics
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

### 3. Kubernetes Deployment

For production orchestration on Kubernetes.

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
          value: "measure_js_analytics"
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
```

## 🚀 Automated Deployment Script

The `deploy.sh` script provides a streamlined deployment experience with comprehensive validation and error handling.

### Script Features

- **Prerequisites Validation**: Checks gcloud installation, authentication, and project configuration
- **Environment Validation**: Verifies all required environment variables are set
- **Flexible Deployment**: Supports deploying app only, dbt only, or both
- **Comprehensive Logging**: All deployment activity logged to `deploy.log`
- **Error Handling**: Clear error messages with actionable steps
- **Success Guidance**: Provides next steps after successful deployment

### Usage

```bash
# Deploy everything (recommended for first-time setup)
./deploy.sh

# Deploy only the main application
./deploy.sh --app-only

# Deploy only the dbt data pipeline
./deploy.sh --dbt-only

# Get help and usage information
./deploy.sh --help
```

### Prerequisites

Before running the deployment script, ensure:

1. **Google Cloud CLI installed and authenticated**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Environment configured**
   ```bash
   cp example.env .env
   # Edit .env with your production settings
   ```

3. **Required environment variables set**
   - `GCP_PROJECT_ID`
   - `GCP_DATASET_ID`
   - `GCP_TABLE_ID`
   - `GEO_ACCOUNT`
   - `GEO_KEY`
   - `DAILY_SALT`

### Deployment Process

The script performs the following steps:

1. **Validation**: Checks prerequisites and environment configuration
2. **Planning**: Shows what will be deployed
3. **Deployment**: Runs the appropriate deployment scripts
4. **Verification**: Confirms successful deployment
5. **Guidance**: Provides next steps

### Logging

All deployment activity is logged to `deploy.log` in the project root:

```bash
# View deployment logs
tail -f deploy.log

# View recent deployment activity
tail -n 50 deploy.log
```

### Troubleshooting

If the deployment script fails:

1. **Check prerequisites**: Ensure gcloud is installed and authenticated
2. **Verify environment**: Check that all required variables are set in `.env`
3. **Review logs**: Check `deploy.log` for detailed error information
4. **Manual deployment**: Use the individual deployment scripts if needed

```bash
# Manual deployment if script fails
./infrastructure/scripts/deploy_app.sh
./infrastructure/scripts/deploy_dbt_job.sh
```

## 🔧 Environment Configuration

### Required Environment Variables

```env
# Google Cloud Platform
GCP_PROJECT_ID=your-project-id
GCP_DATASET_ID=measure_js_analytics
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
REGION=europe-west3
```

### Optional Environment Variables

```env
# Cookie Settings
CLIENT_ID_COOKIE_NAME=_ms_cid
HASH_COOKIE_NAME=_ms_h
COOKIE_DOMAIN=.yourdomain.com

# Service Configuration
SERVICE_NAME=measure-js-app
PORT=3000

# Advanced Rate Limiting
RATE_LIMIT_SKIP_SUCCESS=true
RATE_LIMIT_SKIP_FAILED=false
```

## 🔒 Security Configuration

### CORS Settings

Configure CORS to allow your domains:

```env
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com,https://app.yourdomain.com
```

### Rate Limiting

Adjust rate limiting based on your traffic:

```env
# Conservative (100 requests per minute)
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100

# Aggressive (1000 requests per minute)
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=1000
```

### SSL/TLS

For custom domains, ensure SSL certificates are properly configured:

```bash
# Cloud Run automatically handles SSL
# For custom domains, follow Google Cloud documentation
```

## 📊 Monitoring & Observability

### Health Checks

The application provides health check endpoints:

```bash
# Basic health check
curl https://your-app-name-xyz123-ez.a.run.app/health

# Detailed health check
curl https://your-app-name-xyz123-ez.a.run.app/health/detailed
```

### Logging

View application logs:

```bash
# Cloud Run logs
gcloud run services logs read measure-js-app --region=europe-west3 --limit=50

# Follow logs in real-time
gcloud run services logs tail measure-js-app --region=europe-west3
```

### Monitoring

Set up monitoring and alerting:

```bash
# Create monitoring dashboard
gcloud monitoring dashboards create --config=dashboard.yaml

# Set up alerts for errors
gcloud alpha monitoring policies create --policy-from-file=alert-policy.yaml
```

## 🔧 Performance Optimization

### Cloud Run Configuration

Optimize Cloud Run settings for your traffic:

```bash
# High traffic (1000+ requests/minute)
gcloud run services update measure-js-app \
  --max-instances=50 \
  --memory=1Gi \
  --cpu=2 \
  --concurrency=100

# Low traffic (100- requests/minute)
gcloud run services update measure-js-app \
  --max-instances=5 \
  --memory=512Mi \
  --cpu=1 \
  --concurrency=80
```

### BigQuery Optimization

Optimize BigQuery for analytics:

```sql
-- Create partitioned table for better performance
CREATE TABLE `your-project.measure_js_analytics.events_partitioned`
PARTITION BY DATE(timestamp)
AS SELECT * FROM `your-project.measure_js_analytics.events`;
```

## 🚀 Scaling

### Auto-scaling

Cloud Run automatically scales based on traffic:

- **Min instances**: 0 (cost-effective)
- **Max instances**: 10-100 (based on traffic)
- **Concurrency**: 80-100 requests per instance

### Manual Scaling

For predictable traffic patterns:

```bash
# Set minimum instances for consistent performance
gcloud run services update measure-js-app \
  --min-instances=2 \
  --max-instances=20
```

## 🔧 Troubleshooting

### Common Issues

**Deployment fails with permission errors?**
```bash
# Check your GCP authentication
gcloud auth list

# Ensure you have the required roles
gcloud projects get-iam-policy your-project-id \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"
```

**Events not appearing in BigQuery?**
- Check service account permissions
- Verify BigQuery dataset and table exist
- Check Cloud Run logs for errors

**CORS errors in browser?**
- Ensure your domain is in the CORS origins list
- Check that the endpoint URL is correct
- Verify Cloud Run service is accessible

**High latency?**
- Check Cloud Run region proximity
- Optimize BigQuery queries
- Review rate limiting settings

### Debug Mode

Enable debug logging:

```env
NODE_ENV=production
LOG_LEVEL=debug
```

## 📋 Production Checklist

Before going live, ensure:

- ✅ [ ] Environment variables are properly configured
- ✅ [ ] CORS origins include your production domains
- ✅ [ ] Rate limiting is appropriate for your traffic
- ✅ [ ] MaxMind GeoIP2 credentials are valid
- ✅ [ ] BigQuery dataset and tables are created
- ✅ [ ] Cloud Run service is accessible
- ✅ [ ] SSL certificates are configured (if using custom domain)
- ✅ [ ] Monitoring and alerting are set up
- ✅ [ ] Backup and disaster recovery procedures are in place
- ✅ [ ] Performance testing has been completed
- ✅ [ ] Security audit has been performed

## 📞 Support

- **[Documentation](docs/README.md)** - Comprehensive guides
- **[GitHub Issues](https://github.com/your-repo/measure-js/issues)** - Bug reports and feature requests
- **[Discussions](https://github.com/your-repo/measure-js/discussions)** - Community discussions
- **[Email Support](mailto:support@9fwr.com)** - Direct support

---

**Need more help?** Check out the [full documentation](../README.md) or [contact support](mailto:support@9fwr.com).

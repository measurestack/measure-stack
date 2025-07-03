# Deploying dbt as a Cloud Run Job

This guide explains how to deploy dbt as a Cloud Run job for scheduled data processing of your Measure-JS analytics data.

## Overview

The dbt Cloud Run job will:
- **Transform raw events** from your tracking API into analytics-ready tables
- **Run on a schedule** (configurable via Cloud Scheduler)
- **Use the same BigQuery dataset** as your tracking API
- **Process data incrementally** for efficiency

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Measure-JS    │    │   Cloud Run     │    │   BigQuery      │
│   Tracking API  │───▶│   dbt Job       │───▶│   Analytics     │
│                 │    │                 │    │   Tables        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │ Cloud Scheduler │
                       │ (Hourly runs)   │
                       └─────────────────┘
```

## Deployment Options

### Option 1: Deploy with Main App (Recommended)

When running the main deployment script, you'll be prompted to deploy dbt:

```bash
./infrastructure/scripts/deploy_app.sh
```

The script will ask: `Deploy dbt as a Cloud Run job for scheduled data processing? [y/N]`

### Option 2: Deploy Separately

Deploy dbt job independently:

```bash
./infrastructure/scripts/deploy_dbt_job.sh
```

**Note**: The dbt Dockerfile is located in `data/dbt/Dockerfile.dbt` and will be built from the project root.

## Configuration

### Environment Variables

The dbt job uses these environment variables:

```bash
GCP_PROJECT_ID=ga4-9fwr
GCP_DATASET_ID=measure_js_analytics
REGION=europe-west3
DBT_TARGET=prod
```

### Service Account Permissions

The dbt job service account has:
- `roles/bigquery.dataEditor` - Read/write BigQuery data
- `roles/bigquery.jobUser` - Run BigQuery jobs

## Scheduling

### Default Schedule
- **Frequency**: Every hour at minute 0
- **Cron**: `0 * * * *`
- **Example**: 1:00, 2:00, 3:00, etc.

### Custom Schedule

To change the schedule, edit the scheduler job:

```bash
# View current schedule
gcloud scheduler jobs describe measure-dbt-scheduler --location=europe-west3

# Update schedule (e.g., every 30 minutes)
gcloud scheduler jobs update http measure-dbt-scheduler \
    --schedule="*/30 * * * *" \
    --location=europe-west3
```

## Manual Execution

### Trigger Job Manually

```bash
./infrastructure/scripts/trigger_dbt_job.sh
```

Or use gcloud directly:

```bash
gcloud run jobs execute measure-dbt-job --region=europe-west3 --wait
```

### View Logs

```bash
# Recent logs
gcloud run jobs logs read measure-dbt-job --region=europe-west3 --limit=50

# Follow logs in real-time
gcloud run jobs logs tail measure-dbt-job --region=europe-west3
```

## Monitoring

### Cloud Console
1. Go to [Cloud Run Jobs](https://console.cloud.google.com/run/jobs)
2. Select `measure-dbt-job`
3. View execution history and logs

### Cloud Logging
```bash
# View logs in Cloud Logging
gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=measure-dbt-job" --limit=50
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Check service account permissions
   gcloud projects get-iam-policy ga4-9fwr \
       --flatten="bindings[].members" \
       --filter="bindings.members:serviceAccount:measure-dbt-sa@ga4-9fwr.iam.gserviceaccount.com"
   ```

2. **Job Timeout**
   - Increase timeout: `--task-timeout="3600s"`
   - Check for long-running queries in BigQuery

3. **Memory Issues**
   - Increase memory: `--memory="4Gi"`
   - Optimize dbt models for efficiency

### Debug Mode

Run dbt in debug mode locally:

```bash
cd data/dbt/measure_js
dbt debug --profiles-dir ..
dbt run --target prod --profiles-dir ..
```

## Data Flow

1. **Raw Events** → Stored in `measure_js_analytics.events`
2. **dbt Staging** → `measure_js_analytics.staging.*`
3. **dbt Core** → `measure_js_analytics.core.*`
4. **dbt Mart** → `measure_js_analytics.mart.*`

## Cost Optimization

- **Scheduling**: Run less frequently during low-traffic periods
- **Timeout**: Set appropriate timeouts to avoid unnecessary charges
- **Memory**: Use minimum required memory
- **Incremental Models**: Use dbt incremental models for efficiency

## Next Steps

After deployment:
1. **Monitor first few runs** to ensure everything works
2. **Set up alerts** for job failures
3. **Create dashboards** using the transformed data
4. **Optimize models** based on usage patterns

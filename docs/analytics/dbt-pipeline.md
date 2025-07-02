# dbt Data Pipeline

The Measure.js dbt pipeline transforms raw event data from BigQuery into clean, analytics-ready datasets. This document covers the data transformation process, models, and how to use the analytics data.

## Overview

The dbt pipeline processes raw events from the `events` table and creates several layers of transformed data:

- **Staging**: Cleaned and validated raw data
- **Core**: Business logic and user/session identification
- **Mart**: Analytics-ready aggregated tables

## Pipeline Architecture

```
Raw Events (BigQuery)
       ↓
   Staging Layer
       ↓
    Core Layer
       ↓
    Mart Layer
       ↓
  Analytics Dashboards
```

## Setup

### Prerequisites

- dbt Core or dbt Cloud
- BigQuery access
- Python 3.8+

### Installation

```bash
# Navigate to dbt project
cd data/dbt/measure_js

# Install dbt
pip install dbt-bigquery

# Install dependencies
dbt deps

# Configure profile
cp profiles.yml.example profiles.yml
```

### Configuration

Edit `profiles.yml`:

```yaml
dbt_measure_js:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: your-gcp-project
      dataset: analytics_dev
      location: US
      keyfile: /path/to/service-account-key.json
      threads: 4
      timeout_seconds: 300
    prod:
      type: bigquery
      method: service-account
      project: your-gcp-project
      dataset: analytics
      location: US
      keyfile: /path/to/service-account-key.json
      threads: 8
      timeout_seconds: 300
```

## Data Models

### Staging Models

#### `staging.event_blocks`

Groups events into time blocks for efficient processing.

```sql
-- models/staging/event_blocks.sql
SELECT
  DATE(timestamp) as date,
  HOUR(timestamp) as hour,
  TIMESTAMP_TRUNC(timestamp, HOUR) as hour_block,
  COUNT(*) as event_count
FROM {{ source('raw', 'events') }}
GROUP BY 1, 2, 3
```

#### `staging.events_sessionated`

Adds session information to events.

```sql
-- models/staging/events_sessionated.sql
SELECT
  *,
  CASE
    WHEN TIMESTAMP_DIFF(timestamp, LAG(timestamp) OVER (
      PARTITION BY client_id ORDER BY timestamp
    ), MINUTE) > 30 THEN 1
    ELSE 0
  END as new_session,
  SUM(CASE
    WHEN TIMESTAMP_DIFF(timestamp, LAG(timestamp) OVER (
      PARTITION BY client_id ORDER BY timestamp
    ), MINUTE) > 30 THEN 1
    ELSE 0
  END) OVER (
    PARTITION BY client_id ORDER BY timestamp
  ) as session_number
FROM {{ ref('events_cleaned') }}
```

#### `staging.user_map`

Maps client IDs to user IDs for authenticated users.

```sql
-- models/staging/user_map.sql
SELECT
  client_id,
  user_id,
  MIN(timestamp) as first_seen,
  MAX(timestamp) as last_seen
FROM {{ source('raw', 'events') }}
WHERE user_id IS NOT NULL
GROUP BY 1, 2
```

### Core Models

#### `core.users`

User-level analytics with engagement metrics.

```sql
-- models/core/users.sql
SELECT
  client_id,
  user_id,
  MIN(timestamp) as first_seen,
  MAX(timestamp) as last_seen,
  COUNT(DISTINCT DATE(timestamp)) as days_active,
  COUNT(*) as total_events,
  COUNT(DISTINCT session_id) as total_sessions,
  AVG(session_duration) as avg_session_duration
FROM {{ ref('events_sessionated') }}
GROUP BY 1, 2
```

#### `core.sessions`

Session-level analytics with detailed session information.

```sql
-- models/core/sessions.sql
SELECT
  session_id,
  client_id,
  user_id,
  MIN(timestamp) as session_start,
  MAX(timestamp) as session_end,
  TIMESTAMP_DIFF(MAX(timestamp), MIN(timestamp), SECOND) as session_duration,
  COUNT(*) as pageviews,
  COUNT(DISTINCT url) as unique_pages,
  ARRAY_AGG(DISTINCT event_name) as events
FROM {{ ref('events_sessionated') }}
GROUP BY 1, 2, 3
```

#### `core.clients`

Client-level analytics for anonymous users.

```sql
-- models/core/clients.sql
SELECT
  client_id,
  MIN(timestamp) as first_seen,
  MAX(timestamp) as last_seen,
  COUNT(DISTINCT DATE(timestamp)) as days_active,
  COUNT(*) as total_events,
  COUNT(DISTINCT session_id) as total_sessions
FROM {{ ref('events_sessionated') }}
WHERE user_id IS NULL
GROUP BY 1
```

### Mart Models

#### `mart.daily_performance`

Daily aggregated metrics for dashboard reporting.

```sql
-- models/mart/daily_performance.sql
SELECT
  DATE(timestamp) as date,
  COUNT(DISTINCT client_id) as daily_active_users,
  COUNT(DISTINCT user_id) as daily_active_registered_users,
  COUNT(DISTINCT session_id) as total_sessions,
  COUNT(*) as total_events,
  COUNT(CASE WHEN event_name = 'pageview' THEN 1 END) as pageviews,
  AVG(session_duration) as avg_session_duration
FROM {{ ref('events_sessionated') }}
GROUP BY 1
ORDER BY 1
```

## Running the Pipeline

### Development

```bash
# Run all models
dbt run

# Run specific model
dbt run --select staging.events_sessionated

# Run models with dependencies
dbt run --select +mart.daily_performance

# Run with full refresh
dbt run --full-refresh
```

### Testing

```bash
# Run all tests
dbt test

# Run specific test
dbt test --select test_name

# Run data quality tests
dbt test --select tag:data_quality
```

### Documentation

```bash
# Generate documentation
dbt docs generate

# Serve documentation
dbt docs serve
```

## Data Quality

### Tests

The pipeline includes comprehensive data quality tests:

```yaml
# models/schema.yml
version: 2

models:
  - name: events_sessionated
    description: "Events with session information"
    columns:
      - name: client_id
        description: "Unique client identifier"
        tests:
          - not_null
          - unique

      - name: timestamp
        description: "Event timestamp"
        tests:
          - not_null
          - dbt_utils.is_timestamp

      - name: session_id
        description: "Session identifier"
        tests:
          - not_null
```

### Custom Tests

```sql
-- tests/assert_positive_session_duration.sql
SELECT
  session_id,
  session_duration
FROM {{ ref('sessions') }}
WHERE session_duration < 0
```

## Analytics Queries

### User Engagement

```sql
-- Daily Active Users
SELECT
  date,
  daily_active_users,
  LAG(daily_active_users) OVER (ORDER BY date) as prev_day_users,
  (daily_active_users - LAG(daily_active_users) OVER (ORDER BY date)) /
    LAG(daily_active_users) OVER (ORDER BY date) * 100 as growth_pct
FROM {{ ref('daily_performance') }}
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY date;
```

### Session Analysis

```sql
-- Session Duration Distribution
SELECT
  CASE
    WHEN session_duration < 60 THEN '0-1 min'
    WHEN session_duration < 300 THEN '1-5 min'
    WHEN session_duration < 900 THEN '5-15 min'
    WHEN session_duration < 3600 THEN '15-60 min'
    ELSE '60+ min'
  END as duration_bucket,
  COUNT(*) as session_count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
FROM {{ ref('sessions') }}
WHERE session_start >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY 1
ORDER BY session_count DESC;
```

### Page Performance

```sql
-- Top Pages by Views
SELECT
  url,
  COUNT(*) as pageviews,
  COUNT(DISTINCT client_id) as unique_visitors,
  COUNT(*) / COUNT(DISTINCT client_id) as avg_views_per_visitor
FROM {{ ref('events_sessionated') }}
WHERE event_name = 'pageview'
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY 1
ORDER BY pageviews DESC
LIMIT 20;
```

### Geographic Analysis

```sql
-- Traffic by Country
SELECT
  location.country,
  location.country_code,
  COUNT(*) as events,
  COUNT(DISTINCT client_id) as unique_users,
  COUNT(DISTINCT session_id) as sessions
FROM {{ ref('events_sessionated') }}
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND location.country IS NOT NULL
GROUP BY 1, 2
ORDER BY events DESC;
```

## Scheduling

### dbt Cloud

Configure dbt Cloud jobs for automated runs:

```yaml
# dbt_project.yml
models:
  dbt_measure_js:
    staging:
      +materialized: view
    core:
      +materialized: table
    mart:
      +materialized: table
      +schedule: "0 2 * * *"  # Daily at 2 AM
```

### Manual Scheduling

```bash
# Create cron job
0 2 * * * cd /path/to/dbt/project && dbt run --target prod
```

## Performance Optimization

### Incremental Models

```sql
-- models/core/users_incremental.sql
{{ config(materialized='incremental') }}

SELECT
  client_id,
  user_id,
  MIN(timestamp) as first_seen,
  MAX(timestamp) as last_seen,
  COUNT(DISTINCT DATE(timestamp)) as days_active
FROM {{ ref('events_sessionated') }}

{% if is_incremental() %}
  WHERE timestamp > (SELECT MAX(last_seen) FROM {{ this }})
{% endif %}

GROUP BY 1, 2
```

### Partitioning

```sql
-- models/mart/daily_performance_partitioned.sql
{{ config(
  materialized='table',
  partition_by={
    "field": "date",
    "data_type": "date",
    "granularity": "day"
  }
) }}

SELECT * FROM {{ ref('daily_performance') }}
```

## Monitoring

### Model Performance

```sql
-- Check model run times
SELECT
  model_name,
  run_started_at,
  run_completed_at,
  TIMESTAMP_DIFF(run_completed_at, run_started_at, SECOND) as duration_seconds
FROM {{ ref('dbt_run_results') }}
ORDER BY run_started_at DESC
LIMIT 10;
```

### Data Freshness

```sql
-- Check data freshness
SELECT
  'events' as table_name,
  MAX(timestamp) as latest_record,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(timestamp), HOUR) as hours_behind
FROM {{ source('raw', 'events') }}

UNION ALL

SELECT
  'daily_performance' as table_name,
  MAX(date) as latest_record,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(date), HOUR) as hours_behind
FROM {{ ref('daily_performance') }};
```

## Troubleshooting

### Common Issues

**Model failures:**
```bash
# Check model logs
dbt run --select model_name --debug

# Validate SQL syntax
dbt compile --select model_name
```

**Performance issues:**
```sql
-- Check query performance
SELECT
  creation_time,
  query,
  total_bytes_processed,
  total_slot_ms
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
ORDER BY creation_time DESC;
```

**Data quality issues:**
```bash
# Run specific tests
dbt test --select test_name

# Check for null values
dbt run-operation check_nulls --args '{table_name: events_sessionated}'
```

## Best Practices

### 1. Model Organization

- Keep staging models simple and focused
- Use core models for business logic
- Create mart models for specific use cases

### 2. Performance

- Use incremental models for large tables
- Implement proper partitioning
- Monitor query performance regularly

### 3. Testing

- Test all critical models
- Use custom tests for business rules
- Monitor data quality metrics

### 4. Documentation

- Document all models and columns
- Include business context
- Keep documentation up to date

---

**Need help?** Check the [Data Schema](./data-schema.md) or [contact support](mailto:support@9fwr.com).

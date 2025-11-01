# End-to-End Tests

Comprehensive test suite for MeasureStack that verifies all functionality by running the server, sending requests, and checking BigQuery storage.

## Prerequisites

- `.env` file configured with your GCP credentials and settings
- BigQuery dataset created (`measure_js.events` table)
- Google Cloud authentication set up locally

## Running Tests

```bash
# Run all E2E tests
bun test tests/e2e/server.test.ts

# Run with watch mode
bun test --watch tests/e2e/server.test.ts
```

## Test Coverage

The test suite covers:

1. **Root endpoint** - Verifies server responds correctly
2. **Static file serving** - Tests `measure.js` script delivery
3. **POST events with JSON** - Tests event ingestion and BigQuery storage
4. **GET events with query params** - Tests alternative event format
5. **Consent cookie management** - Verifies GDPR cookie handling
6. **CORS protection** - Tests allowed and disallowed origins
7. **Device enrichment** - Verifies user-agent parsing
8. **Hash consistency** - Ensures stable client identification

## Configuration

Tests use environment variables from `.env`:

- `GCP_PROJECT_ID` - Your Google Cloud project
- `GCP_DATASET_ID` - BigQuery dataset (default: `measure_js`)
- `GCP_TABLE_ID` - Events table (default: `events`)
- `CORS_ORIGIN` - Allowed origins (first one used for testing)
- `TEST_URL` - Optional: test against deployed server instead of localhost

## Testing Against Production

To test a deployed instance:

```bash
TEST_URL=https://your-cloud-run-url.run.app bun test tests/e2e/server.test.ts
```

## Troubleshooting

- **BigQuery timeout errors**: Increase `jobTimeoutMs` in test file
- **CORS failures**: Check `CORS_ORIGIN` in `.env` matches test expectations
- **Server startup issues**: Ensure port 3000 is available

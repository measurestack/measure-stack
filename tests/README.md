# Test Suite Documentation

## Overview

This test suite covers the measure-js application with different types of tests:

- **Unit Tests**: Test individual functions and components in isolation
- **Integration Tests**: Test API endpoints and component interactions
- **End-to-End Tests**: Test complete user flows

## Test Structure

```
tests/
├── unit/                    # Unit tests
│   ├── utils/              # Utility function tests
│   │   ├── ipUtils.test.ts # IP address utility tests
│   │   └── crypto.test.ts  # Cryptographic utility tests
│   ├── config/             # Configuration tests
│   │   └── environment.test.ts
│   └── services/           # Service layer tests
├── integration/            # Integration tests
│   └── api/               # API endpoint tests
│       ├── events.test.ts # Event tracking endpoint tests
│       └── health.test.ts # Health check endpoint tests
└── e2e/                   # End-to-end tests
    └── basic-flow.test.ts # Complete user flow tests
```

## Running Tests

### All Tests
```bash
bun test
```

### Specific Test Types
```bash
# Unit tests only
bun test tests/unit/

# Integration tests only
bun test tests/integration/

# End-to-end tests only
bun test tests/e2e/
```

### Watch Mode
```bash
bun test --watch
```

## Test Coverage

### Unit Tests ✅
- **IP Utilities**: IPv4/IPv6 truncation, client IP detection, IP sanitization
- **Crypto Utilities**: Hash generation, consistent hashing
- **Environment Configuration**: Config structure validation

### Integration Tests ⚠️
- **Health Endpoint**: ✅ Working correctly
- **Events Endpoint**: ⚠️ Failing due to Hono/Bun adapter issues in test environment

### End-to-End Tests ⚠️
- **Basic Flow**: ⚠️ Same adapter issues as integration tests

## Known Issues

1. **Hono/Bun Adapter**: The `getConnInfo` function from Hono's Bun adapter expects a specific environment setup that's not available in the test environment. This affects:
   - Event processing tests
   - Integration tests for the events endpoint
   - End-to-end tests

2. **Environment Variables**: Some tests may fail if environment variables are set differently than expected.

## Test Results Summary

### Passing Tests ✅
- IP utility functions (10/10)
- Crypto utility functions (6/6)
- Environment configuration structure (4/4)
- Health endpoint integration (2/2)

### Failing Tests ❌
- Event processing integration tests (4/4) - Due to Hono adapter issues
- End-to-end tests - Due to same adapter issues

## Recommendations

1. **Mock the Hono Context**: For unit tests of services that use Hono context, create proper mocks
2. **Test Environment Setup**: Set up a proper test environment that mimics the Bun runtime
3. **Separate Unit and Integration**: Keep unit tests focused on business logic without framework dependencies

## Adding New Tests

1. **Unit Tests**: Place in `tests/unit/` with descriptive names
2. **Integration Tests**: Place in `tests/integration/` for API endpoint testing
3. **E2E Tests**: Place in `tests/e2e/` for complete flow testing

### Example Unit Test
```typescript
import { describe, it, expect } from 'bun:test';
import { myFunction } from '../../src/utils/myUtils';

describe('My Utils', () => {
  it('should work correctly', () => {
    const result = myFunction('input');
    expect(result).toBe('expected output');
  });
});
```

## Test Best Practices

1. **Descriptive Names**: Use clear, descriptive test names
2. **Arrange-Act-Assert**: Structure tests with clear sections
3. **Isolation**: Each test should be independent
4. **Mocking**: Mock external dependencies appropriately
5. **Coverage**: Aim for high test coverage of business logic

#!/usr/bin/env bun

import { describe, it, expect } from 'bun:test';

// Import all test files
import './unit/utils/ipUtils.test';
import './unit/utils/crypto.test';
import './unit/config/environment.test';
import './integration/api/events.test';
import './integration/api/health.test';

console.log('🧪 Running all tests...');

// This file serves as an entry point for running all tests
// You can run it with: bun run tests/test-runner.ts

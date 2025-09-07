# Privacy and Analytics: Client IDs vs Server-Side Hashing

## Why Client IDs Are Needed for Analytics

Client IDs (cookies) enable essential analytics capabilities that would be impossible without persistent user identification:

### Session Metrics
- **Session duration and depth**: Track how long users stay engaged and how many pages they view per session
- **Session quality scoring**: Identify high-value sessions based on engagement patterns
- **Bounce rate analysis**: Measure the percentage of single-page sessions to optimize content

### User Journey Analysis
- **Multi-touch attribution**: Understand which marketing channels contribute to conversions across multiple visits
- **Funnel analysis**: Track user progression through conversion paths over time
- **Cohort analysis**: Analyze user behavior changes and retention patterns

### Cross-Visit Correlations
- **Return visitor identification**: Distinguish new vs. returning users for accurate growth metrics
- **Campaign effectiveness**: Measure long-term impact of marketing campaigns across user sessions
- **Personalization**: Deliver relevant content based on previous user interactions

## Legal Framework: Cookies vs Server-Side Hashing

### Cookies and Consent Requirements

In many jurisdictions, cookies require explicit user consent:
- **GDPR/DSGVO**: Cookies storing personal identifiers require consent under Article 6(1)(a)
- **ePrivacy Directive**: Cookies (except strictly necessary ones) require prior consent
- **User control**: Users must be able to accept/reject cookies and withdraw consent

### Server-Side Hashing: A Privacy-Friendly Alternative

Our implementation in [`eventProcessor.ts`](../src/services/tracking/eventProcessor.ts) and [`hashing.ts`](../src/utils/crypto/hashing.ts) creates privacy-compliant analytics:

#### GDPR Article 6(1)(f) - Legitimate Interest
Server-side hashes can rely on legitimate interest because:
- **Purpose limitation**: Only used for analytics, not profiling or targeting
- **Data minimization**: No personal identifiers stored or transmitted
- **Technical necessity**: Essential for basic website functionality analytics

#### Privacy-Preserving Design

Our hashing implementation ensures privacy through several mechanisms:

1. **Daily Salt Rotation**:
   ```typescript
   // From hashing.ts - salt changes daily and old salts are deleted
   const dailySalt = await getDailySalt();
   const combined = `${ip}${userAgent}${dailySalt}`;
   return createHash('sha256').update(combined).digest('hex');
   ```

2. **IP Truncation**: Only partial IP addresses are stored

3. **Server-Side Processing**: Hashing happens server-side, so raw IP/User-Agent data never leaves the server

4. **Temporal Limitation**: Daily salt rotation means hashes cannot be correlated across days

## Technical Implementation

### Event Processing Flow
The [`eventProcessor.ts`](../src/services/tracking/eventProcessor.ts) implements a dual approach:
- **With consent**: Uses persistent client ID cookies for full analytics capabilities
- **Without consent**: Uses daily-rotated server-side hashes for basic analytics

### Session Construction
The analytics pipeline in [`event_blocks.sql`](../data/dbt/measure_js/models/staging/event_blocks.sql) and [`events_sessionated.sql`](../data/dbt/measure_js/models/staging/events_sessionated.sql) handles both identification methods:

1. **Block Detection**: Groups events by 30-minute inactivity gaps
2. **ID Harmonization**: Links events within blocks using either client IDs or hashes
3. **Session Attribution**: Assigns traffic sources and campaign data to complete sessions

### Privacy Benefits of Salted Hashing

The daily salt rotation provides several privacy guarantees:
- **No cross-day tracking**: Users cannot be identified across different days
- **Collision resistance**: SHA-256 with salt prevents reverse engineering
- **Automatic expiry**: Previous day's data becomes unlinkable when salt rotates
- **GDPR compliance**: Meets data minimization and purpose limitation requirements

## Best Practices

1. **Transparent disclosure**: Clearly communicate both cookie and hash-based tracking in privacy notices
2. **User choice**: Offer granular consent options for different tracking methods
3. **Data retention**: Implement appropriate retention periods for analytics data
4. **Regular audits**: Review and validate privacy compliance of analytics implementation

This approach balances meaningful analytics insights with strong privacy protections, enabling businesses to understand user behavior while respecting privacy rights and regulatory requirements.

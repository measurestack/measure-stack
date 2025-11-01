# Privacy & GDPR Compliance

MeasureStack supports two tracking modes to comply with EU regulations (GDPR, ePrivacy Directive).

## Cookie-Based Tracking (Requires Consent)

**Legal basis:** User consent (GDPR Art. 6(1)(a), ePrivacy Directive Art. 5(3))

When users grant consent, persistent cookies enable:
- Session tracking across visits
- Return visitor identification
- Multi-visit funnel analysis
- Cohort and retention metrics

**Requirements:**
- Obtain explicit consent before setting cookies
- Allow users to withdraw consent
- Document consent in privacy policy

## Cookieless Tracking (No Consent Required)

**Legal basis:** Legitimate interest (GDPR Art. 6(1)(f))

Without consent, daily-rotated hashes provide privacy-friendly analytics:

**Hash generation:**
```
hash = SHA256(full_ip + user_agent + daily_salt)
```

**Privacy mechanisms:**
1. **Daily salt rotation** - Salt changes each day, making cross-day tracking impossible. Old salts are automatically deleted after 24 hours.
2. **Full IP for hashing only** - Full IP is used only for hash generation (with daily salt), never stored. This provides stable same-day session identification while remaining privacy-preserving due to daily salt rotation.
3. **IP truncation for storage** - Only truncated IP (last octet removed for IPv4, last 80 bits removed for IPv6) is stored in BigQuery and used for geolocation purposes
4. **Server-side only** - Raw IP never transmitted anywhere; salt never leaves server; deleted after 48h
5. **No reverse engineering** - SHA-256 with daily rotating salt is cryptographically secure and one-way

**Limitations:**
- Single-day sessions only (hash changes daily)
- Cannot track returning visitors across days
- No long-term user journey analysis

## Data Processing

**What we store:**
- Truncated IP addresses
- User-agent strings
- Page URLs and referrers
- Event names and parameters
- Country/city (from IP geolocation, optional)
- daily unique hash
- pseudonymous cookie id if consent is given

**What we don't store:**
- Full IP addresses
- Cross-site tracking data

## Compliance Recommendations

1. **Privacy Policy** - Disclose both tracking modes in your privacy policy
2. **Consent banner** - Implement cookie consent for EU visitors
3. **Data retention** - Set appropriate retention periods (recommend 14 months for raw events)
4. **Data processing agreements** - Document processor relationships if applicable
5. **PII Data** - do not submit private data like email addresses, names, payment ids/tokens with your tracking payload

**Note:** This is technical guidance, not legal advice. Consult legal counsel for compliance requirements specific to your jurisdiction and use case.

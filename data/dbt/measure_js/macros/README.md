# GA4 Event Macros Documentation

This directory contains reusable dbt macros for parsing and validating Google Analytics 4 (GA4) events in your Measure-JS analytics pipeline.

## 📁 File Structure

```
macros/
├── ga4_events.sql          # Core GA4 event parsing macros
├── ga4_validation.sql      # Validation and enrichment macros
└── README.md              # This documentation
```

## 🎯 Core Event Parsing Macros (`ga4_events.sql`)

### Ecommerce Events

#### `ga4_parse_purchase(parameters)`
Parses purchase event parameters including transaction details.

**Returns:** STRUCT with currency, value, transaction_id, coupon, shipping, tax, affiliation, shipping_tier, payment_type

**Usage:**
```sql
{{ ga4_parse_purchase('parameters') }} AS ecommerce
```

#### `ga4_parse_view_item(parameters)`
Parses view_item event parameters for product views.

**Returns:** STRUCT with item details, pricing, and categorization

**Usage:**
```sql
{{ ga4_parse_view_item('parameters') }} AS view_item_data
```

#### `ga4_parse_add_to_cart(parameters)`
Parses add_to_cart event parameters.

**Returns:** STRUCT with item details and cart information

**Usage:**
```sql
{{ ga4_parse_add_to_cart('parameters') }} AS add_to_cart_data
```

#### `ga4_parse_begin_checkout(parameters)`
Parses begin_checkout event parameters.

**Returns:** STRUCT with checkout details

**Usage:**
```sql
{{ ga4_parse_begin_checkout('parameters') }} AS begin_checkout_data
```

### User Lifecycle Events

#### `ga4_parse_sign_up(parameters)`
Parses sign_up event parameters.

**Returns:** STRUCT with signup method

**Usage:**
```sql
{{ ga4_parse_sign_up('parameters') }} AS sign_up_data
```

#### `ga4_parse_login(parameters)`
Parses login event parameters.

**Returns:** STRUCT with login method

**Usage:**
```sql
{{ ga4_parse_login('parameters') }} AS login_data
```

#### `ga4_parse_generate_lead(parameters)`
Parses generate_lead event parameters.

**Returns:** STRUCT with currency and value

**Usage:**
```sql
{{ ga4_parse_generate_lead('parameters') }} AS generate_lead_data
```

### Engagement Events

#### `ga4_parse_page_view(parameters)`
Parses page_view event parameters.

**Returns:** STRUCT with page_title, page_location, page_referrer

**Usage:**
```sql
{{ ga4_parse_page_view('parameters') }} AS page_view_data
```

#### `ga4_parse_scroll(parameters)`
Parses scroll event parameters.

**Returns:** STRUCT with percent_scrolled

**Usage:**
```sql
{{ ga4_parse_scroll('parameters') }} AS scroll_data
```

#### `ga4_parse_video_events(parameters)`
Parses video-related event parameters.

**Returns:** STRUCT with video details

**Usage:**
```sql
{{ ga4_parse_video_events('parameters') }} AS video_data
```

### Ecommerce Items

#### `ga4_parse_items(parameters, event_name)`
Parses items array for ecommerce events.

**Returns:** ARRAY of STRUCT with item details

**Usage:**
```sql
{{ ga4_parse_items('parameters', 'event_name') }} AS items
```

## 🔍 Validation & Enrichment Macros (`ga4_validation.sql`)

### Data Validation

#### `ga4_validate_currency(currency)`
Validates and standardizes currency codes.

**Returns:** Standardized currency code (defaults to 'USD')

**Usage:**
```sql
{{ ga4_validate_currency('currency_field') }} AS validated_currency
```

#### `ga4_validate_ecommerce_event(event_name, parameters)`
Validates required fields for ecommerce events.

**Returns:** BOOLEAN indicating if event is valid

**Usage:**
```sql
{{ ga4_validate_ecommerce_event('event_name', 'parameters') }} AS is_valid
```

### Data Enrichment

#### `ga4_enrich_event_category(event_name)`
Categorizes events into standard GA4 categories.

**Returns:** Event category (ecommerce, engagement, user_lifecycle, custom, other)

**Usage:**
```sql
{{ ga4_enrich_event_category('event_name') }} AS event_category
```

#### `ga4_calculate_session_value(parameters)`
Extracts and calculates session value.

**Returns:** FLOAT64 session value

**Usage:**
```sql
{{ ga4_calculate_session_value('parameters') }} AS session_value
```

### Custom Dimensions & Metrics

#### `ga4_extract_custom_dimensions(parameters, max_dimensions)`
Extracts custom dimensions from parameters.

**Usage:**
```sql
{{ ga4_extract_custom_dimensions('parameters', 10) }}
```

#### `ga4_extract_custom_metrics(parameters, max_metrics)`
Extracts custom metrics from parameters.

**Usage:**
```sql
{{ ga4_extract_custom_metrics('parameters', 10) }}
```

### User & Traffic Data

#### `ga4_parse_user_properties(parameters)`
Parses user properties from parameters.

**Returns:** STRUCT with user properties

**Usage:**
```sql
{{ ga4_parse_user_properties('parameters') }} AS user_properties
```

#### `ga4_parse_traffic_source(parameters)`
Parses traffic source information.

**Returns:** STRUCT with traffic source details

**Usage:**
```sql
{{ ga4_parse_traffic_source('parameters') }} AS traffic_source
```

#### `ga4_parse_device_category(device_type, device_brand, device_model)`
Categorizes devices into mobile/tablet/desktop.

**Returns:** Device category string

**Usage:**
```sql
{{ ga4_parse_device_category('device.type', 'device.brand', 'device.model') }} AS device_category
```

## 🚀 Implementation Example

Here's how to use these macros in your `events_sessionated.sql` model:

```sql
WITH event_ids AS (
  SELECT
    -- ... existing fields ...

    -- Use GA4 parsing macros
    {{ ga4_parse_purchase('parameters') }} AS ecommerce,
    {{ ga4_parse_view_item('parameters') }} AS view_item_data,
    {{ ga4_parse_add_to_cart('parameters') }} AS add_to_cart_data,
    {{ ga4_parse_begin_checkout('parameters') }} AS begin_checkout_data,
    {{ ga4_parse_sign_up('parameters') }} AS sign_up_data,
    {{ ga4_parse_login('parameters') }} AS login_data,
    {{ ga4_parse_generate_lead('parameters') }} AS generate_lead_data,
    {{ ga4_parse_page_view('parameters') }} AS page_view_data,
    {{ ga4_parse_scroll('parameters') }} AS scroll_data,
    {{ ga4_parse_video_events('parameters') }} AS video_data,

    -- Use validation and enrichment macros
    {{ ga4_enrich_event_category('event_name') }} AS event_category,
    {{ ga4_validate_ecommerce_event('event_name', 'parameters') }} AS is_valid_ecommerce,
    {{ ga4_calculate_session_value('parameters') }} AS session_value,
    {{ ga4_parse_device_category('device.type', 'device.brand', 'device.model') }} AS device_category,

    -- Use items parsing macro
    {{ ga4_parse_items('parameters', 'event_name') }} AS items

  FROM {{ source('measure_js','events')}}
)
```

## 📊 Benefits of Using Macros

1. **Consistency**: Standardized parsing across all models
2. **Maintainability**: Single source of truth for GA4 event logic
3. **Reusability**: Easy to apply to new models and tables
4. **Documentation**: Self-documenting code with clear macro names
5. **Testing**: Can test macros independently
6. **Flexibility**: Easy to modify parsing logic in one place

## 🔧 Customization

To customize these macros for your specific needs:

1. **Add new event types**: Create new parsing macros following the existing pattern
2. **Modify validation rules**: Update the validation macros with your business rules
3. **Extend enrichment logic**: Add new enrichment macros for your specific use cases
4. **Add custom fields**: Extend existing macros to include additional GA4 parameters

## 🧪 Testing

Test your macros using dbt's built-in testing capabilities:

```bash
# Test specific macro files
dbt test --select macro:ga4_events
dbt test --select macro:ga4_validation

# Test models that use these macros
dbt test --select events_sessionated
```

## 📈 Performance Considerations

- Macros are compiled at runtime, so complex logic may impact query performance
- Consider materializing frequently used macro results in intermediate models
- Use appropriate data types (FLOAT64 for monetary values, INT64 for counts)
- Index frequently queried macro-generated fields in your data warehouse

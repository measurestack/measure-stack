#!/bin/bash

# Quick test script for Measure-JS API using curl
# This script tests all endpoints quickly

set -e

echo "🧪 Quick testing Measure-JS API..."

# Source environment variables
if [ -f .env ]; then
  source .env
else
  echo "❌ Error: .env file not found"
  exit 1
fi

# Get the deployed URL
DEPLOYED_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)' 2>/dev/null || echo "")

if [ -z "$DEPLOYED_URL" ]; then
  echo "❌ Could not find deployed service. Please deploy first."
  exit 1
fi

echo "🌍 Testing API at: $DEPLOYED_URL"
echo ""

# Test 1: Health Check
echo "1️⃣ Testing Health Check..."
HEALTH_RESPONSE=$(curl -s "$DEPLOYED_URL/health")
if [[ $HEALTH_RESPONSE == *"ok"* ]]; then
  echo "✅ Health check passed: $HEALTH_RESPONSE"
else
  echo "❌ Health check failed: $HEALTH_RESPONSE"
fi
echo ""

# Test 2: CORS Preflight
echo "2️⃣ Testing CORS Preflight..."
CORS_RESPONSE=$(curl -s -I -H "Origin: https://9fwr.com" -H "Access-Control-Request-Method: POST" "$DEPLOYED_URL/events")
if [[ $CORS_RESPONSE == *"Access-Control-Allow-Origin"* ]]; then
  echo "✅ CORS headers present"
else
  echo "❌ CORS headers missing"
fi
echo ""

# Test 3: Page View Event
echo "3️⃣ Testing Page View Event..."
PAGEVIEW_RESPONSE=$(curl -s -X POST "$DEPLOYED_URL/events" \
  -H "Content-Type: application/json" \
  -H "Origin: https://9fwr.com" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -d '{
    "et": "page_view",
    "en": "test_page",
    "url": "https://9fwr.com/test",
    "r": "https://google.com",
    "p": {"test": true, "page": "test"}
  }')

if [[ $PAGEVIEW_RESPONSE == *"ok"* ]]; then
  echo "✅ Page view event sent successfully"
  echo "   Response: $PAGEVIEW_RESPONSE"
else
  echo "❌ Page view event failed: $PAGEVIEW_RESPONSE"
fi
echo ""

# Test 4: Click Event
echo "4️⃣ Testing Click Event..."
CLICK_RESPONSE=$(curl -s -X POST "$DEPLOYED_URL/events" \
  -H "Content-Type: application/json" \
  -H "Origin: https://9fwr.com" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -d '{
    "et": "click",
    "en": "test_button",
    "url": "https://9fwr.com/test",
    "p": {"button_id": "test-btn", "test": true}
  }')

if [[ $CLICK_RESPONSE == *"ok"* ]]; then
  echo "✅ Click event sent successfully"
  echo "   Response: $CLICK_RESPONSE"
else
  echo "❌ Click event failed: $CLICK_RESPONSE"
fi
echo ""

# Test 5: Consent Grant
echo "5️⃣ Testing Consent Grant..."
CONSENT_RESPONSE=$(curl -s -X POST "$DEPLOYED_URL/events" \
  -H "Content-Type: application/json" \
  -H "Origin: https://9fwr.com" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -d '{
    "et": "consent",
    "en": "consent",
    "p": {"id": true}
  }')

if [[ $CONSENT_RESPONSE == *"ok"* ]]; then
  echo "✅ Consent grant sent successfully"
  echo "   Response: $CONSENT_RESPONSE"
else
  echo "❌ Consent grant failed: $CONSENT_RESPONSE"
fi
echo ""

# Test 6: Query Parameters
echo "6️⃣ Testing Query Parameters..."
QUERY_RESPONSE=$(curl -s "$DEPLOYED_URL/events?et=page_view&en=query_test&url=https://9fwr.com/query&r=https://google.com" \
  -H "Origin: https://9fwr.com" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36")

if [[ $QUERY_RESPONSE == *"ok"* ]]; then
  echo "✅ Query parameters event sent successfully"
  echo "   Response: $QUERY_RESPONSE"
else
  echo "❌ Query parameters event failed: $QUERY_RESPONSE"
fi
echo ""

# Test 7: Form Data
echo "7️⃣ Testing Form Data..."
FORM_RESPONSE=$(curl -s -X POST "$DEPLOYED_URL/events" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Origin: https://9fwr.com" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -d "et=page_view&en=form_test&url=https://9fwr.com/form&p[test]=true")

if [[ $FORM_RESPONSE == *"ok"* ]]; then
  echo "✅ Form data event sent successfully"
  echo "   Response: $FORM_RESPONSE"
else
  echo "❌ Form data event failed: $FORM_RESPONSE"
fi
echo ""

echo "🎉 Quick test completed!"
echo ""
echo "📊 To check if data reached BigQuery, run:"
echo "   bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM \`$GCP_PROJECT_ID.$GCP_DATASET_ID.$GCP_TABLE_ID\` WHERE event_name LIKE \"%test%\"'"
echo ""
echo "🔗 API Endpoints:"
echo "   Health: $DEPLOYED_URL/health"
echo "   Events: $DEPLOYED_URL/events"

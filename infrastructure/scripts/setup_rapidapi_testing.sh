#!/bin/bash

# Setup script for RapidAPI testing
# This script helps you get your deployed URL and set up RapidAPI testing

set -e

echo "🚀 Setting up RapidAPI testing for Measure-JS..."

# Source environment variables
if [ -f .env ]; then
  echo "📄 Loading environment variables from .env file..."
  source .env
else
  echo "❌ Error: .env file not found. Please create one based on example.env"
  exit 1
fi

# Get the deployed URL
echo "🔍 Getting deployed URL..."
DEPLOYED_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)' 2>/dev/null || echo "")

if [ -z "$DEPLOYED_URL" ]; then
  echo "❌ Could not find deployed service. Please deploy first using:"
  echo "   ./infrastructure/scripts/deploy_app.sh"
  exit 1
fi

echo "✅ Found deployed URL: $DEPLOYED_URL"

# Create RapidAPI test configuration (Postman format)
echo "📝 Creating RapidAPI test configuration..."
cat > rapidapi-simple-tests.json << EOF
{
  "name": "Measure-JS API Tests",
  "description": "Comprehensive test suite for Measure-JS analytics API",
  "baseUrl": "$DEPLOYED_URL",
  "endpoints": [
    {
      "name": "Health Check",
      "method": "GET",
      "path": "/health",
      "description": "Test the health endpoint"
    },
    {
      "name": "Page View Event",
      "method": "POST",
      "path": "/events",
      "description": "Send a page view tracking event",
      "headers": {
        "Content-Type": "application/json",
        "Origin": "https://9fwr.com",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
      },
      "body": {
        "et": "page_view",
        "en": "homepage",
        "url": "https://9fwr.com",
        "r": "https://google.com",
        "p": {
          "page_title": "Homepage",
          "test": true
        }
      }
    },
    {
      "name": "Click Event",
      "method": "POST",
      "path": "/events",
      "description": "Send a click tracking event",
      "headers": {
        "Content-Type": "application/json",
        "Origin": "https://9fwr.com",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
      },
      "body": {
        "et": "click",
        "en": "cta_button",
        "url": "https://9fwr.com",
        "p": {
          "button_id": "cta-primary",
          "button_text": "Get Started",
          "test": true
        }
      }
    },
    {
      "name": "Consent Grant",
      "method": "POST",
      "path": "/events",
      "description": "Send a consent grant event",
      "headers": {
        "Content-Type": "application/json",
        "Origin": "https://9fwr.com",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
      },
      "body": {
        "et": "consent",
        "en": "consent",
        "p": {
          "id": true
        }
      }
    }
  ]
}
EOF

echo "✅ Created rapidapi-simple-tests.json"

# Test the endpoints
echo "🧪 Testing endpoints..."

# Health check
echo "🏥 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s "$DEPLOYED_URL/health")
if [[ $HEALTH_RESPONSE == *"ok"* ]]; then
  echo "✅ Health check passed"
else
  echo "❌ Health check failed: $HEALTH_RESPONSE"
fi

# Test page view event
echo "📊 Testing page view event..."
EVENT_RESPONSE=$(curl -s -X POST "$DEPLOYED_URL/events" \
  -H "Content-Type: application/json" \
  -H "Origin: https://9fwr.com" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -d '{
    "et": "page_view",
    "en": "test_page",
    "url": "https://9fwr.com/test",
    "r": "https://google.com",
    "p": {"test": true}
  }')

if [[ $EVENT_RESPONSE == *"ok"* ]]; then
  echo "✅ Page view event test passed"
else
  echo "❌ Page view event test failed: $EVENT_RESPONSE"
fi

echo ""
echo "🎉 RapidAPI testing setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Go to https://rapidapi.com/studio"
echo "2. Create a new project"
echo "3. Import the rapidapi-simple-tests.json file (Postman format)"
echo "4. Update the baseUrl variable to: $DEPLOYED_URL"
echo "5. Run the tests!"
echo ""
echo "🔗 Your API endpoints:"
echo "   Health: $DEPLOYED_URL/health"
echo "   Events: $DEPLOYED_URL/events"
echo ""
echo "💡 Quick test commands:"
echo "   curl $DEPLOYED_URL/health"
echo "   curl -X POST $DEPLOYED_URL/events -H 'Content-Type: application/json' -d '{\"et\":\"page_view\",\"en\":\"test\"}'"

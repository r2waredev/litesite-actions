#!/bin/bash
set -e

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Validate required environment variables
if [ -z "$API_KEY" ]; then
    error "API_KEY environment variable is required"
    exit 1
fi

if [ -z "$SITE" ]; then
    error "SITE environment variable is required"
    exit 1
fi

if [ -z "$BRANCH" ]; then
    error "BRANCH environment variable is required"
    exit 1
fi

# Determine API domain based on branch
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    API_DOMAIN="https://r2ware.dev"
elif [ "$BRANCH" = "release" ]; then
    API_DOMAIN="http://rpstg.lan"
else
    # Use host.docker.internal for local development (act)
    API_DOMAIN="http://host.docker.internal:5050"
fi

info "Deploying site: $SITE"
info "Branch: $BRANCH"
info "API Domain: $API_DOMAIN"

# Create archive
info "Creating archive..."
ARCHIVE_NAME="${BRANCH//\\//-}-$(date +%Y%m%d-%H%M%S).tar.gz"
git archive --format=tar.gz -o "$ARCHIVE_NAME" HEAD
success "Created archive: $ARCHIVE_NAME ($(du -h "$ARCHIVE_NAME" | cut -f1))"

# Test API connectivity
info "Testing API connectivity..."
PING_RESPONSE=$(curl -s -w "\n%{http_code}" "${API_DOMAIN}/api/v1/ping")
PING_CODE=$(echo "$PING_RESPONSE" | tail -n1)

if [ "$PING_CODE" -ne 200 ]; then
    error "API ping failed with status $PING_CODE"
    exit 1
fi
success "API is reachable"

# Get upload URL
info "Requesting upload URL..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"filename\": \"$ARCHIVE_NAME\", \"slug\": \"$SITE\"}" \
    "${API_DOMAIN}/api/v1/get-upload-url")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 200 ]; then
    error "Failed to get upload URL (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    exit 1
fi

UPLOAD_URL=$(echo "$BODY" | jq -r '.upload_url')
BUCKET=$(echo "$BODY" | jq -r '.bucket')
KEY=$(echo "$BODY" | jq -r '.key')

if [ -z "$UPLOAD_URL" ] || [ "$UPLOAD_URL" = "null" ]; then
    error "Failed to extract upload_url from response"
    exit 1
fi

success "Got upload URL"
info "S3 Location: s3://$BUCKET/$KEY"

# Upload to S3
info "Uploading archive to S3..."
curl -s -X PUT -T "$ARCHIVE_NAME" "$UPLOAD_URL"
success "Upload complete"

# Process upload and deploy
info "Processing upload and deploying site..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"key\": \"$KEY\"}" \
    "${API_DOMAIN}/api/v1/process-upload")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 200 ]; then
    error "Deployment failed (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    exit 1
fi

success "Site deployed successfully!"

# Set outputs for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "archive_name=$ARCHIVE_NAME" >> "$GITHUB_OUTPUT"
    echo "s3_key=$KEY" >> "$GITHUB_OUTPUT"
fi

#!/bin/bash

echo "Setting up Fly.io secrets for prod..."

flyctl secrets set CLIENT_ORIGIN="https://eliasderhai.github.io"
flyctl secrets set COOKIE_DOMAIN="eliasderhai.github.io"
flyctl secrets set SERVER_HOST="0.0.0.0"

echo "secrets are set"
echo "Don't forget to manually set or update: DATABASE_URL and SERVER_SECRET"

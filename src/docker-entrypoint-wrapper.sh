#!/bin/sh

# Create necessary directories in the persistent /data volume
echo "Creating necessary directories in the persistent /data volume..."
mkdir -p /data/postgresql/data /data/postgresql/run
chmod 0700 /data/postgresql/data
chmod 0755 /data/postgresql/run

# Initialize PostgreSQL if not already initialized
echo "Initializing PostgreSQL if not already initialized..."
if [ ! -f "/data/postgresql/data/PG_VERSION" ]; then
    # Initialize database
    echo "Initializing database..."
    initdb -D /data/postgresql/data
    
    # Modify pg_hba.conf to allow local connections
    echo "local all all trust" > /data/postgresql/data/pg_hba.conf
    echo "host all all 127.0.0.1/32 trust" >> /data/postgresql/data/pg_hba.conf
    echo "host all all ::1/128 trust" >> /data/postgresql/data/pg_hba.conf
    echo "host all all 0.0.0.0/0 trust" >> /data/postgresql/data/pg_hba.conf
    echo "host all all ::/0 trust" >> /data/postgresql/data/pg_hba.conf
fi

# Start PostgreSQL with the persistent directories
echo "Starting PostgreSQL..."
pg_ctl -D /data/postgresql/data -o "-c listen_addresses='*' -c unix_socket_directories='/data/postgresql/run'" start

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h localhost; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 1
done

# Create database and roles
echo "Creating database and roles..."
createuser -h /data/postgresql/run -s postgres || true
createdb -h /data/postgresql/run node || true

# Set NEXTAUTH_URL based on SPACE_HOST if available
if [ -n "$SPACE_ID" ]; then
    echo "Setting NEXTAUTH_URL to https://huggingface.co/spaces/${SPACE_ID}"
    # export NEXTAUTH_URL="https://huggingface.co/spaces/${SPACE_ID}"
    export NEXTAUTH_URL="https://${SPACE_HOST}"
else
    echo "WARNING: SPACE_ID not found"
fi

# Update DATABASE_URL to use TCP connection
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/node"

# Export these environment variables to influence Next.js binding
export HOSTNAME="0.0.0.0"
export HOST="0.0.0.0"
export PORT=3000

# Disable CSP headers to allow for embedded use within HF
export LANGFUSE_CSP_DISABLE="true"

# Preset oauth env vars based on injected space variables
# See https://huggingface.co/docs/hub/en/spaces-oauth#create-an-oauth-app
export AUTH_CUSTOM_CLIENT_ID=$OAUTH_CLIENT_ID
export AUTH_CUSTOM_CLIENT_SECRET=$OAUTH_CLIENT_SECRET
export AUTH_CUSTOM_ISSUER=$OPENID_PROVIDER_URL
export AUTH_CUSTOM_SCOPE=$OAUTH_SCOPES
export AUTH_CUSTOM_NAME="Hugging Face"

# Disable authentication via username/password to enforce authentication via HF
export AUTH_DISABLE_USERNAME_PASSWORD="true"

# Setup default org and project
export LANGFUSE_INIT_ORG_ID="default"
export LANGFUSE_INIT_ORG_NAME="default"
export LANGFUSE_INIT_PROJECT_ID="default"
export LANGFUSE_INIT_PROJECT_NAME="default"
export LANGFUSE_DEFAULT_ORG_ID="default"
export LANGFUSE_DEFAULT_PROJECT_ID="default"
export LANGFUSE_DEFAULT_ORG_ROLE="MEMBER"
export LANGFUSE_DEFAULT_PROJECT_ROLE="MEMBER"

# Start Next.js in the background
echo "Starting Next.js..."
./web/entrypoint.sh node ./web/server.js \
    --keepAliveTimeout 110000
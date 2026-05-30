#!/bin/bash
# Unified startup script for Railway / Coolify / Docker deployment
# Runs both FastAPI server and LiveKit agent worker in parallel

set -e

cd "$(dirname "$0")"

echo "🚀 Starting Outbound Mass Caller..."
echo ""

# Load environment
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Fix macOS Python SSL certificate verification
if command -v python -m certifi &> /dev/null; then
    CERT_FILE=$(python -m certifi)
    export SSL_CERT_FILE="$CERT_FILE"
    export REQUESTS_CA_BUNDLE="$CERT_FILE"
fi

echo "📋 Configuration:"
echo "   LiveKit: ${LIVEKIT_URL}"
echo "   Gemini: ${GEMINI_MODEL:-gemini-2.0-flash-live-001}"
echo "   Supabase: ${SUPABASE_URL}"
echo ""

# Railway injects $PORT; fall back to 8000 for local/Coolify deployments
# LiveKit agent reserves 8081 for its own HTTP server
APP_PORT=${PORT:-8000}
echo "🌐 Starting FastAPI server on port ${APP_PORT}..."
uvicorn server:app --host 0.0.0.0 --port "${APP_PORT}" &
SERVER_PID=$!

# Give server time to start
sleep 2

# Start LiveKit agent worker in foreground
echo "🤖 Starting LiveKit agent worker..."
python agent.py start

# If agent stops, kill server too
kill $SERVER_PID 2>/dev/null || true

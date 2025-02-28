# syntax=docker/dockerfile:1
######## WebUI frontend ########
FROM --platform=$BUILDPLATFORM node:22-alpine3.20 AS build
ARG BUILD_HASH
WORKDIR /app

# Install frontend dependencies and build assets
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ENV APP_BUILD_HASH=${BUILD_HASH}
RUN npm run build

######## WebUI backend ########
FROM python:3.11-slim-bookworm AS base

## Basic environment and application-specific settings ##
ENV ENV=prod \
  PORT=8080 \
  OPENAI_API_KEY="" \
  OPENAI_API_BASE_URL="https://api.openai.com" \
  WEBUI_SECRET_KEY="" \
  SCARF_NO_ANALYTICS=true \
  DO_NOT_TRACK=true \
  ANONYMIZED_TELEMETRY=false

WORKDIR /app/backend

# Install essential system packages and Python dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends git build-essential pandoc gcc netcat-openbsd curl jq && \
  apt-get install -y --no-install-recommends python3-dev && \
  rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies (minimal and relevant to OpenAI use)
COPY requirements.txt ./requirements.txt
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy built frontend files
COPY --from=build /app/build /app/build
COPY --from=build /app/CHANGELOG.md /app/CHANGELOG.md
COPY --from=build /app/package.json /app/package.json

# Copy backend files
COPY ./backend .

EXPOSE 8080

HEALTHCHECK CMD curl --silent --fail http://localhost:${PORT:-8080}/health | jq -ne 'input.status == true' || exit 1

CMD ["bash", "start.sh"]
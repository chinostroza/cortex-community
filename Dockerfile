# Dockerfile
FROM elixir:1.16-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git npm

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy source code
COPY lib lib
COPY priv priv

# Copy assets and build them
COPY assets assets
RUN cd assets && npm install && cd ..
RUN mix assets.deploy

# Build release
ENV MIX_ENV=prod
RUN mix release

# Runtime stage
FROM alpine:3.18

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/cortex_community ./

# Create non-root user
RUN addgroup -g 1000 cortex && \
    adduser -D -u 1000 -G cortex cortex && \
    chown -R cortex:cortex /app

USER cortex

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/api/health || exit 1

# Start command
CMD ["bin/cortex_community", "start"]
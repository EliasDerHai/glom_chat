# Build stage
FROM erlang:27.1.1.0-alpine AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.12.0-erlang-alpine /bin/gleam /bin/gleam

WORKDIR /build
COPY src/shared /build/shared
COPY src/server /build/server
WORKDIR /build/server
RUN gleam export erlang-shipment

# Runtime stage
FROM erlang:27.1.1.0-alpine

RUN apk update && apk add --no-cache postgresql-client
RUN addgroup --system webapp && adduser --system webapp -g webapp
COPY --from=build /build/server/build/erlang-shipment /app
COPY --from=build /build/server/priv /app/priv
RUN chown -R webapp:webapp /app
USER webapp
WORKDIR /app

EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]

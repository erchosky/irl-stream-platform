FROM golang:1.26.5-alpine3.23 AS build

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/caddy .

FROM alpine:3.23.5

RUN apk add --no-cache ca-certificates=20260611-r0 \
    && addgroup -S -g 10003 gateway \
    && adduser -S -D -H -u 10003 -G gateway gateway \
    && mkdir -p /data /config \
    && chown -R 10003:10003 /data /config

COPY --from=build /out/caddy /usr/bin/caddy

ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data

USER 10003:10003
EXPOSE 8080 8443 8443/udp 2019
ENTRYPOINT ["caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]

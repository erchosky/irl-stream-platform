FROM golang:1.26.5-alpine3.23 AS build

ARG APP_VERSION=dev
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w -X main.version=${APP_VERSION}" \
    -o /out/control-api .

FROM alpine:3.23.5

RUN addgroup -S -g 10001 app \
    && adduser -S -D -H -u 10001 -G app app
COPY --from=build /out/control-api /usr/local/bin/control-api

USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/control-api"]

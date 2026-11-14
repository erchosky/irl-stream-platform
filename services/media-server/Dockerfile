ARG MEDIAMTX_VERSION=1.19.3
FROM bluenviron/mediamtx:${MEDIAMTX_VERSION} AS mediamtx

FROM alpine:3.23.5

RUN addgroup -S -g 10002 media \
    && adduser -S -D -H -u 10002 -G media media
COPY --from=mediamtx /mediamtx /usr/local/bin/mediamtx
COPY mediamtx.yml /etc/mediamtx/mediamtx.yml

USER 10002:10002
EXPOSE 1935 1936 8888 8890/udp 9997 9998
ENTRYPOINT ["/usr/local/bin/mediamtx"]
CMD ["/etc/mediamtx/mediamtx.yml"]

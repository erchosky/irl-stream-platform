FROM alpine:3.23.5

RUN apk add --no-cache \
    bash=5.3.3-r1 \
    curl=8.20.0-r0 \
    ffmpeg=8.0.1-r1
COPY synthetic-flow.sh /usr/local/bin/synthetic-flow
RUN chmod 0555 /usr/local/bin/synthetic-flow

USER 65534:65534
ENTRYPOINT ["/usr/local/bin/synthetic-flow"]

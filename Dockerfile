FROM alpine:latest

# Install required packages
RUN apk add --no-cache ffmpeg bash lame shadow su-exec

COPY entrypoint.sh /
COPY sync-music.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/sync-music.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

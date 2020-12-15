FROM alpine:3.12 as build
RUN apk add --no-cache yaml-static openssl-dev openssl-libs-static \
                       zlib-static musl-dev upx tini-static && \
    apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
            shards crystal
WORKDIR /work
COPY shard.yml ./
# RUN shards install
COPY ./src ./src
RUN shards build --progress --static --release && \
    du -sh bin/klaxon && \
    upx bin/klaxon && \
    du -sh bin/klaxon

FROM busybox
COPY --from=build /work/bin/klaxon /usr/local/bin/klaxon
# COPY --from=build /sbin/tini-static /sbin/tini
# CMD /sbin/tini /usr/local/bin/klaxon
CMD /usr/local/bin/klaxon

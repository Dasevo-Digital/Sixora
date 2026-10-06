# Sixora server image. Build from the repository root:
#   docker build -t sixora-server .
# Pinned multi-architecture image digests make release builds reproducible.
FROM dart:3.12.2@sha256:5ac89dbcae4327278b257920e2786df0f22c87adc630017266b67cfcceef8348 AS build
WORKDIR /src
# The core package is only a dev dependency (tests), but pub resolves it.
COPY packages/sixora_core packages/sixora_core
COPY server/pubspec.* server/
WORKDIR /src/server
RUN dart pub get
COPY server .
RUN dart build cli -t bin/server.dart -o /out \
    && mkdir -p /out/data

# Only the bundle, for LXC installs: deploy/lxc/build_bundle.sh
FROM scratch AS bundle
COPY --from=build /out/bundle /bundle

# Distroless: glibc only, no shell or package manager.
FROM gcr.io/distroless/cc-debian12:nonroot@sha256:9dac0a79194e45a7da0158a9c6da57b217585af0786db3845d1f0ec1a0dd182f
COPY --from=build /out/bundle /opt/sixora
COPY --from=build --chown=65532:65532 /out/data /data
ENV SIXORA_DATA_DIR=/data
VOLUME /data
EXPOSE 8080
USER 65532:65532
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/opt/sixora/bin/server", "--healthcheck"]
ENTRYPOINT ["/opt/sixora/bin/server"]

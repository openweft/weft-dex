# Forked-build of dexidp/dex into a 4-arch openweft image
# (linux/amd64 + arm64 + riscv64 + loong64). Tracks upstream releases
# via the DEX_VERSION build-arg ; bump = one ARG change + a `vX.Y.Z`
# git tag here.

ARG DEX_VERSION=v2.40.0
ARG GO_VERSION=1.23

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-bookworm AS builder
ARG DEX_VERSION TARGETOS TARGETARCH
WORKDIR /src
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git clone --depth=1 --branch=${DEX_VERSION} https://github.com/dexidp/dex.git .
# Patch cmd/dex/config.go to use the pure-Go ent SQLite backend in
# both legacy + new code paths. Upstream's cmd/dex/config.go references
# storage/sql.SQLite3 unconditionally, but that type only exists when
# the file storage/sql/sqlite.go is included — and sqlite.go ships
# under //go:build cgo, which excludes it from CGO_ENABLED=0 builds.
# Swap the legacy reference for ent.SQLite3 (storage/ent/sqlite.go has
# no build tag) so the binary keeps "sqlite3" storage support without
# needing libsqlite3 + glibc on the runtime side.
#
# Validated locally on amd64+arm64+riscv64+loong64 (commit f896457 era).
RUN sed -i \
    -e 's|_ StorageConfig = (\*sql\.SQLite3)(nil)|// openweft: sql.SQLite3 needs cgo ; ent.SQLite3 is the pure-Go path|' \
    -e 's|getORMBasedSQLStorage(&sql\.SQLite3{}, &ent\.SQLite3{})|getORMBasedSQLStorage(\&ent.SQLite3{}, \&ent.SQLite3{})|' \
    cmd/dex/config.go
ENV CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH}
RUN go build -trimpath -ldflags="-s -w" -o /out/dex ./cmd/dex

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /out/dex /usr/local/bin/dex
# dex v2.34+ embeds web/{templates,static} via go:embed, so we don't
# need to copy the upstream web/ tree into the runtime stage anymore.
EXPOSE 5556 5557 5558
ENTRYPOINT ["/usr/local/bin/dex"]
CMD ["serve", "/etc/dex/config.yaml"]

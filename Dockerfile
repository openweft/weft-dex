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
ENV CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH}
RUN go build -trimpath -ldflags="-s -w" -o /out/dex ./cmd/dex

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /out/dex /usr/local/bin/dex
COPY --from=builder /src/web /web
EXPOSE 5556 5557 5558
ENTRYPOINT ["/usr/local/bin/dex"]
CMD ["serve", "/etc/dex/config.yaml"]

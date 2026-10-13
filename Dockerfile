# Toolchain image for `./run.sh --docker`: Node.js for locklift + prebuilt nekroddos.
FROM rust:1-bookworm AS nekroddos
ARG NEKRODDOS_REF=master
# Changes when the nekroddos branch moves, so the clone below is not cached forever.
ARG CACHE_BUST=0
RUN echo "$CACHE_BUST" > /dev/null \
    && git clone https://github.com/broxus/nekroddos.git /src \
    && cd /src \
    && git checkout "$NEKRODDOS_REF" \
    && cargo build --release

FROM node:22-bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=nekroddos /src/target/release/nekroddos /usr/local/bin/nekroddos
ENV NEKRODDOS_BIN=/usr/local/bin/nekroddos
WORKDIR /work

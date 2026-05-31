FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc-riscv64-unknown-elf \
    picolibc-riscv64-unknown-elf && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 compile.sh /usr/local/bin/compile.sh

WORKDIR /runs

ENTRYPOINT ["/usr/local/bin/compile.sh"]

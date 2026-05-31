# syntax=docker/dockerfile:1.7
# DESCRIPTION: Dockerfile for image to run Verilator inside
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2020 Stefan Wallentowitz
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

FROM debian:bookworm-slim AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG REPO=https://github.com/verilator/verilator
ARG SOURCE_COMMIT=master

ENV PATH=/usr/lib/ccache:${PATH}     CCACHE_DIR=/ccache     CCACHE_MAXSIZE=1G

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked     --mount=type=cache,target=/var/lib/apt,sharing=locked     apt-get update     && apt-get install --no-install-recommends -y         autoconf         bc         bison         build-essential         ca-certificates         ccache         flex         git         help2man         libfl2         libfl-dev         libjemalloc-dev         numactl         perl         perl-doc         python3         zlib1g         zlib1g-dev     && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN --mount=type=cache,target=/ccache     git clone --filter=blob:none "${REPO}" verilator     && cd verilator     && git checkout "${SOURCE_COMMIT}"     && autoconf     && ./configure     && make -j"$(nproc)"     && make install

FROM debian:bookworm-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked     --mount=type=cache,target=/var/lib/apt,sharing=locked     apt-get update     && apt-get install --no-install-recommends -y         ca-certificates         ccache         g++         libfl2         libjemalloc2         liblz4-dev         make         numactl         perl         python3         zlib1g         zlib1g-dev     && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local /usr/local

WORKDIR /work

# ENTRYPOINT [ "/usr/local/bin/verilator-wrap.sh" ]
ENTRYPOINT ["verilator"]
CMD ["--help"]

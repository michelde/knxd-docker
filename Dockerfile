# Build stage - compile knxd from source
FROM alpine:3.18 AS builder

# Build arguments
ARG KNXD_VERSION
ARG BUILD_DATE
ARG VCS_REF

# Build metadata labels
LABEL org.opencontainers.image.title="knxd-docker" \
      org.opencontainers.image.description="KNX daemon in Docker container" \
      org.opencontainers.image.version="${KNXD_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Michel Munzert" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/michelde/knxd-docker" \
      org.opencontainers.image.source="https://github.com/michelde/knxd-docker" \
      org.opencontainers.image.documentation="https://github.com/michelde/knxd-docker/blob/main/README.md"

# Set environment for build
ENV LANG=C.UTF-8 \
    MAKEFLAGS="-j$(nproc)"

# Install build dependencies in a single layer
RUN set -xe && \
    apk update && \
    apk add --no-cache --virtual .build-deps \
        git \
        build-base \
        automake \
        autoconf \
        argp-standalone \
        linux-headers \
        libev-dev \
        libusb-dev \
        cmake \
        gcc \
        g++ \
        make \
        libtool && \
    # Install runtime dependencies needed for build
    apk add --no-cache \
        libev \
        libusb \
        libgcc \
        libstdc++

# Clone, build and install knxd
RUN set -xe && \
    git clone --branch "${KNXD_VERSION}" --depth 1 https://github.com/knxd/knxd.git /tmp/knxd && \
    cd /tmp/knxd && \
    chmod +x ./bootstrap.sh && \
    ./bootstrap.sh && \
    ./configure \
        --disable-systemd \
        --disable-static \
        --enable-shared \
        --enable-busmonitor \
        --enable-tpuart \
        --enable-usb \
        --enable-eibnetipserver \
        --enable-eibnetip \
        --enable-eibnetserver \
        --enable-eibnetiptunnel \
        --enable-groupcache \
        --prefix=/usr/local && \
    # Fix missing header issue
    mkdir -p src/include/sys && \
    ln -sf /usr/lib/bcc/include/sys/cdefs.h src/include/sys/cdefs.h 2>/dev/null || true && \
    make && \
    make DESTDIR=/install install && \
    # Strip binaries to reduce size
    find /install -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true && \
    # Clean up build directory
    cd / && rm -rf /tmp/knxd && \
    # Remove build dependencies
    apk del .build-deps && \
    # Clean package cache
    rm -rf /var/cache/apk/*

# Runtime stage - minimal image with only runtime dependencies
FROM alpine:3.18

# Runtime metadata labels
LABEL org.opencontainers.image.title="knxd-docker" \
      org.opencontainers.image.description="KNX daemon in Docker container" \
      org.opencontainers.image.version="${KNXD_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Michel Munzert" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://github.com/michelde/knxd-docker" \
      org.opencontainers.image.source="https://github.com/michelde/knxd-docker" \
      org.opencontainers.image.documentation="https://github.com/michelde/knxd-docker/blob/main/README.md"

# Create non-root user for security
RUN addgroup -g 1000 knxd && \
    adduser -D -u 1000 -G knxd -s /bin/sh knxd

# Install only runtime dependencies
RUN set -xe && \
    apk update && \
    apk add --no-cache \
        # Core runtime libraries
        libev \
        libusb \
        libgcc \
        libstdc++ \
        libtool \
        # System utilities
        udev \
        bash \
        # Configuration processing
        gettext \
        # Network utilities for health checks
        netcat-openbsd \
        procps && \
    # Clean package cache
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Copy knxd binaries and libraries from builder stage
COPY --from=builder /install/ /

# Copy configuration template and initialization script
COPY knxd-template.ini /etc/knxd-template.ini
COPY init.sh /usr/local/bin/init.sh

# Set proper permissions
RUN chmod +x /usr/local/bin/init.sh && \
    chmod 644 /etc/knxd-template.ini && \
    # Create directories with proper ownership
    mkdir -p /var/log/knxd /var/run/knxd && \
    chown -R knxd:knxd /var/log/knxd /var/run/knxd /etc/knxd-template.ini

# Expose KNX ports
EXPOSE 6720/tcp 3671/udp

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD sh -c 'ps aux | grep -v grep | grep knxd && netstat -ln | grep 6720' || exit 1

# Set working directory
WORKDIR /

# Use non-root user by default (can be overridden if device access requires root)
# USER knxd

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["knxd", "/etc/knxd.ini"]

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
        git=2.40.1-r0 \
        build-base=0.5-r3 \
        automake=1.16.5-r2 \
        autoconf=2.71-r2 \
        argp-standalone=1.4.0-r0 \
        linux-headers=6.3-r0 \
        libev-dev=4.33-r1 \
        libusb-dev=1.0.26-r0 \
        cmake=3.26.5-r0 \
        gcc=12.2.1_git20220924-r10 \
        g++=12.2.1_git20220924-r10 \
        make=4.4.1-r1 \
        libtool=2.4.7-r2 && \
    # Install runtime dependencies needed for build
    apk add --no-cache \
        libev=4.33-r1 \
        libusb=1.0.26-r0 \
        libgcc=12.2.1_git20220924-r10 \
        libstdc++=12.2.1_git20220924-r10

# Clone knxd source code
RUN git clone --branch "${KNXD_VERSION}" --depth 1 https://github.com/knxd/knxd.git /tmp/knxd

# Set working directory for build
WORKDIR /tmp/knxd

# Build and install knxd
RUN set -xe && \
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
    find /install -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true

# Clean up build artifacts
WORKDIR /
RUN rm -rf /tmp/knxd && \
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
        libev=4.33-r1 \
        libusb=1.0.26-r0 \
        libgcc=12.2.1_git20220924-r10 \
        libstdc++=12.2.1_git20220924-r10 \
        libtool=2.4.7-r2 \
        # System utilities
        udev=252-r0 \
        bash=5.2.15-r5 \
        # Configuration processing
        gettext=0.21.1-r7 \
        # Network utilities for health checks
        netcat-openbsd=1.219-r0 \
        procps=4.0.3-r0 && \
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

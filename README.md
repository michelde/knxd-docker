# knxd-docker

This repo is to build the [KNX daemon](https://github.com/knxd/knxd). The container is used to have an IP
tunnel using the busware USB device.

KNXD requires a knxd.ini file to define the communication. This docker uses for most of the parameters in
the knxd.ini file environment variables. Therefore it's important to start the container with all the
needed environment variables.

The basic configuration file is `knxd-template.ini`. Please check this file for reference of all environment
variables.

## Build Docker Container

The container uses a multi-stage build process for optimal image size and includes comprehensive metadata labels.

### Build Arguments

The following build arguments can be used to customize the build:

| Argument | Description | Required | Default | Example |
|----------|-------------|----------|---------|---------|
| `KNXD_VERSION` | Version/tag of knxd to build | **Yes** | - | `0.14.66` |
| `BUILD_DATE` | Build timestamp for metadata | No | - | `2024-01-15T10:30:00Z` |
| `VCS_REF` | Git commit hash for metadata | No | - | `abc123def` |

### Basic Build

The simplest way to build the container:

```bash
docker build --build-arg KNXD_VERSION=0.14.66 -t knxd .
```

### Build with Metadata

For better image metadata and traceability:

```bash
docker build \
    --build-arg KNXD_VERSION=0.14.66 \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    -t michelmu/knxd-docker:latest \
    -t michelmu/knxd-docker:0.14.66 \
    .
```

### Multi-Platform Build

For building and pushing to Docker Hub with multiple architectures:

```bash
# Create and use buildx builder
docker buildx create --name mybuilder --use
docker buildx inspect mybuilder --bootstrap

# Build for multiple platforms
docker buildx build \
    --build-arg KNXD_VERSION=0.14.66 \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    --platform=linux/amd64,linux/arm64 \
    -t michelmu/knxd-docker:latest \
    -t michelmu/knxd-docker:0.14.66 \
    . \
    --push
```

### Build Optimizations

The Dockerfile includes several optimizations:

- **Multi-stage build**: Separates build and runtime environments
- **Aggressive cleanup**: Removes build dependencies and caches
- **Binary stripping**: Reduces binary sizes
- **Minimal runtime**: Only includes necessary runtime dependencies
- **Security**: Creates non-root user (commented out due to device access requirements)
- **Health checks**: Built-in container health monitoring
- **Metadata labels**: OCI-compliant image labels for better management

### Image Size Comparison

The optimized multi-stage build significantly reduces the final image size:
- **Previous single-stage**: ~200-300MB
- **Optimized multi-stage**: ~50-80MB (estimated reduction of 60-75%)

## Environment Variables

The following environment variables can be set to configure the container. All variables are used to populate the `knxd.ini` configuration file from the template.

### Core Configuration Variables

| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `ADDRESS` | KNX physical address of the daemon | **Yes** | - | `1.5.1` | Format: area.line.device (1-15.1-15.1-255) |
| `CLIENT_ADDRESS` | KNX client address range | **Yes** | - | `1.5.2:10` | Format: start_address:count |
| `INTERFACE` | Interface driver type | **Yes** | - | `tpuart`, `usb`, `ipt`, `ft12` | Must match one of the supported drivers |
| `DEBUG_ERROR_LEVEL` | Logging level | No | `error` | `error`, `warning`, `info`, `debug` | Controls verbosity of log output |

### Interface-Specific Variables

#### TPUART Interface (Serial/USB)
| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `DEVICE` | Device path for TPUART interface | **Yes*** | - | `/dev/knx`, `/dev/ttyUSB0` | *Required for TPUART interface |
| `FILTERS` | Packet filtering mode | No | `single` | `single`, `none` | Controls packet filtering |

#### TPUART-IP Interface (Network-based TPUART)
| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `IP_ADDRESS` | IP address of TPUART device | **Yes*** | - | `192.168.1.100` | *Required for TPUART-IP interface |
| `DEST_PORT` | Destination port | **Yes*** | - | `3671` | *Required for TPUART-IP interface |
| `FILTERS` | Packet filtering mode | No | `single` | `single`, `none` | Controls packet filtering |

#### USB Interface
| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `USB_DEVICE` | USB device identifier | No | - | `/dev/bus/usb/001/002` | Alternative to USB_BUS |
| `USB_BUS` | USB bus identifier | No | - | `001:002` | Alternative to USB_DEVICE |
| `FILTERS` | Packet filtering mode | No | `single` | `single`, `none` | Controls packet filtering |

#### IP Tunneling Interface
| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `IP_ADDRESS` | KNX/IP gateway IP address | **Yes*** | - | `192.168.1.50` | *Required for IPT interface |
| `DEST_PORT` | KNX/IP gateway port | No | `3671` | `3671` | Standard KNX/IP port |
| `NAT` | Enable NAT mode for tunneling | No | `false` | `true`, `false` | Use when behind NAT |

#### FT12/FT12CEMI Interface (Serial)
| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `DEVICE` | Serial device path | **Yes*** | - | `/dev/ttyS0`, `/dev/ttyUSB0` | *Required for FT12 interfaces |
| `FILTERS` | Packet filtering mode | No | `single` | `single`, `none` | Controls packet filtering |

#### NCN5120 Interface
| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `DEVICE` | Device path for NCN5120 | **Yes*** | - | `/dev/ttyUSB0` | *Required for NCN5120 interface |
| `FILTERS` | Packet filtering mode | No | `single` | `single`, `none` | Controls packet filtering |

#### NCN5120-IP Interface
| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `IP_ADDRESS` | IP address of NCN5120 device | **Yes*** | - | `192.168.1.100` | *Required for NCN5120-IP interface |
| `DEST_PORT` | Destination port | **Yes*** | - | `3671` | *Required for NCN5120-IP interface |
| `FILTERS` | Packet filtering mode | No | `single` | `single`, `none` | Controls packet filtering |

### Server Configuration Variables

| Variable | Description | Required | Default | Example | Notes |
|----------|-------------|----------|---------|---------|-------|
| `SERVER_INTERFACE` | Network interface for multicast | No | (default) | `eth0`, `eth1` | Useful for macvlan/bridge networks |

### Configuration Examples by Interface Type

#### TPUART (USB Serial Adapter)
```bash
ADDRESS=1.5.1
CLIENT_ADDRESS=1.5.2:10
INTERFACE=tpuart
DEVICE=/dev/knx
DEBUG_ERROR_LEVEL=error
FILTERS=single
```

#### USB Interface
```bash
ADDRESS=1.5.1
CLIENT_ADDRESS=1.5.2:10
INTERFACE=usb
USB_DEVICE=/dev/bus/usb/001/002
DEBUG_ERROR_LEVEL=error
FILTERS=single
```

#### IP Tunneling
```bash
ADDRESS=1.5.1
CLIENT_ADDRESS=1.5.2:10
INTERFACE=ipt
IP_ADDRESS=192.168.1.50
DEST_PORT=3671
NAT=false
DEBUG_ERROR_LEVEL=error
```

#### FT12 Serial
```bash
ADDRESS=1.5.1
CLIENT_ADDRESS=1.5.2:10
INTERFACE=ft12
DEVICE=/dev/ttyS0
DEBUG_ERROR_LEVEL=error
FILTERS=single
```

**Note**: Variables marked with * are required only when using the corresponding interface type.
## run the container

To start the container using docker with the busware usb stick, it would look like this:

```bash
docker run \
--name=knxd \
-p 6720:6720/tcp \
-p 3671:3671/udp \
--device=/dev/bus/usb:/dev/bus/usb:rwm \
--device=/dev/mem:/dev/mem:rw \
--device=/dev/serial/by-id/usb-busware.de_TPUART_transparent_95738343235351D032C0-if00:/dev/knx \
--cap-add=SYS_MODULE \
--cap-add=SYS_RAWIO \
-e ADDRESS="1.5.1" \
-e CLIENT_ADDRESS="1.5.2:10" \
-e INTERFACE=tpuart \
-e DEVICE="/dev/knx" \
-e DEBUG_ERROR_LEVEL="error" \
-e FILTERS="single" \
--restart unless-stopped michelmu/knxd-docker:latest
```


If you want to use docker-compose the following yaml file would look like this:

```yaml
services:
  knxd:
    image: michelmu/knxd-docker:latest
    container_name: knxd
    ports:
      - "6720:6720/tcp"
      - "3671:3671/udp"
    devices:
      - "/dev/bus/usb:/dev/bus/usb:rwm"
      - "/dev/mem:/dev/mem:rw"
      - "/dev/serial/by-id/usb-busware.de_TPUART_transparent_95738343235351D032C0-if00:/dev/knx"
    cap_add:
      - SYS_MODULE
      - SYS_RAWIO
    environment:
      - ADDRESS=1.5.1
      - CLIENT_ADDRESS=1.5.2:10
      - INTERFACE=tpuart
      - DEVICE=/dev/knx
      - DEBUG_ERROR_LEVEL=error
      - FILTERS=single
    restart: unless-stopped
```

## Health Checks and Verification

### Container Status Check

First, verify that the container is running and healthy:

```bash
# Check if container is running
docker ps | grep knxd

# Check container logs for startup messages
docker logs knxd

# Check container resource usage
docker stats knxd --no-stream
```

### Service Connectivity Tests

#### 1. Check KNX Daemon Process
```bash
# Verify knxd process is running inside container
docker exec knxd ps aux | grep knxd

# Check if knxd is listening on expected ports
docker exec knxd netstat -ln | grep -E '(6720|3671)'
```

#### 2. Network Port Verification
```bash
# Test TCP port 6720 (KNX daemon)
telnet localhost 6720

# Test UDP port 3671 (KNXnet/IP) - requires netcat
nc -u localhost 3671
```

#### 3. KNX Bus Communication Test
```bash
# Access container shell
docker exec -it knxd bash

# Test basic KNX communication with knxtool
knxtool on ip:127.0.0.1 0/1/50    # Turn on device at group address 0/1/50
knxtool off ip:127.0.0.1 0/1/50   # Turn off device at group address 0/1/50

# Read group address value
knxtool read ip:127.0.0.1 0/1/50

# Monitor KNX bus traffic
knxtool groupsocketlisten ip:127.0.0.1
```

### Docker Health Check Configuration

Add a health check to your docker-compose.yaml:

```yaml
services:
  knxd:
    image: michelmu/knxd-docker:latest
    container_name: knxd
    ports:
      - "6720:6720/tcp"
      - "3671:3671/udp"
    devices:
      - "/dev/bus/usb:/dev/bus/usb:rwm"
      - "/dev/mem:/dev/mem:rw"
      - "/dev/serial/by-id/usb-busware.de_TPUART_transparent_95738343235351D032C0-if00:/dev/knx"
    cap_add:
      - SYS_MODULE
      - SYS_RAWIO
    environment:
      - ADDRESS=1.5.1
      - CLIENT_ADDRESS=1.5.2:10
      - INTERFACE=tpuart
      - DEVICE=/dev/knx
      - DEBUG_ERROR_LEVEL=error
      - FILTERS=single
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "sh", "-c", "ps aux | grep -v grep | grep knxd && netstat -ln | grep 6720"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

Or for docker run command:

```bash
docker run \
--name=knxd \
-p 6720:6720/tcp \
-p 3671:3671/udp \
--device=/dev/bus/usb:/dev/bus/usb:rwm \
--device=/dev/mem:/dev/mem:rw \
--device=/dev/serial/by-id/usb-busware.de_TPUART_transparent_95738343235351D032C0-if00:/dev/knx \
--cap-add=SYS_MODULE \
--cap-add=SYS_RAWIO \
--health-cmd="sh -c 'ps aux | grep -v grep | grep knxd && netstat -ln | grep 6720'" \
--health-interval=30s \
--health-timeout=10s \
--health-retries=3 \
--health-start-period=40s \
-e ADDRESS="1.5.1" \
-e CLIENT_ADDRESS="1.5.2:10" \
-e INTERFACE=tpuart \
-e DEVICE="/dev/knx" \
-e DEBUG_ERROR_LEVEL="error" \
-e FILTERS="single" \
--restart unless-stopped michelmu/knxd-docker:latest
```

### Troubleshooting Common Issues

#### Container Won't Start
```bash
# Check detailed logs
docker logs knxd --details

# Check if configuration file was generated correctly
docker exec knxd cat /etc/knxd.ini

# Verify environment variables
docker exec knxd env | grep -E "(ADDRESS|INTERFACE|DEVICE)"
```

#### Device Permission Issues
```bash
# Check device permissions on host
ls -la /dev/serial/by-id/
ls -la /dev/ttyUSB*

# Check if devices are accessible inside container
docker exec knxd ls -la /dev/knx
docker exec knxd ls -la /dev/bus/usb/
```

#### Network Connectivity Issues
```bash
# Test from host system
telnet localhost 6720
nc -u localhost 3671

# Check firewall rules
sudo iptables -L | grep -E "(6720|3671)"

# Test KNX/IP gateway connectivity (for IP tunneling)
ping 192.168.1.50  # Replace with your gateway IP
telnet 192.168.1.50 3671
```

#### KNX Bus Communication Problems
```bash
# Enable debug logging
docker run ... -e DEBUG_ERROR_LEVEL="debug" ...

# Monitor all KNX traffic
docker exec -it knxd knxtool groupsocketlisten ip:127.0.0.1

# Test with different group addresses
docker exec knxd knxtool read ip:127.0.0.1 0/0/1  # Test with a known device
```

### Monitoring and Logging

#### Log Analysis
```bash
# Follow logs in real-time
docker logs -f knxd

# Search for specific errors
docker logs knxd 2>&1 | grep -i error

# Check startup sequence
docker logs knxd | head -20
```

#### Performance Monitoring
```bash
# Monitor resource usage
docker stats knxd

# Check container health status
docker inspect knxd | grep -A 10 '"Health"'
```

### Integration Testing

#### Home Assistant Integration Test
```bash
# Test KNX integration from Home Assistant
# Add to configuration.yaml:
# knx:
#   host: <docker_host_ip>
#   port: 3671

# Verify connection in Home Assistant logs
```

#### ETS Integration Test
```bash
# Configure ETS to connect to:
# IP: <docker_host_ip>
# Port: 3671
# Connection type: Tunneling
```

## Repository Structure

This project is organized with the following structure for better maintainability and usability:

```
knxd-docker/
├── README.md                    # Main project documentation
├── Dockerfile                   # Multi-stage optimized Docker build
├── docker-compose.yaml          # Basic docker-compose example
├── init.sh                      # Enhanced initialization script with validation
├── knxd-template.ini           # Configuration template
├── scripts/                     # Utility scripts
│   ├── build.sh                # Automated build script
│   └── health-check.sh         # Comprehensive health check script
├── examples/                    # Ready-to-use configuration examples
│   ├── tpuart/                 # TPUART interface examples
│   ├── usb/                    # USB interface examples
│   ├── ip-tunneling/           # IP tunneling examples
│   └── ft12/                   # FT12 interface examples
└── docs/                       # Comprehensive documentation
    ├── README.md               # Documentation index
    ├── quick-start.md          # Quick start guide
    └── [additional docs]       # Interface guides, troubleshooting, etc.
```

## Quick Start

For the fastest way to get started, see the [Quick Start Guide](docs/quick-start.md).

### Choose Your Interface

1. **TPUART (Most Common)**: USB serial adapters
   ```bash
   cp examples/tpuart/docker-compose.yml ./
   # Edit device path and start
   docker-compose up -d
   ```

2. **IP Tunneling**: KNX/IP gateways
   ```bash
   cp examples/ip-tunneling/docker-compose.yml ./
   # Edit gateway IP and start
   docker-compose up -d
   ```

3. **USB Direct**: Direct USB KNX interfaces
   ```bash
   cp examples/usb/docker-compose.yml ./
   # Configure USB device and start
   docker-compose up -d
   ```

### Utility Scripts

The project includes helpful utility scripts:

```bash
# Build the image with optimizations
./scripts/build.sh 0.14.66

# Run comprehensive health checks
./scripts/health-check.sh [container_name]
```

## Documentation

- [Quick Start Guide](docs/quick-start.md) - Get running in minutes

## Examples

Ready-to-use examples are provided in the [examples/](examples/) directory:

- [TPUART Interface](examples/tpuart/) - USB serial adapters (most common)
- [IP Tunneling](examples/ip-tunneling/) - KNX/IP gateways
- [USB Interface](examples/usb/) - Direct USB KNX interfaces

Each example includes:
- Complete `docker-compose.yml` configuration
- Detailed README with setup instructions
- Troubleshooting tips
- Integration examples

## CI/CD Pipeline

This project includes a comprehensive CI/CD pipeline with GitHub Actions:

### 🚀 Automated Builds
- **Multi-platform support**: Builds for `linux/amd64` and `linux/arm64`
- **Automated testing**: Comprehensive test matrix for all interface types
- **Security scanning**: Vulnerability scanning with Trivy
- **Quality checks**: Dockerfile linting, shell script validation, documentation checks

### 📦 Automated Releases
- **Tagged releases**: Automatic releases when tags are pushed
- **Docker Hub publishing**: Multi-platform images published automatically
- **Release notes**: Auto-generated changelogs with build information

### 🔄 Dependency Management
- **Weekly monitoring**: Automatic checks for new KNXD versions
- **Security updates**: Base image vulnerability scanning
- **Automated PRs**: Patch version updates via pull requests
- **Issue creation**: GitHub issues for major version updates

### 📚 Documentation Quality
- **Link validation**: Automatic checking of internal and external links
- **Markdown linting**: Consistent documentation formatting
- **Structure validation**: Ensures all referenced files exist
- **Metrics tracking**: Documentation coverage and quality metrics

### Workflow Status
[![Build and Release](https://github.com/michelde/knxd-docker/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/michelde/knxd-docker/actions/workflows/build-and-release.yml)
[![Documentation](https://github.com/michelde/knxd-docker/actions/workflows/documentation.yml/badge.svg)](https://github.com/michelde/knxd-docker/actions/workflows/documentation.yml)
[![Dependency Updates](https://github.com/michelde/knxd-docker/actions/workflows/dependency-updates.yml/badge.svg)](https://github.com/michelde/knxd-docker/actions/workflows/dependency-updates.yml)

For detailed information about the CI/CD pipeline, see [GitHub Workflows Documentation](.github/workflows/README.md).

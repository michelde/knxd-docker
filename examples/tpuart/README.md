# TPUART Interface Example

This example demonstrates how to configure knxd-docker with a TPUART interface using a USB serial adapter.

## Overview

TPUART (Twisted Pair Universal Asynchronous Receiver Transmitter) is a common interface for KNX communication over twisted pair cables. This example uses a USB-to-TPUART adapter like the Busware TPUART stick.

## Hardware Requirements

- USB-to-TPUART adapter (e.g., Busware TPUART stick)
- KNX twisted pair bus connection
- Host system with USB port

## Configuration

### Device Identification

First, identify your USB device:

```bash
# List USB devices
lsusb

# Find serial devices
ls -la /dev/serial/by-id/

# Example output:
# usb-busware.de_TPUART_transparent_95738343235351D032C0-if00 -> ../../ttyUSB0
```

### Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `ADDRESS` | `1.5.1` | KNX physical address of the daemon |
| `CLIENT_ADDRESS` | `1.5.2:10` | Client address range (start:count) |
| `INTERFACE` | `tpuart` | Interface type |
| `DEVICE` | `/dev/knx` | Device path inside container |
| `DEBUG_ERROR_LEVEL` | `error` | Logging level |
| `FILTERS` | `single` | Packet filtering mode |

## Usage

### Using Docker Compose

1. Update the device path in `docker-compose.yml` to match your USB device:
   ```yaml
   devices:
     - "/dev/serial/by-id/YOUR_DEVICE_ID:/dev/knx"
   ```

2. Start the container:
   ```bash
   docker-compose up -d
   ```

3. Check the logs:
   ```bash
   docker-compose logs -f
   ```

### Using Docker Run

```bash
docker run -d \
  --name knxd-tpuart \
  -p 6720:6720/tcp \
  -p 3671:3671/udp \
  --device=/dev/bus/usb:/dev/bus/usb:rwm \
  --device=/dev/mem:/dev/mem:rw \
  --device=/dev/serial/by-id/YOUR_DEVICE_ID:/dev/knx \
  --cap-add=SYS_MODULE \
  --cap-add=SYS_RAWIO \
  -e ADDRESS=1.5.1 \
  -e CLIENT_ADDRESS=1.5.2:10 \
  -e INTERFACE=tpuart \
  -e DEVICE=/dev/knx \
  -e DEBUG_ERROR_LEVEL=error \
  -e FILTERS=single \
  --restart unless-stopped \
  michelmu/knxd-docker:latest
```

## Testing

### Basic Connectivity Test

```bash
# Check if container is running
docker ps | grep knxd-tpuart

# Check logs for startup messages
docker logs knxd-tpuart

# Test KNX communication
docker exec -it knxd-tpuart bash
knxtool on ip:127.0.0.1 0/1/50
knxtool off ip:127.0.0.1 0/1/50
```

### Health Check

```bash
# Run health check script
../../scripts/health-check.sh knxd-tpuart
```

## Troubleshooting

### Device Permission Issues

If you get permission errors:

```bash
# Check device permissions
ls -la /dev/serial/by-id/

# Add user to dialout group (may require logout/login)
sudo usermod -a -G dialout $USER

# Or change device permissions (temporary)
sudo chmod 666 /dev/ttyUSB0
```

### Container Won't Start

```bash
# Check detailed logs
docker logs knxd-tpuart --details

# Verify device exists
ls -la /dev/serial/by-id/

# Check if device is already in use
lsof /dev/ttyUSB0
```

### KNX Communication Issues

```bash
# Enable debug logging
docker-compose down
# Edit docker-compose.yml: DEBUG_ERROR_LEVEL=debug
docker-compose up -d

# Monitor KNX traffic
docker exec -it knxd-tpuart knxtool groupsocketlisten ip:127.0.0.1
```

## Integration Examples

### Home Assistant

Add to your Home Assistant `configuration.yaml`:

```yaml
knx:
  host: <docker_host_ip>
  port: 3671
```

### ETS (Engineering Tool Software)

Configure ETS connection:
- Connection Type: KNXnet/IP Tunneling
- IP Address: `<docker_host_ip>`
- Port: `3671`

## Advanced Configuration

### Custom KNX Addresses

Modify the addresses in `docker-compose.yml`:

```yaml
environment:
  - ADDRESS=1.1.1          # Area 1, Line 1, Device 1
  - CLIENT_ADDRESS=1.1.2:5 # Start at 1.1.2, allocate 5 addresses
```

### Network Interface Binding

For specific network interface binding:

```yaml
environment:
  - SERVER_INTERFACE=eth0  # Bind to specific interface
```

### Persistent Configuration

To persist configuration changes:

```yaml
volumes:
  - ./knxd.ini:/etc/knxd.ini:ro  # Mount custom config
  - knxd-logs:/var/log/knxd      # Persistent logs

# Quick Start Guide

Get knxd-docker up and running in minutes with this quick start guide.

## Prerequisites

- Docker installed and running
- Docker Compose (optional but recommended)
- KNX hardware interface (USB adapter, KNX/IP gateway, etc.)

## Step 1: Choose Your Interface Type

Select the appropriate example based on your KNX interface:

- **TPUART/USB Serial**: Most common, uses USB-to-KNX adapters
- **IP Tunneling**: Connects to KNX/IP gateways over network
- **USB Direct**: Direct USB KNX interfaces
- **FT12 Serial**: Legacy serial interfaces

## Step 2: Quick Setup

### Option A: TPUART Interface (Most Common)

1. **Identify your USB device:**
   ```bash
   ls -la /dev/serial/by-id/
   ```

2. **Copy the example:**
   ```bash
   cp examples/tpuart/docker-compose.yml ./
   ```

3. **Edit the device path:**
   ```bash
   nano docker-compose.yml
   # Update the device line to match your USB device:
   # - "/dev/serial/by-id/YOUR_DEVICE_ID:/dev/knx"
   ```

4. **Start the container:**
   ```bash
   docker-compose up -d
   ```

### Option B: IP Tunneling

1. **Copy the example:**
   ```bash
   cp examples/ip-tunneling/docker-compose.yml ./
   ```

2. **Edit the gateway IP:**
   ```bash
   nano docker-compose.yml
   # Update IP_ADDRESS to your KNX/IP gateway:
   # - IP_ADDRESS=192.168.1.50
   ```

3. **Start the container:**
   ```bash
   docker-compose up -d
   ```

## Step 3: Verify Installation

1. **Check container status:**
   ```bash
   docker ps | grep knxd
   ```

2. **Check logs:**
   ```bash
   docker-compose logs -f
   ```

3. **Run health check:**
   ```bash
   ./scripts/health-check.sh
   ```

## Step 4: Test KNX Communication

1. **Access container:**
   ```bash
   docker exec -it knxd bash
   ```

2. **Test basic commands:**
   ```bash
   # Turn on a device (replace 0/1/50 with your group address)
   knxtool on ip:127.0.0.1 0/1/50
   
   # Turn off a device
   knxtool off ip:127.0.0.1 0/1/50
   
   # Read a value
   knxtool read ip:127.0.0.1 0/1/50
   
   # Monitor bus traffic
   knxtool groupsocketlisten ip:127.0.0.1
   ```

## Step 5: Integration

### Home Assistant

Add to your `configuration.yaml`:

```yaml
knx:
  host: <your_docker_host_ip>
  port: 3671
```

### ETS (Engineering Tool Software)

Configure connection:
- Type: KNXnet/IP Tunneling
- IP: `<your_docker_host_ip>`
- Port: `3671`

## Common Configuration

### Environment Variables

The most important variables to configure:

```yaml
environment:
  - ADDRESS=1.5.1           # Your KNX physical address
  - CLIENT_ADDRESS=1.5.2:10 # Client address range
  - INTERFACE=tpuart        # Interface type
  - DEVICE=/dev/knx         # Device path (for serial interfaces)
  - IP_ADDRESS=192.168.1.50 # Gateway IP (for IP tunneling)
```

### Port Mappings

Standard ports used by knxd:

```yaml
ports:
  - "6720:6720/tcp"  # KNX daemon port
  - "3671:3671/udp"  # KNXnet/IP port
```

## Troubleshooting

### Container Won't Start

```bash
# Check detailed logs
docker logs knxd --details

# Verify configuration
docker exec knxd cat /etc/knxd.ini
```

### Device Permission Issues

```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Or temporarily fix permissions
sudo chmod 666 /dev/ttyUSB0
```

### Network Issues

```bash
# Test port connectivity
telnet localhost 6720
nc -u localhost 3671

# Check firewall
sudo iptables -L | grep -E "(6720|3671)"
```

## Next Steps

- Read the [Configuration Guide](configuration.md) for detailed setup
- Check [Interface-specific guides](interfaces/) for your hardware
- Review [Integration guides](integration/) for your home automation system
- Explore [Advanced topics](advanced/) for optimization

## Getting Help

- Review [Examples](../examples/) for your use case
- Search [GitHub Issues](https://github.com/michelde/knxd-docker/issues)
- Create a new issue if needed

## Build from Source

If you want to build the image yourself:

```bash
# Basic build
./scripts/build.sh 0.14.66

# Multi-platform build
PLATFORMS=linux/amd64,linux/arm64 ./scripts/build.sh 0.14.66
```

That's it! You should now have a working knxd-docker installation.

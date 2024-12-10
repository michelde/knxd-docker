# knxd-docker

This repo is to build the [KNX daemon](https://github.com/knxd/knxd). The container is used to have an IP
tunnel using the busware USB device.

KNXD requires a knxd.ini file to define the communication. This docker uses for most of the parameters in
the knxd.ini file environment variables. Therefore it's important to start the container with all the
needed environment variables.

The basic configuration file is `knxd-template.ini`. Please check this file for reference of all environment
variables.

## build docker container

The easiest way to build the container is to use the platform specific build command and passing the knxd version
to the build argument.

```bash
docker build --build-arg KNXD_VERSION=0.14.66 -t knxd .
```

```bash
docker build -t michelmu/knxd-docker --build-arg KNXD_VERSION=0.14.66 -t michelmu/knxd-docker:latest -t michelmu/knxd-docker:0.14.66 .
```

or as multi-platform build and push to docker hub:

```bash
docker buildx create --name mybuilder --use
docker buildx inspect mybuilder --bootstrap
docker buildx build \
    --build-arg KNXD_VERSION=0.14.66 \
    --platform=linux/amd64,linux/arm64 \
    -t michelmu/knxd-docker:latest \
    -t michelmu/knxd-docker:0.14.66 \
    . \
    --push
```

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

## Test

Logon to docker container and test with `knxtool`

```bash
docker exec -it knxd bash

knxtool on ip:127.0.0.1 0/1/50
knxtool off ip:127.0.0.1 0/1/50
```


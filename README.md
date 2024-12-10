# knxd-docker

Build the container with specific version of KNXD.

```bash
docker build -t michelmu/knxd-docker --build-arg KNXD_VERSION=0.14.68 -t michelmu/knxd-docker:latest -t michelmu/knxd-docker:0.14.68 .
```

or as multi-platform build and push to docker hub:

```bash
docker buildx create --name mybuilder --use
docker buildx inspect mybuilder --bootstrap
docker buildx build \
    --build-arg KNXD_VERSION=0.14.68 \
    --platform=linux/amd64,linux/arm64 \
    -t michelmu/knxd-docker:latest \
    -t michelmu/knxd-docker:0.14.68 \
    . \
    --push
```

Run knxd in docker container

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

## Test

Logon to docker container and test with `knxtool`

```bash
docker exec -it knxd bash

knxtool on ip:127.0.0.1 0/1/50
knxtool off ip:127.0.0.1 0/1/50
```

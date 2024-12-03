# knxd-docker

Build the container with specific version of KNXD.

```bash
docker build -t michelmu/knxd-docker --build-arg KNXD_VERSION=0.14.67 .
```

or as multi-platform build and push to docker hub:

```bash
docker buildx build \
    -t michelmu/knxd-docker:0.14.67 \
    -t michelmu/knxd-docker:latest \
    --push \
    --build-arg KNXD_VERSION=0.14.67 \
    --builder=container \
    --platform=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v8 .
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
--restart unless-stopped michelmu/knxd-docker
```

## Test

Logon to docker container and test with `knxtool`

```bash
docker exec -it knxd bash

knxtool on ip:127.0.0.1 0/1/50
knxtool off ip:127.0.0.1 0/1/50
```

## create UDEV Rule for /dev/knx

- Show the attributes of your KNX device. e.g. `udevadm info -a -p $(udevadm info -q path -n /dev/ttyACM0)`
- Note some unique attributes e.g. idVendor, iDProduct, serial and note them down
- Create a new udev rule: `sudo vi /lib/udev/rules.d/99-usb-knx.rules` and put a line with 
`SUBSYSTEM=="tty", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="204b", ATTRS{serial}=="-your-serial-id", SYMLINK+="knx"`
- Reload udev rules: `sudo udevadm control --reload-rules && udevadm trigger`
- Re-Insert KNX device
- Now you should have a device /dev/knx which you can use for this docker container which links to your knx device

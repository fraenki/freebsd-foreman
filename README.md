#### Table of Contents

1. [About](#about)
1. [Requirements](#requirements)
1. [Provision Instructions](#provision-instructions)
1. [Build Instructions](#build-instructions)
1. [More Examples](#more-examples)
1. [Acknowledgement](#acknowledgement)

## About

This repository contains everything needed to build a customized [mfsBSD](https://mfsbsd.vx.sk/) image that can be used to provision [FreeBSD](https://www.freebsd.org/) servers with [Foreman](https://theforeman.org/).

Also check out [unattended upgrades for FreeBSD](https://github.com/fraenki/f-upgrade).

## Requirements

In order to deploy FreeBSD servers with Foreman, the following requirements must be met:

* Provisioning templates for FreeBSD are already [included](https://github.com/theforeman/foreman/blob/develop/app/views/unattended/provisioning_templates/provision/freebsd_(mfsbsd)_provision.erb) in Foreman
* A custom mfsBSD image, can be build manually (see below) or [downloaded from here](https://github.com/fraenki/freebsd-foreman/releases)
* A working PXE/DHCP/TFTP boot environment (Foreman Smart Proxy)
* Server or VM needs at least 1 GB of RAM to store the image during installation

## Provision Instructions

* Create a "installation media" entry in Foreman for FreeBSD (use local or official mirror, e.g. `http://ftp.freebsd.org/pub/FreeBSD/releases/$arch/$major.$minor-RELEASE/`)
* Create a new "operating system" entry in Foreman for the desired FreeBSD release
* Copy the custom mfsBSD image to your TFTP server
* Create a new host in Foreman, watch the FreeBSD installation begin :)

## Build Instructions

Use `build.sh` to create your own images or to include a modified version of `rc.local`. The script must be run as root (on a FreeBSD server).

```
# git clone https://github.com/fraenki/freebsd-foreman.git
# cd freebsd-foreman
# ./build.sh -r 14.2
```

## More Examples

To use a local copy of the mfsbsd image instead of having the script download it, just specify the filename:

```
./build.sh -r 14.3 -f downloads/mfsbsd-14.3-RELEASE-p3-amd64.img
```

If no mfsBSD image is available for download, the script can try to automatically build it for the specified FreeBSD release:

```
./build.sh -r 14.3 -b
```

Please note that building mfsBSD requires more diskspace and will automatically install all required dependencies. Refer to [mfsBSD build instructions](https://github.com/mmatuska/mfsbsd/blob/master/BUILD.md) for further information.

Cleanup build/tmp directories:

```
./build.sh -c
```

## Acknowledgement

Thanks to Martin Matuška for creating [mfsBSD](https://mfsbsd.vx.sk/) and his talk on [Deploying FreeBSD systems with Foreman](https://blog.vx.sk/archives/60).

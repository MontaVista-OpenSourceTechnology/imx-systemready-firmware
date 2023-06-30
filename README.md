# i.MX8 ARM SystemReady Firmware

This repository contains a makefile and git submodules for building
firmware and optee applications for i.MX8M platform devices.
Currently only the the i.MX8M Quad EVK (imx8mq-evk, or MCIMX8M-EVK,
all the same device) is supported, but more may be added.

WARNING: This does not do trusted boot.  That should be added in the
future, but this builds an optee-capable firmware load for an i.MX8
target.

## Building

The standard builds from NXP are not SystemReady.  They build u-boot
with OPTEE enabled, but don't build OPTEE into the image, so when
u-boot tries to access EFI things it goes through OPTEE, which fails.
The trouble is that OPTEE is trying to access EFI variables through
u-boot, but that is not working on a default board, probably because
RPMB is not set up on the eMMC chip.

To work around this, this build puts EFI variables in a normal file.

### Necessary Host Packates

You will need some things on your host to build this.  On Ubuntu, run:

```
sudo apt install gcc-aarch64-linux-gnu
sudo apt install libusb-1.0-0-dev libbz2-dev libzstd-dev pkg-config
sudo apt install cmake libssl-dev g++
sudo apt install libgnutls28-dev
sudo apt install python3-pyelftools
```

There may be more.

### Setting Up For Your Build

After you check this this git repository out, you must run:

```
  git submodule init
  git submodule update
```

to get all the sources.  After that, just type `make` here and it will
build the firmware.  (Note that the first time, `make -j<n>` won't
work because it prompts you for EULA acceptance.)  In fact, `make
-j<n>` doesn't really work at all, that needs to be fixed.

The default build builds an imx8mq-evk target.  If you want to
override this, you can copy the make.config file to your own file,
modify it, and run make with `FW_CONFIG=<file>`.  There are other
configurable things like keys that you probably need to modify.

## Installing the firmware

Once the firmware is built, plug the USB-C and debug cables from your
computer into the MCIMX8M-EVK.  There is a two-switch DIP switch near
the debug port (the BOOT MODE switch) on the device.  The default
setting is "10", change it to "01" to allow programming the eMMC.
Then run:

```
  sudo ./uuu -b emmc imx-boot-imx8mq.bin
```

on the host.  It will burn the firmware into the eMMC device on the
board.  Change the DIP switch back to the default. and reset the
board.  It will then boot a SystemReady image on an SD card or USB
device.

I tested this booting a Yocto image built from
https://github.com/MontaVista-OpenSourceTechnology/opencgx-armsr and a
Rocky Linux image.

This information was pulled from all over the place in the NXP
documentation.  The most important was i.MX_Linux_Users_Guide.pdf, but
there were also the Quick Start Guide for the i.MX 8M Quad Evaluation
Kit, the i.MX 8M EVK Board Hardware User's Guide, and various forum
documentation.

## Installing the firmware from Linux

It took me a while to figure this out, but you can update the firmware
from Linux.  Basically, you do the following:

```
echo 0 > /sys/block/mmcblk0boot0/force_ro
dd if=imx-boot-imx8mq-0.3.bin of=/dev/mmcblk0boot0 bs=1024 seek=33 status=progress
sync
echo 1 > /sys/block/mmcblk0boot0/force_ro
```

I have learned that eMMC devices are not simple devices, there is all
kinds of strange stuff about them.  I used the web page at
https://developer.toradex.com/software/linux-resources/linux-features/emmc-linux/
for information on how these parts work.

## Installing and Running the OPTEE applications

WARNING: See the next section on keys, the default settings are insecure.

This is just a cursory introduction, and is no substitute for reading
https://optee.readthedocs.io/en/latest/index.html

I couldn't find this anywhere, I had to reverse engineer it from the code:

* You must create a /data/tee directory on your target system.  Logs and
  a target database go there.

* You must create a /lib/optee_armtz directory on the target.  The .ta
  files (trusted applications) go there.

The optee applications and tas are stored in the bin directory at the
root of the build.  You should copy the binaries onto your target
where they can be run and the .ta files into /lib/optee_armtz on the
target.  That way tee-supplicant can get to them.

And speaking of tee-supplicant, it is available for the target in
install/sbin/tee-supplicant.  You can copy that to your target and run
it as root to supply the REE client for OPTEE.  It (and the host
applications) are not compiled as dynamic executables, and thus need
no libraries.

Or, if you are using yocto, you can do the following to your
lcoal.conf:

```
IMAGE_INSTALL:append = " optee-client"
```

and it will be installed and run automatically.

# Keys

By default the optee default key is used to sign applications.  This
is insecure, anyone with that key can sign something and load it as a
trusted application.

The documentation at https://optee.readthedocs.io/en/latest/index.html
in the "Signing of TAs" section describes how to create your own keys.
The makefile here uses the same names, TA_PUBLIC_KEY and TA_SIGN_KEY,
as the optee build.  You can override these to provide your own key,
by default these point to the default one in optee.

# Building Your Own OPTEE Applications

The config.make file mentioned earlier is designed so you can build
your own OPTEE applications against this build.  To do this, in your
makefiles set:

```
FW_ROOT=<path to this directory>
include <path to the config.make file you are using>
```

To build an OPTEE application, use the standard format defined by
optee, probably by coping the examples, and make the TA with:

```
make $(KEYS) CROSS_COMPILE=$(CROSS_COMPILE) \
	PLATFORM=$(OPTEE_PLATORM) \
	TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR)
```

Build the host application with:

```
	make CROSS_COMPILE=$(CROSS_COMPILE) \
		TEEC_EXPORT=$(TEEC_EXPORT) --no-builtin-variables
```

You can look at the makefile here for details.  Then copy the
application and .ta file to the target as described earlier and run
the application.  It should automatically load your TA executable.
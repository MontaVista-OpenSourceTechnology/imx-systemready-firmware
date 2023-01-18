# i.MX8 ARM SystemReady Firmware

This repository contains a makefile and git submodules for building
firmware for i.MX8M platform devices.  Currently only the the i.MX8M
Quad EVK (imx8mq-evk, or MCIMX8M-EVK, all the same device) is
supported, but more may be added.

You will need some things on your host to build this.  On Ubuntu, run:
```
sudo apt install gcc-aarch64-linux-gnu
sudo apt install libusb-1.0-0-dev libbz2-dev libzstd-dev pkg-config
sudo apt install cmake libssl-dev g++
```
There may be more.

The standard builds from NXP are not SystemReady.  They build u-boot
with OPTEE enabled, but don't build OPTEE into the image, so when
u-boot tries to access EFI things it goes through OPTEE, which fails.
I tried building OPTEE per the insructions and adding it to the build,
but it still didn't work.  So this build just disabled OPTEE in
u-boot.

After you check this out, you must run:
```
  git submodule init
  git submodule update
```
to get all the sources.  After that, just type "make" here and it will
build the firmware.  (Note that the first time, "make -j<n>" won't
work because it prompts you for EULA acceptance.) Once the firmware is
built, plug the USB-C and debug cables from your computer into the
MCIMX8M-EVK.  There is a two-switch DIP switch near the debug port
(the BOOT MODE switch) on the device.  The default setting is "10",
change it to "01" to allow programming the eMMC.  Then run:
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
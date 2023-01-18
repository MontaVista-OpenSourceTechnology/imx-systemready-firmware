# i.MX8 ARM SystemReady Firmware

This repository contains a makefile and git submodules for building
firmware for i.MX8M platform devices.  Currently only the the i.MX8M
Quad EVK (imx8mq-evk, or MCIMX8M-EVK, all the same device) is
supported, but more may be added.

The standard builds from NXP are not SystemReady.  They build u-boot
with OPTEE enabled, but don't build OPTEE into the image, so when
u-boot tries to access EFI things it goes through OPTEE, which fails.

You should just type "make" here and it will build the firmware.  Once
the firmware is built, plug the USB-C and debug cables from your
computer into the MCIMX8M-EVK and run:

   sudo ./uuu -b emmc imx-boot-imx8mq.bin

It will burn the firmware into the eMMC device on the board.  It will
then boot a SystemReady image on an SD card or USB device.

I tested this booting a Yocto image built from
https://github.com/MontaVista-OpenSourceTechnology/opencgx-armsr and a
Rocky Linux image.
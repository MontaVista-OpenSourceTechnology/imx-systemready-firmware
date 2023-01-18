
all: binaries

clean: arm-tf-clean u-boot-clean mkimage-clean bin-clean

ROOT ?= $(shell pwd)

CROSS_COMPILE ?= aarch64-linux-gnu-

PLATFORM ?= imx8mq

ATF_PLATFORM = $(PLATFORM)
UBOOT_PLATFORM = $(PLATFORM)
DTB = $(PLATFORM)-evk.dtb
TARGET_BIN = imx-boot-$(PLATFORM).bin
MKIMAGE_SOC = iMX8M

FIRMWARE_VER = 8.15
FIRMWARE_URL = https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-$(FIRMWARE_VER).bin

UUU_URL = https://github.com/NXPmicro/mfgtools/releases/download/uuu_1.5.11/uuu

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= CROSS_COMPILE="$(CROSS_COMPILE)"

TF_A_PATH = $(ROOT)/imx-atf

TF_A_OUT = $(TF_A_PATH)/build/$(PLATFORM)/release

TF_A_FLAGS ?= \
        PLAT=$(ATF_PLATFORM)

arm-tf:
	$(TF_A_EXPORTS) $(MAKE) -C imx-atf $(TF_A_FLAGS) bl31

arm-tf-clean:
	$(TF_A_EXPORTS) $(MAKE) -C imx-atf $(TF_A_FLAGS) realclean

################################################################################
# u-boot
################################################################################
U-BOOT_PATH = $(ROOT)/uboot-imx
U-BOOT_BUILD ?= $(U-BOOT_PATH)/build

U-BOOT_DEFCONFIG_FILES := \
	$(U-BOOT_PATH)/configs/ \
        $(ROOT)/$(PLATFORM).config

U-BOOT_EXPORTS ?= \
        CROSS_COMPILE="$(CROSS_COMPILE)" \
        ARCH=arm64

U-BOOT_FLAGS = O=$(U-BOOT_BUILD) PLAT=$(PLATFORM)

u-boot:
	if test ! -e $(U-BOOT_BUILD); then mkdir $(U-BOOT_BUILD); fi
	if test ! -e $(U-BOOT_BUILD)/.config; then \
	  cp $(ROOT)/$(PLATFORM).config $(U-BOOT_BUILD)/.config; \
	fi
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) $(U-BOOT_FLAGS)

u-boot-clean:
	rm -rf $(U-BOOT_BUILD)

################################################################################
# Firmware files
################################################################################
FW_PATH = $(ROOT)/firmware-imx-$(FIRMWARE_VER)
firmware-imx-$(FIRMWARE_VER):
	wget $(FIRMWARE_URL)
	bash ./firmware-imx-$(FIRMWARE_VER).bin

################################################################################
# imx-mkimage
################################################################################
MKIMAGE_PATH = $(ROOT)/imx-mkimage
MKIMAGE_FLAGS = SOC=$(MKIMAGE_SOC) flash_evk_no_hdmi

mkimage: firmware-imx-$(FIRMWARE_VER)
	cp $(U-BOOT_BUILD)/tools/mkimage imx-mkimage/iMX8M/mkimage_uboot
	cp $(U-BOOT_BUILD)/spl/u-boot-spl.bin imx-mkimage/iMX8M
	cp $(U-BOOT_BUILD)/u-boot-nodtb.bin imx-mkimage/iMX8M
	cp $(U-BOOT_BUILD)/arch/arm/dts/$(DTB) imx-mkimage/iMX8M
	cp $(TF_A_PATH)/build/imx8mq/release/bl31.bin imx-mkimage/iMX8M
	cp $(FW_PATH)/firmware/hdmi/cadence/signed_hdmi_imx8m.bin imx-mkimage/iMX8M
	cp $(FW_PATH)/firmware/ddr/synopsys/lpddr4_pmu_train_1d_dmem.bin imx-mkimage/iMX8M
	cp $(FW_PATH)/firmware/ddr/synopsys/lpddr4_pmu_train_1d_imem.bin imx-mkimage/iMX8M
	cp $(FW_PATH)/firmware/ddr/synopsys/lpddr4_pmu_train_2d_dmem.bin imx-mkimage/iMX8M
	cp $(FW_PATH)/firmware/ddr/synopsys/lpddr4_pmu_train_2d_imem.bin imx-mkimage/iMX8M
	(cd $(MKIMAGE_PATH) && $(MAKE) $(MKIMAGE_FLAGS))
	cp $(MKIMAGE_PATH)/iMX8M/flash.bin $(TARGET_BIN)

MKIMAGE_COPIED = iMX8M/bl31.bin \
	iMX8M/imx8mq-evk.dtb \
	iMX8M/lpddr4_pmu_train_1d_dmem.bin \
	iMX8M/lpddr4_pmu_train_1d_imem.bin \
	iMX8M/lpddr4_pmu_train_2d_dmem.bin \
	iMX8M/lpddr4_pmu_train_2d_imem.bin \
	iMX8M/mkimage_uboot \
	iMX8M/signed_hdmi_imx8m.bin \
	iMX8M/u-boot-nodtb.bin \
	iMX8M/u-boot-spl.bin

mkimage-clean:
	(cd $(MKIMAGE_PATH) && $(MAKE) $(MKIMAGE_FLAGS) clean)
	for i in $(MKIMAGE_COPIED); do rm -f $(MKIMAGE_PATH)/$i; done


################################################################################
# 
################################################################################
uuu:
	wget $(UUU_URL)
	chmod +x uuu

################################################################################
# 
################################################################################
binaries: u-boot arm-tf mkimage uuu

bin-clean:
	rm -rf $(TARGET_BIN) $(FW_PATH) firmware-imx-$(FIRMWARE_VER).bin \
		uuu

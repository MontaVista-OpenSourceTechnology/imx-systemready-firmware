
all: binaries

clean: arm-tf-clean u-boot-clean mkimage-clean bin-clean optee-clean \
	optee-client-clean optee-examples-clean

realclean: clean
	rm -f $(FW_PATH) firmware-imx-$(FIRMWARE_VER).bin uuu

BUILDVER = 1.1

FW_ROOT ?= $(shell pwd)

# Override this to use you rown config file.
FW_CONFIG ?= $(FW_ROOT)/make.config

include $(FW_CONFIG)

# Where to put output binaries.  For optee-examples for now.
BIN_DIR ?= bin

ATF_PLATFORM = $(PLATFORM)
UBOOT_PLATFORM = $(PLATFORM)
UBOOT_DEFCONFIG = $(PLATFORM)_evk_defconfig
DTB = $(PLATFORM)-evk.dtb
TARGET_BIN = imx-boot-$(PLATFORM)-$(BUILDVER).bin

# Enable or disable OPTEE.  Enabling does work, but currently EFI
# variables are not stored in the TEE, so some hacking on the config
# has to be done.  That should be fixed at some point.
ENABLE_TEE = true

FIRMWARE_VER = 8.20
FIRMWARE_FILE = firmware-imx-$(FIRMWARE_VER).bin
FIRMWARE_URL = http://sources.buildroot.net/firmware-imx/$(FIRMWARE_FILE)

################################################################################
# ARM Trusted Firmware
################################################################################
TF_A_EXPORTS ?= CROSS_COMPILE="$(CROSS_COMPILE)"

TF_A_PATH = $(FW_ROOT)/imx-atf

TF_A_OUT = $(TF_A_PATH)/build/$(PLATFORM)/release/bl31.bin

TF_A_FLAGS ?= \
        PLAT=$(ATF_PLATFORM)

ifeq ($(ENABLE_TEE),true)
TF_A_FLAGS += SPD=opteed
endif

arm-tf:
	$(TF_A_EXPORTS) $(MAKE) -C imx-atf $(TF_A_FLAGS) bl31

arm-tf-clean:
	$(TF_A_EXPORTS) $(MAKE) -C imx-atf $(TF_A_FLAGS) realclean

################################################################################
# u-boot
################################################################################
U-BOOT_PATCHES = 
U-BOOT_DEFCONFIG_PATCHES = u-boot-config-disable-optee-efi-variable.patch
U-BOOT_PATH = $(FW_ROOT)/uboot-imx
U-BOOT_BUILD ?= $(U-BOOT_PATH)/build

U-BOOT_DEFCONFIG_FILES := \
	$(U-BOOT_PATH)/configs/ \
        $(FW_ROOT)/$(PLATFORM).config

U-BOOT_EXPORTS ?= \
        CROSS_COMPILE="$(CROSS_COMPILE)" \
        ARCH=arm64

U-BOOT_FLAGS = O=$(U-BOOT_BUILD) PLAT=$(PLATFORM)

u-boot-patches-applied:
	for i in $(U-BOOT_PATCHES); do \
		(cd $(U-BOOT_PATH); patch -p1 <../$$i); \
	done
	touch u-boot-patches-applied

u-boot: u-boot-patches-applied
	if test ! -e $(U-BOOT_BUILD); then mkdir $(U-BOOT_BUILD); fi
	if test ! -e $(U-BOOT_BUILD)/.config; then \
	    if $(ENABLE_TEE); then \
		$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) $(U-BOOT_FLAGS) $(UBOOT_DEFCONFIG); \
		for i in $(U-BOOT_DEFCONFIG_PATCHES); do \
			(cd $(U-BOOT_PATH); patch -p1 <../$$i); \
		done; \
	    else \
		 cp $(FW_ROOT)/$(PLATFORM).config $(U-BOOT_BUILD)/.config; \
	    fi \
	fi
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) $(U-BOOT_FLAGS)

u-boot-clean:
	rm -rf $(U-BOOT_BUILD)
	(cd $(U-BOOT_PATH); git reset --hard)
	rm -f u-boot-patches-applied

################################################################################
# Firmware files
################################################################################
FW_PATH = $(FW_ROOT)/firmware-imx-$(FIRMWARE_VER)
firmware-imx-$(FIRMWARE_VER):
#       IPv6 doesn't seem to work on this URL.
	wget -4 $(FIRMWARE_URL)
	bash ./firmware-imx-$(FIRMWARE_VER).bin

################################################################################
# optee
################################################################################
OPTEE_PATH = $(FW_ROOT)/imx-optee-os
OPTEE_FLAGS = PLATFORM=$(OPTEE_PLATFORM) $(KEYS)
OPTEE_OUT = $(OPTEE_PATH)/out/arm-plat-imx/core/tee-raw.bin

optee:
	make -C $(OPTEE_PATH) $(OPTEE_FLAGS)

optee-clean:
	make -C $(OPTEE_PATH) $(OPTEE_FLAGS) clean

################################################################################
# imx-mkimage
################################################################################
MKIMAGE_PATH = $(FW_ROOT)/imx-mkimage
MKIMAGE_FLAGS = SOC=$(MKIMAGE_SOC) flash_evk_no_hdmi

mkimage: firmware-imx-$(FIRMWARE_VER) #optee
	cp $(U-BOOT_BUILD)/tools/mkimage imx-mkimage/iMX8M/mkimage_uboot
	cp $(U-BOOT_BUILD)/spl/u-boot-spl.bin imx-mkimage/iMX8M
	cp $(U-BOOT_BUILD)/u-boot-nodtb.bin imx-mkimage/iMX8M
	cp $(U-BOOT_BUILD)/arch/arm/dts/$(DTB) imx-mkimage/iMX8M
	cp $(TF_A_OUT) imx-mkimage/iMX8M
	if $(ENABLE_TEE); then \
	    cp $(OPTEE_OUT) imx-mkimage/iMX8M/tee.bin; \
	else \
	    rm -f imx-mkimage/iMX8M/tee.bin; \
	fi
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
	iMX8M/u-boot-spl.bin \
	iMX8M/tee.bin

mkimage-clean:
	(cd $(MKIMAGE_PATH) && $(MAKE) clean)
	(for i in $(MKIMAGE_COPIED); do rm -f $(MKIMAGE_PATH)/$$i; done)


################################################################################
# uuu
################################################################################
uuu:
	(cd mfgtools && cmake .)
	(cd mfgtools && make)
	cp mfgtools/uuu/uuu .

uuu-clean:
	rm -f uuu
	(cd mfgtools && make clean)

################################################################################
# optee_client
################################################################################
optee-client:
	if test ! -e optee_client/build; then \
		mkdir optee_client/build && \
		(cd optee_client/build && \
		   cmake -DCMAKE_C_COMPILER=$(CROSS_COMPILE)gcc -DCMAKE_INSTALL_PREFIX=$(FW_ROOT)/$(INSTALL_DIR) ..) \
	fi
	(cd optee_client/build; make)
	(cd optee_client/build; make install)

optee-client-clean:
	rm -rf optee_client/build

################################################################################
# optee-examples
################################################################################
OPTEE_EXAMPLES = hello_world random acipher aes hotp secure_storage
optee-examples:
	mkdir -p $(FW_ROOT)/bin
	for i in $(OPTEE_EXAMPLES); do \
		(cd optee_examples/$$i/ta && \
		 make $(KEYS) CROSS_COMPILE=$(CROSS_COMPILE) \
	           PLATFORM=$(OPTEE_PLATORM) \
	           TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR) && \
		 cp *.ta $(FW_ROOT)/bin) \
	done
	for i in $(OPTEE_EXAMPLES); do \
		(cd optee_examples/$$i/host && \
		 make CROSS_COMPILE=$(CROSS_COMPILE) \
	           TEEC_EXPORT=$(TEEC_EXPORT) --no-builtin-variables && \
		 cp optee_example_$$i $(FW_ROOT)/bin); \
	done

optee-examples-clean:
	for i in $(OPTEE_EXAMPLES); do \
		(cd optee_examples/$$i/ta && \
		 make CROSS_COMPILE=$(CROSS_COMPILE) \
	           PLATFORM=$(OPTEE_PLATORM) \
	           TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR) \
		   clean) \
	done
	for i in $(OPTEE_EXAMPLES); do \
		(cd optee_examples/$$i/host && \
		 make CROSS_COMPILE=$(CROSS_COMPILE) \
	           TEEC_EXPORT=$(TEEC_EXPORT) --no-builtin-variables \
		   clean) \
	done
	rm -f optee_examples/*/ta/dyn_list

################################################################################
# Build everything
# firmware-imx is first so the EULA things is first.
################################################################################
binaries: firmware-imx-$(FIRMWARE_VER) \
	u-boot arm-tf optee mkimage uuu optee-client optee-examples

bin-clean:
	rm -rf uuu $(TARGET_BIN) $(INSTALL_DIR) $(BIN_DIR)

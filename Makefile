#
################################################################################
# @author  Ethan Huang <yongjie989@gmail.com>
# @version V1.0.1
# @date    2018/05/08
################################################################################
# @attention
#
# This file is part of OpenDrone. 
# Modified and reference to CleanFlight, Betaflight and iNAV
#
# OpenDrone are free software. You can redistribute
# this software and/or modify this software under the terms of the
# GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# OpenDrone are distributed in the hope that they
# will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this software.
#
# If not, see <http://www.gnu.org/licenses/>.
################################################################################

TARGET    ?= OPENDRONEBRH
DEBUG     ?=
OPTIONS   ?=
OPBL      ?= no
DEBUG_HARDFAULTS ?=
SERIAL_DEVICE   ?= $(firstword $(wildcard /dev/ttyUSB*) no-port-found)
FLASH_SIZE ?=

###############################################################################

FORKNAME      = OpenDrone
ROOT            := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR         = $(ROOT)/src/main
OBJECT_DIR      = $(ROOT)/obj/main
BIN_DIR         = $(ROOT)/obj
CMSIS_DIR       = $(ROOT)/lib/main/CMSIS
INCLUDE_DIRS    = $(SRC_DIR) \
                  $(ROOT)/src/main/target
LINKER_DIR      = $(ROOT)/src/main/target/link
TOOLS_DIR 		:= $(ROOT)/tools
DL_DIR    		:= $(ROOT)/downloads

###############################################################################

$(DL_DIR):
	mkdir -p $@
$(TOOLS_DIR):
	mkdir -p $@
include $(ROOT)/makes/build_verbosity.mk
include $(ROOT)/makes/system-id.mk
include $(ROOT)/makes/$(OSFAMILY).mk
include $(ROOT)/makes/tools.mk

###############################################################################

HSE_VALUE       = 8000000
FEATURES        =
ALT_TARGETS     = $(sort $(filter-out target, $(basename $(notdir $(wildcard $(ROOT)/src/main/target/*/*.mk)))))
OPBL_TARGETS    = $(filter %_OPBL, $(ALT_TARGETS))

VALID_TARGETS   = $(dir $(wildcard $(ROOT)/src/main/target/*/target.mk))
VALID_TARGETS  := $(subst /,, $(subst ./src/main/target/,, $(VALID_TARGETS)))
VALID_TARGETS  := $(VALID_TARGETS) $(ALT_TARGETS)
VALID_TARGETS  := $(sort $(VALID_TARGETS))

CLEAN_TARGETS = $(addprefix clean_,$(VALID_TARGETS) )
TARGETS_CLEAN = $(addsuffix _clean,$(VALID_TARGETS) )

ifeq ($(filter $(TARGET),$(ALT_TARGETS)), $(TARGET))
BASE_TARGET    := $(firstword $(subst /,, $(subst ./src/main/target/,, $(dir $(wildcard $(ROOT)/src/main/target/*/$(TARGET).mk)))))
-include $(ROOT)/src/main/target/$(BASE_TARGET)/$(TARGET).mk
else
BASE_TARGET    := $(TARGET)
endif

ifeq ($(filter $(TARGET),$(OPBL_TARGETS)), $(TARGET))
OPBL            = yes
endif

-include $(ROOT)/src/main/target/$(BASE_TARGET)/target.mk

ifeq ($(filter $(TARGET),$(VALID_TARGETS)),)
$(error Target '$(TARGET)' is not valid, must be one of $(VALID_TARGETS). Have you prepared a valid target.mk?)
endif

ifeq ($(filter $(TARGET), $(F3_TARGETS) ),)
$(error Target '$(TARGET)' has not specified a valid STM group, must be one of F1, F3, F405, F411, F427 or F7x. Have you prepared a valid target.mk?)
endif

256K_TARGETS  = $(F3_TARGETS)

ifeq ($(FLASH_SIZE),)
ifeq ($(TARGET),$(filter $(TARGET),$(256K_TARGETS)))
FLASH_SIZE = 256
else
$(error FLASH_SIZE not configured for target $(TARGET))
endif
endif

ifeq ($(DEBUG_HARDFAULTS),F3)
CFLAGS               += -DDEBUG_HARDFAULTS
STM32F30x_COMMON_SRC  = startup_stm32f3_debug_hardfault_handler.S
else
STM32F30x_COMMON_SRC  = startup_stm32f30x_md_gcc.S
endif

FC_VER_MAJOR := $(shell grep " FC_VERSION_MAJOR" src/main/build/version.h | awk '{print $$3}' )
FC_VER_MINOR := $(shell grep " FC_VERSION_MINOR" src/main/build/version.h | awk '{print $$3}' )
FC_VER_PATCH := $(shell grep " FC_VERSION_PATCH" src/main/build/version.h | awk '{print $$3}' )

FC_VER := $(FC_VER_MAJOR).$(FC_VER_MINOR).$(FC_VER_PATCH)

# Search path for sources
VPATH           := $(SRC_DIR):$(SRC_DIR)/startup
USBFS_DIR       = $(ROOT)/lib/main/STM32_USB-FS-Device_Driver
USBPERIPH_SRC   = $(notdir $(wildcard $(USBFS_DIR)/src/*.c))
FATFS_DIR       = $(ROOT)/lib/main/FatFS
FATFS_SRC       = $(notdir $(wildcard $(FATFS_DIR)/*.c))

CSOURCES        := $(shell find $(SRC_DIR) -name '*.c')

# for F3 targets
ifeq ($(TARGET),$(filter $(TARGET),$(F3_TARGETS)))
# Library
STDPERIPH_DIR   = $(ROOT)/lib/main/STM32F30x_StdPeriph_Driver
STDPERIPH_SRC   = $(notdir $(wildcard $(STDPERIPH_DIR)/src/*.c))
EXCLUDES        = stm32f30x_crc.c \
                  stm32f30x_can.c

STDPERIPH_SRC   := $(filter-out ${EXCLUDES}, $(STDPERIPH_SRC))
DEVICE_STDPERIPH_SRC = $(STDPERIPH_SRC)

VPATH           := $(VPATH):$(CMSIS_DIR)/CM1/CoreSupport:$(CMSIS_DIR)/CM1/DeviceSupport/ST/STM32F30x
CMSIS_SRC       = $(notdir $(wildcard $(CMSIS_DIR)/CM1/CoreSupport/*.c \
                  $(CMSIS_DIR)/CM1/DeviceSupport/ST/STM32F30x/*.c))

INCLUDE_DIRS    := $(INCLUDE_DIRS) \
                   $(STDPERIPH_DIR)/inc \
                   $(CMSIS_DIR)/CM1/CoreSupport \
                   $(CMSIS_DIR)/CM1/DeviceSupport/ST/STM32F30x

# VCP
ifneq ($(filter VCP, $(FEATURES)),)
INCLUDE_DIRS    := $(INCLUDE_DIRS) \
                   $(USBFS_DIR)/inc \
                   $(ROOT)/src/main/vcp

VPATH           := $(VPATH):$(USBFS_DIR)/src

DEVICE_STDPERIPH_SRC := $(DEVICE_STDPERIPH_SRC)\
                        $(USBPERIPH_SRC)
endif

ifneq ($(filter SDCARD, $(FEATURES)),)
INCLUDE_DIRS    := $(INCLUDE_DIRS) \
                   $(FATFS_DIR) \

VPATH           := $(VPATH):$(FATFS_DIR)
endif

# Flash Address
LD_SCRIPT       = $(LINKER_DIR)/stm32_flash_f303_$(FLASH_SIZE)k.ld

ARCH_FLAGS      = -mthumb -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16 -fsingle-precision-constant -Wdouble-promotion
DEVICE_FLAGS    = -DSTM32F303xC -DSTM32F303
TARGET_FLAGS    = -D$(TARGET)
endif

ifneq ($(BASE_TARGET), $(TARGET))
TARGET_FLAGS  := $(TARGET_FLAGS) -D$(BASE_TARGET)
endif

ifneq ($(FLASH_SIZE),)
DEVICE_FLAGS  := $(DEVICE_FLAGS) -DFLASH_SIZE=$(FLASH_SIZE)
endif

ifneq ($(HSE_VALUE),)
DEVICE_FLAGS  := $(DEVICE_FLAGS) -DHSE_VALUE=$(HSE_VALUE)
endif

TARGET_DIR     = $(ROOT)/src/main/target/$(BASE_TARGET)
TARGET_DIR_SRC = $(notdir $(wildcard $(TARGET_DIR)/*.c))

ifeq ($(OPBL),yes)
TARGET_FLAGS := -DOPBL $(TARGET_FLAGS)

ifeq ($(TARGET), $(filter $(TARGET),$(F3_TARGETS)))
LD_SCRIPT = $(LINKER_DIR)/stm32_flash_f303_$(FLASH_SIZE)k_opbl.ld
endif
.DEFAULT_GOAL := binary
else
.DEFAULT_GOAL := hex
endif

INCLUDE_DIRS    := $(INCLUDE_DIRS) \
                   $(ROOT)/lib/main/MAVLink

INCLUDE_DIRS    := $(INCLUDE_DIRS) \
                   $(TARGET_DIR)

VPATH           := $(VPATH):$(TARGET_DIR)

COMMON_SRC = \
            $(TARGET_DIR_SRC) \
            main.c \
            target/common_hardware.c \
            build/assert.c \
            build/build_config.c \
            build/debug.c \
            build/version.c \
            common/bitarray.c \
            common/crc.c \
            common/encoding.c \
            common/filter.c \
            common/maths.c \
            common/memory.c \
            common/printf.c \
            common/streambuf.c \
            common/time.c \
            common/typeconversion.c \
            common/string_light.c \
            config/config_eeprom.c \
            config/config_streamer.c \
            config/feature.c \
            config/parameter_group.c \
            drivers/adc.c \
            drivers/buf_writer.c \
            drivers/bus.c \
            drivers/bus_busdev_i2c.c \
            drivers/bus_busdev_spi.c \
            drivers/bus_i2c_soft.c \
            drivers/bus_spi.c \
            drivers/display.c \
            drivers/exti.c \
            drivers/gps_i2cnav.c \
            drivers/io.c \
            drivers/io_pca9685.c \
            drivers/light_led.c \
            drivers/logging.c \
            drivers/resource.c \
            drivers/rx_spi.c \
            drivers/rx_xn297.c \
            drivers/pitotmeter_adc.c \
            drivers/pwm_esc_detect.c \
            drivers/pwm_mapping.c \
            drivers/pwm_output.c \
            drivers/rcc.c \
            drivers/rx_pwm.c \
            drivers/serial.c \
            drivers/serial_uart.c \
            drivers/sound_beeper.c \
            drivers/stack_check.c \
            drivers/system.c \
            drivers/timer.c \
            drivers/lights_io.c \
            fc/cli.c \
            fc/config.c \
            fc/controlrate_profile.c \
            fc/fc_core.c \
            fc/fc_init.c \
            fc/fc_tasks.c \
            fc/fc_hardfaults.c \
            fc/fc_msp.c \
            fc/fc_msp_box.c \
            fc/rc_adjustments.c \
            fc/rc_controls.c \
            fc/rc_curves.c \
            fc/rc_modes.c \
            fc/runtime_config.c \
            fc/settings.c \
            fc/stats.c \
            flight/failsafe.c \
            flight/hil.c \
            flight/imu.c \
            flight/mixer.c \
            flight/pid.c \
            flight/pid_autotune.c \
            flight/servos.c \
            io/beeper.c \
            io/lights.c \
            io/pwmdriver_i2c.c \
            io/serial.c \
            io/serial_4way.c \
            io/serial_4way_avrootloader.c \
            io/serial_4way_stk500v2.c \
            io/statusindicator.c \
            io/rcdevice.c \
            io/rcdevice_cam.c \
            msp/msp_serial.c \
            rx/fport.c \
            rx/ibus.c \
            rx/jetiexbus.c \
            rx/msp.c \
            rx/uib_rx.c \
            rx/pwm.c \
            rx/rx.c \
            rx/rx_spi.c \
            rx/crsf.c \
            rx/sbus.c \
            rx/sbus_channels.c \
            rx/spektrum.c \
            rx/sumd.c \
            rx/sumh.c \
            rx/xbus.c \
            rx/eleres.c \
            scheduler/scheduler.c \
            sensors/acceleration.c \
            sensors/battery.c \
            sensors/temperature.c \
            sensors/boardalignment.c \
            sensors/compass.c \
            sensors/diagnostics.c \
            sensors/gyro.c \
            sensors/initialisation.c \
            uav_interconnect/uav_interconnect_bus.c \
            uav_interconnect/uav_interconnect_rangefinder.c \
            $(CMSIS_SRC) \
            $(DEVICE_STDPERIPH_SRC)

HIGHEND_SRC = \
            common/colorconversion.c \
            common/gps_conversion.c \
            drivers/rangefinder/rangefinder_vl53l0x.c \
            drivers/opflow/opflow_fake.c \
            drivers/opflow/opflow_virtual.c \
            drivers/vtx_common.c \
            io/opflow_cxof.c \
            io/dashboard.c \
            io/displayport_max7456.c \
            io/displayport_msp.c \
            io/gps.c \
            io/gps_ublox.c \
            io/gps_nmea.c \
            io/gps_naza.c \
            io/gps_i2cnav.c \
            io/osd.c \
            navigation/navigation.c \
            navigation/navigation_fixedwing.c \
            navigation/navigation_fw_launch.c \
            navigation/navigation_geo.c \
            navigation/navigation_multicopter.c \
            navigation/navigation_pos_estimator.c \
            sensors/barometer.c \
            sensors/pitotmeter.c \
            sensors/rangefinder.c \
            sensors/opflow.c \
            telemetry/crsf.c \
            telemetry/frsky.c \
            telemetry/hott.c \
            telemetry/ibus_shared.c \
            telemetry/ibus.c \
            telemetry/ltm.c \
            telemetry/mavlink.c \
            telemetry/msp_shared.c \
            telemetry/smartport.c \
            telemetry/telemetry.c \
            io/vtx_string.c \
            io/vtx_smartaudio.c \
            io/vtx_tramp.c \
            io/vtx_control.c


VCP_SRC = \
            vcp/hw_config.c \
            vcp/stm32_it.c \
            vcp/usb_desc.c \
            vcp/usb_endp.c \
            vcp/usb_istr.c \
            vcp/usb_prop.c \
            vcp/usb_pwr.c \
            drivers/serial_usb_vcp.c \
            drivers/usb_io.c

STM32F30x_COMMON_SRC = \
            startup_stm32f30x_md_gcc.S \
            target/system_stm32f30x.c \
            drivers/accgyro/accgyro.c \
            drivers/adc_stm32f30x.c \
            drivers/bus_i2c_stm32f30x.c \
            drivers/dma.c \
            drivers/gpio_stm32f30x.c \
            drivers/serial_uart_stm32f30x.c \
            drivers/system_stm32f30x.c \
            drivers/timer_stm32f30x.c

ifeq ($(TARGET),$(filter $(TARGET),$(F3_TARGETS)))
TARGET_SRC := $(STM32F30x_COMMON_SRC) $(TARGET_SRC)
endif

ifneq ($(filter ONBOARDFLASH,$(FEATURES)),)
TARGET_SRC += \
            drivers/flash_m25p16.c \
            io/flashfs.c
endif

ifeq ($(TARGET),$(filter $(TARGET),$(F3_TARGETS)))
TARGET_SRC += $(HIGHEND_SRC)
else ifneq ($(filter HIGHEND,$(FEATURES)),)
TARGET_SRC += $(HIGHEND_SRC)
endif

TARGET_SRC += $(COMMON_SRC)

ifneq ($(filter SDCARD,$(FEATURES)),)
TARGET_SRC += \
            io/asyncfatfs/asyncfatfs.c \
            io/asyncfatfs/fat_standard.c
endif

ifneq ($(filter VCP,$(FEATURES)),)
TARGET_SRC += $(VCP_SRC)
endif

# Search path and source files for the ST stdperiph library
VPATH        := $(VPATH):$(STDPERIPH_DIR)/src

###############################################################################
# Things that might need changing to use different tools
#

# Tool names
TOOLCHAINPATH = $(ARM_SDK_PREFIX)
CROSS_CC    = $(TOOLCHAINPATH)gcc
OBJCOPY     = $(TOOLCHAINPATH)objcopy
SIZE        = $(TOOLCHAINPATH)size

#
# Tool options.
#

ifeq ($(DEBUG),GDB)
OPTIMIZE    = -O0
LTO_FLAGS   = $(OPTIMIZE)
else
OPTIMIZE    = -Os
LTO_FLAGS   = -flto -fuse-linker-plugin $(OPTIMIZE)
endif

DEBUG_FLAGS = -ggdb3 -DDEBUG

CFLAGS      += $(ARCH_FLAGS) \
              $(LTO_FLAGS) \
              $(addprefix -D,$(OPTIONS)) \
              $(addprefix -I,$(INCLUDE_DIRS)) \
              $(DEBUG_FLAGS) \
              -std=gnu99 \
              -Wall -Wextra -Wunsafe-loop-optimizations -Wdouble-promotion \
              -Werror=switch \
              -ffunction-sections \
              -fdata-sections \
              $(DEVICE_FLAGS) \
              -DUSE_STDPERIPH_DRIVER \
              $(TARGET_FLAGS) \
              -D'__FORKNAME__="$(FORKNAME)"' \
              -D'__TARGET__="$(TARGET)"' \
              -save-temps=obj \
              -MMD -MP

ASFLAGS     = $(ARCH_FLAGS) \
              -x assembler-with-cpp \
              $(addprefix -I,$(INCLUDE_DIRS)) \
              -D$(TARGET) \
              -MMD -MP

LDFLAGS     = -lm \
              -nostartfiles \
              --specs=nano.specs \
              -lc \
              -lnosys \
              $(ARCH_FLAGS) \
              $(LTO_FLAGS) \
              $(DEBUG_FLAGS) \
              -static \
              -Wl,-gc-sections,-Map,$(TARGET_MAP) \
              -Wl,-L$(LINKER_DIR) \
              -Wl,--cref \
              -Wl,--no-wchar-size-warning \
              -T$(LD_SCRIPT)


# Define about .bin and .hex and compiler configuration
CPPCHECK        = cppcheck $(CSOURCES) --enable=all --platform=unix64 \
                  --std=c99 --inline-suppr --quiet --force \
                  $(addprefix -I,$(INCLUDE_DIRS)) \
                  -I/usr/include -I/usr/include/linux

#
# Things we will build
#
TARGET_BIN      = $(BIN_DIR)/$(FORKNAME)_$(FC_VER)_$(TARGET).bin
TARGET_HEX      = $(BIN_DIR)/$(FORKNAME)_$(FC_VER)_$(TARGET).hex
TARGET_ELF      = $(OBJECT_DIR)/$(FORKNAME)_$(TARGET).elf
TARGET_OBJS     = $(addsuffix .o,$(addprefix $(OBJECT_DIR)/$(TARGET)/,$(basename $(TARGET_SRC))))
TARGET_DEPS     = $(addsuffix .d,$(addprefix $(OBJECT_DIR)/$(TARGET)/,$(basename $(TARGET_SRC))))
TARGET_MAP      = $(OBJECT_DIR)/$(FORKNAME)_$(TARGET).map


CLEAN_ARTIFACTS := $(TARGET_BIN)
CLEAN_ARTIFACTS += $(TARGET_HEX)
CLEAN_ARTIFACTS += $(TARGET_ELF) $(TARGET_OBJS) $(TARGET_MAP)

# Make sure build date and revision is updated on every incremental build
$(OBJECT_DIR)/$(TARGET)/build/version.o : $(TARGET_SRC)

# Settings generator
.PHONY: .FORCE settings clean-settings
UTILS_DIR		= $(ROOT)/src/utils
SETTINGS_GENERATOR	= $(UTILS_DIR)/settings.rb
BUILD_STAMP		= $(UTILS_DIR)/build_stamp.rb
STAMP			= $(BIN_DIR)/build.stamp

GENERATED_SETTINGS	= $(SRC_DIR)/fc/settings_generated.h $(SRC_DIR)/fc/settings_generated.c
SETTINGS_FILE 		= $(SRC_DIR)/fc/settings.yaml
GENERATED_FILES		= $(GENERATED_SETTINGS)
$(GENERATED_SETTINGS): $(SETTINGS_GENERATOR) $(SETTINGS_FILE) $(STAMP)

$(STAMP): .FORCE
	$(V1) CFLAGS="$(CFLAGS)" TARGET=$(TARGET) ruby $(BUILD_STAMP) $(SETTINGS_FILE) $(STAMP)

# Use a pattern rule, since they're different than normal rules.
# See https://www.gnu.org/software/make/manual/make.html#Pattern-Examples
%generated.h %generated.c:
	$(V1) echo "*** start to compile work ***"
	$(V1) echo Setup the configuration
	$(V1) echo "settings.yaml -> settings_generated.h, settings_generated.c" "$(STDOUT)"
	$(V1) CFLAGS="$(CFLAGS)" TARGET=$(TARGET) ruby $(SETTINGS_GENERATOR) . $(SETTINGS_FILE)

settings-json:
	$(V0) CFLAGS="$(CFLAGS)" TARGET=$(TARGET) ruby $(SETTINGS_GENERATOR) . $(SETTINGS_FILE) --json settings.json

clean-settings:
	$(V1) $(RM) $(GENERATED_SETTINGS)

# List of buildable ELF files and their object dependencies.
# It would be nice to compute these lists, but that seems to be just beyond make.


$(TARGET_HEX): $(TARGET_ELF)
	@echo "Creating HEX $(TARGET_HEX)" "$(STDOUT)"
	$(V1) $(OBJCOPY) -O ihex --set-start 0x8000000 $< $@

$(TARGET_BIN): $(TARGET_ELF)
	$(V1) $(OBJCOPY) -O binary $< $@

$(TARGET_ELF): $(TARGET_OBJS)
	$(V1) echo Linking $(TARGET) , Please wait a moment...
	$(V1) $(CROSS_CC) -o $@ $(filter %.o, $^) $(LDFLAGS)
	$(V0) $(SIZE) $(TARGET_ELF)

# Compile
$(OBJECT_DIR)/$(TARGET)/%.o: %.c
	$(V1) mkdir -p $(dir $@)
	$(V1) echo "Compiling =>" $(notdir $<) "$(STDOUT)"  
	$(V1) $(CROSS_CC) -c -o $@ $(CFLAGS) $<

# Assemble
$(OBJECT_DIR)/$(TARGET)/%.o: %.s
	$(V1) mkdir -p $(dir $@)
	$(V1) echo %% $(notdir $<) "$(STDOUT)"
	$(V1) $(CROSS_CC) -c -o $@ $(ASFLAGS) $<

$(OBJECT_DIR)/$(TARGET)/%.o: %.S
	$(V1) mkdir -p $(dir $@)
	$(V1) echo %% $(notdir $<) "$(STDOUT)"
	$(V1) $(CROSS_CC) -c -o $@ $(ASFLAGS) $<


## all               : Build all valid targets
all: $(VALID_TARGETS)

$(VALID_TARGETS):
	$(V0) echo "" && \
	echo "Building $@" && \
	$(MAKE) -j 8 binary hex TARGET=$@ && \
	echo "Building $@ succeeded."

## clean             : clean up all temporary / machine-generated files
clean:
	$(V0) echo "Cleaning $(TARGET)"
	$(V0) rm -f $(CLEAN_ARTIFACTS)
	$(V0) rm -rf $(OBJECT_DIR)/$(TARGET)
	$(V0) rm -f $(GENERATED_SETTINGS)
	$(V0) echo "Cleaning $(TARGET) succeeded."

## clean_<TARGET>    : clean up one specific target
$(CLEAN_TARGETS) :
	$(V0) $(MAKE) -j 8 TARGET=$(subst clean_,,$@) clean

## clean_all         : clean all valid targets
clean_all:$(CLEAN_TARGETS)

## flash 		  : Flashing firmware into MCU
flash: 
	$(V0) echo "Flashing the firmware $(TARGET_BIN) to MCU"
	dfu-util -a0 -d 0x0483:0xdf11 -s 0x08000000:leave -D $(TARGET_BIN)

## binary		  : Create Binary firmware file for flash to MCU
binary:
	
	$(V0) echo "Creating BIN $(TARGET_BIN)"
	$(V1) $(OBJCOPY) -I ihex --output-target=binary $(TARGET_HEX) $(TARGET_BIN)

hex:    $(TARGET_HEX)

help: Makefile makes/tools.mk
	$(V0) @echo ""
	$(V0) @echo "Makefile for the $(FORKNAME) firmware"
	$(V0) @echo ""
	$(V0) @echo "Usage:"
	$(V0) @echo "        make [TARGET=<target>] [OPTIONS=\"<options>\"]"
	$(V0) @echo "Or:"
	$(V0) @echo "        make <target> [OPTIONS=\"<options>\"]"
	$(V0) @echo ""
	$(V0) @echo "Valid TARGET values are: $(VALID_TARGETS)"
	$(V0) @echo ""
	$(V0) @sed -n 's/^## //p' $?

## targets           : print a list of all valid target platforms (for consumption by scripts)
targets:
	$(V0) @echo "Valid targets:      $(VALID_TARGETS)"
	$(V0) @echo "Target:             $(TARGET)"
	$(V0) @echo "Base target:        $(BASE_TARGET)"


$(TARGET_OBJS) : Makefile | $(GENERATED_FILES) $(STAMP)

-include $(TARGET_DEPS)

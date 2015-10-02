########################################################################
# Makefile variables
########################################################################

FREERTOS_DIR = /home/samant/Git/freertos/FreeRTOS
FREERTOS_PORT = ATMega328
MCU = atmega328p
F_CPU = 16000000L

AVR_TOOLS_PATH = /usr/bin

########################################################################
# Toolchain Setup
########################################################################

CC_NAME      = avr-gcc
CXX_NAME     = avr-g++
OBJCOPY_NAME = avr-objcopy
OBJDUMP_NAME = avr-objdump
AR_NAME      = avr-ar
SIZE_NAME    = avr-size
NM_NAME      = avr-nm
AVRDUDE_NAME = avrdude

CC      = $(AVR_TOOLS_PATH)/$(CC_NAME)
CXX     = $(AVR_TOOLS_PATH)/$(CXX_NAME)
AS      = $(AVR_TOOLS_PATH)/$(AS_NAME)
OBJCOPY = $(AVR_TOOLS_PATH)/$(OBJCOPY_NAME)
OBJDUMP = $(AVR_TOOLS_PATH)/$(OBJDUMP_NAME)
AR      = $(AVR_TOOLS_PATH)/$(AR_NAME)
SIZE    = $(AVR_TOOLS_PATH)/$(SIZE_NAME)
NM      = $(AVR_TOOLS_PATH)/$(NM_NAME)
AVRDUDE = $(AVR_TOOLS_PATH)/$(AVRDUDE_NAME)

CPPFLAGS += \
	-mmcu=$(MCU) \
	-DF_CPU=$(F_CPU) \
	-D__PROG_TYPES_COMPAT__ \

CFLAGS += \
	-std=gnu99 \
	-ffunction-sections \
	-fdata-sections 	\
	-Wall \
	-Os

CXXFLAGS += \
	-ffunction-sections \
	-fdata-sections 	\
	-Wall \
	-fno-exceptions \
	-Os

LDFLAGS += \
	-mmcu=$(MCU) \
	-Wl,--gc-sections,-Map=$(TARGET).map,--cref \
	-Os

SIZEFLAGS += \
	--mcu=$(MCU) \
	-C

########################################################################
# FreeRTOS build
########################################################################

FREERTOS_SRC_DIR = $(FREERTOS_DIR)/Source
FREERTOS_MEMMANG_DIR = $(FREERTOS_SRC_DIR)/portable/MemMang
FREERTOS_PORT_DIR = $(FREERTOS_SRC_DIR)/portable/GCC/$(FREERTOS_PORT)
FREERTOS_SRCS = $(FREERTOS_SRC_DIR)/tasks.c $(FREERTOS_SRC_DIR)/queue.c $(FREERTOS_SRC_DIR)/list.c $(FREERTOS_MEMMANG_DIR)/heap_1.c $(wildcard $(FREERTOS_PORT_DIR)/*.c)
FREERTOS_OBJS = $(notdir $(FREERTOS_SRCS:.c=.o))

vpath %.c $(FREERTOS_SRC_DIR) $(FREERTOS_MEMMANG_DIR) $(FREERTOS_PORT_DIR)

FREERTOS_CPP_FLAGS = -I. -I$(FREERTOS_SRC_DIR)/include -I$(FREERTOS_PORT_DIR)

$(FREERTOS_OBJS): %.o: %.c
	$(CC) -MMD -c $(CPPFLAGS) $(FREERTOS_CPP_FLAGS) $(CFLAGS) $< -o $@

-include $(FREERTOS_OBJS:.o=.d)

########################################################################
# Local build
########################################################################

LOCAL_SRCS = $(wildcard *.c)
LOCAL_OBJS = $(notdir $(LOCAL_SRCS:.c=.o))

LOCAL_CPP_FLAGS = -I. -I$(FREERTOS_SRC_DIR)/include -I$(FREERTOS_PORT_DIR)

%.o: %.c
	$(CC) -MMD -c $(CPPFLAGS) $(LOCAL_CPP_FLAGS) $(CFLAGS) $< -o $@

-include $(LOCAL_OBJS:.o=.d)

TARGET = $(notdir $(CURDIR))
TARGET_HEX = $(TARGET).hex
TARGET_ELF = $(TARGET).elf
TARGET_EEP = $(TARGET).eep
TARGET_LSS = $(TARGET).lss

$(TARGET_ELF): 	$(LOCAL_OBJS) $(FREERTOS_OBJS)
	$(CC) $(LDFLAGS) -o $@ $(LOCAL_OBJS) $(FREERTOS_OBJS)

$(TARGET_HEX): $(TARGET_ELF)
	$(OBJCOPY) -O ihex -R .eeprom $< $@
	$(SIZE) $(SIZEFLAGS) --format=avr $<

$(TARGET_EEP): $(TARGET_ELF)
	$(OBJCOPY) -j .eeprom --set-section-flags=.eeprom="alloc,load" --change-section-lma .eeprom=0 --no-change-warnings -O ihex $< $@

$(TARGET_LSS): $(TARGET_ELF)
	$(OBJDUMP) -h --source --demangle --wide $< > $@

########################################################################
# Private declarations
########################################################################

all: $(TARGET_EEP) $(TARGET_HEX)

disassemble: $(TARGET_LSS)

upload: $(TARGET_EEP) $(TARGET_HEX)
	$(AVRDUDE) -p $(MCU) -c arduino -P /dev/ttyACM0 -D -b 115200 -U flash:w:$(TARGET_HEX):i 

clean:
	rm -rf *.o *.d *.elf *.lss *.hex *.eep *.map

print:
	@echo $(FREERTOS_SRCS)

.DEFAULT_GOAL := all
.PHONY : all clean print

UNAME := $(shell uname)
ARCH := $(shell uname -m)
ifneq (,$(filter $(ARCH), x86_64 amd64))
  X86-64 := 1
  X86_64 := 1
  AMD64 := 1
  ARCHFAMILY := x86_64
else
  ARCHFAMILY := $(ARCH)
endif

ifeq ($(UNAME), Linux)
  OSFAMILY := linux
  LINUX := 1
endif

ifndef OSFAMILY
  $(info uname reports $(UNAME))
  $(info uname -m reports $(ARCH))
  $(error failed to detect operating system)
endif

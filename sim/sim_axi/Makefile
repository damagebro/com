SHELL := /bin/bash
TARGET ?= dma
VALID_TARGETS := extd_wr extd_rd dma
ifeq ($(filter $(TARGET),$(VALID_TARGETS)),)
$(error TARGET must be one of: $(VALID_TARGETS))
endif
TC ?= sim_axi_$(TARGET)
RTL_F = ../rtl_$(TARGET).f
ENV_F = ../testbench.f
TOP_SV = ../tb/top_$(TARGET).sv
TOP = top_$(TARGET)
COM_OPT = -l ./compile.log -Mdir=./csrc -full64 -sverilog -timescale=1ns/100ps -debug_access+all -o simv +define+DUMP_FSDB
RUN_OPT = +vcs+initreg+0 +vcs+initmem+0 -l ./run.log +define+DUMP_FSDB
clean:
	rm -rf ./bin
	source ./ENV.sh
com:
	source ./ENV.sh; cd ./bin; vcs $(COM_OPT) -top $(TOP) -f $(RTL_F) -f $(ENV_F) $(TOP_SV) -assert svaext
run:
	source ./ENV.sh; cd ./bin; ./simv $(RUN_OPT) +TC_NAME=${TC}
all: clean com run

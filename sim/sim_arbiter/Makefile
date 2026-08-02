SHELL := /bin/bash
TC ?= sim_arbiter
RTL_F = ../rtl.f
ENV_F = ../testbench.f
COM_OPT = -l ./compile.log -Mdir=./csrc -full64 -sverilog -timescale=1ns/100ps -debug_access+all -o simv +define+DUMP_FSDB
RUN_OPT = +vcs+initreg+0 +vcs+initmem+0 -l ./run.log +define+DUMP_FSDB

clean:
	rm -rf ./bin
	source ./ENV.sh
com:
	source ./ENV.sh; cd ./bin; vcs $(COM_OPT) -top top -f $(RTL_F) -f $(ENV_F) -assert svaext
run:
	source ./ENV.sh; cd ./bin; ./simv $(RUN_OPT) +TC_NAME=${TC}
all: clean com run
cdns_com:
	source ./ENV.sh; cd ./bin; xrun -64bit -sv -access rwc -elaborate -top top -f $(RTL_F) -f $(ENV_F)

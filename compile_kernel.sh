set -e

function numa_make() {
	numactl -N 1 make -j $(($(nproc) / 2)) $@
}


# main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	make LSMOD=needed_mods localyesconfig
	./scripts/config --set-str LOCALVERSION '-gdb'
	./scripts/config -e GDB_SCRIPTS
	./scripts/config -e READABLE_ASM
	./scripts/config -e NF_CONNTRACK

	numa_make
	echo "===============================DONE: kernel========================================"
	numa_make compile_commands.json
	echo "===============================DONE: compile_commands.json========================="
	numa_make cscope
	echo "===============================DONE: cscope========================================"
fi

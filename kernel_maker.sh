set -ex

echo 'CONFIG_LOCALVERSION="-gdb"' >> .config
echo 'CONFIG_GDB_SCRIPTS=y' >> .config
echo 'CONFIG_READABLE_ASM=y' >> .config

nr_jobs=$(($(nproc)/2))
make --jobs=$nr_jobs LSMOD=needed_mods localyesconfig
make --jobs=$nr_jobs 
make --jobs=$nr_jobs compile_commands.json
make --jobs=$nr_jobs cscope


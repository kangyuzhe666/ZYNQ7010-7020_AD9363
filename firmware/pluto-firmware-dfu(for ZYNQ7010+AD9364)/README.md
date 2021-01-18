After the hardware is soldered, use xilinx sdk to burn, burn BOOT.bin first Enter dfu mode and use dfu-util to burn the firmware

sudo dfu-util -D boot.dfu -a boot.dfu

sudo dfu-util -D uboot-env.dfu -a uboot-env.dfu

sudo dfu-util -D pluto.dfu -a firmware.dfu
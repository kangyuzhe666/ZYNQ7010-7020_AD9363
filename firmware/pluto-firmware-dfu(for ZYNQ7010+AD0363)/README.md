硬件焊接好以后使用xilinx sdk进行烧录 先烧录BOOT.bin

进入dfu模式使用dfu-util烧录固件

sudo dfu-util -D boot.dfu -a boot.dfu

sudo dfu-util -D uboot-env.dfu -a uboot-env.dfu

sudo dfu-util -D pluto.dfu -a firmware.dfu
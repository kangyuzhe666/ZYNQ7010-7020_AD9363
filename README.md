# ZYNQ7010/7020_AD9363
####  基于ZYNQ+AD9363的开源SDR硬件

##### 1.硬件方案

FPGA:ZYNQ7010/7020(ZYNQ7010和ZYNQ7020可以相互代换，如需更多硬件资源请使用ZYNQ7020)

RF:AD9361/AD9363/AD9364(三款芯片可相互代换，区别在于频宽不同。其中AD9361性能更为优秀，尽量使用ABCZ结尾的芯片，区分于BBCZ)

内存：DDR3 256M16

USB-PHY: USB3320C

GMAC-PHY: RTL8211E-VL(RTL8211E有VB和VL两个结尾，其中VB电平为3.3V/2.5V,VL为1.8V)

QSPI FLASH: W25Q256 32MB

##### 2.软件资源

支持Pluto-SDR固件移植、OpenWiFi(需选用ZYNQ7020 FPGA)

##### 3.PCB板设计

设计软件：Altium Designer

层数：4层 （信号层[1]、power[2]、GND[3]、信号层[4]）

工艺：嘉立创工艺

阻抗：不支持

目前正在测试，bug情况未知，打板请谨慎。有问题可发邮件：1399109998@qq.com

![botten](images/botten.png)

![top](images/top.png)

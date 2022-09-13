# ZYNQ7010/7020_AD9363/AD9364/AD9361
![qq](images/qq.PNG)
## 初步开发工作已完成，产品进入试产阶段，有关成品购买事宜请联系邮箱：1399109998@qq.com 
## 2022-09-13更新正式支持openwifi
![a81](images/IMG_2371.JPG)
![a83](images/IMG_2753.JPG)
![a82](images/IMG_2754.JPG)
![a81](images/IMG_2747.JPG)
## 2r2t
![a81](images/IMG_2765.JPG)

####  基于ZYNQ+AD936X的开源SDR硬件

项目介绍视频：https://www.bilibili.com/video/BV1Di4y1c7ZW

GSM信号接收测试：https://www.bilibili.com/video/BV17U4y147Pg

FM接收测试：https://www.bilibili.com/video/BV13o4y1o7U2

正弦波发射测试：https://www.bilibili.com/video/BV1BK411g7GA

pluto-sdr固件移植工作全部完成，刷入固件无需操作系统默认就是AD9364。

关于BOM成本，ZYNQ7010/ZYN17020、AD9363在使用拆机芯片的情况下成本在150-200元左右。使用全新芯片由于数量较少没有议价能力BOM成本在500元左右。

#### 1.硬件方案

FPGA:ZYNQ7010/7020(ZYNQ7010和ZYNQ7020可以相互代换，如需更多硬件资源请使用ZYNQ7020)

RF:AD9361/AD9363/AD9364(三款芯片可相互代换，区别在于频宽不同。其中AD9361性能更为优秀，尽量使用ABCZ结尾的芯片，区分于BBCZ)

https://ez.analog.com/wide-band-rf-transceivers/design-support/f/q-a/80027/what-is-difference-of-ad9363-abcz-and-bbcz?ReplyOffsetId=179002&ReplyOffsetDirection=Next&ReplySortBy=CreatedDate&ReplySortOrder=Ascending&pifragment-7309=2

AD9363ABCZ Band: 325 MHz to 3.8 GHz

AD9363BBCZ Band: 650 MHz to 2.7 GHz

内存：DDR3 256M16

USB-PHY: USB3320C

GMAC-PHY: RTL8211E-VL(RTL8211E有VB和VL两个结尾，其中VB电平为3.3V/2.5V,VL为1.8V)

QSPI FLASH: W25Q256 32MB

电源拓扑

![power](images/power.png)

block design

![blockdesign](images/blockdesign.png)

#### 2.软件资源

支持Pluto-SDR固件移植、OpenWiFi(需选用ZYNQ7020 FPGA)、支持adi官方ZED+AD-FMCOMMS2/3/4相关固件代码

软件上支持MATLAB、GNU Radio、SDR sharp等

#### 3.PCB板设计

设计软件：Altium Designer

层数：4层 （信号层[1]、GND[2]、POWER[3]、信号层[4]）

工艺：嘉立创工艺

阻抗：不支持

阻抗版本将于2021年中旬测试，目前收发测试正常正在进行openwifi的移植。

#### 4. 不同于Pluto-SDR:

- 支持CLG400封装 XC7Z010 XC7Z020
- 支持2R2T收发模式
- 4层PCB设计成本低
- 支持SD卡可运行完整的Linux系统
- 支持千兆以太网

#### 5. 实物图片:

PCB渲染图

![2](images/grade.png)

PCBA实物图

![](images/IMG_8132.JPG)

射频部分细节

![](images/IMG_8133.JPG)

1000M以太网测试（测试环境为单臂路由）

![eth](images/500m.JPG)

AD9363初始化正常基于adi NO-OS测试环境

<img src="images/csh.png" alt="eth" style="zoom:50%;" />

Pluto-uboot移植成功

![eth](images/pluto-system.png)

Pluto固件工作正常

![](images/IMG_8016.PNG)

950MHZ GSM信号接收测试

![IMG_8017](images/iio.png)

AD9363破解成AD9364接收FM信号 

![pj](images/pj.png)

两块PCBA交互测试

![IMG_8018](images/IMG_8129.JPG)

两块PCBA可以堆叠通过千兆交换机和路由器进行与上位机的链接

![IMG_8018](images/IMG_8131.JPG)

SDR-SHARP测试

![sdrsharp](images/sdrsharp.jpg)

#### 6 TO DO LIST

-继续优化RF部分以达到adi官方演示板指标 

-基于四层PCB的阻抗设计 -将于2021年1月至2月完成，以完成openwifi的相关移植工作 

-在2021年3月设计阻抗版本 -在2021年4月对阻抗版本进行商业指标测试 

-商业版将于2021年4月底推出时，它将支持adi的官方SDR固件（ADRV9364数据包），openwifi和openbts openbts等。
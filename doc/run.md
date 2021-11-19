@page run_linux Running in Linux
# Run Guide
The Kahawai library required VFIO(IOMMU) and huge page to run, it also support non-root run thus it can be easily deployed within docker/k8s env.

## 1. System setup

#### 1.1 Enable IOMMU(VT-D and VT-X) in BIOS.

#### 1.2 Enable IOMMU in kernel
###### 1.2.1 Ubuntu/Debian:
Edit GRUB_CMDLINE_LINUX_DEFAULT item in /etc/default/grub file, append below parameters into GRUB_CMDLINE_LINUX_DEFAULT item.
```bash
intel_iommu=on iommu=pt
```
then:
```bash
update-grub
reboot
```
###### 1.2.2 Centos:
```bash
grubby --update-kernel=ALL --args="intel_iommu=on iommu=pt"
reboot
```

#### 1.3 Double check iommu_groups is created by kernel after reboot.
```bash
ls -l /sys/kernel/iommu_groups/
```

## 2. NIC setup:

#### 2.1 Update NIC FW and driver to latest version.
Refer to https://www.intel.com/content/www/us/en/download/15084/intel-ethernet-adapter-complete-driver-pack.html

#### 2.2 Bind NIC to DPDK PMD mode.
Below is the command to bind BDF 0000:af:00.0 to PF PMD mode, customize the BDF port as your setup.
```bash
sudo ./script/nicctl.sh bind_pmd 0000:af:00.0
```

## 3. Run the sample application:
#### 3.1 VFIO access for non-root run:
Add VFIO dev permissions to current user:
```bash
# change <USER> to the user name currently login.
sudo chown -R <USER>:<USER> /dev/vfio/
```

#### 3.2 Huge page setup:
e.g Enable 2048 2M huge pages, in total 4g memory.
```bash
sysctl -w vm.nr_hugepages=2048
```

#### 3.3 Prepare source files:
Pls note the input yuv source file for sample app is the yuv422YCBCR10be pixel group format, not ffmpeg yuv422p10be pixel format. Kahawai include a simple tools to convert the format.
###### 3.3.1 Convert yuv422p10be to yuv422YCBCR10be
Below is the command to convert yuv422p10be file to yuv422YCBCR10be pg format(ST2110-20 supported pg format for 422 10bit)
```bash
./build/app/ConvApp --width 1920 --height 1080 --in_pix_fmt yuv422p10be --out_pix_fmt yuv422YCBCR10be -i signal_be.yuv -o test.yuv
```
Below is the command to convert yuv422YCBCR10be pg format(ST2110-20 supported pg format for 422 10bit) to yuv422p10be file
```
./build/app/ConvApp --width 1920 --height 1080 --in_pix_fmt yuv422YCBCR10be --out_pix_fmt yuv422p10be  -i test.yuv -o signal_out.yuv
```

#### 3.4 PTP setup(optional):
Precision Time Protocol (PTP) provides global microsecond accuracy timing of all essences. Typical deployment include a PTP grandmaster within the network, and clients use tools(ex. ptp4l) to sync with the grandmaster. Kahawai library also include a built-in PTP implementation, sample app provide a option to enable it, see 3.6 for how to enable. The built-in PTP is disabled as default, Kahawai will use the system time source(clock_gettime) as PTP clock. If built-in PTP is enabled, Kahawai will select the internal NIC time as PTP source.

#### 3.5 Run sample app with json config
Below is the command to run one video tx/rx session with json config, customize the config item in json as your setup.
```bash
./build/app/RxTxApp --config_file config/test_tx_1port_1v.json
```
If it runs well, you will see below similar log output periodically.
```bash
ST: * *    S T    D E V   S T A T E   * *
ST: DEV(0): Avr rate, tx: 2638 Mb/s, rx: 0 Mb/s, pkts, tx: 2613182, rx: 80
ST: DEV(0): Status: imissed 0 ierrors 0 oerrors 0 rx_nombuf 0
ST: PTP(0), time 1636076300487864574, 2021-11-05 09:38:20
ST: PTP(0), mode l4, delta: avr 9477, min 8477, max 10568, cnt 10, avg 9477
ST: CNI(0): eth_rx_cnt 80
ST: TX_VIDEO_SESSION(0,0): fps 60.099933, pkts build 2593192 burst 2593192
ST: * *    E N D    S T A T E   * 
```
Then run a rx in another node/port.
```bash
./build/app/RxTxApp --config_file config/test_rx_1port_1v.json
```
If it runs well, you will see below similar log output periodically.
```bash
ST: * *    S T    D E V   S T A T E   * *
ST: DEV(0): Avr rate, tx: 0 Mb/s, rx: 2614 Mb/s, pkts, tx: 12, rx: 2589728
ST: DEV(0): Status: imissed 0 ierrors 0 oerrors 0 rx_nombuf 0
ST: PTP(0), time 1636075100571923971, 2021-11-05 09:18:20
ST: PTP(0), mode l2, delta: avr 7154, min -5806, max 10438, cnt 4, avg 6198
ST: CNI(0): eth_rx_cnt 52
ST: RX_VIDEO_SESSION(0,0): fps 59.899925, received frames 599, pkts 2589686
app_rx_video_stat(0), fps 59.899932, 599 frame received
ST: * *    E N D    S T A T E   * *
```
For the supported parameters in the json, please refer to [JSON configuration guide](configuration_guide.md) for detail.

#### 3.6 Available parameters in sample app
```bash
--config_file <URL>                  : the json config file path
--ptp                                : Enable the built-in Kahawai PTP, default is disabled and system time is selected as PTP time source
--lcores <lcore list>                : the DPDK lcore list for this run, e.g. --lcores 28,29,30,31. If not assigned, lib will allocate lcore from system socket cores.
--test_time <seconds>                : the run duration, unit: seconds
--ebu                                : debug option, enable timing check for video rx streams
--promiscuous                        : debug option, enable RX promiscuous( receive all data passing through it regardless of whether the destination address of the data) mode for NIC.
--cni_thread                         : debug option, use a dedicated thread for cni messages instead of tasklet
--sch_session_quota <count>          : debug option, max sessions count for one lcore, unit: 1080P 60FPS TX
--p_tx_dst_mac <mac>                 : debug option, destination MAC address for primary port, debug usage only
--r_tx_dst_mac <mac>                 : debug option, destination MAC address for redundant port, debug usage only
--log_level <level>                  : debug option, set log level. e.g. debug, info, warning, error
```

## 4. Tests:
Kahawai include many automate test cases based on gtest, below is the example command to run, customize the argument as your setup.
```bash
./build/tests/KahawaiTest --p_port 0000:af:00.0 --r_port 0000:af:00.1
```
BTW, the test required large huge page settings, pls expend it to 8g.
```bash
sysctl -w vm.nr_hugepages=4096
```

## 5. FAQs:
#### 5.1 Notes after reboot.
Sometimes after reboot, OS will update to a new kernel version, remember to rebuild the fw/DDP version.

#### 5.2 Notes for non-root run:
When running as non-root user, there may be some additional resource limits that are imposed by the system.

#### 5.2.1 RLIMIT_MEMLOCK:
RLIMIT_MEMLOCK (amount of pinned pages the process is allowed to have), if you see below error at Kahawai start up, it's likely caused by too small RLIMIT_MEMLOCK settings.
```
EAL: Cannot set up DMA remapping, error 12 (Cannot allocate memory)
EAL: 0000:af:01.0 DMA remapping failed, error 12 (Cannot allocate memory)
EAL: Requested device 0000:af:01.0 cannot be used
```
Pls
```bash
# Edit /etc/security/limits.conf, append below two lines at the end of file, change <USER> to the user name currently login.
<USER>    hard   memlock           unlimited
<USER>    soft   memlock           unlimited
reboot
```
After reboot, double check the limit is disabled.
```bash
ulimit -a | grep "max locked memory"
max locked memory       (kbytes, -l) unlimited
```

#### 5.3 BDF port not bind to DPDK PMD mode:
Below error indicate the port driver is not settings to DPDK PMD mode, run nicctl.sh to config it.
```bash
ST: st_dev_get_socket, failed to locate 0000:86:20.0. Please run nicctl.sh
```

#### 5.4 Hugepage not available
If you see below hugepage error when running, it's caused by neither 1G nor 2M huge page exist in current setup.
```bash
EAL: FATAL: Cannot get hugepage information.
EAL: Cannot get hugepage information.
```
Below error generally means mbuf pool create fail as no enough huge pages available, try to allocate more.
```bash
ST: st_init, mbuf_pool create fail
```

#### 5.5 No access to vfio device
Please add current user the access to the dev if below error message.
```bash
EAL: Cannot open /dev/vfio/147: Permission denied
EAL: Failed to open VFIO group 147
```

#### 5.6 Link not connected
Below error indicate the link of physical port is not connected to a network, pls confirm the cable link is working.
```bash
ST: dev_create_port(0), link not connected
```

#### 5.7 Bind BDF port back to kernel mode:
```bash
./script/nicctl.sh bind_kernel 0000:af:00.0
```
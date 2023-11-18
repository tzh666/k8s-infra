

## KVM（内核级虚拟化技术）

## Kernel-based Virtual Machine

### 一、安装准备

##### 1、勾选以下选项，再开机（勾选第一个也可）

<img src="C:\Users\Lenovo\AppData\Roaming\Typora\typora-user-images\image-20200822211256102.png" alt="image-20200822211256102" style="zoom: 67%;" />

##### 2、开启虚拟机之后查看是否支持虚拟化

```shell
#有的话就是支持全虚拟化技术（Intel 是 vmx，AMD 是svm，有其中一个即可）
[root@node1 ~]# grep -E '(vmx|svm)' /proc/cpuinfo 
flags           : fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 syscall nx mmxext fxsr_opt pdpe1gb rdtscp lm constant_tsc art rep_good nopl tsc_reliable nonstop_tsc extd_apicid eagerfpu pni pclmulqdq ssse3 fma cx16 sse4_1 sse4_2 x2apic movbe popcnt aes xsave avx f16c rdrand hypervisor lahf_lm svm extapic cr8_legacy abm sse4a misalignsse 3dnowprefetch osvw perfctr_core retpoline_amd ssbd ibpb vmmcall fsgsbase bmi1 avx2 smep bmi2 rdseed adx smap clflushopt clwb sha_ni xsaveopt xsavec clzero arat npt svm_lock nrip_save vmcb_clean flushbyasid decodeassists overflow_recov succor
#这样查看也行
[root@node1 ~]# lscpu | egrep Virtualization
Virtualization:        AMD-V
Virtualization type:   full
```

### 二、安装KVM

##### 1、安装

```shell
相关插件解释：

qemu-kvm ： kvm主程序， KVM虚拟化模块

virt-manager： KVM图形化管理工具

libvirt： 虚拟化服务

libguestfs-tools : 虚拟机的系统管理工具

virt-install ： 安装虚拟机的实用工具 。比如 virt-clone克隆工具就是这个包安装的

libvirt-python ： python调用libvirt虚拟化服务的api接口库文件

#安装qemu-kvm、libvirt够用
[root@node1 ~]# yum insyall -y qemu-kvm libvirt 
```

#####  2、启动

```shell
systemctl start libvirtd      （开启虚拟化服务）

systemctl enable libvirtd     （设置libvirtd服务开机自启）

systemctl is-enabled libvirtd （查看是不是开机自启）
```

##### 3、创建虚拟机

3.1、创建一块硬盘大小为5G、位置/名字 /kvm/Centos-7-x86_64.raw 

```shell
[root@node1 ~]# qemu-img create -f raw /kvm/Centos-7-x86_64.raw 5G
Formatting '/kvm/Centos-7-x86_64.raw', fmt=raw size=5368709120

#查看文件
[root@node1 kvm]# file Centos-7-x86_64.raw 
Centos-7-x86_64.raw: data
```

3.2、创建虚拟机（-cdrom=这个镜像要自备）

**第一种创建方式 ：virt-install**

```shell
[root@node1 ~]# virt-install --virt-type kvm --name Centos-7-x86_64 --ram 1024 --cdrom=/kvm/CentOS-7-x86_64-DVD-1810.iso --disk path=//kvm/Centos-7-x86_64.raw --network network=default --graphics vnc,listen=0.0.0.0 --noautoconsole                                               
#创建成功哈
Starting install...
Domain installation still in progress. You can reconnect to 
the console to complete the installation process.
```

3.3、输入安装命令用TightVNC Viewer连接，然后就是平时安装centos7的步骤！

3.4、启动KVM创建的centos7

```shell
#查看所以虚拟机
[root@node1 ~]# virsh list --all
 Id    Name                           State
----------------------------------------------------
 -     Centos-7-x86_64                shut off

#启动虚拟机
[root@node1 ~]# virsh start Centos-7-x86_64
Domain Centos-7-x86_64 started

#再次查看发现状态已经变成running
[root@node1 ~]# virsh list --all           
 Id    Name                           State
----------------------------------------------------
 2     Centos-7-x86_64                running
```

3.5、然后就可以再次通过TightVNC Viewer连接，进行相关配置

3.6、手动创建桥接网卡

```shell
#可以先把刚刚创建的虚拟机关机，然后创建桥接网卡 shutdown -h now
#查看已有网卡
[root@node1 ~]# brctl show
#新建网卡
[root@node1 ~]# brctl addbr br0
#添加到桥接----然后CTR就连接不上了哈哈哈
[root@node1 ~]# brctl addif br0 ens33
##以下是先删除原来的，设置新的ip、gw
```

![image-20200822232945079](C:\Users\Lenovo\AppData\Roaming\Typora\typora-user-images\image-20200822232945079.png)

3.7、编辑刚刚创建出来的虚拟机

```shell
#（实际上编辑的是xml文件，毕竟linux万物皆文件嘛）
[root@node1 ~]# virsh edit  Centos-7-x86_64  
```

**第二种创建方式：qemu-kvm**

```
# 自行准备 iso 镜像文件
[root@~ ~]#ls /mnt/iso/
CentOS-7-x86_64-DVD-1511.iso
 
# 安装 vnc 客户端 和 x11 需要的插件
[root@~ ~]#yum install tigervnc xorg-x11-xauth -y
[root@~ ~]#qemu-img create -f qcow2 -o size=20G,preallocation=metadata /images/Centos7.qcow2
[root@~ ~]#qemu-kvm -name 'centos7' -cpu host -smp 1 -m 1024m -drive file=/images/Centos7.qcow2 -cdrom /mnt/iso/CentOS-7-x86_64-DVD-1511.iso -daemonize
# 如果这里召唤不出界面，建议重新开启一个终端执行
[root@~ ~]#vncviewer :5900
```

**第三种创建方式：virt-manager**

```
virt-manager 是通过图形界面直接鼠标选择安装，这个不再演示。注意以下几个点：

　　（1）通过命令 virt-manager 无法唤出界面，需要安装 xorg-x11-xauth , 然后重新开启一个会话执行 virt-manger

　　（2）如果 virt-manager 出现乱码，需要安装 dejavu-sans-mono-fonts

　　（3）注意防火墙和 selinux
```

##### #virt-install参数

```shell
--name=xxx                        　　　　#虚拟机唯一名称
--memory=1024[,maxmemory=2048]    　　　　#虚拟机内存，单位为mb --memory=1024,maxmemory=2048
--vcpus=1[,maxvcpus=4]            　　　　#虚拟机CPU数量
--cdrom=/xxx/xxx                　　　　　#指定安装源文件
--location=/xxx/xxx                　　　 #指定安装源文件，跟--cdrom二选一，如果要用控制台安装得用这个，配合--extra-args参数
--disk path=/xx/xxx[,size=10,format=raw] #存储文件及格式
--graphics vnc,port=xxx,listen=xxx 　　　　#图形化参数，不用图形化用--graphics none --extra-args="console=ttyS0"
--network bridge=br0    　　　　　　　　　　#网络连接方式
--os-variant=xxx 　　　　　　　　　　　　　　#对应的系统值，可以osinfo-query os这个查对应值
--virt-type=kvm        　　　　　　　　　　　#虚拟机类型
--noautoconsole    　　　　　　　　　　　　#不自动连接，默认是安装时用virt-viewer或者virsh console去连接虚拟机
```

#####  把管理虚拟机的命令也写一下

```
virsh list --all    #查看所有虚拟机，加all列出关机状态的
virsh console xxx    #以控件台连接到指定虚拟机
virsh start xxx        #启动虚拟机
virsh shutdown xxx    #关闭虚拟机，一般关不了
virsh destroy xxx    #强制关闭虚拟机
virsh autostart xxx    #设置虚拟机随机启动
virsh undefine xxx    #删除虚拟机，只会删除对应的xml，硬盘文件不会删除
virsh autostart xxx    #设置虚拟机自动启动
```


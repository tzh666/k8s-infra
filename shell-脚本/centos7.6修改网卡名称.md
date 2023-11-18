## centos7.6修改网卡名称

### 一、查看版本号

```shell
[root@zabbix ~]# cat /etc/redhat-release 
CentOS Linux release 7.6.1810 (Core) 
```



### 二、修改步骤

#### 2.1、查看原来网卡名

```shell
[root@zabbix ~]# ip a
# 可以看到是ens33
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:f0:ac:5a brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.132/24 brd 192.168.1.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fef0:ac5a/64 scope link 
       valid_lft forever preferred_lft forever
```

#### 2.2、修改网卡配置文件

```shell
# 1、进到网卡目录
[root@zabbix ~]# cd /etc/sysconfig/network-scripts/

# 2、备份原来的网卡配置文件，以防万一
[root@zabbix network-scripts]# cp ifcfg-ens33 ifcfg-ens33_back

# 3、把NAME、DEVICE改为eth0
[root@zabbix network-scripts]# vim ifcfg-ens33
NAME=eth0
DEVICE=eth0

# 4、重命名网卡
[root@zabbix network-scripts]# mv ifcfg-ens33 ifcfg-eth0

# 5、编辑/etc/default/grub，在quiet后面加上net.ifnames=0 biosdevname=0（禁用网卡命名规则）
[root@zabbix ~]# cat /etc/default/grub | grep quiet
GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet net.ifnames=0 biosdevname=0"

# 6、创建自己的网卡接口命名规则 vim /etc/udev/rules.d/70-persistent-ipoib.rules添加内容如下一行（添加udev网卡规则）
[root@zabbix ~]# vim /etc/udev/rules.d/70-persistent-ipoib.rules
SUBSYSTEM=="net",ACTION=="add",DRIVERS=="?*",ATTR{address}=="需要修改名称的网卡MAC地址",ATTR｛type｝=="1",KERNEL=="eth*",NAME="eth0"


# 7、运行命令grub2-mkconfig -o /boot/grub2/grub.cfg 来重新生成GRUB配置并更新内核参数
[root@zabbix ~]# grub2-mkconfig -o /boot/grub2/grub.cfg
```

#### 2.3、重启Linux服务器后，查看是否更改成功

```shell
[root@zabbix ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
# 成功看到网卡名已经更改成功
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:f0:ac:5a brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.132/24 brd 192.168.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fef0:ac5a/64 scope link 
       valid_lft forever preferred_lft forever
```


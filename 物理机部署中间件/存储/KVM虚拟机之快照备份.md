# KVM虚拟机之快照备份

**KVM** **快照的定义：快照就是将虚机在某一个时间点上的磁盘、内存和设备状态保存一下，以备将来之用。它包括以下几类：**

（1）**磁盘快照**：磁盘的内容（可能是虚机的全部磁盘或者部分磁盘）在某个时间点上被保存，然后可以被恢复。

磁盘数据的保存状态：

​		在一个运行着的系统上，一个磁盘快照很可能只是崩溃一致的（crash-consistent） 而不是完整一致（clean）的，也是说它所保存的磁盘状态可能相当于机器突然掉电时硬盘数据的状态，机器重启后需要通过 fsck 或者别的工具来恢复到完整一致的状态（类似于 Windows 机器在断电后会执行文件检查）。(注：命令 qemu-img check -f qcow2 --output=qcow2 -r all filename-img.qcow2 可以对 qcow2 和 vid 格式的镜像做一致性检查。)

对一个非运行中的虚机来说，如果上次虚机关闭的时候磁盘是完整一致的，那么其被快照的磁盘快照也将是完整一致的。

磁盘快照有两种：

 	  **内部快照** - 使用单个的 qcow2 的文件来保存快照和快照之后的改动。这种快照是 libvirt 的默认行为，现在的支持很完善（创建、回滚和删除），但是只能针对 qcow2 格式的磁盘镜像文件，而且其过程较慢等。

  	 **外部快照** - 快照是一个只读文件，快照之后的修改是另一个 qcow2 文件中。外置快照可以针对各种格式的磁盘镜像文件。外置快照的结果是形成一个 qcow2 文件链：original <- snap1 <- snap2 <- snap3。

（2）**内存状态**（或者虚机状态）：只是保持内存和虚机使用的其它资源的状态。如果虚机状态快照在做和恢复之间磁盘没有被修改，那么虚机将保持一个持续的状态；如果被修改了，那么很可能导致数据corruption。

系统还原点（system checkpoint）：虚机的所有磁盘的快照和内存状态快照的集合，可用于恢复完整的系统状态（类似于系统休眠）。

​		**KVM的快照功能和VMware一样，可以实现热备和回滚的功能，在进行快照之前需要确保磁盘格式必须是QCOW2，因为RAW格式是不支持快照的。**

### 一、内存（状态）快照  virsh save   （不建议）

对运行中的 CentOS7运行 “virsh save” 命令。命令执行完成后，CentOS7变成 “shut off” 状态。

创建快照

```shell
#先查看虚拟机
[root@node1 ~]# virsh list --all
 Id    Name                           State
----------------------------------------------------
 1     Centos-7-x86_64                running

#创建备份目录
[root@node1 ~]# mkdir /kvm/backup -p
#备份
[root@node1 ~]# virsh save --bypass-cache Centos-7-x86_64  /kvm/backup/vm1_save --running

Domain Centos-7-x86_64 saved to /kvm/backup/vm1_save
#参数：
--bypass-cache  后面接虚拟机Name
/kvm/backup/vm1_save  保存的路径

#快照保存完成虚拟机会shut off
[root@node1 ~]# virsh list --all    
 Id    Name                           State
----------------------------------------------------
 -     Centos-7-x86_64                shut off
 
#跑刚刚的快照
[root@node1 ~]# virsh restore /kvm/backup/vm1_save
Domain restored from /kvm/backup/vm1_save
```

**内存数据被保存到 raw 格式的文件中。要恢复的时候，可以运行 “virsh restore /kvm/backup/vm1_save” 命令从保存的文件上恢复。**



### 二、磁盘快照  virsh snapshot-create-as

1.创建快照备份

```shell
[root@node1 ~]# virsh list --all
 Id    Name                           State
----------------------------------------------------
 2     Centos-7-x86_64                running

[root@node1 ~]# virsh snapshot-create-as --domain Centos-7-x86_64 --name snap-test1 --description "URL: www.test.com"
error: unsupported configuration: internal snapshot for disk vda unsupported for storage type raw
##失败了说明：如果磁盘类型raw不支持，就不能创建快照
```


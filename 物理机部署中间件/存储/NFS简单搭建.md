## NFS简单搭建

##### 服务端：192.168.47.191

##### 客户端：192.168.47.192

​    	NFS 是Network File System的缩写，即网络文件系统。一种使用于分散式文件系统的协定，由Sun公司开发，于1984年向外公布。**功能是通过网络让不同的机器、不同的操作系统能够彼此分享个别的数据，让应用程序在客户端通过网络访问位于服务器磁盘中的数据，是在类Unix系统间实现磁盘文件共享的一种方法。**

  	  NFS在文件传送或信息传送过程中依赖于RPC协议，RPC远程过程调用 (Remote Procedure Call) 是能使客户端执行其他系统中程序的一种机制，NFS本身是没有提供信息传输的协议和功能的。

 	   NFS应用场景，常用于高可用文件共享，多台服务器共享同样的数据，可扩展性比较差，本身高可用方案不完善，取而代之的数据量比较大的可以采用MFS、TFS、HDFS、GFS等等分布式文件系统。

```shell
NFS（网络文件系统）：让网络上的不同linux/unix系统机器实现文件共享
nfs本身只是一种文件系统，没有提供文件传递的功能，但却能让我们进行文件的共享，原因在于 NFS 使用RPC服务，用到NFS的地方都需要启动RPC服务，无论是NFS客户端还是服务端
nfs和rpc的关系：nfs是一个文件系统，负责管理分享的目录;rpc负责文件的传递
nfs启动时至少有rpc.nfsd和rpc.mountd2个daemon
rpc.nfsd主要是管理客户机登陆nfs服务器时，判断改客户机是否能登陆，和客户机ID信息。
Rpc.mountd主要是管理nfs的文件系统。当客户机顺利登陆nfs服务器时，会去读/etc/exports文件中的配置，然后去对比客户机的权限。
协议使用端口：
RPC：111 tcp/udp
nfsd：  2049 tcp/udp
mountd：RPC服务在 nfs服务启动时默认会为 mountd动态选取一个随机端口（32768--65535）来进行通讯 ，可以在/etc/nfsmount.conf文件中指定mountd的端口
```

### 一、服务端安装配置

1、NFS文件系统安装配置

```
[root@node1 ~]# yum  install  nfs-utils rpcbind  -y  
```

NFS安装完毕，需要创建共享目录，共享目录在vim  /etc/exports文件里面配置，可配置参数如下，在配置文件中添加如上一行，然后重启Portmap：

```shell
[root@node1 ~]# mkdir /data
[root@node1 ~]# chmod -Rf 777 /data/
[root@node1 ~]# vim /etc/exports
/data *(rw,no_root_squash,no_all_squash,insecure)
#生效配置
exportfs -r
[root@node1 ~]# systemctl restart rpcbind nfs
```

配置文件详解：

```shell
/data/            表示需要共享的目录。
IP                表示允许哪个客户端访问。
IP后括号里的设置表示对该共享文件的权限。
ro                只读访问 
rw                读写访问 
sync              所有数据在请求时写入共享 
all_squash        共享文件的UID和GID映射匿名用户anonymous，适合公用目录。 
no_all_squash     保留共享文件的UID和GID（默认） 
root_squash       root用户的所有请求映射成如anonymous用户一样的权限（默认） 
no_root_squash    root用户具有根目录的完全管理访问权限
```

查看 RPC 服务的注册状况

```shell
rpcinfo -p localhost
选项与参数：
-p ：针对某 IP (未写则预设为本机) 显示出所有的 port 与 porgram 的信息；
-t ：针对某主机的某支程序检查其 TCP 封包所在的软件版本；
-u ：针对某主机的某支程序检查其 UDP 封包所在的软件版本；
```

### 二、客户端安装配置

1、安装nfs-utils客户端

```
[root@node2 ~]# yum -y install nfs-utils
```

查看服务器抛出的共享目录信息

```shell
[root@node2 ~]# showmount -e 192.168.47.191
Export list for 192.168.47.191:
/data 192.168.47.*
```

Linux客户端，如何想使用这个NFS文件系统，需要在客户端挂载，挂载命令为（为了提高NFS的稳定性，使用TCP协议挂载，NFS默认用UDP协议）

```shell
[root@node2 ~]# mkdir /tst
[root@node2 ~]# mount -t nfs  192.168.47.191:/data /tst/  -o proto=tcp -o nolock
```

开启自动挂载，在/etc/fstab下加上如下配置：

```shell
[root@node2 ~]# echo '192.168.47.191:/data /tst  nfs  defaults  0 0 ' >>/etc/fstab
```

查看挂载结果：

```shell
[root@node2 ~]# df -h
Filesystem               Size  Used Avail Use% Mounted on
192.168.47.191:/data      17G  1.5G   16G   9% /tst
```

### 三、测试

1、在服务端新建文件

```
[root@node1 ~]# echo 'test nfs' > /data/a
```

2、在客户端查看

```
[root@node2 ~]# cat /tst/a 
test nfs
```


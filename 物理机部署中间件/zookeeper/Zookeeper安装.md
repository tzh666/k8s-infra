### Zookeeper安装

安装环境：

1. 系统：centos7.6
2. Java环境：JDK8

zookeeper安装需要java环境，怎么配置请看

```
https://www.cnblogs.com/hsyw/p/13203495.html
```

**1、下载zookeeper**

```
wget https://mirrors.bfsu.edu.cn/apache/zookeeper/zookeeper-3.5.8/apache-zookeeper-3.5.8-bin.tar.gz
```

**2、安装配置**

```shell
#规划好安装目录，方便日后搭建集群
mkdir /app/zktst -p
#把刚刚下载的安装包移动过来
mv apache-zookeeper-3.5.8-bin.tar.gz /app/zktst/
#解压
tar -zxvf apache-zookeeper-3.5.8-bin.tar.gz
#删除安装包，节省服务器磁盘空间
rm -rf apache-zookeeper-3.5.8-bin.tar.gz
#把/app/zktst/apache-zookeeper-3.5.8-bin移动到/app/zktst/
#再删除问价夹/apache-zookeeper-3.5.8-bin
cd /app/zktst/apache-zookeeper-3.5.8-bin
mv ./* ../ 
rm -rf apache-zookeeper-3.5.8-bin
```

做完之后的目录是这样的：

![image-20200628163122190](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20200628163122190.png)

**3、启动zookeeper准备**

```shell
#新建两个文件夹一个存数据，一个存日志
mkdir {data,logs}
#进到conf目录，把zoo_sample.cfg 复制一份改名为zoo.cfg
cd conf/	
cp zoo_sample.cfg zoo.cfg
#然后配置文件更改如下
[root@t1 conf]# grep -v ^"#" zoo.cfg 
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/app/zktst/data
dataLogDir=/app/zktst/logs
clientPort=2181
```

4、启动

```shell
#启动zookeeper，进去bin目录
[root@t1 bin]# ./zkServer.sh start
ZooKeeper JMX enabled by default
Using config: /app/zktst/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED
#查看状态
[root@t1 bin]# ./zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /app/zktst/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost.
Mode: standalone
#查看日志，进去logs目录
[root@t1 logs]# tail -f zookeeper-root-server-t1.out 
2020-06-28 17:09:30,705 [myid:] - INFO  [main:ServerCnxnFactory@135] - Using org.apache.zookeeper.server.NIOServerCnxnFactory as server connection factory
2020-06-28 17:09:30,707 [myid:] - INFO  [main:NIOServerCnxnFactory@673] - Configuring NIO connection handler with 10s sessionless connection timeout, 1 selector thread(s), 2 worker threads, and 64 kB direct buffers.
2020-06-28 17:09:30,709 [myid:] - INFO  [main:NIOServerCnxnFactory@686] - binding to port 0.0.0.0/0.0.0.0:2181
2020-06-28 17:09:30,733 [myid:] - INFO  [main:ZKDatabase@117] - zookeeper.snapshotSizeFactor = 0.33
2020-06-28 17:09:30,741 [myid:] - INFO  [main:FileTxnSnapLog@404] - Snapshotting: 0x0 to /app/zktst/data/version-2/snapshot.0
2020-06-28 17:09:30,744 [myid:] - INFO  [main:FileTxnSnapLog@404] - Snapshotting: 0x0 to /app/zktst/data/version-2/snapshot.0
2020-06-28 17:09:30,778 [myid:] - INFO  [main:ContainerManager@64] - Using checkIntervalMs=60000 maxPerMinute=10000
2020-06-28 17:10:46,179 [myid:] - INFO  [NIOWorkerThread-1:FourLetterCommands@234] - The list of known four letter word commands is : [{1936881266=srvr, 1937006964=stat, 2003003491=wchc, 1685417328=dump, 1668445044=crst, 1936880500=srst, 1701738089=envi, 1668247142=conf, -720899=telnet close, 2003003507=wchs, 2003003504=wchp, 1684632179=dirs, 1668247155=cons, 1835955314=mntr, 1769173615=isro, 1920298859=ruok, 1735683435=gtmk, 1937010027=stmk}]
2020-06-28 17:10:46,179 [myid:] - INFO  [NIOWorkerThread-1:FourLetterCommands@235] - The list of enabled four letter word commands is : [[srvr]]
2020-06-28 17:10:46,180 [myid:] - INFO  [NIOWorkerThread-1:NIOServerCnxn@518] - Processing srvr command from /127.0.0.1:50786
##日志无报错说明zk已经安排成功
```

**zoo.cfg文件参数详解**

```shell
tickTime这个时间是作为zookeeper服务器之间或客户端与服务器之间维持心跳的时间间隔,也就是说每个tickTime时间就会发送一个心跳。
initLimit这个配置项是用来配置zookeeper接受客户端（这里所说的客户端不是用户连接zookeeper服务器的客户端,而是zookeeper服务器集群中连接到leader的follower 服务器）初始化连接时最长能忍受多少个心跳时间间隔数。
当已经超过10个心跳的时间（也就是tickTime）长度后 zookeeper 服务器还没有收到客户端的返回信息,那么表明这个客户端连接失败。总的时间长度就是 10*2000=20秒。
syncLimit这个配置项标识leader与follower之间发送消息,请求和应答时间长度,最长不能超过多少个

tickTime的时间长度,总的时间长度就是5*2000=10秒。

dataDir zookeeper保存数据的目录,zookeeper将写数据的日志文件也保存在这个目录里；

logDir 日志文件目录，记录着zookeeper各种日志信息。

clientPort 默认端口号为2181
```


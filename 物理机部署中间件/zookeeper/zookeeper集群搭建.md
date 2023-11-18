### Zookeeper集群搭建

安装环境：

1. 系统：centos7.6
2. Java环境：JDK8
3. 关闭这三台机器的防火墙，sellinux
4. 主机188、189、190分别已经部署了单机的zk。单机安装请看我上一篇博客。

```shell
https://www.cnblogs.com/hsyw/p/13204017.html
```

**1、修改配置文件。在zoo.cfg配置文件新增（三台主机都操作）**

```shell
server.1=192.168.47.188:2888:3888
server.2=192.168.47.189:2888:3888
server.3=192.168.47.190:2888:3888
```

**2、创建ServerID标识**

```
2.1、在服务器192.168.47.188上的data目录下创建myid文件，并设置为1，同时保持跟zoo.cfg配置文件的server.1保持一致
[root@t3 data]# pwd
/app/zktst/data
echo 1 > myid
```

```
2.2、在服务器192.168.47.189上的data目录下创建myid文件，并设置为2，同时保持跟zoo.cfg配置文件的server.2保持一致
[root@t3 data]# pwd
/app/zktst/data
echo 2 > myid
```

```
2.3、在服务器192.168.47.190上的data目录下创建myid文件，并设置为3，同时保持跟zoo.cfg配置文件的server.3保持一致
[root@t3 data]# pwd
/app/zktst/data
echo 3 > myid
```

**3、分别启动三个zk节点，查看状态**

```shell
[root@t1 bin]# /app/zktst/bin/zkServer.sh start
ZooKeeper JMX enabled by default
Using config: /app/zktst/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED
#已经成功启动，然后去日志看看有没有报错
[root@t1 logs]# pwd
/app/zktst/logs
[root@t1 logs]# tail -f zookeeper-root-server-t1.out 
2020-06-29 11:46:07,589 [myid:2] - INFO  [QuorumPeer[myid=2](plain=[0:0:0:0:0:0:0:0]:2181)(secure=disabled):Learner@395] - Getting a snapshot from leader 0x1
2020-06-29 11:46:07,597 [myid:2] - INFO  [QuorumPeer[myid=2](plain=[0:0:0:0:0:0:0:0]:2181)(secure=disabled):Learner@546] - Learner received NEWLEADER message
2020-06-29 11:46:07,601 [myid:2] - INFO  [QuorumPeer[myid=2](plain=[0:0:0:0:0:0:0:0]:2181)(secure=disabled):FileTxnSnapLog@404] - Snapshotting: 0x1 to /app/zktst/data/version-2/snapshot.1
2020-06-29 11:46:07,638 [myid:2] - INFO  [QuorumPeer[myid=2](plain=[0:0:0:0:0:0:0:0]:2181)(secure=disabled):Learner@529] - Learner received UPTODATE message
2020-06-29 11:46:07,653 [myid:2] - INFO  [QuorumPeer[myid=2](plain=[0:0:0:0:0:0:0:0]:2181)(secure=disabled):CommitProcessor@256] - Configuring CommitProcessor with 1 worker threads.
2020-06-29 11:46:11,142 [myid:2] - INFO  [/192.168.47.189:3888:QuorumCnxManager$Listener@936] - Received connection request from /192.168.47.190:40920
2020-06-29 11:46:11,148 [myid:2] - INFO  [WorkerReceiver[myid=2]:FastLeaderElection@697] - Notification: 2 (message format version), 3 (n.leader), 0x0 (n.zxid), 0x1 (n.round), LOOKING (n.state), 3 (n.sid), 0x0 (n.peerEPoch), FOLLOWING (my state)0 (n.config version)
2020-06-29 11:46:11,153 [myid:2] - INFO  [WorkerReceiver[myid=2]:FastLeaderElection@697] - Notification: 2 (message format version), 1 (n.leader), 0x1 (n.zxid), 0x1 (n.round), LOOKING (n.state), 3 (n.sid), 0x0 (n.peerEPoch), FOLLOWING (my state)0 (n.config version)
2020-06-29 11:46:39,438 [myid:2] - WARN  [QuorumPeer[myid=2](plain=[0:0:0:0:0:0:0:0]:2181)(secure=disabled):Follower@125] - Got zxid 0x100000001 expected 0x1
2020-06-29 11:46:39,438 [myid:2] - INFO  [SyncThread:2:FileTxnLog@218] - Creating new log file: log.100000001
##也没报错。
#查看集群状态，我们可以看到188是leader节点，其余两台是follower节点。到此zk集群已经部署完毕。
#189
[root@t1 bin]# /app/zktst/bin/zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /app/zktst/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost.
Mode: leader
#199
[root@t2 logs]#/app/zktst/bin/zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /app/zktst/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost.
Mode: follower
#190
[root@t3 logs]# /app/zktst/bin/zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /app/zktst/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost.
Mode: follower
```

**4、测试连接**

```shell
#在188上操作
/app/zktst/bin/zkCli.sh 默认端口是2181，我们没改直接连接就可以了
#如果改了默认端口
./zkCli.sh -timeout 0 -r -server ip:port
./zkCli.sh -timeout 5000 -server 192.168.47.188:2181
-----------------
[zk: localhost:2181(CONNECTED) 2] create /node
Created /node
[zk: localhost:2181(CONNECTED) 3] create /node/tzh
Created /node/tzh
[zk: localhost:2181(CONNECTED) 4] ls /
[node, zookeeper]  
[zk: localhost:2181(CONNECTED) 5] set /node/tzh jiayou
[zk: localhost:2181(CONNECTED) 6] get /node/tzh
jiayou 
[zk: localhost:2181(CONNECTED) 7] quit
#在189上看看是否也有刚刚在188上新建的节点。
[zk: localhost:2181(CONNECTED) 1] ls /
[node, zookeeper]
[zk: localhost:2181(CONNECTED) 2] get /node/tzh
jiayou
#可以看到是有的说明我们的zk集群已经可以正常工作。 
```

**5、zkCli.sh的常用命令介绍**

```shell
-timeout
默认 -timeout 3000 
```

```shell
命令： ls 查看节点信息（ls2被弃用不做过多解释）
语法： ls [-s] [-w] [-R] path
例子：
#查看/node的下级节点
[zk: localhost:2181(CONNECTED) 4] ls -w /node
[tzh]
#列出层级节点
[zk: localhost:2181(CONNECTED) 5] ls -R /node
/node
/node/tzh
[zk: localhost:2181(CONNECTED) 6] ls -s /node
[tzh]cZxid = 0x100000006
ctime = Mon Jun 29 20:32:39 CST 2020
mZxid = 0x100000006
mtime = Mon Jun 29 20:32:39 CST 2020
pZxid = 0x100000007
cversion = 1
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 0
numChildren = 1
```

```shell
命令：connect #可以连接到另一台zkCli
语法：connect host:port
例子：connect 192.168.47.189:2181
```

```shell
命令：create #创建节点
语法：create [-s] [-e] [-c] [-t ttl] path [data] [acl]
例子：create /node 
-s: 表示节点为顺序节点
-e: 表示节点为临时节点
acl: 访问控制列表
```

```
命令：set #设置节点的数据或者修改节点数据
语法：set path date
例子：set /node/tzh tzh1
```

```shell
命令：get #查看节点数据
语法：get [-s] [-w] path
例子：get /node/tzh
```

```shell
命令：delete #删除节点、可理解单点删除
语法：delete [-v version] path
例子：delete /a/b #只删除了/b  /a 还在
```

```shell
命令：rmr （弃用）#删除多节点（递归节点--删除目录一样---全部删除）deleteall /a
语法：rmr path---------------deleteall /a
例子：rmr /a-----------------deleteall /a
#The command 'rmr' has been deprecated. Please use 'deleteall' instead.
```

```shell
命令：stat	#查看节点的详细信息 类似ls -s
语法：stat path [watch]
例子：stat /node
#说明
cZxid = 0x100000006  					节点被创建时的事物的ID
ctime = Mon Jun 29 20:32:39 CST 2020	创建时间
mZxid = 0x100000006						节点最后一次被修改时的事物的ID
mtime = Mon Jun 29 20:32:39 CST 2020	最后一次修改时间
pZxid = 0x100000007						子节点列表最近一次呗修改的事物ID
cversion = 1							子节点版本号
dataVersion = 0						 	数据版本号
aclVersion = 0							ACL版本号
ephemeralOwner = 0x0					创建临时节点的事物ID，持久节点事物为0
dataLength = 0							数据长度，每个节点都可保存数据
numChildren = 1							子节点的个数
```

```shell
命令：listquota path  #列出节点的限制     getAcl  获得节点的权限的列表
语法：listquota path					 getAcl   path
例子：listquota /node/tzh/a/			 getAcl  /node/tzh/a
```

```shell
命令：setAcl #设置节点权限
语法：setAcl [-s] [-v version] [-R] path acl
setAcl path acl
设置节点的权限
acl格式: schema:id:permision
schema: ip|digest|world|auth|
id: ip|userName:string|anyone|
permision: crwda #权限
c: create     创建子节点
r: read       获得节点数据和子节点列表
w: write      更新节点数据
d: delete     删除子节点
a: admin      设置节点的ACL
```

```shell
命令：delquota #删除节点权限
语法：delquota  [-n|-b] path
```

```shell
close #关闭连接，不退出客户端
quit  #关闭连接且退出客户端
```


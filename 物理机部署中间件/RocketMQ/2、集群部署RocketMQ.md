## RocketMQ集群部署

- 背景： 生产环境单机的MQ不具有高可用，所以我们应该部署成集群模式，这里给大家部署一个**双主双从异步复制的Broker集群**

### 一、单机部署、部署前提参考

```sh
https://www.cnblogs.com/hsyw/p/17428530.html
https://www.cnblogs.com/hsyw/p/17429834.html
```

### 二、集群部署

- 双主双从异步复制的Broker集群

- 集群角色划分如下

|   主机名   |      IP       |       功能        |     集群角色     |
| :--------: | :-----------: | :---------------: | :--------------: |
| slaveNode1 | 192.168.1.161 | NameServer+Broker | Master01+Slave02 |
| slaveNode2 | 192.168.1.162 | NameServer+Broker | Master02+Slave01 |

- #### 2.1 主要配置文件介绍

```sh
[root@slavenode1 conf]# pwd
/app/rocketmq/conf
[root@slavenode1 conf]# ll
total 36
drwxr-xr-x 2 root root   118 Mar 27 14:06 2m-2s-async        # 两主两从异步复制
drwxr-xr-x 2 root root   118 Mar 27 14:06 2m-2s-sync         # 两主两从同步复制
drwxr-xr-x 2 root root    91 Mar 27 14:06 2m-noslave         # 两主无从
-rw-r--r-- 1 root root   949 Mar 27 14:06 broker.conf
drwxr-xr-x 2 root root    72 Mar 27 14:06 dledger
-rw-r--r-- 1 root root 15398 Mar 27 14:06 logback_broker.xml
-rw-r--r-- 1 root root  3872 Mar 27 14:06 logback_namesrv.xml
-rw-r--r-- 1 root root  3797 Mar 27 14:06 logback_tools.xml
-rw-r--r-- 1 root root  1363 Mar 27 14:06 plain_acl.yml
-rw-r--r-- 1 root root   834 Mar 27 14:06 tools.yml

# 根据我们集群部署规划表，对应 【A主+B从】在slaveNode1节点，【B主+A从】在slaveNode2节点，这样就能保证高可用
[root@slavenode1 2m-2s-async]# pwd
/app/rocketmq/conf/2m-2s-async
[root@slavenode1 2m-2s-async]# ll
total 16
-rw-r--r-- 1 root root 929 Mar 27 14:06 broker-a.properties       # A主
-rw-r--r-- 1 root root 922 Mar 27 14:06 broker-a-s.properties     # A从
-rw-r--r-- 1 root root 929 Mar 27 14:06 broker-b.properties       # B主
-rw-r--r-- 1 root root 922 Mar 27 14:06 broker-b-s.properties     # B从
```

#### 2.2、修改slaveNode1节点上的配置文件

- 修改broker-a.properties：/app/rocketmq/conf/2m-2s-async/broker-a.properties
- 以下是完整的配置文件

```sh
# 默认的双主双从的大集群模式名字
brokerClusterName=DefaultCluster
# 双主双从里面的小集群名字broker-a
brokerName=broker-a
# brokerId=0表示 master节点，非0 slave节点
brokerId=0
# 指定删除消息存储过期的文件时间是凌晨4点
deleteWhen=04
# 指定未发生更新的消息存储文件的保留时长为 48 小时， 48 小时后过期，将会被删除
fileReservedTime=48
# 指定当前broker为异步复制master
brokerRole=ASYNC_MASTER
# 指定刷盘策略为异步刷盘
flushDiskType=ASYNC_FLUSH
# 指定Name Server的地址
namesrvAddr=192.168.1.161:9876;192.168.1.162:9876
```

- 修改broker-b-s.properties：/app/rocketmq/conf/2m-2s-async/broker-b-s.properties
- 以下是完整的配置文件

```sh
# 默认是大集群名字
brokerClusterName=DefaultCluster
# 指定这是另外一个master-slave集群
brokerName=broker-b
brokerId=1
deleteWhen=04
fileReservedTime=48
# 指定当前broker为slave
brokerRole=SLAVE
flushDiskType=ASYNC_FLUSH
# 指定Name Server的地址
namesrvAddr=192.168.1.161:9876;192.168.1.162:9876
# 指定Broker对外提供服务的端口，即Broker与producer与consumer通信的端口。默认10911 。由于当前主机同时充当着master1与slave2，而前面的master1使用的是默认端口。这里需要将这两个端口加以区分，以区分出master1与slave2
listenPort= 11911
# 指定消息存储相关的路径。默认路径为~/store目录。由于当前主机同时充当着master1与slave2，master1使用的是默认路径，这里就需要再指定一个不同路径
storePathRootDir=~/store-s
storePathCommitLog=~/store-s/commitlog
storePathConsumeQueue=~/store-s/consumequeue
storePathIndex=~/store-s/index
storeCheckpoint=~/store-s/checkpoint
abortFile=~/store-s/abort
```

- 除了以上配置外，这些配置文件中还可以设置其它属性。

```sh
#指定整个broker集群的名称，或者说是RocketMQ集群的名称
brokerClusterName=rocket-MS
#指定master-slave集群的名称。一个RocketMQ集群可以包含多个master-slave集群
brokerName=broker-a
#0 表示 Master，>0 表示 Slave
brokerId=0
#nameServer地址，分号分割
namesrvAddr=nameserver1:9876;nameserver2:9876
#默认为新建Topic所创建的队列数
defaultTopicQueueNums=4
#是否允许 Broker 自动创建Topic，建议生产环境中关闭
autoCreateTopicEnable=true
#是否允许 Broker 自动创建订阅组，建议生产环境中关闭
autoCreateSubscriptionGroup=true
#Broker对外提供服务的端口，即Broker与producer与consumer通信的端口
listenPort=10911
#HA高可用监听端口，即Master与Slave间通信的端口，默认值为listenPort+1
haListenPort=10912
#指定删除消息存储过期文件的时间为凌晨 4 点
deleteWhen=04
#指定未发生更新的消息存储文件的保留时长为 48 小时， 48 小时后过期，将会被删除
fileReservedTime=48
#指定commitLog目录中每个文件的大小，默认1G
mapedFileSizeCommitLog=1073741824
#指定ConsumeQueue的每个Topic的每个Queue文件中可以存放的消息数量，默认30w条
mapedFileSizeConsumeQueue=300000
#在清除过期文件时，如果该文件被其他线程所占用（引用数大于 0 ，比如读取消息），此时会阻止此次删除任务，同时在第一次试图删除该文件时记录当前时间戳。该属性则表示从第一次拒绝删除后开始计时，该文件最多可以保留的时长。在此时间内若引用数仍不为 0 ，则删除仍会被拒绝。不过时间到后，文件将被强制删除
destroyMapedFileIntervalForcibly=120000
#指定commitlog、consumequeue所在磁盘分区的最大使用率，超过该值，则需立即清除过期文件
diskMaxUsedSpaceRatio=88
#指定store目录的路径，默认在当前用户主目录中
storePathRootDir=/usr/local/rocketmq-all-4.5.0/store
#commitLog目录路径
storePathCommitLog=/usr/local/rocketmq-all-4.5.0/store/commitlog
#consumeueue目录路径
storePathConsumeQueue=/usr/local/rocketmq-all-4.5.0/store/consumequeue
#index目录路径
storePathIndex=/usr/local/rocketmq-all-4.5.0/store/index
#checkpoint文件路径
storeCheckpoint=/usr/local/rocketmq-all-4.5.0/store/checkpoint
#abort文件路径
abortFile=/usr/local/rocketmq-all-4.5.0/store/abort
#指定消息的最大大小
maxMessageSize= 65536
#Broker的角色
# - ASYNC_MASTER 异步复制Master
# - SYNC_MASTER 同步双写Master
# - SLAVE
brokerRole=SYNC_MASTER
#刷盘策略
# - ASYNC_FLUSH 异步刷盘
# - SYNC_FLUSH 同步刷盘
flushDiskType=SYNC_FLUSH
#发消息线程池数量
sendMessageThreadPoolNums=128
#拉消息线程池数量
pullMessageThreadPoolNums=128
#强制指定本机IP，需要根据每台机器进行修改。官方介绍可为空，系统默认自动识别，但多网卡时IP地址可能读取错误
brokerIP1=192.168.3.105
```

#### 2.3、修改slaveNode2节点上的配置文件

- 修改broker-b.properties，以下是全部配置文件

```sh
# vim /app/rocketmq/conf/2m-2s-async/broker-b.properties
brokerClusterName=DefaultCluster
brokerName=broker-b
brokerId=0
deleteWhen=04
fileReservedTime=48
brokerRole=ASYNC_MASTER
flushDiskType=ASYNC_FLUSH
# 增加这个
namesrvAddr=192.168.1.161:9876;192.168.1.162:9876
```

- 修改broker-a-s.properties

```sh
brokerClusterName=DefaultCluster
brokerName=broker-a
brokerId=1
deleteWhen=04
fileReservedTime=48
brokerRole=SLAVE
flushDiskType=ASYNC_FLUSH
namesrvAddr=192.168.1.161:9876;192.168.1.162:9876
listenPort=11911
storePathRootDir=~/store-s
storePathCommitLog=~/store-s/commitlog
storePathConsumeQueue=~/store-s/consumequeue
storePathIndex=~/store-s/index
storeCheckpoint=~/store-s/checkpoint
abortFile=~/store-s/abort
```

#### 2.4、启动集群

- 启动NameServer集群，两个节点上都执行

```sh
# 前台启动
/app/rocketmq/bin/mqnamesrv

# 后台启动，确认无错误日志可以改后台启动
nohup sh bin/mqnamesrv &
```

- 启动两个Master
  - 分别启动两个主机中的broker master。**注意，它们指定所要加载的配置文件是不同的。**

```sh
# slaveNode1上
cd /app/rocketmq/
sh bin/mqbroker -c conf/2m-2s-async/broker-a.properties

# 后台启动
nohup sh bin/mqbroker -c conf/2m-2s-async/broker-a.properties &
tail -f ~/logs/rocketmqlogs/broker.log
```

```sh
# slaveNode2上
cd /app/rocketmq/
sh bin/mqbroker -c conf/2m-2s-async/broker-b.properties

# 后台启动
nohup sh bin/mqbroker -c conf/2m-2s-async/broker-b.properties &
tail -f ~/logs/rocketmqlogs/broker.log
```

- 启动两个Slave
  - 分别启动两个主机中的broker slave。**注意，它们指定所要加载的配置文件是不同的。**

```sh
# slaveNode1上
cd /app/rocketmq/
sh bin/mqbroker -c conf/2m-2s-async/broker-b-s.properties

# 后台启动
nohup sh bin/mqbroker -c conf/2m-2s-async/broker-b-s.properties &
tail -f ~/logs/rocketmqlogs/broker.log
```

```sh
# slaveNode2上
cd /app/rocketmq/
sh bin/mqbroker -c conf/2m-2s-async/broker-a-s.properties

# 后台启动
nohup sh bin/mqbroker -c conf/2m-2s-async/broker-a-s.properties &
tail -f ~/logs/rocketmqlogs/broker.log
```

#### 2.5、mqadmin命令

在mq解压目录的bin目录下有一个mqadmin命令，该命令是一个运维指令，用于对mq的主题，集群，broker 等信息进行管理。

- 修改bin/tools.sh

在运行mqadmin命令之前，先要修改mq解压目录下bin/tools.sh配置的JDK的ext目录位置。本机的ext目录在`/usr/java/jdk1.8.0_161/jre/lib/ext`

使用vim命令打开tools.sh文件，并在JAVA_OPT配置的-Djava.ext.dirs这一行的后面添加ext的路径。

```sh
# 不知道在哪里可以直接find
[root@slavenode1 bin]# find / -name ext
cd /usr/local/jdk1.8.0_221/jre/lib/ext

# [root@slavenode1 ext]# cd /app/rocketmq/bin/
JAVA_OPT="${JAVA_OPT} -server -Xms1g -Xmx1g -Xmn256m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=128m"
# 在这 "/lib/ext:" 后面加上/usr/local/jdk1.8.0_221/jre/lib/ext，或者加上一整行
JAVA_OPT="${JAVA_OPT} -Djava.ext.dirs=${BASE_DIR}/lib:${JAVA_HOME}/jre/lib/ext:${JAVA_HOME}/lib/ext:/usr/local/jdk1.8.0_221/jre/lib/ext"
JAVA_OPT="${JAVA_OPT} -cp ${CLASSPATH}"
```

```sh
[root@slavenode1 bin]# ./mqadmin
The most commonly used mqadmin commands are:
   updateTopic          Update or create topic
   deleteTopic          Delete topic from broker and NameServer.
   updateSubGroup       Update or create subscription group
   deleteSubGroup       Delete subscription group from broker.
   updateBrokerConfig   Update broker's config
   updateTopicPerm      Update topic perm
   topicRoute           Examine topic route info
   topicStatus          Examine topic Status info
   topicClusterList     get cluster info for topic
   brokerStatus         Fetch broker runtime status data
   queryMsgById         Query Message by Id
   queryMsgByKey        Query Message by Key
   queryMsgByUniqueKey  Query Message by Unique key
   queryMsgByOffset     Query Message by offset
   queryMsgTraceById    query a message trace
   printMsg             Print Message Detail
   printMsgByQueue      Print Message Detail
   sendMsgStatus        send msg to broker.
   brokerConsumeStats   Fetch broker consume stats data
   producerConnection   Query producer's socket connection and client version
   consumerConnection   Query consumer's socket connection, client version and subscription
   consumerProgress     Query consumers's progress, speed
   consumerStatus       Query consumer's internal data structure
   cloneGroupOffset     clone offset from other group.
   producer             Query producer's instances, connection, status, etc.
   clusterList          List all of clusters
   topicList            Fetch all topic list from name server
   updateKvConfig       Create or update KV config.
   deleteKvConfig       Delete KV config.
   wipeWritePerm        Wipe write perm of broker in all name server you defined in the -n param
   addWritePerm         Add write perm of broker in all name server you defined in the -n param
   resetOffsetByTime    Reset consumer offset by timestamp(without client restart).
   skipAccumulatedMessage Skip all messages that are accumulated (not consumed) currently
   updateOrderConf      Create or update or delete order conf
   cleanExpiredCQ       Clean expired ConsumeQueue on broker.
   deleteExpiredCommitLog Delete expired CommitLog files
   cleanUnusedTopic     Clean unused topic on broker.
   startMonitoring      Start Monitoring
   statsAll             Topic and Consumer tps stats
   allocateMQ           Allocate MQ
   checkMsgSendRT       check message send response time
   clusterRT            List All clusters Message Send RT
   getNamesrvConfig     Get configs of name server.
   updateNamesrvConfig  Update configs of name server.
   getBrokerConfig      Get broker config by cluster or special broker!
   getConsumerConfig    Get consumer config by subscription group name!
   queryCq              Query cq command.
   sendMessage          Send a message
   consumeMessage       Consume message
   updateAclConfig      Update acl config yaml file in broker
   deleteAclConfig      Delete Acl Config Account in broker
   clusterAclConfigVersion List all of acl config version information in cluster
   updateGlobalWhiteAddr Update global white address for acl Config File in broker
   getAclConfig         List all of acl config information in cluster
   exportMetadata       export metadata
   exportConfigs        export configs
   exportMetrics        export metrics
```

#### 2.6、集群验证

- 发送消息测试

```sh
[root@masternode1 ~]# cd /app/rocketmq/
[root@masternode1 ~]# export NAMESRV_ADDR=localhost:9876

# 成功执行以后会发送1000条测试数据，执行成功脚本自动推出
[root@masternode1 ~]# sh bin/tools.sh org.apache.rocketmq.example.quickstart.Producer
# 成功最后的两行日志
07:06:35.589 [NettyClientSelector_1] INFO RocketmqRemoting - closeChannel: close the connection to remote address[127.0.0.1:9876] result: true
07:06:35.596 [NettyClientSelector_1] INFO RocketmqRemoting - closeChannel: close the connection to remote address[192.168.1.160:10911] result: true
```

- 接收消息

```sh
# 会接受上面发送的1000条数据
[root@masternode1 rocketmq]# sh bin/tools.sh org.apache.rocketmq.example.quickstart.Consumer
```

### 至此集群搭建完毕，可以部署一个可视化页面管理我们的集群，参考单机部署MQ的文档中的链接即可


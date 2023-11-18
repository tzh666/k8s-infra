## 容器化部署RocketMQ4.9.4集群

- 背景： 生产环境单机的MQ不具有高可用，所以我们应该部署成集群模式，这里给大家部署一个**双主双从异步复制的Broker集群**

### 一、安装docker 

```sh
yum install -y docker
systemctl enable docker --now
```

```sh
# 单机部署参考：
https://www.cnblogs.com/hsyw/p/17429834.html
```



### 二、集群部署

#### 2.1、基础概念介绍

- 单节点 :
  优点：本地开发测试，配置简单，同步刷盘消息一条都不会丢
  缺点：不可靠，如果宕机，会导致服务不可用

- 主从(异步、同步双写) :
  优点：同步双写消息不丢失, 异步复制存在少量丢失 ，主节点宕机，从节点可以对外提供消息的消费，但是不支持写入
  缺点：主备有短暂消息延迟，毫秒级，目前不支持自动切换，需要脚本或者其他程序进行检测然后进行停止broker,
  重启让从节点成为主节点

- 双主：
  优点：配置简单, 可以靠配置RAID磁盘阵列保证消息可靠，异步刷盘丢失少量消息
  缺点: master机器宕机期间，未被消费的消息在机器恢复之前不可消费，实时性会受到影响

- **双主双从，多主多从模式（异步复制）我们这里采用这种**
  **优点：磁盘损坏，消息丢失的非常少，消息实时性不会受影响，Master 宕机后，消费者仍然可以从Slave消费**
  **缺点：主备有短暂消息延迟，毫秒级，如果Master宕机，磁盘损坏情况，会丢失少量消息**

- 双主双从，多主多从模式（同步双写）
  优点：同步双写方式，主备都写成功，向应用才返回成功，服务可用性与数据可用性都非常高
  缺点：性能比异步复制模式略低，主宕机后，备机不能自动切换为主机

----

- 概念
  rocketmq分为Name Server和Broker Server

- 名字服务（Name Server）
  名称服务充当路由消息的提供者。生产者或消费者能够通过名字服务查找各主题相应的Broker IP列表。多个Namesrv实例组成集群，但相互独立，没有信息交换。
  是Topic路由注册中心，端口默认为9876

- 代理服务器（Broker Server）
  消息中转角色，负责存储消息、转发消息。代理服务器在RocketMQ系统中负责接收从生产者发送来的消息并存储、同时为消费者的拉取请求作准备。代理服务器也存储消息相关的元数据，包括消费者组、消费进度偏移和主题和队列消息等。

- 端口有三个
  listenPort：默认10911，接受客户端连接的监听端口，作为对producer和consumer使用服务的端口号，可以通过配置文件改
  haListenPort：默认为listenPort + 1，高可用服务监听端口，主要用于slave同master同步
  fastListenPort：默认为listenPort -2， 主要是fastRemotingServer服务使用，用于VIP通道


#### 2.2、集群规划、部署

- 双主双从异步复制的Broker集群

- 集群角色划分如下

|   主机名   |      IP       |       功能        |     集群角色     |
| :--------: | :-----------: | :---------------: | :--------------: |
| slaveNode1 | 192.168.1.161 | NameServer+Broker | Master01+Slave02 |
| slaveNode2 | 192.168.1.162 | NameServer+Broker | Master02+Slave01 |

##### 2.2.1、部署rmqnamesrv

两台的rmqnamesrv节点都直接运行即可【192.168.1.161、192.168.1.162】

```sh
## 创建目录
mkdir -p /app/rocketmq/rmqnamesrv/logs

docker run -d --name rmqnamesrv \
 -v /app/rocketmq/rmqnamesrv/logs:/home/rocketmq/logs \
 -p 9876:9876 \
 --restart=always \
 apache/rocketmq:4.9.4 sh mqnamesrv

# 查看日志, 是否正常启动成功
docker logs -f rmqnamesrv
```

##### 2.2.2、两个节点copy配置文件出来，修改

```sh
mkdir -p /app/rocketmq/{logs,store}
docker cp rmqnamesrv:/home/rocketmq/rocketmq-4.9.4/conf/  /app/rocketmq/
```

##### 2.2.3、主要配置文件介绍

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

##### 2.2.4、修改slaveNode1节点上的配置文件

- 修改broker-a.properties：/app/rocketmq/conf/2m-2s-async/broker-a.properties
- 以下是完整的配置文件

```sh
[root@slavenode1 ~]# cat /app/rocketmq/conf/2m-2s-async/broker-a.properties
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
brokerIP1=192.168.1.161
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
brokerIP1=192.168.1.161
```

##### 2.2.5、修改slaveNode2节点上的配置文件

- 修改broker-b.properties，以下是全部配置文件

```sh
[root@slavenode2 rocketmq]# cat /app/rocketmq/conf/2m-2s-async/broker-b.properties | grep -v -E "^#"         
brokerClusterName=DefaultCluster
brokerName=broker-b
brokerId=0
deleteWhen=04
fileReservedTime=48
brokerRole=ASYNC_MASTER
flushDiskType=ASYNC_FLUSH
namesrvAddr=192.168.1.161:9876;192.168.1.162:9876
brokerIP1=192.168.1.162
```

- broker-a-s.properties

```sh
[root@slavenode2 rocketmq]# cat /app/rocketmq/conf/2m-2s-async/broker-a-s.properties | grep -v -E "^#"
brokerClusterName=DefaultCluster
brokerName=broker-a
brokerId=1
deleteWhen=04
fileReservedTime=48
brokerRole=SLAVE
flushDiskType=ASYNC_FLUSH
namesrvAddr=192.168.1.161:9876;192.168.1.162:9876
brokerIP1=192.168.1.162
```

#### 2.3、启动集群

##### 2.3.1、启动rmqnamesrv

- 2.2.1步骤以及启动两个节点的rmqnamesrv，故此处不再重复启动

##### 2.3.2、启动两个Master   [起不来就是权限问题]

- 分别启动两个主机中的broker master。**注意，它们指定所要加载的配置文件是不同的。**
- 其他参数 
  - -e "JAVA_OPT_EXT=-server -Xms128m -Xmx128m -Xmn128m"

```sh
######################################## slaveNode1上 ########################################
## 创建目录
[root@slavenode1 ~]# mkdir -p /app/rocketmq/broker-a/logs/
[root@slavenode1 ~]# mkdir -p /app/rocketmq/broker-a/store/
[root@slavenode1 ~]# chown -R rocketmq:rocketmq /app/rocketmq/
[root@slavenode1 ~]# chmod -R 777 /app/rocketmq/

docker run -d --name broker-a                                   \
 -v /app/rocketmq/broker-a/logs/:/home/rocketmq/logs/           \
 -v /app/rocketmq/conf/:/home/rocketmq/rocketmq-4.9.4/conf/     \
 -v /app/rocketmq/broker-a/store/:/home/rocketmq/store/         \
 -p 10909:10909    \
 -p 10911:10911    \
 -p 10912:10912    \
 --restart=always  \
 --privileged=true \
 apache/rocketmq:4.9.4 sh mqbroker -c ../conf/2m-2s-async/broker-a.properties

######################################## slaveNode2上 ########################################
## 创建目录
[root@slavenode1 ~]# mkdir -p /app/rocketmq/broker-b/logs/
[root@slavenode1 ~]# mkdir -p /app/rocketmq/broker-b/store/
[root@slavenode1 ~]# chown -R rocketmq:rocketmq /app/rocketmq/
[root@slavenode1 ~]# chmod -R 777 /app/rocketmq/

docker run -d --name broker-b                                   \
 -v /app/rocketmq/broker-b/logs/:/home/rocketmq/logs/           \
 -v /app/rocketmq/broker-b/store/:/home/rocketmq/store/         \
 -v /app/rocketmq/conf/:/home/rocketmq/rocketmq-4.9.4/conf/     \
 -p 10909:10909    \
 -p 10911:10911    \
 -p 10912:10912    \
 --restart=always  \
 --privileged=true \
 apache/rocketmq:4.9.4 sh mqbroker -c ../conf/2m-2s-async/broker-b.properties
```

##### 2.3.2、启动两个slave

- 启动两个Slave
  - 分别启动两个主机中的broker slave。**注意，它们指定所要加载的配置文件是不同的。**

```sh
######################################## slaveNode1上 ########################################
## 创建目录
[root@slavenode1 ~]# mkdir -p /app/rocketmq/broker-b-s/logs/
[root@slavenode1 ~]# mkdir -p /app/rocketmq/broker-b-s/store/
[root@slavenode1 ~]# chown -R rocketmq:rocketmq /app/rocketmq/
[root@slavenode1 ~]# chmod -R 777 /app/rocketmq/

docker run -d --name broker-b-s                                   \
 -v /app/rocketmq/broker-b-s/logs/:/home/rocketmq/logs/           \
 -v /app/rocketmq/broker-b-s/store/:/home/rocketmq/store/         \
 -v /app/rocketmq/conf/:/home/rocketmq/rocketmq-4.9.4/conf/       \
 -p 10124:10909    \
 -p 10623:10911    \
 -p 10624:10912    \
 --restart=always  \
 --privileged=true \
 apache/rocketmq:4.9.4 sh mqbroker -c ../conf/2m-2s-async/broker-b-s.properties


######################################## slaveNode2上 ########################################
## 创建目录
[root@slavenode1 ~]# mkdir -p /app/rocketmq/broker-a-s/logs/
[root@slavenode1 ~]# mkdir -p /app/rocketmq/broker-a-s/store/
[root@slavenode1 ~]# chown -R rocketmq:rocketmq /app/rocketmq/
[root@slavenode1 ~]# chmod -R 777 /app/rocketmq/

docker run -d --name broker-a-s                                   \
 -v /app/rocketmq/broker-a-s/logs/:/home/rocketmq/logs/           \
 -v /app/rocketmq/broker-a-s/store/:/home/rocketmq/store/         \
 -v /app/rocketmq/conf/:/home/rocketmq/rocketmq-4.9.4/conf/       \
 -p 10124:10909    \
 -p 10623:10911    \
 -p 10624:10912    \
 --restart=always  \
 --privileged=true \
 apache/rocketmq:4.9.4 sh mqbroker -c ../conf/2m-2s-async/broker-a-s.properties
```

#### 2.4、部署可视化页面rocketmq-console-ng

```sh
docker run -d \
-p 8080:8080 \
--name rocketmq-console-ng \
-v /home/docker/rocketmq/tmp:/tmp \
--restart=always \
-e "JAVA_OPTS=-Drocketmq.namesrv.addr=192.168.1.161;192.168.1.162:9876 -Dcom.rocketmq.sendMessageWithVIPChannel=false" \
styletang/rocketmq-console-ng
```

![image-20230628003954359](C:\Users\Lenovo\AppData\Roaming\Typora\typora-user-images\image-20230628003954359.png)


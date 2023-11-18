## Kafka集群安装

### 一、安装环境

系统：centos7.6（192.168.47.188,192.168.47.189,192.168.47.190）

JDK版本：1.8

zookeeper：三台 【参考 https://www.cnblogs.com/hsyw/p/13208716.html】

Kafka：三台【参考 https://www.cnblogs.com/hsyw/p/13416311.html】

### 二、集群安装（便于方便管理用的也是独立部署的zk）

**2.1、配置文件详解**

​		zookeeper集群部署、Kafka单机部署请查看我上面的博客，下面我们就直接进入Kafka集群搭建了！

​		Kafka有很多配置文件，我们这次做集群部署，研究/app/kafka/config/下的server.properties就可以了

```
配置文件详解：https://www.cnblogs.com/hsyw/p/13416673.html
```

**2.2、实际上我们要修改的选项**

```
# 每台服务器的broker.id都不能相同
broker.id=0  
# 监听改成自己的IP:port
PLAINTEXT://192.168.47.188:9092 
#在log.retention.hours=168 下面新增下面三项
message.max.byte=5242880
default.replication.factor=2
replica.fetch.max.bytes=5242880
#设置zookeeper的连接端口
zookeeper.connect=192.168.47.188:2181,192.168.47.189:2181,192.168.47.190:2181
```

**2.3、启动集群**

```shell
#启动Kafka得先启动zookeeper（三台都启动）
[root@t1 ~]# /app/zktst/bin/zkServer.sh restart
#可以先前台启动看看是否有报错
[root@t1 kafka]# /app/kafka/bin/kafka-server-start.sh /app/kafka/config/server.properties 

#后台启动
[root@t1 kafka]# /app/kafka/bin/kafka-server-start.sh -daemon /app/kafka/config/server.properties 

[root@t3 ~]# ss -ntl|grep 9092
LISTEN     0      50          :::9092                    :::*        
```

### 三、测试集群健康

**3.1、创建Topic**

```shell
[root@t1 bin]# ./kafka-topics.sh --create --zookeeper 192.168.47.188:2181 --replication-factor 2 --partitions 1 --topic tzh
Created topic tzh.
#参数
--replication-factor 2   #复制两份
--partitions 1			 #创建1个分区
--topic 				 #主题为tzh
```

**3.2、在一台服务器上创建一个发布者**

```
[root@t1 bin]# ./kafka-console-producer.sh --broker-list 192.168.47.188:9092 --topic tzh
>ni hao
```

**3.3、在一台服务器上创建一个订阅者**

```shell
##订阅者成功收到信息说明Kafka成功搭建
[root@t3 bin]# ./kafka-console-consumer.sh --bootstrap-server 192.168.47.189:9092 --topic tzh --from-beginning
ni hao
```

**3.4、日志说明**

```
server.log 		 #kafka的运行日志
state-change.log #kafka他是用zookeeper来保存状态，所以他可能会进行切换，切换的日志就保存在这里
controller.log 	 #kafka选择一个节点作为“controller”,当发现有节点down掉的时候它负责在游泳分区的所有节点中选择新的		leader,这使得Kafka可以批量的高效的管理所有分区节点的主从关系。如果controller down掉了，活着的节点中的一个会备切换为新的controller.
```
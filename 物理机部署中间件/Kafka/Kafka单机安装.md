## Kafka单机安装

### 一、Kafka简介

​		Kafka是由**Apache软件基金会**开发的一个开源流处理平台，由Scala和Java编写。Kafka**是一种高吞吐量的**

**分布式发布订阅消息系统**，它可以处理消费者规模的网站中的所有动作流数据。 这种动作（网页浏览，搜索

和其他用户的行动）是在现代网络上的许多社会功能的一个关键因素。 这些数据通常是由于吞吐量的要求而通过

处理日志和日志聚合来解决。 对于像Hadoop的一样的日志数据和离线分析系统，但又要求实时处理的限制，这是

一个可行的解决方案。Kafka的目的是通过Hadoop的并行加载机制来统一线上和离线的消息处理，也是为了通过

集群来提供实时的消息。

类似的组件还有：Azure的ServiceBus、RabbitMQ等，据网上描述，Kafka比RabbitMQ性能强。

### 二、安装

**2.1、安装Kafka之前得先安装jdk，最好就是1.8及以上**

```
参考：https://www.cnblogs.com/hsyw/p/13203495.html
```

**2.2、下载Kafka**

```
下载地址:http://kafka.apache.org/downloads.html
```

**2.3、安装**

```shell
#我下载的是kafka_2.11-2.2.1.tgz，需要什么版本可自选
[root@t1 ~]# tar -zxvf kafka_2.11-2.2.1.tgz -C /app/ && cd /app
[root@t1 app]# mv kafka_2.11-2.2.1/ kafka
[root@t1 app]# cd kafka/
#存放Kafka日志
[root@t1 kafka]# mkdir logs
[root@t1 kafka]# vim config/server.properties 
#修改日志目录方便查看日志
log.dirs=/app/kafka/logs
```

**2.4、启动**

```shell
#启动Kafka得先启动zookeeper，可以用内置的，也可以自带。我这用的是另外安装的，默认端口是2181，所以不 修改Kafka的启动配置文件
#前台启动看看有没有报错，如果有报错排查
[root@t1 bin]# ./kafka-server-start.sh ../config/server.properties 
#后台启动，可以到日志查看是否有错误
[root@t1 bin]# ./kafka-server-start.sh  -daemon ../config/server.properties 
```

### 三、验证

**3.1、创建一个Topic**

```shell
[root@t1 bin]# ./kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic test
Created topic test.
```

**3.2、查看刚刚创建的Topic**

```
[root@t1 bin]# ./kafka-topics.sh --list --zookeeper localhost:2181
```

**3.3、产生消息**

```shell
[root@t1 bin]# ./kafka-console-producer.sh --broker-list localhost:9092 --topic test
>hello tzh
>ni zui jin hai hao ma    
>wo hen xiang ni
```

**3.4、消费消息**

```shell
###高版本用--bootstrap-server消费消息
[root@t1 bin]# ./kafka-console-consumer.sh --bootstrap-server 192.168.47.188:9092 --topic  test  --from-beginning   
hello tzh
ni zui jin hai hao ma
wo hen xiang ni 


###低版本用--zookeeper消费消息
./kafka-console-consumer.sh --zookeeper localhost:2181 --topic test --from-beginning
```



### 四、bin目录文件介绍

```sh
kafka-server-start.sh Kafka服务启动脚本
kafka-server-stop.sh Kafka服务停止脚本
kafka-console-consumer.sh Kafka命令窗口消费者启动脚本
kafka-console-producer.sh Kafka命令窗口生产者启动脚本
zookeeper-server-start.sh Kafka自带zookeeper服务的启动脚本
zookeeper-server-stop.sh Kafka自带zookeeper服务的停止脚本
```



### 五、conf目录文件介绍

```sh
server.properties Kafka服务的启动配置文件
zookeeper.properties Kafka自带zookeeper的启动配置文件
```


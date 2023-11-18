### 一、topic相关

#### 1.1、新建一个topic

- **create**                        
  - 创建主题
- **zookeeper**                
  - 指定zookeeper地址
- **replication-factor**    
  - 设置主题的副本数，每个主题可以有多个副本，副本位于集群中不同的broker上，也就是说副本的数量不能超过                                                                                             broker的数量，否则创建主题时会失败。一般情况下等于broker的个数
  - 如果没有在创建时显示指定或通过API向一个不存在的topic生产消息时会使用broker(server.properties)中的default.replication.factor配置的数量
- **partitions**                  
  - num.partitions来指定新建Topic的默认Partition数量，也可在创建Topic时通过参数指定，同时也可以在Topic创                                        建之后通过Kafka提供的工具修改。控制topic将分片成多少个log
  - 虽然增加分区数可以提供kafka集群的吞吐量、但是过多的分区数或者或是单台服务器上的分区数过多，会增加不可用及延迟的风险。因为多的分区数，意味着需要打开更多的文件句柄、增加点到点的延时、增加客户端的内存消耗。
  - 分区数也限制了consumer的并行度，即限制了并行consumer消息的线程数不能大于分区数
- **topic**                          
  - 主题名称

```sh
[root@slavenode1 bin]# ./kafka-topics.sh --create --zookeeper 192.168.1.160:2181 --replication-factor 3 --partitions 10 --topic test
Created topic test.
```

#### 1.2、查看所有topic列表

```sh
[root@slavenode1 bin]# ./kafka-topics.sh --zookeeper 192.168.1.160:2181 --list
test
```

#### 1.3、查看指定topic信息

```
[root@slavenode1 bin]# ./kafka-topics.sh --zookeeper 192.168.1.160:2181 --describe --topic test
Topic:test      PartitionCount:10       ReplicationFactor:3     Configs:
        Topic: test     Partition: 0    Leader: 1       Replicas: 1,2,3 Isr: 1
        Topic: test     Partition: 1    Leader: 2       Replicas: 2,3,1 Isr: 2,1
        Topic: test     Partition: 2    Leader: 3       Replicas: 3,1,2 Isr: 3,1
        Topic: test     Partition: 3    Leader: 1       Replicas: 1,3,2 Isr: 1
        Topic: test     Partition: 4    Leader: 2       Replicas: 2,1,3 Isr: 2,1
        Topic: test     Partition: 5    Leader: 3       Replicas: 3,2,1 Isr: 3,1
        Topic: test     Partition: 6    Leader: 1       Replicas: 1,2,3 Isr: 1
        Topic: test     Partition: 7    Leader: 2       Replicas: 2,3,1 Isr: 2,1
        Topic: test     Partition: 8    Leader: 3       Replicas: 3,1,2 Isr: 3,1
        Topic: test     Partition: 9    Leader: 1       Replicas: 1,3,2 Isr: 1
```

#### 1.4、控制台向topic生产数据

```
[root@slavenode2 bin]# ./kafka-console-producer.sh --broker-list slavenode2:9092 --topic tzh1
>ni hao
```

#### 1.5、控制台消费topic的数据

```shell
[root@slavenode1 bin]# ./kafka-console-consumer.sh --bootstrap-server slavenode1:9092 --topic tzh1 --from-beginning
ni hao

[root@slavenode1 bin]#./kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --group group-test
```

#### 1.6、查看topic某分区偏移量最大（小）值

- **注：** time为-1时表示最大值，time为-2时表示最小值

```sh
[root@masternode1 bin]# ./kafka-run-class.sh kafka.tools.GetOffsetShell --topic test  --time -1 --broker-list 192.168.1.160:9092 --partitions 0
test:0:0
```

#### 1.7、增加topic分区数

- 为**topic** **tesh** 增加1个分区
- **partitions**  指定分区，只能比原来的分区------>想增加几个分区**partitions** = 原来的分区数+想新增的分区数

```sh
[root@masternode1 bin]# kafka-topics.sh --zookeeper masternode1:2181 --alter --topic test --partitions 11
WARNING: If partitions are increased for a topic that has a key, the partition logic or ordering of the messages will be affected
Adding partitions succeeded!

# 查看当前一共有多少个分区，不出意外是11（原来的分区+新增的）。
[root@masternode1 bin]# ./kafka-topics.sh --zookeeper 192.168.1.160:2181 --describe --topic test         
Topic:test      PartitionCount:11       ReplicationFactor:3     Configs:
        Topic: test     Partition: 0    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3
        Topic: test     Partition: 1    Leader: 2       Replicas: 2,3,1 Isr: 1,2,3
        Topic: test     Partition: 2    Leader: 3       Replicas: 3,1,2 Isr: 1,2,3
        Topic: test     Partition: 3    Leader: 1       Replicas: 1,3,2 Isr: 1,2,3
        Topic: test     Partition: 4    Leader: 2       Replicas: 2,1,3 Isr: 1,2,3
        Topic: test     Partition: 5    Leader: 3       Replicas: 3,2,1 Isr: 1,2,3
        Topic: test     Partition: 6    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3
        Topic: test     Partition: 7    Leader: 2       Replicas: 2,3,1 Isr: 1,2,3
        Topic: test     Partition: 8    Leader: 3       Replicas: 3,1,2 Isr: 1,2,3
        Topic: test     Partition: 9    Leader: 1       Replicas: 1,3,2 Isr: 1,2,3
        Topic: test     Partition: 10   Leader: 2       Replicas: 2,3,1 Isr: 2,3,1
```

#### 1.8、删除topic，慎用，只会删除zookeeper中的元数据，消息文件须手动删除

- 如果kafaka启动时加载的配置文件中server.properties没有配置delete.topic.enable=true，那么此时的删除并不是真正的删除，而是把topic标记为：**marked for deletion**

- 你可以通过命令：**./bin/kafka-topics --zookeeper 【zookeeper server】 --list** 来查看所有topic

- 此时你若想真正删除它，可以如下操作：

     （1）登录zookeeper客户端：命令：**./bin/zookeeper-client**

     （2）找到topic所在的目录：**ls /brokers/topics**

     （3）找到要删除的topic，执行命令：**rmr /brokers/topics/【topic name】即可，此时topic被彻底删除。**

```sh
[root@masternode1 bin]# ./kafka-topics.sh  --delete --zookeeper masternode1:2181  --topic tzh  
Topic tzh is marked for deletion.
Note: This will have no impact if delete.topic.enable is not set to true.
```

#### 1.9、查看topic消费进度

- 这个会显示出consumer group的offset情况， 必须参数为--group， 不指定--topic，默认为所有topic
- **消费者组 (Consumer Group)**
  - consumer group下可以有一个或多个consumer instance，consumer instance可以是一个进程，也可以是一个线程
  - group.id是一个字符串，唯一标识一个consumer group
  - consumer group下订阅的topic下的每个分区只能分配给某个group下的一个consumer(当然该分区还可以被分配给其他group)
- **消费者位置(consumer position)** 
  - 消费者在消费的过程中需要记录自己消费了多少数据，即消费位置信息。在Kafka中这个位置信息有个专门的术语：位移(offset)
  - 很多消息引擎都把这部分信息保存在服务器端(broker端)，这样做的好处当然是实现简单，但会有三个主要的问题：
    - 1. broker从此变成有状态的，会影响伸缩性；
      2. 需要引入应答机制(acknowledgement)来确认消费成功。
      3. 由于要保存很多consumer的offset信息，必然引入复杂的数据结构，造成资源浪费。而Kafka选择了不同的方式：每个consumer group保存自己的位移信息，那么只需要简单的一个整数表示位置就够了；同时可以引入checkpoint机制定期持久化，简化了应答机制的实现。
  - 详细参考：https://www.cnblogs.com/huxi2b/p/6223228.html

```sh
# 查看所有组
[root@slavenode1 bin]# ./kafka-consumer-groups.sh --bootstrap-server masternode1:9092 --list
group-test
console-consumer-33594
console-consumer-51445
console-consumer-21313
console-consumer-72215     

# 查看消费情况
[root@slavenode1 bin]# ./kafka-consumer-groups.sh --describe --bootstrap-server masternode1:9092 --group group-test
Consumer group 'group-test' has no active members.

TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
test            6          0               0               0               -               -               -
topic-test      0          7               7               0               -               -               -
test            10         2               2               0               -               -               -
test            0          0               0               0               -               -               -
test            7          0               0               0               -               -               -
test            5          0               0               0               -               -               -
test            8          0               0               0               -               -               -
test            1          0               0               0               -               -               -
topic-test      1          7               7               0               -               -               -
tzh1            0          3               17              14              -               -               -
test            4          0               0               0               -               -               -
test            9          0               0               0               -               -               -
test            3          0               0               0               -               -               -
test            2          0               0               0               -               -               -
```

| `TOPIC`   | `PARTITION` | `CURRENT-OFFSET` | `LOG-END-OFFSET` | `LAG`        | `CONSUMER-ID` | `HOST` | `CLIENT-ID` |
| :-------- | :---------- | :--------------- | :--------------- | :----------- | :------------ | :----- | :---------- |
| topic名字 | 分区id      | 当前已消费的条数 | 总条数           | 未消费的条数 | 消费id        | 主机ip | 客户端id    |



### 二、Kafka之消费者组（Consumer Group）命令

**要点：**

1、一个消费者只能属于一个消费者组

2、消费者组订阅的topic只能被其中的一个消费者消费

3、不同消费者组中的消费者可以消费同一个topic

4、消费者组中的消费者实例个数不能超过分区的数量

假设分区数量设置为1，消费者实例设置为2，这个时候会发现只有1个消费者在消费消息，另一个消费者闲置。

#### 2.1、消费者组命令：

创建分区数量为2的topic

```sh
[root@masternode1 bin]# ./kafka-topics.sh --create --zookeeper 192.168.1.160:2181 --replication-factor 1 --partitions 2 --topic topic-test
Created topic topic-test.
```

打开2个命令行窗口，执行同样的语句进行消息消费

- 消费的时候加上参数   --group group-test
  - 指定这个消费者归属**group**的**group-test**中

```sh
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic topic-test --group group-test
```

打开1个命令行窗口，进行消息发送

```shell
kafka-console-producer.sh --broker-list localhost:9092 --topic topic-test
```


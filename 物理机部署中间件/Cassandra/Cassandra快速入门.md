# Cassandra快速入门

### 一、Cassandra是什么？

```shell
高可用性和可扩展的分布式数据库

Apache Cassandra™是一个开源分布式数据，可提供当今最苛刻的应用程序所需的高可用性、高性能和线性可伸缩性。它提供了跨云服务提供商、数据中心和地理位置的操作简便性和轻松的复制，并且可以在混合云环境中每秒处理PB级信息和数千个并发操作。

在Hadoop关联的项目中对Cassandra的解释是：A scalable multi-master database with no single points of failure.

可以看出，高可用性和高可伸缩性是Cassandra最闪亮的特点。没有单点故障。
```



### 二、Cassandra vs. MongoDB vs. Couchbase vs. HBase

```shell
Apache Cassandra™在高负载下提供了更高的性能，在许多用场景中都超过了它的NoSQL数据库竞争对手。

Apache Cassandra: 高度可伸缩、高性能的分布式数据库，设计用于处理许多商用服务器上的大量数据，提供高可用性，没有单点故障。 

Apache HBase: 基于谷歌的BigTable的开源、非关系型、分布式数据库，是用Java编写的。它是Apache Hadoop项目的一部分，在HDFS上运行，为Hadoop提供类似于BigTable的功能。

MongoDB: 跨平台的面向文档的数据库系统，避开了传统的基于表的关系数据库结构，转而使用具有动态模式的类JSON文档，从而使数据在某些类型的应用程序中的集成更加容易和快捷。

Couchbase: 为交互式应用程序优化的分布式NoSQL面向文档的数据库。
```



### 三、架构简介

```shell
   Cassandra被设计用来处理跨多个节点的大数据工作负载，没有单点故障。Cassandra通过采用跨同构节点的对等分布式系统来解决故障问题，其中数据分布在集群中的所有节点中。每个节点使用点对点gossip通信协议频繁地交换自己和集群中其他节点的状态信息。每个节点上按顺序写入的提交日志被捕获写入活动，以确保数据的持久性。然后，数据被编入索引并写入内存结构，称为memtable，它类似于回写缓存。每次内存结构满了，数据就被写到一个SSTables数据文件的磁盘上。所有写操作都会自动分区并在整个集群中复制。Cassandra定期使用一个称为压缩的进程合并SSTables，丢弃用tombstone标记为要删除的过时数据。为了确保集群中的所有数据保持一致，需要使用各种修复机制。

   Cassandra是一个分区的行存储数据库，其中行被组织成具有所需主键的表。Cassandra的体系结构允许任何授权用户连接到任何数据中心中的任何节点，并使用CQL语言访问数据。为了易于使用，CQL使用与SQL类似的语法并处理表数据。通常，集群中的每个应用程序都有一个键空间，由许多不同的表组成。

   客户端读或写请求可以发送到集群中的任何节点。当客户端使用请求连接到某个节点时，该节点充当该特定客户端操作的协调器。协调器充当客户端应用程序和拥有所请求数据的节点之间的代理。协调器根据集群的配置方式确定环形中的哪些节点应该获得请求。
```

#### 3.1、核心结构

• Node

存储数据的地方。它是Cassandra的基础设施组件

• datacenter

相关节点的集合。数据中心可以是物理数据中心，也可以是虚拟数据中心。不同的工作负载应该使用单独的数据中心，无论是物理的还是虚拟的。复制由数据中心设置。使用单独的数据中心可以防止Cassandra事务受到其他工作负载的影响，并使请求彼此接近以降低延迟。根据复制因子，可以将数据写入多个数据中心。数据中心绝不能跨越物理位置。

• Cluster 

一个集群包含一个或多个数据中心。它可以跨越物理位置。

• Commit log

为了持久性，所有数据写入之前都要首先写入提交日志（日志写入优先）。所有数据都刷新到SSTables之后，就可以对其进行归档、删除或回收。 

• SSTable（Sorted String Table） 

一个SSTable是一个不可变的数据文件，Cassandra定期将memtables写入其中。仅追加SSTables并按顺序存储在磁盘上，并为每个Cassandra表维护SSTables。

• CQL Table

按表行获取的有序列的集合。一张表由多列组成，并且有一个主键。

#### 3.2、核心组件

• Gossip

一种对等通信协议，用于发现和共享Cassandra集群中其他节点的位置和状态信息。Gossip息也由每个节点本地保存，以便在节点重新启动时立即使用。

• Partitioner

分区程序确定哪个节点将接收一段数据的第一个副本，以及如何跨集群中的其他节点分发其他副本。每一行数据都由一个主键唯一地标识，主键可能与其分区键相同，但也可能包含其他集群列。Partitioner是一个哈希函数，它从一行的主键派生标记。分区程序使用令牌值来确定集群中的哪些节点接收该行的副本。Murmur3Partitioner是新Cassandra集群的默认分区策略，几乎在所有情况下都是新集群的正确选择。

• Replication factor

整个集群中的副本总数。副本因子1表示在一个节点上每一行只有一个副本。副本因子2表示每一行有两个副本，其中每个副本位于不同的节点上。所有的副本都同样重要，没有主副本。你可以为每个数据中心定义副本因子。通常，应该将副本策略设置为大于1，但不超过集群中的节点数。

• Replica placement strategy

Cassandra将数据的副本存储在多个节点上，以确保可靠性和容错能力。副本策略决定将副本放在哪个节点上。数据的第一个副本就是第一个副本，它在任何意义上都不是唯一的。强烈建议使用NetworkTopologyStrategy策略，因为在将来需要扩展时，可以轻松扩展到多个数据中心。创建keyspace时，必须定义副本放置策略和所需的副本数。

• Snitch

snitch将一组机器定义为数据中心和机架(拓扑)，副本策略使用这些数据中心和机架放置副本。

在创建集群时，必须配置一个snitch。所有的snitch都使用一个动态的snitch层，该层监视性能并选择最佳副本进行读取。它是默认启用的，建议在大多数部署中使用。在cassandra.yaml配置文件中为每个节点配置动态snitch阈值。

• cassandra.yaml

用于设置集群的初始化属性、表的缓存参数、调优和资源利用率的属性、超时设置、客户端连接、备份和安全性的主要配置文件。



### 四、部署cassandra

```shell
# 1、下载（需要JDK环境）
https://mirrors.bfsu.edu.cn/apache/cassandra/3.11.10/apache-cassandra-3.11.10-bin.tar.gz

# 2、解压
[root@node1 app]# tar -zxvf apache-cassandra-3.11.10-bin.tar.gz       

# 3、重命名
[root@node1 app]# mv apache-cassandra-3.11.10 cassandra

# 4、创建用户、授权
[root@node1 app]# useradd -m cassandra
[root@node1 app]# chown -R cassandra.cassandra cassandra

# 5、启动
[root@node1 ~]# su - cassandra
[cassandra@node1 ~]$ cd /app/cassandra/bin/
[cassandra@node1 bin]$ ./cassandra

# 6、检查启动
[cassandra@node1 bin]$ ps -ef|grep cassandra

# 7、端口检查
[cassandra@node1 bin]$ ss -ntl | grep 7199
LISTEN     0      50     127.0.0.1:7199                     *:*     

# 8、日志查看
[cassandra@node1 logs]$ pwd
/app/cassandra/logs
[cassandra@node1 logs]$ tail -f system.log
```


## 集群部署ClickHouse

### 一、部署前提

- 需要一个Zookeeper集群
  - 搭建clickhouse集群时，需要使用Zookeeper去实现集群副本之间的同步，所以这里需要zookeeper集群，zookeeper集群安装后可忽略此步骤。

- 需要三个节点部署单机的ClickHouse【重复单机部署的操着即可，密码也可以改】



### 二、集群部署ClickHouse

#### 1.1、3节点增加配置文件 【/etc/clickhouse-server/config.d】

- 在metrika.xml中我们配置后期使用的clickhouse集群中创建分布式表时使用3个分片，每个分片有1个副本，配置如下：

- vim /etc/clickhouse-server/config.d/metrika.xml

```xml
<yandex>
    <remote_servers>
        <clickhouse_cluster_3shards_1replicas>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>master</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>slave1</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <internal_replication>true</internal_replication>
                <replica>
                    <host>slave2</host>
                    <port>9000</port>
                </replica>
            </shard>
        </clickhouse_cluster_3shards_1replicas>
    </remote_servers>
   
    <zookeeper>
        <node index="1">
            <host>master</host>
            <port>2181</port>
        </node>
        <node index="2">
            <host>slave1</host>
            <port>2181</port>
        </node>
        <node index="3">
            <host>slave2</host>
            <port>2181</port>
        </node>
    </zookeeper>
    <macros>
        <shard>01</shard> 
        <replica>master</replica>
    </macros>
    <networks>
        <ip>::/0</ip>
    </networks>
    <clickhouse_compression>
        <case>
            <min_part_size>10000000000</min_part_size>
            <min_part_size_ratio>0.01</min_part_size_ratio>
            <method>lz4</method>
        </case>
    </clickhouse_compression>
</yandex>
```

#### 对以上配置文件中配置项的解释如下:

- remote_servers：

clickhouse集群配置标签，固定写法。**注意：这里与之前版本不同，之前要求必须以clickhouse开头，新版本不再需要。**

- clickhouse_cluster_3shards_1replicas:

配置clickhouse的集群名称，可自由定义名称，注意集群名称中不能包含点号。这里代表集群中有3个分片，每个分片有1个副本。

分片是指包含部分数据的服务器，要读取所有的数据，必须访问所有的分片。

副本是指存储分片备份数据的服务器，要读取所有的数据，访问任意副本上的数据即可。

- shard：

分片，一个clickhouse集群可以分多个分片，每个分片可以存储数据，这里 **分片可以理解为clickhouse机器中的每个节点，1个分片只能对应1服务节点** 。这里可以配置一个或者任意多个分片，在每个分片中可以配置一个或任意多个副本，不同分片可配置不同数量的副本。如果只是配置一个分片，这种情况下查询操作应该称为远程查询，而不是分布式查询。

- replica：

每个分片的副本，默认每个分片配置了一个副本。也可以配置多个，副本的数量上限是由clickhouse节点的数量决定的。如果配置了副本，读取操作可以从每个分片里选择一个可用的副本。如果副本不可用，会依次选择下个副本进行连接。该机制利于系统的可用性。

- internal_replication：

默认为false,写数据操作会将数据写入所有的副本，设置为true,写操作只会选择一个正常的副本写入数据，数据的同步在后台自动进行。

- zookeeper：

配置的zookeeper集群，**注意：与之前版本不同，之前版本是“zookeeper-servers”。**

- macros：

区分每台clickhouse节点的宏配置，macros中标签代表当前节点的分片号，标签代表当前节点的副本号，这两个名称可以随意取，后期在创建副本表时可以动态读取这两个宏变量。注意：每台clickhouse节点需要配置不同名称。

- networks：

这里配置ip为“::/0”代表任意IP可以访问，包含IPv4和IPv6。

注意：允许外网访问还需配置/etc/clickhouse-server/config.xml 参照第三步骤。

- clickhouse_compression：

MergeTree引擎表的数据压缩设置，min_part_size：代表数据部分最小大小。min_part_size_ratio：数据部分大小与表大小的比率。method：数据压缩格式。

**注意：需要在每台clickhouse节点上配置metrika.xml文件，并且修改每个节点的 macros配置名称。**

```
#node2节点修改metrika.xml中的宏变量如下：
    <macros>
        <shard>02</replica> 
        <replica>slave1</replica>
    </macros>

#node3节点修改metrika.xml中的宏变量如下:
    <macros>
        <shard>03</replica> 
        <replica>slave2</replica>
    </macros>
```

#### 1.2、在每台节点上启动/查看/重启/停止clickhouse服务

```sh
#每台节点启动Clickchouse服务
service clickhouse-server start

#每台节点查看clickhouse服务状态
service clickhouse-server status

#每台节点重启clickhouse服务
service clickhouse-server restart

#每台节点关闭Clikchouse服务
service clickhouse-server stop
```

#### 1.3、验证集群状态

- 在node1、node2、node3任意一台节点进入clickhouse客户端，查询集群配置

```sh
#选择三台clickhouse任意一台节点，进入客户端
clickhouse-client --password 

#查询集群信息，看到如下所示即代表集群配置成功。
master :) select * from system.clusters;
```

![image-20221029162627991](G:\陶振欢的组件笔记\ClickHouse\2、集群部署ClickHouse\image-20221029162627991.png)

```sh
#查询集群信息，也可以使用如下命令
master :) select cluster,host_name from system.clusters;

SELECT
    cluster,
    host_name
FROM system.clusters

Query id: 97f53b80-89ed-4f98-93cf-d37bf4a3f1a9

┌─cluster──────────────────────────────────────┬─host_name─┐
│ clickhouse_cluster_3shards_1replicas         │ master    │
│ clickhouse_cluster_3shards_1replicas         │ slave1    │
│ clickhouse_cluster_3shards_1replicas         │ slave2    │
│ test_cluster_two_shards                      │ 127.0.0.1 │
│ test_cluster_two_shards                      │ 127.0.0.2 │
│ test_cluster_two_shards_internal_replication │ 127.0.0.1 │
│ test_cluster_two_shards_internal_replication │ 127.0.0.2 │
│ test_cluster_two_shards_localhost            │ localhost │
│ test_cluster_two_shards_localhost            │ localhost │
│ test_shard_localhost                         │ localhost │
│ test_shard_localhost_secure                  │ localhost │
│ test_unavailable_shard                       │ localhost │
│ test_unavailable_shard                       │ localhost │
└──────────────────────────────────────────────┴───────────┘

13 rows in set. Elapsed: 0.003 sec. 

slave2 :) select cluster,host_name from system.clusters;

SELECT
    cluster,
    host_name
FROM system.clusters

Query id: dee41356-8ecd-43ac-a57b-1c2808fc5108

┌─cluster──────────────────────────────────────┬─host_name─┐
│ clickhouse_cluster_3shards_1replicas         │ master    │
│ clickhouse_cluster_3shards_1replicas         │ slave1    │
│ clickhouse_cluster_3shards_1replicas         │ slave2    │
│ test_cluster_two_shards                      │ 127.0.0.1 │
│ test_cluster_two_shards                      │ 127.0.0.2 │
│ test_cluster_two_shards_internal_replication │ 127.0.0.1 │
│ test_cluster_two_shards_internal_replication │ 127.0.0.2 │
│ test_cluster_two_shards_localhost            │ localhost │
│ test_cluster_two_shards_localhost            │ localhost │
│ test_shard_localhost                         │ localhost │
│ test_shard_localhost_secure                  │ localhost │
│ test_unavailable_shard                       │ localhost │
│ test_unavailable_shard                       │ localhost │
└──────────────────────────────────────────────┴───────────┘

13 rows in set. Elapsed: 0.002 sec. 
```

#### 1.4、 客户端命令行参数

我们可以通过clickhouse client来连接启动的clickhouse服务，连接服务时，我们可以指定以下参数，这里指定的参数会覆盖默认值和配置文件中的配置。

| **参数**         | **解释**                                                     |
| ---------------- | ------------------------------------------------------------ |
| --host, -h       | 服务端的host名称, 默认是localhost。您可以选择使用host名称或者IPv4或IPv6地址。 |
| --port           | 连接的端口，默认值：9000。注意HTTP接口以及TCP原生接口使用的是不同端口。 |
| --user, -u       | 用户名。默认值：default。                                    |
| --password       | 密码。默认值：空字符串。                                     |
| --query，-q      | 使用非交互模式查询。                                         |
| --database, -d   | 默认当前操作的数据库. 默认值：服务端默认的配置（默认是default）。 |
| --multiline, -m  | 如果指定，允许多行语句查询（Enter仅代表换行，不代表查询语句完结）。 |
| --time, -t       | 如果指定，**非交互模式下**会打印查询执行的时间到stderr中。   |
| --stacktrace     | 如果指定，如果出现异常，会打印堆栈跟踪信息。                 |
| --config-file    | 配置文件的名称。                                             |
| --multiquery，-n | 使用非交互模式查询数据时，可以分号隔开多个sql语句。          |

Ø **--host，-h:**

使用-h指定ip或者host名称时，需要在/etc/clickhouse-server/config.xml配置文件中114行配置：<listen_host>::</listen_host> ，代表可以任意ip可访问。配置完成后需要重启当期clickhouse节点生效。

```
clickhouse-client  -h node1
ClickHouse client version 20.8.3.18.
Connecting to node1:9000 as user default.
Connected to ClickHouse server version 20.8.3 revision 54438.
```

Ø **--query，-q**

```
clickhouse-client -q "show databases"
_temporary_and_external_tables
default
system
```

Ø **--database, -d:**

```
clickhouse-client -d "system" -q "show tables"
aggregate_function_combinators
asynchronous_metric_log
asynchronous_metrics
build_options
... ....
```

Ø **--multiline, -m:**

```
clickhouse-client -m

node1 :) select 
:-] 1+1
:-] ;

SELECT 1 + 1
┌─plus(1, 1)─┐
│          2 │
└────────┘
1 rows in set. Elapsed: 0.004 sec.
```

Ø **--time, -t:**

```
clickhouse-client -t -q "show databases"
_temporary_and_external_tables
default
system
0.004
```

Ø **--stacktrace:**

```
clickhouse-client --stacktrace
ClickHouse client version 20.8.3.18.
Connecting to localhost:9000 as user default.
Connected to ClickHouse server version 20.8.3 revision 54438.

node1 :) use aaa;
USE aaa
Received exception from server (version 20.8.3):
Code: 81. DB::Exception: Received from localhost:9000. DB::Exception: Database aaa doesn't exist. Stack trace:
0.Poco::Exception::Exception(std::__1 ... ....
... ....
```

Ø **--multiquery，-n**

```
[root@node1 ~]# clickhouse-client  -n -q "show databases;use default;"
_temporary_and_external_tables
default
system
```

#### 1.4、数据类型

ClickHouse提供了许多数据类型，它们可以划分为基础类型、复合类型和特殊类型。我们可以在system.data_type_families表中检查数据类型名称以及是否区分大小写。这个表中存储了ClickHouse支持的所有数据类型。

```
select * from system.data_type_families limit 10;
SELECT *
FROM system.data_type_families
LIMIT 10

┌─name────────────┬─case_insensitive─┬─alias_to─┐
│ Polygon          │                    0 │            │
│ Ring              │                    0 │            │
│ MultiPolygon    │                    0 │            │
│ IPv6              │                    0 │            │
│ IntervalSecond  │                    0 │            │
│ IPv4              │                    0 │            │
│ UInt32            │                   0 │             │
│ IntervalYear     │                   0 │             │
│ IntervalQuarter │                   0 │             │
│ IntervalMonth    │                   0 │             │
└─────────────────┴──────────────────┴──────────┘

10 rows in set. Elapsed: 0.004 sec.
```

下面介绍下常用的数据类型，ClickHouse与Mysql、Hive中常用数据类型的对比图如下：

| **MySQL** | **Hive**  | **ClickHouse(区分大小写)** |
| --------- | --------- | -------------------------- |
| byte      | TINYINT   | Int8                       |
| short     | SMALLINT  | Int16                      |
| int       | INT       | Int32                      |
| long      | BIGINT    | Int64                      |
| varchar   | STRING    | String                     |
| timestamp | TIMESTAMP | DateTime                   |
| float     | FLOAT     | Float32                    |
| double    | DOUBLE    | Float64                    |
| boolean   |           |                            |
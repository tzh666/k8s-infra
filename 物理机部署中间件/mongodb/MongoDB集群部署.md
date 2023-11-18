## MongoDB集群部署

### 一、部署环境

## 1、MongoDB机器信息

|    192.168.47.188    |    192.168.47.189    |    192.168.47.190    |
| :------------------: | :------------------: | :------------------: |
|        mongos        |        mongos        |        mongos        |
|    config server     |    config server     |    config server     |
| shard server1 主节点 | shard server1 副节点 |  shard server1 仲裁  |
|  shard server2 仲裁  | shard server2 主节点 | shard server2 副节点 |
| shard server3 副节点 |  shard server3 仲裁  | shard server3 主节点 |

```
系统：centos7.6

DB版本：mongodb-linux-x86_64-rhel62-4.2.1.tgz

下载地址：https://www.mongodb.com
```

### 二、安装MongoDB

2.1、安装MongoDB（三台主机均操作）

```shell
[root@t1 ~]# tar -zxvf mongodb-linux-x86_64-rhel62-4.2.1.tgz  -C /app/
[root@t1 ~]# cd /app && mv mongodb-linux-x86_64-rhel62-4.2.1/ mongodb && cd mongodb
#分别在每台机器建立conf、mongos、config、shard1、shard2、shard3六个目录，因为mongos不存储数据，只需要建立日志文件目录即可。
[root@t1 mongodb]# mkdir conf \
mkdir -p config/{data,log} \
mkdir -p shard1/{data,log} \
mkdir -p shard2/{data,log} \
mkdir -p shard3/{data,log} \


配置环境变量
vim /etc/profile
# MongoDB 环境变量内容
export MONGODB_HOME=/app/mongodb
export PATH=$MONGODB_HOME/bin:$PATH


####
source /etc/profile
```

2.2、配置config server服务器

```shell
[root@t1 mongodb]# vim conf/config.conf
pidfilepath = /app/mongodb/config/log/configsrv.pid
dbpath = /app/mongodb/config/data
logpath = /app/mongodb/config/log/congigsrv.log
logappend = true
bind_ip = 0.0.0.0
port = 21000
fork = true
#declare this is a config db of a cluster;
configsvr = true
#副本集名称
replSet = configs
#设置最大连接数
maxConns = 20000

#启动三台服务器的config server（三台）
[root@t2 ~]# /app/mongodb/bin/mongod -f /app/mongodb/conf/config.conf
about to fork child process, waiting until server is ready for connections.
forked process: 3154
child process started successfully, parent exiting

#登录任意一台配置服务器，初始化配置副本集
#连接 MongoDB
[root@t2 ~]# /app/mongodb/bin/mongo --port 21000

#config 变量
config = {
    _id : "configs",
    members : [
    {_id : 0, host : "192.168.47.188:21000" },
    {_id : 1, host : "192.168.47.189:21000" },
    {_id : 2, host : "192.168.47.190:21000" }
    ]
}

#初始化副本集
rs.initiate(config)
```

其中，"_id" : "configs"应与配置文件中配置的 replicaction.replSetName 一致，"members" 中的 "host" 为三个节点的 ip 和 port
 响应内容如下

```json
> config = {
...     _id : "configs",
...     members : [
...     {_id : 0, host : "192.168.47.188:21000" },
...     {_id : 1, host : "192.168.47.189:21000" },
...     {_id : 2, host : "192.168.47.190:21000" }
...     ]
... }
{
        "_id" : "configs",
        "members" : [
                {
                        "_id" : 0,
                        "host" : "192.168.47.188:21000"
                },
                {
                        "_id" : 1,
                        "host" : "192.168.47.189:21000"
                },
                {
                        "_id" : 2,
                        "host" : "192.168.47.190:21000"
                }
        ]
}
> rs.initiate(config)
{
        "ok" : 1,####注意看状态
        "$gleStats" : {
                "lastOpTime" : Timestamp(1596357707, 1),
                "electionId" : ObjectId("000000000000000000000000")
        },
        "lastCommittedOpTime" : Timestamp(0, 0),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1596357707, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        },
        "operationTime" : Timestamp(1596357707, 1)
}
configs:SECONDARY> 
```

此时会发现终端上的输出已经有了变化。

```
//从单个一个
>
//变成了
configs:SECONDARY>
```

查询状态

```sql
configs:PRIMARY> rs.status()
```

### 3. 配置分片副本集

**3.1 设置第一个分片副本集**

设置第一个分片副本集(三台机器均操作)
配置文件

```shell
[root@t1 ~]# vim /app/mongodb/conf/shard1.conf
#配置文件内容
#——————————————–
pidfilepath = /app/mongodb/shard1/log/shard1.pid
dbpath = /app/mongodb/shard1/data
logpath = /app/mongodb/shard1/log/shard1.log
logappend = true

bind_ip = 0.0.0.0
port = 27001
fork = true
 
#副本集名称
replSet = shard1
 
#declare this is a shard db of a cluster;
shardsvr = true
 
#设置最大连接数
maxConns = 20000
```

启动三台服务器的shard1 server

```shell
[root@t1 ~]# /app/mongodb/bin/mongod -f /app/mongodb/conf/shard1.conf
about to fork child process, waiting until server is ready for connections.
forked process: 13708
child process started successfully, parent exiting
```

登陆任意一台服务器，初始化副本集(除了192.168.47.190）
连接 MongoDB

```shell
[root@t1 ~]# /app/mongodb/bin/mongod -f /app/mongodb/conf/shard1.conf

#连接数据库
[root@t1 ~]# /app/mongodb/bin/mongo --port 27001
#使用admin数据库
use admin

#定义副本集配置
config = {
    _id : "shard1",
     members : [
         {_id : 0, host : "192.168.47.188:27001" },
         {_id : 1, host : "192.168.47.189:27001" },
         {_id : 2, host : "192.168.47.190:27001" , arbiterOnly: true }
     ]
 }
 
#初始化副本集配置
rs.initiate(config)
```

响应内容如下

```json
> use admin
switched to db admin
> config = {
...     _id : "shard1",
...      members : [
...          {_id : 0, host : "192.168.47.188:27001" },
...          {_id : 1, host : "192.168.47.189:27001" },
...          {_id : 2, host : "192.168.47.190:27001" , arbiterOnly: true }
...      ]
...  }
{
        "_id" : "shard1",
        "members" : [
                {
                        "_id" : 0,
                        "host" : "192.168.47.188:27001"
                },
                {
                        "_id" : 1,
                        "host" : "192.168.47.189:27001"
                },
                {
                        "_id" : 2,
                        "host" : "192.168.47.190:27001",
                        "arbiterOnly" : true
                }
        ]
}
> rs.initiate(config)
```

此时会发现终端上的输出已经有了变化。

```cpp
//从单个一个
>
//变成了
shard1:SECONDARY>

//查询状态
shard1:SECONDARY> rs.status()
```

**3.2 设置第二个分片副本集**

设置第二个分片副本集（三台）
配置文件

```bash
[root@t1 ~]# vim /app/mongodb/conf/shard2.conf

#配置文件内容
#——————————————–
pidfilepath = /app/mongodb/shard2/log/shard2.pid
dbpath = /app/mongodb/shard2/data
logpath = /app/mongodb/shard2/log/shard2.log
logappend = true

bind_ip = 0.0.0.0
port = 27002
fork = true
 
#副本集名称
replSet=shard2
 
#declare this is a shard db of a cluster;
shardsvr = true
 
#设置最大连接数
maxConns=20000
```

```shell
#启动三台服务器的shard2 server
[root@t1 ~]# /app/mongodb/bin/mongod -f /app/mongodb/conf/shard2.conf
about to fork child process, waiting until server is ready for connections.
forked process: 14533
child process started successfully, parent exiting

登陆任意一台服务器，初始化副本集(除了192.168.47.188）
连接 MongoDB
#连接 MongoDB
[root@t1 ~]# /app/mongodb/bin/mongo --port 27002

#使用admin数据库
use admin

#定义副本集配置
config = {
    _id : "shard2",
     members : [
         {_id : 0, host : "192.168.47.188:27002"  , arbiterOnly: true },
         {_id : 1, host : "192.168.47.189:27002" },
         {_id : 2, host : "192.168.47.190:27002" }
     ]
 }
#初始化副本集配置
rs.initiate(config)
```

**3.3设置第三个分片副本集**

设置第三个分片副本集（三台）
配置文件

```bash
[root@t1 ~]# vim /app/mongodb/conf/shard3.conf

#配置文件内容
#——————————————–
pidfilepath = /app/mongodb/shard3/log/shard3.pid
dbpath = /app/mongodb/shard3/data
logpath = /app/mongodb/shard3/log/shard3.log
logappend = true
bind_ip = 0.0.0.0
port = 27003
fork = true
replSet=shard3
shardsvr = true
maxConns=20000
```

```shell
#启动三台服务器的shard3 server
[root@t1 ~]# /app/mongodb/bin/mongod -f /app/mongodb/conf/shard3.conf
about to fork child process, waiting until server is ready for connections.
forked process: 15799
child process started successfully, parent exiting

登陆任意一台服务器，初始化副本集(除了192.168.47.189）
连接 MongoDB
#连接 MongoDB
[root@t1 ~]# /app/mongodb/bin/mongo --port 27003

#使用admin数据库
use admin

#定义副本集配置
config = {
    _id : "shard3",
     members : [
         {_id : 0, host : "192.168.47.188:27003" },
         {_id : 1, host : "192.168.47.189:27003" , arbiterOnly: true},
         {_id : 2, host : "192.168.47.190:27003" }
     ]
 }
#初始化副本集配置
rs.initiate(config)
```

响应内容如下

```cpp
> use admin
switched to db admin
> config = {
...     _id : "shard3",
...      members : [
...          {_id : 0, host : "192.168.47.188:27003" },
...          {_id : 1, host : "192.168.47.189:27003" , arbiterOnly: true},
...          {_id : 2, host : "192.168.47.190:27003" }
...      ]
...  }
{
        "_id" : "shard3",
        "members" : [
                {
                        "_id" : 0,
                        "host" : "192.168.47.188:27003"
                },
                {
                        "_id" : 1,
                        "host" : "192.168.47.189:27003",
                        "arbiterOnly" : true
                },
                {
                        "_id" : 2,
                        "host" : "192.168.47.190:27003"
                }
        ]
}
> rs.initiate(config)
{
        "ok" : 1,
        "$clusterTime" : {
                "clusterTime" : Timestamp(1596360929, 1),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        },
        "operationTime" : Timestamp(1596360929, 1)
}
shard3:OTHER> 
```

**3.4 配置路由服务器 mongos**

先启动配置服务器和分片服务器,后启动路由实例启动路由实例:（三台机器）

```
vim /app/mongodb/conf/mongos.conf

#内容
pidfilepath = /app/mongodb/mongos/log/mongos.pid
logpath = /app/mongodb/mongos/log/mongos.log
logappend = true

bind_ip = 0.0.0.0
port = 20000
fork = true

#监听的配置服务器,只能有1个或者3个 configs为配置服务器的副本集名字
configdb = configs/192.168.47.188:21000,192.168.47.189:21000,192.168.47.190:21000
 
#设置最大连接数
maxConns = 20000
```

启动三台服务器的mongos server

```shell
[root@t3 ~]# mkdir -p /app/mongodb/mongos/log
[root@t3 logs]# /app/mongodb/bin/mongos -f /app/mongodb/conf/mongos.conf
about to fork child process, waiting until server is ready for connections.
forked process: 9226
child process started successfully, parent exiting
```

### 4. 串联路由服务器

​		目前搭建了mongodb配置服务器、路由服务器，各个分片服务器，不过应用程序连接到mongos路由服务器并不能使用分片机制，还需要在程序里设置分片配置，让分片生效。



登陆任意一台mongos

```shell
[root@t1 conf]# /app/mongodb/bin/mongo --port 20000

#使用admin数据库
use  admin

#串联路由服务器与分配副本集
sh.addShard("shard1/192.168.47.188:27001,192.168.47.189:27001,192.168.47.190:27001");
sh.addShard("shard2/192.168.47.188:27002,192.168.47.189:27002,192.168.47.190:27002");
sh.addShard("shard3/192.168.47.188:27003,192.168.47.189:27003,192.168.47.190:27003");
#查看集群状态
sh.status()
```

响应内容如下

```cpp
mongos> use  admin
switched to db admin
mongos> sh.addShard("shard1/192.168.47.188:27001,192.168.47.189:27001,192.168.47.190:27001");
{
        "shardAdded" : "shard1",
        "ok" : 1,
        "operationTime" : Timestamp(1596361773, 6),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1596361773, 6),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
mongos> sh.addShard("shard2/192.168.47.188:27002,192.168.47.189:27002,192.168.47.190:27002");
{
        "shardAdded" : "shard2",
        "ok" : 1,
        "operationTime" : Timestamp(1596361780, 4),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1596361780, 4),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
mongos> sh.addShard("shard3/192.168.47.188:27003,192.168.47.189:27003,192.168.47.190:27003");
{
        "shardAdded" : "shard3",
        "ok" : 1,
        "operationTime" : Timestamp(1596361785, 2),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1596361785, 2),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}

mongos> sh.status()
--- Sharding Status --- 
  sharding version: {
        "_id" : 1,
        "minCompatibleVersion" : 5,
        "currentVersion" : 6,
        "clusterId" : ObjectId("5f267c56fa6ddb9a93f6d800")
  }
  shards:
        {  "_id" : "shard1",  "host" : "shard1/192.168.47.188:27001,192.168.47.189:27001",  "state" : 1 }
        {  "_id" : "shard2",  "host" : "shard2/192.168.47.189:27002,192.168.47.190:27002",  "state" : 1 }
        {  "_id" : "shard3",  "host" : "shard3/192.168.47.188:27003,192.168.47.190:27003",  "state" : 1 }
  active mongoses:
        "4.2.1" : 3
  autosplit:
        Currently enabled: yes
  balancer:
        Currently enabled:  yes
        Currently running:  no
        Failed balancer rounds in last 5 attempts:  0
        Migration Results for the last 24 hours: 
                No recent migrations
  databases:
        {  "_id" : "config",  "primary" : "config",  "partitioned" : true }
                config.system.sessions
                        shard key: { "_id" : 1 }
                        unique: false
                        balancing: true
                        chunks:
                                shard1  1
                        { "_id" : { "$minKey" : 1 } } -->> { "_id" : { "$maxKey" : 1 } } on : shard1 Timestamp(1, 0) 
```

## 5. 启用集合分片生效

​		目前配置服务、路由服务、分片服务、副本集服务都已经串联起来了，但我们的目的是希望插入数据，数据能够自动分片。连接在mongos上，准备让指定的数据库、指定的集合分片生效。

登陆任意一台mongos

```shell
[root@t1 ~]# /app/mongodb/bin/mongo --port 20000

#使用admin数据库
use  admin
```

指定testdb分片生效

```cpp
mongos> db.runCommand( { enablesharding :"testdb"});
或
mongos> sh.enablesharding("testdb")

mongos> db.runCommand( { enablesharding :"testdb"});
{
        "ok" : 1,
        "operationTime" : Timestamp(1596362245, 4),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1596362245, 4),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
```

指定数据库里需要分片的集合和片键，哈希name分片

```cpp
db.runCommand( { shardcollection : "testdb.table1",key : {"name": "hashed"} } );
或
mongos> sh.shardcollection("testdb.table1", {"name": "hashed"})

mongos> db.runCommand( { shardcollection : "testdb.table1",key : {"name": "hashed"} } );
{
        "collectionsharded" : "testdb.table1",
        "collectionUUID" : UUID("15567b49-f3c4-4ebb-a08f-62afe78da4e6"),
        "ok" : 1,
        "operationTime" : Timestamp(1596362380, 39),
        "$clusterTime" : {
                "clusterTime" : Timestamp(1596362380, 39),
                "signature" : {
                        "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
                        "keyId" : NumberLong(0)
                }
        }
}
```

### 六、测试

```
# 任意一节点操作
mongo --port 20000
use admin
db.runCommand( { enablesharding  : "testdb1"});
db.runCommand( { shardcollection : "testdb1.tab1",key : {id: 1} } )
exit
# 创建一个testdb1库，指定该库分片
# 分配testdb1库的需要分片的集合和键
# 任意一节点操作
mongo 127.0.0.1:20000
use testdb1;
for(var i=1;i<=100;i++) db.tab1.save({id:i,"test1":"testval1"});
exit
# 任意一节点操作
mongo 127.0.0.1:20000
use testdb1;
db.tab1.stats();
exit
# 使用testdb1库
# 循环插入数据到testdb1库的tab1集合中的键id中
# 该库对应的该集合对应的该键被设置成了分片
```

七、启动

```
启动

mongodb的启动顺序是，先启动配置服务器，在启动分片，最后启动mongos.

mongod -f /app/mongodb/conf/config.conf
mongod -f /app/mongodb/conf/shard1.conf
mongod -f /app/mongodb/conf/shard2.conf
mongod -f /app/mongodb/conf/shard3.conf
mongod -f /app/mongodb/conf/mongos.conf
```

关闭时，直接killall杀掉所有进程

```undefined
killall mongod
killall mongos
```

参考：https://www.jianshu.com/p/e7e70ca7c7e5


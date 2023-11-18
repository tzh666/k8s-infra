#### 7、MongoDB Sharding Cluster 分片集群

```shell
# 功能说明
mongos     		#只接收请求，接收请求后询问config server端，数据要存在哪个shard上
shard	   		#真正存储数据的地方
config server	#记录shard的状态
```

##### 7.1 规划

```shell
10个实例：38017-38026
（1）configserver:38018-38020
3台构成的复制集（1主两从，不支持arbiter）38018-38020（复制集名字configsvr）
（2）shard节点：
sh1：38021-23    （1主两从，其中一个节点为arbiter，复制集名字sh1）
sh2：38024-26    （1主两从，其中一个节点为arbiter，复制集名字sh2）
（3） mongos:
38017
```

##### 7.2 Shard节点配置过程

###### 7.2.1 目录创建：

```bash
mkdir -p /app/mongodb/38021/conf  /app/mongodb/38021/logs  /app/mongodb/38021/data
mkdir -p /app/mongodb/38022/conf  /app/mongodb/38022/logs  /app/mongodb/38022/data
mkdir -p /app/mongodb/38023/conf  /app/mongodb/38023/logs  /app/mongodb/38023/data
mkdir -p /app/mongodb/38024/conf  /app/mongodb/38024/logs  /app/mongodb/38024/data
mkdir -p /app/mongodb/38025/conf  /app/mongodb/38025/logs  /app/mongodb/38025/data
mkdir -p /app/mongodb/38026/conf  /app/mongodb/38026/logs  /app/mongodb/38026/data
```

###### 7.2.2 修改配置文件：

###### 第一组复制集搭建：21-23（1主 1从 1Arb）

```tsx
cat >  /app/mongodb/38021/conf/mongodb.conf  <<EOF
systemLog:
  destination: file
  path: /app/mongodb/38021/logs/mongodb.logs   
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /app/mongodb/38021/data
  directoryPerDB: true
  #engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true
net:
  bindIp: 192.168.1.111,127.0.0.1
  port: 38021
replication:
  oplogSizeMB: 2048
  replSetName: sh1
sharding:
  clusterRole: shardsvr
processManagement: 
  fork: true
EOF
\cp  /app/mongodb/38021/conf/mongodb.conf  /app/mongodb/38022/conf/
\cp  /app/mongodb/38021/conf/mongodb.conf  /app/mongodb/38023/conf/

sed 's#38021#38022#g' /app/mongodb/38022/conf/mongodb.conf -i
sed 's#38021#38023#g' /app/mongodb/38023/conf/mongodb.conf -i
```

###### 第二组节点：24-26(1主1从1Arb)

```jsx
cat > /app/mongodb/38024/conf/mongodb.conf <<EOF
systemLog:
  destination: file
  path: /app/mongodb/38024/logs/mongodb.logs   
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /app/mongodb/38024/data
  directoryPerDB: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true
net:
  bindIp: 192.168.1.111,127.0.0.1
  port: 38024
replication:
  oplogSizeMB: 2048
  replSetName: sh2
sharding:
  clusterRole: shardsvr
processManagement: 
  fork: true
EOF

\cp  /app/mongodb/38024/conf/mongodb.conf  /app/mongodb/38025/conf/
\cp  /app/mongodb/38024/conf/mongodb.conf  /app/mongodb/38026/conf/
sed 's#38024#38025#g' /app/mongodb/38025/conf/mongodb.conf -i
sed 's#38024#38026#g' /app/mongodb/38026/conf/mongodb.conf -i
```

###### 7.2.3 启动所有节点，并搭建复制集

```bash
mongod -f  /app/mongodb/38021/conf/mongodb.conf 
mongod -f  /app/mongodb/38022/conf/mongodb.conf 
mongod -f  /app/mongodb/38023/conf/mongodb.conf 
mongod -f  /app/mongodb/38024/conf/mongodb.conf 
mongod -f  /app/mongodb/38025/conf/mongodb.conf 
mongod -f  /app/mongodb/38026/conf/mongodb.conf  
ps -ef |grep mongod

mongo --port 38021
use  admin
config = {_id: 'sh1', members: [
                          {_id: 0, host: '192.168.1.111:38021'},
                          {_id: 1, host: '192.168.1.111:38022'},
                          {_id: 2, host: '192.168.1.111:38023',"arbiterOnly":true}]
           }

rs.initiate(config)
  
 mongo --port 38024 
 use admin
config = {_id: 'sh2', members: [
                          {_id: 0, host: '192.168.1.111:38024'},
                          {_id: 1, host: '192.168.1.111:38025'},
                          {_id: 2, host: '192.168.1.111:38026',"arbiterOnly":true}]
           }
  
rs.initiate(config)
```

##### 7.3 config节点配置

###### 7.3.1 目录创建

```bash
mkdir -p /app/mongodb/38018/conf  /app/mongodb/38018/logs  /app/mongodb/38018/data
mkdir -p /app/mongodb/38019/conf  /app/mongodb/38019/logs  /app/mongodb/38019/data
mkdir -p /app/mongodb/38020/conf  /app/mongodb/38020/logs  /app/mongodb/38020/data
```

###### 7.3.2修改配置文件：

```tsx
cat > /app/mongodb/38018/conf/mongodb.conf <<EOF
systemLog:
  destination: file
  path: /app/mongodb/38018/logs/mongodb.conf
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /app/mongodb/38018/data
  directoryPerDB: true
  #engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
      directoryForIndexes: true
    collectionConfig:
      blockCompressor: zlib
    indexConfig:
      prefixCompression: true
net:
  bindIp: 192.168.1.111,127.0.0.1
  port: 38018
replication:
  oplogSizeMB: 2048
  replSetName: configReplSet
sharding:
  clusterRole: configsvr
processManagement: 
  fork: true
EOF

\cp /app/mongodb/38018/conf/mongodb.conf /app/mongodb/38019/conf/
\cp /app/mongodb/38018/conf/mongodb.conf /app/mongodb/38020/conf/
sed 's#38018#38019#g' /app/mongodb/38019/conf/mongodb.conf -i
sed 's#38018#38020#g' /app/mongodb/38020/conf/mongodb.conf -i
```

###### 7.3.3启动节点，并配置复制集

```bash
mongod -f /app/mongodb/38018/conf/mongodb.conf 
mongod -f /app/mongodb/38019/conf/mongodb.conf 
mongod -f /app/mongodb/38020/conf/mongodb.conf 

mongo --port 38018
use  admin
 config = {_id: 'configReplSet', members: [
                          {_id: 0, host: '192.168.1.111:38018'},
                          {_id: 1, host: '192.168.1.111:38019'},
                          {_id: 2, host: '192.168.1.111:38020'}]
           }
rs.initiate(config)  
  
注：configserver 可以是一个节点，官方建议复制集。configserver不能有arbiter。
新版本中，要求必须是复制集。
注：mongodb 3.4之后，虽然要求config server为replica set，但是不支持arbiter
```

##### 7.4 mongos节点配置：

###### 7.4.1创建目录：

```bash
mkdir -p /app/mongodb/38017/conf  /app/mongodb/38017/logs 
```

###### 7.4.2配置文件：

```cpp
cat > /app/mongodb/38017/conf/mongos.conf <<EOF
systemLog:
  destination: file
  path: /app/mongodb/38017/logs/mongos.logs
  logAppend: true
net:
  bindIp: 192.168.1.111,127.0.0.1
  port: 38017
sharding:
  configDB: configReplSet/192.168.1.111:38018,192.168.1.111:38019,192.168.1.111:38020
processManagement: 
  fork: true
EOF
```

###### 7.4.3启动mongos

```undefined
 mongos -f /app/mongodb/38017/conf/mongos.conf 
```

##### 7.5 分片集群添加节点

```ruby
 连接到其中一个mongos（192.168.1.111），做以下配置
（1）连接到mongs的admin数据库
# su - mongod
$ mongo 192.168.1.111:38017/admin
（2）添加分片
db.runCommand( { addshard : "sh1/192.168.1.111:38021,192.168.1.111:38022,192.168.1.111:38023",name:"shard1"} )
db.runCommand( { addshard : "sh2/192.168.1.111:38024,192.168.1.111:38025,192.168.1.111:38026",name:"shard2"} )
（3）列出分片
mongos> db.runCommand( { listshards : 1 } )
（4）整体状态查看
mongos> sh.status();
```

##### 7.6 使用分片集群

###### 7.6.1 RANGE分片配置及测试

###### 1、激活数据库分片功能

```css
mongo --port 38017 admin
admin>  ( { enablesharding : "数据库名称" } )
eg：
admin> db.runCommand( { enablesharding : "test" } )
```

###### 2、指定分片键对集合分片

```css
### 创建索引
use test
> db.vast.ensureIndex( { id: 1 } )
### 开启分片
use admin
> db.runCommand( { shardcollection : "test.vast",key : {id: 1} } )
```

###### 3、集合分片验证

```bash
admin> use test
test> for(i=1;i<1000000;i++){ db.vast.insert({"id":i,"name":"shenzheng","age":70,"date":new Date()}); }
test> db.vast.stats()
```

###### 4、分片结果测试

```css
shard1:
mongo --port 38021
db.vast.count();

shard2:
mongo --port 38024
db.vast.count();
```

###### 7.6.2 Hash分片例子：

```rust
对oldboy库下的vast大表进行hash
创建哈希索引
（1）对于oldboy开启分片功能
mongo --port 38017 admin
use admin
admin> db.runCommand( { enablesharding : "oldboy" } )
（2）对于oldboy库下的vast表建立hash索引
use oldboy
oldboy> db.vast.ensureIndex( { id: "hashed" } )
（3）开启分片 
use admin
admin > sh.shardCollection( "oldboy.vast", { id: "hashed" } )
（4）录入10w行数据测试
use oldboy
for(i=1;i<100000;i++){ db.vast.insert({"id":i,"name":"shenzheng","age":70,"date":new Date()}); }
（5）hash分片结果测试
mongo --port 38021
use oldboy
db.vast.count();
mongo --port 38024
use oldboy
db.vast.count();
```

##### 7.7 分片集群的查询及管理

###### 7.7.1 判断是否Shard集群

```css
admin> db.runCommand({ isdbgrid : 1})
```

###### 7.7.2 列出所有分片信息

```css
admin> db.runCommand({ listshards : 1})
```

###### 7.7.3 列出开启分片的数据库

```swift
admin> use config
config> db.databases.find( { "partitioned": true } )
或者：
config> db.databases.find() //列出所有数据库分片情况
```

###### 7.7.4 查看分片的片键

```swift
config> db.collections.find().pretty()
{
    "_id" : "test.vast",
    "lastmodEpoch" : ObjectId("58a599f19c898bbfb818b63c"),
    "lastmod" : ISODate("1970-02-19T17:02:47.296Z"),
    "dropped" : false,
    "key" : {
        "id" : 1
    },
    "unique" : false
}
```

###### 7.7.5 查看分片的详细信息

```css
admin> sh.status()
```

###### 7.7.6 删除分片节点（谨慎）

```css
（1）确认blance是否在工作
sh.getBalancerState()
（2）删除shard2节点(谨慎)
mongos> db.runCommand( { removeShard: "shard2" } )
注意：删除操作一定会立即触发blancer。
```

##### 7.8 balancer操作

###### 7.8.1 介绍

```css
mongos的一个重要功能，自动巡查所有shard节点上的chunk的情况，自动做chunk迁移。
什么时候工作？
1、自动运行，会检测系统不繁忙的时候做迁移
2、在做节点删除的时候，立即开始迁移工作
3、balancer只能在预设定的时间窗口内运行

有需要时可以关闭和开启blancer（备份的时候）
mongos> sh.stopBalancer()
mongos> sh.startBalancer()
```

###### 7.8.2 自定义 自动平衡进行的时间段

```objectivec
https://docs.mongodb.com/manual/tutorial/manage-sharded-cluster-balancer/#schedule-the-balancing-window
// connect to mongos

mongo --port 38017 admin
use config
sh.setBalancerState( true )
db.settings.update({ _id : "balancer" }, { $set : { activeWindow : { start : "3:00", stop : "5:00" } } }, true )

sh.getBalancerWindow()
sh.status()

关于集合的balancer（了解下）
关闭某个集合的balance
sh.disableBalancing("students.grades")
打开某个集合的balancer
sh.enableBalancing("students.grades")
确定某个集合的balance是开启或者关闭
db.getSiblingDB("config").collections.findOne({_id : "students.grades"}).noBalance;
```


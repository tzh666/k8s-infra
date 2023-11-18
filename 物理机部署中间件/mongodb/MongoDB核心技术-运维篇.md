## MongoDB核心技术-运维篇

### 第一章：逻辑结构

```cpp
Mongodb 逻辑结构                         MySQL逻辑结构
库database                                 库
集合（collection）                          表
文档（document）                            数据行
```

### 第二章：安装部署

#### 2.1、下载

```shell
root@master app]# wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-3.6.20.tgz
```

#### 2.2、安装

##### 2.2.1、安装前提

```shell
前提：
	（1）redhat或centos6.2以上系统
	（2）系统开发包完整
	（3）ip地址和hosts文件解析正常
	（4）iptables防火墙&SElinux关闭
	（5）关闭大页内存机制
root用户下，添加完毕重启生效
在vim /etc/rc.local最后添加如下代码
[root@master mongodb]# cat >>  /etc/rc.local << EFO
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EFO
[root@master mongodb]# reboot
```

##### 2.2.2、安装步骤

```shell
# 解压安装包、重命名
[root@master app]# tar -zxvf  mongodb-linux-x86_64-rhel70-3.6.20.tgz 
[root@master app]# mv mongodb-linux-x86_64-rhel70-3.6.20 mongodb && cd mongodb
```

```shell
# 创建日志、数据、配置文件、pid目录
[root@master mongodb]# mkdir  {logs,data,conf,pid}

# 创建用户和组
[root@master mongodb]# useradd mongod
[root@master mongodb]# passwd mongod

# 设置目录结构权限
[root@master mongodb]# chown -R mongod:mongod /app/mongodb/
```

```shell
# 设置用户环境变量
[root@master ~]# su - mongod

# 在最末尾添加
[mongod@master ~]$ vim .bash_profile
export PATH=/app/mongodb/bin:$PATH

[mongod@master ~]$ source .bash_profile
```

##### 2.2.3、启动mongodb

```shell
[mongod@master ~]$ mongod --dbpath=/app/mongodb/data --logpath=/app/mongodb/logs/mongodb.log --pidfilepath=/app/mongodb/pid/mongodb.pid --port=27017 --logappend --fork 
```

##### 2.2.4、登录mongodb

```shell
[mongod@master mongodb]$ mongo
```

#### 2.3、使用配置文件

```shell
YAML模式

--系统日志有关  
systemLog:
   destination: file        
   path: "/app/mongodb/logs/mongodb.log"    --日志位置
   logAppend: true                          --日志以追加模式记录
  
--数据存储有关   
storage:
   journal:
      enabled: true
   dbPath: "/app/mongodb/data"              --数据路径的位置

-- 进程控制  
processManagement:
   fork: true                         --后台守护进程
   pidFilePath: "/app/mongodb/pid"    --pid文件的位置，一般不用配置，可以去掉这行，自动生成到data中
    
--网络配置有关   
net:            
   bindIp: 0.0.0.0                    -- 监听地址
   port: <port>                       -- 端口号,默认不配置端口号，是27017
   
-- 安全验证有关配置      
security:
  authorization: enabled              --是否打开用户名密码验证
  
------------------以下是复制集与分片集群有关----------------------  

replication:
 oplogSizeMB: <NUM>
 replSetName: "<REPSETNAME>"
 secondaryIndexPrefetch: "all"
 
sharding:
   clusterRole: <string>
   archiveMovedChunks: <boolean>
      
---for mongos only
replication:
   localPingThresholdMs: <int>

sharding:
   configDB: <string>
---
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
YAML例子，（mongod用户下）
[mongod@master ~]$ cat >  /app/mongodb/conf/mongo.conf <<EOF
systemLog:
   destination: file
   path: "/app/mongodb/logs/mongodb.log"
   logAppend: true
storage:
   journal:
      enabled: true
   dbPath: "/app/mongodb/data/"
processManagement:
   fork: true
net:
   port: 27017
   bindIp: 0.0.0.0
EOF

# 停止之前启动的（mongod用户下）
[mongod@master ~]$ mongod -f /app/mongodb/conf/mongo.conf --shutdown

# 再次启动更改过配置文件之后的（mongod用户下）
[mongod@master ~]$ mongod -f /app/mongodb/conf/mongo.conf
```

#### 2.4、使用systemd管理mongodb（root用户下）

```ruby
[root@master ~]#  cat > /etc/systemd/system/mongod.service <<EOF
[Unit]
Description=mongodb 
After=network.target remote-fs.target nss-lookup.target
[Service]
User=mongod
Type=forking
ExecStart=/app/mongodb/bin/mongod --config /app/mongodb/conf/mongo.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/app/mongodb/bin/mongod --config /app/mongodb/conf/mongo.conf --shutdown
PrivateTmp=true  
[Install]
WantedBy=multi-user.target
EOF

# 试试命令吧，报错的话把data的数据干掉就行
[root@master ~]# systemctl restart mongod
[root@master ~]# systemctl stop mongod
[root@master ~]# systemctl start mongod
[root@master ~]# systemctl status mongod
```

#### 3、mongodb常用基本操作

##### 3.1、mongodb 默认存在的库

```plsql
test:登录时默认存在的库
管理MongoDB有关的系统库
admin库:系统预留库,MongoDB系统管理库
local库:本地预留库,存储关键日志
config库:MongoDB配置信息库

--- 基本命令：
	> show databases
	> show dbs
	> show tables
	> show collections
	> use admin 
	> db
```

#### 3.2、mongodb 命令种类

##### 3.2.1、db 对象相关命令

```plsql
db.[TAB][TAB]
db.help()
db.tzh.[TAB][TAB]
db.tzh.help()
```

##### 3.2.2、rs 复制集有关(replication set)

```plsql
rs.[TAB][TAB]
rs.help()
```

##### 3.2.3、sh 分片集群(sharding cluster)

```mysql
sh.[TAB][TAB]
sh.help()
```

#### 4、mongodb对象操作

```rust
mongo         mysql
库    ----->  库
集合  ----->  表
文档  ----->  数据行
```

##### 4.1、 库的操作

```bash
> use test
>db.dropDatabase()   
{ "dropped" : "test", "ok" : 1 }
```

##### 4.2 、集合的操作

```objectivec
app> db.createCollection('a')
{ "ok" : 1 }
app> db.createCollection('b')
方法2：当插入一个文档的时候，一个集合就会自动创建。

use oldboy
db.test.insert({name:"zhangsan"})
db.stu.insert({id:101,name:"zhangsan",age:20,gender:"m"})
show tables;
db.stu.insert({id:102,name:"lisi"})
db.stu.insert({a:"b",c:"d"})
db.stu.insert({a:1,c:2})
```

##### 4.3、 文档操作

```cpp
数据录入：
for(i=0;i<10000;i++){db.log.insert({"uid":i,"name":"mongodb","age":6,"date":new
Date()})}

查询数据行数：
> db.log.count()
全表查询：
> db.log.find()
每页显示50条记录：
> DBQuery.shellBatchSize=50; 
按照条件查询
> db.log.find({uid:999})
以标准的json格式显示数据
> db.log.find({uid:999}).pretty()
{
    "_id" : ObjectId("5cc516e60d13144c89dead33"),
    "uid" : 999,
    "name" : "mongodb",
    "age" : 6,
    "date" : ISODate("2019-04-28T02:58:46.109Z")
}
删除集合中所有记录
app> db.log.remove({})
```

#### 5、用户及权限管理

##### 5.1 、注意

```rust
验证库: 建立用户时use到的库，在使用用户时，要加上验证库才能登陆。

对于管理员用户,必须在admin下创建.
1. 建用户时,use到的库,就是此用户的验证库
2. 登录时,必须明确指定验证库才能登录
3. 通常,管理员用的验证库是admin,普通用户的验证库一般是所管理的库设置为验证库
4. 如果直接登录到数据库,不进行use,默认的验证库是test,不是我们生产建议的.
5. 从3.6 版本开始，不添加bindIp参数，默认不让远程登录，只能本地管理员登录。
```

##### 5.2 、用户创建语法

```bash
use admin 
db.createUser
{
    user: "<name>",
    pwd: "<cleartext password>",
    roles: [
       { role: "<role>",
     db: "<database>" } | "<role>",
    ...
    ]
}

基本语法说明：
user:用户名
pwd:密码
roles:
    role:角色名
    db:作用对象
role：root, readWrite,read   
```

##### 5.3、 用户管理例子

```rust
# 创建超级管理员：管理所有数据库（必须use admin再去创建
$ mongo
use admin
db.createUser(
{
    user: "root",
    pwd: "root123",
    roles: [ { role: "root", db: "admin" } ]
}
)

use xxx   (use的库是xxx,就不能新建root权限的用户)
db.createUser(
{
    user: "xxx",
    pwd: "xxx123",
    roles: [ { role: "readWrite", db: "xxx" } ]
}
)
```

##### 5.4、验证用户

```bash
# 返回1说明创建成功
db.auth('root','root123')
```

##### 5.5、用刚刚创建的用户登录看看

###### 5.5.1、先加个验证的参数

```shell
[mongod@master ~]$ vim /app/mongodb/conf/mongo.conf
security:
  authorization: enabled

# 重启mongodb（root下）
[root@master ~]# systemctl restart mongod

#重启mongodb（mongod下）
[mongod@master ~]$ mongod -f /app/mongodb/conf/mongo.conf --shutdown 
[mongod@master ~]$ mongod -f /app/mongodb/conf/mongo.conf 
```

###### 5.5.2、登录验证

```shell
[mongod@master ~]$ mongo -uroot -proot123  admin
[mongod@master ~]$ mongo -uroot -proot123  192.168.1.111/admin   (后面这个admin一定要加，不加验证库是无法登录的)

# 登录不上，不加验证库
[mongod@master ~]$ mongo -uroot -proot123  192.168.1.111
MongoDB shell version v3.6.20
connecting to: mongodb://192.168.1.111:27017/test?gssapiServiceName=mongodb
2020-11-29T21:45:56.273+0800 E QUERY    [thread1] Error: Authentication failed. :
connect@src/mongo/shell/mongo.js:275:13
@(connect):1:6
exception: connect failed
======================================================
# 或者
[mongod@master ~]$ mongo
> use admin
switched to db admin
> db.auth('root','root123')
1
```

###### 5.5.3、登录上去后新建角色玩玩

```shell
# 查看用户:
> use admin
switched to db admin
> db.system.users.find().pretty()

# 创建应用用户
> use root
switched to db root
db.createUser(
{
    user: "qqaz",
    pwd: "qqaz123",
    roles: [ { role: "readWrite", db: "root" } ]
}
)
Successfully added user: {
	"user" : "qqaz",
	"roles" : [
		{
			"role" : "readWrite",
			"db" : "root"
		}
	]
}

# 查询mongodb中的用户信息
[mongod@master ~]$ mongo -uqqaz -pqqaz123 192.168.1.111/root
> db.system.users.find().pretty()
```

##### 5.6、删除用户（root身份登录，use到验证库）

```bash
# 1、使用管理员用户登录
[mongod@master ~]$ mongo -uroot -proot123 192.168.1.111/admin

# 2、use到验证库（删除qqaz,qqaz用户是在root库创建的，所以得先use到root验证库）
> use root
switched to db tzh
# 3、删除用户
> db.dropUser("qqaz")
true
```

##### 5.7、用户管理注意事项

```undefined
1. 建用户要有验证库，管理员admin，普通用户是要管理的库
2. 登录时，注意验证库
mongo -uapp01 -papp01 192.168.1.111/admin
3. 重点参数
net:
   port: 27017
   bindIp: 192.168.1.111,127.0.0.1
security:
   authorization: enabled
```

#### 6、MongoDB复制集RS（ReplicationSet）

##### 6.1 基本原理

```undefined
基本构成是1主2从的结构，自带互相监控投票机制（Raft（MongoDB）  Paxos（mysql MGR 用的是变种））
如果发生主库宕机，复制集内部会进行投票选举，选择一个新的主库替代原有主库对外提供服务。同时复制集会自动通知
客户端程序，主库已经发生切换了。应用就会连接到新的主库。
```

#### 6.2 Replication Set配置过程详解

##### 6.2.1  规划

```undefined
三个以上的mongodb节点（或多实例）
```

##### 6.2.2 环境准备

###### 多个端口：

```undefined
28017、28018、28019、28020
```

###### 多套目录：

```bash
su - mongod 
mkdir -p /mongodb/28017/conf /mongodb/28017/data /mongodb/28017/log
mkdir -p /mongodb/28018/conf /mongodb/28018/data /mongodb/28018/log
mkdir -p /mongodb/28019/conf /mongodb/28019/data /mongodb/28019/log
mkdir -p /mongodb/28020/conf /mongodb/28020/data /mongodb/28020/log
```

###### 多套配置文件

```undefined
/mongodb/28017/conf/mongod.conf
/mongodb/28018/conf/mongod.conf
/mongodb/28019/conf/mongod.conf
/mongodb/28020/conf/mongod.conf
```

###### 配置文件内容

```tsx
cat > /mongodb/28017/conf/mongod.conf <<EOF
systemLog:
  destination: file
  path: /mongodb/28017/log/mongodb.log
  logAppend: true
storage:
  journal:
    enabled: true
  dbPath: /mongodb/28017/data
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
processManagement:
  fork: true
net:
  bindIp: 10.0.0.51,127.0.0.1
  port: 28017
replication:
  oplogSizeMB: 2048
  replSetName: my_repl
EOF
        

cp  /mongodb/28017/conf/mongod.conf  /mongodb/28018/conf/
cp  /mongodb/28017/conf/mongod.conf  /mongodb/28019/conf/
cp  /mongodb/28017/conf/mongod.conf  /mongodb/28020/conf/

sed 's#28017#28018#g' /mongodb/28018/conf/mongod.conf -i
sed 's#28017#28019#g' /mongodb/28019/conf/mongod.conf -i
sed 's#28017#28020#g' /mongodb/28020/conf/mongod.conf -i
```

###### 启动多个实例备用

```undefined
mongod -f /mongodb/28017/conf/mongod.conf
mongod -f /mongodb/28018/conf/mongod.conf
mongod -f /mongodb/28019/conf/mongod.conf
mongod -f /mongodb/28020/conf/mongod.conf
netstat -lnp|grep 280
```

#### 6.3 配置普通复制集：

```bash
1主2从，从库普通从库
mongo --port 28017 admin
config = {_id: 'my_repl', members: [
                          {_id: 0, host: '10.0.0.51:28017'},
                          {_id: 1, host: '10.0.0.51:28018'},
                          {_id: 2, host: '10.0.0.51:28019'}]
          }                   
rs.initiate(config) 
查询复制集状态
rs.status();
```

#### 6.4 1主1从1个arbiter

```bash
mongo -port 28017 admin
config = {_id: 'my_repl', members: [
                          {_id: 0, host: '10.0.0.51:28017'},
                          {_id: 1, host: '10.0.0.51:28018'},
                          {_id: 2, host: '10.0.0.51:28019',"arbiterOnly":true}]
          }                
rs.initiate(config) 
```

#### 6.5 复制集管理操作

##### 6.5.1 查看复制集状态

```cpp
rs.status();    //查看整体复制集状态
rs.isMaster(); // 查看当前是否是主节点
rs.conf()；   //查看复制集配置信息
```

##### 6.5.2 添加删除节点

```csharp
rs.remove("ip:port"); // 删除一个节点
rs.add("ip:port"); // 新增从节点
rs.addArb("ip:port"); // 新增仲裁节点
例子：
添加 arbiter节点
1、连接到主节点
[mongod@db03 ~]$ mongo --port 28018 admin
2、添加仲裁节点
my_repl:PRIMARY> rs.addArb("192.168.1.111:28020")
3、查看节点状态
my_repl:PRIMARY> rs.isMaster()
{
    "hosts" : [
        "192.168.1.111:28017",
        "192.168.1.111:28018",
        "192.168.1.111:28019"
    ],
    "arbiters" : [
        "192.168.1.111:28020"
    ],

rs.remove("ip:port"); // 删除一个节点
例子：
my_repl:PRIMARY> rs.remove("192.168.1.111:28019");
{ "ok" : 1 }
my_repl:PRIMARY> rs.isMaster()
rs.add("ip:port"); // 新增从节点
例子：
my_repl:PRIMARY> rs.add("192.168.1.111:28019")
{ "ok" : 1 }
my_repl:PRIMARY> rs.isMaster()
```

##### 6.5.3 特殊从节点

```undefined
arbiter节点：主要负责选主过程中的投票，但是不存储任何数据，也不提供任何服务
hidden节点：隐藏节点，不参与选主，也不对外提供服务。
delay节点：延时节点，数据落后于主库一段时间，因为数据是延时的，也不应该提供服务或参与选主，所以通常会配合hidden（隐藏）
一般情况下会将delay+hidden一起配置使用
```

###### 6.5.3.1配置延时节点（一般延时节点也配置成hidden）

```bash
# [2] 这个2，如果是新集群（id号码是连续的时候），可以对应上_id的值，如果不是，那就数从0开始数
cfg=rs.conf() 
cfg.members[2].priority=0      #参与选主的权重值  
cfg.members[2].hidden=true     #是否隐藏，是
cfg.members[2].slaveDelay=120  #120秒
cfg.members[2].votes=0		   #持有的票数为0
rs.reconfig(cfg)               #重新加载配置文件


取消以上配置
cfg=rs.conf() 
cfg.members[2].priority=1
cfg.members[2].hidden=false
cfg.members[2].votes=1
cfg.members[2].slaveDelay=0
rs.reconfig(cfg)    
配置成功后，通过以下命令查询配置后的属性
rs.conf(); 
```

##### 6.5.4 副本集其他操作命令

```rust
查看副本集的配置信息
admin> rs.conf()
查看副本集各成员的状态
admin> rs.status()
++++++++++++++++++++++++++++++++++++++++++++++++
--副本集角色切换（不要人为随便操作）
admin> rs.stepDown()
注：
admin> rs.freeze(300) //锁定从，使其不会转变成主库
freeze()和stepDown单位都是秒。
+++++++++++++++++++++++++++++++++++++++++++++
设置副本节点可读：在副本节点执行
admin> rs.slaveOk()
eg：
admin> use app
switched to db app
app> db.createCollection('a')
{ "ok" : 0, "errmsg" : "not master", "code" : 10107 }

查看副本节点（监控主从延时）
admin> rs.printSlaveReplicationInfo()
source: 192.168.1.22:27017
    syncedTo: Thu May 26 2016 10:28:56 GMT+0800 (CST)
    0 secs (0 hrs) behind the primary

OPlog日志（备份恢复章节）
```

##### 
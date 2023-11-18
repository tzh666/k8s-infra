## MongoDB单机部署

### 一、环境

```
系统：centos7.6

DB版本：mongodb-linux-x86_64-rhel62-4.2.1.tgz

官网地址：https://www.mongodb.com

wget https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.4/x86_64/RPMS/mongodb-org-server-4.4.0-1.el7.x86_64.rpm
```

### 二、安装

```shell
[root@t1 ~]# tar -zxvf mongodb-linux-x86_64-rhel62-4.2.1.tgz  -C /app/
[root@t1 app]# cd /app && mv mongodb-linux-x86_64-rhel62-4.2.1/ mongodb && cd mongodb
#创建日志、数据、配置文件、pid目录
[root@t1 mongodb]# mkdir  {logs,data,config,pid}  
#创建启动配置文件
[root@t1 config]# vim mongodb.conf 
#端口号
port = 27017 
#数据目录
dbpath = /app/mongodb/data
#日志目录
logpath = /app/mongodb/logs/mongodb.log
#pid目录
pidfilepath = /app/mongodb/pid/mongodb.pid
#设置后台运行
fork = true
#日志输出方式
logappend = true
#开启认证
#auth = true
#本地ip
bind_ip=0.0.0.0
```

### 三、启动

```shell
[root@t1 bin]# ./mongod --config ../config/mongodb.conf  
about to fork child process, waiting until server is ready for connections.
forked process: 10134
child process started successfully, parent exiting
#检查是否启动成功
[root@t1 bin]# ps -ef|grep mongodb
root      10134      1  1 15:42 ?        00:00:01 ./mongod --config ../config/mongodb.conf 
[root@t1 bin]# ss -ntlp|grep 27017
LISTEN     0      128    *:27017    *:*   users:(("mongod",pid=10134,fd=11))
```

### 四、进入数据库

```shell
[root@t1 bin]# ./mongo
MongoDB shell version v4.2.1
connecting to: mongodb://127.0.0.1:27017/?compressors=disabled&gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("0357cfa5-c9d8-4eca-a04e-f49fc137d420") }
MongoDB server version: 4.2.1
Welcome to the MongoDB shell.
For interactive help, type "help".
For more comprehensive documentation, see
        http://docs.mongodb.org/
Questions? Try the support group
        http://groups.google.com/group/mongodb-user
Server has startup warnings: 
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] 
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] ** WARNING: Access control is not enabled for the database.
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] **          Read and write access to data and configuration is unrestricted.
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] ** WARNING: You are running this process as the root user, which is not recommended.
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] 
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] 
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] ** WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] **        We suggest setting it to 'never'
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] 
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] ** WARNING: /sys/kernel/mm/transparent_hugepage/defrag is 'always'.
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] **        We suggest setting it to 'never'
2020-08-02T15:42:38.431+0800 I  CONTROL  [initandlisten] 
---
Enable MongoDB's free cloud-based monitoring service, which will then receive and display
metrics about your deployment (disk utilization, CPU, operation statistics, etc).

The monitoring data will be available on a MongoDB website with a unique URL accessible to you
and anyone you share the URL with. MongoDB may use this information to make product
improvements and to suggest MongoDB products and deployment options to you.

To enable free monitoring, run the following command: db.enableFreeMonitoring()
To permanently disable this reminder, run the following command: db.disableFreeMonitoring()
---

> 
```


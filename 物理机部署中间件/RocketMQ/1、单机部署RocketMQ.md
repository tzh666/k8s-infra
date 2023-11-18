## 单机部署RocketMQ

### 一、下载安装包

- 操作系统 centos7.6
- jdk1.8以上

```sh
# wget下载
wget https://archive.apache.org/dist/rocketmq/4.9.5/rocketmq-all-4.9.5-bin-release.zip
```



### 二、部署RocketMQ

- 上传安装包 sz ftp 都可以

```sh
# 解压安装包
unzip rocketmq-all-4.9.5-bin-release.zip

# 移动到 /app目录
mv rocketmq-all-4.9.5-bin-release /app/rocketmq
```

- 日志目录、数据目录更改/app/rocketmq/conf 在这个目录的几个xml配置文件
- 修改配置文件，生产环境可以根据并发量改大

```sh
# 修改初始内存【修改两个启动脚本的jvm】
cd /app/rocketmq/bin/
# 默认在71行，修改初始堆内存大小，要不测试环境没那么多内存 
原：JAVA_OPT="${JAVA_OPT} -server -Xms4g -Xmx4g -Xmn2g -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m"
改：JAVA_OPT="${JAVA_OPT} -server -Xms1g -Xmx1g -Xmn512m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m"

vim runbroker.sh
# 默认在85行，修改初始堆内存大小，要不测试环境没那么多内存 
原:  JAVA_OPT="${JAVA_OPT} -server -Xms8g -Xmx8g"
改:  JAVA_OPT="${JAVA_OPT} -server -Xms256m -Xmx256m -Xmn128m"
```

- 启动，出现以下日志说明成功启动可以放后台启动

```sh
# 启动NameServer，bin目录前台启动，确定没报错再后台启动  【sh bin/mqnamesrv &】
[root@slavenode1 bin]# ./mqnamesrv
The Name Server boot success. serializeType=JSON

# 启动broker，bin目录前台启动，确定没报错再后台启动
[root@masternode1 bin]# ./mqbroker -n localhost:9876
The broker[masternode1, 192.168.1.160:10911] boot success. serializeType=JSON and name server is localhost:9876

# 查看进程
[root@masternode1 ~]# jps
2214 Jps
2071 BrokerStartup
1947 NamesrvStartup
```

- 发送消息测试 

```sh
[root@masternode1 ~]# cd /app/rocketmq/
[root@masternode1 ~]# export NAMESRV_ADDR=localhost:9876

# 成功执行以后会发送1000条测试数据，执行成功脚本自动推出
[root@masternode1 ~]# sh bin/tools.sh org.apache.rocketmq.example.quickstart.Producer
# 成功最后的两行日志
07:06:35.589 [NettyClientSelector_1] INFO RocketmqRemoting - closeChannel: close the connection to remote address[127.0.0.1:9876] result: true
07:06:35.596 [NettyClientSelector_1] INFO RocketmqRemoting - closeChannel: close the connection to remote address[192.168.1.160:10911] result: true
```

- 接收消息

```sh
# 会接受上面发送的1000条数据
[root@masternode1 rocketmq]# sh bin/tools.sh org.apache.rocketmq.example.quickstart.Consumer
```

**到此，单机版本的MQ部署完成**



### 二、部署RocketMQ控制台

- 建议是用docker部署

```sh
# 下载源码包 # yum install -y git maven
git clone https://github.com/apache/rocketmq-dashboard.git

cd rocketmq-dashboard
mvn clean package -Dmaven.test.skip=true
```

- 打包异常参考

```sh
https://blog.51cto.com/09112012/5045979
```

- 修改文件位置：/app/rocketmq-dashboard/src/test/resources
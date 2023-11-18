## 搭建cassandra 集群

### 一、集群环境规划

| 主机名 |      IP       |      说明      |
| :----: | :-----------: | :------------: |
| node1  | 192.168.1.129 | 已经有JAVA环境 |
| node2  | 192.168.1.130 | 已经有JAVA环境 |
| node3  | 192.168.1.131 | 已经有JAVA环境 |



### 二、所有机器部署cassandra

```shell
# 1、下载（需要JDK环境）
wget https://mirrors.bfsu.edu.cn/apache/cassandra/3.11.10/apache-cassandra-3.11.10-bin.tar.gz

# 2、解压
[root@node1 app]# tar -zxvf apache-cassandra-3.11.10-bin.tar.gz       

# 3、重命名
[root@node1 app]# mv apache-cassandra-3.11.10 cassandra

# 4、创建用户、授权
[root@node1 app]# useradd -m cassandra
[root@node1 app]# chown -R cassandra.cassandra /app/cassandra

# 5、如果启动过cassandra，先把原来的数据删掉。把以下目录的数据删了即可（生产别乱删！！！）
cassandra/saved_caches/*
cassandra/commitlog/*
cassandra/data/*
```



### 三、更改配置文件

`需要对3个服务器上的cassandra配置中的属性seeds、rpc_address、listen_address进行修改`

#### 3.1、node1上

```shell
[root@node1 ~]# su - cassandra
[cassandra@node1 ~]$ vim /app/cassandra/conf/cassandra.yaml

seeds:"192.168.1.129,192.168.1.130,192.168.1.131"   # 三台机器的IP
listen_address:"192.168.1.129"                      # 本机IP
rpc_address:"192.168.1.129"                         # 本机IP
```

#### 3.2、node2上

```shell
[root@node2 ~]# su - cassandra
[cassandra@node1 ~]$ vim /app/cassandra/conf/cassandra.yaml

seeds:"192.168.1.129,192.168.1.130,192.168.1.131"   # 三台机器的IP
listen_address:"192.168.1.130"                      # 本机IP
rpc_address:"192.168.1.130"                         # 本机IP
```

#### 3.3、node3上

```shell
[root@node3 ~]# su - cassandra
[cassandra@node1 ~]$ vim /app/cassandra/conf/cassandra.yaml

seeds:"192.168.1.129,192.168.1.130,192.168.1.131"   # 三台机器的IP
listen_address:"192.168.1.131"                      # 本机IP
rpc_address:"192.168.1.131"                         # 本机IP
```

#### 3.4、分别启动三台主机上的cassandra

```shell
[cassandra@node2 ~]$ cd /app/cassandra
[cassandra@node3 cassandra]$ bin/cassandra

# 查看日志确定没报错
[cassandra@node3 ~]$ cd /app/cassandra/logs/
[cassandra@node3 logs]$ tail -f system.log 
```

#### 3.5、验证集群状态

```shell
# 任意节点查看，可以 查看到目前三个节点都是正常的
[cassandra@node2 ~]$ cd /app/cassandra/bin
[cassandra@node2 bin]$ nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address        Load       Tokens       Owns (effective)  Host ID                               Rack
UN  192.168.1.129  70.67 KiB  256          66.4%             0e70923b-319d-48c4-8cdf-68d112a34d98  rack1
UN  192.168.1.130  70.7 KiB   256          67.5%             c8c09f79-f557-4d72-962a-7e583c1396d7  rack1
UN  192.168.1.131  89.94 KiB  256          66.1%             13c2a66b-26c8-4aa4-8693-76cbb53d8db9  rack1
```

#### 3.6、system管理（可选）

```shell
[root@node1 ~]# cat /usr/lib/systemd/system/cassandra.service
[Unit]
Description=Cassandra
Requires=network.service
After=network.service
[Service]
Type=forking
Environment=JAVA_HOME=/usr/local/java
Environment=LOCAL_JMX=no
PIDFile=/app/cassandra/pid/cassandra.pid
ExecStart=/app/cassandra/bin/cassandra -p /app/cassandra/pid/cassandra.pid
User=cassandra
Group=cassandra
LimitNOFILE=65536
LimitNPROC=65536
LimitMEMLOCK=infinity
SuccessExitStatus=143
[Install]
WantedBy=multi-user.target
```

#### 3.7、参考文献

```shell
https://cassandra.apache.org/doc/latest/getting_started/installing.html#installing-the-binary-tarball
https://www.jianshu.com/p/9f76dc4f0c3e
https://my.oschina.net/colben/blog/3067636
```


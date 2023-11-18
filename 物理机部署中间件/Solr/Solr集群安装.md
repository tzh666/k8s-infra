### Solr集群安装

### 什么是SolrCloud？

​       SolrCloud是基于 solr 和 zookeeper 的分布式搜索方案，它的主要思想是使用zookeeper作为SolrCloud集群的配置信息中心，统一管理SolrCloud的配置。SolrCloud一般都是解决大数据量，大并发的搜索服务。 SolrCloud将索引数据进行shard拆分（分片），每个分片有多台服务器共同完成，当一个索引或搜索请求过来时会分别从不同的shard的服务器中操作索引。

### 什么时候使用到SolrCloud？

​		当你需要大规模，高容错率，分布式索引和检索能力时使用solrcloud。当索引量很大，搜索请求并发很高，这时需要使用solrcloud满足这些需求。当一个系统的索引数据量少的时候是不需要使用solrcloud的。

### SolrCloud有什么特色功能？

​		1、集中式的配置信息：使用zk进行集中配置，启动时可以指定把solr的相关配置文件上传zookeeper，多机器共用同一套配置。这些zk中的配置不会再拿到本地缓存，solr直接读取zk中的配置信息。另外配置文件的变动，所有机器都可以感知到。

​		2、自动容错：solrcloud对索引分片，并对每个分片(shard)创建多个replication。每个 replication 都可以对外提供服务。一个 replication 挂掉不会影响索引服务，更强大的是，solrcloud还能自动的在其它机器上帮你把失败机器上的索引replication重建并投入使用。

​		3、近实时搜索：立即推送式的replication(也支持慢推送)，可以在秒内检索到新加入索引。

​		4、查询时自动负载均衡：solrcloud 索引的多个replication可以分布在多台机器上，均衡查询压力，如果压力大，可以通过扩展机器，增加replication来减缓。

​		5、除此之外，solrcloud还提供了其他一些特色功能：

​					a 、可将索引存储在HDFS上

​					b、 通过MR批量创建索引

​					c、 强大的restful API

### 一、集群安装环境准备

```shell
#首先在三台服务器上单独安装solr（做到解压到/app目录下，可以正常启动就可以了）
可以参考：https://www.cnblogs.com/hsyw/p/13414681.html
#zookeeper作为SolrCloud集群的配置信息中心、所以还得先安装zookeeper集群
zookeeper集群安装：https://www.cnblogs.com/hsyw/p/13208716.html
```

### 二、集群安装（三台机器都改）

```shell
#进入到bin目录、修改solr.in.sh文件
[root@t1 ~]# cd /app/solr/bin
找到#ZK_HOST=""改下成如下
[root@t1 bin]# vim solr.in.sh
ZK_HOST="192.168.47.188:2181,192.168.47.189:2181,192.168.47.190:2181"
```

### 三、启动集群

```shell
[root@t1 bin]#  ./solr start -cloud -force（启动命令不一样了）
NOTE: Please install lsof as this script needs it to determine if Solr is listening on port 8983.

Started Solr server on port 8983 (pid=11870). Happy searching!

[root@t1 bin]# ss -ntl|grep 8983
LISTEN     0      50          :::8983                    :::*          
```

```
浏览器查看页面192.168.47.188:8983（189和190都试试，确保都没有问题）
```

<img src="C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20200801155451160.png" alt="image-20200801155451160" style="zoom:50%;" />



#### 四、测试，新建分片

##### 4.1、上传配置文件到zk统一管理配置文件

```shell
[root@t1 ~]# cd /app/solr/server/scripts/cloud-scripts
#上传配置文件（用solr自带的做测试即可）
#如果是自己上传的配置文件，三个节点都要上传
#多个集合，就在zk新建一个节点统一管理
[root@t1 cloud-scripts]# ./zkcli.sh -zkhost 192.168.47.188:2181,192.168.47.189:2181,192.168.47.190:2181 /test -cmd upconfig -confdir /app/solr/server/solr/configsets/_default/conf/ -confname myconf
-confdir： 这个指的是 本地上传的文件位置
-confname：上传后在zookeeper中的节点名称
###重启solr
[root@t2 bin]# ./solr restart -cloud -force

###新建分片 浏览器输入
http://192.168.47.188:8983/solr/admin/collections?action=CREATE&name=collection1&maxShardsPerNode=3&numShards=3&replicationFactor=3

####然后到页面查看、大功告成了
```

<img src="C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20200801165842554.png" alt="image-20200801165842554" style="zoom:50%;" />



##### 4.2、到zk中查看节点

```shell
[root@t2 ~]# cd /app/zktst/bin
#默认端口
[root@t2 bin]# ./zkCli.sh 
[zk: localhost:2181(CONNECTED) 2] ls /test
[configs]
[zk: localhost:2181(CONNECTED) 3] ls /test/configs
[myconf]
```
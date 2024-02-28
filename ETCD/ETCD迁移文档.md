## ETCD迁移文档

### 一、背景

​		有个节点etcd数据目录部署的时候磁盘选错，意外的选到了HDD，导致该节点读写很慢，读写接近1s，这会导致kube-apiserver时不时有个告警：**“Liveness probe failed: HTTP probe failed with statuscode: 500”**

然后，apiserver日志有记录ETCD的update响应时间，所以猜测这一系列问题的源头就是：**etcd03节点磁盘读写导致的**。  

```sh
github也有类似的问题记录： https://github.com/kubernetes/kubernetes/issues/95681
```



### 二、迁移步骤

#### 2.1、详细步骤

##### 添加SSD，然后挂到data1，然后停止etcd，containerd，把/data的数据copy到data1，然后取消挂载data、data1，最后再把SSD挂载到data上，这样我们就完成了数据的迁移，然后启动即可

```sh
# 查看节点信息
export ETCDCTL_API=3
etcdctl --endpoints="10.30.250.43:2379,10.30.250.42:2379,10.30.250.41:2379" --cacert=/etc/kubernetes/pki/etcd/etcd-ca.pem --cert=/etc/kubernetes/pki/etcd/etcd.pem --key=/etc/kubernetes/pki/etcd/etcd-key.pem  endpoint status --write-out=table
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|     ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 10.30.250.43:2379 | 9876aebcaaeaaf6c |   3.5.9 |   22 MB |     false |      false |        11 |   20111748 |           20111748 |        |
| 10.30.250.42:2379 | 9925cef18741f3a3 |   3.5.9 |   22 MB |     false |      false |        11 |   20111748 |           20111748 |        |
| 10.30.250.41:2379 | 4780dd1d47f3c388 |   3.5.9 |   22 MB |      true |      false |        11 |   20111748 |           20111748 |        |
+-------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+



# 挂盘迁移步骤
mkfs.xfs /dev/sdc -f 
lsblk -l
mkdir /data1
mount /dev/sdc /data1/

# 停止
systemctl stop etcd
systemctl stop containerd

# 数据迁移
cp -ar /data /data1/
umount /data
umount /data1
vi /etc/fstab
mount -a

# 启动
systemctl start containerd
# 启动etcd前修改配置文件 initial-cluster-state: 'existing'  原来是new
systemctl start etcd
```



#### 2.2、讲一讲遇到的故障，以及恢复的步骤

> 一般来说是不会遇到这个故障的，之前迁移过其他环境的ETCD节点很顺利

**故障关键字： panic: tocommit(11) is out of range [lastIndex(0)]. Was the raft log corrupted, truncated, or lost?**   

**出现的原因： 此问题是由于，etcd 进程 关闭估计异常，或者是数据copy有问题，导致数据不一致**

```sh
# 解决方案
# 1、把该节点的etcd数据目录mv走
mv etcd-data etcd-data-back

# 2、从集群中踢出故障节点  "9876aebcaaeaaf6c 是节点ID"
etcdctl --endpoints="10.30.250.43:2379,10.30.250.42:2379,10.30.250.41:2379" --cacert=/etc/kubernetes/pki/etcd/etcd-ca.pem --cert=/etc/kubernetes/pki/etcd/etcd.pem --key=/etc/kubernetes/pki/etcd/etcd-key.pem  member remove 9876aebcaaeaaf6c

# 3、需要指明节点的 etcd 的 name 和 peer-urls【这个端口是2380】
etcdctl --endpoints=https://10.30.250.41:2379,https://10.30.250.42:2379 --cacert=/etc/kubernetes/pki/etcd/etcd-ca.pem --cert=/etc/kubernetes/pki/etcd/etcd.pem --key=/etc/kubernetes/pki/etcd/etcd-key.pem  member add etcd1 --peer-urls=https://10.30.250.43:2380

# 4、修改etcd配置文件
--initial-cluster-state ：new --改成--> existing

# 5、重启etcd即可，然后查看集群就成功加入到节点中了
systemctl start etcd
```


























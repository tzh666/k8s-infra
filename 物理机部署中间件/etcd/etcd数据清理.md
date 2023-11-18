## ETCD 常用命令

- 查看集群信息
  - ENDPOINT： 节点IP、port
  - ID：节点ID标识
  - VERSION： 节点版本
  - DB SIZE：DB大小, –quota-backend-bytes 默认为 2G，2G 一般情况下是不够用的，
  - IS LEADER：是否为leader
  - IS LEARNER：是否为LEARNER
  - RAFT TERM：
  - RAFT INDEX：
  - RAFT APPLIED INDEX ：
  - ERRORS：

```sh
# 使用API3
export ETCDCTL_API=3

[root@k8s-master01 ~]# etcdctl --endpoints="192.168.1.110:2379,192.168.1.111:2379,192.168.1.112:2379" --cacert=/etc/kubernetes/pki/etcd/etcd-ca.pem --cert=/etc/kubernetes/pki/etcd/etcd.pem --key=/etc/kubernetes/pki/etcd/etcd-key.pem  endpoint status --write-out=table
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|      ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 192.168.1.110:2379 | f0cc47784bbee8d9 |  3.4.12 |  1.0 GB |      true |      false |      1176 |    1647196 |            1647196 |        |
| 192.168.1.111:2379 | 59e395afcfa1b0a7 |  3.4.12 |  1.0 GB |     false |      false |      1176 |    1647196 |            1647196 |        |
| 192.168.1.112:2379 | 4fbf3d2bf257033f |  3.4.12 |  1.0 GB |     false |      false |      1176 |    1647196 |            1647196 |        |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```



- 查看告警信息

```sh
[root@k8s-master01 ~]#  etcdctl --endpoints="192.168.1.110:2379,192.168.1.111:2379,192.168.1.112:2379" --cacert=/etc/kubernetes/pki/etcd/etcd-ca.pem --cert=/etc/kubernetes/pki/etcd/etcd.pem --key=/etc/kubernetes/pki/etcd/etcd-key.pem   alarm list
```

- 取消告警信息

```sh
[root@k8s-master01 ~]#  etcdctl --endpoints="192.168.1.110:2379,192.168.1.111:2379,192.168.1.112:2379" --cacert=/etc/kubernetes/pki/etcd/etcd-ca.pem --cert=/etc/kubernetes/pki/etcd/etcd.pem --key=/etc/kubernetes/pki/etcd/etcd-key.pem   alarm disarm
```



- 获取当前版本

```sh
# 单机
VS=$(etcdctl endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9].*')

# 集群
rev=$(ETCDCTL_API=3 etcdctl --endpoints="192.168.1.110:2379,192.168.1.111:2379,192.168.1.112:2379" --cacert=/etc/kubernetes/pki/etcd/etcd-ca.pem --cert=/etc/kubernetes/pki/etcd/etcd.pem --key=/etc/kubernetes/pki/etcd/etcd-key.pem endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9].*')

```



- 集群ETCD数据清理【集群etcd到每个主机上执行清理】

```sh
# 查看警告信息
$ etcdctl --endpoints=http://127.0.0.1:2379 alarm list
  memberID:8630161756594109333 alarm:NOSPACE
# 获取当前版本
$ rev=$(etcdctl --endpoints=http://127.0.0.1:2379 endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9].*')
# 压缩旧版本
$ etcdctl --endpoints=http://127.0.0.1:2379 compact $rev 
# 清理磁盘碎片
$ etcdctl --endpoints=http://127.0.0.1:2379 defrag
# 最后验证空间是否释放
$ etcdctl endpoint status #
# 最后清除警告
$ etcdctl --endpoints=http://127.0.0.1:2379 alarm disarm
```








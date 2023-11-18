### 备份

- 如果现场环境不同，要更改的位置
  - 集群地址
  - 证书位置
- 备份目录可自行调整（或者备份多个地方），例如
  - 本机/data0目录，（默认百夫长5.1、5.2都有这个目录，如果是其他版本可自行调整）
  - 4.x，可以备份在/admin目录新建个文件夹
  - nas存储上
  - 底层方舟节点

```sh
# 新建备份目录
[root@node-1 ~]# mkdir /data0/etcd/{data_back,kube_api_yaml_back,etcd_db_back} -p
[root@node-1 ~]# cd /data0/etcd

[root@node-1 etcd]# cat etcd_back.sh 
#!/usr/bin/env bash

# etcd数据备份脚本
# 证书位置
CACERT="/etc/ssl/etcd/ssl/ca.pem"
CERT="/etc/ssl/etcd/ssl/member-node-1.pem"
EKY="/etc/ssl/etcd/ssl/member-node-1-key.pem"
# 集群地址
ENDPOINTS="10.9.240.118:2379"

# db备份目录
ETCD_BACK="/data0/etcd/etcd_db_back"
# 备份日期后缀
DATA_STYLE=`date +%Y%m%d%H%M%S`

# 备份命令
ETCDCTL_API=3 etcdctl \
--cacert="${CACERT}" --cert="${CERT}" --key="${EKY}" \
--endpoints=${ENDPOINTS} \
snapshot save ${ETCD_BACK}/etcd-snapshot-${DATA_STYLE}.db

# 判断是否备份成功
if [ $? -eq 0 ]; then
  echo "etcd back success"
fi

# 备份保留30天
find ${ETCD_BACK}/  -name *.db -mtime +30 -exec rm -f {} \;
```

```sh
# 定时任务
crontab -e
# 凌晨1点执行
0 0 1 * * ? /data0/etcd/etcd_back.sh >> /tmp/etcd_back.log
```





### 恢复

- 如果现场环境不同，要更改的位置
  - 集群地址
  - 证书位置
  - etcd数据目录
  - etcd数据备份目录
  - kube-apiserver文件相关目录
- 恢复数据kube-apiserver启动需要几十秒，耐心等待后执行kubectl get no 正常即可

```sh
[root@node-1 etcd]# cat etcd_recovery.sh 
#!/bin/bash

# etcd恢复数据脚本
# 证书目录
CACERT="/etc/ssl/etcd/ssl/ca.pem"
CERT="/etc/ssl/etcd/ssl/member-node-1.pem"
EKY="/etc/ssl/etcd/ssl/member-node-1-key.pem"
ENDPOINTS="10.9.240.118:2379"

# etcd数据目录
DATA_DIR="/var/lib/etcd/"
# etcd数据备份目录
ETCD_DATA_BACK="/data0/etcd/data_back/"
# 备份时间戳
DATA_STYLE=`date +%Y%m%dH%M%S`

# kube-apiserver文件,原目录、备份目录
SRC_API="/etc/kubernetes/manifests/kube-apiserver.yaml"
DEST_API="/data0/etcd/kube_api_yaml_back/kube-apiserver.yaml"

# 1、停止所有Master上kube-apiserver服务
mv ${SRC_API} ${DEST_API}

API_PID=`ps -ef | grep kube-apiserver | grep -v grep  | wc -l`

# 2、停止集群中所有 ETCD 服务
if [ ${API_PID} -eq 0 ]; then
  systemctl stop etcd
  echo "etcd stop success"
fi

# 3、移除所有 ETCD 存储目录下数据
mv /var/lib/etcd ${ETCD_DATA_BACK}etcd_${DATA_STYLE}

# 4、恢复快照
ETCDCTL_API=3 etcdctl snapshot restore $1 \
--cacert="${CACERT}" --cert="${CERT}" --key="${EKY}" \
--data-dir=${DATA_DIR}   \
--endpoints=${ENDPOINTS}

# 5、启动etcd、启动kube-apiserver
# 判断是否恢复成功
echo $?
if [ $? -eq 0 ]; then
  echo "etcd recovery success"
  systemctl start etcd
fi

sleep 5
# 6、启动kube-apiserver
mv ${DEST_API} ${SRC_API}
```

```sh
# 使用例子
[root@node-1 etcd]# ./etcd_recovery.sh /data0/etcd/etcd_db_back/etcd-snapshot-20220808173213.db 
etcd stop success
2022-08-08 15:16:00.322932 I | mvcc: restore compact to 22870444
2022-08-08 15:16:00.340814 I | etcdserver/membership: added member 8e9e05c52164694d [http://localhost:2380] to cluster cdf818194e3a8c32
0
etcd recovery success
```


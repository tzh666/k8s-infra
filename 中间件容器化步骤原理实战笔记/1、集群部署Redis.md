### 一、k8s上部署Redis集群

- 本文采用nfs作为k8s动态存储
- nfs环境可参考官网demo

#### 1.1、部署sc

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: infra-nfs-redis
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

#### 1.2、创建redis配置文件，redis 配置文件使用 configmap 方式进行挂载

- redis-cluster-cm.yml
- fix-ip.sh 脚本的作用用于当 redis 集群某 pod 重建后 Pod IP 发生变化，在 /data/nodes.conf 中将新的 Pod IP 替换原 Pod IP。不然集群会出问题

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-cluster
  namespace: infra
data:
  fix-ip.sh: |
    #!/bin/sh
    CLUSTER_CONFIG="/data/nodes.conf"
    if [ -f ${CLUSTER_CONFIG} ]; then
      if [ -z "${POD_IP}" ]; then
        echo "Unable to determine Pod IP address!"
        exit 1
      fi
      echo "Updating my IP to ${POD_IP} in ${CLUSTER_CONFIG}"
      sed -i.bak -e '/myself/ s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/'${POD_IP}'/' ${CLUSTER_CONFIG}
    fi
    exec "$@"
  redis.conf: |
    bind 0.0.0.0
    protected-mode yes
    port 6379
    tcp-backlog 2048
    timeout 0
    tcp-keepalive 300
    daemonize no
    supervised no
    pidfile /var/run/redis.pid
    loglevel notice
    logfile /data/redis.log
    databases 16
    always-show-logo yes
    stop-writes-on-bgsave-error yes
    rdbcompression yes
    rdbchecksum yes
    dbfilename dump.rdb
    dir /data
    masterauth liuchang@2022
    replica-serve-stale-data yes
    replica-read-only no
    repl-diskless-sync no
    repl-diskless-sync-delay 5
    repl-disable-tcp-nodelay no
    replica-priority 100
    requirepass 123456
    maxclients 32768
    #maxmemory 6g
    maxmemory-policy allkeys-lru
    lazyfree-lazy-eviction no
    lazyfree-lazy-expire no
    lazyfree-lazy-server-del no
    replica-lazy-flush no
    appendonly yes
    appendfilename "appendonly.aof"
    appendfsync everysec
    no-appendfsync-on-rewrite no
    auto-aof-rewrite-percentage 100
    auto-aof-rewrite-min-size 64mb
    aof-load-truncated yes
    aof-use-rdb-preamble yes
    lua-time-limit 5000
    cluster-enabled yes
    cluster-config-file /data/nodes.conf
    cluster-node-timeout 15000
    slowlog-log-slower-than 10000
    slowlog-max-len 128
    latency-monitor-threshold 0
    notify-keyspace-events ""
    hash-max-ziplist-entries 512
    hash-max-ziplist-value 64
    list-max-ziplist-size -2
    list-compress-depth 0
    set-max-intset-entries 512
    zset-max-ziplist-entries 128
    zset-max-ziplist-value 64
    hll-sparse-max-bytes 3000
    stream-node-max-bytes 4096
    stream-node-max-entries 100
    activerehashing yes
    client-output-buffer-limit normal 0 0 0
    client-output-buffer-limit replica 256mb 64mb 60
    client-output-buffer-limit pubsub 32mb 8mb 60
    hz 10
    dynamic-hz yes
    aof-rewrite-incremental-fsync yes
    rdb-save-incremental-fsync yes
```

#### 1.3、redis-cluster-sts.yml

- 也是服用zk的标签，调度到node01、node02、mater03上

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  namespace: infra
  name: redis-cluster
spec:
  serviceName: redis-cluster
  replicas: 6
  selector:
    matchLabels:
      app: redis-cluster
  template:
    metadata:
      labels:
        app: redis-cluster
    spec:
      affinity:
        nodeAffinity:                                      # node亲和性
          requiredDuringSchedulingIgnoredDuringExecution:  # 硬策略,调度在app.kubernetes.io/component=zookeeper的节点中
            nodeSelectorTerms:
            - matchExpressions:
              - key: app.kubernetes.io/component
                operator: In
                values:
                  - zookeeper
        podAntiAffinity:                                    # Pod反亲和性
          preferredDuringSchedulingIgnoredDuringExecution:  # 软策略,使Pod分布在不同的节点上
          - weight: 1                                       # 权重,有多个策略通过权重控制调度
            podAffinityTerm:
              topologyKey: app.kubernetes.io/name           # 通过app.kubernetes.io/name作为域调度  
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values:
                  - zookeeper
      containers:
      - name: redis
        image: redis:5.0.13
        ports:
        - containerPort: 6379
          name: client
        - containerPort: 16379
          name: gossip
        command: ["/etc/redis/fix-ip.sh", "redis-server", "/etc/redis/redis.conf"]
        env:
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        volumeMounts:
        - name: conf
          mountPath: /etc/redis/
          readOnly: false
        - name: redis-data
          mountPath: /data
          readOnly: false
      volumes:
      - name: conf
        configMap:
          name: redis-cluster
          defaultMode: 0755
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      storageClassName: infra-nfs-redis
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: 5Gi
```

#### 1.4、创建svc

```yaml
apiVersion: v1
kind: Service
metadata:
  namespace: infra
  name: redis-cluster
spec:
  clusterIP: None
  ports:
  - port: 6379
    targetPort: 6379
    name: client
  - port: 16379
    targetPort: 16379
    name: gossip
  selector:
    app: redis-cluster
```

#### 1.5、初始化集群

- 注意: 必须使用 ip 进行初始化 redis 集群，使用域名会报如下错误

  - ```sh
    Node redis-cluster-1.redis-cluster.redis-cluster.svc.cluster.local:6379 replied with error:
    ERR Invalid node address specified: redis-cluster-0.redis-cluster.redis-cluster.svc.cluster.local:6379
    ```

- 获取 Redis 集群 6 个节点 Pod 的 ip 地址

- 应用连接 redis 集群时使用 pod 的域名 

  - svc名字.ns名字.svc.cluster.local
  - nslookup redis-cluster.infra.svc.cluster.local 

```sh
# 方式一:
[root@k8s-master01 集群]# kubectl get po -n infra  -owide
NAME                                      READY   STATUS    RESTARTS   AGE     IP              NODE           NOMINATED NODE   READINESS GATES
nfs-client-provisioner-6b57f44cb6-vrhwx   1/1     Running   1          19h     10.244.195.63   k8s-master03   <none>           <none>
redis-cluster-0                           1/1     Running   0          8m26s   10.244.58.221   k8s-node02     <none>           <none>
redis-cluster-1                           1/1     Running   0          7m59s   10.244.195.13   k8s-master03   <none>           <none>
redis-cluster-2                           1/1     Running   0          7m49s   10.244.85.214   k8s-node01     <none>           <none>
redis-cluster-3                           1/1     Running   0          7m23s   10.244.58.222   k8s-node02     <none>           <none>
redis-cluster-4                           1/1     Running   0          7m19s   10.244.195.11   k8s-master03   <none>           <none>
redis-cluster-5                           1/1     Running   0          7m15s   10.244.85.212   k8s-node01     <none>           <none>

# 方式二:
kubectl run -i --tty --image busybox:1.28.4 dns-test --restart=Never --rm /bin/sh
# 应用连接 redis 集群时使用下面 pod 的域名
nslookup redis-cluster.redis-cluster.svc.cluster.local 

svc名字.ns名字.svc.cluster.local
/ # nslookup redis-cluster.infra.svc.cluster.local 
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local
Name:      redis-cluster.infra.svc.cluster.local
Address 1: 10.244.85.212 redis-cluster-5.redis-cluster.infra.svc.cluster.local
Address 2: 10.244.85.214 redis-cluster-2.redis-cluster.infra.svc.cluster.local
Address 3: 10.244.195.11 redis-cluster-4.redis-cluster.infra.svc.cluster.local
Address 4: 10.244.58.221 redis-cluster-0.redis-cluster.infra.svc.cluster.local
Address 5: 10.244.58.222 redis-cluster-3.redis-cluster.infra.svc.cluster.local
Address 6: 10.244.195.13 redis-cluster-1.redis-cluster.infra.svc.cluster.local
```

- 创建集群 
  - 替换成6个pod IP

```sh
[root@k8s-master01 集群]# kubectl exec -it pod/redis-cluster-0 -n infra -- bash
root@redis-cluster-0:/data# redis-cli -a 密码 --cluster create \
> 10.244.85.212:6379 \
> 10.244.85.214:6379 \
> 10.244.195.11:6379 \
> 10.244.58.221:6379 \
> 10.244.58.222:6379 \
> 10.244.195.13:6379 \
> --cluster-replicas 1
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica 10.244.58.222:6379 to 10.244.85.212:6379
Adding replica 10.244.195.13:6379 to 10.244.85.214:6379
Adding replica 10.244.58.221:6379 to 10.244.195.11:6379
M: b18a9738c0f9b080c99563cc629e9d739408bc2e 10.244.85.212:6379
   slots:[0-5460] (5461 slots) master
M: dcfe4e84eb6d56c369fda3cea013e247f87f3a80 10.244.85.214:6379
   slots:[5461-10922] (5462 slots) master
M: 623e7b8734784b15d58f560e9224da8653f28789 10.244.195.11:6379
   slots:[10923-16383] (5461 slots) master
S: d5e437118b5dfadcf8884e8f71260afb580e8720 10.244.58.221:6379
   replicates 623e7b8734784b15d58f560e9224da8653f28789
S: 5392f77757ddc9b6459fc2c2ecc0f1e9adaebfb7 10.244.58.222:6379
   replicates b18a9738c0f9b080c99563cc629e9d739408bc2e
S: 4ec83ffa582159f54630be7e95033badd3f04579 10.244.195.13:6379
   replicates dcfe4e84eb6d56c369fda3cea013e247f87f3a80
Can I set the above configuration? (type 'yes' to accept): yes       # 此处输入yes
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join
.
>>> Performing Cluster Check (using node 10.244.85.212:6379)
M: b18a9738c0f9b080c99563cc629e9d739408bc2e 10.244.85.212:6379
   slots:[0-5460] (5461 slots) master
   1 additional replica(s)
M: dcfe4e84eb6d56c369fda3cea013e247f87f3a80 10.244.85.214:6379
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
S: 4ec83ffa582159f54630be7e95033badd3f04579 10.244.195.13:6379
   slots: (0 slots) slave
   replicates dcfe4e84eb6d56c369fda3cea013e247f87f3a80
M: 623e7b8734784b15d58f560e9224da8653f28789 10.244.195.11:6379
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
S: d5e437118b5dfadcf8884e8f71260afb580e8720 10.244.58.221:6379
   slots: (0 slots) slave
   replicates 623e7b8734784b15d58f560e9224da8653f28789
S: 5392f77757ddc9b6459fc2c2ecc0f1e9adaebfb7 10.244.58.222:6379
   slots: (0 slots) slave
   replicates b18a9738c0f9b080c99563cc629e9d739408bc2e
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

#### 1.6、验证 Redis Cluster 集群

- 看到以下信息说明集群部署成功

```sh
[root@k8s-master01 集群]# kubectl exec -it pod/redis-cluster-0 -n infra -- bash
root@redis-cluster-0:/data# redis-cli -h redis-cluster-1.redis-cluster.infra.svc.cluster.local -c -a '密码'

redis-cluster-1.redis-cluster.infra.svc.cluster.local:6379> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:2
cluster_stats_messages_ping_sent:240
cluster_stats_messages_pong_sent:231
cluster_stats_messages_meet_sent:1
cluster_stats_messages_sent:472
cluster_stats_messages_ping_received:231
cluster_stats_messages_pong_received:241
cluster_stats_messages_received:472

redis-cluster-1.redis-cluster.infra.svc.cluster.local:6379> cluster nodes
4ec83ffa582159f54630be7e95033badd3f04579 10.244.195.13:6379@16379 myself,slave dcfe4e84eb6d56c369fda3cea013e247f87f3a80 0 1664877624000 6 connected
623e7b8734784b15d58f560e9224da8653f28789 10.244.195.11:6379@16379 master - 0 1664877625000 3 connected 10923-16383
b18a9738c0f9b080c99563cc629e9d739408bc2e 10.244.85.212:6379@16379 master - 0 1664877626150 1 connected 0-5460
dcfe4e84eb6d56c369fda3cea013e247f87f3a80 10.244.85.214:6379@16379 master - 0 1664877624144 2 connected 5461-10922
5392f77757ddc9b6459fc2c2ecc0f1e9adaebfb7 10.244.58.222:6379@16379 slave b18a9738c0f9b080c99563cc629e9d739408bc2e 0 1664877626000 5 connected
d5e437118b5dfadcf8884e8f71260afb580e8720 10.244.58.221:6379@16379 slave 623e7b8734784b15d58f560e9224da8653f28789 0 1664877627157 4 connected
```

#### 1.7、故障测试 【***】

- 删除任意一个 pod(删除名称为 redis-cluster-3 的 pod)

```sh
kubectl describe po -n infra redis-cluster-3
```

-  pod 被重新拉起(还占用原来的pvc 和 pv)

```sh
[root@k8s-master01 集群]# kubectl get  po -n infra redis-cluster-3 -owide
NAME              READY   STATUS    RESTARTS   AGE   IP              NODE         NOMINATED NODE   READINESS GATES
redis-cluster-3   1/1     Running   0          7s    10.244.58.224   k8s-node02   <none>           <none>
```

```shell
# 可以看到名称为 redis-cluster-3 的 pod 启动时长 AGE 为 7s，IP 由原来的 10.244.58.222 变为 10.244.58.224，
/data/nodes.conf 文件中 "myself" 对应的 ip 被 fix-ip.sh 脚本修改，redis 集群修复时会将该 ip 同步到其它 pod
节的 /data/nodes.conf 文件中，从而保证整个 redis 集群的可用性。

# kubectl exec -it pod/redis-cluster-0 -n infra -- bash
root@redis-cluster-0:/data# cat /data/nodes.conf   | grep 10.244.58.224
5392f77757ddc9b6459fc2c2ecc0f1e9adaebfb7 10.244.58.224:6379@16379 slave b18a9738c0f9b080c99563cc629e9d739408bc2e 1664877856604 1664877855096 5 disconnected
```

- 再次验证集群

```sh
root@redis-cluster-0:/data# redis-cli -h redis-cluster-1.redis-cluster.infra.svc.cluster.local -c -a 'mima'
root@redis-cluster-0:/data# [root@k8s-master01 集群]# kubectl exec -it pod/redis-cluster-0 -n infra -- bash
redis-cluster-1.redis-cluster.infra.svc.cluster.local:6379> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:2
cluster_stats_messages_ping_sent:803
cluster_stats_messages_pong_sent:741
cluster_stats_messages_meet_sent:1
cluster_stats_messages_sent:1545
cluster_stats_messages_ping_received:741
cluster_stats_messages_pong_received:802
cluster_stats_messages_received:1543
```

#### 1.8、补充

- 如果整个 redis 集群的 pod 全部都挂掉了，pod自动拉起后，集群不可用，需要重建集群

##### 重建集群的方法一:   重新开始【肯定不建议这样啊】

-  删除 redis 集群所有的资源，然后重新创建 redis 集群	

```sh
 kubectl delete -f redis-cluster-sts.yml
```

- 删除 redis 集群中所有的 pvc(pv)

```sh
kubectl delete pvc/data-redis-cluster-0 -n infra 
kubectl delete pvc/data-redis-cluster-1 -n infra
kubectl delete pvc/data-redis-cluster-2 -n infra
kubectl delete pvc/data-redis-cluster-3 -n infra
kubectl delete pvc/data-redis-cluster-4 -n infra
kubectl delete pvc/data-redis-cluster-5 -n infra
```

- 删除 redis 集群中 pod 对应的 nfs 持久化存储目录

```sh
rm -rf 对应目录
```

- 重新创建 redis 集群
  - 然后重新创建集群

```sh
kubectl apply -f redis-cluster-sts.yml
```

##### 重建集群的方法二:    在原有 redis 集群的基础上进行修复

- 删除 redis 集群中所有的 pod

```sh
 kubectl delete -f redis-cluster-sts.yml
```

- 找到 redis 集群中 pod 对应的 nfs 持久化存储目录后删除 nodes.conf

```sh
[root@k8s-node02 infra_data]# cd /admin/infra_data/
# 删了这些,conf.bak 是重启过pod的备份
[root@k8s-node02 infra_data]# ls infra-redis-data-redis-cluster-*/nodes.conf*
infra-redis-data-redis-cluster-0-pvc-353cde34-443d-444b-8f63-a7b466f6e0b8/nodes.conf
infra-redis-data-redis-cluster-1-pvc-20b64aaf-2234-41cb-92f0-357df89ab05a/nodes.conf
infra-redis-data-redis-cluster-2-pvc-8a0607fb-e20c-44f3-858b-0efd5d8574c6/nodes.conf
infra-redis-data-redis-cluster-3-pvc-f12779be-f0dc-4058-aa61-21941de461fa/nodes.conf
infra-redis-data-redis-cluster-3-pvc-f12779be-f0dc-4058-aa61-21941de461fa/nodes.conf.bak
infra-redis-data-redis-cluster-4-pvc-883db134-fc4e-46e7-8f6f-555aefa085c0/nodes.conf
infra-redis-data-redis-cluster-5-pvc-a8335203-725c-4101-b7f9-c83b86e4cbda/nodes.conf
```

- 重新创建 redis 集群

```sh
 kubectl apply -f redis-cluster-sts.yml
```


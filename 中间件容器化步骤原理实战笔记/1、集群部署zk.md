### 一、集群部署zookeeper

#### 1.1、指定节点部署

- 给以下节点打上标签：k8s-node01、k8s-node02、k8s-master03【也就是我们的三个节点的集群部署在这三个节点上】

```sh
[root@k8s-master01 ~]# kubectl get nodes 
NAME           STATUS   ROLES    AGE    VERSION
k8s-master01   Ready    <none>   300d   v1.19.5
k8s-master02   Ready    <none>   300d   v1.19.5
k8s-master03   Ready    <none>   300d   v1.19.5
k8s-node01     Ready    <none>   300d   v1.19.5
k8s-node02     Ready    <none>   300d   v1.19.5

# 打标签
# 注意这里相当于也打了两个域【app.kubernetes.io/component、app.kubernetes.io/name】,调度的时候会用上
kubectl get nodes --show-labels
kubectl label nodes k8s-master03 app.kubernetes.io/component=zookeeper
kubectl label nodes k8s-node02 app.kubernetes.io/component=zookeeper
kubectl label nodes k8s-node01 app.kubernetes.io/component=zookeeper
kubectl label nodes k8s-master03 app.kubernetes.io/name=zookeeper
kubectl label nodes k8s-node01 app.kubernetes.io/name=zookeeper
kubectl label nodes k8s-node02 app.kubernetes.io/name=zookeeper
```

#### 1.2、创建svc

```yaml
[root@k8s-master01 集群]# cat zk-svc-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: zk-headless
  namespace: infra
  labels:
    app.kubernetes.io/name: zookeeper
    app.kubernetes.io/component: zookeeper
spec:
  type: ClusterIP
  clusterIP: None
  publishNotReadyAddresses: true
  ports:
    - name: tcp-client
      port: 2181
      targetPort: client
    - name: tcp-follower
      port: 2888
      targetPort: follower
    - name: tcp-election
      port: 3888
      targetPort: election
  selector:
    app.kubernetes.io/name: zookeeper
---
[root@k8s-master01 集群]# cat zk-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: zk-test
  namespace: infra
  labels:
    app.kubernetes.io/name: zookeeper
    app.kubernetes.io/component: zookeeper
spec:
  type: ClusterIP
  sessionAffinity: None
  ports:
    - name: tcp-client
      port: 2181
      targetPort: client
      nodePort: null
    - name: tcp-follower
      port: 2888
      targetPort: follower
    - name: tcp-election
      port: 3888
      targetPort: election
  selector:
    app.kubernetes.io/name: zookeeper
    app.kubernetes.io/component: zookeeper
```

#### 1.3、创建zk启动脚本的，通过cm形式挂载进去

```yaml
[root@k8s-master01 集群]# cat zk-cm.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: infra-zk-scripts
  namespace: infra
  labels:
    app.kubernetes.io/name: zookeeper
    app.kubernetes.io/component: zookeeper
data:
  init-certs.sh: |-
    #!/bin/bash
  setup.sh: |-
    #!/bin/bash
    if [[ -f "/bitnami/zookeeper/data/myid" ]]; then
        export ZOO_SERVER_ID="$(cat /bitnami/zookeeper/data/myid)"
    else
        HOSTNAME="$(hostname -s)"
        if [[ $HOSTNAME =~ (.*)-([0-9]+)$ ]]; then
            ORD=${BASH_REMATCH[2]}
            export ZOO_SERVER_ID="$((ORD + 1 ))"
        else
            echo "Failed to get index from hostname $HOST"
            exit 1
        fi
    fi
    exec /entrypoint.sh /run.sh
```

#### 1.4、创建StatefulSet

- 动态存储我使用的nfs, 生产不建议用这种，建议使用分布式动态存储例如：ceph、minio、GFS等

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zk-test
  namespace: infra
  labels:
    app.kubernetes.io/name: zookeeper
    app.kubernetes.io/component: zookeeper
    role: zookeeper
spec:
  replicas: 3
  podManagementPolicy: Parallel
  selector:
    matchLabels:
      app.kubernetes.io/name: zookeeper
      app.kubernetes.io/component: zookeeper
  serviceName: zk-headless
  updateStrategy:
    rollingUpdate: {}
    type: RollingUpdate
  template:
    metadata:
      annotations:
      labels:
        app.kubernetes.io/name: zookeeper
        app.kubernetes.io/component: zookeeper
    spec:
      serviceAccountName: default
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
          - weight: 49                                      # 权重,有多个策略通过权重控制调度
            podAffinityTerm:
              topologyKey: app.kubernetes.io/name           # 通过app.kubernetes.io/name作为域调度  
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/component
                  operator: In
                  values:
                  - zookeeper
      securityContext:
        fsGroup: 1001
      initContainers:
      containers:
        - name: zookeeper
          image: bitnami/zookeeper:3.8.0-debian-10-r0
          imagePullPolicy: "IfNotPresent"
          securityContext:
            runAsNonRoot: true
            runAsUser: 1001
          command:
            - /scripts/setup.sh
          resources:                                       # QoS 最高等级
            limits:
              cpu: 500m
              memory: 500Mi
            requests:
              cpu: 500m
              memory: 500Mi
          env:
            - name: BITNAMI_DEBUG
              value: "false"
            - name: ZOO_DATA_LOG_DIR
              value: ""
            - name: ZOO_PORT_NUMBER
              value: "2181"
            - name: ZOO_TICK_TIME
              value: "2000"
            - name: ZOO_INIT_LIMIT
              value: "10"
            - name: ZOO_SYNC_LIMIT
              value: "5"
            - name: ZOO_PRE_ALLOC_SIZE
              value: "65536"
            - name: ZOO_SNAPCOUNT
              value: "100000"
            - name: ZOO_MAX_CLIENT_CNXNS
              value: "60"
            - name: ZOO_4LW_COMMANDS_WHITELIST
              value: "srvr, mntr, ruok"
            - name: ZOO_LISTEN_ALLIPS_ENABLED
              value: "no"
            - name: ZOO_AUTOPURGE_INTERVAL
              value: "0"
            - name: ZOO_AUTOPURGE_RETAIN_COUNT
              value: "3"
            - name: ZOO_MAX_SESSION_TIMEOUT
              value: "40000"
            - name: ZOO_SERVERS
              value: zk-test-0.zk-headless.infra.svc.cluster.local:2888:3888::1 zk-test-1.zk-headless.infra.svc.cluster.local:2888:3888::2 zk-test-2.zk-headless.infra.svc.cluster.local:2888:3888::3
            - name: ZOO_ENABLE_AUTH
              value: "no"
            - name: ZOO_HEAP_SIZE
              value: "1024"
            - name: ZOO_LOG_LEVEL
              value: "ERROR"
            - name: ALLOW_ANONYMOUS_LOGIN
              value: "yes"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.name
          ports:
            - name: client
              containerPort: 2181
            - name: follower
              containerPort: 2888
            - name: election
              containerPort: 3888
          livenessProbe:
            failureThreshold: 6
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            exec:
              command: ['/bin/bash', '-c', 'echo "ruok" | timeout 2 nc -w 2 localhost 2181 | grep imok']
          readinessProbe:
            failureThreshold: 6
            initialDelaySeconds: 5
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            exec:
              command: ['/bin/bash', '-c', 'echo "ruok" | timeout 2 nc -w 2 localhost 2181 | grep imok']
          volumeMounts:
            - name: scripts
              mountPath: /scripts/setup.sh
              subPath: setup.sh
            - name: zookeeper-data
              mountPath: /bitnami/zookeeper
      volumes:
        - name: scripts
          configMap:
            name: infra-zk-scripts
            defaultMode: 0755
  volumeClaimTemplates:
  - metadata:
      name: zookeeper-data
    spec:
      storageClassName: infra-nfs-storage
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 2Gi
```

#### 1.5、查看部署结果

- 看到分布在3个节点

```sh
[root@k8s-master01 集群]# kubectl get po -n infra  -l app.kubernetes.io/component=zookeeper -owide 
NAME        READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
zk-test-0   1/1     Running   0          10m   10.244.195.58   k8s-master03   <none>           <none>
zk-test-1   1/1     Running   0          10m   10.244.85.200   k8s-node01     <none>           <none>
zk-test-2   1/1     Running   0          10m   10.244.58.196   k8s-node02     <none>           <none>
```

#### 1.6、查看zookeeper配置

```sh
[root@k8s-master01 集群]# kubectl exec -it zk-test-0 -n infra -- cat /opt/bitnami/zookeeper/conf/zoo.cfg 
# The number of milliseconds of each tick
tickTime=2000
# The number of ticks that the initial 
# synchronization phase can take
initLimit=10
# The number of ticks that can pass between 
# sending a request and getting an acknowledgement
syncLimit=5
# the directory where the snapshot is stored.
# do not use /tmp for storage, /tmp here is just 
# example sakes.
dataDir=/bitnami/zookeeper/data
# the port at which the clients will connect
clientPort=2181
# the maximum number of client connections.
# increase this if you need to handle more clients
maxClientCnxns=60
#
# Be sure to read the maintenance section of the 
# administrator guide before turning on autopurge.
#
# https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_maintenance
#
# The number of snapshots to retain in dataDir
autopurge.snapRetainCount=3
# Purge task interval in hours
# Set to "0" to disable auto purge feature
autopurge.purgeInterval=0

## Metrics Providers
#
# https://prometheus.io Metrics Exporter
#metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider
#metricsProvider.httpHost=0.0.0.0
#metricsProvider.httpPort=7000
#metricsProvider.exportJvmInfo=true
preAllocSize=65536
snapCount=100000
maxCnxns=0
reconfigEnabled=false
quorumListenOnAllIPs=false
4lw.commands.whitelist=srvr, mntr, ruok
maxSessionTimeout=40000
admin.serverPort=8080
admin.enableServer=true
server.1=zk-test-0.zk-headless.infra.svc.cluster.local:2888:3888;2181
server.2=zk-test-1.zk-headless.infra.svc.cluster.local:2888:3888;2181
server.3=zk-test-2.zk-headless.infra.svc.cluster.local:2888:3888;2181
```

#### 1.7、查看zk集群状态

- 看到说明是正常的,到此集群部署成功

```sh
[root@k8s-master01 集群]# kubectl exec -it zk-test-0 -n infra -- /opt/bitnami/zookeeper/bin/zkServer.sh status
/opt/bitnami/java/bin/java
ZooKeeper JMX enabled by default
Using config: /opt/bitnami/zookeeper/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost. Client SSL: false.
Mode: follower

[root@k8s-master01 集群]# kubectl exec -it zk-test-1 -n infra -- /opt/bitnami/zookeeper/bin/zkServer.sh status
/opt/bitnami/java/bin/java
ZooKeeper JMX enabled by default
Using config: /opt/bitnami/zookeeper/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost. Client SSL: false.
Mode: leader

[root@k8s-master01 集群]# kubectl exec -it zk-test-2 -n infra -- /opt/bitnami/zookeeper/bin/zkServer.sh status
/opt/bitnami/java/bin/java
ZooKeeper JMX enabled by default
Using config: /opt/bitnami/zookeeper/bin/../conf/zoo.cfg
Client port found: 2181. Client address: localhost. Client SSL: false.
Mode: follower
```

#### 1.8、zk-bdp.yaml

```yaml
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: zk-infra-pdb
  namespace: infra
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: zookeeper
  minAvailable: 2     # 滚动更新的时候至少保留2个pod,防止宕机
```


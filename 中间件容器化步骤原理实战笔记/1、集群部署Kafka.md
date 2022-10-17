### 一、集群部署Kafka

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

# 打标签 【复用zookeeper的标签即可】
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
#部署 Service Headless，用于Kafka间相互通信
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
  namespace: infra
  labels:
    app: kafka
spec:
  type: ClusterIP
  clusterIP: None  # 创建无头服务，如果需要对外暴露端口可自行创建service
  ports:
  - name: kafka
    port: 9092
    targetPort: kafka
  selector:
    app: kafka
---
#部署 Service，用于外部访问 Kafka
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: infra
  labels:
    app: kafka
spec:
  type: ClusterIP
  ports:
  - name: kafka
    port: 9092
    targetPort: kafka
  selector:
    app: kafka
```

#### 1.3、kafka-pdb.yaml

- 创建pdb，防止滚动更新的时候全部更新

```yaml
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: kafka-pdb
  namespace: infra
spec:
  selector:
    matchLabels:
      app: kafka
  minAvailable: 2
```

#### 1.4、创建sc

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: infra-nfs-kafka
provisioner: fuseim.pri/ifs
parameters:
  archiveOnDelete: "false"   # 设置为"false"时删除PVC不会保留数据,"true"则保留数据
```

#### 1.5、创建Kafka

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka-test
  namespace: infra
  labels:
    app: kafka
spec:
  selector:
    matchLabels:
      app: kafka
  serviceName: kafka-headless
  podManagementPolicy: "Parallel"
  replicas: 3
  updateStrategy:
    type: "RollingUpdate"
  template:
    metadata:
      name: "kafka"
      labels:
        app: kafka
    spec:      
      securityContext:
        fsGroup: 1001
        runAsUser: 1001
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
      - name: kafka
        image: "docker.io/bitnami/kafka:2.3.0-debian-9-r4"
        imagePullPolicy: "IfNotPresent"
        env:
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: KAFKA_CFG_ZOOKEEPER_CONNECT
          value: "zk-headless"                      # Zookeeper Service 名称
        - name: KAFKA_PORT_NUMBER 
          value: "9092"
        - name: KAFKA_CFG_LISTENERS
          value: "PLAINTEXT://:$(KAFKA_PORT_NUMBER)"
        - name: KAFKA_CFG_ADVERTISED_LISTENERS
          value: 'PLAINTEXT://$(MY_POD_NAME).kafka-headless:$(KAFKA_PORT_NUMBER)'
        - name: ALLOW_PLAINTEXT_LISTENER
          value: "yes"
        - name: KAFKA_HEAP_OPTS
          value: "-Xmx512m -Xms512m"
        - name: KAFKA_CFG_LOGS_DIRS
          value: /opt/bitnami/kafka/data
        - name: JMX_PORT
          value: "9988"
        ports:
        - name: kafka
          containerPort: 9092
        livenessProbe:
          tcpSocket:
            port: kafka
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 2
        readinessProbe:
          tcpSocket:
            port: kafka
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 6
        volumeMounts:
        - name: data
          mountPath: /bitnami/kafka
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        storageClassName: infra-nfs-kafka     # 指定为上面创建的 storageclass
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: 5Gi
```

#### 1.6、查看Kafka部署是否调度在指定节点

```sh
[root@k8s-master01 ~]# kubectl get po -n infra  -l app=kafka -owide
NAME           READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
kafka-test-0   1/1     Running   0          58m   10.244.195.10   k8s-master03   <none>           <none>
kafka-test-1   1/1     Running   0          57m   10.244.58.218   k8s-node02     <none>           <none>
kafka-test-2   1/1     Running   0          58m   10.244.85.210   k8s-node01     <none>           <none>
```

#### 1.7、Kafka功能验证

- 进入 kafka-0 ，创建topic test，进入生产者窗口
- kafka消息的生产和消费正常，kafka集群正常。k8s部署kafka集群完成。

```sh
# 进入pod
[root@k8s-master01 infra]# kubectl exec -it -n infra kafka-test-0 -- bash
# 进入脚本目录
I have no name!@kafka-test-0:~ $ cd /opt/bitnami/kafka/bin/

# 创建topic
I have no name!@kafka-test-0:/opt/bitnami/kafka/bin$ kafka-topics.sh --create --topic test --zookeeper zk-test-0.zk-headless.infra.svc.cluster.local:2181,zk-test-1.zk-headless.infra.svc.cluster.local:2181,zk-test-2.zk-headless.infra.svc.cluster.local:2181 --partitions 3 --replication-factor 2
Created topic test.

# 查看topic列表
I have no name!@kafka-test-0:/opt/bitnami/kafka/bin$ kafka-topics.sh --list --zookeeper zk-test-0.zk-headless.infra.svc.cluster.local:2181,zk-test-1.zk-headless.infra.svc.cluster.local:2181,zk-test-2.zk-headless.infra.svc.cluster.local:2181
aaa
test

# 进入topic为aaa的生产者消息中心
I have no name!@kafka-test-0:/opt/bitnami/kafka/bin$ kafka-console-producer.sh --topic test --broker-list localhost:9092
>aaa   
>bbbb
>
```

- 进入 kafka-1 ，进入消费者窗口
- kafka消息的生产和消费正常，kafka集群正常。k8s部署kafka集群完成。

```sh
# 进入pod
[root@k8s-master01 infra]# kubectl exec -it -n infra kafka-test-1 -- bash

# 进入脚本目录
I have no name!@kafka-test-0:~ $ cd /opt/bitnami/kafka/bin/

# 能消费到数据,说明Kafka状态ok
I have no name!@kafka-test-1:/opt/bitnami/kafka/bin$ kafka-console-consumer.sh --topic test --bootstrap-server localhost:9092
aaa
bbbb
```


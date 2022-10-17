### 一、集群部署Elasticsearch

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
# 注意这里相当于也打了两个域【app.kubernetes.io/component】,调度的时候会用上
kubectl get nodes --show-labels
kubectl label nodes k8s-node01    esname=elasticsearch
kubectl label nodes k8s-node02    esname=elasticsearch
kubectl label nodes k8s-master03  esname=elasticsearch
```

#### 1.2、创建svc

- 生产应该创建个clusterIP: None类型的headless svc
- 再暴露个9300端口

```yaml
[root@k8s-master01 集群]# cat es-svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: es7
  namespace: infra
spec:
  selector:
    app: es7
  type: NodePort
  ports:
  - port: 9200
    nodePort: 30002
    targetPort: 9200
```

#### 1.3、创建sc

```yaml
[root@k8s-master01 集群]# cat es-sc.yaml 
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: infra-es-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer               # 延迟绑定
```

#### 1.4、创建pv

- 此处采用loacl-pv的方式
- 扩容的时候应该再指定一个节点，再创建一个pv然后再新增副本即可

```yaml
[root@k8s-master01 集群]# cat es-pv.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-storage-pv-1
  namespace: infra
  labels:
    name: local-storage-pv-1
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: infra-es-sc
  local:
    path: /admin/es
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-master03
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-storage-pv-2
  namespace: infra
  labels:
    name: local-storage-pv-2
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: infra-es-sc
  local:
    path: /admin/es
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-node01
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-storage-pv-3
  namespace: infra
  labels:
    name: local-storage-pv-3
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: infra-es-sc
  local:
    path: /admin/es
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-node02
```

#### 1.5、部署es集群

```yaml
[root@k8s-master01 集群]# cat es-sts.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-test
  namespace: infra
spec:
  serviceName: es7
  replicas: 3
  selector:
    matchLabels:
      app: es7
  template:
    metadata:
      labels:
        app: es7
    spec:
      affinity:
        nodeAffinity:                                      # node亲和性
          requiredDuringSchedulingIgnoredDuringExecution:  # 硬策略,调度在
            nodeSelectorTerms:
            - matchExpressions:
              - key: esname
                operator: In
                values:
                  - elasticsearch
        podAntiAffinity:                                    # Pod反亲和性
          preferredDuringSchedulingIgnoredDuringExecution:  # 软策略,使Pod分布在不同的节点上
          - weight: 1                                       # 权重,有多个策略通过权重控制调度
            podAffinityTerm:
              topologyKey: esname                           # 通过xxx作为域调度  
              labelSelector:
                matchExpressions:
                - key: esname
                  operator: In
                  values:
                  - elasticsearch
      containers:
      - name: es7
        image: elasticsearch:7.16.2
        resources:
            limits:
              cpu: 1000m
            requests:
              cpu: 100m
        ports:
        - containerPort: 9200
          name: rest
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        env:
          - name: cluster.name
            value: k8s-logs
          - name: node.name
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: discovery.zen.minimum_master_nodes
            value: "2"
          # es 集群地址 podname.svcname
          - name: discovery.seed_hosts
            value: "es-test-0.es7,es-test-1.es7,es-test-2.es7"
          # es 名字
          - name: cluster.initial_master_nodes
            value: "es-test-0,es-test-1,es-test-2"
          - name: ES_JAVA_OPTS
            value: "-Xms1g -Xmx1g"
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      - name: increase-fd-ulimit
        image: busybox
        command: ["sh", "-c", "ulimit -n 65536"]
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: infra-es-sc
      resources:
        requests:
          storage: 1Gi
```

#### 1.6、检查集群状态

- 也可以通过elasticsearch-head连接查看
- 到此集群部署完毕

```sh
[root@k8s-master01 集群]# curl 192.168.1.110:30002/_cat/nodes?v
ip            heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
10.244.85.230           33          36   0    0.03    0.07     0.11 cdfhilmrstw -      es-test-2
10.244.195.20           16          35   0    0.11    0.44     0.39 cdfhilmrstw -      es-test-1
10.244.58.231           54          36   0    0.07    0.10     0.12 cdfhilmrstw *      es-test-0
```


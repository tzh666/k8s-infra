# prometheus监控elasticsearch

```
参考：https://github.com/prometheus-community/elasticsearch_exporter
```

### 1、elk-exporter部署

```shell
cat es-exporter.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elk-exporter
  namespace: monitoring
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  selector:
    matchLabels:
      app: elk-exporter
  template:
    metadata:
      labels:
        app: elk-exporter
    spec:
      nodeName: k8s-node02
      containers:
        - command:
            - /bin/elasticsearch_exporter
            - --es.uri=http://elastic:XXX@10.30.xx.xx:9200
            - --es.all
            - --es.indices
            #- --es.indices_settings
            #- --es.indices_mappings
            - --es.shards
            #- --es.timeout=30s
          image: xx/xx/elasticsearch-exporter:latest
          securityContext:
            capabilities:
              drop:
                - SETPCAP
                - MKNOD
                - AUDIT_WRITE
                - CHOWN
                - NET_RAW
                - DAC_OVERRIDE
                - FOWNER
                - FSETID
                - KILL
                - SETGID
                - SETUID
                - NET_BIND_SERVICE
                - SYS_CHROOT
                - SETFCAP
            readOnlyRootFilesystem: true
          livenessProbe:
            httpGet:
              path: /healthz
              port: 9114
            initialDelaySeconds: 30
            timeoutSeconds: 10
          name: elk-exporter
          ports:
            - containerPort: 9114
              name: http
          readinessProbe:
            httpGet:
              path: /healthz
              port: 9114
            initialDelaySeconds: 10
            timeoutSeconds: 10
          resources:
            limits:
              cpu: 500m
              memory: 2G
            requests:
              cpu: 25m
              memory: 64Mi
      restartPolicy: Always
      securityContext:
        runAsNonRoot: true
        runAsGroup: 10000
        runAsUser: 10000
        fsGroup: 10000
```

image

```
docker pull quay.io/prometheuscommunity/elasticsearch-exporter:latest
```

### 2、svc部署

```
cat es-exporter-server.yaml
apiVersion: v1
kind: Service
metadata:
  name: elk-exporter-svc
  namespace: monitoring
spec:
  selector:
    app: elk-exporter
  clusterIP:
  type: ClusterIP
  ports:
  - port: 9114  # Service端口       
    targetPort: 9114 # pod端口
```

### 3、Prometheus添加监控项

```
# consul自动发现es-exporter
- job_name: 'consul-prometheus-es'
  consul_sd_configs:
    - server: 'consul-server:8500'
  relabel_configs:
    - source_labels: [__meta_gce_metadata_Cluster]
      separator: ;
      regex: (.*)
      target_label: cluster
      replacement: ${1}
      action: replace
    - source_labels: [__meta_consul_service]
      regex: "es-exporter"
      action: keep

```

#### 注册到consul中

```
curl --location --request PUT 'http://xx:32685/v1/agent/service/register' \
--header 'Content-Type: application/json' \
--d'{
    "id": "elk-exporter-svc",
    "name": "es-exporter",
    "address": "elk-exporter-svc",
    "port": 9114,
    "Meta": {
        "env": "prod",
        "team": "es-exporter",
        "project": "devops",
        "owner": "devops"
    },
    "checks": [
        {
            "http": "http://elk-exporter-svc:9114/",
            "interval": "5s"
        }
    ]
}'
```



### 4、grafana面板

```
https://grafana.com/grafana/dashboards/2322
```

### 5、告警规则

```
https://github.com/prometheus-community/elasticsearch_exporter/blob/master/examples/prometheus/elasticsearch.rules.yml
```

```
cat > prometheus-es-rule.yaml << EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    prometheus: k8s
    role: alert-rules
  name: es-cluster-rules
  namespace: kubesphere-monitoring-system
spec:
  groups:
    - name: elasticsearch集群告警
      rules:
        - alert: Elasticsearch 正在运行的节点数量过少
          annotations:
            description: 'Elasticsearch 集群中缺少节点。'
            summary: 'Elasticsearch 集群运行节点数量不足 3 个实例。'
          expr: >-
            elasticsearch_cluster_health_number_of_nodes < 3
          for: 0m
          labels:
            severity: 紧急
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 堆内存使用过高
          annotations:
            description: 'Elasticsearch 堆内存使用警告'
            summary: '堆内存使用率超过 90%（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            (elasticsearch_jvm_memory_used_bytes{area="heap"} / elasticsearch_jvm_memory_max_bytes{area="heap"}) * 100 > 90
          for: 2m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 集群红色
          annotations:
            description: 'Elasticsearch 集群红色（实例{{ $labels.instance }}，节点{{$labels.node}}）。'
            summary: 'Elasticsearch 集群红色状态（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_status{color="red"} == 1
          for: 0m
          labels:
            severity: 紧急
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 集群黄色
          annotations:
            description: 'Elasticsearch 集群黄色（实例{{ $labels.instance }}，节点{{$labels.node}}）。'
            summary: 'Elasticsearch 集群黄色状态（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_status{color="yellow"} == 1
          for: 0m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 健康数据节点
          annotations:
            description: 'Elasticsearch 健康数据节点（实例{{ $labels.instance }}，节点{{$labels.node}}）。'
            summary: 'Elasticsearch 集群中缺少数据节点（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_number_of_data_nodes < 3
          for: 0m
          labels:
            severity: 紧急
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 正在重新分配的分片
          annotations:
            description: 'Elasticsearch 正在重新分配的分片（实例{{ $labels.instance }}，节点{{$labels.node}}）。'
            summary: 'Elasticsearch 正在重新分配分片（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_relocating_shards > 0
          for: 0m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 正在重新分配分片的时间过长
          annotations:
            description: Elasticsearch 正在重新分配分片的时间过长（实例{{ $labels.instance }}，节点{{$labels.node}}）。
            summary: 'Elasticsearch 已经重新分配分片超过15分钟（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_relocating_shards > 0
          for: 15m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 正在初始化的分片
          annotations:
            description: Elasticsearch 正在初始化分片（实例{{ $labels.instance }}，节点{{$labels.node}}）。
            summary: 'Elasticsearch 正在初始化分片（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_initializing_shards > 0
          for: 0m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 初始化分片的时间过长
          annotations:
            description: Elasticsearch 初始化分片的时间过长（实例{{ $labels.instance }}，节点{{$labels.node}}）。
            summary: 'Elasticsearch 已经初始化分片超过15分钟（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_initializing_shards > 0
          for: 15m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 未分配的分片
          annotations:
            description: Elasticsearch 未分配的分片（实例{{ $labels.instance }}，节点{{$labels.node}}）。
            summary: 'Elasticsearch 存在未分配的分片（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_unassigned_shards > 0
          for: 0m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 待处理任务
          annotations:
            description: Elasticsearch 待处理任务（实例{{ $labels.instance }}，节点{{$labels.node}}）。
            summary: 'Elasticsearch 存在待处理任务。集群响应速度变慢。（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            elasticsearch_cluster_health_number_of_pending_tasks > 0
          for: 15m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test

        - alert: Elasticsearch 没有新的文档
          annotations:
            description: Elasticsearch 没有新的文档（实例{{ $labels.instance }}，节点{{$labels.node}}）。
            summary: '10分钟内没有新的文档！（VALUE = {{ $value }}，LABELS = {{ $labels }}）。'
          expr: >-
            increase(elasticsearch_indices_docs{es_data_node="true"}[10m]) < 1
          for: 0m
          labels:
            severity: 警告
            region: 业务生产ES集群
            vendor: test
EOF
```




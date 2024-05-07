# prometheus监控zookeeper

- prometheus监控zookeeper，分2种情况，主要是看zk版本
  -  zookeeper 从3.5.5版本开始，原生支持开放指标接口供Prometheus采集 
  -  低于3.5.5版本，只能使用zookeeper-exporter进行采集 
- 官方文档：https://zookeeper.apache.org/doc/r3.8.0/zookeeperMonitor.html

### 一、 低于3.5.5版本

- ##### 部署zookeeper-exporter

  - Deployment
  - Service
  - ServiceMonitor
    -  创建ServiceMonitor，让Prometheus-operator自动添加采集job 

- ##### Grafana面板ID：11442

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zookeeper-exporter
  namespace: monitoring
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: zookeeper-exporter
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: zookeeper-exporter
    spec:
      containers:
      - args:
        - --zk-hosts
        - 192.168.18.234:2181 # 修改为zookeeper实例的地址，以逗号分隔
        - --listen
        - 0.0.0.0:9141
        - --location
        - /metrics
        - --timeout
        - "30"
        env:
        - name: TZ
          value: Asia/Shanghai
        image: dabealu/zookeeper-exporter:v0.1.13
        imagePullPolicy: IfNotPresent
        name: zookeeper-exporter
        ports:
        - containerPort: 9141
          protocol: TCP
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 200m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: zookeeper-exporter
  name: zookeeper-exporter
  namespace: monitoring
spec:
  ports:
  - name: zookeeper-exporter
    port: 9141
    protocol: TCP
    targetPort: 9141
  selector:
    app: zookeeper-exporter
  sessionAffinity: None
  type: ClusterIP
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: zookeeper-exporter
  name: zookeeper-exporter
  namespace: monitoring
spec:
  endpoints:
  - honorLabels: true
    interval: 20s
    path: /metrics
    port: zookeeper-exporter
    scheme: http
    scrapeTimeout: 20s
  jobLabel: zookeeper-exporter
  namespaceSelector:
    matchNames:
    - monitoring
  sampleLimit: 0
  selector:
    matchLabels:
      app: zookeeper-exporter
```

- ##### 遇到的问题解决办法：

```sh
# 在启动zookeeper_exporter时，提示mntr is not executed because it is not in the whitelist ，即mntr命令不在白名单中。

# 修改配置文件 zoo.cfg
# 这代表允许使用所有命令
4lw.commands.whitelist=*   
```



### 二、高于3.5.5版本

- ##### 高于这个版本直接，加上以下配置

  - **metricsProvider.className**：
    - 以启用Prometheus.io导出器
  -  **metricsProvider.httpPort** 
    -  Prometheus.io导出器将启动Jetty服务器并绑定到该端口，默认为7000 
    -  则Prometheus.io将导出有关JVM的指标，默认值为true 

- ##### Grafana面板ID：10465

```sh
metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider
metricsProvider.httpPort=7000
metricsProvider.exportJvmInfo=true
```

```sh
# 然后添加采集
global:
  scrape_interval: 10s
scrape_configs:
  - job_name: test-zk
    static_configs:
    - targets: ['zk1:7000','zk2:7000','zk3:7000']
```



### 三、告警规则

```yaml
groups:
- name: zk-alert-example
  rules:
  - alert: ZooKeeper server is down
    expr:  up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Instance {{ $labels.instance }} ZooKeeper server is down"
      description: "{{ $labels.instance }} of job {{$labels.job}} ZooKeeper server is down: [{{ $value }}]."

  - alert: create too many znodes
    expr: znode_count > 1000000
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} create too many znodes"
      description: "{{ $labels.instance }} of job {{$labels.job}} create too many znodes: [{{ $value }}]."

  - alert: create too many connections
    expr: num_alive_connections > 50 # suppose we use the default maxClientCnxns: 60
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} create too many connections"
      description: "{{ $labels.instance }} of job {{$labels.job}} create too many connections: [{{ $value }}]."

  - alert: znode total occupied memory is too big
    expr: approximate_data_size /1024 /1024 > 1 * 1024 # more than 1024 MB(1 GB)
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} znode total occupied memory is too big"
      description: "{{ $labels.instance }} of job {{$labels.job}} znode total occupied memory is too big: [{{ $value }}] MB."

  - alert: set too many watch
    expr: watch_count > 10000
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} set too many watch"
      description: "{{ $labels.instance }} of job {{$labels.job}} set too many watch: [{{ $value }}]."

  - alert: a leader election happens
    expr: increase(election_time_count[5m]) > 0
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} a leader election happens"
      description: "{{ $labels.instance }} of job {{$labels.job}} a leader election happens: [{{ $value }}]."

  - alert: open too many files
    expr: open_file_descriptor_count > 300
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} open too many files"
      description: "{{ $labels.instance }} of job {{$labels.job}} open too many files: [{{ $value }}]."

  - alert: fsync time is too long
    expr: rate(fsynctime_sum[1m]) > 100
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} fsync time is too long"
      description: "{{ $labels.instance }} of job {{$labels.job}} fsync time is too long: [{{ $value }}]."

  - alert: take snapshot time is too long
    expr: rate(snapshottime_sum[5m]) > 100
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} take snapshot time is too long"
      description: "{{ $labels.instance }} of job {{$labels.job}} take snapshot time is too long: [{{ $value }}]."

  - alert: avg latency is too high
    expr: avg_latency > 100
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Instance {{ $labels.instance }} avg latency is too high"
      description: "{{ $labels.instance }} of job {{$labels.job}} avg latency is too high: [{{ $value }}]."

  - alert: JvmMemoryFillingUp
    expr: jvm_memory_bytes_used / jvm_memory_bytes_max{area="heap"} > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "JVM memory filling up (instance {{ $labels.instance }})"
      description: "JVM memory is filling up (> 80%)\n labels: {{ $labels }}  value = {{ $value }}\n"
```


## 基于 Prometheus Stack 监控 Java 容器

```sh
# 参考文档：
https://github.com/prometheus/jmx_exporter
https://mp.weixin.qq.com/s/q_22V8rpiSGGA7hSNpcg8Q
https://blog.csdn.net/sinat_31632437/article/details/128934360
```



### 一、背景概述

```sh
   随着云原生技术体系的崛起以及周边生态理念的日渐成熟，越来越多的公司开始将自身原有的基于传统模型的业务开始迁移至云原生，然而，随着迁移的不断进行，而原有的观测模式也逐渐发生变化，从而使得原有的技术体系在新的生态环境中开始出现水土不服。

   在传统的监控模型体系中，由于所构建的微服务大多数都是运行在传统的虚拟机平台，使得数据的获取相对来说比较容易，无论这些微服务是基于传统的 Zabbix 组件还是新兴的 Prometheus 平台。然而，基于云化改造后的微服务实例，它们以成千上万个 Pod 模型运行在 Kubernetes Cluster 中提供服务，并且分布在不同的 Namespace 中，除此之外，这些 Pod 可能因各种不同的原因频繁重启或重建，导致其对应的 IP 地址发生变化，使得容器中实例的数据采集以及监控成为一个头痛的难题。
```



### 二、方案

#### 方案1：

- 参考：https://www.cnblogs.com/hsyw/p/17101231.html

```sh
1、集成 Actuator 与 Micrometer 插件

     通常情况下，若我们基于 Prometheus 进行应用级别的数据采集及观测，那么，需要在 Spring Boot 应用中使用 Spring Boot Actuator 插件监控应用、暴露指标，并使用 Micrometer Prometheus 将 Actuator 监控指标转换为 Prometheus 格式。

     同时，Micrometer 为 Java 平台上的性能数据收集提供了一个通用的 API，类似于 SLF4J ，只不过它关注的不是 Logging（日志），而是 Application Metrics（应用指标）。 

     2、配置 Prometheus 自动发现

     作为一个开源系统监控和告警工具链组件， 基于其特性，Prometheus 能够采集相关监控指标，并存储为时间序列数据，同时，Prometheus 还提供了灵活的查询语言 PromQL 来查询数据。

     Prometheus 通过拉模型采集指标，因此，我们需要在 Prometheus 集群中配置服务发现（Service Monitor）来定期从应用中抓取指标
```

#### 方案2：

- 使用 JMX Exporter

```sh
# 1、首先准备一个base images，把jmx_prometheus jar包集成到base镜像，当然也可以用init的方式
cat Dockerfile
FROM xxx/k8s-base/openjdk8:alpine-3.16-jre8

ENV SKYWALKING_OPTS=""

ADD apache-skywalking-java-agent-8.13.0.tgz /usr/

COPY jmx_prometheus/jmx_prometheus_javaagent-0.19.0.jar /app/jmx_prometheus-0.19.0.jar

COPY jmx_prometheus/config.yaml /app/

# 配置文件
cat jmx_prometheus/config.yaml 
---
# 可以设置采集规则，默认是采集所有指标
rules:
- pattern: ".*"
```

```yaml
# 2、然后在Pod的deployment编排文件,添加注解参数
kind: Deployment
apiVersion: apps/v1
metadata:
  .
  .
  .
spec:
  .
  .
  .
  template:
    metadata:
      annotations:
        # promethues通过这个标签动态获取到pod的信息
        prometheus.io/scrape: jvm
        prometheus.io/port: '2024'
    spec:
      containers:
        - .
          env:
            # 设置java的jvm参数
            - name: JAVA_OPTS
            value: -Xms4g -Xmx4g -javaagent:./jmx_prometheus-0.19.0.jar=2024:config.yaml
          ports:
            - containerPort: JAVAPORT
              protocol: TCP
              name: apiport
            - containerPort: 8784
              protocol: TCP
              name: jmxport
```

```sh
# 3、第三步就是添加Prometheus的自动发现
kubectl -n monitoring edit cm/prometheus-config
# Pod metrics,scrape=jvm
- job_name: 'jmx-exporter'
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - action: keep
    regex: jvm
    source_labels:
    - __meta_kubernetes_pod_annotation_prometheus_io_scrape
  - action: replace
    regex: (.+)
    source_labels:
    - __meta_kubernetes_pod_annotation_prometheus_io_path
    target_label: __metrics_path__
  - action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    source_labels:
    - __address__
    - __meta_kubernetes_pod_annotation_prometheus_io_port
    target_label: __address__
    # 匹配你在pod中定义的标签名，比如app: PROJECTNAME-DENV app: bims-meta-yfdev，tke的会默认加上pod-template-hash='XXXXXXXXXXXXX'
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - action: replace
    source_labels:
    - __meta_kubernetes_namespace
    target_label: namespace
  - action: replace
    source_labels:
    - __meta_kubernetes_pod_name
    target_label: pod
  # 新增一个contained的lable  意思是把容器名字赋值给container
  - action: replace
    source_labels:
    - __meta_kubernetes_pod_container_name
    target_label: container  
```

```sh
# 4、grafana面板可以用  10124
```

```sh
# 5、告警规则
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    prometheus: k8s
    role: alert-rules
  name: jvm-metrics-rules
  namespace: monitoring
spec:
  groups:
  - name: jvm-metrics-rules
    rules:
    # 在5分钟里，GC花费时间超过10%
    - alert: GcTimeTooMuch
      expr: increase(jvm_gc_collection_seconds_sum[5m]) > 30
      for: 5m
      labels:
        severity: red
      annotations:
        summary: "{{ $labels.app }} GC时间占比超过10%"
        message: "ns:{{ $labels.namespace }} pod:{{ $labels.pod }} GC时间占比超过10%，当前值({{ $value }}%)"
    # GC次数太多
    - alert: GcCountTooMuch
      expr: increase(jvm_gc_collection_seconds_count[1m]) > 30
      for: 1m
      labels:
        severity: red
      annotations:
        summary: "{{ $labels.app }} 1分钟GC次数>30次"
        message: "ns:{{ $labels.namespace }} pod:{{ $labels.pod }} 1分钟GC次数>30次，当前值({{ $value }})"
    # FGC次数太多
    - alert: FgcCountTooMuch
      expr: increase(jvm_gc_collection_seconds_count{gc="ConcurrentMarkSweep"}[1h]) > 3
      for: 1m
      labels:
        severity: red
      annotations:
        summary: "{{ $labels.app }} 1小时的FGC次数>3次"
        message: "ns:{{ $labels.namespace }} pod:{{ $labels.pod }} 1小时的FGC次数>3次，当前值({{ $value }})"
    # 非堆内存使用超过80%
    - alert: NonheapUsageTooMuch
      expr: jvm_memory_bytes_used{job="jmx-exporter", area="nonheap"} / jvm_memory_bytes_max * 100 > 80
      for: 1m
      labels:
        severity: red
      annotations:
        summary: "{{ $labels.app }} 非堆内存使用>80%"
        message: "ns:{{ $labels.namespace }} pod:{{ $labels.pod }} 非堆内存使用率>80%，当前值({{ $value }}%)"
    # 内存使用预警
    - alert: HeighMemUsage
      expr: process_resident_memory_bytes{job="jmx-exporter"} / os_total_physical_memory_bytes * 100 > 85
      for: 1m
      labels:
        severity: red
      annotations:
        summary: "{{ $labels.app }} rss内存使用率大于85%"
        message: "ns:{{ $labels.namespace }} pod:{{ $labels.pod }} rss内存使用率大于85%，当前值({{ $value }}%)"
```



- 踩坑

```yaml
# https://blog.csdn.net/qq_34468174/article/details/123084653

#增加prometheus-k8s用户权限
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-k8s
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/metrics
      - services
      - nodes
      - endpoints
      - pods
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - get
  - nonResourceURLs:
      - /metrics
    verbs:
      - get
```


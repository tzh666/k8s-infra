## k8s上部署Prometheus

### 一、k8上部署Prometheus

- k8s上部署Prometheus有多种方式，可以通过helm部署，可以手撕yaml部署，也可以通过 Kube-Prometheus 技术栈的方式部署，**本文采用的就是Kube-Prometheus方式部署**
- 参考文献：
  - https://blog.csdn.net/gyfghh/article/details/131004355
  - https://www.cnblogs.com/hsyw/p/14272514.html

- Prometheus git官网  【要注意的是部署的版本要跟k8s版本对应】
  - https://github.com/prometheus-operator/kube-prometheus

#### 1.1、下载配置文件

```sh
git clone -b release-0.13 --single-branch https://github.com/coreos/kube-prometheus.git
```

#### 1.2、整理目录

```sh
cd kube-prometheus/

mkdir alertmanager
mkdir grafana
mkdir blackboxExporter
mkdir nodeExporter
mkdir prometheus
mkdir kubeStateMetrics
mkdir prometheusAdapter
mkdir prometheusOperator
mkdir kubernetesControlPlane

mv alertmanager-* alertmanager/
mv grafana-* grafana/
mv blackboxExporter-* blackboxExporter/
mv nodeExporter-* nodeExporter/
mv prometheus-* prometheus/
mv kubeStateMetrics-* kubeStateMetrics/
mv prometheusAdapter-* prometheusAdapter/
mv prometheusOperator-* prometheusOperator/
mv kubernetesControlPlane-* kubernetesControlPlane/
mv kubePrometheus-prometheusRule.yaml prometheus/
```

#### 1.3、持久化数据

- 采用NFS做动态存储
  - 参考文档：https://blog.csdn.net/weixin_55509209/article/details/130214432
  - NFS部署参考：https://www.cnblogs.com/hsyw/p/13610960.html
  - https://www.cnblogs.com/pollos/articles/17369294.html
  - https://www.cnblogs.com/hsyw/p/14461502.html

##### 1.3.1、持久化Prometheus数据

```yaml
cd manifests/
vim prometheus/prometheus-prometheus.yaml 
# 修改数据保存时间
spec:
  retention: 30d # 数据保留时间
  alerting:
    alertmanagers:
    - apiVersion: v2
      name: alertmanager-main
      namespace: monitoring
      port: web
  storage:   # 数据持久化
    volumeClaimTemplate:
      spec:
        storageClassName: prometheus-data-db  # sc name
        resources:
          requests:
            storage: 100Gi
```

##### 1.3.2、持久化grafana数据

```yaml
volumes:
#- emptyDir: {}                   # 注释这2行，改成下面的指定pvc
#  name: grafana-storage
- name: grafana-storage
persistentVolumeClaim:
claimName: grafana-pvc
```

##### 1.3.3、持久化alertmanager数据

```sh
spec:
  image: quay.io/prometheus/alertmanager:v0.26.0
  nodeSelector:
    kubernetes.io/os: linux
  podMetadata:
    labels:
      app.kubernetes.io/component: alert-router
      app.kubernetes.io/instance: main
      app.kubernetes.io/name: alertmanager
      app.kubernetes.io/part-of: kube-prometheus
      app.kubernetes.io/version: 0.26.0 
  storage:   # 数据持久化，新增这个指定sc名字
    volumeClaimTemplate:
      spec:
        storageClassName: alertmanager-data-db
        resources:
          requests:
            storage: 100Gi
```

##### 1.3.4、sc的yaml文件

```yaml
cd kube-prometheus/manifests
mkdir data-db-sc

[root@k8s-master01 manifests]# ll data-db-sc/
total 16
-rw-r--r-- 1 root root 227 Oct 17 11:47 alertmanager-sc.yaml
-rw-r--r-- 1 root root 215 Oct 17 11:40 grafana-pvc.yaml
-rw-r--r-- 1 root root 217 Oct 17 11:37 grafana-sc.yaml
-rw-r--r-- 1 root root 225 Oct 16 17:38 prometheus-sc.yaml

[root@k8s-master01 manifests]# cat data-db-sc/*
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alertmanager-data-db
provisioner: fuseim.pri/ifs
parameters:
  archiveOnDelete: "true"   # 设置为"false"时删除PVC不会保留数据,"true"则保留数据
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: grafana-pvc
  namespace: monitoring
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: grafana-sc
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: grafana-sc
provisioner: fuseim.pri/ifs
parameters:
  archiveOnDelete: "true"   # 设置为"false"时删除PVC不会保留数据,"true"则保留数据
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prometheus-data-db
provisioner: fuseim.pri/ifs
parameters:
  archiveOnDelete: "true"   # 设置为"false"时删除PVC不会保留数据,"true"则保留数据
```

#### 1.3.5、启动服务

```sh
# 先启动operator，然后再启动其他的即可
kubectl apply -f setup/

kubectl apply -f prometheus/
kubectl apply -f prometheusOperator/
kubectl apply -f prometheusAdapter/
kubectl apply -f kubeStateMetrics/
kubectl apply -f kubernetesControlPlane/
kubectl apply -f nodeExporter/
kubectl apply -f grafana/
kubectl apply -f blackboxExporter/
kubectl apply -f alertmanager/


# 关闭
kubectl delete -f ./grafana/grafana-networkPolicy.yaml
kubectl delete -f ./nodeExporter/nodeExporter-networkPolicy.yaml
kubectl delete -f ./prometheus/prometheus-networkPolicy.yaml
kubectl delete -f ./blackboxExporter/blackboxExporter-networkPolicy.yaml
kubectl delete -f ./kubeStateMetrics/kubeStateMetrics-networkPolicy.yaml
kubectl delete -f ./prometheusAdapter/prometheusAdapter-networkPolicy.yaml
kubectl delete -f ./prometheusOperator/prometheusOperator-networkPolicy.yaml
kubectl delete -f ./alertmanager/alertmanager-networkPolicy.yaml
```



### 二、采用钉钉告警

- kubectl apply -f dingtalk-configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dingtalk-cm
  namespace: monitoring
data:
  config.yml: |-
    templates:
      - /etc/prometheus-webhook-dingtalk/dingding.tmpl
    targets:
      webhook:
        url: https://oapi.dingtalk.com/robot/send?access_token=***
        secret: "SEC***"
        message:
          text: '{{ template "dingtalk.to.message" . }}'
  dingding.tmpl: |-
    {{ define "dingtalk.to.message" }}
    {{- if gt (len .Alerts.Firing) 0 -}}
    {{- range $index, $alert := .Alerts -}}

    =========  **监控告警** =========  

    **告警集群:**     k8s 
    **告警类型:**    {{ $alert.Labels.alertname }}   
    **告警级别:**    {{ $alert.Labels.severity }}  
    **告警状态:**    {{ .Status }}   
    **故障主机:**    {{ $alert.Labels.instance }} {{ $alert.Labels.device }}   
    **告警主题:**    {{ .Annotations.summary }}   
    **告警详情:**    {{ $alert.Annotations.message }}{{ $alert.Annotations.description}}   
    **主机标签:**    {{ range .Labels.SortedPairs  }}  </br> [{{ .Name }}: {{ .Value | markdown | html }} ] 
    {{- end }} </br>

    **故障时间:**    {{ ($alert.StartsAt.Add 28800e9).Format "2006-01-02 15:04:05" }}  
    ========= = **end** =  =========  
    {{- end }}
    {{- end }}

    {{- if gt (len .Alerts.Resolved) 0 -}}
    {{- range $index, $alert := .Alerts -}}

    ========= **故障恢复** =========  
    **告警集群:**     k8s
    **告警主题:**    {{ $alert.Annotations.summary }}  
    **告警主机:**    {{ .Labels.instance }}   
    **告警类型:**    {{ .Labels.alertname }}  
    **告警级别:**    {{ $alert.Labels.severity }}    
    **告警状态:**    {{ .Status }}  
    **告警详情:**    {{ $alert.Annotations.message }}{{ $alert.Annotations.description}}  
    **故障时间:**    {{ ($alert.StartsAt.Add 28800e9).Format "2006-01-02 15:04:05" }}  
    **恢复时间:**    {{ ($alert.EndsAt.Add 28800e9).Format "2006-01-02 15:04:05" }}  

    ========= = **end** =  =========
    {{- end }}
    {{- end }}
    {{- end }}
```

- kubectl apply -f  dingtalk.yaml 

```yaml
apiVersion: v1
kind: Service
metadata:
  name: dingtalk
  namespace: monitoring
spec:
  selector:
    app: dingtalk
  ports:
    - name: http
      protocol: TCP
      port: 8060
      targetPort: 8060
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dingtalk
  namespace: monitoring
  labels:
    app: dingtalk
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  selector:
    matchLabels:
      app: dingtalk
  template:
    metadata:
      labels:
        app: dingtalk
    spec:
      restartPolicy: "Always"
      containers:
      - name: dingtalk
        image: timonwong/prometheus-webhook-dingtalk
        imagePullPolicy: "IfNotPresent"
        volumeMounts:
          - name: dingtalk-conf
            mountPath: /etc/prometheus-webhook-dingtalk/
        resources:
          limits:
            cpu: "400m"
            memory: "500Mi"
          requests:
            cpu: "100m"
            memory: "100Mi"
        ports:
        - containerPort: 8060
          name: http
          protocol: TCP 
        readinessProbe:
          failureThreshold: 3
          periodSeconds: 5
          initialDelaySeconds: 30
          successThreshold: 1
          tcpSocket:
            port: 8060
        livenessProbe:
          tcpSocket:
            port: 8060
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
        - name: dingtalk-conf
          configMap:
            name: dingtalk-cm
```

-  配置告警规则，创建文件alertmanager.yaml 

```yaml
global:
  resolve_timeout: 5m  #解析超时时间，也就是报警恢复不是立马发送的，而是在一个时间范围内不在触发报警，才能发送恢复报警，默认为5分钟
receivers:
- name: 'null'   #定义一个为null的接受者
- name: 'webhook'  #钉钉webhook
  webhook_configs:
  - url: 'http://dingtalk:8060/dingtalk/webhook/send'
    send_resolved: true  #告警解决发送
route:
  group_by: ['job']  #采用哪个标签作为分组
  group_wait: 30s   # 当一个新的报警分组被创建后，需要等待至少group_wait时间来初始化通知，这种方式可以确保您能有足够的时间为同一分组来获取多个警报，然后一起触发这个报警信息
  group_interval: 5m   # 当第一个报警发送后，等待'group_interval'时间来发送新的一组报警信息
  repeat_interval: 12h   # 如果一个报警信息已经发送成功了，等待'repeat_interval'时间来重新发送他们
  receiver: "webhook" #默认的receiver：如果一个报警没有被一个route匹配，则发送给默认的接收器
  routes:   #子路由
  - match:
      severity: 'info'   
    continue: true
    receiver: 'null'
  - match:
      severity: 'none'
    continue: true
    receiver: 'null'  #过滤级别为info和none的告警
```



### 三、添加新的告警规则【PrometheusRule】

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    app.kubernetes.io/component: prometheus
    app.kubernetes.io/instance: k8s
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/part-of: kube-prometheus
    app.kubernetes.io/version: 2.46.0
    prometheus: k8s
    role: alert-rules
  name: base-linux-rules
  namespace: monitoring
spec:

# 上面的不用动，改下面的，改完   apply 创建一下即可
  groups:
  - name: mysql-exporter
    rules:
    - alert: mysqlDown
      annotations: 
        description: MySQL实例:{{ $labels.instance }} 挂了
        summary: MySQL无法连接
      expr: mysql_up != 1 
      for: 1m
      labels:
        level: high
        severity: critical
        type: database
```

上面参数说明：

- `apiVersion`: 这个字段指定了使用的 Kubernetes API 版本，`monitoring.coreos.com/v1` 表示使用了 Prometheus Operator 中的自定义资源版本
- `kind`: 这里指定了自定义资源的类型，即 `PrometheusRule`
- `metadata`: 这里是一些元数据，比如标签（labels）、名称（name）、命名空间（namespace）等，用于对该资源进行标识和分类
- `spec`: 这里定义了实际的规则配置
- `groups`: 这个字段是一个规则组（RuleGroup），它可以包含一个或多个相关的规则。
- `name`: 这里定义了规则组的名称为 "mysql-exporter"。
- `rules`: 这里是规则组包含的规则列表。
- `alert`: 这是规则的名称，即 "mysqlDown"，用于标识规则。
- `annotations`: 这里定义了一些注释，包括告警的描述和摘要信息。
- `expr`: 这是一个 PromQL 表达式，用于定义告警的触发条件。在这个示例中，它检查mysql_up不等于1。
- `for`: 这是规则的持续时间，即在满足触发条件持续 1 分钟后才触发告警。
- `labels`: 这里定义了一些标签，用于对告警进行分类和标识。



### 四、添加外部的主机监控  【 additionalScrapeConfigs 】

```sh
# 首先，这个配置文件是记录外部主机的信息，job_name、static_configs、targets、labels等
# 拿这个模板抄就行了
[root@k8s-master01 prometheusAdditional]# cat exporter_out_linux.yaml 
- job_name: 'node'
  static_configs:
  - targets: ['192.168.18.222:9100','192.168.18.226:9100','192.168.18.232:9100']
    labels:
      job: 'Linux'
- job_name: 'node-monitor'
  static_configs:
  #  科大引擎、新方MS主机监控
  - targets: ['192.168.18.211:9100','192.168.20.149:9100']
    labels: {cluster: 'test',job: 'Linux',export: 'node_exporter_out'}
  # tts 黑洞
  - targets: ['192.168.18.140:9100','192.168.20.195:9100']
    labels: {cluster: 'test',job: 'Linux',export: 'node_exporter_out'}

# 然后创建secret
kubectl create secret generic additional-linux -n monitoring --from-file=exporter_out_linux.yaml --dry-run -oyaml > additional_out_linux.yaml
```

- 修改Prometheus文件

```sh
# 进到manifests目录，编辑
[root@k8s-master01 manifests]# vim prometheus-prometheus.yaml 
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
  labels:
    prometheus: prometheus
spec:
  replicas: 2
... 加上下面3行
  additionalScrapeConfigs:
    name: additional-scrape-configs
    key: prometheus-additional.yaml
...

# replace刚刚修改的文件
[root@k8s-master01 manifests]# kubectl replace -f  prometheus-prometheus.yaml  -n monitoring

# 手动删除pod、使之重新构建
[root@k8s-master01 manifests]# kubectl delete po  prometheus-k8s-0  prometheus-k8s-1  -n monitoring 
```




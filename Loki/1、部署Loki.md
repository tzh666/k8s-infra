## 部署Loki

### 一、部署Loki

#### 1.1、添加 Loki 的 Chart 仓库

```sh
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

#### 1.2、获取 `loki-stack` 的 Chart 包并解压

```sh
helm pull grafana/loki-stack --untar --version 2.6.4
```

`loki-stack` 这个 Chart 包里面包含所有的 Loki 相关工具依赖，在安装的时候可以根据需要开启或关闭，比如我们想要安装 Grafana，则可以在安装的时候简单设置 `--set grafana.enabled=true` 即可。默认情况下 `loki`、`promtail` 是自动开启的，也可以根据我们的需要选择使用 `filebeat` 或者 `logstash`，同样在 Chart 包根目录下面创建用于安装的 Values 文件

```yaml
# loki-sc.yaml

```

```yaml
# values-prod.yaml
loki:
  enabled: true
  replicas: 1
  rbac:
    pspEnabled: false
  persistence:
    enabled: true
    storageClassName: local-path

promtail:
  enabled: true
  rbac:
    pspEnabled: false

grafana:
  enabled: true
  service:
    type: NodePort
  rbac:
    pspEnabled: false
  persistence:
    enabled: true
    storageClassName: local-path
    accessModes:
      - ReadWriteOnce
    size: 1Gi
```

然后直接使用上面的 Values 文件进行安装即可：

```sh
[root@k8s-master01 loki-stack]# kubectl create ns logging
[root@k8s-master01 loki-stack]# helm upgrade --install loki -n logging -f values-prod.yaml .
Release "loki" does not exist. Installing it now.
NAME: loki
LAST DEPLOYED: Sat Oct 29 22:23:25 2022
NAMESPACE: logging
STATUS: deployed
REVISION: 1
NOTES:
The Loki stack has been deployed to your cluster. Loki can now be added as a datasource in Grafana.

See http://docs.grafana.org/features/datasources/loki/ for more detail.
```

安装完成后可以查看 Pod 的状态：

```sh
[root@k8s-master01 loki-stack]# kubectl get po -n logging
NAME                           READY   STATUS    RESTARTS   AGE
loki-0                         1/1     Running   0          3m30s
loki-grafana-fbf99574f-6nlhk   2/2     Running   0          3m30s
loki-promtail-cbxcj            1/1     Running   0          11m
loki-promtail-gbnqd            1/1     Running   0          11m
loki-promtail-n9nn5            1/1     Running   0          11m
loki-promtail-q2zp4            1/1     Running   0          11m
loki-promtail-wtmrg            1/1     Running   0          11m
```

这里我们为 Grafana 设置的 NodePort 类型的 Service：

```sh
[root@k8s-master01 loki-stack]# kubectl get svc -n logging
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
loki            ClusterIP   10.104.186.9    <none>        3100/TCP       5m34s
loki-grafana    NodePort    10.110.58.196   <none>        80:31634/TCP   5m34s
loki-headless   ClusterIP   None            <none>        3100/TCP       5m34s
```

可以通过 NodePort 端口 `31634` 访问 Grafana，使用下面的命令获取 Grafana 的登录密码：

```sh
kubectl get secret --namespace logging loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

我们使用 Helm 安装的 Promtail 默认已经帮我们做好了配置，已经针对 Kubernetes 做了优化，我们可以查看其配置：

```sh
[root@k8s-master01 loki-stack]# kubectl get secret loki-promtail -n logging -o json | jq -r '.data."promtail.yaml"' | base64 --decode
server:
  log_level: info
  http_listen_port: 3101

client:
  url: http://loki:3100/loki/api/v1/push
  

positions:
  filename: /run/promtail/positions.yaml

scrape_configs:
  # See also https://github.com/grafana/loki/blob/master/production/ksonnet/promtail/scrape_config.libsonnet for reference
  - job_name: kubernetes-pods
    pipeline_stages:
      - cri: {}
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels:
          - __meta_kubernetes_pod_controller_name
        regex: ([0-9a-z-.]+?)(-[0-9a-f]{8,10})?
        action: replace
        target_label: __tmp_controller_name
      - source_labels:
          - __meta_kubernetes_pod_label_app_kubernetes_io_name
          - __meta_kubernetes_pod_label_app
          - __tmp_controller_name
          - __meta_kubernetes_pod_name
        regex: ^;*([^;]+)(;.*)?$
        action: replace
        target_label: app
      - source_labels:
          - __meta_kubernetes_pod_label_app_kubernetes_io_component
          - __meta_kubernetes_pod_label_component
        regex: ^;*([^;]+)(;.*)?$
        action: replace
        target_label: component
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: node_name
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        replacement: $1
        separator: /
        source_labels:
        - namespace
        - app
        target_label: job
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container
      - action: replace
        replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_uid
        - __meta_kubernetes_pod_container_name
        target_label: __path__
      - action: replace
        regex: true/(.*)
        replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_annotationpresent_kubernetes_io_config_hash
        - __meta_kubernetes_pod_annotation_kubernetes_io_config_hash
        - __meta_kubernetes_pod_container_name
        target_label: __path__
```


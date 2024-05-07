## Ingress-Nginx部署

### 一、版本选择

- 查看官网匹配版本：https://github.com/kubernetes/ingress-nginx
- 我当前的k8s版本毕竟新，1.28.0，所以我也选当前最新的【Helm Chart 4.8.3】

- 参考：https://www.shangyexinzhi.com/article/4466422.html

```sh
由于 ingress-nginx 所在的节点需要能够访问外网（不是强制的），这样域名可以解析到这些节点上直接使用，所以需要让 ingress-nginx 绑定节点的 80 和 443 端口，所以可以使用 hostPort 来进行访问，当然对于线上环境来说为了保证高可用，一般是需要运行多个 ·ingress-nginx 实例的，然后可以用一个 nginx/haproxy 作为入口，通过 keepalived 来访问边缘节点的 vip 地址

"边缘节点" 所谓的边缘节点即集群内部用来向集群外暴露服务能力的节点，集群外部的服务通过该节点来调用集群内部的服务，边缘节点是集群内外交流的一个 Endpoint
```



### 二、安装

```sh
# 添加仓库，更新
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 版本查询
helm search repo ingress-nginx/ingress-nginx

# 下载包，且解压
helm pull ingress-nginx/ingress-nginx --version 4.8.3 --untar

# 或者
wget https://github.com/kubernetes/ingress-nginx/releases/download/helm-chart-4.8.3/ingress-nginx-4.8.3.tgz
```

```sh
# 修改配置文件
cp values.yaml ingress-values.yaml

vim ingress-values.yaml
# 需要修改的位置
	a)	Controller和admissionWebhook的镜像地址，需要将公网镜像同步至公司内网镜像仓库
	b)	hostNetwork设置为true
	c)	dnsPolicy设置为 ClusterFirstWithHostNet
	d)	NodeSelector添加ingress: "true"部署至指定节点
	e)	类型更改为kind: DaemonSet
	f)    tolerations:   # kubeadm 安装的集群默认情况下master是有污点，需要容忍这个污点才可以部署
            - key: "node-role.kubernetes.io/master"
              operator: "Equal"
              value: "value"
              effect: "NoSchedule"
    g)    publishService:  # hostNetwork 模式下设置为false，通过节点IP地址上报ingress status数据
            enabled: false
    l)    service:  # HostNetwork 模式不需要创建service
            enabled: false
    m)    admissionWebhooks:
            enabled: true
# 安装
helm upgrade   --install ingress-nginx -n ingress-nginx -f ./ingress-values.yaml .
```

```yaml
# 不想改就用我的
[root@k8s-master01 ingress-nginx]# cat ingress-values.yaml
namespaceOverride: ""
commonLabels: {}
controller:
  name: controller
  enableAnnotationValidations: false
  image:
    chroot: false
    registry: registry.k8s.io
    image: ingress-nginx/controller
    tag: "v1.9.4"
    digest: sha256:5b161f051d017e55d358435f295f5e9a297e66158f136321d9b04520ec6c48a3
    digestChroot: sha256:5976b1067cfbca8a21d0ba53d71f83543a73316a61ea7f7e436d6cf84ddf9b26
    pullPolicy: IfNotPresent
    runAsUser: 101
    allowPrivilegeEscalation: true
  existingPsp: ""
  containerName: controller
  containerPort:
    http: 80
    https: 443
  config: {}
  configAnnotations: {}
  proxySetHeaders: {}
  addHeaders: {}
  dnsConfig: {}
  hostAliases: []
  hostname: {}
  dnsPolicy: ClusterFirstWithHostNet
  reportNodeInternalIp: false
  watchIngressWithoutClass: false
  ingressClassByName: false
  enableTopologyAwareRouting: false
  allowSnippetAnnotations: false
  hostNetwork: true
  hostPort:
    enabled: false
    ports:
      http: 80
      https: 443
  networkPolicy:
    enabled: false
  electionID: ""
  ingressClassResource:
    name: nginx
    enabled: true
    default: false
    controllerValue: "k8s.io/ingress-nginx"
    parameters: {}
  ingressClass: nginx
  podLabels: {}
  podSecurityContext: {}
  sysctls: {}
  publishService:
    enabled: false
    pathOverride: ""
  scope:
    enabled: false
    namespace: ""
    namespaceSelector: ""
  configMapNamespace: ""
  tcp:
    configMapNamespace: ""
    annotations: {}
  udp:
    configMapNamespace: ""
    annotations: {}
  maxmindLicenseKey: ""
  extraArgs: {}
  extraEnvs: []
  kind: DaemonSet
  annotations: {}
  labels: {}
  updateStrategy: {}
  minReadySeconds: 0
  tolerations:
    - key: "node-role.kubernetes.io/master"
      operator: "Equal"
      value: "value"
      effect: "NoSchedule"
  affinity: {}
  topologySpreadConstraints: []
  terminationGracePeriodSeconds: 300
  nodeSelector:
    kubernetes.io/os: linux
    ingress: "true"
  livenessProbe:
    httpGet:
      path: "/healthz"
      port: 10254
      scheme: HTTP
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 5
  readinessProbe:
    httpGet:
      path: "/healthz"
      port: 10254
      scheme: HTTP
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 3
  healthCheckPath: "/healthz"
  healthCheckHost: ""
  podAnnotations: {}
  replicaCount: 1
  minAvailable: 1
  resources:
    requests:
      cpu: 100m
      memory: 90Mi
  autoscaling:
    enabled: false
    annotations: {}
    minReplicas: 1
    maxReplicas: 11
    targetCPUUtilizationPercentage: 50
    targetMemoryUtilizationPercentage: 50
    behavior: {}
  autoscalingTemplate: []
  keda:
    apiVersion: "keda.sh/v1alpha1"
    enabled: false
    minReplicas: 1
    maxReplicas: 11
    pollingInterval: 30
    cooldownPeriod: 300
    restoreToOriginalReplicaCount: false
    scaledObject:
      annotations: {}
    triggers: []
    behavior: {}
  enableMimalloc: true
  customTemplate:
    configMapName: ""
    configMapKey: ""
  service:
    enabled: false
    appProtocol: true
    annotations: {}
    labels: {}
    externalIPs: []
    loadBalancerIP: ""
    loadBalancerSourceRanges: []
    loadBalancerClass: ""
    enableHttp: true
    enableHttps: true
    ipFamilyPolicy: "SingleStack"
    ipFamilies:
      - IPv4
    ports:
      http: 80
      https: 443
    targetPorts:
      http: http
      https: https
    type: LoadBalancer
    nodePorts:
      http: ""
      https: ""
      tcp: {}
      udp: {}
    external:
      enabled: true
    internal:
      enabled: false
      annotations: {}
      loadBalancerIP: ""
      loadBalancerSourceRanges: []
      ports: {}
      targetPorts: {}
  shareProcessNamespace: false
  extraContainers: []
  extraVolumeMounts: []
  extraVolumes: []
  extraInitContainers: []
  extraModules: []
  opentelemetry:
    enabled: false
    image: registry.k8s.io/ingress-nginx/opentelemetry:v20230721-3e2062ee5@sha256:13bee3f5223883d3ca62fee7309ad02d22ec00ff0d7033e3e9aca7a9f60fd472
    containerSecurityContext:
      allowPrivilegeEscalation: false
    resources: {}
  admissionWebhooks:
    enabled: true
    annotations: {}
    enabled: true
    extraEnvs: []
    failurePolicy: Fail
    port: 8443
    certificate: "/usr/local/certificates/cert"
    key: "/usr/local/certificates/key"
    namespaceSelector: {}
    objectSelector: {}
    labels: {}
    existingPsp: ""
    service:
      annotations: {}
      externalIPs: []
      loadBalancerSourceRanges: []
      servicePort: 443
      type: ClusterIP
    createSecretJob:
      securityContext:
        allowPrivilegeEscalation: false
      resources: {}
    patchWebhookJob:
      securityContext:
        allowPrivilegeEscalation: false
      resources: {}
    patch:
      enabled: true
      image:
        registry: registry.k8s.io
        image: ingress-nginx/kube-webhook-certgen
        tag: v20231011-8b53cabe0
        digest: sha256:a7943503b45d552785aa3b5e457f169a5661fb94d82b8a3373bcd9ebaf9aac80
        pullPolicy: IfNotPresent
      priorityClassName: ""
      podAnnotations: {}
      nodeSelector:
        kubernetes.io/os: linux
      tolerations: []
      labels: {}
      securityContext:
        runAsNonRoot: true
        runAsUser: 2000
        fsGroup: 2000
    certManager:
      enabled: false
      rootCert:
        duration: ""
      admissionCert:
        duration: ""
  metrics:
    port: 10254
    portName: metrics
    enabled: false
    service:
      annotations: {}
      labels: {}
      externalIPs: []
      loadBalancerSourceRanges: []
      servicePort: 10254
      type: ClusterIP
    serviceMonitor:
      enabled: false
      additionalLabels: {}
      namespace: ""
      namespaceSelector: {}
      scrapeInterval: 30s
      targetLabels: []
      relabelings: []
      metricRelabelings: []
    prometheusRule:
      enabled: false
      additionalLabels: {}
      rules: []
  lifecycle:
    preStop:
      exec:
        command:
          - /wait-shutdown
  priorityClassName: ""
revisionHistoryLimit: 10
defaultBackend:
  enabled: false
  name: defaultbackend
  image:
    registry: registry.k8s.io
    image: defaultbackend-amd64
    tag: "1.5"
    pullPolicy: IfNotPresent
    runAsUser: 65534
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
  existingPsp: ""
  extraArgs: {}
  serviceAccount:
    create: true
    name: ""
    automountServiceAccountToken: true
  extraEnvs: []
  port: 8080
  livenessProbe:
    failureThreshold: 3
    initialDelaySeconds: 30
    periodSeconds: 10
    successThreshold: 1
    timeoutSeconds: 5
  readinessProbe:
    failureThreshold: 6
    initialDelaySeconds: 0
    periodSeconds: 5
    successThreshold: 1
    timeoutSeconds: 5
  updateStrategy: {}
  minReadySeconds: 0
  tolerations: []
  affinity: {}
  podSecurityContext: {}
  containerSecurityContext: {}
  podLabels: {}
  nodeSelector:
    kubernetes.io/os: linux
  podAnnotations: {}
  replicaCount: 1
  minAvailable: 1
  resources: {}
  extraVolumeMounts: []
  extraVolumes: []
  autoscaling:
    annotations: {}
    enabled: false
    minReplicas: 1
    maxReplicas: 2
    targetCPUUtilizationPercentage: 50
    targetMemoryUtilizationPercentage: 50
  networkPolicy:
    enabled: false
  service:
    annotations: {}
    externalIPs: []
    loadBalancerSourceRanges: []
    servicePort: 80
    type: ClusterIP
  priorityClassName: ""
  labels: {}
rbac:
  create: true
  scope: false
podSecurityPolicy:
  enabled: false
serviceAccount:
  create: true
  name: ""
  automountServiceAccountToken: true
  annotations: {}
imagePullSecrets: []
tcp: {}
udp: {}
portNamePrefix: ""
dhParam: ""
```

```sh
# 打标签
# 查看刚刚构建的ingress
[root@k8s-master01 ingress-nginx]# kubectl get  pod -n ingress-nginx 

# ingress扩容与缩容，只需要给想要扩容的节点加标签就行，缩容就把节点标签去除即可
[root@k8s-master01 ~]# kubectl label node k8s-master02 ingress=true
node/k8s-master02 labeled

[root@k8s-master01 ~]# kubectl label node k8s-master03 ingress-
node/k8s-master03 labeled
```



### 三、卸载

```sh
helm delete ingress-nginx -n ingress-nginx
```


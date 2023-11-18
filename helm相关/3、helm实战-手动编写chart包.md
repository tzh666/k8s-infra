## 编写Chart部署RabibtMQ

### 一、创建一个Chart

```sh
helm create rabbitmq-cluster && cd rabbitmq-cluster/

# 查看目录结构，都是熟悉的吧
[root@k8s-master01 rabbitmq-cluster]# tree .
.
├── charts
├── Chart.yaml
├── templates
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── serviceaccount.yaml
│   ├── service.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml
```



### 二、文件清理、准备

```sh
# 1、文件清理
cd templates/
rm -rf deployment.yaml hpa.yaml ingress.yaml serviceaccount.yaml service.yaml tests
[root@k8s-master01 templates]# tree .
.
├── _helpers.tpl
└── NOTES.txt

# 2、copy 文件，讲之前部署的集群mq的配置文件搬过来【在git上有存】
cp /app/infra/rabbitmq/集群/*.yaml .
```



### 二、开始修改value.yaml文件

- 改一个变量，就去对应模板中更改即可，一步步编排就行了
- 然后改一点，测试部署一点，出问题方便排查

```yaml
helm install rmb-cluster  . -n infra --dry-run
```



```sh
# 部署
[root@k8s-master01 rabbitmq-cluster]# helm install rmb-cluster  . -n infra
NAME: rmb-cluster
LAST DEPLOYED: Sun Oct 23 22:05:07 2022
NAMESPACE: infra
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
牛逼

# 卸载
 helm uninstall rmb-cluster  -n infra
 
 # 查看部署
 [root@k8s-master01 rabbitmq-cluster]# kubectl get po -n infra -l app.kubernetes.io/name=rabbitmq-cluster
NAME            READY   STATUS              RESTARTS   AGE
rmb-cluster-0   1/1     Running             0          4m14s
rmb-cluster-1   1/1     Running             0          2m35s
rmb-cluster-2   0/1     Running             0          38s
```
























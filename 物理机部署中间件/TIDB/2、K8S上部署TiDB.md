## Kubernetes 上的 TiDB 集群

### 一、k8s环境准备

- 略

### 二、k8s上部署TiDB

#### 2.1、部署StorageClass-nfs方案

- sc种类很多，模拟的话此处就有较为简单的nfs类型的sc

```sh
# nfs部署方案
https://www.cnblogs.com/hsyw/p/13610960.html

# nfs类型的sc部署方案
https://github.com/tzh666/k8s-infra/tree/main/StorageClass/NFS
```

#### 2.2、SC

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tidb-sc
provisioner: fuseim.pri/ifs
parameters:
  archiveOnDelete: "false"   # 设置为"false"时删除PVC不会保留数据,"true"则保留数据
```



#### 2.3、部署helm

Kubernetes 应用在 Helm 中被打包为 chart。PingCAP 针对 Kubernetes 上的 TiDB 部署运维提供了多个 Helm chart：

- `tidb-operator`：用于部署 TiDB Operator；
- `tidb-cluster`：用于部署 TiDB 集群；
- `tidb-backup`：用于 TiDB 集群备份恢复；
- `tidb-lightning`：用于 TiDB 集群导入数据；
- `tidb-drainer`：用于部署 TiDB Drainer；
- `tikv-importer`：用于部署 TiKV Importer；

```sh
# 1、下载
[root@k8s-master01 ~]# wget https://get.helm.sh/helm-v3.4.2-linux-amd64.tar.gz

# 2、安装
[root@k8s-master01 ~]# tar -zxvf helm-v3.4.2-linux-amd64.tar.gz 
[root@k8s-master01 ~]# mv linux-amd64/helm /usr/local/bin/helm

# 3、使用添加helmPingCAP的提供的 chart
helm repo add pingcap https://charts.pingcap.org/

# 4、查看是否添加成功
[root@k8s-master01 infra]# helm repo list
NAME            URL                                       
pingcap         https://charts.pingcap.org/

# 5、添加完成后，可以使用 helm search 搜索 PingCAP 提供的 chart：
[root@k8s-master01 infra]# helm search repo pingcap
NAME                    CHART VERSION   APP VERSION     DESCRIPTION                            
pingcap/diag            v1.1.0          v1.1.0          clinic diag Helm chart for Kubernetes  
pingcap/tidb-backup     v1.3.9                          A Helm chart for TiDB Backup or Restore
pingcap/tidb-cluster    v1.3.9                          A Helm chart for TiDB Cluster          
pingcap/tidb-drainer    v1.3.9                          A Helm chart for TiDB Binlog drainer.  
pingcap/tidb-lightning  v1.3.9                          A Helm chart for TiDB Lightning        
pingcap/tidb-operator   v1.3.9          v1.3.9          tidb-operator Helm chart for Kubernetes
pingcap/tikv-importer   v1.3.9                          A Helm chart for TiKV Importer         
pingcap/tikv-operator   v0.1.0          v0.1.0          A Helm chart for Kubernetes           
```

#### 2.4、部署TiDB Operator

- 注意
  - 对于 Kubernetes 1.16 之前的版本，Kubernetes 仅支持 v1beta1 版本的 CRD，你需要将上述命令中的 `crd.yaml` 修改为 `crd_v1beta1.yaml`

```sh
# 1、下载配置文件
wget https://raw.githubusercontent.com/pingcap/tidb-operator/v1.3.9/manifests/crd.yaml
[root@k8s-master01 tidb]# kubectl create -f ./crd.yaml
customresourcedefinition.apiextensions.k8s.io/backupschedules.pingcap.com created
customresourcedefinition.apiextensions.k8s.io/backups.pingcap.com created
customresourcedefinition.apiextensions.k8s.io/dmclusters.pingcap.com created
customresourcedefinition.apiextensions.k8s.io/restores.pingcap.com created
customresourcedefinition.apiextensions.k8s.io/tidbclusterautoscalers.pingcap.com created
customresourcedefinition.apiextensions.k8s.io/tidbclusters.pingcap.com created
customresourcedefinition.apiextensions.k8s.io/tidbinitializers.pingcap.com created
customresourcedefinition.apiextensions.k8s.io/tidbmonitors.pingcap.com created
customresourcedefinition.apiextensions.k8s.io/tidbngmonitorings.pingcap.com created

# 如果显示如下信息表示 CRD 安装成功：
kubectl get crd
NAME                                 CREATED AT
backups.pingcap.com                  2020-06-11T07:59:40Z
backupschedules.pingcap.com          2020-06-11T07:59:41Z
restores.pingcap.com                 2020-06-11T07:59:40Z
tidbclusterautoscalers.pingcap.com   2020-06-11T07:59:42Z
tidbclusters.pingcap.com             2020-06-11T07:59:38Z
tidbinitializers.pingcap.com         2020-06-11T07:59:42Z
tidbmonitors.pingcap.com             2020-06-11T07:59:41Z

# 2、创建命名空间
kubectl create namespace tidb-admin

# 3、安装 TiDB Operator
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.3.9 \
    --set operatorImage=registry.cn-beijing.aliyuncs.com/tidb/tidb-operator:v1.3.9 \
    --set tidbBackupManagerImage=registry.cn-beijing.aliyuncs.com/tidb/tidb-backup-manager:v1.3.9 \
    --set scheduler.kubeSchedulerImageName=registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler

NAME: tidb-operator
LAST DEPLOYED: Sat Oct 15 17:11:22 2022
NAMESPACE: tidb-admin
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Make sure tidb-operator components are running:

    kubectl get pods --namespace tidb-admin -l app.kubernetes.io/instance=tidb-operator
# 4、查看部署结果
[root@k8s-master01 tidb]# kubectl get pods --namespace tidb-admin -l app.kubernetes.io/instance=tidb-operator
NAME                                       READY   STATUS    RESTARTS   AGE
tidb-controller-manager-7cf8b6f894-lhqms   1/1     Running   0          4m58s
tidb-scheduler-585fd9f8f-4rm65             2/2     Running   0          4m58s
```

#### 2.5、安装TiDB集群

- 需要改StorageClass名字，改成上门自己创建的名字
- PV 一般由系统管理员或 volume provisioner 自动创建，PV 与 Pod 是通过 [PersistentVolumeClaim (PVC)](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims) 进行关联的
- 普通用户在使用 PV 时并不需要直接创建 PV，而是通过 PVC 来申请使用 PV，对应的 volume provisioner 根据 PVC 创建符合要求的 PV，并将 PVC 与该 PV 进行绑定
- 这玩意不合适在生产上使用，需要修改配置后才能上生产，例如修改调度、存储大小、副本个数等

```sh
wget https://raw.githubusercontent.com/pingcap/tidb-operator/master/examples/basic/tidb-cluster.yaml

kubectl create namespace tidb-cluster && kubectl apply  -n  tidb-cluster -f tidb-cluster.yaml

# 如果访问 Docker Hub 网速较慢，可以使用 UCloud 上的镜像：
kubectl create namespace tidb-cluster && \
    kubectl -n tidb-cluster apply -f https://raw.githubusercontent.com/pingcap/tidb-operator/master/examples/basic-cn/tidb-cluster.yaml
```

#### 2.6、部署 TiDB 集群监控

```sh
# 如果访问 Docker Hub 网速较慢，可以使用 UCloud 上的镜像：
kubectl -n tidb-cluster apply -f https://raw.githubusercontent.com/pingcap/tidb-operator/master/examples/basic-cn/tidb-monitor.yaml
```

#### 2.7、查看 Pod 状态

```sh
watch kubectl get po -n tidb-cluster
```

参考官网：

```sh
https://docs.pingcap.com/zh/tidb-in-kubernetes/stable/prerequisites

https://docs.pingcap.com/zh/tidb-in-kubernetes/stable/get-started#%E7%AC%AC-2-%E6%AD%A5%E9%83%A8%E7%BD%B2-tidb-operator
```

### 
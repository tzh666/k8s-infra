## Helm仓库搭建

### 一、前提条件

```sh
https://helm.sh/zh/docs/intro/quickstart/
```

- 如何使用阿里Helm私有仓库

  - ```sh
    https://help.aliyun.com/document_detail/131467.html
    ```



### 二、Helm仓库搭建

- 私有Helm仓库搭建可以用nginx作为后端存储挂载，也可以采用minio当后端存储挂载

  - ```sh
    # minio参考
    https://www.cnblogs.com/infodriven/p/16308475.html
    
    # 本文参考
    https://www.cnblogs.com/huningfei/p/12705114.html
    ```

#### 2.1、用nginx做私有仓库

- 在网站根目录创建一个charts目录，专门存放helm打包的压缩包

```sh
[root@k8s-master01 ~]# mkdir -p /app/k8s/helm/charts
[root@k8s-master01 ~]# docker run -d --name=nginx -p 80:80  -v /app/k8s/helm/charts:/usr/share/nginx/html/charts nginx

# 查看nginx是否启动成功
[root@k8s-master01 ~]# docker ps  | grep nginx
e840097e9874   nginx                                                                 "/docker-entrypoint.…"   About a minute ago   Up About a minute   0.0.0.0:80->80/tcp, :::80->80/tcp   nginx
```

- 打包package

```sh
# 创建chart
[root@k8s-master01 helm]# helm create mychart
Creating mychart

# 打包chart
[root@k8s-master01 helm]# helm package mychart
Successfully packaged chart and saved it to: /root/helm/mychart-0.1.0.tgz
```

- 执行helm repo index生成库的index文件

```sh
[root@k8s-master01 helm]# mkdir myrepo
[root@k8s-master01 helm]# mv mychart-0.1.0.tgz myrepo/

# 生成index.yaml
[root@k8s-master01 helm]# helm repo index myrepo/ --url http://192.168.1.110/charts

# 查看是否生成
[root@k8s-master01 helm]# ls myrepo
index.yaml  mychart-0.1.0.tgz  
```

- 将生成的index.yaml文件及charts包复制到nginx的charts目录下面

```sh
[root@k8s-master01 helm]# cp myrepo/* /app/k8s/helm/charts/
[root@k8s-master01 helm]# ls /app/k8s/helm/charts/
index.yaml  mychart-0.1.0.tgz
```

- 通过helm repo add 将新仓库添加到helm

```sh
[root@k8s-master01 helm]# helm repo add newrepo http://192.168.1.110/charts
"newrepo" has been added to your repositories

[root@k8s-master01 helm]# helm repo list
NAME         	URL                                         
newrepo      	http://192.168.1.110/charts       

# 查看
[root@k8s-master01 helm]# helm search repo mychart
NAME           	CHART VERSION	APP VERSION	DESCRIPTION                
newrepo/mychart	0.1.0        	1.16.0     	A Helm chart for Kubernetes
```

- 从新的私有库中安装mychart进行测试

```sh
[root@k8s-master01 ~]# helm install repo newrepo/mychart
NAME: repo
LAST DEPLOYED: Wed Oct 19 16:30:25 2022
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=mychart,app.kubernetes.io/instance=repo" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace default port-forward $POD_NAME 8080:80
  
# 查看部署结果
[root@k8s-master01 ~]# kubectl get pods --namespace default -l "app.kubernetes.io/name=mychart,app.kubernetes.io/instance=repo"
NAME                            READY   STATUS    RESTARTS   AGE
repo-mychart-6579bfdb8d-msrkc   1/1     Running   0          42s
```



### 二 上传到阿里的私有仓库

- 如合开通自己的私有仓库：

https://help.aliyun.com/document_detail/131467.html

- 添加Helm仓库

```bash
export NAMESPACE=127854-hnf;helm repo add $NAMESPACE https://repomanage.rdc.aliyun.com/helm_repositories/$NAMESPACE --username=YhgrHd --password=gvM3C8cuEc
```

- 发布Chart

```perl
# 安装Helm Push插件
$ helm plugin install https://github.com/chartmuseum/helm-push

#注意，如果一直下着不下来，可以去浏览器下载，然后解压安装
helm plugin install helm-push-master
```

- 发布chart

```makefile
$ cat mychart/Chart.yaml 
name: mychart 
version: 0.3.2
helm push mychart/ $NAMESPACE
```

- 发布Chart压缩包

```perl
 helm package mychart
 helm push mychart-0.3.2.tgz $NAMESPACE
```

- 更新本地索引

```sql
 helm repo update
```

- 搜索

```bash
helm search repo $NAMESPACE/mychart
```

- 安装 

```bash
helm install my-nginx $NAMESPACE/mychart
```
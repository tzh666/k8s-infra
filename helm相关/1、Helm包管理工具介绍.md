## Helm包管理工具介绍

### 一、Helm安装

- 版本选择：https://github.com/helm/helm/releases

```sh
# 1、下载
[root@k8s-master01 ~]# wget https://get.helm.sh/helm-v3.4.2-linux-amd64.tar.gz

# 2、安装
[root@k8s-master01 ~]# tar -zxvf helm-v3.4.2-linux-amd64.tar.gz 
[root@k8s-master01 ~]# mv linux-amd64/helm /usr/local/bin/helm

# 3、验证：能执行命令即可, 例如添加仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
```



### 二、Helm一些概念

#### 2.1、三大概念

- ***Chart* 代表着 Helm 包。它包含在 Kubernetes 集群内部运行应用程序，工具或服务所需的所有资源定义**。你可以把它看作是 Homebrew formula，Apt dpkg，或 Yum RPM 在Kubernetes 中的等价物
- ***Repository（仓库）* 是用来存放和共享 charts 的地方**，类似于docker 仓库
- ***Release* 是运行在 Kubernetes 集群中的 chart 的实例**。一个 chart 通常可以在同一个集群中安装多次。每一次安装都会创建一个新的 *release*。以 MySQL chart为例，如果你想在你的集群中运行两个数据库，你可以安装该chart两次。每一个数据库都会拥有它自己的 *release* 和 *release name*

### 2.2、那什么是helm呢？

- Helm 安装 *charts* 到 Kubernetes 集群中，每次安装都会创建一个新的 *release*。你可以在 Helm 的 chart *repositories* 中寻找新的 chart



### 三、常用的Helm命令

- **添加chart仓库**

```sh
$ helm repo add bitnami https://charts.bitnami.com/bitnami
```

- **查看安装的charts列表**

```sh
$ helm search repo bitnami
NAME                             	CHART VERSION	APP VERSION  	DESCRIPTION
bitnami/bitnami-common           	0.0.9        	0.0.9        	DEPRECATED Chart with custom templates used in ...
bitnami/airflow                  	8.0.2        	2.0.0        	Apache Airflow is a platform to programmaticall...
bitnami/apache                   	8.2.3        	2.4.46       	Chart for Apache HTTP Server
bitnami/aspnet-core              	1.2.3        	3.1.9        	ASP.NET Core is an open-source framework create...
# ... and many more
```

- **安装Chart示例**

```sh
$ helm repo update              # 确定我们可以拿到最新的charts列表
$ helm install bitnami/mysql --generate-name
NAME: mysql-1612624192          # bitnami/mysql这个chart被发布，名字是 mysql-1612624192
LAST DEPLOYED: Sat Feb  6 16:09:56 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES: ...
```

- **查看chart的基本信息**

```sh
helm show chart bitnami/mysql
```

- **查看chart的所有信息**

```sh
helm show all bitnami/mysql
```

- **查看所有可被部署的版本**

```sh
helm list

helm ls
```

- **卸载一个版本**
  - 该命令会从Kubernetes卸载 `mysql-1612624192`， 它将删除和该版本相关的所有相关资源（service、deployment、 pod等等）甚至版本历史

```sh
helm uninstall mysql-1612624192  # mysql-1612624192  bitnami/mysql这个chart被发布，名字是 mysql-1612624192
```



### 四、Helm目录层级

```sh
# 创建一个Chart：
helm create helm-test
├── charts # 依赖文件
├── Chart.yaml # 当前chart的基本信息
apiVersion：Chart的apiVersion，目前默认都是v2
name：Chart的名称
type：图表的类型[可选]
version：Chart自己的版本号
appVersion：Chart内应用的版本号[可选]
description：Chart描述信息[可选]
├── templates # 模板位置
│ ├── deployment.yaml
│ ├── _helpers.tpl # 自定义的模板或者函数
│ ├── ingress.yaml
│ ├── NOTES.txt #Chart安装完毕后的提醒信息
│ ├── serviceaccount.yaml
│ ├── service.yaml
│ └── tests # 测试文件
│ └── test-connection.yaml
└── values.yaml #配置全局变量或者一些参数
```



### 五、Helm内置变量

```sh
◆ Release.Name: 实例的名称，helm install指定的名字

◆ Release.Namespace: 应用实例的命名空间

◆ Release.IsUpgrade: 如果当前对实例的操作是更新或者回
滚，这个变量的值就会被置为true

◆ Release.IsInstall: 如果当前对实例的操作是安装，则这边
变量被置为true

◆ Release.Revision: 此次修订的版本号，从1开始，每次升
级回滚都会增加1

◆ Chart: Chart.yaml文件中的内容，可以使用Chart.Version表
示应用版本，Chart.Name表示Chart的名称
```



### 六、Helm常见函数

http://masterminds.github.io/sprig/strings.html



### 七、Helm流程控制

https://helm.sh/docs/chart_template_guide/control_structures/

除了这些之外，还提供了一些声明和使用命名模板的关键字：

- `define` 在模板中声明一个新的命名模板
- `template` 导入一个命名模板
- `block` 声明一种特殊的可填充的模板块

#### 7.1、If/Else，用来创建条件语句

- "-" 加这个符号是删除新空白行

```sh
{{- if PIPELINE }}
  # Do something
{{- else if OTHER PIPELINE }}
  # Do something else
{{- else }}
  # Default case
{{- end -}}
```

#### 7.2、with，修改使用`with`的范围

- 作用是重复的字段不需要一直写，用with即可

```sh
{{ with PIPELINE }}
  # restricted scope
{{ end }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- with .Values.favorite }}                     # 直接进入到 .Values.favorite层
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  {{- end }}
```

#### 7.3、range， 提供"for each"类型的循环

```sh
values.yaml

# 一个是字典、一个是切片
favorite:
  drink: coffee
  food: pizza
pizzaToppings:
  - mushrooms
  - cheese
  - peppers
  - onions
  
---
# range
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myvalue: "Hello World"
  {{- with .Values.favorite }}
  drink: {{ .drink | default "tea" | quote }}
  food: {{ .food | upper | quote }}
  {{- end }}
  toppings: |-
    {{- range .Values.pizzaToppings }}
    - {{ . | title | quote }}
    {{- end }}    
```


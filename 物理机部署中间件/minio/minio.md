minio 高性能 Kubernetes 原生对象存储

- minio 高性能 Kubernetes 原生

  对象存储

  - 特点
  - 安装
    - 单机
    - 分布式
  - 客户端mc安装和使用
  - minio在K8S的优化实践

>  MinIO 是一个基于Apache License v2.0开源协议的对象存储服务。它兼容亚马逊S3云存储服务接口，非常适合于存储大容量非结构化的数据，例如图片、视频、日志文件、备份数据和容器/虚拟机镜像等，而一个对象文件可以是任意大小，从几kb到最大5T不等。      MinIO是一个非常轻量的服务,可以很简单的和其他应用的结合，类似 NodeJS, [Redis](https://cloud.tencent.com/product/crs?from=10680) 或者 MySQL。      

### 特点

- 高性能 minio是世界上最快的对象存储(官网说的: https://min.io/)     
- 弹性扩容 很方便对集群进行弹性扩容     
- 天生的云原生服务     
- 开源免费,最适合企业化定制     
- S3事实标准     
- 简单强大     
- 存储机制(Minio使用纠删码erasure code和校验和checksum来保护数据免受硬件故障和无声数据损坏。 即便丢失一半数量（N/2）的硬盘，仍然可以恢复数据)     

### 安装

>  minio分服务端和客户端,服务端是通过minio进行部署,客户端只是1个二进制命令(mc),通过mc可以操作对象存储(增删查等),当然minio也提供各种语言的SDK,具体可以参考[官网](https://docs.min.io/)  

服务端的安装分为独立单机模式和分布式安装,  以下单机模式的安装方法. 分布式的安装和单机模式的安装类似,只是根据传参不同     

#### 单机

- Docker容器安装      docker pull minio/minio      docker run -p 9000:9000 minio/minio server /data     
- macOS      brew install minio/stable/minio      minio server /data     
- Linux      wget https://dl.min.io/server/minio/release/linux-amd64/minio      chmod +x minio      ./minio server /data     
- Windows      wget https://dl.min.io/server/minio/release/windows-amd64/minio.exe      minio.exe server D:\Photos     

#### 分布式

**分布式好处** 分布式Minio可以让你将多块硬盘（甚至在不同的机器上）组成一个对象存储服务。由于硬盘分布在不同的节点上，分布式Minio避免了单点故障     

**数据保护** 分布式Minio采用 纠删码来防范多个节点宕机和位衰减bit rot。 分布式Minio至少需要4个硬盘，使用分布式Minio自动引入了纠删码功能。     

**高可用** 单机Minio服务存在单点故障，相反，如果是一个有N块硬盘的分布式Minio,只要有N/2硬盘在线，你的数据就是安全的。不过你需要至少有N/2+1个硬盘来创建新的对象。 例如，一个16节点的Minio集群，每个节点16块硬盘，就算8台服務器宕机，这个集群仍然是可读的，不过你需要9台服務器才能写数据。 注意，只要遵守分布式Minio的限制，你可以组合不同的节点和每个节点几块硬盘。比如，你可以使用2个节点，每个节点4块硬盘，也可以使用4个节点，每个节点两块硬盘，诸如此类。     

**一致性** Minio在分布式和单机模式下，所有读写操作都严格遵守read-after-write一致性模型。     

**纠删码** Minio使用纠删码erasure code和校验和checksum来保护数据免受硬件故障和无声数据损坏。 即便您丢失一半数量（N/2）的硬盘，您仍然可以恢复数据。  

**什么是纠删码erasure code?** 纠删码是一种恢复丢失和损坏数据的数学算法， Minio采用Reed-Solomon code将对象拆分成N/2数据和N/2 奇偶校验块。 这就意味着如果是12块盘，一个对象会被分成6个数据块、6个奇偶校验块，你可以丢失任意6块盘（不管其是存放的数据块还是奇偶校验块），你仍可以从剩下的盘中的数据进行恢复，是不是很NB，感兴趣的同学请google。 

**为什么纠删码有用?** 纠删码的工作原理和RAID或者复制不同，像RAID6可以在损失两块盘的情况下不丢数据，而Minio纠删码可以在丢失一半的盘的情况下，仍可以保证[数据安全](https://cloud.tencent.com/solution/data_protection?from=10680)。 而且Minio纠删码是作用在对象级别，可以一次恢复一个对象，而RAID是作用在卷级别，数据恢复时间很长。 Minio对每个对象单独编码，存储服务一经部署，通常情况下是不需要更换硬盘或者修复。Minio纠删码的设计目标是为了性能和尽可能的使用硬件加速。     

**什么是位衰减bit rot保护?** 位衰减又被称为数据腐化Data Rot、无声数据损坏Silent Data Corruption,是目前硬盘数据的一种严重数据丢失问题。硬盘上的数据可能会神不知鬼不觉就损坏了，也没有什么错误日志。正所谓明枪易躲，暗箭难防，这种背地里犯的错比硬盘直接咔咔宕了还危险。 不过不用怕，Minio纠删码采用了高速 HighwayHash 基于哈希的校验和来防范位衰减。     

**分布式部署:GNU/Linux 和 macOS** 示例1: 启动分布式Minio实例，8个节点，每节点1块盘，需要在8个节点上都运行下面的命令。     

```javascript
export MINIO_ACCESS_KEY=<ACCESS_KEY>     
export MINIO_SECRET_KEY=<SECRET_KEY>     
minio server http://192.168.1.11/export1 http://192.168.1.12/export2 \     
               http://192.168.1.13/export3 http://192.168.1.14/export4 \     
               http://192.168.1.15/export5 http://192.168.1.16/export6 \     
               http://192.168.1.17/export7 http://192.168.1.18/export8     
```

![image-20211128231602569](G:\陶振欢的组件笔记\minio\minio.assets\image-20211128231602569.png)**分布式部署:kebernetes** 

```javascript
#helm安装自行google     
helm install minio --set mode=distributed,numberOfNodes=4,imagePullPolicy=IfNotPresent,accessKey=v9rwqYzXXim6KJKeyPm344,secretKey=0aIRBu9KU7gAN0luoX8uBE1eKWNPDgMnkVqbPC,service.type=NodePort,service.nodePort=25557 googleapis/minio -n velero     

#安装完成之后查询pods状态,如果pods的READY状态是正常的,则安装成功,如下图图示     
kubectl get pods -n velero -o wide     

#如果pods的READY状态一直不是状态的话,查看下logs     
kubectl logs minio-0 -n velero     

#如果都是提示disk都是等待状态,可以重启pods在查看     
kubectl delete pods -n velero minio-{0,1,2,3} 

#默认是cluser访问,为了方便,我这里是nodeport方式     
```

![img](https://ask.qcloudimg.com/http-save/yehe-1240192/tab2q29b6d.png?imageView2/2/w/1620)

![img](https://ask.qcloudimg.com/http-save/yehe-1240192/9ylsd2lckp.png?imageView2/2/w/1620)

如上图,当我使用4个节点创建分布式minio时,会使用默认的pvc创建存储.默认每个节点创建1个10G的存储(可以自定义修改)     

### 客户端mc安装和使用

**安装** 

```javascript
wget https://dl.min.io/client/mc/release/linux-amd64/mc     
chmod +x mc     
./mc --help     
```

**mc命令指南** 

```javascript
ls       列出文件和文件夹。     
mb       创建一个存储桶或一个文件夹。     
cat      显示文件和对象内容。     
pipe     将一个STDIN重定向到一个对象或者文件或者STDOUT。     
share    生成用于共享的URL。     
cp       拷贝文件和对象。     
mirror   给存储桶和文件夹做镜像。     
find     基于参数查找文件。     
diff     对两个文件夹或者存储桶比较差异。     
rm       删除文件和对象。     
events   管理对象通知。     
watch    监听文件和对象的事件。     
policy   管理访问策略。     
session  为cp命令管理保存的会话。     
config   管理mc配置文件。     
update   检查软件更新。     
version  输出版本信息。     
```

**mc命令实践** 

```javascript
#查看minio服务端配置     
mc config host ls     

#添加minio服务端配置     
mc config host add minio  http://minio.vaicheche.com:25555  v9rwqYzXXim6KJKeyPm344 0aIRBu9KU7gAN0luoX8uBE1eKWNPDgMnkVqbPC --api s3v4     

#查看minio bucket     
mc ls minio     

#创建bucket     
mc mb minio/backup     

#上传本地目录(文件不加r)     
mc cp -r  ingress minio/backup/     

#下载远程目录(文件不加r)     
mc cp -r  minio/backup .     

#将一个本地文件夹镜像到minio(类似rsync)      
mc mirror localdir/ minio/backup/     

#持续监听本地文件夹镜像到minio(类似rsync)      
mc mirror -w localdir/ minio/backup/     

#持续从minio存储桶中查找所有jpeg图像，并复制到minio "play/bucket"存储桶     
mc find minio/bucket --name "*.jpg" --watch --exec "mc cp {} play/bucket"     

#删除目录     
mc rm minio/backup/ingress  --recursive --force     

#删除文件     
mc rm minio/backup/service_minio.yaml     

#从mybucket里删除所有未完整上传的对象     
mc rm  --incomplete --recursive --force play/mybucket     

#删除7天前的对象     
mc rm --force --older-than=7 play/mybucket/oldsongs     

#将MySQL数据库dump文件输出到minio     
mysqldump -u root -p ******* db | mc pipe minio/backups/backup.sql     

#mongodb备份     
mongodump -h mongo-server1 -p 27017 -d blog-data --archive | mc pipe minio1/mongobkp/backups/mongo-blog-data-`date +%Y-%m-%d`.archive     
```

### minio在K8S的优化实践

如上minio在k8s的实践,在我实践环境里面.我通过helm安装分布式之后,我默认是采用nfs作为storeagesclasses,一共起了4个节点,自动创建了4个pvc,在我删除1个pvc的数据之后,minio依然可以正常读写,数据依然的可以存在.参考下图 

![img](G:\陶振欢的组件笔记\minio\minio.assets\image-20211128231637653.png)

![image-20211128231706807](G:\陶振欢的组件笔记\minio\minio.assets\image-20211128231706807.png)

但这其中有1个最大的问题, 如果你使用的是nfs这种自建共享存储的话,就算minio起了4个节点,能保证数据安全.但是你的nfs磁盘确只有1个,万一的你的nfs宕机,磁盘损坏了,你的数据全都没有了.所以为了保证数据的安全性.建议通过`hostPath`的方式,在每个节点保存对应的数据.这样就算节点的宕机了,磁盘损坏了,你的数据并不会丢.而且通过本地节点的方式,读写数据的速度也会更快.当然你需要额外管理节点本地存储.     

**minio在K8S的`hostPath`部署实践** 

环境描述: 5个节点k8s环境,使用其中4个节点作为mino,同时都使用节点主机网络     

```javascript
#1.给其中4个节点打标签,因为我要选择标签为minio-server=true的节点部署minio     
kubectl get node --show-labels=true     
kubectl label nodes node-hostname1  minio-server=true     
kubectl label nodes node-hostname2  minio-server=true     
kubectl label nodes node-hostname3  minio-server=true     
kubectl label nodes node-hostname3  minio-server=true     

#2.给对应主机添加hosts,如果你的hostname能够自动解析,不用修改.4台主机都添加     
echo "host1 [IP1] >> /etc/hosts"     
echo "host2 [IP2] >> /etc/hosts"     
echo "host3 [IP3] >> /etc/hosts"     
echo "host4 [IP4] >> /etc/hosts"     

#3.创建namespace     
#你也可以使用自定义的其他namespace,不过你需要修改下面yaml文件     
kubectl create ns velero     

#4.下载headless、daemonset、service     
wget https://download.osichina.net/tools/k8s/yaml/minio/minio-distributed-headless-service.yaml     
wget https://download.osichina.net/tools/k8s/yaml/minio/minio-distributed-daemonset.yaml     
wget https://download.osichina.net/tools/k8s/yaml/minio/minio-distributed-service.yaml     

#5.修改并创建对应的service、daemonset     
其中主要修改的是`minio-distributed-daemonset.yaml`     
hostPath: 定义你需要使用节点本地路径     
MINIO_ACCESS_KEY、MINIO_SECRET_KEY: 定义你的秘钥,为了安全及时修改     
args: 启动参数后url改成主机名方式: http://host{1...4}/data/minio     

`minio-distributed-service.yaml`为对外服务,默认为ClusterIP,可以结合ingress或者nodePort来访问,可以自行修改     

kubectl create -f minio-distributed-statefulset.yaml      
kubectl create -f minio-distributed-daemonset.yaml     
kubectl create -f minio-distributed-service.yaml     
```
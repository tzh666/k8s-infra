## Containerd 高级命令行工具 nerdctl

### 一、安装nerdctl

```sh
# 在 GitHub Release 页面下载对应的压缩包解压到 PATH 路径下即可：

wget https://github.com/containerd/nerdctl/releases/download/v1.5.0/nerdctl-1.5.0-linux-amd64.tar.gz

mkdir -p /usr/local/containerd/bin/ && tar -zxvf nerdctl-1.5.0-linux-amd64.tar.gz nerdctl && mv nerdctl /usr/local/containerd/bin/

ln -s /usr/local/containerd/bin/nerdctl /usr/local/bin/nerdctl

# 验证 【有个告警说"buildctl": executable file not found in $PATH】我们再安装另一个buildctl
[root@k8s-master03 ~]# nerdctl version
WARN[0000] unable to determine buildctl version: exec: "buildctl": executable file not found in $PATH 
Client:
 Version:	v1.5.0
 OS/Arch:	linux/amd64
 Git commit:	b33a58f288bc42351404a016e694190b897cd252
 buildctl:
  Version:	

Server:
 containerd:
  Version:	1.6.22
  GitCommit:	8165feabfdfe38c65b599c4993d227328c231fca
 runc:
  Version:	1.1.8
  GitCommit:	v1.1.8-0-g82f18fe
```



### 二、安装buildctl

```sh
wget https://github.com/moby/buildkit/releases/download/v0.12.2/buildkit-v0.12.2.linux-amd64.tar.gz

mkdir -p /usr/local/buildctl -p && tar -zxvf buildkit-v0.12.2.linux-amd64.tar.gz -C /usr/local/buildctl

ln -s /usr/local/buildctl/bin/buildkitd /usr/local/bin/buildkitd
ln -s /usr/local/buildctl/bin/buildctl /usr/local/bin/buildctl

# 使用Systemd来管理buildkitd，创建如下所示的systemd unit文件
cat >> /etc/systemd/system/buildkit.service <<EOF
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit

[Service]
ExecStart=/usr/local/bin/buildkitd --oci-worker=false --containerd-worker=true

[Install]
WantedBy=multi-user.target
EOF

# 启动buildkitd
systemctl daemon-reload
systemctl enable buildkit --now
systemctl status buildkit

# 再次验证
[root@k8s-master03 bin]# nerdctl version  
Client:
 Version:	v1.5.0
 OS/Arch:	linux/amd64
 Git commit:	b33a58f288bc42351404a016e694190b897cd252
 buildctl:
  Version:	v0.12.2
  GitCommit:	567a99433ca23402d5e9b9f9124005d2e59b8861

Server:
 containerd:
  Version:	1.6.22
  GitCommit:	8165feabfdfe38c65b599c4993d227328c231fca
 runc:
  Version:	1.1.8
  GitCommit:	v1.1.8-0-g82f18fe
```



### 三、常用nerdctl命令

```sh
#nerdctl run :创建容器
nerdctl run -d -p 80:80 --name=nginx --restart=always nginx

#nerdctl exec :进入容器
nerdctl exec -it nginx /bin/sh

#nerdctl ps :列出容器
nerdctl ps -a

#nerdctl inspect :获取容器的详细信息 
nerdctl inspect nginx

#nerdctl logs :获取容器日志
nerdctl logs -f nginx

#nerdctl stop :停止容器
nerdctl stop nginx

#nerdctl rm :删除容器
nerdctl rm -f nginx
nerdctl rmi -f <IMAGE ID>

#nerdctl images：镜像列表
nerdctl images
nerdctl -n=k8s.io images
nerdctl -n=k8s.io images | grep -v '<none>'

#nerdctl pull :拉取镜像
nerdctl pull nginx

#使用 nerdctl login --username xxx --password xxx 进行登录，使用 nerdctl logout 可以注销退出登录
nerdctl login
nerdctl logout

#nerdctl tag :镜像标签
nerdctl tag nginx:latest harbor.k8s/image/nginx:latest

#nerdctl push :推送镜像
nerdctl push harbor.k8s/image/nginx:latest

#nerdctl save :导出镜像
nerdctl save -o busybox.tar.gz busybox:latest

#nerdctl load :导入镜像
nerdctl load -i busybox.tar.gz

#nerdctl rmi :删除镜像
nerdctl rmi busybox

#nerdctl build :从Dockerfile构建镜像
nerdctl build -t centos:v1.0 -f centos.dockerfile .

# 查看所有的名称空间
nerdctl namespace ls

# 查看某个名称空间下的镜像
nerdctl   -n   k8s.io  images

# 指定名称空间重新打tag
nerdctl --namespace k8s.io   tag    calico/cni:v3.19.1  docker.harbor.com/ops/cni:v3.19.1

# 设置nerdctl子命令可以使用tab键
vim /etc/profile
source <(nerdctl completion bash)
 
# 让其生效
source /etc/profile

# 打镜像
nerdctl build -t alpine:nerctl  --no-cache  -f Dockefile . 
```

参考：https://www.boysec.cn/boy/12ce5543.html



### 四、解决拉取自建harbor仓库自签https证书问题

- 域名改成签发证书的时候的

```sh
# 每个节点
mkdir /etc/containerd/certs.d/harbor.zlsd.com

[root@k8s-master01 harbor.zlsd.com]# cat hosts.toml 
server = "https://harbor.x.com"
[host."https://harbor.x.com"]
capabilities = ["pull", "resolve", "push"]
skip_verify = true

# 配置文件加上
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = ""

      [plugins."io.containerd.grpc.v1.cri".registry.auths] 
      # 认证配置
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.x.com".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.x.com".auth]
          username = "x"
          password = "x"
      [plugins."io.containerd.grpc.v1.cri".registry.headers]

      # 镜像加速地址
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://bqr1dr1n.mirror.aliyuncs.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.aliyuncs.com/k8sxio"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."harbor.zlsd.com"]
          endpoint = ["https://harbor.zlsd.com"]

systemctl restart containerd
```


## minio集群部署

### 一、Minio分布式部署的优势

#### 1.1 数据保护

- 分布式 Minio 采用纠删码来防范多个节点宕机和位衰减。
- 分布式 Minio 至少需要 4 个节点（4台服务器），使用分布式 Minio 就 自动引入了纠删码功能。
- 纠删码是一种恢复丢失和损坏数据的数学算法， Minio 采用 Reed-Solomon code 将对象拆分成 N/2 数据和 N/2 奇偶校验块。 这就意味着如果是 12 块盘，一个对象会被分成 6 个数据块、6 个奇偶校验块，你可以丢失任意 6 块盘（不管其是存放的数据块还是奇偶校验块），你仍可以从剩下的盘中的数据进行恢复。
- 纠删码的工作原理和 RAID 或者复制不同，像 RAID6 可以在损失两块盘的情况下不丢数据，而 Minio 纠删码可以在丢失一半的盘的情况下，仍可以保证数据安全。 而且 Minio 纠删码是作用在对象级别，可以一次恢复一个对象，而RAID 是作用在卷级别，数据恢复时间很长。 Minio 对每个对象单独编码，存储服务一经部署，通常情况下是不需要更换硬盘或者修复。Minio 纠删码的设计目标是为了性能和尽可能的使用硬件加速。
- 位衰减又被称为数据腐化 Data Rot、无声数据损坏 Silent Data Corruption ，是目前硬盘数据的一种严重数据丢失问题。硬盘上的数据可能会神不知鬼不觉就损坏了，也没有什么错误日志。正所谓明枪易躲，暗箭难防，这种背地里犯的错比硬盘直接故障还危险。 所以 Minio 纠删码采用了高速 HighwayHash 基于哈希的校验和来防范位衰减。

#### 1.2 高可用

- 单机 Minio 服务存在单点故障，相反，如果是一个 N 节点的分布式 Minio ,只要有 N/2 节点在线，你的数据就是安全的。不过你需要至少有 N/2+1 个节点来创建新的对象。
- 例如，一个 8 节点的 Minio 集群，每个节点一块盘，就算 4 个节点宕机，这个集群仍然是可读的，不过你需要 5 个节点才能写数据。

#### 1.3 限制

- 分布式 Minio 单租户存在最少 4 个盘最多 16 个盘的限制（受限于纠删码）。这种限制确保了 Minio 的简洁，同时仍拥有伸缩性。如果你需要搭建一个多租户环境，你可以轻松的使用编排工具（Kubernetes）来管理多个Minio实例。
- 注意，只要遵守分布式 Minio 的限制，你可以组合不同的节点和每个节点几块盘。比如，你可以使用 2 个节点，每个节点 4 块盘，也可以使用 4 个节点，每个节点两块盘，诸如此类。

#### 1.4 一致性

- Minio 在分布式和单机模式下，所有读写操作都严格遵守 read-after-write 一致性模型。



### 二、Minio分布式集群搭建

#### 2.1 环境准备

- 生产data1 data2  得挂2块不同的磁盘

| 节点          | 目录                             |
| ------------- | -------------------------------- |
| 192.168.1.106 | /{app1,app2}/minio/{data1,data2} |
| 192.168.1.107 | /{app1,app2}/minio/{data1,data2} |
| 192.168.1.108 | /{app1,app2}/minio/{data1,data2} |
| 192.168.1.109 | /{app1,app2}/minio/{data1,data2} |

#### 2.2、安装包下载

```sh
[root@minio1 ~]#  wget http://dl.minio.org.cn/server/minio/release/darwin-amd64/minio
[root@minio1 ~]#  chmod +x minio
```

#### 2.3、对应目录创建

- run：启动脚本及二进制文件目录；
- data：数据存储目录；
- conf：配置文件目录；

```sh
[root@minio1 ~]# mkdir /app/minio/{data1,run,conf} -p
[root@minio1 ~]# mv minio /app/minio/run/
```

#### 2.4、集群启动文件

- `MINIO_ACCESS_KEY`：用户名，长度最小是5个字符；
- `MINIO_SECRET_KEY`：密码，密码不能设置过于简单，不然minio会启动失败，长度最小是8个字符；
- `–config-dir`：指定集群配置文件目录；
- --console-address: 指定web端口（新版本需要指定，老版本应该是9000）

```sh
# 虚拟机搭建，此处我就整了一块盘
[root@minio1 ~]# vim /app/minio/run/run.sh
#!/bin/bash
export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=admin2021

/app/minio/run/minio server --console-address ":50000" --config-dir /app/minio/conf \
http://192.168.1.106/app/minio/data
http://192.168.1.107/app/minio/data
http://192.168.1.108/app/minio/data
http://192.168.1.109/app/minio/data

[root@minio1 run]# chmod +x run.sh 
```

```sh
# 生产可以4台机器8块盘，或者8台机器8块盘，成4的倍数
[root@minio1 ~]# vim /app/minio/run/run.sh
#!/bin/bash
export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=admin2021

/app/minio/run/minio server --console-address ":50000" --config-dir /app/minio/conf \
http://192.168.1.106/app1/minio/data1 http://192.168.1.106/app2/minio/data2 \
http://192.168.1.107/app1/minio/data1 http://192.168.1.107/app2/minio/data2 \
http://192.168.1.108/app1/minio/data1 http://192.168.1.108/app2/minio/data2 \
http://192.168.1.109/app1/minio/data1 http://192.168.1.109/app2/minio/data2 \

[root@minio1 run]# chmod +x run.sh 
```

#### 2.5、 配置为系统服务

```sh
[root@minio1 ~]# vim /usr/lib/systemd/system/minio.service
[Unit]
Description=Minio service
Documentation=https://docs.minio.io/

[Service]
WorkingDirectory=/app/minio/run/
ExecStart=/app/minio/run/run.sh

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**注意：**

- **将minio二进制文件上传到`/data/minio/run`目录！**

#### 2.6、 启动集群

```sh
systemctl daemon-reload && systemctl enable minio && systemctl start minio
```

### 2.7、集群状态查看

```sh\
[root@minio1 run]# systemctl status minio
● minio.service - Minio service
   Loaded: loaded (/usr/lib/systemd/system/minio.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2021-10-17 23:15:00 CST; 21min ago
     Docs: https://docs.minio.io/
 Main PID: 9738 (run.sh)
   CGroup: /system.slice/minio.service
           ├─9738 /bin/bash /app/minio/run/run.sh
           └─9739 /app/minio/run/minio server --console-address :50000 --config-dir /app/minio/conf http://192.168.1.106/app/minio/data http://192.168.1.107/app/minio/data http://192.16...

Oct 17 23:15:28 minio1 run.sh[9738]: Waiting for all MinIO sub-systems to be initialized.. lock acquired
Oct 17 23:15:28 minio1 run.sh[9738]: Waiting for all MinIO sub-systems to be initialized.. possible cause (Unable to initialize config system: Unable to load config file. S.../config.json)
Oct 17 23:15:30 minio1 run.sh[9738]: Waiting for all MinIO sub-systems to be initialized.. lock acquired
Oct 17 23:15:30 minio1 run.sh[9738]: Automatically configured API requests per node based on available memory on the system: 54
Oct 17 23:15:30 minio1 run.sh[9738]: All MinIO sub-systems initialized successfully
Oct 17 23:15:30 minio1 run.sh[9738]: Waiting for all MinIO IAM sub-system to be initialized.. lock acquired
Oct 17 23:15:30 minio1 run.sh[9738]: Status:         4 Online, 0 Offline.
Oct 17 23:15:30 minio1 run.sh[9738]: API: http://192.168.1.106:9000  http://127.0.0.1:9000
Oct 17 23:15:30 minio1 run.sh[9738]: Console: http://192.168.1.106:50000 http://127.0.0.1:50000
Oct 17 23:15:30 minio1 run.sh[9738]: Documentation: https://docs.min.io
```

#### 2.8、集群访问

- 因为当前是集群模式，所以访问任意节点都是一样的，所以，需要nginx代理集群

```sh
upstream minio.tzh{
        server 192.168.1.106:50000 weight=1;
        server 192.168.1.107:50000 weight=1;
        server 192.168.1.108:50000 weight=1;
        server 192.168.1.109:50000 weight=1;
    }
    server {
        listen 80;
        server_name minio.tzh;
        location / {
                proxy_pass http://minio.tzh;
                proxy_set_header Host $http_host;
                client_max_body_size 1000m;
        }
    }
```


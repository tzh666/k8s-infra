### 一、TiDB的由来

#### 1.1、时代基于，数据量爆炸性增长于数据库架构现状的矛盾

- 据IDC预测，2020年有超过500亿的终端与设备联网，而有50%的物联网网络将面临网络带宽的限制，40%的数据需要在网络边缘分析、处理与储存。

- 边缘计算市场規模将超万亿，成为与云计算平分秋色的新兴市场。而在国内市场方面，据CEDA预関，2020年我国物联网市场规模有

  望达到18300亿元，年复合増速高速25%，我国边缘计算发展将在接下来的两年迎来高峰

- 到2020年，平均下来，一个人每天会产生1.56的数据，每辆车会产生4TB的数据，，每架飞机会产生40TB的数据，每个小型的工厂

  会产生1PB数据

#### 1.2、现有数据存储技术制约

- 有状态数据据难以扩展，数据孤岛

- 大数据技术栈实时处理延时高，并发处理能力弱

- 实时分析时效慢，数据服务价值低

#### 1.3、用户需求

- 按需求水平扩展，灵活的业务不再受制于基础架构
- 并发高、相应延时低且稳定
- 实时决策

#### 1.4、TiDB解决方案应该考虑的事

- 扩展性
- 强一致性
- 高可用
- 标准SQL与事务ACID
- MySQL协议
- 云原生
- HTAP

#### 1.5、TiDB应用场景

- 海量数据高并发OLTP系统
  - 不再分库分表,不在使用受协的数据库中间件,业务不再受制于基础架构
- 海量数据高性能Real- Time Insights& Experiences实时分析
  - 兼容MySQL,大数据量下比MSQL快1-2个数量级的融合OLTP和OLAP的HTAP
  - 通过 TISPAK无连接 Spark,无需ETL,提供实时大规模复杂OLAP的HTAP
- 多源高吞吐汇总与实时计算
  - 多源(数十至数百异构数据源)、高吞吐(数十万QPS)汇聚写入AD-Hoc准实时查询
- 高写入场景
  - 金融级别多数据中心多活故障自动恢复、无需人工介入的真正意义的高可用
- 云数据库( Baas)
  - 云原生支持



### 二、TiDB的版本演进

 ```sh
# 版本
https://docs.pingcap.com/zh/tidb/stable/release-notes

# 官网
https://cn.pingcap.com/
 ```





### 三、TiDB部署

#### 3.1、基本结构介绍

- 作为一个分布式系统，最基础的TiDB测试集群通常由2个TiDB实例、3个TiVK实例、3个PD实例和可选的TiFlash实例构成。通过TiUP Playground，可以快速搭建上述的一套基础测试集群

#### 3.2、使用TiUP Playground快速部署本地测试环境

- 使用场景
  - 利用本地单机Linux环境快速部署TiDB集群。可以体验TDB集群的基本架构,以及TDB、 TIKVI PD、监控等基础组件的运行。适合开发测试使用。

#### 3.3、在线部署

- 参考官网：https://docs.pingcap.com/zh/tidb/stable/production-deployment-using-tiup

```sh
# 下载并且安装TiUP工具
mkdir /app/tidb && cd /app/tidb
wget https://tiup-mirrors.pingcap.com/install.sh

# 执行部署脚本
[root@tidb01 tidb]# sh install.sh
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 7085k  100 7085k    0     0  6850k      0  0:00:01  0:00:01 --:--:-- 6852k
WARN: adding root certificate via internet: https://tiup-mirrors.pingcap.com/root.json
You can revoke this by remove /root/.tiup/bin/7b8e153f2e2d0928.root.json
Successfully set mirror to https://tiup-mirrors.pingcap.com
Detected shell: bash
Shell profile:  /root/.bash_profile
/root/.bash_profile has been modified to add tiup to PATH
open a new terminal or source /root/.bash_profile to use it
Installed path: /root/.tiup/bin/tiup
===============================================
Have a try:     tiup playground
===============================================

# 重新声明全局环境变量
source /root/.bash_profile

# 确认 TiUP 工具是否安装
[root@tidb01 tidb]# which tiup
/root/.tiup/bin/tiup

# 部署  --without-monitor 控制是否开启监控 --host 指定本机ip   【等下载即可】
tiup playground v5.0.0 --db 2 --pd 3 --kv 3 --without-monitor --host 192.168.1.50

# 部署成功会显示【看到这个说明部署成功了】
CLUSTER START SUCCESSFULLY, Enjoy it ^-^
To connect TiDB: mysql --comments --host 192.168.1.50 --port 4000 -u root -p (no password)
To connect TiDB: mysql --comments --host 192.168.1.50 --port 4001 -u root -p (no password)
To view the dashboard: http://192.168.1.50:2379/dashboard
PD client endpoints: [192.168.1.50:2379 192.168.1.50:2382 192.168.1.50:2384]

# 测试连接 两个端口都可以【再打开一个窗口执行,刚刚部署的窗口不能关闭】
[root@tidb01 ~]# mysql --comments --host 192.168.1.50 --port 4000 -u root -p
Enter password:
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MySQL connection id is 7
Server version: 5.7.25-TiDB-v5.0.0 TiDB Server (Apache License 2.0) Community Edition, MySQL 5.7 compatible

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MySQL [(none)]>

[root@tidb01 ~]# mysql --comments --host 192.168.1.50 --port 4001 -u root -p
Enter password:
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MySQL connection id is 7
Server version: 5.7.25-TiDB-v5.0.0 TiDB Server (Apache License 2.0) Community Edition, MySQL 5.7 compatible

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MySQL [(none)]>

```

```sh
# dashboard登录页面, 默认root用户、密码空
http://192.168.1.50:2379/dashboard

# Prometheus页面
http://192.168.1.50:9090
```

```sh
# 销毁
通过 ctrl + c 停止进程

# 执行官方命令也行
tiup clean --all
```

#### 3.4、使用TiUP cluster 在单机上模拟生产环境部署

- 模拟在生产部署，实际生产  TiKV  3、TiDB  2、PD  3、TiFlash 1、Monitor 1 or 多个
- 地址规划好就行，然后其他的参考官网；例如挂盘、ssh免密、时间同步等

| 实例    | 个数 | IP                                     | 配置                   |
| ------- | ---- | -------------------------------------- | ---------------------- |
| TiKV    | 3    | 192.168.1.50,192.168.1.50,192.168.1.50 | 避免端口和目录冲突     |
| TiDB    | 1    | 192.168.1.50                           | 默认端口  全局目录配置 |
| PD      | 1    | 192.168.1.50                           | 默认端口  全局目录配置 |
| TiFlash | 1    | 192.168.1.50                           | 默认端口  全局目录配置 |
| Monitor | 1    | 192.168.1.50                           | 默认端口  全局目录配置 |

```sh
对于有需求，通过手动配置中控机至目标节点互信的场景，可参考本段。通常推荐使用 TiUP 部署工具会自动配置 SSH 互信及免密登录，可忽略本段内容。

以 root 用户依次登录到部署目标机器创建 tidb 用户并设置登录密码。

useradd tidb && \
passwd tidb
执行以下命令，将 tidb ALL=(ALL) NOPASSWD: ALL 添加到文件末尾，即配置好 sudo 免密码。

visudo
tidb ALL=(ALL) NOPASSWD: ALL
以 tidb 用户登录到中控机，执行以下命令。将 10.0.1.1 替换成你的部署目标机器 IP，按提示输入部署目标机器 tidb 用户密码，执行成功后即创建好 SSH 互信，其他机器同理。新建的 tidb 用户下没有 .ssh 目录，需要执行生成 rsa 密钥的命令来生成 .ssh 目录。如果要在中控机上部署 TiDB 组件，需要为中控机和中控机自身配置互信。

ssh-keygen -t rsa
ssh-copy-id -i ~/.ssh/id_rsa.pub 10.0.1.1
以 tidb 用户登录中控机，通过 ssh 的方式登录目标机器 IP。如果不需要输入密码并登录成功，即表示 SSH 互信配置成功。

ssh 10.0.1.1
[tidb@10.0.1.1 ~]$
以 tidb 用户登录到部署目标机器后，执行以下命令，不需要输入密码并切换到 root 用户，表示 tidb 用户 sudo 免密码配置成功。

sudo -su root
[root@10.0.1.1 tidb]#
```

```sh
# 1、下载并且安装TiUP工具
mkdir /app/tidb && cd /app/tidb
wget https://tiup-mirrors.pingcap.com/install.sh

# 2、执行部署脚本
[root@tidb01 tidb]# sh install.sh

# 3、重新声明全局环境变量
source /root/.bash_profile

# 4、确认 TiUP 工具是否安装
[root@tidb01 tidb]# which tiup
/root/.tiup/bin/tiup

# 5、安装TiUP 的 cluster组件
tiup cluster
tiup  update --self && tiup update cluster

# 6、修改sshd服务, 因为模拟在一个节点所以需要调整
 vim /etc/ssh/sshd_config
MaxSessions 20
systemctl restart sshd

# 7、创建并且启动集群
# 执行如下命令，生成集群初始化配置文件：当然也可以用官网的【端口不需要改,模板改IP规矩即可】
tiup cluster template > topology.yaml

# 8、执行部署命令前，先使用 check 及 check --apply 命令检查和自动修复集群存在的潜在风险：
# 检查集群存在的潜在风险：
tiup cluster check ./topology.yaml --user root [-p] [-i /home/root/.ssh/gcp_rsa]

# 自动修复集群存在的潜在风险：
tiup cluster check ./topology.yaml --apply --user root [-p] [-i /home/root/.ssh/gcp_rsa]

# 部署 TiDB 集群  版本自己选
tiup cluster deploy tidb-test v6.1.1 ./topology.yaml --user root [-p] [-i /home/root/.ssh/gcp_rsa]

# 说明成功
Enabling component pd
        Enabling instance 192.168.1.50:2376
        Enabling instance 192.168.1.50:2379
        Enabling instance 192.168.1.50:2378
        Enable instance 192.168.1.50:2379 success
        Enable instance 192.168.1.50:2376 success
        Enable instance 192.168.1.50:2378 success
Enabling component tikv
        Enabling instance 192.168.1.50:20160
        Enable instance 192.168.1.50:20160 success
Enabling component tidb
        Enabling instance 192.168.1.50:4000
        Enable instance 192.168.1.50:4000 success
Enabling component tiflash
        Enabling instance 192.168.1.50:9000
        Enable instance 192.168.1.50:9000 success
Enabling component prometheus
        Enabling instance 192.168.1.50:9090
        Enable instance 192.168.1.50:9090 success
Enabling component grafana
        Enabling instance 192.168.1.50:3000
        Enable instance 192.168.1.50:3000 success
Enabling component alertmanager
        Enabling instance 192.168.1.50:9093
        Enable instance 192.168.1.50:9093 success
Enabling component node_exporter
        Enabling instance 192.168.1.50
        Enable 192.168.1.50 success
Enabling component blackbox_exporter
        Enabling instance 192.168.1.50
        Enable 192.168.1.50 success
Cluster `tidb-test` deployed successfully, you can start it with command: `tiup cluster start tidb-test --init`

# 查看 TiUP 管理的集群情况
tiup cluster list

# 检查部署的 TiDB 集群情况
tiup cluster display tidb-test

# 启动集群
方式一：安全启动
tiup cluster start tidb-test --init
The root password of TiDB database has been changed.
The new password is: '9^RCem64*2BMN5!+0K'.
Copy and record it to somewhere safe, it is only displayed once, and will not be stored.
The generated password can NOT be get and shown again.
方式二：普通启动
tiup cluster start tidb-test

# 验证集群运行状态 【预期结果输出：各节点 Status 状态信息为 Up 说明集群状态正常。

】
tiup cluster display tidb-test
```

以上部署示例中：

- `tidb-test` 为部署的集群名称。
- `v6.1.1` 为部署的集群版本，可以通过执行 `tiup list tidb` 来查看 TiUP 支持的最新可用版本。
- 初始化配置文件为 `topology.yaml`。
- `--user root` 表示通过 root 用户登录到目标主机完成集群部署，该用户需要有 ssh 到目标机器的权限，并且在目标机器有 sudo 权限。也可以用其他有 ssh 和 sudo 权限的用户完成部署。
- [-i] 及 [-p] 为可选项，如果已经配置免密登录目标机，则不需填写。否则选择其一即可，[-i] 为可登录到目标机的 root 用户（或 --user 指定的其他用户）的私钥，也可使用 [-p] 交互式输入该用户的密码。

预期日志结尾输出 `Deployed cluster `tidb-test` successfully` 关键词，表示部署成功。




















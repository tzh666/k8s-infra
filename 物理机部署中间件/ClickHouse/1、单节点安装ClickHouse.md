## 单机部署ClickHouse

### 一、单机部署ClickHouse

#### 1.1、ClickHouse部署前提

- Clickhouse官网为：[https://clickhouse.com/],在官网中可以看到ClickHouse可以基于多种方式安装，rpm安装、tgz安装包安装、docker镜像安装、源码编译安装等

- 目前Clickhouse仅支持Linux系统且cpu必须支持SSE4.2指令集，可以通过以下命令查询Linux是否支持：

```sh
# 如果服务器不支持SSE4.2指令集，则不能下载预编译安装包，需要通过源码编译特定版本进行安装。
[root@master ~]# grep -q sse4_2 /proc/cpuinfo && echo "SSE 4.2 supported" || echo "SSE 4.2 not supported"
SSE 4.2 supported
```

##### 1.2、下载ClickHouse安装包

- 下载地址【https://packages.clickhouse.com/tgz/stable/】

```sh
# 选择版本下载，小技巧选择个版本依次这样下载即可
export CK_VERSION=21.9.4.35
curl -O https://repo.clickhouse.tech/tgz/stable/clickhouse-common-static-$CK_VERSION.tgz
curl -O https://repo.clickhouse.tech/tgz/stable/clickhouse-common-static-dbg-$CK_VERSION.tgz
curl -O https://repo.clickhouse.tech/tgz/stable/clickhouse-server-$CK_VERSION.tgz
curl -O https://repo.clickhouse.tech/tgz/stable/clickhouse-client-$CK_VERSION.tgz
```

1.3、 依次将这四个安装包解压，并且每解压一个，执行一下解压文件夹下的install下的doinst.sh脚本

- 密码：默认密码在/etc/clickhouse-server/users.d/default-password.xml 里，如果忘记了或者想换一个密码，可以删掉default-password.xml，在/etc/clickhouse-server/users.xml中设置新的密码
- clickhouse用户的密码在users.xml，比如你想将default用户的密码设置成123456，可以找到default用户的配置，修改password的配置为123456【 <password>123456</password>】
- 加密方法：echo -n "123456" | sha256sum | tr -d '-' 
- 如果需要将密码加密，clickhouse也支持sha256的方式，修改password_sha256_hex的配置
- 修改完密码之后，重启clickhouse server进程，密码就生效了 【clickhouse restart】

```sh
# 解压、运行doinst.sh 
tar -zxvf clickhouse-common-static-21.9.4.35.tgz
./clickhouse-common-static-21.9.4.35/install/doinst.sh 


tar -zxvf clickhouse-common-static-dbg-21.9.4.35.tgz 
./clickhouse-common-static-dbg-21.9.4.35/install/doinst.sh
 
#  运行 ./clickhouse-server-21.9.4.35/install/doinst.sh 出现以下提示 说密码在/etc/clickhouse-server/users.d
# Password for default user is already specified. To remind or reset, see /etc/clickhouse-server/users.xml and /etc/clickhouse-server/users.d.
# Setting capabilities for clickhouse binary. This is optional.

# 输入默认用户default的密码：
# Enter password for default user: 

# 是否本机访问,默认本机 y,当然也可以改配置文件下文有提及
# Allow server to accept connections from the network (default is localhost only), [y/N]: 
tar -zxvf clickhouse-server-21.9.4.35.tgz
./clickhouse-server-21.9.4.35/install/doinst.sh


tar -zxvf clickhouse-client-21.9.4.35.tgz
./clickhouse-client-21.9.4.35/install/doinst.sh
```

#### 1.3、启动

```sh
# 查看命令
clickhouse --help 

# 启动
[root@master clickhouse]# clickhouse start 
 chown --recursive clickhouse '/var/run/clickhouse-server/'
Will run su -s /bin/sh 'clickhouse' -c '/usr/bin/clickhouse-server --config-file /etc/clickhouse-server/config.xml --pid-file /var/run/clickhouse-server/clickhouse-server.pid --daemon'
Waiting for server to start
Waiting for server to start
Server started
```

#### 1.4、连接clickhouse

- clickhouse就简单安装成功了！
- 这是删了/etc/clickhouse-server/users.d/default-password.xml后，在/etc/clickhouse-server/users.xml中设置新的密码

```crystal
[root@master clickhouse]# clickhouse-client --password
ClickHouse client version 21.9.4.35 (official build).
Password for user (default):    # 输入密码123456; 
Connecting to localhost:9000 as user default.
Connected to ClickHouse server version 21.9.4 revision 54449.

master :) show databases;

SHOW DATABASES

Query id: 98112a6b-004c-4637-8740-9ac82885b0cb

┌─name────┐
│ default │
│ system  │
└─────────┘

2 rows in set. Elapsed: 0.006 sec. 

master :) 

```

#### 1.5、clickhouse相关目录

```sh
#  命令目录
cd /usr/bin
ll |grep clickhouse

# 配置文件目录
cd /etc/clickhouse-server/
 
# 日志目录
cd /var/log/clickhouse-server/
 
# 数据文件目录
cd /var/lib/clickhouse/

# 其他配置文件参数
#日志存放位置 根据个人所需修改 <log>/var/log/clickhouse-server/clickhouse-server.log</log> <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>

#数据目录 个人所需修改 <path>/var/lib/clickhouse/</path> <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>

#允许被访问 放开注释 <listen_host>::</listen_host>

#最大连接数 <max_connections>4096</max_connections>
```

#### 1.6、允许远程访问

- clickhouse 默认不允许远程访问，需要修改配置文件
- 改为：在浏览器输入服务器ip+8123验证一下能访问即可

```sh
vim /etc/clickhouse-server/config.xml
 
# 打开这行的注释
<listen_host>::</listen_host> 

# 修改时区 
<timezone>Asia/Shanghai</timezone>


# 重启ck
clickhouse restart

# 其他节点访问验证
curl 192.168.1.111:8123
Ok.
```


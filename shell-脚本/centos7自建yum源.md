**1. 系统环境 
**

```
# cat /etc/centos-release
CentOS Linux release 7.6. (Core) # uname -r
3.10.-.el7.x86_64 # ip a |awk 'NR==9{print $2}'|awk -F '/' '{print $1}'
10.0.0.100
```

**2. 修改yum 源为阿里云源**

**2.1 备份系统自带的yum源**

```
# tar -zcvf CentOS-bk.tar.gz /etc/yum.repos.d/CentOS-*
```

**2.2 修改yum源** 

```
# wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo# wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
```

或者

```
# curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo# curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
```

**2.3 检验阿里云源是否正常**

```
# yum repolist Loaded plugins: fastestmirror Loading mirror speeds from cached hostfile  * base: mirrors.aliyun.com  * extras: mirrors.aliyun.com  * updates: mirrors.aliyun.com #仓库标识仓库名称状态 repo id                                                                     repo name                                                                                                status !base//x86_64                                                              CentOS- - Base - mirrors.aliyun.com                                                                     , !epel/x86_64                                                                Extra Packages for Enterprise Linux  - x86_64                                                           , !extras//x86_64                                                            CentOS- - Extras - mirrors.aliyun.com                                                                       !updates//x86_64                                                           CentOS- - Updates - mirrors.aliyun.com                                                                   , repolist: ,
```

**3. 安装yum相关的软件**

```
# yum install -y wget make cmake gcc gcc-c++ pcre-devel zlib-devel openssl openssl-devel createrepo yum-utils
```

**yum-utils**：reposync同步工具

**createrepo**：编辑yum库工具

**plugin-priorities**：控制yum源更新优先级工具，这个工具可以用来控制进行yum源检索的先后顺序，建议可以用在client端。

注：由于很多人喜欢最小化安装，上边软件是一些常用环境。

**4. 根据源标识同步源到本地目录**

**4.1 创建本地目录**

```
# mkdir /mirror
```

**4.2 同步到本地目录**

```
# reposync -p / mirror
```

注：不用担心没有创建相关目录，系统自动创建相关目录，并下载，时间较长请耐心等待。

可以用  repo -r --repoid=repoid 指定要查询的repo id，可以指定多个（# reposync -r base -p /mirror  #这里同步base目录到本地）

更新新的rpm包

```
# reposync -np /mirror
```

注：时间同样较长，请耐心等待。

**4.3 创建索引**

```
# createrepo -po /mirror/base/ /mirror/base/
# createrepo -po /mirror/extras/ /mirror/extras/
# createrepo -po /mirror/updates/ /mirror/updates/
# createrepo -po /mirror/epel/ /mirror/epel/
```

**4.4 更新源数据**

```
# createrepo --update /mirror/base
# createrepo --update /mirror/extras
# createrepo --update /mirror/updates
# createrepo --update /mirror/epel
```

**4.5 创建定时任务脚本**

```
# vim /mirror/script/centos_yum_update.sh
#!/bin/bash
echo 'Updating Aliyum Source'
DATETIME=`date +%F_%T`
exec > /var/log/aliyumrepo_$DATETIME.log
     reposync -np /mirror
if [ $? -eq  ];then
      createrepo --update /mirror/base
      createrepo --update /mirror/extras
      createrepo --update /mirror/updates
      createrepo --update /mirror/epel
    echo "SUCESS: $DATETIME aliyum_yum update successful"
  else
    echo "ERROR: $DATETIME aliyum_yum update failed"
fi
```

**4.6 将脚本加入到定时任务中**

```
# crontab -e
# Updating Aliyum Source
  * *  [ $(date +%d) -eq $(cal | awk 'NR==3{print $NF}') ] && /bin/bash /mirror/script/centos_yum_update.sh
```

每月第一个周六的13点更新阿里云yum源

**5. 安装nginx开启目录权限保证本地机器可以直接本地yum源**

**5.1 创建运行账户**

```
# groupadd nginx
# useradd -r -g nginx -s /bin/false -M nginx
# yum install nginx -y
```

**5.2 修改nginx 配置文件**

```
# vim nginx.conf
worker_processes  ;
events {
    worker_connections  ;
} http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  ;
    server {
        listen       ;
        server_name  localhost;
        root         /mirror ;           #这里是yum源存放目录
        location / {
            autoindex on;        #打开目录浏览功能
            autoindex_exact_size off;  # off：以可读的方式显示文件大小
            autoindex_localtime on;    # on/off：是否以服务器的文件时间作为显示的时间
            charset utf-,gbk;     #展示中文文件名
            index index.html;
        }
        error_page        /50x.html;
        location = /50x.html {
            root   html;
        }
    }
} 
```

**6. 客户端创建repo文件**

注：搭建好后yum安装速度并没有想象中的那么快，安装时解决依赖速度也很慢。

```
# vim CentOS7.x-Base.repo
[base]
name=CentOS-$releasever - Base - mirror.template.com
baseurl=http://10.0.0.100/base/
path=/
enabled=
gpgcheck=  [updates]
name=CentOS-$releasever - Updates - mirror.template.com
baseurl=http://10.0.0.100/updates/
path=/
enabled=
gpgcheck= [extras]
name=CentOS-$releasever - Extras - mirrors.template.com
baseurl=http://10.0.0.100/extras/
path=/
enabled=
gpgcheck=  [epel]
name=CentOS-$releasever - epel - mirrors.template.com
baseurl=http://10.0.0.100/epel/
failovermethod=priority
enabled=
gpgcheck=
```

```sh
# 源于
https://www.bbsmax.com/A/xl56w9kodr/#c
https://blog.csdn.net/sin30_zhangdj/article/details/79414726
```



https://jingyan.baidu.com/article/6c67b1d65756732787bb1e02.html

1. 安装基础软件

   yum install -y make cmake gcc gcc-c++

   ![Centos7.5自建yum源方法](https://exp-picture.cdn.bcebos.com/58021a0148fe1e42be48b462c2299a88381303bb.jpg?x-bce-process=image%2Fresize%2Cm_lfit%2Cw_500%2Climit_1%2Fformat%2Cf_jpg%2Fquality%2Cq_80)

2. 

   安装制作yum源需要的一些软件

   yum install -y pcre-devel zlib-devel openssl openssl-devel createrepo yum-utils

   ![Centos7.5自建yum源方法](https://exp-picture.cdn.bcebos.com/5c2a1ad149299a88de30585667eeadbcbf2f7fbb.jpg?x-bce-process=image%2Fresize%2Cm_lfit%2Cw_500%2Climit_1%2Fformat%2Cf_jpg%2Fquality%2Cq_80)

3. 

   安装nginx

   yum install nginx

   ![Centos7.5自建yum源方法](https://exp-picture.cdn.bcebos.com/edafb3bcbe2f4770ab3b6f696f3b3b86032179bb.jpg?x-bce-process=image%2Fresize%2Cm_lfit%2Cw_500%2Climit_1%2Fformat%2Cf_jpg%2Fquality%2Cq_80)

4. 

   创建索引mkdir -p /opt/yum/centos/7/os/x86_64/createrepo /opt/yum/centos/7/os/x86_64/

   ![Centos7.5自建yum源方法](https://exp-picture.cdn.bcebos.com/3ac71c214f579356a7984893effb960b302170bb.jpg?x-bce-process=image%2Fresize%2Cm_lfit%2Cw_500%2Climit_1%2Fformat%2Cf_jpg%2Fquality%2Cq_80)

5. 

   设置阿里云镜像为本地yum源

   ![Centos7.5自建yum源方法](https://exp-picture.cdn.bcebos.com/974a2f21056104a3aeca331d63d7592ae2ef6bbb.jpg?x-bce-process=image%2Fresize%2Cm_lfit%2Cw_500%2Climit_1%2Fformat%2Cf_jpg%2Fquality%2Cq_80)

6. 

   将阿里云中的epel源同步到本地/opt/yum/centos/7/os/中reposync -r base -p /opt/yum/centos/7/os/

   ![Centos7.5自建yum源方法](https://exp-picture.cdn.bcebos.com/82eff6d7592ae3efe05ca48254b6326c566664bb.jpg?x-bce-process=image%2Fresize%2Cm_lfit%2Cw_500%2Climit_1%2Fformat%2Cf_jpg%2Fquality%2Cq_80)

7. 

   vi /root/yum-update.sh

   \#!/bin/bash

   datetime=`date +"%Y-%m-%d"`

   exec > /var/log/centosrepo.log

   reposync -d -r base -p /opt/yum/centos/7/os

   if [ $? -eq 0 ];then

     createrepo --update /opt/yum/centos/7/os/x86_64

     \#每次添加新的rpm时,必须更新索引信息

   echo "SUCESS: $datetime epel update successful"

   else

   echo "ERROR: $datetime epel update failed"

   fi

8. 

   设置定时任务crontab -e0 2 * * 3 sh /root/yum-update.sh

   ![Centos7.5自建yum源方法](https://exp-picture.cdn.bcebos.com/1570c1b6326c57669cebb2e0a4632385e13661bb.jpg?x-bce-process=image%2Fresize%2Cm_lfit%2Cw_500%2Climit_1%2Fformat%2Cf_jpg%2Fquality%2Cq_80)

9. 

   更新索引createrepo --update /opt/yum/centos/7/os/x86_64/

10. 

    清理缓存数据yum clean all && yum makecache

11. 11

    在测试服务器上编写repo文件vim /etc/yum.repos.d/tongbu-7.repo[feiyu]name=centos-tongbu

    baseurl=http://192.168.0.27/centos/releasever/os/basearch/enabled=1gpgcheck=0

12. 12

    配置nginx

    ![Centos7.5自建yum源方法](https://exp-picture.cdn.bcebos.com/2e223d85e036e2914ccc8353b2723d03baea5bbb.jpg?x-bce-process=image%2Fresize%2Cm_lfit%2Cw_500%2Climit_1%2Fformat%2Cf_jpg%2Fquality%2Cq_80)
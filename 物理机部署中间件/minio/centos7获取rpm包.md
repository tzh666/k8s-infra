### 一、xxx

- 同学们经常用yum下载软件，今天就教大家一个方法，把软件包弄下来
- 优点
  - 有的软件包安装的时候需要很多依赖包，内网不能上公网，这个命令就能很好的帮助我们
  - 做离线yum源的时候，补什么包都可以用这个命令去下载离线rpm包添加到自建yum即可

```sh
yum -y install --downloadonly --downloaddir=/tmp  packagename
```

- --downloadonly ：仅下载，不安装
- --downloaddir：离线包存储目录
- packagename：所需下载的安装包名

例子：

```sh
[root@node01 ~]# yum -y install --downloadonly --downloaddir=/tmp  docker-ce
```

```sh
# 以下就是docker安装所需依赖包了
[root@node01 tmp]# ll
total 98208
-rw-r--r--. 1 root root   261632 Aug 23  2019 audit-2.8.5-4.el7.x86_64.rpm
-rw-r--r--. 1 root root   104408 Aug 23  2019 audit-libs-2.8.5-4.el7.x86_64.rpm
-rw-r--r--. 1 root root    78256 Aug 23  2019 audit-libs-python-2.8.5-4.el7.x86_64.rpm
-rw-r--r--. 1 root root   302068 Nov 12  2018 checkpolicy-2.5-8.el7.x86_64.rpm
-rw-r--r--. 1 root root 29804976 Oct  5 01:39 containerd.io-1.4.11-3.1.el7.x86_64.rpm
-rw-r--r--. 1 root root    40816 Jul  6  2020 container-selinux-2.119.2-1.911c772.el7_8.noarch.rpm
-rw-r--r--. 1 root root 23785744 Oct  5 01:39 docker-ce-20.10.9-3.el7.x86_64.rpm
-rw-r--r--. 1 root root 30801216 Oct  5 01:39 docker-ce-cli-20.10.9-3.el7.x86_64.rpm
-rw-r--r--. 1 root root  8427040 Oct  5 01:39 docker-ce-rootless-extras-20.10.9-3.el7.x86_64.rpm
-rw-r--r--. 1 root root  4373740 Jun  3 03:29 docker-scan-plugin-0.8.0-3.el7.x86_64.rpm
-rw-r--r--. 1 root root    83764 Apr 29  2020 fuse3-libs-3.6.1-4.el7.x86_64.rpm
-rw-r--r--. 1 root root    55796 Apr 29  2020 fuse-overlayfs-0.7.2-6.el7_8.x86_64.rpm
-rw-r--r--. 1 root root    67720 Aug 23  2019 libcgroup-0.41-21.el7.x86_64.rpm
-rw-r--r--. 1 root root    57460 Apr  4  2020 libseccomp-2.3.1-4.el7.x86_64.rpm
-rw-r--r--. 1 root root   115284 Nov 12  2018 libsemanage-python-2.5-14.el7.x86_64.rpm
-rw-r--r--. 1 root root   938736 Apr  4  2020 policycoreutils-2.5-34.el7.x86_64.rpm
-rw-r--r--. 1 root root   468316 Apr  4  2020 policycoreutils-python-2.5-34.el7.x86_64.rpm
-rw-r--r--. 1 root root    32880 Jul  4  2014 python-IPy-0.75-6.el7.noarch.rpm
-rw-r--r--. 1 root root   635184 Nov 12  2018 setools-libs-3.3.8-4.el7.x86_64.rpm
-rw-r--r--. 1 root root    83452 Apr 29  2020 slirp4netns-0.4.3-4.el7_8.x86_64.rpm
```



### 当然也可以指定到具体版本

```sh
# 列出所有版本
yum list docker-ce --showduplicates | sort -r

# 指定版本安装
[root@localhost dk]# yum -y install --downloadonly --downloaddir=/tmp/dk  docker-ce-19.03.9-3.el7

# 查看结果
[root@localhost dk]# ll
total 91216
-rw-r--r--. 1 root root   261632 Aug 23  2019 audit-2.8.5-4.el7.x86_64.rpm
-rw-r--r--. 1 root root   104408 Aug 23  2019 audit-libs-2.8.5-4.el7.x86_64.rpm
-rw-r--r--. 1 root root    78256 Aug 23  2019 audit-libs-python-2.8.5-4.el7.x86_64.rpm
-rw-r--r--. 1 root root   302068 Nov 12  2018 checkpolicy-2.5-8.el7.x86_64.rpm
-rw-r--r--. 1 root root 29804976 Oct  5 01:39 containerd.io-1.4.11-3.1.el7.x86_64.rpm
-rw-r--r--. 1 root root    40816 Jul  6  2020 container-selinux-2.119.2-1.911c772.el7_8.noarch.rpm
-rw-r--r--. 1 root root 25286180 Jul 28  2020 docker-ce-19.03.9-3.el7.x86_64.rpm
-rw-r--r--. 1 root root 30801216 Oct  5 01:39 docker-ce-cli-20.10.9-3.el7.x86_64.rpm
-rw-r--r--. 1 root root  4373740 Jun  3 03:29 docker-scan-plugin-0.8.0-3.el7.x86_64.rpm
-rw-r--r--. 1 root root    67720 Aug 23  2019 libcgroup-0.41-21.el7.x86_64.rpm
-rw-r--r--. 1 root root    57460 Apr  4  2020 libseccomp-2.3.1-4.el7.x86_64.rpm
-rw-r--r--. 1 root root   115284 Nov 12  2018 libsemanage-python-2.5-14.el7.x86_64.rpm
-rw-r--r--. 1 root root   938736 Apr  4  2020 policycoreutils-2.5-34.el7.x86_64.rpm
-rw-r--r--. 1 root root   468316 Apr  4  2020 policycoreutils-python-2.5-34.el7.x86_64.rpm
-rw-r--r--. 1 root root    32880 Jul  4  2014 python-IPy-0.75-6.el7.noarch.rpm
-rw-r--r--. 1 root root   635184 Nov 12  2018 setools-libs-3.3.8-4.el7.x86_64.rpm
```


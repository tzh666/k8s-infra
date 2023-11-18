Solr单机安装

### 一、下载

```
自行到官网下载所需版本即可，我这里使用的是solr-7.1.0
solr官网：http://archive.apache.org/dist/lucene/solr/
```

### 二、安装环境

```shell
1、solr是JAVA语言开发的、自然是少不了jdk（1.8以上）
2、服务器版本：[root@t1 ~]# cat /etc/redhat-release 
   CentOS Linux release 7.6.1810 (Core)
3、可以选tomcat、或者内置的jetty容器部署（我选择的是内置的jetty）
```

### 三、安装步骤

```shell
3.1、下载 
[root@t1 ~]# wget http://archive.apache.org/dist/lucene/solr/7.1.0/solr-7.1.0.tgz 

3.2、解压到app目录、重命名
[root@t1 ~]# tar -zxvf solr-7.1.0.tgz  -C /app/ && cd /app/
[root@t1 app]# mv solr-7.1.0/ solr
```

### 四、启动

```shell
[root@t1 bin]# pwd
/app/solr/bin
[root@t1 bin]# ./solr start -force
NOTE: Please install lsof as this script needs it to determine if Solr is listening on port 8983.

Started Solr server on port 8983 (pid=7570). Happy searching!

#查看端口、默认是8983
[root@t1 bin]# ss -ntl|grep 8983
LISTEN     0      50          :::8983                    :::*   
```

### 五、浏览器访问

```
浏览器输入http://192.168.47.188:8983/solr/#/
```

<img src="C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20200801143845657.png" alt="image-20200801143845657" style="zoom: 33%;" />



### 六、新建core

```shell
#新建目录test
[root@t1 ~]# cd /app/solr/server/solr
[root@t1 solr]# mkdir test

#复制/app/solr/server/solr/configsets/_default/下的conf文件夹到test
[root@t1 test]# cd /app/solr/server/solr/configsets/_default
[root@t1 _default]# cp -r conf/ /app/solr/server/solr/test/
[root@t1 test]# ll
total 0
drwxr-xr-x 3 root root 143 Aug  1 22:52 conf
```

<img src="C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20200801145520650.png" alt="image-20200801145520650" style="zoom:80%;" />

建好之后的样子

<img src="C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20200801145653268.png" alt="image-20200801145653268" style="zoom:67%;" />
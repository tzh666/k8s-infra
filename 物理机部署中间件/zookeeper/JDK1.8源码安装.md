### JDK1.8源码安装

一、先卸载openjdk

```shell
#查找已安装的版本，若是没有结果，就表示没安装
rpm -qa|grep jdk
rpm -qa|grep java
#有的话卸载 --nodeps卸载相关依赖
rpm -e --nodeps + 版本
```

二、安装JDK1.8

1、下载自行到官网下载所需版本即可。

2、我把我已经下载下来的的jkd1.8穿到服务器上。

> CRT连接上服务器，输入rz然后找到jdk的安装包点击上传
>
> 如果提示没有这个命令下载
>
> yum install -y lrzsz

![image-20200628155323002](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\image-20200628155323002.png)

3、解压、改名

```shell
tar -zxvf jdk-8u221-linux-x64.tar.gz
mkdir -p /usr/local/java  
mv jdk1.8.0_221/ /usr/local/java
```

4、添加环境变量

```shell
#在最后添加如下内容
vim /etc/profile 
export JAVA_HOME=/usr/local/java
#针对tomcat要这么配置，否则起不来（要不在启动脚本里设置环境变量）
export JRE_HOME=/$JAVA_HOME/jre
export CLASSPATH=:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
export PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin:$CLASSPATH
export PATH=$PATH:$JAVA_HOME/bin
#使配置文件生效，执行
source /etc/profile
```

5、查看是否成功，有如下信息就是成功了

```shell
[root@t1 ~]# java -version
java version "1.8.0_221"
Java(TM) SE Runtime Environment (build 1.8.0_221-b11)
Java HotSpot(TM) 64-Bit Server VM (build 25.221-b11, mixed mode)
```


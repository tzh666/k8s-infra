 

#### Prometheus安装配置windows Exporter节点

*   [一、 windows\_exporter的安装下载](#_windows_exporter_2)
*   *   *   [1\. 安装包的下载](#1__3)
        *   [2.windows\_exporter下载完成后，双击即可运行。](#2windows_exporter_7)
        *   [3\. 在注册表和服务数据库中创建windows\_exporter服务项](#3__windows_exporter_12)
        *   [4\. 启动注册的windows\_export服务](#4_windows_export_20)
*   [二、Prometheus增加windows\_exporter配置](#Prometheuswindows_exporter_27)
*   *   *   [1\. 添加 prometheus.yml 配置： （需要注意文件格式）](#1__prometheusyml___28)
        *   [2\. 检查windows\_exporter节点](#2_windows_exporter_35)
*   [三、导入exporter的grafana 监控面板](#exportergrafana__38)
*   *   *   [1.查看grafana版本](#1grafana_39)
        *   [2\. 搜索所需的面板](#2__49)
        *   [3\. 下载控制面板](#3___52)
        *   [4\. grafana导入选中的面板](#4_grafana_55)
        *   [5\. 导入成功后的面板](#5__60)

一、 windows\_exporter的安装下载
-------------------------

#### 1\. 安装包的下载

[windows\_exporter 官方下载地址：https://github.com/prometheus-community/windows\_exporter/releases](https://github.com/prometheus-community/windows_exporter/releases)  
![在这里插入图片描述](https://img-blog.csdnimg.cn/448ffadfd5fa491fbdcb231c76b79f59.png)

#### 2.windows\_exporter下载完成后，双击即可运行。

1.  默认端口是9182，在浏览器输入：localhost:9182即可打开如下页面。为方便后续管理及使用，把windows\_exporter注册为服务

![在这里插入图片描述](https://img-blog.csdnimg.cn/fc57999b556e4ec282820066437959a6.png)

#### 3\. 在注册表和服务数据库中创建windows\_exporter服务项

```cpp
sc create windows_exporter binpath= "C:\Program Files (x86)\windwos_exporter\windows_exporter-0.20.0-amd64.exe" type= own start= auto displayname= windows_exporter

注：binpath后接的是.exe程序所在的目录及程序名称
```

#### 4\. 启动注册的windows\_export服务

1.  打开服务属性  
    ![在这里插入图片描述](https://img-blog.csdnimg.cn/93b608a73a3e4e9cb54c402de8f5ac0f.png)
2.  输入启动参数：–telemetry.addr=127.0.0.1:9182  
    ![在这里插入图片描述](https://img-blog.csdnimg.cn/3f710b95e7ad49fc9a5436646e5ef6c8.png)
3.  运行windows\_exporter服务  
    ![在这里插入图片描述](https://img-blog.csdnimg.cn/96e60ff8e6b44dcf8d9ed205ca2bf84a.png)

二、Prometheus增加windows\_exporter配置
---------------------------------

#### 1\. 添加 prometheus.yml 配置： （需要注意文件格式）

  `- job_name: "windwos_exporter"     scrape_interval: 15s     static_configs:          - targets: ["10.8.109.232:9182","10.8.109.233:9182"]`		

#### 2\. 检查windows\_exporter节点

1.  重启prometheus，即可查看已经配置好的exporter  
    ![在这里插入图片描述](https://img-blog.csdnimg.cn/3c1ce044a8af4140b186e6582660672b.png)![在这里插入图片描述](https://img-blog.csdnimg.cn/325b5ac75ec7460c9836ff6ae610f3ad.png)

三、导入exporter的[grafana](https://so.csdn.net/so/search?q=grafana&spm=1001.2101.3001.7020) 监控面板
--------------------------------------------------------------------------------------------

#### 1.查看grafana版本

因为某些grafana监控面板，对grafana版本有一定要求

`[root@rdapp ~]# ps -axu |grep  grafana root      7362  0.0  0.0 112824   984 pts/2    S+   16:04   0:00 grep --color=auto grafana root     20852  0.4  1.0 1939228 83064 ?       Ssl  11:19   1:24 /opt/rdapp/grafana/bin/grafana-server [root@rdapp ~]# cat /opt/rdapp/grafana/VERSION 9.2.3`

#### 2\. 搜索所需的面板

浏览器打开 [grafana监控面板地址：https://grafana.com/grafana/dashboards/?search=windows\_exporter](https://grafana.com/grafana/dashboards/?search=windows_exporter)  
![在这里插入图片描述](https://img-blog.csdnimg.cn/bab6587845564a7782a8d101617c0862.png)

#### 3\. 下载控制面板

选中所需面板，点击 Copy ID 或者 Download JSON  
![在这里插入图片描述](https://img-blog.csdnimg.cn/f1327040a3dd41be9671745bc4580d5d.png)

#### 4\. grafana导入选中的面板

1.  方法一：输入复制的面板 ID号，点击Load导入
2.  方法二：上传下载的Json文件，导入面板  
    ![在这里插入图片描述](https://img-blog.csdnimg.cn/74cf965607424629a4b8c36416a24dd5.png)  
    ![在这里插入图片描述](https://img-blog.csdnimg.cn/77503d06c13d4a3f99b495e2e720295b.png)

#### 5\. 导入成功后的面板

![在这里插入图片描述](https://img-blog.csdnimg.cn/12726814991f4ea49ede8297a6e1b6f7.png)


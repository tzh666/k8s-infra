## Prometheus监控Nginx

### 一、方案选择

```sh
    基于prometheus监控nginx可选两个exporter，一个是通过nginx_exporter主要是获取nginx-status中的内建的指标，nginx自身提供status信息，较为简单，promethues中对应的metrics也较少。
    另外一个是可以通过 nginx-vts-exporter监控更多的指标，但nginx-vts-exporter依赖在编译nginx的时候添加nginx-module-vts模块来实现。vts提供了访问虚拟主机状态的信息，包含server，upstream以及cache的当前状态，指标会更丰富一些。
```



### 二、nginx-vts-exporter方案

- #### nginx暴露数据操作

```sh
# 1、下载安装包
# 2、安装步骤
# 进入nginx安装目录，上传nginx-module-vts安装包，解压nginx-module-vts
cd /usr/local/nginx
tar -zxvf nginx-module-vts-0.2.1.tar.gz
# 预编译
./configure --add-module=nginx-module-vts-0.2.1
# 编译（这里只make，不要make install，不然会覆盖。如果是新装nginx，可以继续make install）
make

# 3、调整nginx启动脚本
# 进入nginx的sbin目录
cd /usr/local/nginx/sbin/
./nginx -s stop
mv nginx nginx.old
cp /usr/local/nginx/nginx-1.20.1/objs/nginx /usr/local/nginx/sbin/
# 启动nginx
cd /usr/local/nginx/sbin/
./nginx

# 4、查看插件是否安装成功
./nginx -V
configure arguments: 最后是否有 --add-module=nginx-module-vts-0.2.1

# 5、修改配置文件，添加nginx暴露数据的接口, 修改nginx.conf配置，增加以下内容
http {
    ...
    # 这两个要加
    vhost_traffic_status_zone;  
    vhost_traffic_status_filter_by_host on;
    ...
    server {
        ...   
        # 这个要加
        location /status {
            vhost_traffic_status_display;
            vhost_traffic_status_display_format html;
        }
        }
}

# 重启nginx
/usr/local/nginx/sbin/nginx -t
/usr/local/nginx/sbin/nginx -s reload

# 6、配置解析：
1、打开vhost过滤：
vhost_traffic_status_filter_by_host on;
开启此功能，在Nginx配置有多个server_name的情况下，会根据不同的server_name进行流量的统计，否则默认会把流量全部计算到第一个server_name上。

2、在不想统计流量的server区域禁用vhost_traffic_status，配置示例：
server {
        ...
        vhost_traffic_status off;
        ...
}
```

- #### nginx-vts-exporter安装指导

```sh
# 进入nginx安装目录
cd /usr/local/nginx
# 上传nginx-vts-exporter安装包
# 解压nginx-vts-exporter
tar -zxvf nginx-vts-exporter-0.10.7.tar.gz

# 查看默认配置
cd /usr/local/nginx/nginx-vts-exporter-0.10.3.linux-amd64
./nginx-vts-exporter -h

# 输出内容如下
Usage of ./nginx-vts-exporter:
  -insecure
            Ignore server certificate if using https (default true)
  -metrics.namespace string
            Prometheus metrics namespace. (default "nginx")
  -nginx.scrape_timeout int
            The number of seconds to wait for an HTTP response from the nginx.scrape_uri (default 2)
  -nginx.scrape_uri string
            URI to nginx stub status page (default "http://localhost/status")
  -telemetry.address string
            Address on which to expose metrics. (default ":9913")
  -telemetry.endpoint string
            Path under which to expose metrics. (default "/metrics")
  -version
            Print version information.
 
 
# 将nginx-vts-exporter配置为系统服务
# 进入systemd目录
cd /usr/lib/systemd/system

# 创建文件
vim nginx-vts-exporter.service
 
# 添加如下内容
[Unit]
Description=https://github.com/hnlq715/nginx-vts-exporter
After=network-online.target
 
[Service]
Restart=on-failure
ExecStart=/usr/local/nginx/nginx-vts-exporter-0.10.3.linux-amd64/nginx-vts-exporter -nginx.scrape_uri http://10.15.111.15/status/format/json
 
[Install]
WantedBy=multi-user.target

# 保存退出后生效系统文件
systemctl daemon-reload

# 设置开机自启
systemctl enable nginx-vts-exporter

# 启动nginx-vts-export
systemctl restart nginx-vts-exporter
```

- 添加prometheus监控配置并重启

```sh
# 添加如下内容
- job_name: 'nginx'
    scrape_interval: 30s
    static_configs:
      - targets: ['39.101.198.57:9913']
        labels:
          instance: '监控(39.101.198.57:9913)'
```



### 三、nginx_stub_status方案

- nginx 暴露数据操作

```sh
# 1、执行以下命令检查 Nginx 是否已经开启了该模块
nginx -V 2>&1 | grep -o with-http_stub_status_module

# 2、若无
./configure \
… \
--with-http_stub_status_module
make
# make install  # 注意 旧环境不需要重新make install  

# 3、确认 stub_status 模块启用之后，修改 Nginx 的配置文件指定 status 页面的 URL
vim prometheus-exporter.conf 
server {
    listen 8080;
    server_name 10.30.xx.xx;
    access_log /data/logs/prometheus-exporter.log  main;

   location = /nginx_status {
       stub_status;
   }
}

# 4、reload
nginx -t
nginx -s reload
```

- 部署 Nginx rometheus Exporter 

```sh
apiVersion: v1
kind: Service
metadata:
  name: nginx-exporter-106
  namespace: monitoring
spec:
  selector:
    app: nginx-exporter-106
  ports:
    - protocol: TCP
      port: 9113
      targetPort: 9113
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-exporter-106
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-exporter-106
  template:
    metadata:
      labels:
        app: nginx-exporter-106
    spec:
      nodeName: k8s-node02
      containers:
        - name: nginx-exporter-106
          image: harbor.zhilingsd.com/infra/nginx-prometheus-exporter:1.1.0
          args:
            - "--nginx.scrape-uri=http://10.30.15.106:8080/nginx_status"
          ports:
            - containerPort: 9113
          livenessProbe:
            httpGet:
              path: /metrics
              port: 9113
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /metrics
              port: 9113
            initialDelaySeconds: 30
            periodSeconds: 10
          resources:
            requests:
            limits:
              memory: "128Mi"
              cpu: "500m"
```

-  配置 Prometheus 的抓取 Job 

```sh
- job_name: 'consul-prometheus'
  consul_sd_configs:
    - server: 'consul-server:8500'
  relabel_configs:
    - source_labels: [__meta_consul_service_id]
      regex: (.+)
      target_label: 'node_name'
      replacement: '$1'
    - source_labels: [__meta_consul_service]
      regex: "node-exporter|nginx_exporter"
      action: keep
```

- 注册

```sh
curl --location --request PUT 'http://10.30.250.44:32685/v1/agent/service/register' \
--header 'Content-Type: application/json' \
--data '{
    "id": "nginx106",
    "name": "nginx_exporter",
    "address": "nginx-exporter-106",
    "port": 9113,
    "Meta": {
        "env": "prod",
        "team": "nginx_exporter",
        "project": "devops",
        "owner": "devops"
    },
    "checks": [
        {
            "http": "http://nginx-exporter-106:9113/",
            "interval": "10s"
        }
    ]
}'
```

- 导入面板

```sh
# 暂时用官方的，后续自己定制
https://github.com/nginxinc/nginx-prometheus-exporter/tree/main/grafana
```

- 告警规则

```sh
# 根据官方说的指标说明进行符合自己的告警规则定义
https://github.com/nginxinc/nginx-prometheus-exporter
```


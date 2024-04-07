## Prometheus监控keepalived

### 一、部署

- **--ka.pid-path 路径要注意下**
- **keepalived 安装路径不对可以加个软连接**：
  - ln -s  /usr/local/keepalived/sbin/keepalived  /usr/sbin/keepalived
- 他那个告警脚本暂时没用上

```sh
# 1、下载
export VERSION=1.3.2
wget https://github.com/mehdy/keepalived-exporter/releases/download/v${VERSION}/keepalived-exporter-${VERSION}.linux-amd64.tar.gz
tar xvzf keepalived-exporter-${VERSION}.linux-amd64.tar.gz keepalived-exporter-${VERSION}.linux-amd64/keepalived-exporter
sudo mv keepalived-exporter-${VERSION}.linux-amd64/keepalived-exporter /usr/local/bin/

# 2、部署
tar -xf keepalived-exporter-1.3.2.linux-amd64.tar.gz
mv keepalived-exporter /usr/local/bin/

# 启动脚本
vim /usr/lib/systemd/system/keepalived-exporter.service
[Unit]
Description=Keepalived Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/keepalived-exporter -web.listen-address=:9165 --ka.pid-path=/run/keepalived.pid	
ExecReload=/bin/kill -HUP
KillMode=process
TimeoutStopSec=20s
Restart=always

[Install]
WantedBy=default.target

# 启动 && 开启自启
systemctl enable keepalived-exporter && systemctl start keepalived-exporter
```



### 二、Prometheus监控

```sh
curl --location --request PUT 'http://xx:port/v1/agent/service/register' \
--header 'Content-Type: application/json' \
--data '{
    "id": "k8s-master03-ka",
    "name": "ka-exporter",
    "address": "xxx.43",
    "port": 9165,
    "Meta": {
        "env": "prod",
        "team": "ka-exporter",
        "project": "devops",
        "owner": "devops"
    },
    "checks": [
        {
            "http": "http://xx:9165/",
            "interval": "5s"
        }
    ]
}'

# 看你喜欢哪种
 - job_name: keepalived
    static_configs:
      - targets: ['x.x.x.x:9165']

```



### 三、面板导入

```sh
# git仓库介绍：
https://github.com/mehdy/keepalived-exporter

# 面板就用作者提供的
https://github.com/mehdy/keepalived-exporter/tree/v1.3.2/grafana/dashboards/keepalived-exporter.json
```



### 四、告警规则

```sh
# cat  rules/rules-keepalived.yml
groups:
- name: keepalived.rules
  rules:
  - alert: keepalived is down
    expr: keepalived_up == 0
    for: 5m
    labels:
      severity: critital
      instance: "{{ $labels.instance }}"
      apps: "{{ $labels.apps }}"
    annotations:
      summary: "keepalived 已关闭"
      description: "keepalived 已关闭,当前值: {{ $value }}(0异常|1正常)"
      value: "{{ $value }}"

  - alert: Keepalived vip has changed
    expr: keepalived_become_master_total{state="MASTER"} == 0
    for: 5m
    labels:
      severity: critital
      instance: "{{ $labels.instance }}"
      apps: "{{ $labels.apps }}"
    annotations:
      summary: "keepalived vip 已经变更"
      description: "keepalived vip 已经变更,当前值: {{ $value }}(0已变更|1未变更)"
      value: "{{ $value }}"

  - alert: Keepalived Check script status
    expr: keepalived_script_status == 0
    for: 5m
    labels:
      severity: critital
      instance: "{{ $labels.instance }}"
      apps: "{{ $labels.apps }}"
    annotations:
      summary: "keepalived 检查脚本状态"
      description: "keepalived 检查脚本状态,当前值: {{ $value }}(0异常|1正常)"
      value: "{{ $value }}"
```


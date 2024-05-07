# prometheus监控kafka

- kafka 监控需求：https://developer.aliyun.com/article/1098381
- 阿里云的例子：https://help.aliyun.com/zh/prometheus/use-cases/monitor-self-managed-kafka-clusters-and-message-queue-for-apache-kafka-instances
- 参考文档：
  - https://blog.csdn.net/penngo/article/details/128059472、
  - https://blog.csdn.net/weixin_43092290/article/details/133937623

### 一、方式一，exporter方式监控

-  kafka_exporter只需在集群的一个节点安装部署即可 
- git地址:  https://[github](https://so.csdn.net/so/search?q=github&spm=1001.2101.3001.7020).com/danielqsj/kafka_exporter
- 官方仪表板ID：7589

```sh
# kafka 任意节点部署
wget https://github.com/danielqsj/kafka_exporter/releases/download/v1.7.0/kafka_exporter-1.7.0.linux-amd64.tar.gz

# systemd 管理
vim /usr/lib/systemd/system/kafka_exporter.service
[Unit]
Description=kafka_exporter
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/kafka_exporter/kafka_exporter --kafka.server=kafkaIP:9092 --web.listen-address=:9308 --zookeeper.server=zkIP:2181
[Install]
WantedBy=multi-user.target

# 启动
systemctl daemon-reload
systemctl start kafka_exporter
systemctl enable kafka_exporter
```

- –kafka.server=172.18.244.164:9092 #需要监控的kafka连接地址
  –web.listen-address=:9308 #kafka_exporter监听地址
  –zookeeper.server=172.18.244.164:2181 #需要监控的zookeeper连接地址

```sh
# prometh
      - job_name: 'kafka'
        static_configs:
        - targets:
          - kafkaIP:9308 
```



### 二、JVM的方式

1. 下载jmx程序包。
2. 修改kafka启动参数
3. 重启kafka
4. 访问JMX-Agent端口验证监控指标
5. 5.修改配置文件，并重启Prometheus
6. 访问Prometheus，验证target是否监控成功。
7. 配置Grafana：导入模板、配置数据源、查看监控数据



### 三、告警规则

```yaml
# kafka_exporter_rules.yml
[root@grafana rules]# cat kafka_exporter_rules.yml
# kafka集群服务监控
groups:
- name: kafka服务监控
  rules:
  - alert: kafka消费滞后
    expr: sum(kafka_consumergroup_lag{topic!="sop_free_study_fix-student_wechat_detail"}) by (consumergroup, topic, job) > 50000
    for: 3m
    labels:
      severity: 严重告警
    annotations:
      summary: "{{$labels.instance}} kafka消费滞后({{$.Labels.consumergroup}})"
      description: "{{$.Labels.topic}}消费滞后超过5万持续3分钟(当前{{$value}})"
 
  - alert: kafka集群节点减少
    expr: kafka_brokers < 3   #kafka集群节点数3
    for: 3m
    labels:
      severity: 严重告警
    annotations:
      summary: "kafka集群部分节点已停止，请尽快处理！"
      description: "{{$labels.instance}} kafka集群节点减少"
 
  - alert: emqx_rule_to_kafka最近五分钟内的每秒平均变化率为0
    expr: sum(rate(kafka_topic_partition_current_offset{topic="emqx_rule_to_kafka"}[5m])) by ( instance,topic,job) ==0
    for: 5m
    labels:
      severity: 严重告警
    annotations:
      summary: "{{$labels.instance}} emqx_rule_to_kafka未接收到消息"
      description: "{{$.Labels.topic}}emqx_rule_to_kafka持续5分钟未接收到消息(当前{{$value}})"
```


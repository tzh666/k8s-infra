## 容器化部署单机版本RocketMQ

- 测试环境数据、日志懒得挂出来了
- /home/rocketmq/rocketmq-4.9.4/conf/ docker cp一份文件

```sh
docker run --name name_server \
--restart=always \
-p 9876:9876 \
-v /data1/name_server/conf/:/home/rocketmq/rocketmq-4.4.0/conf/ \
--privileged=true \
-e "MAX_POSSIBLE_HEAP=100000000" \
-d docker.io/apache/rocketmq:4.9.4 sh mqnamesrv autoCreateTopicEnable=true
```

```sh
docker run -d --name broker \
-p 10911:10911  \
-p 10909:10909 \
-v /data1/broker/conf/:/home/rocketmq/rocketmq-4.4.0/conf/  \
-e "NAMESRV_ADDR=192.168.1.162:9876"  \
-e "MAX_POSSIBLE_HEAP=200000000" \
docker.io/apache/rocketmq:4.9.4 sh mqbroker -c /home/rocketmq/rocketmq-4.4.0/conf/broker.conf
```

```sh
docker run -e "JAVA_OPTS=-Drocketmq.namesrv.addr=192.168.1.162:9876 -Dcom.rocketmq.sendMessageWithVIPChannel=false" -p 8080:8080 -t styletang/rocketmq-console-ng
```

- broker.conf配置文件改一下(记得修改brokerIP1的值为宿主机的ip地址)

```sh
brokerIP1=(宿主机内部IP地址)
```


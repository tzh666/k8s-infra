FROM registry.cn-hangzhou.aliyuncs.com/zhenhuan/tzh-k8s:base-skywalking-openjdk8

# 暴露端口
EXPOSE 9090

ENV JAVA_OPTS=""

ADD app.jar  /app/app.jar

# 启动命令,在k8s中可以通过环境变量注入jvm,就可以不需要写启动命令
#ENTRYPOINT ["sh","-c","java  ${JAVA_OPTS} -jar /app/app.jar ${SKYWALKING_OPTS}"]
ENTRYPOINT ["sh","-c","java ${SKYWALKING_OPTS} -jar ${JAVA_OPTS} /app/app.jar"]



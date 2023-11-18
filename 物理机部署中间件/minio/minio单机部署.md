### 一、minio单机部署

#### 1.1、版本选择

```sh
# 根据自己需求选择版本
http://dl.minio.org.cn/server/minio/release/linux-amd64/archive/
```

#### 1.2、部署

```sh
[root@minio1 ~]#  wget http://dl.minio.org.cn/server/minio/release/darwin-amd64/minio
[root@minio1 ~]#  chmod +x minio

# 启动成功可以看到一些对应信息（不指定信息启动）
[root@minio1 ~]# ./minio server /app/data

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ You are running an older version of MinIO released 6 days ago ┃
┃ Update: Run `mc admin update`                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

API: http://192.168.1.106:9000  http://127.0.0.1:9000         # 这里是固定的
RootUser: minioadmin 
RootPass: minioadmin 

Console: http://192.168.1.106:34153 http://127.0.0.1:34153    # 这端口不指定的话是随机的
RootUser: minioadmin 
RootPass: minioadmin 

Command-line: https://docs.min.io/docs/minio-client-quickstart-guide
   $ mc alias set myminio http://192.168.1.106:9000 minioadmin minioadmin

Documentation: https://docs.min.io

WARNING: Console endpoint is listening on a dynamic port (34153), please use --console-address ":PORT" to choose a static port.
WARNING: Detected default credentials 'minioadmin:minioadmin', we recommend that you change these values with 'MINIO_ROOT_USER' and 'MINIO_ROOT_PASSWORD' environment variables


```

#### 1.3、指定用户名、密码、web端口启动

```sh
export MINIO_ROOT_USER=admin
export MINIO_ROOT_PASSWORD=admin123
# 指定端口启动
[root@minio1 ~]# ./minio server /app/data --console-address ":50000" 

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ You are running an older version of MinIO released 6 days ago ┃
┃ Update: Run `mc admin update`                                 ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

API: http://192.168.1.106:9000  http://127.0.0.1:9000     
RootUser: admin 
RootPass: admin123 

Console: http://192.168.1.106:50000 http://127.0.0.1:50000   
RootUser: admin 
RootPass: admin123 

Command-line: https://docs.min.io/docs/minio-client-quickstart-guide
   $ mc alias set myminio http://192.168.1.106:9000 admin admin123

Documentation: https://docs.min.io
```

#### 1.4、基于dockers启动

```sh
docker run -d -p 9000:9000 -p 50000:50000 --name minio \  
-e "MINIO_ROOT_USER=admin" \  
-e "MINIO_ROOT_PASSWORD=12345678" \ 
-v /mnt/data:/data \  
-v /mnt/config:/root/.minio \ 
minio/minio server --console-address ":50000" /data 
```


#### 1.部署安装confluence[教程](https://blog.csdn.net/AnNan1997/article/details/125497406)

```BASH
[root@syj-test-33 ~]# mkdir -p  /home/{confluence,confluence-yml}
[root@syj-test-33 ~]# cd /home/confluence && chown -R daemon.daemon confluence-data/
[root@syj-test-33 confluence-yml]# cat /home/confluence-yml/docker-compose.yml
version: '3.4'
services:
  confluence:
    image: cptactionhank/atlassian-confluence:7.8.3
    container_name: confluence
    ports:
      - "80:8090"
      - "8091:8091"
    restart: always
    depends_on:
      - db
    volumes:
      - /home/confluence/logs:/opt/atlassian/confluence/logs
      - /home/confluence/confluence-data:/var/atlassian/confluence
  db:
    image: postgres:9.4
    container_name: confluence-db
    ports:
      - "5432:5432"
    restart: always
    environment:
      - POSTGRES_PASSWORD=123456
    volumes:
      - /home/confluence/pgsql-data:/var/lib/postgresql/data
 ---------------------------------------------------------------------     
 [root@syj-test-33 confluence-yml]# docker-compose up -d
```

#### 2.破解jar包

```bash
# 1.破解-下载 atlassian-extras-decoder-v2-3.4.1.jar 文件到pc上，然后重命名为“atlassian-extras-2.4.jar”，因为破解工具只识别这个文件名。
[root@syj-test-33 ~]# docker cp confluence:/opt/atlassian/confluence/confluence/WEB-INF/lib/atlassian-extras-decoder-v2-3.4.1.jar ./atlassian-extras-2.4.jar
 --------------------------------------------------------------------- 
# 2.破解好的jar包,上传到服务器上改名为atlassian-extras-decoder-v2-3.4.1.jar复制到容器并重启
[root@syj-test-33 ~]# docker cp atlassian-extras-decoder-v2-3.4.1.jar confluence:/opt/atlassian/confluence/confluence/WEB-INF/lib   
[root@syj-test-33 ~]# docker restart confluence

破解工具下载链接：
链接：https://pan.baidu.com/s/1kEIx7rssQPre1bN8Vfeevw
提取码：c3k8  
```

#### 3.pg创建库

```bash
[root@syj-test-33 home]# docker exec -it confluence-db /bin/bash
root@54cedea9b303:/# psql -U postgres
psql (9.4.26)
Type "help" for help.

postgres=# create database confluence with owner postgres;
postgres=# \l
                                 List of databases
    Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
------------+----------+----------+------------+------------+-----------------------
 confluence | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 postgres   | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 template0  | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
            |          |          |            |            | postgres=CTc/postgres
 template1  | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
            |          |          |            |            | postgres=CTc/postgres
(4 rows)
```

![image-20240228132238645](/Users/jiang/Library/Application Support/typora-user-images/image-20240228132238645.png)
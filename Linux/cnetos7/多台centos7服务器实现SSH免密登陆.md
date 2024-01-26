## 多台centos7服务器实现SSH免密登陆

### 一、环境

centos7.x  三台

node1、node2、node3

### 二、实现免密登陆

##### 2.1、node1上，生成公钥与私钥

```shell
[root@node1 ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:8tK4pGADFikGA7kOL55prlOJD7qxNJsVIrS3WngQYXk root@node1
The key's randomart image is:
+---[RSA 2048]----+
|=+.              |
|+ooE             |
|.B.              |
|* +              |
|=B +  . S        |
|*oO o  =         |
|+O*=  + o        |
|+OXo o o         |
|BB  . .          |
+----[SHA256]-----+
```

##### 2.2、node上，自己连接自己

```shell
[root@node1 .ssh]# ssh-copy-id 192.168.1.129
```

##### 2.3、node1上，scp密钥到node2、node3

```shell
[root@node1 ~]# scp -pr .ssh/ 192.168.1.130:/root/
[root@node1 ~]# scp -pr .ssh/ 192.168.1.131:/root/
```

##### 2.3、检验是否成功

```
[root@node1 ~]# ssh 192.168.1.130
Last failed login: Wed Sep 16 18:30:37 CST 2020 from 192.168.1.129 on ssh:notty
There were 2 failed login attempts since the last successful login.
Last login: Wed Sep 16 17:48:42 2020 from 192.168.1.1
[root@node2 ~]# 
```


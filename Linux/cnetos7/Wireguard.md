#### [Wireguard服务器/客户端配置](https://www.cnblogs.com/wangruixing/p/12936643.html)

#### 1. C/S wg安装 

```bash
$ sudo yum install yum-utils epel-release
$ sudo yum-config-manager --setopt=centosplus.includepkgs=kernel-plus --enablerepo=centosplus --save
$ sudo sed -e 's/^DEFAULTKERNEL=kernel$/DEFAULTKERNEL=kernel-plus/' -i /etc/sysconfig/kernel
$ sudo yum install kernel-plus wireguard-tools
$ sudo reboot
```

#### 2.服务端生成密钥对

```bash
# 开启ipv4流量转发
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# 创建并进入WireGuard文件夹
mkdir -p /etc/wireguard && chmod 0777 /etc/wireguard
cd /etc/wireguard
umask 077

# 生成服务器和客户端密钥对
wg genkey | tee server_privatekey | wg pubkey > server_publickey
wg genkey | tee client_privatekey | wg pubkey > client_publickey
```

#### 3.配置文件生成

```bash
##########################生成服务端的配置文件 /etc/wireguard/wg0.conf##########################
echo "
[Interface]
PrivateKey = $(cat server_privatekey) # 填写本机的privatekey 内容
Address = 10.0.8.1/24
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = 50814 # 注意该端口是UDP端口
DNS = 8.8.8.8
MTU = 1420
[Peer]
PublicKey =  $(cat client_publickey)  # 填写对端的publickey 内容
AllowedIPs = 10.0.8.10/24 " > wg0.conf
# 设置开机自启
systemctl enable wg-quick@wg0
# 重要！如果名字不是eth0, 以下PostUp和PostDown处里面的eth0替换成自己服务器显示的名字
# ListenPort为端口号，可以自己设置想使用的数字
# 以下内容一次性粘贴执行，不要分行执行



##########################生成客户端的配置文件 /etc/wireguard/client.conf##########################
echo "
[Interface]
  PrivateKey = $(cat client_privatekey)  # 填写本机的privatekey 内容
  Address = 10.0.8.10/24
  DNS = 8.8.8.8
  MTU = 1420

[Peer]
  PublicKey = $(cat server_publickey)  # 填写对端的publickey 内容
  Endpoint = server公网的IP:50814
  AllowedIPs = 0.0.0.0/0, ::0/0
  PersistentKeepalive = 25 " > client.conf
 # 注：文件在服务端配好了可以下载下来传到客户端

```

#### 4.启动WireGuard

```bash
########################服务端###################
# 启动WireGuard
wg-quick up wg0
# 停止WireGuard
wg-quick down wg0
# 查看WireGuard运行状态
[root@localhost~]# wg
interface: wg0
  public key: b8fztAWxqS/SKQ619YTM09siKESbzoUiBeautnFsaGU=
  private key: (hidden)
  listening port: 50814

peer: HF7vS/rpk2tEQ1WxWnh78Rp8lSuwEMLISqQsX6MFlwk=
  endpoint: 221.225.202.158:11562
  allowed ips: 10.0.8.0/24
  latest handshake: 34 seconds ago
  transfer: 16.26 KiB received, 12.87 KiB sent
########################客户端###################
# 启动WireGuard
wg-quick up client
# 停止WireGuard
wg-quick down client
# 查看WireGuard运行状态
[root@v2 ~]# wg
interface: client
  public key: HF7vS/rpk2tEQ1WxWnh78Rp8lSuwEMLISqQsX6MFlwk=
  private key: (hidden)
  listening port: 59633
  fwmark: 0xca6c

peer: b8fztAWxqS/SKQ619YTM09siKESbzoUiBeautnFsaGU=
  endpoint: server公网的IP:50814
  allowed ips: 0.0.0.0/0, ::/0
  latest handshake: 17 seconds ago
  transfer: 9.96 KiB received, 19.09 KiB sent
  persistent keepalive: every 25 seconds

```

#### 5.2台机器测试10网段的互ping

##### 6.客户端路由配置

```bash
[root@v2 ~]# ip route add 103.52.188.136 via 192.168.1.2 
[root@v2 ~]# ip route add 0.0.0.0/0 via 10.0.8.1   # 所有的流量都走这个ip
```

#### 7.server端

```bash
yum -y install tcpdump
# 监视指定网络接口的数据包 
tcpdump -i wg0 # 我们的转发都是经过这个私网来进行的可以客户ping的同时，服务端进行抓包查看
```


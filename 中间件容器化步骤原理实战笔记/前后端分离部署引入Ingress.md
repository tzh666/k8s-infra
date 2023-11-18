## 引入Ingress-nginx部署前后端项目

### 一、ingress-nginx部署

```sh
参考:  https://www.cnblogs.com/hsyw/p/17804493.html
```



### 二、首先看看传统的部署

本文是采用go-admin开源项目进行部署，参考文档如下

- https://www.go-admin.pro/guide/xmbs

#### 2.1、部署后端

```yaml
### 镜像我都上传到阿里云公开仓库了
apiVersion: v1
kind: Service
metadata:
  name: go-admin
  labels:
    app: go-admin
    service: go-admin
spec:
  ports:
  - port: 8000
    name: http
    protocol: TCP
  selector:
    app: go-admin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-admin-v1
  labels:
    app: go-admin
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: go-admin
      version: v1
  template:
    metadata:
      labels:
        app: go-admin
        version: v1
    spec:
      containers:
      - name: go-admin
        image: registry.cn-hangzhou.aliyuncs.com/zhenhuan/go-admin:v1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000
        volumeMounts:
        - name: go-admin-config
          mountPath: /config/
          readOnly: true
      volumes:
      - name: go-admin-config
        configMap:
          name: settings-admin
```

#### 2.2、部署前端

- 这打包前端的时候，如果这修改了那么ng配置文件也得修改
- `.env.production`文件里的写的是：**VUE_APP_BASE_API = 'http://go-admin.haimait.com/goadminapi'**

```yaml
# 为了方便调试此处用hostpath，生产ng请勿用这种方式
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeName: k8s-node01
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: nginx
          image: registry.cn-hangzhou.aliyuncs.com/zhenhuan/go-admin-ui:v1
          ports:
            - containerPort: 80
          volumeMounts:
          - name: nginx-config
            mountPath: /etc/nginx/nginx.conf
            subPath: nginx.conf
          - name: nginx-all-conf
            mountPath: /etc/nginx/conf.d/
      volumes:                
      - name: nginx-all-conf
        hostPath:
          path: /data/zlsd/nginx/conf.d/
      - name: nginx-config    
        configMap:
          name: nginx-config 
          items:
          - key: nginx.conf   
            path: nginx.conf 
---
## 然后此处直接用80暴露的NodePort
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  ports:
    - port: 80
      targetPort: 80
      name: http
      nodePort: 80
  selector:
    app: nginx
  type: NodePor
```

- Nginx配置文件

```yaml
[root@k8s-master01 传统nginx]# cat go-admin.haimait.com.conf 
server {
    listen       80;
    server_name go-admin.haimait.com;
    charset utf-8;
    access_log  /tmp/host.access.log  main;
    
    location / {
        index  index.html;
        root  /usr/share/nginx/dist;
        try_files $uri $uri/ /index.html;
    }

    location ~ ^/goadminapi/ {
         proxy_pass http://192.168.1.180:8000;
         proxy_redirect              off;
         proxy_set_header            Host $host;
         proxy_set_header            X-Real-IP $remote_addr;
         proxy_set_header            X-Forwarded-For $proxy_add_x_forwarded_for;
         client_max_body_size 10m;
         client_body_buffer_size 128k;
         rewrite ^/goadminapi/(.*)$ /$1 break;
    }      
}
```

基本上没啥问题， **在hosts文件加个映射就能正常访问go-admin.haimait.com**



### 三、引入Ingress组件

```sh
# 参考文档：
  https://www.cnblogs.com/hahaha111122222/p/15341857.html
  https://blog.csdn.net/u011663693/article/details/125526801
```

#### 3.1、部署后端

```sh
# 就是2.1的部署，没改
```

#### 3.2、部署前端

- 这打包前端的时候，如果这修改了那么ng配置文件也得修改
- `.env.production`文件里的写的是：**VUE_APP_BASE_API = 'http://go-admin.haimait.com'

```sh
[root@k8s-master01 go-admin-ui]# cat .env.production 
# just a flag
ENV = 'production'

# base api
VUE_APP_BASE_API = 'http://go-admin.haimait.com'
```

- 直接上配置文件

```yaml
## 首先是NG配置文件
[root@k8s-master01 ingress]# cat go-admin.haimait.com.conf 
server {
    listen       80;
    server_name go-admin.haimait.com;
    charset utf-8;
    access_log  /tmp/host.access.log  main;
    
    location / {
        index  index.html index.htm;
        root  /usr/share/nginx/html/dist;
        try_files $uri $uri/ /index.html;
    }
    location ~ ^/api/ {
         proxy_pass http://go-admin:8000;
         proxy_redirect              off;
         rewrite ^/goadminapi/(.*)$ /$1 break;
    }
}

# 前端部署yaml文件
[root@k8s-master01 ingress]# cat nginx_svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  ports:
    - port: 80
      targetPort: 80
      name: http
  selector:
    app: nginx
[root@k8s-master01 ingress]# cat nginx_deploy.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeName: k8s-node01
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: nginx
          image: registry.cn-hangzhou.aliyuncs.com/zhenhuan/go-admin-ui:v9
          ports:
            - containerPort: 80
          volumeMounts:
          - name: nginx-config
            mountPath: /etc/nginx/nginx.conf
            subPath: nginx.conf
          - name: nginx-all-conf
            mountPath: /etc/nginx/conf.d/
      volumes:                
      - name: nginx-all-conf
        hostPath:
          path: /data/zlsd/nginx/conf.d/
      - name: nginx-config    
        configMap:
          name: nginx-config  
          items:
          - key: nginx.conf  
            path: nginx.conf  
```

#### 3.3、Ingress配置文件

- 这里ingress就代理前端
  - 前端那边配置文件，配置了前端，一个后端

```yaml
[root@k8s-master01 ingress]# cat go-admin-ui-ingress.yaml 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: go-admin
  annotations:
spec:
  ingressClassName: nginx
  rules:
  - host: go-admin.haimait.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-svc
            port:
              number: 80
```



行了就这样了
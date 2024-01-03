k8s-StatefulSet方式部署分布式MinIO（分布式MinIO）

```shell
kubectl label node node1 node=minio
kubectl label node node2 node=minio
kubectl create ns minio
```

```shell
mkdir ~/minio-yml
```

```shell
cat > ~/minio-yml/minio.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: minio
  labels:
    app: minio
  namespace: minio
spec:
  clusterIP: None
  ports:
    - port: 9000
      name: data
    - port: 9001
      name: console
  selector:
    app: minio

---
apiVersion: v1
kind: Service
metadata:
  name: minio-service
  namespace: minio
spec:
  type: NodePort
  ports:
   - name: data
     nodePort: 31900
     port: 9000
     targetPort: 9000
     protocol: TCP
     nodePort:
   - name: console
     nodePort: 31901
     port: 9001
     targetPort: 9001
     protocol: TCP
     nodePort:
  selector:
    app: minio

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
  namespace: minio
spec:
  serviceName: "minio"
  replicas: 4
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      nodeSelector:
        node: minio
      containers:
      - name: minio
        env:
        - name: MINIO_ROOT_USER
          value: "admin"
        - name: MINIO_ROOT_PASSWORD
          value: "Admin@2023"
        image: minio/minio:RELEASE.2023-06-23T20-26-00Z
        imagePullPolicy: IfNotPresent
        command:
          - /bin/sh
          - -c
          - minio server --console-address ":9001" http://minio-{0...3}.minio.minio.svc.cluster.local:9000/data
        ports:
        - name: data
          containerPort: 9000
          protocol: "TCP"
        - name: console
          containerPort: 9001
          protocol: "TCP"
        volumeMounts:
        - name: minio-data
          mountPath: /data
        - name: time-mount
          mountPath: /etc/localtime
      volumes:
      - name: time-mount
        hostPath:
          path: /usr/share/zoneinfo/Asia/Shanghai
  volumeClaimTemplates:
  - metadata:
      name: minio-data
    spec:
      storageClassName: "nfs-storage"
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 2Ti
EOF
```

```shell
kubectl apply -f ~/minio-yml/minio.yml
```


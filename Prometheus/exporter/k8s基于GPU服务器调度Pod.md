## k8s基于GPU服务器调度Pod

### 一、先决条件

- 需要k8s集群中节点有GPU
- 需要安装显卡驱动  
  - 参考：https://www.jianshu.com/p/a1db05bba743

- k8s上部署设备插件 【 NVIDIA 】



### 二、k8s上部署设备插件

```sh
# 参考官网
https://github.com/NVIDIA/k8s-device-plugin
```

#### 2.1、先决条件

- NVIDIA 驱动程序 ~= 384.81

- Kubernetes 版本 >= 1.10

- nvidia-docker >= 2.0 || nvidia-container-toolkit >= 1.7.0

  - 安装参考：https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

  - ```sh
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
      sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
      
    yum-config-manager --enable nvidia-container-toolkit-experimental
    
    yum install -y nvidia-container-toolkit
    ```

- nvidia-container-runtime 配置为默认低级运行时  

  - ```sh
    # 如果是docker作为容器运行时：
    {
        "default-runtime": "nvidia",
        "runtimes": {
            "nvidia": {
                "path": "/usr/bin/nvidia-container-runtime",
                "runtimeArgs": []
            }
        }
    }
    # restart
    systemctl restart docker
    
    
    # 如果是containerd作为容器运行时：
    vim /etc/containerd/config.toml
    version = 2
    [plugins]
      [plugins."io.containerd.grpc.v1.cri"]
        [plugins."io.containerd.grpc.v1.cri".containerd]
          default_runtime_name = "nvidia"
    
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
              privileged_without_host_devices = false
              runtime_engine = ""
              runtime_root = ""
              runtime_type = "io.containerd.runc.v2"
              [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
                BinaryName = "/usr/bin/nvidia-container-runtime"
    # restart           
    systemctl restart containerd
    ```

#### 2.2、部署插件到k8s

```sh
# 在集群中的所有 GPU 节点上配置上述选项后，您可以通过部署以下 Daemonset 来启用 GPU 支持：
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.3/nvidia-device-plugin.yml

# 生产建议用helm部署
https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file#deployment-via-helm
```

```sh
# 查看部署结果
[root@k8s-master01 ~]# kubectl get po -n kube-system -l name=nvidia-device-plugin-ds
NAME                                   READY   STATUS    RESTARTS   AGE
nvidia-device-plugin-daemonset-w5kwg   1/1     Running   0          41h

# 查看k8s集群是否识别到GPU
[root@k8s-master01 ~]# kubectl describe no k8s-node05 | grep gpu
                    gpu-node=true
  nvidia.com/gpu:     2
  nvidia.com/gpu:     2
  nvidia.com/gpu     2              2    # 可以看到是有2个卡识别到
```

```sh
# 验证Pod是否能通过GPU调度
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  restartPolicy: Never
  containers:
    - name: cuda-container
      image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda10.2
      resources:
        limits:
          nvidia.com/gpu: 1 # requesting 1 GPU
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF

# 查看日志  出现这个日志说明正常了，Pod能通过GPU调度
kubectl logs gpu-pod
[Vector addition of 50000 elements]
Copy input data from the host memory to the CUDA device
CUDA kernel launch with 196 blocks of 256 threads
Copy output data from the CUDA device to the host memory
Test PASSED
Done
```

```sh
# 提供一个能直接跑GPU业务服务的dockerfile
# 这样玩意镜像里面有cuda:10.0-cudnn7 这样才支持跑tensorflow
FROM nvidia/cuda:10.0-cudnn7-devel-centos7

# 时区 jdk
RUN rm -rf /etc/localtime \
    && ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && yum install -y java-1.8.0-openjdk-devel.x86_64 && 
```



### 三、Prometheus监控GPU

```sh
wget https://github.com/utkuozdemir/nvidia_gpu_exporter/releases/download/v1.2.0/nvidia_gpu_exporter_1.2.0_linux_x86_64.tar.gz
```

```sh
# 运行nvidia_gpu_exporter
tar xf nvidia_gpu_exporter_1.2.0_linux_x86_64.tar.gz
 
mv nvidia_gpu_exporter /usr/local/gpu-exporter/nvidia_gpu_exporter
 
/usr/local/gpu-exporter/nvidia_gpu_exporter &
```

```sh
# 在prometheus.yml中添加exporter地址
- job_name: gpu-exporter
  static_configs:
  - targets: ['192.168.2.23:9835']
    lables:
      gpu: nvidia-4090
      app: gpu-exporter
  - targets: ['192.168.2.26:9835']
    lables:
      gpu: nvidia-4080
      app: gpu-exporter
```

```sh
# 面板
https://grafana.com/grafana/dashboards/14574-nvidia-gpu-metrics/
```

```sh
# 告警规则
groups:
- name: nvidia_gpu_alerts
  rules:
  - alert: GPU内存使用率
    expr: nvidia_smi_utilization_memory_ratio * 100 > 90
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "GPU memory usage is high"
      description: "GPU memory usage is above 90%"

  - alert: GPU温度过高
    expr: nvidia_smi_temperature_gpu > 80
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "GPU temperature is high"
      description: "GPU temperature is above 80 degrees Celsius"

  - alert: GPU负载高
    expr: nvidia_smi_utilization_gpu_ratio > 90
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "GPU utilization is high"
      description: "GPU utilization is above 90%"
```


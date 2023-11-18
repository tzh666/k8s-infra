





### 报错

```sh
Warning  FailedMount  15s  kubelet  MountVolume.SetUp failed for volume "pvc-7ed9203c-02ce-46ca-8113-aadfc0983571" : mount failed: exit status 32
Mounting command: systemd-run
Mounting arguments: --description=Kubernetes transient mount for /var/lib/kubelet/pods/41db95b4-29d7-4cad-942c-2c88a7728b36/volumes/kubernetes.io~nfs/pvc-7ed9203c-02ce-46ca-8113-aadfc0983571 --scope -- mount -t nfs 192.168.1.71:/data/nfs-share/minio-export-minio-0-pvc-7ed9203c-02ce-46ca-8113-aadfc0983571 /var/lib/kubelet/pods/41db95b4-29d7-4cad-942c-2c88a7728b36/volumes/kubernetes.io~nfs/pvc-7ed9203c-02ce-46ca-8113-aadfc0983571
Output: Running scope as unit run-35650.scope.
mount: wrong fs type, bad option, bad superblock on 192.168.1.71:/data/nfs-share/minio-export-minio-0-pvc-7ed9203c-02ce-46ca-8113-aadfc0983571,
       missing codepage or helper program, or other error
       (for several filesystems (e.g. nfs, cifs) you might
       need a /sbin/mount.<type> helper program)

       In some cases useful info is found in syslog - try
       dmesg | tail or so.
```

```sh
# 解决
原因是有两台服务器没安装nfs命令
yum  install  nfs-utils rpcbind  -y  
```


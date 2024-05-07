#!/bin/bash
########################################################################################################
# @Scpript      该脚本用于系统日常巡检，仅供学习研究                                           #######################
########################################################################################################

function RED(){
	echo -e "\033[31m$@\033[0m"
}

function GRE(){
	echo -e "\033[36m$@\033[0m"
}

function OS_INFO(){
	# 系统名
	local OS_NAME=`uname -n`
	# 系统版本
	local OS_VERSION=`cat /etc/redhat-release || echo 获取信息失败`
	# 系统类型
	local OS_TYPE=`uname`
	# 主机序列号
	local OS_NUM=`dmidecode -t system | grep 'Serial Number' | awk '{print $3}'`
	# 系统内核版本
	local OS_KERNEL=`uname -r`
	# 系统机器码
	local OS_CODE=""
	# 系统语言环境
	local OS_LANG=`echo $LANG`
	# 系统时间
	local OS_DATE=`date +"%Y-%m-%d %H:%M:%S"`
	# 系统运行时间
	local OS_UPTIME=`uptime | awk -F',' '{sub(/.*up /,"",$1);print $1'} || echo 获取信息失败`
	# 系统上次重启时间
	local OS_LAST_REBOOT=`last reboot | head -1 | awk '{print $5,$6,$7,$8,$10}'`
	# 系统上次关机时间
	local OS_LAST_SHUTDOWN=`last -x | grep shutdown | head -1 | awk '{print $5,$6,$7,$8,$10}'`

	RED "################################# [ 系统信息巡检区 ] ######################################"
	GRE "主机名：$OS_NAME"
	GRE "主机类型：$OS_TYPE"
	GRE "主机序列号：${OS_NUM:-获取信息失败}"
	GRE "系统版本：$OS_VERSION"
	GRE "系统内核版本：$OS_KERNEL"
	GRE "系统机器码：${OS_CODE:-获取信息失败}"
	GRE "系统语言环境：${OS_LANG}"
	GRE "系统时间；$OS_DATE"
	GRE "系统已运行时间：$OS_UPTIME"
	GRE "系统上次重启时间：${OS_LAST_REBOOT:-获取信息失败}"
	GRE "系统上次关机时间：${OS_LAST_SHUTDOWN:-获取信息失败}"
}

function OS_HDWARE(){
	# CPU架构
	local CPU_ARCH=`uname -m`
	# CPU型号
	local CPU_TYPE=`cat /proc/cpuinfo | grep "model name" | uniq | awk -F':' '{sub(/ /,"",$2);print $2}'`
	# CPU个数
	local CPU_NUM=`cat /proc/cpuinfo | grep "physical id" | sort | uniq | wc -l`
	# CPU 核数
	local CPU_CORE=`cat /proc/cpuinfo | grep cores | uniq | awk -F':' '{sub(/ /,"",$2);print $2}'`
	# CPU 频率
	local CPU_HZ=`cat /proc/cpuinfo | grep "cpu MHz" | uniq | awk -F':' '{sub(/ /,"",$2);printf "%s MHz\n",$2}'`

	# 内存容量
	local ME_SIZE=$(echo "scale=2;`cat /proc/meminfo | grep 'MemTotal:' | awk '{print $2}'`/1048576"|bc)
	# 空闲内存
	local ME_FREE=$(echo "scale=2;`cat /proc/meminfo | grep 'MemFree:' | awk '{print $2}'`/1048576"|bc)
	# 可用内存
	local ME_FREEE=$(echo "scale=2;`cat /proc/meminfo | grep 'MemAvailable:' | awk '{print $2}'`/1048576" | bc)
	# 内存使用率
	local ME_USE=$(awk 'BEGIN{printf "%.1f%\n",('$ME_SIZE'-'$ME_FREEE')/'$ME_SIZE'*100}')
	# SWAP大小
	local ME_SWAP_SIZE=$(echo "scale=2;`cat /proc/meminfo | grep 'SwapTotal:' | awk '{print $2}'`/1048576"|bc)
	# SWAP可用
	local ME_SWAP_FREE=$(echo "scale=2;`cat /proc/meminfo | grep 'SwapFree:' | awk '{print $2}'`/1048576"|bc)
	# SWAP使用率
	local ME_SWAP_USE=$(awk 'BEGIN{printf "%.1f%\n",('$ME_SWAP_SIZE'-'$ME_SWAP_FREE')/'$ME_SWAP_SIZE'*100}')
	# Buffer大小
	local ME_BUF=$(cat /proc/meminfo | grep 'Buffers:' | awk '{printf "%s KB",$2}')
	# 内存Cache大小
	local ME_CACHE=$(cat /proc/meminfo | grep '^Cached:' | awk '{printf "%s KB",$2}')

	# 当前系统所有网卡
	local NET_DEVICE=(`cat /proc/net/dev | awk 'NR>2 && $1 !~/lo/ {sub(/:/,"");print $1}'`)

	RED "################################# [ 系统硬件巡检区 ] ######################################"
	GRE "CPU型号：$CPU_TYPE"
	GRE "CPU架构：$CPU_ARCH"
	GRE "CPU个数：$CPU_NUM"
	GRE "CPU核数: $CPU_CORE"
	GRE "CPU频率：$CPU_HZ"
	GRE "内存容量：${ME_SIZE} GB"
	GRE "内存空闲：${ME_FREE} GB"
	GRE "内存可用：${ME_FREEE} GB"
	GRE "内存使用率：${ME_USE}"
	GRE "SWAP容量：$ME_SWAP_SIZE GB"
	GRE "SWAP可用容量：$ME_SWAP_FREE GB"
	GRE "SWAP使用率：$ME_SWAP_USE"
	GRE "内存Buffer大小：${ME_BUF}"
	GRE "内存Cache大小：${ME_CACHE}"

	for i in ${NET_DEVICE[@]}
	do
		GRE "网卡：$i  状态: $(ip link show $NET_DEVICE | awk 'NR==1{print $9}') RX: $(ethtool -g $NET_DEVICE | grep "RX:" | tail -1 | awk '{print $2}') TX: $(ethtool -g $NET_DEVICE | grep "TX:" | tail -1 | awk '{print $2}')"
	done
}

function OS_NETWORK(){
	# 系统IP
	local IP=$(hostname -I)
	# 网关地址
	local GATEWAY=$(ip route | grep default &>/dev/null && ip route | grep default | awk '{print $3}' || echo '未设置默认网关')
	# DNS地址
	local DNS=(`cat /etc/resolv.conf | grep nameserver | uniq | awk '{print $2}'`)

	RED "################################# [ 系统网络巡检区 ] ######################################"
	GRE "IP地址：$IP"
	GRE "网关地址：$GATEWAY"
	GRE "DNS地址：${DNS[@]}"
	GRE "网关[$GATEWAY]连接情况: $(ping -t 1 -i 1 -c 5 -W 1 $GATEWAY &>/dev/null && echo '正常通信' || echo '无法通信')"
}

function OS_RESOURCE(){
	# 系统磁盘列表
	local DISK_LIST=(`lsblk | egrep "^[a-z].*" | grep -v "^sr" | awk '{print $1}'`)
	# 系统磁盘使用率情况
	local DISK_PER=(`df -h | awk 'NR>1 && $1 !~/sr/ {gsub(/%/,"",$5);print $5}'`)

	# CPU空闲率
	local CPU_FREE=$(top -d 1 -n 1 -b | awk 'NR==3{print $8}')
	# CPU使用率
	local CPU_USE=$(awk 'BEGIN{printf "%.1f%\n",100-'$CPU_FREE'}')
	# CPU_TOP_TEN
	local CPU_TOP_TEN=$(top -d 1 -n 1 -b | column -t | awk 'NR>=7 && NR<=15')

	# 当前进程数
	local CPU_PROCESSORS=$(top -d 1 -n 1 -b | awk 'NR==2{print $2}')
	# 当前正在运行进程数
	local CPU_RUN_PROCESSORS=$(top -d 1 -n 1 -b | awk 'NR==2{print $4}')
	# 当前正在休眠进程数
	local CPU_SL_PROCESSORS=$(top -d 1 -n 1 -b | awk 'NR==2{print $6}')
	# 当前停止运行进程数
	local CPU_STOP_PROCESSORS=$(top -d 1 -n 1 -b | awk 'NR==2{print 8}')
	# 当前僵尸进程数
	local CPU_ZOM_PROCESSORS=$(top -d 1 -n 1 -b | awk 'NR==2{print $10}')
	

	RED "################################# [ 系统资源巡检区 ] ######################################"
	GRE "CPU使用率：$CPU_USE"
	GRE "CPU使用率前十进程信息:"
	GRE "$(ps -eo user,pid,pcpu,pmem,args --sort=-pcpu | head -n 10)"
	GRE "\n内存使用率前十进程信息:"
	GRE "$(ps -eo user,pid,pcpu,pmem,args --sort=-pmem | head -n 10)"
	GRE "\n磁盘IO信息:$(iotop -bon 1 &>/dev/null || echo 'io top 未安装信息获取失败')"
	GRE "$(iotop -bon 1 &>/dev/null && iotop -bon 1 | head -n 13)"
	GRE "\n磁盘分区使用率是否正常：正常"
	for i in ${DISK_LIST[@]}
	do
		if [[ -z "$(lsblk --nodeps -no serial /dev/$i)" ]]; then
			GRE "磁盘：$i	磁盘序列号：获取信息失败"	
		else
			GRE "磁盘：$i	磁盘序列号：$(lsblk --nodeps -no serial /dev/$i)"
		fi
	done
	for i in ${DISK_PER[@]}
	do
		if [ $i -gt 80 ]; then
			RED "某分区磁盘使用率为：$i% > 80% 请及时扩容"
		fi
	done
	GRE "\n系统磁盘分区inode使用情况："
	GRE "$(df -Thi)"
	GRE "\n系统当前进程数：$CPU_PROCESSORS"	
	GRE "系统当前进程运行数：$CPU_RUN_PROCESSORS"
	GRE "系统当前休眠进程数：$CPU_SL_PROCESSORS"
	GRE "系统当前停止进程数：$CPU_STOP_PROCESSORS"
	GRE "系统当前僵尸进程数：$CPU_ZOM_PROCESSORS"

	GRE "\n系统当前允许最大fd数量：$(cat /proc/sys/fs/file-nr | awk '{print $3}')"
	GRE "系统当前已打开fd数量：$(cat /proc/sys/fs/file-nr | awk '{print $1}')"
	GRE "系统单个进程运行打开fd数量：$(ulimit -n)"

	GRE "\n系统当前socket连接数：$(netstat -anp &>/dev/null && netstat -anp | wc -l || echo 'net-tools 未安装,获取信息失败')"
	GRE "系统 established socket数量: $(netstat -anp &>/dev/null && netstat -anp | grep "ESTABLISHED" | wc -l || echo 'net-tools 未安装,获取信息失败')"
	GRE "系统 sync socket数量：$(netstat -anp &>/dev/null && netstat -anp | grep "SYN" | wc -l || echo 'net-tools 未安装,获取信息失败')"
	GRE "系统当前已建立socket如下:"
	GRE "$(netstat -anp &>/dev/null && netstat -anp | grep ESTABLISHED | awk '{printf "  本地:%-20s <=>    外部:%-22s\n",$4,$5}' || echo '')"
}

function OS_SECURITY(){
	# 系统所有能登录的用户
	local OS_USER=(`cat /etc/passwd | awk -F':' '$NF !~/nologin|sync|shutdown|halt/ {print $1}'`)
	# Selinux
	local OS_SELINUX=`getenforce`
	# 防火墙状态
	local OS_FIREWALLD=`service firewalld status &>/dev/null | grep "running" && echo on || echo off`

	RED "################################# [ 系统安全巡检区 ] ######################################"
	GRE "防火墙状态: $OS_FIREWALLD"
	GRE "Selinux状态：${OS_SELINUX}\n"
	GRE "系统可登录用户数：$(cat /etc/passwd | awk -F':' '$NF !~/nologin|sync|shutdown|halt/ {print $1}' | wc -l)"
	GRE "系统可登录用户：${OS_USER[@]}"
	for i in ${OS_USER[@]}
	do
		GRE "用户 $i 最后1次登录信息: $(lastlog -u $i | awk 'NR==2')"
	done
	GRE "系统当前登录用户："
	GRE "$(who | sed 's#[()]##g' | awk '{printf "   用户: %10s 终端: %7s 登录时间: %7s %7s 登录IP: %7s\n",$1,$2,$3,$4,$5}')"
}

function OS_SERVICE(){
	RED "################################# [ 系统服务巡检区 ] ######################################"
	GRE "自行添加"
}

if [ $(id -u -n) != "root" ]; then
	ERROR "请以ROOT用户运行这个脚本"
fi

OS_INFO
OS_HDWARE
OS_NETWORK
OS_RESOURCE
OS_SECURITY

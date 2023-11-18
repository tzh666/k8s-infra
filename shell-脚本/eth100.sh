#! /bin/bash
# 更改网卡名为eth100
# 张临东

UP_NET_COUNT=`ip a |grep 'state UP'|awk -F ':| ' '{print$3}'|wc -l`
NET_NAME=`ip a|grep 'state UP'|awk -F ':| ' '{print$3}'`
MAC=`ip a|grep -A 1 'state UP'|awk 'NR==2{print$2}'`
DNET_NAME=`ip a|grep 'state DOWN'|awk -F ':| ' '{print$3}'`

function ONE_UP_NET {
    SPE=`ethtool ${NET_NAME}|grep Speed|awk '{print$2}'`
    # echo "网卡${NET_NAME}的带宽是${SPE}"
    echo "The bandwidth of network card ${NET_NAME} is ${SPE}"
    # read -p "请确保该激活的网卡为改为eth100的网卡:" nus
    read -t 10 -p "Please ensure that the active NIC is changed to eth100 NIC(y/n)(default is y):" nus
	nus=${nus:-y}
    if [ $nus = y ]; then
        echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"${MAC}\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"eth100\""> /etc/udev/rules.d/70-persistent-net.rules
        echo '70-persistent-net.rules is OK!'
        sed -i "s/${NET_NAME}/eth100/g" /etc/sysconfig/network-scripts/ifcfg-${NET_NAME}
        mv /etc/sysconfig/network-scripts/ifcfg-${NET_NAME} /etc/sysconfig/network-scripts/ifcfg-eth100
        # echo '网卡已改完'
        if [ $? -eq 0 ]; then
	    	echo -e "\033[32m The network adapter has been changed. \033[0"
	    	echo -e "\033[37m   \033[0"
	    	sed -i 's/\(.*\)quiet\"/\1quiet biosdevname=0 net.ifnames=0\"/g' /etc/default/grub
	    	echo -e "\033[32m grub is OK! \033[0"
	    	echo -e "\033[37m   \033[0"
	    	grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/unll
	    	# echo 'grub已生效 准备重启...'
	    	echo -e "\033[32m grub is effective, ready to restart... \033[0"
	    	echo -e "\033[37m   \033[0"
	    	sleep 5
	    	init 6
	    else
	        echo -e "\033[31m Error \033[0"
	    	echo -e "\033[37m   \033[0"
	    	exit 1
	    fi
    elif [ $nus = n ]; then
        echo 'exit！'
        exit 0
    else
        echo 'Input error！'
        exit 1
    fi
}

function NONE_UP_NET {
    m=0
    for n in $DNET_NAME; do NETS[$m]=$n; let m++; done
	
    m=0
    for n in ${NETS[*]}; do echo $m')' $n; let m++; done
    # read -p '无激活的网卡，请选择一个改为eth100的网卡(编号):' num
    read -p 'No active network adapter. Please select a eth100 adapter (serial number).:' num
 
    NMAC=`ip a|grep -A 1 "${NETS[$num]}"|awk 'NR==2{print$2}'`
    NNET_NAME=${NETS[$num]}
 
    echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"${NMAC}\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"eth100\""> /etc/udev/rules.d/70-persistent-net.rules
    echo '70-persistent-net.rules is OK!'
    sed -i "s/${NNET_NAME}/eth100/g" /etc/sysconfig/network-scripts/ifcfg-${NNET_NAME}
    mv /etc/sysconfig/network-scripts/ifcfg-${NNET_NAME} /etc/sysconfig/network-scripts/ifcfg-eth100
    if [ $? -eq 0 ]; then
		echo -e "\033[32m The network adapter has been changed. \033[0"
		echo -e "\033[37m   \033[0"
		sed -i 's/\(.*\)quiet\"/\1quiet biosdevname=0 net.ifnames=0\"/g' /etc/default/grub
		echo -e "\033[32m grub is OK! \033[0"
		echo -e "\033[37m   \033[0"
		grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/unll
		# echo 'grub已生效 准备重启...'
		echo -e "\033[32m grub is effective, ready to restart... \033[0"
		echo -e "\033[37m   \033[0"
		sleep 5
		init 6
	else
	    echo -e "\033[31m Error \033[0"
		echo -e "\033[37m   \033[0"
		exit 1
	fi
}

function MORE_UP_NET {
    m=0
    for n in $NET_NAME; do NETS[$m]=$n; let m++; done
	
    m=0
    for n in ${NETS[*]}; do echo $m')' $n; let m++; done
    # read -p '激活的网卡有多个，请选择一个改为eth100的网卡(编号):' num
    read -p 'There are more than one active network adapter. Please choose a network adapter (eth100):' num
    NMAC=`ip a|grep -A 1 "${NETS[$num]}"|awk 'NR==2{print$2}'`
    NNET_NAME=${NETS[$num]}
	
    echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"${NMAC}\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"eth100\""> /etc/udev/rules.d/70-persistent-net.rules
    echo '70-persistent-net.rules is OK!'
    sed -i "s/${NNET_NAME}/eth100/g" /etc/sysconfig/network-scripts/ifcfg-${NNET_NAME}
    mv /etc/sysconfig/network-scripts/ifcfg-${NNET_NAME} /etc/sysconfig/network-scripts/ifcfg-eth100
    if [ $? -eq 0 ]; then
		echo -e "\033[32m The network adapter has been changed. \033[0"
		echo -e "\033[37m   \033[0"
		sed -i 's/\(.*\)quiet\"/\1quiet biosdevname=0 net.ifnames=0\"/g' /etc/default/grub
		echo -e "\033[32m grub is OK! \033[0"
		echo -e "\033[37m   \033[0"
		grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/unll
		# echo 'grub已生效 准备重启...'
		echo -e "\033[32m grub is effective, ready to restart... \033[0"
		echo -e "\033[37m   \033[0"
		sleep 5
		init 6
	else
	    echo -e "\033[31m Error \033[0"
		echo -e "\033[37m   \033[0"
		exit 1
	fi
}

if [ $UP_NET_COUNT = 1 ]
    then ONE_UP_NET
elif [ $UP_NET_COUNT = 0 ]
    then NONE_UP_NET
else
    MORE_UP_NET
fi

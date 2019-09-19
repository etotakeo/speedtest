#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

govar="2.1.0"

#密钥公钥 参数自己定义,内容写在"内
ca_vps="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDZtqIeIuBRN4rpJ6wcWipg+07VLOTGl0ofXlq6BoVqp ed25519 256-042719"
ca_s="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEyQiYMRgJDBXLGnUTkausTl4h+zRAW7ijIzZVOk0sz4 ed25519 256-042619"

#定义颜色的变量
RED_COLOR='\E[1;31m'  #红
GREEN_COLOR='\E[1;32m' #绿
YELOW_COLOR='\E[1;33m' #黄
BLUE_COLOR='\E[1;34m'  #蓝
PINK='\E[1;35m'      #粉红
RES='\E[0m'

#这里判断系统
if [ -f /etc/redhat-release ]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
fi

[[ $EUID -ne 0 ]] && echo -e "${PINK}error:${RES} This script must be run as root!" && exit 1

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
	[[ -z ${IP} ]] && IP=$( wget -qO- -t1 -T2 myip.ipip.net )
    [[ -z ${IP} ]] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [[ -z ${IP} ]] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
#	clear
    [[ ! -z ${IP} ]] && echo 网卡 IP：${IP} && echo $ipname || echo "-------------------"
}

# Install some dependencies
clear

printf "
${BLUE_COLOR}#######################################################################${RES}
#     欢迎使用 SSH密钥安装程序 ${govar}
#     系统支持 CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
${BLUE_COLOR}#######################################################################${RES}
"
echo -e "${PINK}Info:${RES} 密钥安装成功将会自动关闭密码登陆,可加参数 ${GREEN_COLOR} -p${RES} 跳过"
read -t 30 -p "Info: 按任意键继续...按 Ctrl + C 取消" var

#check count of parameters. We need only 1, which is key id
if [ $# -eq 0 -o $# -gt 2 ]; then
	echo -e "${GREEN_COLOR}Info:${RES} 欢迎使用SSH密钥安装程序!"
    echo -e "${GREEN_COLOR}Info:${RES} 安装密钥不关闭密码登陆~参数增加 -p!"
	echo " - Usage: $0 {ca~name} [-p]"; exit 1;
fi
KEY_ID=${1}
DISABLE_PW_LOGIN=1
authorized_keys=1
SHELL_ZZH=0

if [ $# -eq 2 -a "$2" = '-p' ]; then
	DISABLE_PW_LOGIN=0
fi

# Disable selinux
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi

echo -e "\n${GREEN_COLOR}Info:${RES} 是否安装可能需要的依赖[Y/n]"
read -t 10 -p "(默认: y):" yn
[[ -z "${yn}" ]] && yn="y"
if [[ ${yn} == [Yy] ]]; then
	if [ "${release}" = "centos" ]; then
		#yum -y upgrade
		yum install epel* -y
		#yum -y remove ntp
    	pkgList="iftop htop wget vim net-tools git unzip ca-certificates"
    	for Package in ${pkgList}; do
    		yum -y install ${Package}
    	done
	else
		apt-get update -y
		#apt-get upgrade -y
        apt-get -y purge apache2 apache2-* bind9-* xinetd samba-* nscd-* portmap sendmail-* sasl2-bin rpcbind postfix exim4 bsd-mailx exim4-base exim4-config exim4-daemon-light
    	pkgList="iftop htop wget curl vim net-tools git unzip ca-certificates"
    	for Package in ${pkgList}; do
      		apt-get -y install $Package
    	done
	fi
	rm -rf /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	clear
fi

echo -e "${GREEN_COLOR}Info:${RES} 是否卸载 postfix (邮件传输代理)[Y/n]"
read -t 10 -p "(默认: y):" yn
[[ -z "${yn}" ]] && yn="y"
if [[ ${yn} == [Yy] ]]; then
	if [ "${release}" = "centos" ]; then
	yum remove postfix rpcbind -y
	else
	apt-get autoremove --purge postfix rpcbind
	fi
	clear
fi

#ca 参数转换为变量
ca_setup=`eval echo '$'${KEY_ID}`
#echo ${ca_setup}

#
if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
	echo -e "${GREEN_COLOR}Info:${RES} ~/.ssh/authorized_keys 本密钥文件未找到 ...";

	echo -e "创建本地密钥文件 ${HOME}/.ssh/authorized_keys ..."
	mkdir -p ${HOME}/.ssh/
	touch ${HOME}/.ssh/authorized_keys

	if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
		echo -e "${GREEN_COLOR}Info:${RES} 无法创建SSH密钥文件!"
	else
		echo e "${GREEN_COLOR}Info:${RES} 密钥文件已创建，正在进行下一步..."
	fi
fi

echo -e "${GREEN_COLOR}-----------------------${RES} 密钥参数 ${YELOW_COLOR}${KEY_ID}${RES}"
echo "${ca_setup}"
echo -e "${GREEN_COLOR}-----------------------${RES} 准备安装...\n"

if [ "${ca_setup}" = '' ]; then
	echo -e "${PINK}error:${RES} 密钥参数 ${KEY_ID} 无法识别,我不知道你要安装哪个密钥,请检查本脚本!!"; exit 1;
fi

if [ $(grep -m 1 -c "${ca_setup}" ${HOME}/.ssh/authorized_keys) -eq 1 ]; then
	echo -e "${GREEN_COLOR}Info:${RES} 发现密钥已经安装，是否更新？[Y/n]"
	read -t 10 -p "(默认: y):" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ ${yn} == [Nn] ]]; then
		authorized_keys=0
		echo && echo "${GREEN_COLOR}Info:${RES} 已取消更新安装密钥..." && echo
	else
	rm -rf ${HOME}/.ssh/authorized_keys && touch ${HOME}/.ssh/authorized_keys
	fi
fi

#install key
if [ ${authorized_keys} -eq 1 ]; then
	echo -e "${ca_setup}\n" >> ${HOME}/.ssh/authorized_keys
	if [ $(grep -m 1 -c "${ca_setup}" ${HOME}/.ssh/authorized_keys) -ne 1 ]; then
		rm -rf ${HOME}/.ssh/authorized_keys && touch ${HOME}/.ssh/authorized_keys
        DISABLE_PW_LOGIN=0
		echo &&	echo "${PINK}\nerror:${RES} 钥匙安装失败!($Verif)" && echo && echo "-----${HOME}/.ssh/authorized_keys---↓---" && echo "${var}" && echo "------var-------↓---" && echo "${KEY_ID}" && echo "------Error--log----↑-------------" && exit 1;
	fi
	chmod 700 ${HOME}/.ssh
	chmod 600 ${HOME}/.ssh/authorized_keys
	echo -e "${GREEN_COLOR}Info:${RES} 钥匙安装成功!"
    echo -e "${GREEN_COLOR}Info:${RES} 查看已安装密钥可执行 ${YELOW_COLOR}cat ~/.ssh/authorized_keys${RES} 查看!"

#disable root password
if [ ${DISABLE_PW_LOGIN} -eq 1 ]; then
	#grep ^PasswordAuthentication /etc/ssh/sshd_config | awk '{print $2}'
	if [ -z "`grep ^PasswordAuthentication /etc/ssh/sshd_config`" ]; then
	sed -i "s@^#PasswordAuthentication.*@&\nPasswordAuthentication no@" /etc/ssh/sshd_config
	else
	sed -i "s@^PasswordAuthentication.*@PasswordAuthentication no@" /etc/ssh/sshd_config
	fi
	echo -e "${GREEN_COLOR}Info:${RES} 禁用密码登录设置完毕!"
	#echo -e "Restart SSHd manually!"
fi

if [ ${DISABLE_PW_LOGIN} -eq 1 ]; then
	#grep ^StrictModes /etc/ssh/sshd_config | awk '{print $2}'
	if [ -z "`grep ^StrictModes /etc/ssh/sshd_config`" ]; then
		sed -i "s@^#StrictModes.*@&\nStrictModes no@" /etc/ssh/sshd_config
	else
		sed -i "s@^StrictModes.*@StrictModes no@" /etc/ssh/sshd_config
	fi
	echo -e "${GREEN_COLOR}Info:${RES} 关闭 StrictModes 设置完毕!"
	#echo -e "Restart SSHd manually!"
fi

if [ "${release}" = 'centos' ]; then
    echo -e ""
	service sshd restart
else
    echo -e ""
	/etc/init.d/ssh restart
fi
echo -e "${GREEN_COLOR}Info:${RES} 重新启动SSH服务成功!"
fi

echo -e "${GREEN_COLOR}Info:${RES} -----------------------"
get_ip

# Use default SSH port 22. If you use another SSH port on your server
if [ -e "/etc/ssh/sshd_config" ]; then
	[ -z "`grep ^Port /etc/ssh/sshd_config`" ] && ssh_port=22 || ssh_port=`grep ^Port /etc/ssh/sshd_config | awk '{print $2}'`
	while :; do echo
    	read -t 10 -p "请输入新的SSH端口（当前端口: $ssh_port): " SSH_PORT
    	[ -z "$SSH_PORT" ] && SSH_PORT=$ssh_port
    if [ $SSH_PORT -eq 22 >/dev/null 2>&1 -o $SSH_PORT -gt 1024 >/dev/null 2>&1 -a $SSH_PORT -lt 65535 >/dev/null 2>&1 ]; then
    	break
    else
		echo -e "${PINK}error:${RES} 输入错误！ 输入范围: 22,1025~65534"
    fi
  done

  if [ -z "`grep ^Port /etc/ssh/sshd_config`" -a "$SSH_PORT" != '22' ]; then
    sed -i "s@^#Port.*@&\nPort $SSH_PORT@" /etc/ssh/sshd_config
  elif [ -n "`grep ^Port /etc/ssh/sshd_config`" ]; then
    sed -i "s@^Port.*@Port $SSH_PORT@" /etc/ssh/sshd_config
  fi

	if [ "${release}" = 'centos' ]; then
        echo -e ""
		service sshd restart
	else
        echo -e ""
		/etc/init.d/ssh restart
	fi
	echo -e "${GREEN_COLOR}Info:${RES} 重新启动SSH服务成功!" && echo
#这里可以增加 防火墙 操作部分
	echo -e "${GREEN_COLOR}Info:${RES} 是否关闭防火墙并禁止自启动?菜鸟建议关闭，老手请自行修改防火墙策略[Y/n]"
	read -t 10 -p "(默认: y):" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ ${yn} == [Yy] ]]; then
		if [ "${release}" = "centos" ]; then
		chkconfig iptables off 2>/dev/null && service iptables stop 2>/dev/null
		systemctl disable firewalld 2>/dev/null && systemctl stop firewalld 2>/dev/null
		echo -e "${GREEN_COLOR}\nInfo:${RES} ${release} 防火墙关闭并禁止自启动（老手自理）"
		else
		apt-get -y remove iptables  #卸载命令
		apt-get -y remove --auto-remove iptables   #删除依赖包
		apt-get -y purge iptables   #清除规则
		apt-get -y purge --auto-remove iptables  #清除配置文件等等
		#echo  "${GREEN_COLOR}Info:${RES} ${release} 防火墙默认没安装，故此没有判断（老手自理）"
		systemctl stop firewalld
		systemctl disable firewalld
		fi
		if [ "${release}" = 'centos' ]; then
			service sshd restart
		else
			/etc/init.d/ssh restart
		fi
		echo -e "${GREEN_COLOR}Info:${RES} 重新启动SSHd成功!" && echo
	fi
fi

echo -e "${GREEN_COLOR}Info:${RES} 是否[取消显示]每次登陆提示的历史IP(lastlogin)？[Y/n]"
read -t 10 -p "(默认: y):" yn
[[ -z "${yn}" ]] && yn="y"
if [[ ${yn} == [Nn] ]]; then
	echo && echo -e "${GREEN_COLOR}Info:${RES} 跳过本设置..." && echo
else
	if [ -z "`grep ^PrintLastLog /etc/ssh/sshd_config`" ]; then
	sed -i "s@^#PrintLastLog.*@&\nPrintLastLog no@" /etc/ssh/sshd_config
	else
	sed -i "s@^PrintLastLog.*@PrintLastLog no@" /etc/ssh/sshd_config
	fi
if [ "${release}" = 'centos' ]; then
	service sshd restart
else
	/etc/init.d/ssh restart
fi
	echo -e "${GREEN_COLOR}Info:${RES} 不显示每次登陆显示的IP 设置完毕!"
	echo -e "${GREEN_COLOR}Info:${RES} 此功能可能需要重启系统才能生效!"
fi


echo -e "${GREEN_COLOR}Info:${RES} -----------------------"
echo
echo -e "${GREEN_COLOR}Info:${RES} 是否安装shell命令美化?[Y/n]"
read -t 10 -p "(默认: y):" yn
[[ -z "${yn}" ]] && yn="y"
if [[ ${yn} == [Yy] ]]; then
	SHELL_ZZH=1
	if [ "${release}" = "centos" ]; then
		yum -y install wget git #zsh
	else
		apt-get update -y
		apt-get -y install wget curl git #zsh
	fi
fi


if [ ${SHELL_ZZH} -eq 1 ]; then
	#chsh -s /bin/zsh
	#echo "${GREEN_COLOR}Info:${RES} 安装oh-my-zsh"
  	#sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
	echo "
-------------------------------------------------------------------------
Welcome back ! The server connection is successful !
-------------------------------------------------------------------------
	" > /etc/motd
	wget -O /usr/bin/screenfetch-dev https://blog.wxlost.com/one/code/onepve/ca/include/screenfetch-dev
	#wget -O /usr/bin/screenfetch-dev https://raw.githubusercontent.com/KittyKatt/screenFetch/master/screenfetch-dev
	chmod +x /usr/bin/screenfetch-dev
	#wget -O /etc/profile.d/logo.sh https://blog.wxlost.com/one/code/onepve/ca/include/logo.sh
	echo "screenfetch-dev" > /etc/profile.d/logo.sh
	clear
	#echo -e "${GREEN_COLOR}Info:${RES} 安装oh-my-zsh完毕"
	echo -e "${GREEN_COLOR}Info:${RES} 安装shell命令美化完毕,请重新连接ssh即可查看效果" && echo
# Custom profile
cat > /etc/profile.d/oneinstack.sh << EOF
HISTSIZE=10000
PS1="\[\e[37;40m\][\[\e[32;40m\]\u\[\e[37;40m\]@\h \[\e[35;40m\]\W\[\e[0m\]]\\\\$ "
HISTTIMEFORMAT="%F %T \$(whoami) "

alias l='ls -AFhlt'
alias lh='l | head'
alias vi=vim

GREP_OPTIONS="--color=auto"
alias grep='grep --color'
alias egrep='egrep --color'
alias fgrep='fgrep --color'
EOF

fi

#以下为我个人用的自定义

echo -e "${GREEN_COLOR}Info:${RES} Linux history 命令记录加执行时间戳以及记录到日志" && echo
[ -z "$(grep ^'PROMPT_COMMAND=' /etc/bashrc)" ] && cat >> /etc/bashrc << EOF
PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });logger "[euid=\$(whoami)]":\$(who am i):[\`pwd\`]"\$msg"; }'
EOF
echo -e "${GREEN_COLOR}Info:${RES} 配置 limits.conf (65535)" && echo
# /etc/security/limits.conf
[ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
sed -i '/^# End of file/,$d' /etc/security/limits.conf
cat >> /etc/security/limits.conf <<EOF
# End of file
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
EOF
echo -e "${GREEN_COLOR}Info:${RES} 工作完成,立即自毁.w(ﾟДﾟ)w" && echo
unlink $0
#!/bin/bash
#4/25/2023
#Abrahan Diaz
#Version 0.1 Alpha
#Wherever you are is where I want to be

#TODO
#3. Detect MegaRAID and VM for hdd and sdd
#4. PHP modules and versions installed
#5. Logging
#6. Detect if DB is even active before reading tables
#7. Need gather information about the database diretory
#8. Mysql governor
#9. cagefs which accounts
#10. php selector
 
#Preliminary

#Check if sudo
if [ "$EUID" -ne 0 ];then 
	echo "${RED}Not running as root!${NC}"
	exit 1
fi

RED='\033[0;31m'
GRE='\033[0;32m'
BLU='\033[0;34m'
YLW='\033[0;33m'
NC='\033[0m'
Date=$(date '+%m-%d-%y')

#Check if Cpanel is installed
if /usr/local/cpanel/cpanel -V &>/dev/null;then
	:
else
	echo -e "${RED}Cpanel is not installed!${NC}"
	exit 1
fi

#Create directory for all relevant data
if [[ -d "~/migration-$Date" ]];then
	cd ~/migration-$Date
else
	mkdir ~/migration-$Date
	cd ~/migration-$Date
fi

touch accounts.info
touch database.info
touch versions.info
touch drive.info

#Check OS
echo -e "${BLU}======>OPERATING SYSTEM<======${NC}"
if grep -q "ubuntu" $(find /etc -iname "os*release");then 
	os=ubuntu
	echo -e "$(find /etc -iname "os*release" -exec grep -i "pretty.name" {} \; | awk -F= '{print $2}' | tr -d '"')"
elif find /etc -iname "redhat*release" &>/dev/null;then
	if egrep -qi "almalinux" /etc/redhat*release;then
		os="almalinux"
		echo -e "$(cat /etc/redhat*release)"
	elif egrep -qi "centos" /etc/redhat*release;then
		os="centos"
		echo -e "$(cat /etc/redhat*release)"
	elif egrep -qi "cloudlinux" /etc/redhat*release;then
		os="cloudlinux"
		echo -e "$(cat /etc/redhat*release)"
	elif egrep -qi "rockylinux" /etc/redhat*release;then
		os="rockylinux"
		echo -e "$(cat /etc/redhat*release)"
	elif egrep -qi "red.{1,3}hat" /etc/redhat*release;then
		os="redhat"
		echo -e "$(cat /etc/redhat*release)"
	fi
else
	echo "Unsupported OS!"
	exit 1
fi

#Install tools
if [[ $os = "ubuntu" ]];then
	apt update -y &>/dev/null && apt install smartmontools dmidecode lshw util-linux &>/dev/null
elif [ $os = "almalinux" ] || [ $os = "centos" ] || [ $os = "rockylinux" ] || [ $os = "cloudlinux" ];then
	yum install smartmontools dmidecode lswh util-linux -y &>/dev/null
else
	dnf install smartmontools dmidecode lshw util-linux -y &>/dev/null
fi

#Drive Information
drives(){
echo -e "${BLU}======>DRIVE STATS<======${NC}"
	if smartctl --scan | grep -i "megaraid";then
		echo -e "${RED}Hardware RAID was detected!${NC}"
		echo "BEGIN HW DRIVE SCAN"
		for drive in $(smartctl --scan | egrep -i "megaraid" | awk '{print $3}');do 
			echo -e "Drive: $drive "
			echo -e "Health:"
			smartctl -a -d $drive /dev/sda | grep "^  1\|^  5\|^ 10\|^184\|^187\|^188\|^196\|^197\|^198\|^201"
		done
		echo "END HW DRIVE SCAN"
	fi
	for drive in $(smartctl --scan | awk '{print $1}');do 
		echo -e "Drive: $drive "
		echo -e "Health:"
		smartctl -a $drive | grep "^  1\|^  5\|^ 10\|^184\|^187\|^188\|^196\|^197\|^198\|^201"
		echo -e "\nParitions"
		echo "Usage:"
		df -Th | egrep "$drive" | awk '{printf "%s: Type: %s Size: %s Used: %s %s Free: %s Mnt: %s\n", $1 , $2, $3, $4, $6, $5, $7}'	
		echo "Inode usage:"
		df -ih | egrep "$drive" | awk '{print $1": "$5}'
	done
}

#Versions
versions(){
	echo -e "${BLU}======>VERSIONS<======${NC}"
	if  lsof -i TCP:443 | grep -iq "httpd" || lsof -i TCP:80 | grep -iq "httpd" ;then
		echo -e "Apache is running\n"
		httpd -v 2>/dev/null || apache2 -v 2>/dev/null
	fi
	if  lsof -i TCP:443 | grep -iq "nginx" || lsof -i TCP:80 | grep -iq "nginx" ;then
		echo -e "Nginx is running\n"
		nginx -v
	fi
	if  lsof -i TCP:443 | grep -iq "lshttp" || lsof -i TCP:80 | grep -iq "lshttp" ;then
		echo -e "LiteSpeed is running\n"
		lshttpd -v
	fi
	if ps aux | grep -v "grep" | egrep -qi "bin.mysql|bin.mariadb";then
		echo -e "MySQL/MariaDB is running\n"
		mysql --version
	fi
	if ps aux | grep -v "grep" | egrep -qi "bin.psql";then
		echo -e "PostgreSQL is running\n"
		postgres -V
	fi
	if ps aux | grep -v "grep" | egrep -qi "bin.mongo"; then
		echo -e "MongoDB is running\n"
		mongod -version
	fi
	if ps aux | grep -v "grep" | egrep -qi "bin.kcar"; then
		echo -e "KernelCare is running\n"
		kcarectl --info
	fi
}

#DOMAINS
accounts(){
	echo -e "${BLU}======>DOMAINS<======${NC}"
	for acc in $(/usr/local/cpanel/bin/whmapi1 --output=jsonpretty   listaccts 2>/dev/null | grep user | awk '{print $3}' | sed 's/[",]//g');do
        
		adom=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep "domain:" | awk '{print $2}' )
        aip=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep "ip:" | awk '{print $2}')
        asus=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep " suspended:" | awk '{print $2}')
		ahome=$(grep "documentroot:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
		assl=$(grep "ssl_redirect:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
		aphp=$(grep "phpversion:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')

        echo -e "${YLW}++++++$adom++++++${NC}"
		#Load
        if curl -sIL $adom | egrep -q "HTTP.{3,5} 200 OK";then
            echo -e "${GRE}$adom loads 200${NC}"
        else
            echo -e "${RED}$adom did not load${NC}"
        fi
		#SSL
		if [[ $assl -eq "1" ]];then
			echo -e "${GRE}SSL redirect enabled${NC}"
			curlout=$(curl -svL $adom 2>&1)
	        if echo $curlout | egrep -q "SSL certificate verify ok";then
				echo -e "${GRE}$adom SSL is good, expires: $(echo $curlout | egrep -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}"
			else
				echo -e "${RED}$adom SSL not working${NC}"
			fi
		else
			echo -e "${RED}SSL redirect disabled${NC}"
		fi
		#PHP
		echo -e "PHP version: $aphp"
		#DNS
        echo -e "Domain Cpanel IP: $aip"
        echo -e "A record: $(dig @8.8.8.8 A $adom +short | paste -sd" ")"
        echo -e "NS record: $(dig @8.8.8.8 NS $adom +short | paste -sd" ")"

	done
}

#DATABASES
database(){
	echo -e "${BLU}======>DATABASES<======${NC}"
	for db in $(mysql -e "SHOW DATABASES;"| awk 'NR != 1 && $1 != "information_schema" && $1 != "performance_schema" && $1 != "mysql" && $1 != "sys"{print $1}');do
		echo -e "${YLW}++++++$db++++++${NC}"
		for tb in $(mysql -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE \"$db\";" | awk 'NR != 1 {print $1}');do
			if mysql -e "SELECT * FROM $db.$tb LIMIT 10;" &>/dev/null;then
				echo -e "Database: $db Table: $tb reads"
			else
				echo -e "Database: $db Table: $tb did not read"
			fi
		done
	done
}

#Virtual Machine
#Detect VM OS
virtual(){
	isVirt=false
	if dmidecode -s system-manufacturer | egrep -qi "innotek|GmbH|QEMU";then
		isVirt=true
	fi
	if dmidecode -s system-product-name | egrep -qi "Virtual|Standard PC";then
		isVirt=true
	fi
	if lscpu | egrep -qi "Hypervisor vendor: [a-z]+";then
		isVirt=true
	fi
	if lshw -class system | egrep -qi "innotek|GmbH|QEMU";then
		isVirt=true
	fi
	if $isVirt;then
		echo -e "${RED}Virtual Machine has been detected!${NC}"
	fi
}

virtual
drives
versions
accounts
database

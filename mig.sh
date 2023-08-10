#!/bin/bash
#4/25/2023
#Abe Diaz
#Version 0.9
#Wherever you are is where I want to be

#TODO
#cl logic check /var/cagefs/*/*/etc/cl.selector | /var/cagefs/*/*/etc/cl.php.d

#Global variables
RED='\033[0;31m'
GRE='\033[0;32m'
BLU='\033[0;34m'
YLW='\033[0;33m'
NC='\033[0m'
Date=$(date '+%m-%d-%y')

#Preliminary
#Check if sudo
if [ "$EUID" -ne 0 ];then
        echo -e "${RED}Not root!${NC}" 1>&2
        exit 1
fi

#Check if Cpanel is installed
if /usr/local/cpanel/cpanel -V &>/dev/null;then
        :
else
        echo -e "${RED}Cpanel not installed!${NC}" 1>&2
        exit 1
fi

basic(){
        #Create directory for all relevant data
        if [[ -d "~/migration-$Date" ]];then
                cd ~/migration-$Date
        else
                mkdir ~/migration-$Date
                cd ~/migration-$Date
        fi

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
                echo -e "${RED}Unsupported OS!${NC}"
                exit 1 1>&2
        fi

        #VM check
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

        #Install tools
        if [[ $os = "ubuntu" ]];then
                apt update -y &>/dev/null && apt install smartmontools dmidecode lshw util-linux &>/dev/null
        elif [ $os = "almalinux" ] || [ $os = "centos" ] || [ $os = "rockylinux" ] || [ $os = "cloudlinux" ];then
                yum install smartmontools dmidecode lswh util-linux -y &>/dev/null
        else
                dnf install smartmontools dmidecode lshw util-linux -y &>/dev/null
        fi
}

#Drive Information
drives(){
        left=$(df -Th)
        echo -e "${BLU}======>DRIVE STATS<======${NC}"
        if smartctl --scan | grep -i "megaraid";then
                echo -e "${RED}Hardware RAID was detected!${NC}"
                echo "BEGIN HW DRIVE SCAN"
                for drive in $(smartctl --scan | egrep -i "megaraid" | awk '{print $3}');do
                        echo -e "Drive: $drive "
                        echo "Health:"
                        smartctl -a -d $drive /dev/sda | grep "^  1\|^  5\|^ 10\|^184\|^187\|^188\|^196\|^197\|^198\|^201"
                done
                echo "END HW DRIVE SCAN"
        fi
        for drive in $(smartctl --scan | awk '{print $1}');do
                left=$(echo -e "$left"| egrep -v "$drive")
                echo -e "Drive: $drive "
                echo "Health:"
                smartctl -a $drive | grep "^  1\|^  5\|^ 10\|^184\|^187\|^188\|^196\|^197\|^198\|^201"
                echo -e "\nParitions"
                echo "Usage:"
                df -Th | egrep "$drive" | awk '{printf "%s: Type: %s Size: %s Used: %s %s Free: %s Mnt: %s\n", $1 , $2, $3, $4, $6, $5, $7}'
                echo "Inode usage:"
                df -ih | egrep "$drive" | awk '{print $1": "$5}'
                echo
        done
        echo "LEFT OVER PARTITIONS:"
        echo "$left" | grep -v "tempfs"
}

#Versions
versions(){
        echo -e "${BLU}======>VERSIONS<======${NC}"
        if  lsof -i TCP:443 | grep -iq "httpd" || lsof -i TCP:80 | grep -iq "httpd" ;then
                echo -e "\nApache is running"
                httpd -v 2>/dev/null || apache2 -v 2>/dev/null
        fi
        if  lsof -i TCP:443 | grep -iq "nginx" || lsof -i TCP:80 | grep -iq "nginx" ;then
                echo -e "\nNginx is running"
                nginx -v
        fi
        if  lsof -i TCP:443 | grep -iq "lshttp" || lsof -i TCP:80 | grep -iq "lshttp" ;then
                echo -e "\nLiteSpeed is running"
                lshttpd -v
        fi
        if ps aux | grep -v "grep" | egrep -qi "bin.mysql|bin.mariadb";then
                echo -e "\nMySQL/MariaDB is running"
                mysql --version
        fi
        if ps aux | grep -v "grep" | egrep -qi "bin.psql";then
                echo -e "\nPostgreSQL is running"
                postgres -V
        fi
        if ps aux | grep -v "grep" | egrep -qi "bin.mongo"; then
                echo -e "\nMongoDB is running"
                mongod -version
        fi
        if ps aux | grep -v "grep" | egrep -qi "bin.kcar"; then
                echo -e "\nKernelCare is running"
                kcarectl --info
        fi
}

#DOMAINS
accounts(){
        echo -e "${BLU}======>DOMAINS<======${NC}" | tee -a accounts.info
        for acc in $(/usr/local/cpanel/bin/whmapi1 --output=jsonpretty   listaccts 2>/dev/null | grep user | awk '{print $3}' | sed 's/[",]//g');do
                adom=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep "domain:" | awk '{print $2}')
        aip=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep "ip:" | awk '{print $2}')
        asus=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep " suspended:" | awk '{print $2}')
                ahome=$(grep "documentroot:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
                assl=$(grep "ssl_redirect:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
                aphp=$(grep "phpversion:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
        echo -e "${GRE}++++++$acc++++++${NC}"
                #Load
        if curl -vL $adom 2>&1 | egrep -q "HTTP.{2,5} 200";then
            echo -e "${GRE}$adom loads 200${NC}" >> accounts.info
        else
                        echo -e "${YLW}====>Main: $adom${NC}" | tee -a accounts.info
            echo -e "${RED}$adom did not load${NC}"| tee -a accounts.info
        fi
                #SSL
                if [[ $assl -eq "1" ]];then
                        echo -e "${GRE}SSL redirect enabled${NC}" >> accounts.info
                        curlout=$(curl -svL $adom 2>&1)
                if echo "$curlout" | egrep -q "SSL certificate verify ok";then
                                echo -e "${GRE}$adom SSL is good, expires: $(echo "$curlout" | egrep -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}" >> accounts.info
                        else
                                echo -e "${RED}$adom SSL not working${NC}"| tee -a accounts.info
                        fi
                else
                        echo -e "${RED}SSL redirect disabled${NC}"| tee -a accounts.info
                fi
                #PHP
                echo -e "PHP version: $aphp" >> accounts.info
                #DNS
                echo -e "Domain Cpanel IP: $aip" >> accounts.info
        echo -e "A record: $(dig @8.8.8.8 A $adom +short | paste -sd" ")" >> accounts.info
        echo -e "NS record: $(dig @8.8.8.8 NS $adom +short | paste -sd" ")" >> accounts.info
                #Account subdomains
                for asub in $(grep "^  - " /var/cpanel/userdata/$acc/main | awk '{print $2}');do
                        shome=$(grep "documentroot:" /var/cpanel/userdata/$acc/$asub | awk '{print $2}')
                        sssl=$(grep "ssl_redirect:" /var/cpanel/userdata/$acc/$asub | awk '{print $2}')
                        sphp=$(grep "phpversion:" /var/cpanel/userdata/$acc/$asub | awk '{print $2}')
                        sip=$(grep "ip:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
                        #Load
						if curl -vL $asub 2>&1 | egrep -q "HTTP.{2,5} 200";then
                                echo -e "${GRE}$asub loads 200${NC}" >> accounts.info
                        else
                                echo -e "${YLW}====>Sub: $asub${NC}"| tee -a accounts.info
                                echo -e "${RED}$asub did not load${NC}"| tee -a accounts.info
                        fi
                        #SSL
                        if [[ $sssl -eq "1" ]];then
                                echo -e "${GRE}SSL redirect enabled${NC}" >> accounts.info
                                scurlout=$(curl -svL $asub 2>&1)
                                if echo "$scurlout" | egrep -q "SSL certificate verify ok";then
                                        echo -e "${GRE}$asub SSL is good, expires: $(echo "$scurlout" | egrep -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}" >> accounts.info
                                else
                                        echo -e "${RED}$asub SSL not working${NC}"| tee -a accounts.info
                                fi
                        else
                                echo -e "${RED}SSL redirect disabled${NC}"| tee -a accounts.info
                        fi
                        #PHP
                        echo -e "PHP version: $sphp" >> accounts.info
                        #DNS
                        echo -e "Domain Cpanel IP: $aip" >> accounts.info
                        echo -e "A record: $(dig @8.8.8.8 A $asub +short | paste -sd" ")" >> accounts.info
                        echo -e "NS record: $(dig @8.8.8.8 NS $asub +short | paste -sd" ")" >> accounts.info
                done
        done
}

#DOMAINS Extensive
accounts_ext(){
        echo -e "${BLU}======>DOMAINS<======${NC}"
        for acc in $(/usr/local/cpanel/bin/whmapi1 --output=jsonpretty   listaccts 2>/dev/null | grep user | awk '{print $3}' | sed 's/[",]//g');do
                adom=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep "domain:" | awk '{print $2}')
        aip=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep "ip:" | awk '{print $2}')
        asus=$(/usr/local/cpanel/bin/whmapi1 accountsummary user=$acc 2>/dev/null | grep " suspended:" | awk '{print $2}')
                ahome=$(grep "documentroot:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
                assl=$(grep "ssl_redirect:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
                aphp=$(grep "phpversion:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
        echo -e "${GRE}++++++$acc++++++${NC}"
                #Load
                echo -e "${YLW}====>Main: $adom${NC}"
		if curl -vL $adom 2>&1 | egrep -q "HTTP.{2,5} 200";then
            echo -e "${GRE}$adom loads 200${NC}"
        else
            echo -e "${RED}$adom did not load${NC}"
        fi
                #SSL
                if [[ $assl -eq "1" ]];then
                        echo -e "${GRE}SSL redirect enabled${NC}"
                        curlout=$(curl -svL $adom 2>&1)
                if echo "$curlout" | egrep -q "SSL certificate verify ok";then
                                echo -e "${GRE}$adom SSL is good, expires: $(echo "$curlout" | egrep -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}"
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
                #Account subdomains
                for asub in $(grep "^  - " /var/cpanel/userdata/$acc/main | awk '{print $2}');do
                        shome=$(grep "documentroot:" /var/cpanel/userdata/$acc/$asub | awk '{print $2}')
                        sssl=$(grep "ssl_redirect:" /var/cpanel/userdata/$acc/$asub | awk '{print $2}')
                        sphp=$(grep "phpversion:" /var/cpanel/userdata/$acc/$asub | awk '{print $2}')
                        sip=$(grep "ip:" /var/cpanel/userdata/$acc/$adom | awk '{print $2}')
                        #Load
                        echo -e "${YLW}====>Sub: $asub${NC}"
						if curl -vL $asub 2>&1 | egrep -q "HTTP.{2,5} 200";then
                                echo -e "${GRE}$asub loads 200${NC}"
                        else
                                echo -e "${RED}$asub did not load${NC}"
                        fi
                        #SSL
                        if [[ $sssl -eq "1" ]];then
                                echo -e "${GRE}SSL redirect enabled${NC}"
                                scurlout=$(curl -svL $asub 2>&1)
                                if echo "$scurlout" | egrep -q "SSL certificate verify ok";then
                                        echo -e "${GRE}$asub SSL is good, expires: $(echo "$scurlout" | egrep -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}"
                                else
                                        echo -e "${RED}$asub SSL not working${NC}"
                                fi
                        else
                                echo -e "${RED}SSL redirect disabled${NC}"
                        fi
                        #PHP
                        echo -e "PHP version: $sphp"
                        #DNS
                        echo -e "Domain Cpanel IP: $aip"
                        echo -e "A record: $(dig @8.8.8.8 A $asub +short | paste -sd" ")"
                        echo -e "NS record: $(dig @8.8.8.8 NS $asub +short | paste -sd" ")"
                done
        done
}

#DATABASES
database(){
        echo -e "${BLU}======>DATABASES<======${NC}"
        if mysql -e "SHOW DATABASES;" &>/dev/null;then
                :
        else
                echo -e "${RED}MySQL/MariaDB not active or not accsseible via root without password. Skipping database checking!${NC}" 1>&2
                return
        fi
        if grep -q "datadir=" /etc/my.cnf;then
                ddir=$(grep "datadir=" /etc/my.cnf | awk -F= '{print $2}')
        else
                ddir="/var/lib/mysql"
        fi
        echo -e "Databse location: $ddir"
        dsize=$(du -s $ddir | awk '{print $1}')
        if [[ $dsize -gt 20000000 ]];then
                echo -e "Database Size:${RED} $(echo "$dsize" | awk '$1/1024 > 1000{printf "%.2fGB\n", $1/(1000*1024)}$1/1024 < 1000{printf "%.2fMB\n", $1/1024}')"
        else
                echo -e "Database Size:${GRE} $(echo "$dsize" | awk '$1/1024 > 1000{printf "%.2fGB\n", $1/(1000*1024)}$1/1024 < 1000{printf "%.2fMB\n", $1/1024}')${NC}"
        fi
        for db in $(mysql -e "SHOW DATABASES;"| awk 'NR != 1 && $1 != "information_schema" && $1 != "performance_schema" && $1 != "mysql" && $1 != "sys"{print $1}');do
                for tb in $(mysql -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE \"$db\";" | awk 'NR != 1 {print $1}');do
                        if mysql -e "SELECT * FROM $db.$tb LIMIT 10;" &>/dev/null;then
                                echo -e "Database: $db Table: $tb ${GRE}good${NC}" >> database.info
                        else
                                echo -e "${YLW}++++++$db++++++${NC}" >> database.info
                                echo -e "Database: $db Table: $tb  ${RED}bad${NC}" >> database.info
                        fi
                done
        done
}

#Pull various configuration
config(){
        /usr/local/cpanel/bin/cpconftool --modules=cpanel::smtp::exim,cpanel::system::backups,cpanel::system::whmconf,cpanel::easy::apache, --backup 2>/dev/null
        cp /etc/my.cnf ./my.cnf.back
        echo -e "${BLU}======>PHP<======${NC}"
        for php in $(whmapi1  php_get_handlers 2>/dev/null | grep "version: .*php" | awk '{print $2}');do
                printf "$php Handler"
                whmapi1  php_get_handlers  2>/dev/null | egrep -B 1 "$php" | grep "current_handler:" | awk '{print $2}'
                if echo -e "$php" | grep -q "alt-php";then continue ;fi
                echo -e "_________$php_________" >> php.modules
                /opt/cpanel/$php/root/usr/bin/php -m  2>/dev/null | egrep "^[a-zA-Z]" >> php.modules
        done
}

if [[ $1 == "" ]];then
        basic
        cd ~/migration-$Date
        config
        drives | tee -a drive.info
        versions | tee -a versions.info
        accounts
        database | tee -a database.info
        exit
fi

while getopts "asdh" opt; do
        case $opt in
                a)
                        basic
                        cd ~/migration-$Date
                        config
                        drives | tee -a drive.info
                        versions | tee -a versions.info
                        accounts
                        database | tee -a database.info
                        ;;
                s)
                        account
                        ;;
                d)
                        database | tee -a accounts.info
                        ;;
                h)
                        cat << EOF
        -a All checks, same as no argument.

        -s Check only domains(extensive output)

        -d Check only databases.

        -h Display help
EOF
                        ;;
                \?)
                        exit 1
                        ;;
        esac
done

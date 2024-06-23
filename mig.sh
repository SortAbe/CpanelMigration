#!/bin/bash
#4/25/2023
#Abe Diaz
#Version 0.95
#Wherever you are is where I want to be

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
    if [[ -d "./migration-$Date" ]];then
        cd ./migration-"$Date" || exit 1
    else
        mkdir ./migration-"$Date"
        cd ./migration-"$Date" || exit 1
    fi

    #Check OS
    echo -e "${BLU}======>OPERATING SYSTEM<======${NC}"
    if grep -q "ubuntu" "$(find /etc -iname "os*release")";then
        os=ubuntu
        echo -e "$(find /etc -iname "os*release" -exec grep -i "pretty.name" {} \; | gawk -F= '{print $2}' | tr -d '"')"
        elif find /etc -iname "redhat*release" &>/dev/null;then
        if grep -Eqi "almalinux" /etc/redhat*release;then
            os="almalinux"
            echo -e "$(cat /etc/redhat*release)"
            elif grep -Eqi "centos" /etc/redhat*release;then
            os="centos"
            echo -e "$(cat /etc/redhat*release)"
            elif grep -Eqi "cloudlinux" /etc/redhat*release;then
            os="cloudlinux"
            echo -e "$(cat /etc/redhat*release)"
            elif grep -Eqi "rockylinux" /etc/redhat*release;then
            os="rockylinux"
            echo -e "$(cat /etc/redhat*release)"
            elif grep -Eqi "red.{0,3}hat" /etc/redhat*release;then
            os="redhat"
            echo -e "$(cat /etc/redhat*release)"
        fi
    else
        echo -e "${RED}Unsupported OS!${NC}"
        exit 1 1>&2
    fi

    #VM check
    virtual_machine=false
    if dmidecode -s system-manufacturer | grep -Eqi "innotek|GmbH|QEMU";then
        virtual_machine=true
    fi
    if dmidecode -s system-product-name | grep -Eqi "Virtual|Standard PC";then
        virtual_machine=true
    fi
    if lscpu | grep -Eqi "Hypervisor vendor: [a-z]+";then
        virtual_machine=true
    fi
    if lshw -class system | grep -Eqi "innotek|GmbH|QEMU";then
        virtual_machine=true
    fi
    if $virtual_machine;then
        echo -e "${RED}Virtual Machine has been detected!${NC}"
    fi

    #Install tools
    if [ "$os" = "ubuntu" ];then
        apt update -y &>/dev/null && apt install smartmontools dmidecode lshw util-linux -y &>/dev/null
    elif [ "$os" = "almalinux" ] || [ "$os" = "centos" ] || [ "$os" = "rockylinux" ] || [ "$os" = "cloudlinux" ];then
        yum install smartmontools -y &>/dev/null
        yum install dmidecode -y &>/dev/null
        yum install lswh -y &>/dev/null
        yum install util-linux -y &>/dev/null
        yum install python3 -y &>/dev/null
        pip3 install requests &>/dev/null
    else
        dnf install smartmontools -y &>/dev/null
        dnf install dmidecode -y &>/dev/null
        dnf install lswh -y &>/dev/null
        dnf install util-linux -y &>/dev/null
        dnf install python3 -y &>/dev/null
        pip3 install requests &>/dev/null
    fi
    echo
}

#Drive Information
drives(){
    remaining=$(df -Th)
    echo -e "${BLU}======>DRIVE STATS<======${NC}"
    if smartctl --scan | grep -i "megaraid";then
        echo -e "${RED}Hardware RAID was detected!${NC}"
        echo "BEGIN HW DRIVE SCAN"
        for drive in $(smartctl --scan | grep -E  -i "megaraid" | gawk '{print $3}');do
            echo -e "Drive: $drive "
            echo "Health:"
            smartctl -a -d "$drive" /dev/sda | grep "^  1\|^  5\|^ 10\|^184\|^187\|^188\|^196\|^197\|^198\|^201"
        done
        echo "END HW DRIVE SCAN"
    fi
    for drive in $(smartctl --scan | gawk '{print $1}');do
        remaining=$(echo -e "$remaining"| grep -E  -v "$drive")
        echo -e "Drive: $drive "
        echo "Health:"
        smartctl -a "$drive" | grep "^  1\|^  5\|^ 10\|^184\|^187\|^188\|^196\|^197\|^198\|^201"
        echo -e "\nParitions"
        echo "Usage:"
        df -Th | grep -E  "$drive" | gawk '{printf "%s: Type: %s Size: %s Used: %s %s Free: %s Mnt: %s\n", $1 , $2, $3, $4, $6, $5, $7}'
        echo "Inode usage:"
        df -ih | grep -E  "$drive" | gawk '{print $1": "$5}'
        echo
    done
    echo "REMAINING PARTITIONS:"
    echo "$remaining" | grep -v "tempfs"
    echo
}

#Versions
versions(){
    echo -e "${BLU}======>VERSIONS<======${NC}"
    if  lsof -i TCP:443 | grep -iq "httpd" || lsof -i TCP:80 | grep -iq "httpd" ;then
        echo -e "Apache is running"
        httpd -v 2>/dev/null || apache2 -v 2>/dev/null
        echo
    fi
    if  lsof -i TCP:443 | grep -iq "nginx" || lsof -i TCP:80 | grep -iq "nginx" ;then
        echo -e "Nginx is running"
        nginx -v
        echo
    fi
    if  lsof -i TCP:443 | grep -iq "lshttp" || lsof -i TCP:80 | grep -iq "lshttp" ;then
        echo -e "LiteSpeed is running"
        lshttpd -v
        echo
    fi
    if pgrep -i "mysql" &>/dev/null;then
        echo -e "MySQL or MariaDB is running"
        mysql --version || mariadb --version
        echo
    fi
    if pgrep -i "mariadb" &>/dev/null;then
        echo -e "MariaDB is running"
        mysql --version || mariadb --version
        echo
    fi
    if pgrep -i "postgres" &>/dev/null;then
        echo -e "PostgreSQL is running"
        postgres -V
        echo
    fi
    if pgrep -i "mongo" &>/dev/null; then
        echo -e "MongoDB is running"
        mongod -version
        echo
    fi
    if pgrep -i "kcar" &>/dev/null;then
        echo -e "KernelCare is running"
        kcarectl --info
        echo
    fi
}

#DOMAINS
domain_check(){
    echo -e "${BLU}======>DOMAINS<======${NC}" | tee -a accounts.info
    echo -e "${YLW}Only domains with errors or warnings appear here!${NC}"
    ~/CpanelMigration/domain_check.py | tee -a accounts.info
    echo
}

#DOMAINS
#DEPERCATED
#Might role features into other domain check in the future.
accounts(){
    echo -e "${BLU}======>DOMAINS<======${NC}" | tee -a accounts.info
    for acc in $(/usr/local/cpanel/bin/whmapi1 --output=jsonpretty   listaccts 2>/dev/null | grep user | gawk '{print $3}' | sed 's/[",]//g');do
        adom=$(/usr/local/cpanel/bin/whmapi1 accountsummary user="$acc" 2>/dev/null | grep "domain:" | gawk '{print $2}')
        aip=$(/usr/local/cpanel/bin/whmapi1 accountsummary user="$acc" 2>/dev/null | grep "ip:" | gawk '{print $2}')
        assl=$(grep "ssl_redirect:" /var/cpanel/userdata/"$acc"/"$adom" | gawk '{print $2}')
        aphp=$(grep "phpversion:" /var/cpanel/userdata/"$acc"/"$adom" | gawk '{print $2}')
        echo -e "${GRE}++++++$acc++++++${NC}"
        #Load
        if curl -vL "$adom" 2>&1 | grep -E  -q "HTTP.{2,5} 200";then
            echo -e "${GRE}$adom loads 200${NC}" >> accounts.info
        else
            echo -e "${YLW}====>Main: $adom${NC}" | tee -a accounts.info
            echo -e "${RED}$adom did not load${NC}"| tee -a accounts.info
        fi
        #SSL
        if [[ $assl -eq "1" ]];then
            echo -e "${GRE}SSL redirect enabled${NC}" >> accounts.info
            curlout=$(curl -svL "$adom" 2>&1)
            if echo "$curlout" | grep -E  -q "SSL certificate verify ok";then
                echo -e "${GRE}$adom SSL is good, expires: $(echo "$curlout" | grep -E  -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}" >> accounts.info
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
        echo -e "A record: $(dig @8.8.8.8 A "$adom" +short | paste -sd" ")" >> accounts.info
        echo -e "NS record: $(dig @8.8.8.8 NS "$adom" +short | paste -sd" ")" >> accounts.info
        #Account subdomains
        for asub in $(grep "^  - " /var/cpanel/userdata/"$acc"/main | gawk '{print $2}');do
            sssl=$(grep "ssl_redirect:" /var/cpanel/userdata/"$acc"/"$asub" | gawk '{print $2}')
            sphp=$(grep "phpversion:" /var/cpanel/userdata/"$acc"/"$asub" | gawk '{print $2}')
            #Load
            if curl -vL "$asub" 2>&1 | grep -E  -q "HTTP.{2,5} 200";then
                echo -e "${GRE}$asub loads 200${NC}" >> accounts.info
            else
                echo -e "${YLW}====>Sub: $asub${NC}"| tee -a accounts.info
                echo -e "${RED}$asub did not load${NC}"| tee -a accounts.info
            fi
            #SSL
            if [[ $sssl -eq "1" ]];then
                echo -e "${GRE}SSL redirect enabled${NC}" >> accounts.info
                scurlout=$(curl -svL "$asub" 2>&1)
                if echo "$scurlout" | grep -E  -q "SSL certificate verify ok";then
                    echo -e "${GRE}$asub SSL is good, expires: $(echo "$scurlout" | grep -E  -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}" >> accounts.info
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
            echo -e "A record: $(dig @8.8.8.8 A "$asub" +short | paste -sd" ")" >> accounts.info
            echo -e "NS record: $(dig @8.8.8.8 NS "$asub" +short | paste -sd" ")" >> accounts.info
        done
    done
}

#DOMAINS Extensive
#DEPERCATED
accounts_ext(){
    echo -e "${BLU}======>DOMAINS<======${NC}"
    for acc in $(/usr/local/cpanel/bin/whmapi1 --output=jsonpretty   listaccts 2>/dev/null | grep user | gawk '{print $3}' | sed 's/[",]//g');do
        adom=$(/usr/local/cpanel/bin/whmapi1 accountsummary user="$acc" 2>/dev/null | grep "domain:" | gawk '{print $2}')
        aip=$(/usr/local/cpanel/bin/whmapi1 accountsummary user="$acc" 2>/dev/null | grep "ip:" | gawk '{print $2}')
        assl=$(grep "ssl_redirect:" /var/cpanel/userdata/"$acc"/"$adom" | gawk '{print $2}')
        aphp=$(grep "phpversion:" /var/cpanel/userdata/"$acc"/"$adom" | gawk '{print $2}')
        echo -e "${GRE}++++++$acc++++++${NC}"
        #Load
        echo -e "${YLW}====>Main: $adom${NC}"
        if curl -vL "$adom" 2>&1 | grep -E  -q "HTTP.{2,5} 200";then
            echo -e "${GRE}$adom loads 200${NC}"
        else
            echo -e "${RED}$adom did not load${NC}"
        fi
        #SSL
        if [[ $assl -eq "1" ]];then
            echo -e "${GRE}SSL redirect enabled${NC}"
            curlout=$(curl -svL "$adom" 2>&1)
            if echo "$curlout" | grep -E  -q "SSL certificate verify ok";then
                echo -e "${GRE}$adom SSL is good, expires: $(echo "$curlout" | grep -E  -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}"
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
        echo -e "A record: $(dig @8.8.8.8 A "$adom" +short | paste -sd" ")"
        echo -e "NS record: $(dig @8.8.8.8 NS "$adom" +short | paste -sd" ")"
        #Account subdomains
        for asub in $(grep "^  - " /var/cpanel/userdata/"$acc"/main | gawk '{print $2}');do
            sssl=$(grep "ssl_redirect:" /var/cpanel/userdata/"$acc"/"$asub" | gawk '{print $2}')
            sphp=$(grep "phpversion:" /var/cpanel/userdata/"$acc"/"$asub" | gawk '{print $2}')
            #Load
            echo -e "${YLW}====>Sub: $asub${NC}"
            if curl -vL "$asub" 2>&1 | grep -E  -q "HTTP.{2,5} 200";then
                echo -e "${GRE}$asub loads 200${NC}"
            else
                echo -e "${RED}$asub did not load${NC}"
            fi
            #SSL
            if [[ $sssl -eq "1" ]];then
                echo -e "${GRE}SSL redirect enabled${NC}"
                scurlout=$(curl -svL "$asub" 2>&1)
                if echo "$scurlout" | grep -E  -q "SSL certificate verify ok";then
                    echo -e "${GRE}$asub SSL is good, expires: $(echo "$scurlout" | grep -E  -o "expire date:.+20[0-9]{2} [A-Z]{2,4}" | sed 's/expire date://' )${NC}"
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
            echo -e "A record: $(dig @8.8.8.8 A "$asub" +short | paste -sd" ")"
            echo -e "NS record: $(dig @8.8.8.8 NS "$asub" +short | paste -sd" ")"
        done
    done
}

#DATABASES
database(){
    echo -e "${BLU}======>DATABASES<======${NC}"
    if mysql -e "SHOW DATABASES;" &>/dev/null;then
        :
    else
        echo -e "${RED}MySQL/MariaDB is not active or not accsseible via root without password. Skipping database checking!${NC}" 1>&2
        return
    fi
    if grep -q "datadir=" /etc/my.cnf;then
        data_directory=$(grep "datadir=" /etc/my.cnf | gawk -F= '{print $2}')
    else
        data_directory="/var/lib/mysql"
    fi
    echo -e "Databse location: $data_directory"
    directory_size=$(du -s "$data_directory" | gawk '{print $1}')
    if [[ $directory_size -gt 20000000 ]];then
        echo -e "Database Size:${RED} $(echo "$directory_size" | gawk ' $1/1024 > 1000{printf "%.2fGB\n", $1/(1000*1024)} $1/1024 < 1000{printf "%.2fMB\n", $1/1024}')${NC}"
    else
        echo -e "Database Size:${GRE} $(echo "$directory_size" | gawk ' $1/1024 > 1000{printf "%.2fGB\n", $1/(1000*1024)} $1/1024 < 1000{printf "%.2fMB\n", $1/1024}')${NC}"
    fi
    for db in $(mysql -e "SHOW DATABASES;"| gawk 'NR != 1 && $1 != "information_schema" && $1 != "performance_schema" && $1 != "mysql" && $1 != "sys"{print $1}');do
        for tb in $(mysql -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE \"$db\";" | gawk 'NR != 1 {print $1}');do
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
    /usr/local/cpanel/bin/cpconftool --modules=cpanel::smtp::exim,cpanel::system::backups,cpanel::system::whmconf,cpanel::easy::apache, --backup 2>/dev/null \
        | grep "Backup Successful"
    whm_backup=$(find /home -iname "whm-config-backup-*.tar.gz" -mmin -1)
    cp "$whm_backup" whm_backup.tar.gz
    cp /etc/my.cnf ./my.cnf.back
    echo -e "${BLU}======>PHP<======${NC}"
    for php in $(whmapi1  php_get_handlers 2>/dev/null | grep "version: .*php" | gawk '{print $2}');do
        printf "%s Handler " "$php"
        whmapi1  php_get_handlers  2>/dev/null | grep -E  -B 1 "$php" | grep "current_handler:" | gawk '{print $2}'
        if echo -e "$php" | grep -q "alt-php";then continue ;fi
        echo -e "====== $php =====" >> php.modules
        /opt/cpanel/"$php"/root/usr/bin/php -m  2>/dev/null | grep -E  "^[a-zA-Z]" >> php.modules
    done
    echo
}

if [[ $1 == "" ]];then
    basic
    config
    drives | tee -a drive.info
    versions | tee -a versions.info
    domain_check
    database | tee -a database.info
    exit
fi

while getopts "asdh" opt; do
    case $opt in
        a)
            basic
            config
            drives | tee -a drive.info
            versions | tee -a versions.info
            domain_check
            database | tee -a database.info
            ;;
        s)
            domain_check
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

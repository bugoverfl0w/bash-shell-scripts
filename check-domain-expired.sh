#!/bin/bash

# check expired domain
# @quydox

[ -z "$(which whois)" ] && echo "please install whois command" && exit 0

export LC_TIME=en_US

E_INVALID_DATE=-99
E_CAN_GET_SSL=-3
E_OK=0
E_OTHER=-1
E_EXP=-2

DOMAINS=(
    google.com
    manutd.com
)
DOMAINS_COUNT=0

MY_MSG=""
TIME_STRING=$(date +%s)

NOTIFY_CRITICAL=15
NOTIFY_IS_CRITICAL=0
NOTIFY_IS_EXP=0

# check is int
# $1 number
is_int()
{
    if [[ "$1" != [0-9]* ]]; then
        echo 0;
    else
        echo 1;
    fi
}

# check domain type
# $1 domain
check_ext() {
   ext=$(echo "$1" | sed -n 's/.*\.\(.*\)$/\1/p')
   echo "$ext"
   return 0
}

# check ssl
# $1 domain
check_ssl()
{
    domain_ext=$(check_ext "$1")
    if [[ "$domain_ext" == "mobi" ]]; then 
        exp_date=$(whois $1 | grep -i -E '(expiry|expiration)' | head -n 1 | sed 's/.*Expiry Date:\s*//' | sed 's/\r//' | sed 's/T.*Z/ /')
    elif [[ "$domain_ext" == "io" ]]; then 
        exp_date=$(curl https://nic.io/cgi-bin/whois?DOMAIN=$1 2>/dev/null | grep -A 1 Expiry | tail -n 1 | sed 's/<td>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/pg' | tail -n 1 | sed 's/\s*//g')
        if [ -z "$exp_date" ]; then
            exp_date=$(whois  $1 | grep -i -E '(expiry|expiration)' | head -n 1 | sed 's/.*Expiry[^:]*\s*//' | sed 's/.*Expiration Date:\s*//' | sed 's/\r//' | sed 's/: //' | sed 's/T.*Z/ /')
        fi
    else
        exp_date=$(whois  $1 | grep -i -E '(expiry|expiration)' | head -n 1 | sed 's/.*Expiry[^:]*\s*//' | sed 's/.*Expiration Date:\s*//' | sed 's/\r//' | sed 's/: //' | sed 's/T.*Z/ /')
    fi

    exp_len=${#exp_date}
    if [ $exp_len -lt 5 ]; then
        echo $E_CAN_GET_SSL
        return 0
    fi

    exp_date=$(date -d "$exp_date" +%s)

    # is invalid date
    check_int=$(is_int "$exp_date")
    if [ $check_int -eq 0 ]; then
        echo $E_INVALID_DATE
        return 0
    fi

    exp_date=`expr $exp_date + 0`

    # is expired
    remain_date=$[$exp_date-$TIME_STRING]
    [ $remain_date -le 0 ] && return $E_EXP

    remain_day=$(($remain_date/86400))

    echo $remain_day
}

# debug
if [ -n "$1" ]; then
    DOMAINS=(
        "$1"
    )
fi

# run
for((i=0; i<${#DOMAINS[@]}; i++)); do
    domain=${DOMAINS[i]}

    return_code=$(check_ssl $domain)
    echo $return_code

    case $return_code in
        $E_INVALID_DATE )
            MY_MSG="$MY_MSG[EC] $domain: invalid date<br />"
            ;;
        $E_EXP )
            MY_MSG="$MY_MSG[EC] $domain: expired date<br />"
            NOTIFY_IS_EXP=1
            DOMAINS_COUNT=$[$DOMAINS_COUNT+1]
            ;;
        $E_CAN_GET_SSL )
            MY_MSG="$MY_MSG[FAP] $domain: can not get expired date<br />"
            ;;
        $E_OTHER )
            MY_MSG="$MY_MSG[FAP] $domain: can not get info<br />"
            ;;
        * )
            # notify level    
            if [ $return_code -le $NOTIFY_CRITICAL ]; then
                MY_MSG="$MY_MSG[<font color='red'>CRITICAL</font>] $domain $return_code days<br />"
                NOTIFY_IS_CRITICAL=1
                DOMAINS_COUNT=$[$DOMAINS_COUNT+1]
            #else
                #MY_MSG="$MY_MSG[WARNING] $domain $return_code days<br />"
            fi
            ;;
    esac
    sleep 1
done

# debug
if [ -n "$1" -a -z "$2" ]; then 
    echo $MY_MSG
    exit 0
fi

title="[cron]"
[ $NOTIFY_IS_EXP -ne 0 ] && title="[EXPIRED]"
[ $NOTIFY_IS_CRITICAL -ne 0 ] && title="[CRITICAL]"

curl_msg=$(echo "DOMAIN EXPIRED notification<br />"$MY_MSG | sed -r 's/<br \/>/\n/g' | sed -r 's/<[^>]*//g')
echo $curl_msg

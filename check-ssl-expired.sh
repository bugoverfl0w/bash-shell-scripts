#!/bin/bash

# check ssl expired date
# @quydox

export LC_TIME=en_US

E_INVALID_DATE=-99
E_CAN_GET_SSL=-3
E_OK=0
E_OTHER=-1
E_EXP=-2

DOMAINS=(
    manutd.com
    google.com
)
DOMAINS_COUNT=0

MY_MSG=""
TIME_STRING=$(date +%s)

NOTIFY_CRITICAL=30
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

# check ssl
# $1 domain
check_ssl()
{
    exp_date=$(curl -vIs https://$1 2>&1 | grep 'expire date' | sed 's/\*\s*expire date:\s//')

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

    # is expired
    remain_date=$[$exp_date-$TIME_STRING]
    [ $remain_date -le 0 ] && return $E_EXP

    remain_day=$(($remain_date/86400))

    echo $remain_day
}

# run
for((i=0; i<${#DOMAINS[@]}; i++)); do
    domain=${DOMAINS[i]}
    return_code=$(check_ssl $domain)

    case $return_code in
        $E_INVALID_DATE )
            MY_MSG="$MY_MSG[ERR] $domain: invalid date<br />"
            ;;
        $E_EXP )
            MY_MSG="$MY_MSG[ERR] $domain: expired date<br />"
            NOTIFY_IS_EXP=1
            DOMAINS_COUNT=$[$DOMAINS_COUNT+1]
            ;;
        $E_CAN_GET_SSL )
            MY_MSG="$MY_MSG[ERR] $domain: can not get SSL<br />"
            ;;
        $E_OTHER )
            MY_MSG="$MY_MSG[ERR] $domain: can not get info<br />"
            ;;
        * )
            # notify level    
            if [ $return_code -le $NOTIFY_CRITICAL ]; then
                MY_MSG="$MY_MSG[CRITICAL] $domain $return_code days<br />"
                NOTIFY_IS_CRITICAL=1
                DOMAINS_COUNT=$[$DOMAINS_COUNT+1]
            else
                MY_MSG="$MY_MSG[WARNING] $domain $return_code days<br />"
            fi
            ;;
    esac
done

title="[cron]"
[ $NOTIFY_IS_EXP -ne 0 ] && title="[EXPIRED]"
[ $NOTIFY_IS_CRITICAL -ne 0 ] && title="[CRITICAL]"

echo "$MY_MSG" | /bin/mail -r "crond@server.com" -s "$(echo -e "$title [$DOMAINS_COUNT] ssl expired date report\nContent-Type: text/html; charset=UTF-8")" receiver-email@company.com

#!/bin/bash

# how to use: ./accesslog.sh /path/to/nginx/file.log
# read access_log from start time A to end time B
# start time A => line a
# end time B => line b
# script will get logs from line a to line b
# tail -n +a $file | head -n +(b-a) $file => results
# can check top IP access your file

# default log file
ACCESS_LOG=/var/log/nginx/access.log

if [ -z "$1" ]; then
    echo -n "put your access log file ($ACCESS_LOG): "
    read enter_acc
else
    enter_acc=$1
fi

test -n "$enter_acc" && ACCESS_LOG=$enter_acc
test ! -f $ACCESS_LOG && echo "file $ACCESS_LOG does not exist" && exit 0

echo "use access log file $ACCESS_LOG"

echo ""
tail -n 1 $ACCESS_LOG
echo ""

SAVE_LOG=$HOME/$(basename $ACCESS_LOG)_$(date +"%d%m%Y-%H-%M-%S")

echo "search result saved in $SAVE_LOG"
echo ""

# find start line
echo -n "enter first string to find (find start line): "
read str1
start=$(grep -n "$str1" $ACCESS_LOG | head -n 1 | cut -d: -f1)

if [[ $start != [0-9]* ]]; then
    echo "'$str1' does not exist in access log file $ACCESS_LOG"
    exit 0
fi

# find end line
echo -n "enter last string to find (find start line): "
read str2
end=$(grep -n "$str2" $ACCESS_LOG | tail -n 1 | cut -d: -f1)

if [[ $end != [0-9]* ]]; then
    echo "'$str2' does not exist in access log $ACCESS_LOG"
    exit 0
fi

# total line to read
total=$(($end-$start))

test $total -le 0 && echo "$total <= 0, break" && exit 0

# write results to log file
echo "# $(date) # $(whoami)
# report by script $0
# string first search dau/lines : $str1/$start
# string end string / lines: $str2/$end
# total lines: $total = $end - $start
" > $SAVE_LOG

# write to file
echo "total line $total found - saved in $SAVE_LOG"
tail -n +$start $ACCESS_LOG | head -n +$total >> $SAVE_LOG

# view ips
echo -n "do you want to check top IP Addresses access your sites? (y/n) "
read choi
if [[ "$choi" =~ [yY] ]]; then
    echo -n "awk '{print \$n} $SAVE_LOG', enter n:"
    read n
    if [[ $n != [0-9]* ]]; then
        echo "invalid data, break ;))"
    else
        awk -v x=$n '{print $x}' $SAVE_LOG | sort | uniq -c | sort -n | tail -n 10 | tee -a $SAVE_LOG
    fi
fi

# view logs via vim?
echo -n "do you want to read logs via vim editor? (y/n) "
read choi
if [[ "$choi" =~ [yY] ]]; then
    vim $SAVE_LOG
fi 

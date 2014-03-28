#! /bin/bash

PLUGIN=${0%.sh}
SERVICE=`echo ${PLUGIN#*_} | tr a-z A-Z`

if [ "$1" = "-w" ] && [ "$2" -gt "0" ] && [ "$3" = "-c" ] && [ "$4" -gt "0" ]; then
    memTotal_b=`free -b |grep Mem |awk '{print $2}'`
    memFree_b=`free -b |grep Mem |awk '{print $4}'`
    memBuffer_b=`free -b |grep Mem |awk '{print $6}'`
    memCache_b=`free -b |grep Mem |awk '{print $7}'`

    memTotal_m=`free -m |grep Mem |awk '{print $2}'`
    memFree_m=`free -m |grep Mem |awk '{print $4}'`
    memBuffer_m=`free -m |grep Mem |awk '{print $6}'`
    memCache_m=`free -m |grep Mem |awk '{print $7}'`

    memUsed_b=$(($memTotal_b-$memFree_b-$memBuffer_b-$memCache_b))
    memUsed_m=$(($memTotal_m-$memFree_m-$memBuffer_m-$memCache_m))

    memUsedPrc=$((($memUsed_b*100)/$memTotal_b))

    if [ "$memUsedPrc" -ge "$4" ]; then
        echo "$SERVICE CRITICAL - total:$memTotal_m MB,used:$memUsed_m MB | 'total_b'=${memTotal_b}b;$2;$4;; 'used_b'=${memUsed_b}b;$2;$4;; 'cache'=${memCache_b}b;$2;$4;; 'buffer'=${memBuffer_b}b;$2;$4;;"
        $(exit 2)
    elif [ "$memUsedPrc" -ge "$2" ]; then
        echo "$SERVICE WARNING - total:$memTotal_m MB,used:$memUsed_m MB | 'total_b'=${memTotal_b}b;$2;$4;; 'used_b'=${memUsed_b}b;$2;$4;; 'cache'=${memCache_b}b;$2;$4;; 'buffer'=${memBuffer_b}b;$2;$4;;"
        else
            echo "$SERVICE OK - total:$memTotal_m MB,used:$memUsed_m MB | 'total_b'=${memTotal_b}b;$2;$4;; 'used_b'=${memUsed_b}b;$2;$4;; 'cache'=${memCache_b}b;$2;$4;; 'buffer'=${memBuffer_b}b;$2;$4;;"
            $(exit 0)
        fi

else
        echo "check_mem v1.1"
        echo ""
        echo "Usage:"
        echo "check_mem.sh -w <warnlevel> -c <critlevel>"
        echo ""
        echo "warnlevel and critlevel is percentage value without %"
        echo ""
        echo "Copyright (C) 2012 Lukasz Gogolin (lukasz.gogolin@gmail.com)"
        exit
fi

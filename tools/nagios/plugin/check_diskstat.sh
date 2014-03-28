#!/usr/bin/env bash

# Author: Lawrency Meng
# Date: 2013-2-28
# Description:
#       a show the disk iostat
#       b show the all disks iostat

# args conts
DISK=""
WARNING=""
CRITICAL=""
WARN_TPS=""
WARN_READ=""
WARN_WRITE=""
CRIT_TPS=""
CRIT_READ=""
CRIT_WRITE=""
STIME=3
OUTPUT=""
OUTPUTRES=""
PERFRES=""

# state conts
E_OK=0
E_WARNING=1
E_CRITICAL=2
E_UNKNOWN=3
SECTORBYTESIZE=512

# global conts
HISTDIR="/tmp"
HISTFILE=""

# service conts
PLUGIN=${0%.sh}
SERVICE=`echo ${PLUGIN#*_} | tr a-z A-Z`

function checkWarnCitri(){

    # check tps
    if [[ $1 -gt $WARN_TPS || $2 -gt $WARN_READ || $3 -gt $WARN_WRITE ]]; then
        if [[ $1 -gt $CRIT_TPS || $2 -gt $CRIT_READ || $3 -gt $CRIT_WRITE ]]; then
            OUTPUT="CRITICAL"
            EXITCODE=$E_CRITICAL
        else
            OUTPUT="WARNING"
            EXITCODE=$E_WARNING
        fi
    else
        OUTPUT="OK"
    fi
}

function getNewStat(){
    # 01 get the new disk stat
    [ ! -f "/sys/block/$1/stat" ] && echo "disk $1 stat file not found in /sys/block/" && exit $E_UNKNOWN
    cat /sys/block/${1}/stat
}

function output(){

    getNewStat $1 > $HISTFILE
    # 00 sleep interval tiime
    sleep $STIME
    # 01 get the new disk stat
    NEWDISKSTAT=`getNewStat $1`
    OLDDISKSTAT=`cat ${HISTFILE}`
    [[ "x"$NEWDISKSTAT = "x" && "x"$OLDDISKSTAT="x" ]] && echo "the stat data is Null" && exit $E_UNKNOWN

    # 02 get the Interval time
    TIME=$STIME

    # 03 get the old stat
    OLD_SECTORS_READ=$(echo $OLDDISKSTAT | awk '{print $3}')
    OLD_READ=$(echo $OLDDISKSTAT | awk '{print $1}')
    OLD_WRITE=$(echo $OLDDISKSTAT | awk '{print $5}')
    OLD_SECTORS_WRITTEN=$(echo $OLDDISKSTAT | awk '{print $7}')

    # 04 get the new stat
    NEW_SECTORS_READ=$(echo $NEWDISKSTAT | awk '{print $3}')
    NEW_READ=$(echo $NEWDISKSTAT | awk '{print $1}')
    NEW_WRITE=$(echo $NEWDISKSTAT | awk '{print $5}')
    NEW_SECTORS_WRITTEN=$(echo $NEWDISKSTAT | awk '{print $7}')

    # 05 get the stat data
    let "SECTORS_READ = $NEW_SECTORS_READ - $OLD_SECTORS_READ"
    let "SECTORS_WRITE = $NEW_SECTORS_WRITTEN - $OLD_SECTORS_WRITTEN"
    let "BYTES_READ_PER_SEC = $SECTORS_READ * $SECTORBYTESIZE / $TIME"
    let "BYTES_WRITTEN_PER_SEC = $SECTORS_WRITE * $SECTORBYTESIZE / $TIME"
    let "TPS=($NEW_READ - $OLD_READ + $NEW_WRITE - $OLD_WRITE) / $TIME"
    let "KBYTES_READ_PER_SEC = $BYTES_READ_PER_SEC / 1024"
    let "KBYTES_WRITTEN_PER_SEC = $BYTES_WRITTEN_PER_SEC / 1024"

    # 06 check the warning and critical condition
    checkWarnCitri $TPS $KBYTES_READ_PER_SEC $KBYTES_WRITTEN_PER_SEC

    echo $NEWDISKSTAT > $HISTFILE
    # 07 get the output
    OUTPUTTEMP="$SERVICE ${OUTPUT} - $1 tps:$TPS io/s,read:${KBYTES_READ_PER_SEC} kB/s,write:${KBYTES_WRITTEN_PER_SEC} kB/s"
    PERFTEMP="'tps'=${TPS}io/s;$WARN_TPS;$CRIT_TPS;; 'read'=${BYTES_READ_PER_SEC}b/s;$WARN_READ;$CRIT_READ;; 'write'=${BYTES_WRITTEN_PER_SEC}b/s;$WARN_WRITE;$CRIT_WRITE;; "
    if [ -z "$2" ]; then
        OUTPUTRES="$OUTPUTTEMP"
        PERFRES="$PERFTEMP"
    else
        OUTPUTRES="$OUTPUTRES # $OUTPUTTEMP"
        PERFRES="$PERFRES # $PERFTEMP"
    fi
}

# check the input args
function sanitize() {

    # 01 check thresholds
    if [ -z "$WARNING" ]; then
        echo "Need warning threshold"
        exit $E_UNKNOWN
    fi
    if [ -z "$CRITICAL" ]; then
        echo "Need critical threshold"
        exit $E_UNKNOWN
    fi

    # 02 process thresholds
    WARN_TPS=$(echo $WARNING | cut -d , -f 1)
    WARN_READ=$(echo $WARNING | cut -d , -f 2)
    WARN_WRITE=$(echo $WARNING | cut -d , -f 3)
    CRIT_TPS=$(echo $CRITICAL | cut -d , -f 1)
    CRIT_READ=$(echo $CRITICAL | cut -d , -f 2)
    CRIT_WRITE=$(echo $CRITICAL | cut -d , -f 3)

    # 03 check warining nums
    if [[ -z "$WARN_TPS" && -z "$WARN_READ" && -z "$WARN_WRITE" ]]; then
        echo "Need 3 values for warning threshold (tps,read,write)"
        exit $E_UNKNOWN
    fi

    # check critical nums
    if [[ -z "$CRIT_TPS" && -z "$CRIT_READ" && -z "$CRIT_WRITE" ]]; then
        echo "Need 3 values for critical threshold (tps,read,write)"
        exit $E_UNKNOWN
    fi

}

# show the help info
function show_help() {
    echo "$0 -d DEVICE -t TIME -w tps,read,write -c tps,read,write | -h"
    echo
    echo "This plug-in is used to be alerted when maximum hard drive io/s or sectors read|write/s is reached"
    echo
    echo "  -d DEVICE            DEVICE must be without /dev (ex: -sda)(default all disk devs)"
    echo "  -t TIME              TIME means the interval time.(defult 3 secends)"
    echo "  -w/c TPS,READ,WRITE  TPS means transfer per seconds (aka IO/s)"
    echo "                       READ and WRITE are in sectors per seconds"
    echo
    echo " example: $0 [-d sda] [-t 3] -w 200,100000,100000 -c 300,200000,200000"
}

function main(){
    # process args
    [ $# = 0 ] && show_help && exit 1
    while [ ! -z "$1" ]; do
        case $1 in
            -d)     shift; DISK=$1 ;;
            -t)     shift; STIME=$1 ;;
            -w)     shift; WARNING=$1 ;;
            -c)     shift; CRITICAL=$1 ;;
            -h)     show_help; exit 1 ;;
        esac
        shift
    done

    sanitize

    for disk in `ls /dev/ | grep [a-z]d[a-z]$`; do
        if [ -z "$DISK" ]; then
            HISTFILE=${HISTDIR}/check_diskstat.$disk
            [ ! -f $HISTFILE ] && touch $HISTFILE
            output $disk $OUTPUTRES
        else
            if [ $DISK = $disk ]; then
                HISTFILE=${HISTDIR}/check_diskstat.$disk
                [ ! -f $HISTFILE ] && touch $HISTFILE
                output $disk $OUTPUTRES
                break
            else
                continue
            fi
        fi
    done
    echo "$OUTPUTRES | $PERFRES"
    exit $E_OK
}

main $@


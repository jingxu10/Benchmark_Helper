#!/bin/bash

re='^[0-9]*([.][0-9]+)?$'

if [ $# -lt 2 ]; then
    echo "Usage: $0 <LOG_FOLDER> <BATCH_SIZE>"
    exit 1
fi
LOG_FOLDER=$1
BATCH_SIZE=$2

if [ ! -d ${LOG_FOLDER} ]; then
	echo "${LOG_FOLDER} doesn't exist."
	exit 1
fi
if ! [[ ${BATCH_SIZE} =~ $re ]]; then
	echo "${BATCH_SIZE} is not a digit."
	exit 1
fi

which bc > /dev/null
if [ ! $? -eq 0 ]; then
	echo "bc is needed to run this script. Please install it."
	exit 1
fi

do_statics() {
	n_proc=$1
	SUM_LATENCY=0
	SUM_THROUGHPUT=0
	for i in `seq 0 $(($n_proc-1))`; do
		FILE=${LOG_FOLDER}/${n_proc}_$i.log
		if [ ! -f $FILE ]; then
			# echo "$FILE not exist."
			break
		fi
		latency=$(tail -n 1 $FILE | cut -d ' ' -f 2 | rev | cut -c4- | rev | xargs)
		if ! [[ $latency =~ $re ]]; then
			echo "log parsing Error:" $FILE
			exit 1
		fi
		throughput=$(echo "1000.0/$latency" | bc -l)
		SUM_LATENCY=$(echo "${SUM_LATENCY}+$latency" | bc -l)
		SUM_THROUGHPUT=$(echo "${SUM_THROUGHPUT}+$throughput" | bc -l)
	done
	AVE_LATENCY=$(echo "${SUM_LATENCY}/${n_proc}" | bc -l)
	printf "%d,%.4f,%.4f\n" ${n_proc} ${AVE_LATENCY} ${SUM_THROUGHPUT}
}

N_PROC=()
while read -r line
do
	n_proc=$(echo $line | cut -d '_' -f 1)
	exist=0
	for item in ${N_PROC[*]}
	do
		if [ $item -eq $n_proc ]; then 
			exist=1
			break
		fi
	done
	if [ $exist -eq 0 ]; then
		N_PROC+=($n_proc)
	fi
done < <(ls -1 $LOG_FOLDER)

echo "n_proc,lat(ms),thr(fps)"
for item in ${N_PROC[*]}
do
    do_statics $item
done

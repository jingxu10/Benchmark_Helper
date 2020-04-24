#!/bin/bash

LOG_ROOT="LOGS"

PRELOADS=()
ENVVARS=()
VERBOSE=0
FOLDERS=()
VENVS=()
INSTANCES=()
CMDS=()
PRELOADLS=()
ENVVARLS=()
CORE_SS=()
CORE_ES=()
LOGS=()

# Retrieve CPU info
LID=0
sockets=0
corepersocket=0
while IFS= read -r line
do
   [[ $line =~ .*[:：]\ +([0-9]+) ]]
   if [ $LID -eq 7 ]; then
       sockets=${BASH_REMATCH[1]}
   elif [ $LID -eq 6 ]; then
       corepersocket=${BASH_REMATCH[1]}
   fi
   LID=$(($LID+1))
done < <(lscpu)
if [[ $sockets == '' ]] || [[ $corepersocket == '' ]]; then
    echo -e "\e[31mError:\e[0m Failure to retrieve CPU INFO"
    exit 1
fi
ALLCORES=$(($sockets*$corepersocket))

IFS='/' read -r -a tmp <<< "$0"
if [ ${#tmp[@]} -gt 2 ] || ! [[ $0 == ./* ]]; then
    name=$(echo $0 | rev | cut -d '/' -f 1 | rev)
    folder=${0%"/$name"}
    if [ -z $folder ]; then
        folder="/"
    fi
    echo -e "\e[31mError:\e[0m Please enter $folder and then run ./$name."
    exit 1
fi
CONFFILE="benchmark.conf"
if [ $# -gt 0 ]; then
    CONFFILE=$1
    if [[ $CONFFILE != *".conf" ]]; then
        echo "Usage: $0"
        echo "Usage: $0 <conf_file>.conf"
        exit 1
    fi
    if [ ! -f $CONFFILE ]; then
        echo -e "\e[31mError:\e[0m $CONFFILE doesn't exist."
        exit 1
    fi
fi
IFS='/' read -r -a tmp2 <<< "$CONFFILE"
if [ ${#tmp2[@]} -gt 1 ]; then
    echo -e "\e[31mError:\e[0m Configure file has to be in the same folder of ${tmp[1]}."
    exit 1
fi

echo -e "\e[33mInfo:\e[0m CPU info"
for i in `seq 0 $(($sockets-1))`; do
    echo "  Socket $i: $(($i*$corepersocket))-$((($i+1)*$corepersocket-1))"
done

NUMA=1
which numactl > /dev/null
if [ $? -ne 0 ]; then
    read -p "Numactl is not available. You can only run 1 instance. Continue? [y]/n:" flag_run
    flag_run=${flag_run:-y}
    if [ ${flag_run} != "y" ] && [ ${flag_run} != "Y" ] && [ ${flag_run} != "yes" ] && [ ${flag_run} != "Yes" ]; then
        echo "Quit."
        exit 0
    fi
    NUMA=0
fi

# configure file
if [ ! -f $CONFFILE ]; then
    echo -e "\e[35mWarning:\e[0m benchmark.conf doesn't exist."
    echo "It had been created. Please amend this file for setting up your benchmarking tasks and then run $0 again."
    echo "# Configuration file for benchmarking" > $CONFFILE
    echo "# Lines starting with sharp (#) will be skipped." >> $CONFFILE
    echo "" >> $CONFFILE
    echo "# Configure file Structure:" >> $CONFFILE
    echo "# # [Global configuration] Settings will be applied on all tasks" >> $CONFFILE
    echo "# PRELOAD:(Optional)" >> $CONFFILE
    echo "# ENVVAR:(Optional)" >> $CONFFILE
    echo "# VERBOSE:(Optional)" >> $CONFFILE
    echo "# # [folder configuration] Settings will be applied on all tasks under <FOLDER>" >> $CONFFILE
    echo "# FOLDER:(Mandatory)" >> $CONFFILE
    echo "# VENV:(Optional)" >> $CONFFILE
    echo "# INSTANCE:(Optional)" >> $CONFFILE
    echo "# # [Task configuration] Settings will be applied on individual task only" >> $CONFFILE
    echo "# CMD:(Mandatory)" >> $CONFFILE
    echo "# PRELOAD:(Optional)" >> $CONFFILE
    echo "# ENVVAR:(Optional)" >> $CONFFILE
    echo "# CORES:(Optional)" >> $CONFFILE
    echo "# LOG:(Mandatory)" >> $CONFFILE
    echo "" >> $CONFFILE
    echo "# PRELOAD: Path of dynamic libraries for LD_PRELOAD. Use absolute path. Can be multiple lines, each line for each dynamic library." >> $CONFFILE
    echo "# ENVVAR: Environment variables, if needed. This can be multiple lines, each line for each environment variable." >> $CONFFILE
    echo "# VERBOSE: Set to 1 to print detailed execution commands and environment variables to log files. Default is 0, disable printing." >> $CONFFILE
    echo "# FOLDER: Folder path which contains your python scripts or executable binaries. This can be absolute path or relative path." >> $CONFFILE
    echo "# VENV: Python virtual environment or bash script to set runtime environment by \"source\" command. Can be absolute path or relative path for Python virtual environment, containing bin/activate script file. Alternatively, it can be name of conda virtual environment. If you don't use Python virtual environments or bash environment settings, you can comment this line out or leave this empty. For bash script usage, you can append parameters after the bash script filename, separate by space." >> $CONFFILE
    echo "# INSTANCE: Number of instances to run on designated cores. For instance, 2 means tasks will be run with 2 independent instances on designated cores. Each instances takes half of overall cores. Seperate by semicolon(;) for multiple numbers of instances." >> $CONFFILE
    echo "# CMD: Command how the python scrit or executable binary will be run, with full parameters. It must be exactly the same command when you run it in <FOLDER>. Be sure to prepend \"./\" before your executable binaries, i.e. \"./<EXECUTABLE> <PARAMETERS>\". If you run Python scripts, use \"python <SCRIPT> <PARAMETERS>\". CMD is begining of an individual task configuration." >> $CONFFILE
    echo "# CORES: Cores which you would like the task to run on. In format START;NUMBER. For instance, 0;12 means running on 12 physical cores starting from #0. Leave this empty or remove this line to take advantage of all physical cores on all sockets." >> $CONFFILE
    echo "# LOG: Name of log folder. Stdout of your application output will be redirected into files in <FOLDER>/LOGS/<LOG> folder. Log files are named as \"<INSTANCE_NUMBER>_<INSTANCE_ID>.log\". You can set CMD and LOG for multiple times for different tests in the same <FOLDER>. This is end of an individual task configuration." >> $CONFFILE
    echo "" >> $CONFFILE
    echo "# Example:" >> $CONFFILE
    echo "# [Global configuration]" >> $CONFFILE
    echo "# PRELOAD:/opt/intel/compilers_and_libraries_2019.2.187/linux/compiler/lib/intel64_lin/libiomp5.so" >> $CONFFILE
    echo "# ENVVAR: MKL_VERBOSE=1" >> $CONFFILE
    echo "# ENVVAR: MKLDNN_VERBOSE=1" >> $CONFFILE
    echo "# [Folder configuration]" >> $CONFFILE
    echo "# FOLDER:../<path>/<folder1> or /home/user/<path>/<folder1>" >> $CONFFILE
    echo "# VENV:../<path>/<venv> or /home/user/<path>/<venv> or <venv>" >> $CONFFILE
    echo "# INSTANCE:1;2;12" >> $CONFFILE
    echo "# [Task configuration]" >> $CONFFILE
    echo "# CMD:python evaluate.py" >> $CONFFILE
    echo "# ENVVAR:Example1=1" >> $CONFFILE
    echo "# ENVVAR:Example2=1" >> $CONFFILE
    echo "# LOG:FP32" >> $CONFFILE
    echo "# [Task configuration]" >> $CONFFILE
    echo "# CMD:python evaluate.py --profile" >> $CONFFILE
    echo "# CORES: 0;12" >> $CONFFILE
    echo "# LOG:FP32_PROFILE" >> $CONFFILE
    echo "# [folder configuration]" >> $CONFFILE
    echo "# FOLDER:../<path>/<folder1> or /home/user/<path>/<folder1>" >> $CONFFILE
    echo "# VENV:../<path>/<venv> or /home/user/<path>/<venv> or <venv>" >> $CONFFILE
    echo "# INSTANCE:1;6;24" >> $CONFFILE
    echo "# ..." >> $CONFFILE
    echo "" >> $CONFFILE
    exit 1
else
    FOLDER=""
    VENV="none;"
    INSTANCE=""
    CMD=""
    PRELOADL=""
    ENVVARL=""
    CORE_S=0
    CORE_E=$(($ALLCORES-1))
    ln=0
    while IFS= read -r line
    do
        ln_t=$(echo $line | xargs -0)
        if [[ $ln_t != "#"* ]] && [[ ! -z "$ln_t" ]]; then
            if [[ $ln_t == "PRELOAD:"* ]]; then
                preload=$(echo ${ln_t:8} | xargs)
                if [ ! -z "$preload" ]; then
                    if [ -f "$preload" ]; then
                        if [ -z "$FOLDER" ]; then
                            PRELOADS+=($preload)
                        else
                            PRELOADL="$PRELOADL;$preload"
                        fi
                        if [[ $preload == *"/libiomp5.so" ]]; then
                            ln_t="ENVVAR:KMP_AFFINITY=granularity=fine,compact"
                        fi
                    else
                        echo -e "\e[31mError:\e[0m [Line $(($ln+1))] \"PRELOAD:$preload\" doesn't exist." 
                        exit 1
                    fi
                fi
            fi
            if [[ $ln_t == "ENVVAR:"* ]]; then
                envvar=$(echo ${ln_t:7} | xargs -0)
                if [ ! -z "$envvar" ]; then
                    if [ -z "$FOLDER" ]; then
                        ENVVARS+=($envvar)
                    else
                        ENVVARL="$ENVVARL;$envvar"
                    fi
                fi
            fi
            if [[ $ln_t == "VERBOSE:"* ]]; then
                VERBOSE=$(echo ${ln_t:8} | xargs)
                if [ ! -z $VERBOSE ]; then
                    if ! [[ $VERBOSE =~ ^[0-9]+$ ]] || [ $VERBOSE -gt 1 ]; then
                        echo -e "\e[31mError:\e[0m [Line $(($ln+1))] \"VERBOSE:$VERBOSE\" VERBOSE can only be set to 0 or 1."
                        exit 1
                    fi
                fi
            fi
            if [[ $ln_t == "FOLDER:"* ]]; then
                FOLDER=$(echo ${ln_t:7} | xargs)
                if [ ! -d "$FOLDER" ]; then
                    echo -e "\e[35mWarning:\e[0m [Line $(($ln+1))] folder $FOLDER doesn't exist."
                    exit 1
                fi
                VENV="none;"
                INSTANCE=""
                CMD=""
                PRELOADL=""
                ENVVARL=""
            fi
            if [[ $ln_t == "VENV:"* ]]; then
                VENV=$(echo ${ln_t:5} | xargs)
                if [ -z "$VENV" ]; then
                    VENV="none;"
                else
                    which conda > /dev/null
                    if [ $? == 0 ]; then
                        conda env list | grep "$VENV" > /dev/null
                        if [ $? == 0 ]; then
                            VENV="conda;\"$VENV\""
                        fi
                    fi
                    if [[ $VENV != "conda;"* ]]; then
                        if [ ! -f "$VENV/bin/activate" ]; then
                            sh_script=$(echo $VENV | cut -d ' ' -f 1)
                            if [ ! -f "$sh_script" ]; then
                                echo -e "\e[31mError:\e[0m [Line $(($ln+1))] venv/bash script \"$sh_script\" not available."
                                echo "If this is a conda virtual environment, please make sure path of conda is in system environment variable PATH or base virtual environment of conda had been activated."
                                exit 1
                            else
                                tmp=${VENV#"$sh_script"}
                                VENV="bash;\"$sh_script\"$tmp"
                            fi
                        else
                            VENV="venv;$VENV"
                        fi
                    fi
                fi
            fi
            if [[ $ln_t == "INSTANCE:"* ]]; then
                INS="$(echo ${ln_t:9} | xargs)"
                if [ ! -z "$INS" ]; then
                    IFS=';' read -r -a tmp <<< "$INS"
                    for item in ${tmp[*]}
                    do
                        if ! [[ $item =~ ^[0-9]+$ ]]; then
                            echo -e "\e[31mError:\e[0m [Line $(($ln+1))] \"INSTANCE:$INS\" Contains not digital value(s)."
                            exit 1
                        elif [ $item -eq 0 ]; then
                            echo -e "\e[31mError:\e[0m [Line $(($ln+1))] \"INSTANCE:$INS\" Instance number must not be 0."
                            exit 1
                        else
                            if [ -z "$INSTANCE" ]; then
                                INSTANCE="$item;"
                            else
                                INSTANCE="${INSTANCE}${item};"
                            fi
                        fi
                    done
                fi
            fi
            if [[ $ln_t == "CMD:"* ]]; then
                CMD=$(echo ${ln_t:4} | xargs)
            fi
            if [[ $ln_t == "CORES:"* ]]; then
                CORE=$(echo ${ln_t:6} | xargs)
                if [ -z "$CORE" ]; then
                    CORE_S=0
                    CORE_E=$(($ALLCORES-1))
                else
                    CORE_S=$(echo $CORE | cut -d ';' -f 1)
                    CORE_N=$(echo $CORE | cut -d ';' -f 2)
                    if ! [[ $CORE_S =~ ^[0-9]+$ ]] || ! [[ $CORE_N =~ ^[0-9]+$ ]]; then
                        echo -e "\e[31mError:\e[0m [Line $(($ln+1))] \"CORES:$CORE\" Either starting core id or core numbers is not digit."
                        exit 1
                    fi
                    CORE_E=$(($CORE_S+$CORE_N-1))
                    if [ $CORE_E -ge $ALLCORES ]; then
                        echo -e "\e[31mError:\e[0m [Line $(($ln+1))] \"CORES:$CORE\" exceeds CPU capacity [0-$(($ALLCORES-1))]"
                        exit 1
                    fi
                fi

                CORE_N=$(($CORE_E-$CORE_S+1))
                IFS=';' read -r -a tmp <<< "$INSTANCE"
                for item in ${tmp[*]}
                do
                    if [ $item -gt $CORE_N ]; then
                        echo -e "\e[31mError:\e[0m Instances configuration ($item) exceeds cores configuration ($CORE_N)."
                        exit 1
                    fi
                done
            fi
            if [[ $ln_t == "LOG:"* ]]; then
                LOG=$(echo ${ln_t:4} | xargs)
                IFS=' ' read -r -a tmp <<< "$LOG"
                if [ ${#tmp[@]} -gt 1 ]; then
                    echo -e "\e[31mError:\e[0m [Line $(($ln+1))] \"LOG:$LOG\" Log folder name cannot contain space(s)."
                    exit 1
                fi
                FOLDERS+=($FOLDER)
                VENVS+=("$VENV")
                if [ -z $INSTANCE ]; then
                    INSTANCE="1;"
                fi
                if [ $NUMA -eq 0 ]; then
                    INSTANCE="1;"
                    CORE_S=0
                    CORE_E=$(($ALLCORES-1))
                fi
                INSTANCES+=($INSTANCE)
                CMDS+=("$CMD")
                PRELOADLS+=("$PRELOADL")
                PRELOADL=""
                ENVVARLS+=("$ENVVARL")
                ENVVARL=""
                CORE_SS+=($CORE_S)
                CORE_ES+=($CORE_E)
                LOGS+=($LOG)

                CORE_S=0
                CORE_E=$(($ALLCORES-1))
            fi
        fi
        ln=$(($ln+1))
    done < $CONFFILE
    num=${#FOLDERS[@]}
    if [ $num -ne ${#VENVS[@]} ] || [ $num -ne ${#INSTANCES[@]} ] || [ $num -ne ${#CMDS[@]} ] || [ $num -ne ${#PRELOADLS[@]} ] || [ $num -ne ${#ENVVARLS[@]} ] || [ $num -ne ${#CORE_SS[@]} ] || [ $num -ne ${#CORE_ES[@]} ] || [ $num -ne ${#LOGS[@]} ]; then
        echo -e "\e[31mError:\e[0m Configure file parsing error."
        echo -e "\e[31mError:\e[0m $num/${#VENVS[@]}/${#INSTANCES[@]}/${#CMDS[@]}/${#PRELOADLS[@]}/${#ENVVARLS[@]}/${#CORE_SS[@]}/${#CORE_ES[@]}/${#LOGS[@]}"
        exit 1
    fi
    if [ $num -eq 0 ]; then
        echo -e "\e[35mWarning:\e[0m No tasks to run. Quit."
        exit 0
    fi
fi

if [[ $VERBOSE -ne 0 ]]; then
    echo -e "\e[33mInfo:\e[0m Verbose mode: ON"
else
    echo -e "\e[33mInfo:\e[0m Verbose mode: OFF"
fi

if [ ${#PRELOADS[@]} -gt 0 ]; then
    echo -e "\e[33mInfo:\e[0m The following dynamic libraries will be loaded to overwrite default ones for all tasks:"
    for item in ${PRELOADS[*]}
    do
        echo "  $item"
    done
fi
if [ ${#ENVVARS[@]} -gt 0 ]; then
    echo -e "\e[33mInfo:\e[0m The following environment variable(s) will be set for all tasks:"
    for item in ${ENVVARS[*]}
    do
        echo "  $item"
    done
fi
echo -e "\e[33mInfo:\e[0m The following task(s) will be run:"
for i in `seq 0 $((${#FOLDERS[@]}-1))`; do
    IFS=';' read -r -a preloadl <<< "${PRELOADLS[$i]}"
    IFS=';' read -r -a envvarl <<< "${ENVVARLS[$i]}"
    echo -e "  \e[36mFolder:\e[0m ${FOLDERS[$i]}"
    if [[ ${VENVS[$i]} != "none;" ]]; then
        echo -e "  \e[36mVenv:\e[0m ${VENVS[$i]}"
    fi
    echo -e "  \e[36mInstance(s):\e[0m ${INSTANCES[$i]}"
    echo -e "  \e[36mCommand:\e[0m ${CMDS[$i]}"
    if [ ${#preloadl[@]} -gt 0 ]; then
        echo -e "  \e[36mPreload dynamic libraries:\e[0m"
        for item in ${preloadl[*]}
        do
            echo "    $item"
        done
    fi
    if [ ${#envvarl[@]} -gt 0 ]; then
        echo -e "  \e[36mEnvironment variables:\e[0m"
        for item in ${envvarl[*]}
        do
            echo "    $item"
        done
    fi
    echo -e "  \e[36mCores:\e[0m ${CORE_SS[$i]}-${CORE_ES[$i]}"
    echo -e "  \e[36mLog:\e[0m ${LOGS[$i]}"
    echo "  ========================================="
done
read -p "Continue to run tasks? [y]/n:" flag_run
flag_run=${flag_run:-y}
if [ ${flag_run} != "y" ] && [ ${flag_run} != "Y" ] && [ ${flag_run} != "yes" ] && [ ${flag_run} != "Yes" ]; then
    echo "Quit."
    exit 0
fi
EXISTING_LOGS=()
for i in `seq 0 $((${#FOLDERS[@]}-1))`; do
    LOG_FOLDER="${FOLDERS[$i]}/${LOG_ROOT}/${LOGS[$i]}"
    if [ ! -d ${LOG_FOLDER} ]; then
        mkdir -p ${LOG_FOLDER}
    else
        EXISTING_LOGS+=($LOG_FOLDER)
    fi
done
if [ ${#EXISTING_LOGS[@]} -gt 0 ]; then
    echo -e "\e[35mWarning:\e[0m Log folder exists:"
    for item in ${EXISTING_LOGS[*]}
    do
        echo "  $item"
    done
    read -p "Overwrite the whole folder? [y]/n:" overwrite
    overwrite=${overwrite:-y}
    if [ ${overwrite} != "y" ] && [ ${overwrite} != "Y" ] && [ ${overwrite} != "yes" ] && [ ${overwrite} != "Yes" ]; then
        echo -e "\e[35mWarning:\e[0m Old log files with exactly the same file name will be overwritten. You need to take care of other old log files."
    else
        for item in ${EXISTING_LOGS[*]}
        do
            rm $item/* 2>/dev/null
        done
    fi
fi

benchmark() {
    n_proc=$1
    core_s=$2
    core_e=$3
    script=$4
    log=$5
    n_core=$(($core_e-$core_s+1))
    omp_num_threads=$(($n_core/$n_proc))
    t=$(($n_proc/$sockets))
    offset1=$((($n_core-$omp_num_threads*$n_proc)/$sockets))
    export OMP_NUM_THREADS=$omp_num_threads
    export intra_op_parallelism_threads=$omp_num_threads
    for i in `seq 0 $(($n_proc-1))`; do
        echo -e "\e[33mInfo:\e[0m instance(s): $(($i+1))/$n_proc"
        offset2=$(($i/$t))
        cpu_s=$(($i*$omp_num_threads+$core_s+$offset1*$offset2))
        cpu_e=$(($cpu_s+$omp_num_threads-1))
        mem0=$(($cpu_s/$corepersocket))
        mem1=$(($cpu_e/$corepersocket))
        mem_prefix=""
        if [ $mem0 -eq $mem1 ]; then
            mem_prefix="-m ${mem0}"
        else
            echo -e "\e[35mWarning:\e[0m Running on multiple sockets!"
        fi
        numa_prefix=""
        if [ $NUMA -eq 1 ]; then
            numa_prefix="numactl -C ${cpu_s}-${cpu_e} ${mem_prefix}"
        fi
        cmd="${numa_prefix} ./${script}"
        logfile=$log/${n_proc}_${i}.log
        if [ -f $logfile ]; then
            rm $logfile 2>/dev/null
        fi
        if [[ $VERBOSE -ne 0 ]]; then
            echo "$ cat $script" > $logfile
            cat "$script" >> $logfile
            echo "$ export OMP_NUM_THREADS=$omp_num_threads" >> $logfile
            echo "$ export intra_op_parallelism_threads=$omp_num_threads" >> $logfile
            echo "$ $cmd" >> $logfile
            echo "" >> $logfile
        fi
        $cmd >> $logfile 2>&1 &
    done
    wait
    sleep 10
}

MARKER=$(echo $CONFFILE | rev)
MARKER=$(echo ${MARKER:5} | rev)
for i in `seq 0 $((${#FOLDERS[@]}-1))`; do
    folder=${FOLDERS[$i]}
    channel=$(echo ${VENVS[$i]} | cut -d ';' -f 1)
    venv=$(echo ${VENVS[$i]} | cut -d ';' -f 2)
    IFS=';' read -r -a instances <<< "${INSTANCES[$i]}"
    command=${CMDS[$i]}
    IFS=';' read -r -a preloadl <<< "${PRELOADLS[$i]}"
    IFS=';' read -r -a envvarl <<< "${ENVVARLS[$i]}"
    core_s=${CORE_SS[$i]}
    core_e=${CORE_ES[$i]}
    log=${folder}/${LOG_ROOT}/${LOGS[$i]}

    preload=""
    for item in ${PRELOADS[*]}
    do
        if [ ! -z "$item" ]; then
            if [ -z "$preload" ]; then
                preload=$item
            else
                preload="$preload $item"
            fi
        fi
    done
    for item in ${preloadl[*]}
    do
        if [ ! -z "$item" ]; then
            if [ -z "$preload" ]; then
                preload=$item
            else
                preload="$preload $item"
            fi
        fi
    done

    SCRIPT="tmp_$MARKER.sh"
    echo "#!/bin/bash" > "$SCRIPT"
    if [ ! -z "$preload" ]; then
        echo "export LD_PRELOAD=\"$preload\"" >> "$SCRIPT"
    fi
    for item in ${ENVVARS[*]}
    do
        if [ ! -z "$item" ]; then
            echo "export $item" >> "$SCRIPT"
        fi
    done
    for item in ${envvarl[*]}
    do
        if [ ! -z "$item" ]; then
            echo "export $item" >> "$SCRIPT"
        fi
    done
    if [[ $channel == "conda" ]]; then
        echo "source \$(conda info --base)/etc/profile.d/conda.sh" >> "$SCRIPT"
        echo "conda activate \"$venv\"" >> "$SCRIPT"
    fi
    if [[ $channel == "venv" ]]; then
        echo "source \"$venv/bin/activate\"" >> "$SCRIPT"
    fi
    if [[ $channel == "bash" ]]; then
        echo "source $venv" >> "$SCRIPT"
    fi
    echo "cd $folder" >> "$SCRIPT"
    echo "$command" >> "$SCRIPT"
    if [[ $channel == "conda" ]]; then
        echo "conda deactivate" >> "$SCRIPT"
    fi
    if [[ $channel == "venv" ]]; then
        echo "deactivate" >> "$SCRIPT"
    fi
    chmod +x "$SCRIPT"
    
    echo -e "\e[33mInfo:\e[0m $folder"
    echo -e "\e[33mInfo:\e[0m $command"
    for n_proc in ${instances[*]}
    do
        if [ ! -z "$n_proc" ]; then
            benchmark $n_proc $core_s $core_e "$SCRIPT" $log
        fi
    done
    rm "$SCRIPT"
done
echo "Finished"

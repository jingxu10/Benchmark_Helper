These bash scripts help to automate benchmarking and result finalization.
1. benchmark.sh:
    ```bash
    Usage: ./benchmark.sh
    Usage: ./benchmark.sh <conf_file>.conf
    ```
    - scripts for benchmarking multiple tasks in sequence, so you don’t have to wait for one task to finish and then type commands to run another one.
    - It can run multiple instances on your designated physical cores or on all physical cores.
    - You can set environment variables for all tasks, and task specific environment variables for an individual task.
    - This should be able to deal with tasks like python codes, native C/CPP executables, etc., for generic use.
2. Configure file for benchmark.sh
    1. Structure of the configure file:
        - [Global configuration]
          Settings will be applied on all tasks
            - PRELOAD:(Optional)
            - ENVVAR:(Optional)
            - VERBOSE:(Optional)
        - [Folder configuration]
          Settings will be applied on all tasks under <FOLDER>
            - FOLDER:(Mandatory)
            - VENV:(Optional)
            - INSTANCE:(Optional)
        - [Task configuration]
          Settings will be applied on individual task only
            - CMD:(Mandatory)
            - PRELOAD:(Optional)
            - ENVVAR:(Optional)
            - CORES:(Optional)
            - LOG:(Mandatory)
    2. Description of these settings:

        | Name | Description |
        | - | - |
        | PRELOAD | Path of dynamic libraries for LD_PRELOAD. Use absolute path. Can be multiple lines, each line for each dynamic library. |
        | ENVVAR | Environment variables, if needed. This can be multiple lines, each line for each environment variable. |
        | VERBOSE | Set to 1 to print detailed execution commands and environment variables to log files. Default is 0, disable printing. |
        | FOLDER | Folder path which contains your python scripts or executable binaries. This can be absolute path or relative path. |
        | VENV | Python virtual environment or bash script to set runtime environment by \"source\" command. Can be absolute path or relative path for Python virtual environment, containing bin/activate script file. Alternatively, it can be name of conda virtual environment. If you don't use Python virtual environments or bash environment settings, you can comment this line out or leave this empty. For bash script usage, you can append parameters after the bash script filename, separate by space. |
        | INSTANCE | Number of instances to run on designated cores. For instance, 2 means tasks will be run with 2 independent instances on designated cores. Each instances takes half of overall cores. Seperate by semicolon(;) for multiple numbers of instances. |
        | CMD | Command how the python scrit or executable binary will be run, with full parameters. It must be exactly the same command when you run it in \<FOLDER\>. Be sure to prepend \"./\" before your executable binaries, i.e. \"./\<EXECUTABLE\> \<PARAMETERS\>\". If you run Python scripts, use \"python \<SCRIPT\> \<PARAMETERS\>\". CMD is begining of an individual task configuration. |
        | CORES | Cores which you would like the task to run on. In format START;NUMBER. For instance, 0;12 means running on 12 physical cores starting from #0. Leave this empty or remove this line to take advantage of all physical cores on all sockets. |
        | LOG | Name of log folder. Stdout of your application output will be redirected into files in \<FOLDER\>/LOGS/\<LOG\> folder. Log files are named as \"\<INSTANCE_NUMBER\>_\<INSTANCE_ID\>.log\". You can set CMD and LOG for multiple times for different tests in the same \<FOLDER\>. This is end of an individual task configuration. |

    3. Example:
        ```bash
        # [Global configuration]
        PRELOAD:/opt/intel/compilers_and_libraries_2020.0.166/linux/compiler/lib/intel64_lin/libiomp5.so
        ENVVAR:MKL_VERBOSE=1
        ENVVAR:MKLDNN_VERBOSE=1
        ENVVAR:TEST=1
        VERBOSE:1
        
        # [Folder configuration]
        FOLDER:<FOLDER1>
        VENV:<PATH>/<VENV1>
        INSTANCE:1
        # [Task configuration]
        CMD:python main.py <PARA1>
        ENVVAR:TEST2=1
        CORES:
        LOG:TEST1
        # [Task configuration]
        CMD:python main.py <PARA2>
        ENVVAR:TEST3=1
        CORES:0;12
        LOG:TEST2
        
        # [Folder configuration]
        FOLDER:<FOLDER2>
        VENV:<VENV_CONDA>
        INSTANCE:2;8;16
        # [Task configuration]
        CMD:python evaluate.py
        CORES:10;16
        LOG:TEST3
        
        # [Folder configuration]
        FOLDER:.
        VENV:/opt/intel/compilers_and_libraries_2020.0.166/linux/bin/iccvars.sh intel64
        # [Task configuration]
        CMD:icc --version
        PRELOAD:<PATH>/jemalloc/lib/libjemalloc.so
        ENVVAR:MALLOC_CONF="oversize_threshold:1,background_thread:true,metadata_thp:auto,dirty_decay_ms:9000000000,muzzy_decay_ms:9000000000"
        LOG:TEST4
        
        # [Folder configuration]
        FOLDER:.
        VENV:
        # [Task configuration]
        CMD:gcc --version
        LOG:TEST5
        ```
        You will get the following summary before you confirm running.
        ```bash
        Info: Verbose mode: ON
        Info: The following dynamic libraries will be loaded to overwrite default ones for all tasks:
          /opt/intel/compilers_and_libraries_2020.0.166/linux/compiler/lib/intel64_lin/libiomp5.so
        Info: The following environment variable(s) will be set for all tasks:
          KMP_AFFINITY=granularity=fine,compact
          MKL_VERBOSE=1
          MKLDNN_VERBOSE=1
          TEST=1
        Info: The following task(s) will be run:
          Folder: <FOLDER1>
          Venv: venv;<PATH>/<VENV1>
          Instance(s): 1;
          Command: python main.py <PARA1>
          Environment variables:
            TEST2=1
          Cores: 0-47
          Log: TEST1
          =========================================
          Folder: <FOLDER1>
          Venv: venv;<PATH>/<VENV1>
          Instance(s): 1;
          Command: python main.py <PARA2>
          Environment variables:
            TEST3=1
          Cores: 0-11
          Log: TEST2
          =========================================
          Folder: <FOLDER2>
          Venv: conda;<VENV_CONDA>
          Instance(s): 2;8;16;
          Command: python evaluate.py 
          Cores: 10-25
          Log: TEST3
          =========================================
          Folder: .
          Venv: bash;"/opt/intel/compilers_and_libraries_2020.0.166/linux/bin/iccvars.sh" intel64
          Instance(s): 1;
          Command: icc --version
          Preload dynamic libraries:
            <PATH>/jemalloc/lib/libjemalloc.so
          Environment variables:
            MALLOC_CONF="oversize_threshold:1,background_thread:true,metadata_thp:auto,dirty_decay_ms:9000000000,muzzy_decay_ms:9000000000"
          Cores: 0-47
          Log: TEST4
          =========================================
          Folder: .
          Venv: none;
          Instance(s): 1;
          Command: gcc --version
          Cores: 0-47
          Log: TEST5
          =========================================
        ```
3. rst_gather.sh
    ```bash
    Usage: ./rst_gather.sh <LOG_FOLDER>
    ```
    - For multiple instances execution, there will to too many log files generated, which contains performance number, like execution time, for each instance. It will be too time-costing if we get these number by opening them one-by-one.
    - With this script, you only need to input the log files folder as the first parameter. It will generate an csv-format output in stdio. You can use > or tee command with pipe to redirect these output to a file.
    ```bash
    n_proc,lat(s),thr(fps)
    1,10.0000,0.1000
    12,10.0000,1.2000
    2,10.0000,0.2000
    28,10.0000,2.8000
    ```
    - You need to print message containing performance number in format “xxxxx \<time\>” in your code. This message must be the last printed message of your application. Alternatively, you can modify line 32 to make the script fitting your output messages.

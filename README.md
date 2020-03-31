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
2. rst_gather.sh
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

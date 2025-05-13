nextflow.enable.dsl = 2  // Use Nextflow's modern domain-specific language version 2

// Optional: Uncomment the following lines to enable GPU or high-memory tasks.
// These typically run on busy partitions and may delay job start.

workflow {
    // Run the shell script to decide when to start based on carbon intensity
    cluster_options_ch = calculate_daylight_start(file('slurm_green_scheduler.sh'))

    // Launch energy-aware task with cluster options from the script
    highenergy_std_task(cluster_options_ch)

    // Launch standard tasks that are not carbon-aware
    standard_task()
    longrun_task()

    // Uncomment to enable optional high-memory or GPU tasks
    // highenergy_memory_task(cluster_options_ch)
    // gpu_task(cluster_options_ch)
}

process calculate_daylight_start {
    // Input: The scheduling script (staged inside the job dir as 'slurm_green_scheduler.sh')
    input:
    path script, stageAs: 'slurm_green_scheduler.sh'

    // Output: The stdout (e.g., generated SLURM cluster options) as a channel
    output:
    stdout

    // Run the script, passing the SLURM job ID (inherited from submission environment)
    script:
    """
    bash slurm_green_scheduler.sh \$SLURM_JOB_ID
    """
}

process highenergy_std_task {
    label 'std_high_en_partition'  // Assigns this task to a specific SLURM partition

    input:
    val cluster_opts  // Receives the SLURM cluster options from the scheduler

    // Apply those options when submitting to SLURM
    clusterOptions "${cluster_opts} --requeue"

    script:
    """
    echo 'Running high energy task (green-aware)'
    echo "Cluster options received: \$cluster_opts"
    sleep 30  // Simulate workload; replace with your actual task
    """
}

process standard_task {
    label 'standard_partition'  // Assigned to a standard partition

    script:
    """
    echo 'Running standard task'
    sleep 30  // Simulate workload; replace with real computation
    """
}

process longrun_task {
    label 'longrun_partition'  // Assigned to a partition for longer jobs

    script:
    """
    echo 'Running longrun task'
    sleep 30  // Simulate workload; replace with real computation
    """
}

process highenergy_memory_task {
    label 'large_memory_partition'  // SLURM partition for high memory nodes

    input:
    val cluster_opts

    clusterOptions "${cluster_opts} --requeue"

    script:
    """
    echo 'Running large memory task'
    echo "Cluster options received: \$cluster_opts"
    sleep 30  // Simulate workload; replace with real computation
    """
}

process gpu_task {
    label 'gpu_partition'  // SLURM GPU partition

    input:
    val cluster_opts

    clusterOptions "${cluster_opts} --requeue"

    script:
    """
    echo 'Running GPU task (daylight preferred)'
    echo "Cluster options received: \$cluster_opts"
    sleep 30  // Simulate workload; replace with real GPU task
    """
}


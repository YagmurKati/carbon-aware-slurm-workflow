# 🌱 Carbon-Aware SLURM Workflow using Nextflow

This repository provides a Nextflow-based workflow for SLURM clusters (tested on HPC@HU) that delays **energy-intensive jobs** until carbon intensity is below a user-defined threshold. It integrates live data from [ElectricityMap](https://www.electricitymap.org/) along with daylight window filtering.

---

## 🔧 Prerequisites

Before running the workflow, ensure the following are available:

- ✅ Java 11+
- ✅ Nextflow
- ✅ SLURM cluster access with job submission rights
- ✅ `jq` binary (placed in `$HOME/jq`)
- ✅ ElectricityMap API token

## Required Setup

### 🔑 ElectricityMap API Token

Before running the workflow, you must provide your own API token:

1. Visit [https://www.electricitymap.org/map](https://www.electricitymap.org/map)
2. Sign up and obtain your free API key
3. Open the file `slurm_green_scheduler.sh` and replace the following line:

```bash
AUTH_TOKEN="YOUR_API_TOKEN_HERE"
```

### 🛠 Java (via SDKMAN)

If Java is not already available on your system:
```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 11.0.19-tem
```
Make Java available inside SLURM jobs by adding this to your .bashrc:
```bash
echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.bashrc
source ~/.bashrc
```

### 🧰 jq (JSON processor)

If jq is not available via modules:
```bash
wget -O $HOME/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x $HOME/jq
```
Make sure your script references the correct path in slurm_green_scheduler.sh:
```bash
JQ="$HOME/jq"
```

### ⚡ Nextflow

Install locally:
```bash
wget -qO- https://get.nextflow.io | bash
mv nextflow $HOME/.local/bin/
```
Or load it using your cluster's environment module system:
```bash
module load nextflow
```

---

## 🚀 Quick Start

### 1. Submit the Nextflow job in held state

```bash
chmod +x nextflow_job.slurm
sbatch --hold nextflow_job.slurm
```

Note the returned job ID (e.g., 317292).
### 2. Run the carbon-aware scheduler

```bash
chmod +x slurm_green_scheduler.sh
./slurm_green_scheduler.sh <JOB_ID>
```
The script will check carbon intensity hourly for up to 24 hours. When conditions are met, the SLURM job is released automatically.

## 📁 Repository Contents
```bash
.
├── green_controlled_workflow.nf     # Main Nextflow workflow
├── nextflow_job.slurm               # SLURM job that runs Nextflow
├── slurm_green_scheduler.sh         # Carbon-aware job release script
├── nextflow.config                  # Nextflow SLURM resource configuration
└── README.md                        # Documentation
```

## ⚙️ Workflow Details

### Processes Included

| Process                   | Description                           | Notes                                                                 |
|---------------------------|---------------------------------------|-----------------------------------------------------------------------|
| `calculate_daylight_start`| Checks carbon level + daylight        | Injects SLURM `--begin=` if carbon intensity is high                  |
| `highenergy_std_task`     | Energy-intensive CPU task             | Runs only under green conditions                                      |
| `standard_task`           | Lightweight short task                | Always runs immediately                                               |
| `longrun_task`            | Long runtime job                      | Assigned to the `longrun` SLURM partition                             |
| `highenergy_memory_task`  | Memory-intensive task _(optional)_    | Runs only under green conditions; assigned to `large_memory` partition|
| `gpu_task`                | GPU-accelerated task _(optional)_     | Runs only under green conditions; assigned to `gpu` partition         |

💡 *To enable optional processes, uncomment them in the `workflow {}` block of `green_controlled_workflow.nf`.*

## 📜 Script Overview: `slurm_green_scheduler.sh`

This script delays SLURM job execution until the grid is "green enough" based on real-time carbon intensity data from [ElectricityMap](https://www.electricitymap.org/).

- ✅ It checks the carbon intensity for a given zone (e.g., Germany: `"DE"`).
- ♻️ If the intensity is below a user-defined threshold (e.g., **250 gCO₂eq/kWh**), the job is released using `scontrol release`.
- 🕒 Otherwise, it waits **1 hour** and checks again — up to **24 hours total**.
- 📝 All actions are logged to `carbon_scheduler_log.txt`.

> **Important:**  
> You must edit `slurm_green_scheduler.sh` and add your own ElectricityMap API token:
>
> ```bash
> AUTH_TOKEN="YOUR_API_KEY"
> ```

## 🌿 Workflow: `green_controlled_workflow.nf`

This Nextflow script integrates carbon-aware job scheduling using SLURM and real-time electricity carbon intensity data from `slurm_green_scheduler.sh`.

### Workflow Overview

- `calculate_daylight_start`: Executes the `slurm_green_scheduler.sh` script and returns SLURM `clusterOptions` (e.g. `--dependency=afterok:<jobid>`) through a channel called `cluster_options_ch`.
- This channel (`cluster_options_ch`) is passed to selected processes to control **when and under what conditions** they are allowed to start.
- `highenergy_std_task`: Uses `cluster_options_ch` to delay execution until carbon intensity is below a defined threshold.
- `standard_task`, `longrun_task`: Always run immediately, without green scheduling.
- `highenergy_memory_task`, `gpu_task`: Optional energy-aware jobs (commented out by default).

> 💤 Each process currently uses `sleep 30` as a placeholder — replace these lines with your actual job logic or scripts.

> ⚠️ Note: The real carbon-aware scheduling logic is implemented in `slurm_green_scheduler.sh`; this `.nf` file simply integrates its result via the `calculate_daylight_start` process.

## ⚙️ SLURM Configuration: `nextflow.config`

This file defines resource requirements and partition settings for each task label in the workflow. Each `process` label in the `.nf` file (e.g., `standard_partition`, `gpu_partition`) maps to SLURM parameters here.

Key highlights:

- ✅ Adjust `cpus`, `memory`, and `time` according to your cluster limits.
- 💡 Tasks like `highenergy_std_task` or `gpu_task` inherit these settings based on their label.
- ⚠️ Make sure your SLURM queue names (e.g., `'standard'`, `'gpu'`) match your institution's configuration.

> No changes needed unless your cluster uses different queue names or has stricter resource constraints.

## 🚀 SLURM Job Script: `nextflow_job.slurm`

This script submits the green-controlled workflow to SLURM.

### What It Does

- Initializes the required Java environment via SDKMAN.
- Loads the `nextflow` module from your cluster.
- Runs the `green_controlled_workflow.nf` script with optional monitoring:
  - `-resume`: resumes incomplete runs
  - `-with-trace`: generates a detailed task trace
  - `-with-report`: creates a summary report (HTML)
  - `-with-timeline`: shows task execution over time

## 📊 Monitoring & Logs

Once the workflow is submitted and running, you can track its progress and investigate results using the following tools:

### 🔍 Check Job Progress and SLURM Output

```bash
squeue -u $USER          # Show your queued or running jobs  
sacct -j <JOB_ID>        # Detailed info about a finished job
```
### 📂 Inspect Nextflow Logs

These are created by your nextflow_job.slurm submission script:
```bash
vi nextflow_output.log   # General workflow progress  
vi nextflow_error.log    # Any errors from Nextflow
```
### 🔬 Examine Individual Process Logs

Each Nextflow task is run in its own subdirectory under work/:
```bash
ls -lt work/ | head       # List the most recent process directories  
cd work/<hash>/           # Enter a specific process directory
```
Inside, you’ll typically find:

```bash
vi .command.sh      # View the SLURM command script
vi .command.log     # Output and SLURM messages
vi .command.err     # Error output (if any)
vi .command.out     # Standard output
```

### 🧼 Cleanup

To remove all intermediate files and cached Nextflow metadata, run:
```bash
rm -rf work/ .nextflow/ .nextflow.log nextflow_output.log nextflow_error.log
```
This resets the environment for a clean re-run.

## 🌍 Adaptation to Other Regions

To adapt for other countries or cities:

- Update `ZONE="XX"` in `slurm_green_scheduler.sh` with your [ElectricityMap](https://www.electricitymap.org/map) zone key.
- Make sure `jq` is available in your `$HOME` directory or via module.
- Adjust partition or resource labels in `nextflow.config` according to your SLURM cluster.
- The default `CARBON_THRESHOLD=250` (gCO₂eq/kWh) is defined in the slurm_green_scheduler.sh script. This is a reasonable starting point for moderately clean grids, but you should adapt this value to match the typical carbon intensity in your region. Use [ElectricityMap](https://www.electricitymap.org/) to find suitable thresholds.

---

## 🌍 Why Carbon-Aware Scheduling?

High-performance computing uses a significant amount of electricity, often when the grid relies on fossil fuels. By delaying **non-urgent, energy-intensive processes** until periods of **lower carbon intensity**, it's possible to reduce the **CO₂ equivalent emissions** of scientific computing.

This method gives users direct control. They decide which **processes** can wait and let the system run them when the grid is cleaner, based on real-time data. It supports more sustainable computing without automating decisions behind the scenes.

### References

[1] Google Research. *Carbon-Aware Computing for Datacenters*. arXiv:2106.11750, 2021. https://arxiv.org/abs/2106.11750

[2] D. Li et al. *CASPER: Carbon-Aware Scheduling and Provisioning for Distributed Web Services*. arXiv:2403.14792, 2024. https://arxiv.org/abs/2403.14792

[3] S. Ren et al. *LACS: Learning-Augmented Algorithms for Carbon-Aware Resource Scaling with Uncertain Demand*. arXiv:2404.15211, 2024. https://arxiv.org/abs/2404.15211

[4] K. Yang et al. *PCAPS: Carbon- and Precedence-Aware Scheduling for Data Processing Clusters*. arXiv:2502.09717, 2025. https://arxiv.org/abs/2502.09717

[5] A. Basso et al. *GAIA: Green for Less Green — Carbon-Aware Scheduling in Cloud Computing*. ASPLOS 2024. https://lass.cs.umass.edu/papers/pdf/asplos24-greenforlessgreen.pdf

[6] ElectricityMap. *Live carbon intensity data*. https://www.electricitymap.org/


## 📬 Contact

Questions, issues, or suggestions?
**Yagmur Kati** – [yagmur.kati@hu-berlin.de](mailto:yagmur.kati@hu-berlin.de)

## 📖 Citation

If you use this workflow in your research or HPC projects, please cite:

**Yagmur Kati**
*Carbon-Aware SLURM Workflow with Nextflow*
Humboldt-Universität zu Berlin, 2025
GitHub: [https://github.com/YagmurKati/carbon-aware-slurm-workflow](https://github.com/YagmurKati/carbon-aware-slurm-workflow)


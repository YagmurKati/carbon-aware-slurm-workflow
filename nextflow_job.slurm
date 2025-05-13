#!/bin/bash
#SBATCH --job-name=green_nextflow          # Job name displayed in SLURM
#SBATCH --output=nextflow_output.log       # File for standard output
#SBATCH --error=nextflow_error.log         # File for standard error

# Initialize SDKMAN to set up Java environment
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Use a specific Java version required by Nextflow (adjust if needed)
sdk use java 11.0.19-tem

# Load Nextflow module (assuming it's installed via environment modules)
module load nextflow

# Run the workflow with useful monitoring options
# -resume: continues from previous run if possible
# -with-trace: generates trace report of tasks
# -with-report: generates HTML execution report
# -with-timeline: generates interactive timeline
nextflow run green_controlled_workflow.nf -resume -with-trace -with-report -with-timeline


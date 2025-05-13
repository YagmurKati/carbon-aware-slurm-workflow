#!/bin/bash

# === CONFIGURATION SECTION ===

AUTH_TOKEN="YOUR_API_TOKEN_HERE"  # <-- REQUIRED: Replace with your ElectricityMap API token
ZONE="DE"                         # Zone key for Germany (see https://www.electricitymap.org/map for others)
CARBON_THRESHOLD=250             # Threshold in gCO₂eq/kWh to define "green" energy
MAX_HOURS=24                     # Max time (in hours) to wait for green conditions
JOB_ID="$1"                      # SLURM job ID passed as the first argument
JQ="$HOME/jq"                    # Path to local jq binary (used to parse JSON)

# === LOGGING ===

LOGFILE="carbon_scheduler_log.txt"
: > "$LOGFILE"  # Empty the log file at the beginning

# Simple logging function with timestamp
log() {
    echo "[`date '+%F %T'`] $1" >> "$LOGFILE"
}

# === INPUT VALIDATION ===

# Make sure a job ID was provided
if [ -z "$JOB_ID" ]; then
    echo "Usage: $0 <SLURM_JOB_ID>"
    exit 1
fi

log "Monitoring SLURM job $JOB_ID for green conditions..."

# === MAIN LOOP ===
# Loop up to MAX_HOURS times, once per hour
for hour in $(seq 1 $MAX_HOURS); do
    log "Checking carbon intensity (attempt $hour/$MAX_HOURS)..."

    # Query current carbon intensity using ElectricityMap API
    response=$(curl -s "https://api.electricitymap.org/v3/carbon-intensity/latest?zone=${ZONE}" \
        -H "auth-token: ${AUTH_TOKEN}")

    # Parse the carbon intensity value using jq
    carbon=$(echo "$response" | $JQ -r '.carbonIntensity')
    log "Current carbon intensity: ${carbon} gCO2/kWh"

    # Check if value is valid and below threshold
    if [[ "$carbon" =~ ^[0-9]+$ ]] && [[ "$carbon" -lt "$CARBON_THRESHOLD" ]]; then
        log "Green condition met - releasing job $JOB_ID"
        scontrol release "$JOB_ID"  # Release the held SLURM job
        exit 0
    fi

    # Wait 1 hour and retry
    next_check=$(date -d "+1 hour" +%H:%M:%S)
    log "Too much carbon - retrying at $next_check"
    sleep 3600
done

# === FALLBACK ===
# If 24 hours passed and green conditions never met, release the job anyway
log "Max delay reached - releasing job $JOB_ID anyway"
scontrol release "$JOB_ID"


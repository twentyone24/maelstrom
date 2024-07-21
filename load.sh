#!/bin/bash

# Configurations
CONFIG_FILE="maelstrom.conf"
LOG_FILE="loadtest.log"

# Load configurations
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "Configuration file not found!"
        exit 1
    fi
}

# Print the logo
print_logo() {
    echo "\033[1;34m
    ███╗   ███╗ █████╗ ███████╗██╗     ███████╗████████╗██████╗  ██████╗ ███╗   ███╗
    ████╗ ████║██╔══██╗██╔════╝██║     ██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗████╗ ████║
    ██╔████╔██║███████║█████╗  ██║     ███████╗   ██║   ██████╔╝██║   ██║██╔████╔██║
    ██║╚██╔╝██║██╔══██║██╔══╝  ██║     ╚════██║   ██║   ██╔══██╗██║   ██║██║╚██╔╝██║
    ██║ ╚═╝ ██║██║  ██║███████╗███████╗███████║   ██║   ██║  ██║╚██████╔╝██║ ╚═╝ ██║
    ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝
    \033[0m"
}

# Prompt for user input with default values
prompt_for_input() {
    echo "\033[0;36m🔧 Enter configuration values. Press Enter to keep default.\033[0m"
    read -p "Number of requests (default: 1000): " N
    read -p "Number of concurrent threads (default: 10): " THREADS
    read -p "URL to test (default: https://api.sampleapis.com/coffee/hot): " URL
    read -p "Retry limit for failed requests (default: 3): " RETRY_LIMIT
    read -p "Response time threshold in seconds (default: 2.0): " THRESHOLD_TIME
    read -p "Success rate threshold in percentage (default: 95): " THRESHOLD_SUCCESS
    read -p "Enable email notifications (true/false, default: false): " EMAIL_ENABLED
    read -p "Email address for notifications (default: empty): " EMAIL_TO

    # Set default values if no input is provided
    N=${N:-1000}
    THREADS=${THREADS:-10}
    URL=${URL:-https://api.sampleapis.com/coffee/hot}
    RETRY_LIMIT=${RETRY_LIMIT:-3}
    THRESHOLD_TIME=${THRESHOLD_TIME:-2.0}
    THRESHOLD_SUCCESS=${THRESHOLD_SUCCESS:-95}
    EMAIL_ENABLED=${EMAIL_ENABLED:-false}
    EMAIL_TO=${EMAIL_TO:-}

    echo "\033[1;34mStarting load test with $N requests and $THREADS threads...\033[0m"
}

# Spinner function
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='-\|/'

    while [ -d /proc/$pid ]; do
        for s in $spinstr; do
            printf "\r%s" "$s"
            sleep $delay
        done
    done
    printf "\r> WARMUP COMPLETE, STARTING UP THE STORM\n"
}

# Make a request with retry logic and detailed logging
make_request() {
    local thread_id=$1
    local attempt=0
    local max_attempts=$RETRY_LIMIT
    local success=0
    local response
    local HTTP_CODE
    local TIME_TAKEN
    local TIMESTAMP
    local RED='\033[0;91m'
    local GREEN='\033[0;92m'
    local YELLOW='\033[0;93m'
    local NC='\033[0m'

    while [ $attempt -lt $max_attempts ]; do
        response=$(curl -o /dev/null -s -w "%{http_code} %{time_total}\n" "$URL")
        HTTP_CODE=$(echo "$response" | awk '{print $1}')
        TIME_TAKEN=$(echo "$response" | awk '{print $2}')
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

        if [[ $HTTP_CODE -ge 200 && $HTTP_CODE -lt 300 ]]; then
            HTTP_COLOR=$GREEN
        elif [[ $HTTP_CODE -ge 300 && $HTTP_CODE -lt 400 ]]; then
            HTTP_COLOR=$YELLOW
        else
            HTTP_COLOR=$RED
            FAILED_REQUESTS+=("$HTTP_CODE")
        fi

        if (($(echo "$TIME_TAKEN > 1" | bc -l))); then
            TIME_COLOR=$RED
        else
            TIME_COLOR=$GREEN
        fi

        RESPONSE_TIMES+=("$TIME_TAKEN")
        ((COMPLETED_REQUESTS++))

        printf "%s [Thread %2d] Response: ${HTTP_COLOR}%3d${NC}, Time taken: ${TIME_COLOR}%6.2fs${NC}\n" "$TIMESTAMP" "$thread_id" "$HTTP_CODE" "$TIME_TAKEN"

        echo "$TIME_TAKEN" >>"$TEMP_RESPONSE_FILE"

        if [[ $HTTP_CODE -ge 400 ]]; then
            echo "$HTTP_CODE" >>"$TEMP_FAILED_FILE"
        fi

        echo "1" >>"$TEMP_COMPLETED_FILE"

        success=1
        break
    done

    if [ $success -eq 0 ]; then
        echo "$thread_id" >>"$TEMP_FAILED_FILE"
    fi
}

# Results function
results() {
    local total_requests
    local successful_requests
    local failed_requests
    local avg_response_time
    local success_rate

    total_requests=$(wc -l <"$TEMP_COMPLETED_FILE")
    successful_requests=$(grep -c . "$TEMP_COMPLETED_FILE")
    failed_requests=$(grep -c . "$TEMP_FAILED_FILE")
    avg_response_time=$(awk '{ total += $1; count++ } END { if (count > 0) print total / count; else print 0 }' "$TEMP_RESPONSE_FILE")
    success_rate=$(awk "BEGIN {print ($successful_requests / $total_requests) * 100}")
    echo "\n\033[1;34m========================================\033[0m"
    echo "\033[1;34mRESULTS:\033[0m"
    echo "- Total requests: $total_requests"
    echo "- Successful requests: $successful_requests"
    echo "- Failed requests: $failed_requests"
    echo "- Average response time: $avg_response_time seconds"
    echo "- Success rate: $success_rate%"

    if (($(echo "$avg_response_time > $THRESHOLD_TIME" | bc -l))); then
        echo "- Average response time is higher than the threshold. 🚩" | tee -a "$LOG_FILE"
    else
        echo "- Average response time is within the acceptable range. 👍" | tee -a "$LOG_FILE"
    fi

    if (($(echo "$success_rate < $THRESHOLD_SUCCESS" | bc -l))); then
        echo "- Success rate is lower than the threshold. 🚩" | tee -a "$LOG_FILE"
    else
        echo "- Success rate meets the threshold. ✔️" | tee -a "$LOG_FILE"
    fi
    echo "\033[1;34m========================================\033[0m"
}

# Send email notification
send_email() {
    if [ "$EMAIL_ENABLED" = "true" ]; then
        echo "Sending email notification to $EMAIL_TO..."

        # Construct the email subject and body
        local subject="Load Test Report"

        # Use a temporary file to store the email body
        local temp_file=$(mktemp)

        {
            echo "Load Test Report:"
            echo ""
            echo "Total requests: $N"
            echo "Number of concurrent threads: $THREADS"
            echo "URL tested: $URL"
            echo "Retry limit: $RETRY_LIMIT"
            echo "Response time threshold: $THRESHOLD_TIME seconds"
            echo "Success rate threshold: $THRESHOLD_SUCCESS%"
            echo ""
            echo "Results:"
            echo "- Total requests: $total_requests"
            echo "- Successful requests: $successful_requests"
            echo "- Failed requests: $failed_requests"
            echo "- Average response time: $avg_response_time seconds"
            echo "- Success rate: $success_rate%"
            echo ""

            # Check average response time
            if (($(echo "$avg_response_time > $THRESHOLD_TIME" | bc -l))); then
                echo "- Average response time is higher than the threshold. 🚩"
            else
                echo "- Average response time is within the acceptable range. 👍"
            fi

            # Check success rate
            if (($(echo "$success_rate < $THRESHOLD_SUCCESS" | bc -l))); then
                echo "- Success rate is lower than the threshold. 🚩"
            else
                echo "- Success rate meets the threshold. ✔️"
            fi
        } >"$temp_file"

        # Send the email using the temporary file as the body
        mail -s "$subject" "$EMAIL_TO" <"$temp_file"

        # Clean up temporary file
        rm "$temp_file"
    fi
}

# Cleanup function
cleanup() {
    echo "\n\033[0;91mInterrupt received, stopping test...\033[0m"
    # Kill all background request processes
    for pid in "${request_pids[@]}"; do
        kill "$pid" 2>/dev/null
    done
    wait
    results
    send_email
    rm -f "$TEMP_COMPLETED_FILE" "$TEMP_FAILED_FILE" "$TEMP_RESPONSE_FILE"
    exit 0
}

# Trap signals
trap cleanup INT TERM

# Main script execution
load_config
print_logo
prompt_for_input

# Temporary files
TEMP_COMPLETED_FILE=$(mktemp)
TEMP_FAILED_FILE=$(mktemp)
TEMP_RESPONSE_FILE=$(mktemp)

# Start spinner
show_spinner $$ &
spinner_pid=$!

# Initialize request pids array
declare -a request_pids

# Perform load test
for ((i = 1; i <= THREADS; i++)); do
    (
        for ((j = 1; j <= N / THREADS; j++)); do
            make_request "$i"
        done
    ) &
    request_pids+=($!)
done

# Wait for all background jobs to complete
wait

# Cleanup and results
cleanup

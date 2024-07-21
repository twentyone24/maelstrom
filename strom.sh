#!/bin/bash

# Default configuration values
N=1000
THREADS=10
URL="https://api.sampleapis.com/coffee/hot"
RETRY_LIMIT=3
THRESHOLD_TIME=2.0
THRESHOLD_SUCCESS=95
EMAIL_ENABLED=false
EMAIL_TO=""
CURL_MAX_TIME=10
LOG_FILE=""
TEMP_COMPLETED_FILE=$(mktemp)
TEMP_FAILED_FILE=$(mktemp)
TEMP_RESPONSE_FILE=$(mktemp)

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
    echo "\n\033[0;36m🔧 Enter configuration values. Press Enter to keep default.\033[0m"
    read -p "Number of requests (default: $N): " input_N
    read -p "Number of concurrent threads (default: $THREADS): " input_THREADS
    read -p "URL to test (default: $URL): " input_URL
    read -p "Retry limit for failed requests (default: $RETRY_LIMIT): " input_RETRY_LIMIT
    read -p "Response time threshold in seconds (default: $THRESHOLD_TIME): " input_THRESHOLD_TIME
    read -p "Success rate threshold in percentage (default: $THRESHOLD_SUCCESS): " input_THRESHOLD_SUCCESS
    read -p "Enable email notifications (true/false, default: $EMAIL_ENABLED): " input_EMAIL_ENABLED
    read -p "Email address for notifications (default: $EMAIL_TO): " input_EMAIL_TO
    read -p "Curl max-time in seconds (default: $CURL_MAX_TIME): " input_CURL_MAX_TIME
    read -p "Log file path (leave empty for no logging): " input_LOG_FILE

    # Set default values if no input is provided
    N=${input_N:-${N}}
    THREADS=${input_THREADS:-${THREADS}}
    URL=${input_URL:-${URL}}
    RETRY_LIMIT=${input_RETRY_LIMIT:-${RETRY_LIMIT}}
    THRESHOLD_TIME=${input_THRESHOLD_TIME:-${THRESHOLD_TIME}}
    THRESHOLD_SUCCESS=${input_THRESHOLD_SUCCESS:-${THRESHOLD_SUCCESS}}
    EMAIL_ENABLED=${input_EMAIL_ENABLED:-${EMAIL_ENABLED}}
    EMAIL_TO=${input_EMAIL_TO:-${EMAIL_TO}}
    CURL_MAX_TIME=${input_CURL_MAX_TIME:-${CURL_MAX_TIME}}
    LOG_FILE=${input_LOG_FILE}

    if [ -n "$LOG_FILE" ] && ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Log file path is not writable. Logging will be disabled."
        LOG_FILE=""
    fi

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
}

# Make a request with retry logic and detailed logging
make_request() {
    local thread_id=$1
    local attempt=0
    local max_attempts=$RETRY_LIMIT
    local success=0
    local response
    local http_code
    local time_taken
    local timestamp
    local RED='\033[0;91m'
    local GREEN='\033[0;92m'
    local YELLOW='\033[0;93m'
    local NC='\033[0m'

    while [ $attempt -lt $max_attempts ]; do
        response=$(curl -o /dev/null -s -w "%{http_code} %{time_total}\n" --max-time $CURL_MAX_TIME "$URL")
        http_code=$(echo "$response" | awk '{print $1}')
        time_taken=$(echo "$response" | awk '{print $2}')
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        if [[ $http_code -ge 200 && $http_code -lt 300 ]]; then
            http_color=$GREEN
        elif [[ $http_code -ge 300 && $http_code -lt 400 ]]; then
            http_color=$YELLOW
        else
            http_color=$RED
            FAILED_REQUESTS+=("$http_code")
        fi

        if (($(echo "$time_taken > 1" | bc -l))); then
            time_color=$RED
        else
            time_color=$GREEN
        fi

        RESPONSE_TIMES+=("$time_taken")
        ((COMPLETED_REQUESTS++))

        printf "%s [Thread %2d] Response: ${http_color}%3d${NC}, Time taken: ${time_color}%6.2fs${NC}\n" "$timestamp" "$thread_id" "$http_code" "$time_taken"

        echo "$time_taken" >>"$TEMP_RESPONSE_FILE"

        if [[ $http_code -ge 400 ]]; then
            echo "$http_code" >>"$TEMP_FAILED_FILE"
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
        echo "- Average response time is higher than the threshold. 🚩"
        [ -n "$LOG_FILE" ] && echo "- Average response time is higher than the threshold. 🚩" >>"$LOG_FILE"
    else
        echo "- Average response time is within the acceptable range. 👍"
        [ -n "$LOG_FILE" ] && echo "- Average response time is within the acceptable range. 👍" >>"$LOG_FILE"
    fi

    if (($(echo "$success_rate < $THRESHOLD_SUCCESS" | bc -l))); then
        echo "- Success rate is lower than the threshold. 🚩"
        [ -n "$LOG_FILE" ] && echo "- Success rate is lower than the threshold. 🚩" >>"$LOG_FILE"
    else
        echo "- Success rate meets the threshold. ✔️"
        [ -n "$LOG_FILE" ] && echo "- Success rate meets the threshold. ✔️" >>"$LOG_FILE"
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
            results
        } >"$temp_file"

        # Send the email
        if command -v mail >/dev/null; then
            mail -s "$subject" "$EMAIL_TO" <"$temp_file"
            echo "Email sent successfully."
        else
            echo "Mail command is not available. Please install mailutils or similar to enable email notifications."
        fi

        # Remove the temporary file
        rm -f "$temp_file"
    fi
}

# Cleanup temporary files
cleanup() {
    echo "\n\033[0;91mInterrupt received, stopping test...\033[0m"
    # Kill all background request processes
    for pid in "${request_pids[@]}"; do
        kill "$pid" 2>/dev/null
    done

    if [[ -n ${spinner_pid} ]] && ps -p "${spinner_pid}" >/dev/null; then
        kill "$((spinner_pid))"
        wait "${spinner_pid}" 2>/dev/null || true
    fi
    wait
    results
    send_email
    rm -f "$TEMP_COMPLETED_FILE" "$TEMP_FAILED_FILE" "$TEMP_RESPONSE_FILE"
    exit 0
}

# Trap signals
trap cleanup INT TERM

# Main script execution
main() {
    print_logo
    prompt_for_input

    TEMP_COMPLETED_FILE=$(mktemp)
    TEMP_FAILED_FILE=$(mktemp)
    TEMP_RESPONSE_FILE=$(mktemp)

    RESPONSE_TIMES=()
    FAILED_REQUESTS=()
    COMPLETED_REQUESTS=0

    echo "Starting warmup..."

    show_spinner $$ &
    spinner_pid=$!

    for ((i = 1; i <= THREADS; i++)); do
        make_request "$i" &
    done

    wait

    # Stop the spinner once warmup is complete
    if [[ -n ${spinner_pid} ]] && ps -p "${spinner_pid}" >/dev/null; then
        kill "$((spinner_pid))"
        wait "${spinner_pid}" 2>/dev/null || true
    fi

    printf "\n\r> WARMUP COMPLETE, STARTING UP THE STORM\n"
    echo "\033[1;34m========================================\033[0m"

    # Initialize request PIDs array
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

    wait

    results

    if [[ ${EMAIL_ENABLED} == "true" ]]; then
        send_email
    fi

    # Clean up temporary files
    rm -f "${TEMP_COMPLETED_FILE}" "${TEMP_FAILED_FILE}" "${TEMP_RESPONSE_FILE}"
    echo "\n\033[1;32m✅ Load test completed.\033[0m"
}

main

```
███╗   ███╗ █████╗ ███████╗██╗     ███████╗████████╗██████╗  ██████╗ ███╗   ███╗
████╗ ████║██╔══██╗██╔════╝██║     ██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗████╗ ████║
██╔████╔██║███████║█████╗  ██║     ███████╗   ██║   ██████╔╝██║   ██║██╔████╔██║
██║╚██╔╝██║██╔══██║██╔══╝  ██║     ╚════██║   ██║   ██╔══██╗██║   ██║██║╚██╔╝██║
██║ ╚═╝ ██║██║  ██║███████╗███████╗███████║   ██║   ██║  ██║╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝
```

<!-- 
<p align="center">
  <a href="https://github.com/twentyone24/maelstrom?tab=MIT-1-ov-file"><img alt="License" src="https://img.shields.io/github/license/twenyone24/maelstrom?style=for-the-badge&logo=github&color=1A91FF"/></a>
</p> -->
<p align="center">A performant and lightweight A lightweight stress test script that uses concurrent threads to test a URL, with configurable parameters, detailed logging, and email notifications</p>

---
## Features

- **Configurable Parameters**: Customize the number of requests, concurrency level, URL to test, retry limits, response time thresholds, and success rate thresholds.
- **Detailed Logging**: Captures detailed information about each request, including HTTP status codes and response times.
- **Email Notifications**: Optionally sends email notifications with a summary of test results.
- **Graceful Shutdown**: Handles interruptions gracefully, ensuring that results are logged and notifications are sent.
- **Latency Metrics**: Helps understand average latency of APIs helping you understand if the latency increases.
- **Multi-threaded by design**: Simulates multi-threaded concurrent requests to API Endpoints and you can configure the thread count.

## Prerequisites

- **Curl**: Required for making HTTP requests. Ensure it is installed on your system.
- **Mail**: Required for sending email notifications (if enabled). Install a mail utility like `mailx` or `sendmail`.
- **bc**: Required for floating-point arithmetic in shell scripts. Ensure it is installed.

## Configuration

### Configuration File (`maelstrom.conf`)

The script reads configuration values from `maelstrom.conf`. Here’s an example of how to structure this file:

```bash
# maelstrom.conf
N=1000
THREADS=10
URL=https://api.sampleapis.com/coffee/hot
RETRY_LIMIT=3
THRESHOLD_TIME=2.0
THRESHOLD_SUCCESS=95
EMAIL_ENABLED=false
EMAIL_TO=
```

### Parameters

- **Number of requests (`N`)**: Total number of HTTP requests to be performed.
- **Number of concurrent threads (`THREADS`)**: Number of concurrent threads to be used for the load test.
- **URL to test (`URL`)**: The endpoint URL where the load test will be executed.
- **Retry limit (`RETRY_LIMIT`)**: Number of retry attempts for failed requests.
- **Response time threshold (`THRESHOLD_TIME`)**: Maximum acceptable response time in seconds.
- **Success rate threshold (`THRESHOLD_SUCCESS`)**: Minimum acceptable success rate percentage.
- **Enable email notifications (`EMAIL_ENABLED`)**: Boolean value to enable or disable email notifications.
- **Email address for notifications (`EMAIL_TO`)**: Recipient email address for notifications.

## Usage

1. **Prepare the Configuration File**

   Create a `maelstrom.conf` file in the same directory as the script. Set your desired configuration values as described in the [Configuration](#configuration) section.

2. **Run the Script**

   Make the script executable and run it:

   ```bash
   chmod +x load_test.sh
   ./load_test.sh
   ```

3. **Monitor the Load Test**

   The script will output progress and results to the terminal. You can monitor real-time updates during the test.

4. **Review Results**

   Upon completion, the script will display results including total requests, successful requests, failed requests, average response time, and success rate.

5. **Email Notifications**

   If email notifications are enabled, the script will send an email with the test results to the specified address.

## Handling Interruptions

The script is designed to handle interruptions gracefully. To stop the test, press `Ctrl+C` or send a termination signal. The script will log the results and send email notifications if configured.

## Example Output

```bash
🔧 Enter configuration values. Press Enter to keep default.
Number of requests (default: 1000): 1000
Number of concurrent threads (default: 10): 10
URL to test (default: https://api.sampleapis.com/coffee/hot): https://api.sampleapis.com/coffee/hot
Retry limit for failed requests (default: 3): 3
Response time threshold in seconds (default: 2.0): 2.0
Success rate threshold in percentage (default: 95): 95
Enable email notifications (true/false, default: false): false
Email address for notifications (default: empty): 

Starting load test with 1000 requests and 10 threads...

> WARMUP COMPLETE, STARTING UP THE STORM

[Thread  1] Response: 200, Time taken: 0.45s
[Thread  2] Response: 500, Time taken: 1.22s
...

========================================
RESULTS:
- Total requests: 1000
- Successful requests: 950
- Failed requests: 50
- Average response time: 1.35 seconds
- Success rate: 95%

- Average response time is within the acceptable range. 👍
- Success rate meets the threshold. ✔️
========================================
```

## Troubleshooting

- **Configuration File Not Found**: Ensure `maelstrom.conf` is present in the same directory as the script.
- **Mail Command Not Found**: Install a mail utility like `mailx` or `sendmail` for email notifications.

## License

This script is licensed under the MIT License. See [LICENSE](LICENSE) for details.
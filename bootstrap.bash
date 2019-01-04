#!/bin/sh +x

# This is a test file to show bash based bootstrap.  
# It does not work with current version of the swift code in this repo.
# Do not use this in production as this bash based bootstrap takes >1000ms execution time 
# due to many small processes fork and standard pipes being used to communicate between processes.

EXECUTABLE=$LAMBDA_TASK_ROOT/"$(echo $_HANDLER | cut -d. -f1)"

# Processing
while true
do
    HEADERS="$(mktemp)"
    # Get an event
    EVENT_DATA=$(curl -sS -LD "$HEADERS" -X GET "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next")
    REQUEST_ID=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)
    echo "Received Request ID : $REQUEST_ID with payload: $EVENT_DATA"
    X_AMZN_TRACE_ID=$(grep -Fi Lambda-Runtime-Trace-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)

    # Execute the handler function from the script
    RESPONSE=$(/opt/lib/ld-linux-x86-64.so.2 --library-path /opt/lib $EXECUTABLE $EVENT_DATA)

    # Send the response
    echo "Posting response to http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response"
    echo "Response = " $RESPONSE
    curl -sS -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response"  -d "$RESPONSE" #> /dev/null

done

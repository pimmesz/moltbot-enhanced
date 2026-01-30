#!/bin/bash
# Unraid Container Control Script
# Manages Docker containers via Unraid GraphQL API

set -euo pipefail

UNRAID_HOST="192.168.2.96"
API_KEY="2c84f3e3daa457bcdb01f52e6ab19de39776a89d07118e432d354761252d144a"

usage() {
    echo "Usage: $0 <action> <container-name>"
    echo "Actions: start, stop, restart, status, list"
    echo "Example: $0 start Plex-Media-Server"
    exit 1
}

graphql_query() {
    local query="$1"
    curl -s -X POST "http://${UNRAID_HOST}/graphql" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: ${API_KEY}" \
        -d "{\"query\": \"${query}\"}" 2>/dev/null
}

get_container_info() {
    local container_name="$1"
    graphql_query "{ docker { containers { id names state } } }" | \
        jq -r ".data.docker.containers[] | select(.names[0] == \"/${container_name}\") | {id, names, state}" 2>/dev/null
}

list_containers() {
    echo "🐳 Docker Containers:"
    graphql_query "{ docker { containers { id names state } } }" | \
        jq -r '.data.docker.containers[] | "\(.names[0]) - \(.state)"' 2>/dev/null | \
        sed 's/^\//-/' | sort
}

start_container() {
    local container_name="$1"
    local container_info
    container_info=$(get_container_info "$container_name")
    
    if [ -z "$container_info" ] || [ "$container_info" = "null" ]; then
        echo "❌ Container '$container_name' not found"
        return 1
    fi
    
    local container_id
    container_id=$(echo "$container_info" | jq -r '.id')
    
    echo "🚀 Starting container: $container_name"
    local result
    result=$(graphql_query "mutation { docker { start(id: \"${container_id}\") { id names state } } }")
    
    if echo "$result" | jq -e '.errors' >/dev/null 2>&1; then
        echo "❌ Failed to start container:"
        echo "$result" | jq -r '.errors[0].message'
        return 1
    else
        echo "✅ Container started successfully"
        echo "$result" | jq -r '.data.docker.start | "\(.names[0]) - \(.state)"' | sed 's/^\//-/'
    fi
}

stop_container() {
    local container_name="$1"
    local container_info
    container_info=$(get_container_info "$container_name")
    
    if [ -z "$container_info" ] || [ "$container_info" = "null" ]; then
        echo "❌ Container '$container_name' not found"
        return 1
    fi
    
    local container_id
    container_id=$(echo "$container_info" | jq -r '.id')
    
    echo "🛑 Stopping container: $container_name"
    local result
    result=$(graphql_query "mutation { docker { stop(id: \"${container_id}\") { id names state } } }")
    
    if echo "$result" | jq -e '.errors' >/dev/null 2>&1; then
        echo "❌ Failed to stop container:"
        echo "$result" | jq -r '.errors[0].message'
        return 1
    else
        echo "✅ Container stopped successfully"
    fi
}

show_status() {
    local container_name="$1"
    local container_info
    container_info=$(get_container_info "$container_name")
    
    if [ -z "$container_info" ] || [ "$container_info" = "null" ]; then
        echo "❌ Container '$container_name' not found"
        return 1
    fi
    
    echo "📊 Container Status:"
    echo "$container_info" | jq -r '"Name: \(.names[0])\nState: \(.state)\nID: \(.id)"'
}

# Main script logic
if [ $# -lt 1 ]; then
    usage
fi

ACTION="$1"

case "$ACTION" in
    "list")
        list_containers
        ;;
    "start"|"stop"|"restart"|"status")
        if [ $# -ne 2 ]; then
            usage
        fi
        CONTAINER="$2"
        case "$ACTION" in
            "start")
                start_container "$CONTAINER"
                ;;
            "stop")
                stop_container "$CONTAINER"
                ;;
            "restart")
                stop_container "$CONTAINER"
                sleep 2
                start_container "$CONTAINER"
                ;;
            "status")
                show_status "$CONTAINER"
                ;;
        esac
        ;;
    *)
        echo "❌ Unknown action: $ACTION"
        usage
        ;;
esac
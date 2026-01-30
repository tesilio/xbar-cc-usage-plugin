#!/bin/bash

# <xbar.title>Claude Code Usage</xbar.title>
# <xbar.version>v1.1</xbar.version>
# <xbar.author>Sehyun</xbar.author>
# <xbar.author.github>tesilio</xbar.author.github>
# <xbar.desc>Real-time Claude Code usage monitoring</xbar.desc>
# <xbar.dependencies>jq,bc</xbar.dependencies>
# <xbar.var>number(REFRESH_INTERVAL=30): Refresh interval (seconds)</xbar.var>

# Add Homebrew path
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Constants

OAUTH_TOKEN_URL="https://platform.claude.com/v1/oauth/token"
USAGE_API_URL="https://api.anthropic.com/api/oauth/usage"

# Refresh interval (configurable in xbar settings)
REFRESH_INTERVAL=${REFRESH_INTERVAL:-30}

# Cache directory
CACHE_DIR="$HOME/.claude/.cache"
CACHE_FILE="$CACHE_DIR/usage-api.json"
CACHE_TTL=$REFRESH_INTERVAL

# Error display function
show_error() {
    local message=$1
    echo "⚠️ | color=#ef4444"
    echo "---"
    echo "Error: $message | color=#ef4444"
    echo "---"
    echo "Refresh | refresh=true"
    exit 1
}

# Get cache
get_cache() {
    if [ ! -f "$CACHE_FILE" ]; then
        return 1
    fi

    local cache_timestamp=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null)
    if [ -z "$cache_timestamp" ] || [ "$cache_timestamp" = "null" ]; then
        return 1
    fi

    local now=$(date "+%s")
    local age=$((now - cache_timestamp))

    if [ "$age" -lt "$CACHE_TTL" ]; then
        # Cache is valid
        jq -r '.data' "$CACHE_FILE" 2>/dev/null
        return 0
    fi

    return 1
}

# Save cache
set_cache() {
    local data=$1
    mkdir -p "$CACHE_DIR"
    local tmp_file="$CACHE_FILE.$$"
    local now=$(date "+%s")
    if jq -n --argjson ts "$now" --argjson data "$data" '{timestamp: $ts, data: $data}' > "$tmp_file"; then
        mv "$tmp_file" "$CACHE_FILE"
    else
        rm -f "$tmp_file"
    fi
}

# Refresh token
refresh_access_token() {
    local refresh_token=$1

    local response=$(curl -s --connect-timeout 5 --max-time 10 -X POST "$OAUTH_TOKEN_URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=$refresh_token" \
        -d "client_id=$OAUTH_CLIENT_ID")

    local new_access_token=$(echo "$response" | jq -r '.access_token // empty' 2>/dev/null)
    local new_refresh_token=$(echo "$response" | jq -r '.refresh_token // empty' 2>/dev/null)
    local expires_in=$(echo "$response" | jq -r '.expires_in // empty' 2>/dev/null)

    if [ -n "$new_access_token" ] && [ "$new_access_token" != "null" ]; then
        # Update Keychain
        local keychain_raw=$(/usr/bin/security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        local keychain_json=$(decode_keychain_value "$keychain_raw")
        if [ -n "$keychain_json" ]; then
            local now_ms=$(($(date +%s) * 1000))
            local expires_at=$((now_ms + expires_in * 1000))

            local updated_json=$(echo "$keychain_json" | jq \
                --arg at "$new_access_token" \
                --arg rt "${new_refresh_token:-$refresh_token}" \
                --argjson ea "$expires_at" \
                '.claudeAiOauth.accessToken = $at | .claudeAiOauth.refreshToken = $rt | .claudeAiOauth.expiresAt = $ea')

            /usr/bin/security delete-generic-password -s "Claude Code-credentials" 2>/dev/null
            /usr/bin/security add-generic-password -s "Claude Code-credentials" -a "Claude Code" -w "$updated_json" 2>/dev/null
        fi

        echo "$new_access_token"
        return 0
    fi

    return 1
}

# Decode Keychain value (hex or plain text)
decode_keychain_value() {
    local raw_value=$1

    # If starts with JSON, it's plain text
    if [[ "$raw_value" == "{"* ]]; then
        echo "$raw_value"
        return
    fi

    # Check if hex encoded (7b = '{')
    if [[ "$raw_value" == 7b* ]] && [[ "$raw_value" =~ ^[0-9a-fA-F]+$ ]]; then
        echo "$raw_value" | xxd -r -p 2>/dev/null
        return
    fi

    # Otherwise return as-is
    echo "$raw_value"
}

# Get access token
get_access_token() {
    # 1. Try macOS Keychain (stored in JSON format)
    local keychain_raw=$(/usr/bin/security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    local keychain_json=$(decode_keychain_value "$keychain_raw")
    if [ -n "$keychain_json" ]; then
        local token=$(echo "$keychain_json" | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null)
        local refresh_token=$(echo "$keychain_json" | jq -r '.claudeAiOauth.refreshToken // empty' 2>/dev/null)
        local expires_at=$(echo "$keychain_json" | jq -r '.claudeAiOauth.expiresAt // 0' 2>/dev/null)
        local now_ms=$(($(date +%s) * 1000))

        # Try to refresh if expires within 5 minutes
        local buffer_ms=$((5 * 60 * 1000))
        if [ -n "$expires_at" ] && [ "$expires_at" != "null" ] && [ "$((expires_at - buffer_ms))" -lt "$now_ms" ]; then
            if [ -n "$refresh_token" ] && [ "$refresh_token" != "null" ]; then
                local new_token=$(refresh_access_token "$refresh_token")
                if [ -n "$new_token" ]; then
                    echo "$new_token"
                    return 0
                fi
            fi
        fi

        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi

    # 2. File fallback
    local cred_file="$HOME/.claude/.credentials.json"
    if [ -f "$cred_file" ]; then
        # Prefer claudeAiOauth.accessToken, fallback to root accessToken
        local token=$(jq -r '.claudeAiOauth.accessToken // .accessToken // empty' "$cred_file")
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi

    return 1
}

# Calculate reset time (short version - for menu bar)
get_reset_time_short() {
    local reset_iso=$1

    # Check for empty or null input
    if [ -z "$reset_iso" ] || [ "$reset_iso" = "null" ]; then
        echo "?"
        return
    fi

    # Normalize ISO 8601: remove milliseconds, convert +00:00 to Z
    local clean_iso=$(echo "$reset_iso" | sed -E 's/\.[0-9]+//; s/\+00:00$/Z/')

    # Parse ISO 8601 with macOS date command (interpret as UTC)
    local reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$clean_iso" "+%s" 2>/dev/null)
    if [ -z "$reset_epoch" ]; then
        # Try without Z
        reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${clean_iso%Z}" "+%s" 2>/dev/null)
    fi

    if [ -z "$reset_epoch" ]; then
        echo "?"
        return
    fi

    local now_epoch=$(date "+%s")
    local diff=$((reset_epoch - now_epoch))

    if [ "$diff" -lt 0 ]; then
        echo "Reset"
        return
    fi

    # Check if reset time is today
    local today=$(date "+%Y-%m-%d")
    local reset_date=$(date -r "$reset_epoch" "+%Y-%m-%d")

    if [ "$today" = "$reset_date" ]; then
        # If today, show HH:MM
        date -r "$reset_epoch" "+%H:%M"
    else
        # If different day, show M/D HH:MM
        date -r "$reset_epoch" "+%-m/%-d %H:%M"
    fi
}

# Calculate reset time
calculate_reset_time() {
    local reset_iso=$1

    # Normalize ISO 8601: remove milliseconds, convert +00:00 to Z
    local clean_iso=$(echo "$reset_iso" | sed -E 's/\.[0-9]+//; s/\+00:00$/Z/')

    # Parse ISO 8601 with macOS date command (interpret as UTC)
    local reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$clean_iso" "+%s" 2>/dev/null)
    if [ -z "$reset_epoch" ]; then
        # Try without Z
        reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${clean_iso%Z}" "+%s" 2>/dev/null)
    fi

    if [ -z "$reset_epoch" ]; then
        echo "Parse failed"
        return
    fi

    local now_epoch=$(date "+%s")
    local diff=$((reset_epoch - now_epoch))

    if [ "$diff" -lt 0 ]; then
        echo "Reset"
        return
    fi

    local days=$((diff / 86400))
    local hours=$(((diff % 86400) / 3600))
    local minutes=$(((diff % 3600) / 60))

    # Relative time
    local relative=""
    if [ "$days" -gt 0 ]; then
        relative="in ${days}d ${hours}h"
    elif [ "$hours" -gt 0 ]; then
        relative="in ${hours}h ${minutes}m"
    else
        relative="in ${minutes}m"
    fi

    # Absolute time
    local absolute
    if [ "$days" -gt 0 ]; then
        absolute=$(date -r "$reset_epoch" "+%-m/%-d")
    else
        absolute=$(date -r "$reset_epoch" "+%H:%M")
    fi

    echo "$relative ($absolute)"
}

# API call function
call_usage_api() {
    local token=$1
    curl -s --connect-timeout 5 --max-time 10 -w "\n%{http_code}" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" \
        "$USAGE_API_URL"
}

# Color selection function
get_color() {
    local utilization=$1

    if (( $(echo "$utilization < 70" | bc -l) )); then
        echo "#22c55e"
    elif (( $(echo "$utilization < 90" | bc -l) )); then
        echo "#eab308"
    else
        echo "#ef4444"
    fi
}

# Main logic

# Check dependencies
if ! command -v jq &> /dev/null || ! command -v bc &> /dev/null; then
    show_error "jq or bc not installed"
fi

# Check cache
CACHED_BODY=$(get_cache)
if [ $? -eq 0 ] && [ -n "$CACHED_BODY" ]; then
    BODY="$CACHED_BODY"
else
    # Get access token
    ACCESS_TOKEN=$(get_access_token)
    if [ -z "$ACCESS_TOKEN" ]; then
        show_error "Credentials not found"
    fi

    # Call API
    RESPONSE=$(call_usage_api "$ACCESS_TOKEN")

    # Extract HTTP status code
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    # Retry after token refresh on 401 error
    if [ "$HTTP_CODE" = "401" ]; then
        KEYCHAIN_RAW=$(/usr/bin/security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        KEYCHAIN_JSON=$(decode_keychain_value "$KEYCHAIN_RAW")
        REFRESH_TOKEN=$(echo "$KEYCHAIN_JSON" | jq -r '.claudeAiOauth.refreshToken // empty' 2>/dev/null)

        if [ -n "$REFRESH_TOKEN" ] && [ "$REFRESH_TOKEN" != "null" ]; then
            NEW_TOKEN=$(refresh_access_token "$REFRESH_TOKEN")
            if [ -n "$NEW_TOKEN" ]; then
                ACCESS_TOKEN="$NEW_TOKEN"
                RESPONSE=$(call_usage_api "$ACCESS_TOKEN")
                HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
                BODY=$(echo "$RESPONSE" | sed '$d')
            fi
        fi
    fi

    # Error handling
    if [ "$HTTP_CODE" != "200" ]; then
        if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" = "000" ]; then
            show_error "Network connection failed"
        else
            ERROR_MSG=$(echo "$BODY" | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API error: $HTTP_CODE")
            show_error "$ERROR_MSG"
        fi
    fi

    # Validate JSON
    if ! echo "$BODY" | jq empty 2>/dev/null; then
        show_error "Invalid JSON response"
    fi

    # Save cache
    set_cache "$BODY"
fi

# Parse response
FIVE_HOUR_UTIL=$(echo "$BODY" | jq -r '.five_hour.utilization')
FIVE_HOUR_RESET=$(echo "$BODY" | jq -r '.five_hour.resets_at')
SEVEN_DAY_UTIL=$(echo "$BODY" | jq -r '.seven_day.utilization')
SEVEN_DAY_RESET=$(echo "$BODY" | jq -r '.seven_day.resets_at')

# Validate API response
if [ -z "$FIVE_HOUR_UTIL" ] || [ "$FIVE_HOUR_UTIL" = "null" ]; then
    show_error "Failed to parse API response"
fi

# Format usage
FIVE_HOUR_PCT=$(printf "%.0f" "$FIVE_HOUR_UTIL")
SEVEN_DAY_PCT=$(printf "%.0f" "$SEVEN_DAY_UTIL")

# Determine colors
FIVE_HOUR_COLOR=$(get_color "$FIVE_HOUR_UTIL")
SEVEN_DAY_COLOR=$(get_color "$SEVEN_DAY_UTIL")

# Calculate times
FIVE_HOUR_TIME=$(calculate_reset_time "$FIVE_HOUR_RESET")
SEVEN_DAY_TIME=$(calculate_reset_time "$SEVEN_DAY_RESET")
RESET_TIME_SHORT=$(get_reset_time_short "$FIVE_HOUR_RESET")

# Menu bar output (5-hour block usage)
echo "${FIVE_HOUR_PCT}%(${RESET_TIME_SHORT}) | color=$FIVE_HOUR_COLOR"

# Separator
echo "---"

# 5-hour block section
echo "📊 5-Hour Block"
echo "   Usage: ${FIVE_HOUR_PCT}% | color=$FIVE_HOUR_COLOR"
echo "   Resets: ${FIVE_HOUR_TIME}"

# Separator
echo "---"

# Weekly usage section
echo "📅 Weekly Usage"
echo "   Usage: ${SEVEN_DAY_PCT}% | color=$SEVEN_DAY_COLOR"
echo "   Resets: ${SEVEN_DAY_TIME}"

# Separator
echo "---"

# Actions
echo "🔄 Refresh | refresh=true"

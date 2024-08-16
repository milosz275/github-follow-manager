#!/bin/bash

# Follow Manager
# A simple script to manage your GitHub followers and following list.

if ! command -v jq &> /dev/null; then
    echo "jq is required to run this script. Please install jq first. (sudo apt install jq)"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "curl is required to run this script. Please install curl first. (sudo apt install curl)"
    exit 1
fi

if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo ".env file not found! Please create a .env file with GITHUB_USER and GITHUB_TOKEN."
    exit 1
fi

if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "GitHub username or token is not set. Please check your .env file."
    exit 1
fi

GITHUB_API_URL="https://api.github.com"

follow_back() {
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login')
    for user in $followers; do
        echo "Following $user..."
        curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X PUT "$GITHUB_API_URL/user/following/$user" > /dev/null
    done
    echo "All followers have been followed back."
}

unfollow_non_followers() {
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following" | jq -r '.[].login')
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login')
    for user in $following; do
        if ! echo "$followers" | grep -q "$user"; then
            echo "Unfollowing $user..."
            curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X DELETE "$GITHUB_API_URL/user/following/$user" > /dev/null
        fi
    done
    echo "Unfollowed users who are not following you back."
}

list_followers() {
    curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login'
}

list_following() {
    curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following" | jq -r '.[].login'
}

list_not_following_back() {
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following" | jq -r '.[].login')
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login')
    for user in $following; do
        if ! echo "$followers" | grep -q "$user"; then
            echo "$user"
        fi
    done
}

usage() {
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "  follow-back: Follow back all followers"
    echo "  unfollow-non-followers: Unfollow users who are not following you back"
    echo "  list-followers: List all followers"
    echo "  list-following: List all following users"
    echo "  list-not-following-back: List users who are not following you back"
}

case "$1" in
    follow-back)
        follow_back
        ;;
    unfollow-non-followers)
        unfollow_non_followers
        ;;
    list-followers)
        list_followers
        ;;
    list-following)
        list_following
        ;;
    list-not-following-back)
        list_not_following_back
        ;;
    *)
        usage
        exit 1
        ;;
esac

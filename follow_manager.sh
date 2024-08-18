#!/bin/bash

# GitHub Follow Manager
# A simple script to manage your GitHub followers and following list.

CONFIG_DIR="$HOME/.github-follow-manager"
ENV_FILE="$CONFIG_DIR/.env"

if ! command -v jq &> /dev/null; then
    echo "jq is required to run this script. Please install jq first."
    echo "sudo apt install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "curl is required to run this script. Please install curl first."
    echo "sudo apt install curl"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo ".env file not found! Creating one..."
    mkdir -p "$CONFIG_DIR"
    read -p "Enter your GitHub username: " GITHUB_USER
    read -sp "Enter your GitHub token: " GITHUB_TOKEN
    echo
    echo "GITHUB_USER=$GITHUB_USER" > "$ENV_FILE"
    echo "GITHUB_TOKEN=$GITHUB_TOKEN" >> "$ENV_FILE"
    echo ".env file created with your GitHub credentials."
else
    export $(cat "$ENV_FILE" | xargs)
fi

if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "GitHub username or token is not set correctly. Please check your .env file in $CONFIG_DIR."
    exit 1
fi

GITHUB_API_URL="https://api.github.com"

follow_back() {
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login')
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following" | jq -r '.[].login')
    if [ -z "$followers" ]; then
        echo "You don't have any followers to follow back."
        exit 1
    fi
    not_following_back=()
    for user in $followers; do
        if ! echo "$following" | grep -q "$user"; then
            not_following_back+=("$user")
        fi
    done
    echo "You have $(echo "$followers" | wc -l) followers and you are not following back $(echo "${not_following_back[@]}" | wc -w) of them."
    if [ ${#not_following_back[@]} -eq 0 ]; then
        echo "You are already following back all followers."
        exit 0
    fi

    echo "Do you want to follow back all followers? (y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
        echo "Select a user to follow back or choose 0 to abort:"
        select user in "${not_following_back[@]}"; do
            if [ -n "$user" ]; then
                echo "Following $user..."
                curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X PUT "$GITHUB_API_URL/user/following/$user" > /dev/null
                break
            elif [ "$REPLY" -eq 0 ]; then
                echo "Aborting..."
                exit 1
            else
                echo "Invalid option. Aborting..."
                exit 1
            fi
        done
        exit 1
    fi
    for user in $followers; do
        echo "Following $user..."
        curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X PUT "$GITHUB_API_URL/user/following/$user" > /dev/null

    done
    echo "All followers have been followed back."
}

unfollow_non_followers() {
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following" | jq -r '.[].login')
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login')
    
    non_followers=()
    for user in $following; do
        if ! echo "$followers" | grep -q "$user"; then
            non_followers+=("$user")
        fi
    done
    echo "There are $(echo "$following" | wc -l) users you are following and $(echo "${non_followers[@]}" | wc -w) of them are not following you back."
    echo "Users who are not following you back:"
    
    if [ ${#non_followers[@]} -eq 0 ]; then
        echo "No users to unfollow."
        exit 0
    fi

    for user in "${non_followers[@]}"; do
        echo "$user"
    done
    
    echo "Do you want to unfollow all users who are not following you back? (y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
        echo "Select a user to unfollow or choose 0 to abort:"
        select user in "${non_followers[@]}"; do
            if [ -n "$user" ]; then
                echo "Unfollowing $user..."
                curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X DELETE "$GITHUB_API_URL/user/following/$user" > /dev/null
                break
            elif [ "$REPLY" -eq 0 ]; then
                echo "Aborting..."
                exit 1
            else
                echo "Invalid option. Aborting..."
                exit 1
            fi
        done
        exit 1
    fi
    
    for user in "${non_followers[@]}"; do
        echo "Unfollowing $user..."
        curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X DELETE "$GITHUB_API_URL/user/following/$user" > /dev/null
    done
    echo "Unfollowed users who are not following you back."
}

list_followers() {
    echo "Followers:"
    curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login'
    exit 0
}

list_following() {
    echo "Following:"
    curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following" | jq -r '.[].login'
    exit 0
}

list_not_following_back() {
    echo "Users who are not following you back:"
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following" | jq -r '.[].login')
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login')
    for user in $following; do
        if ! echo "$followers" | grep -q "$user"; then
            echo "$user"
        fi
    done
    exit 0
}

list_not_followed_back() {
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following" | jq -r '.[].login')
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers" | jq -r '.[].login')
    for user in $followers; do
        if ! echo "$following" | grep -q "$user"; then
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
    echo "  list-not-followed-back: List users who you are not following back"
}

display_menu() {
    echo "Select an option:"
    echo "0) Abort"
    echo "1) Follow back"
    echo "2) Unfollow non-followers"
    echo "3) List followers"
    echo "4) List following"
    echo "5) List non-followed back"
}

if [ $# -eq 0 ]; then
    while true; do
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0)
                echo "Aborting..."
                exit 0
                ;;
            1)
                follow_back
                ;;
            2)
                unfollow_non_followers
                ;;
            3)
                list_followers
                ;;
            4)
                list_following
                ;;
            5)
                list_not_followed_back
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
fi

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
    list-not-followed-back)
        list_not_followed_back
        ;;
    *)
        usage
        exit 1
        ;;
esac

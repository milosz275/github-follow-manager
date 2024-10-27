#!/bin/bash

# GitHub Follow Manager
# A simple script to manage your GitHub followers and following list.

CONFIG_DIR="$HOME/.github-follow-manager"
ENV_FILE="$CONFIG_DIR/.env"
GITHUB_API_URL="https://api.github.com"
GITHUB_URL="https://github.com"
PAGINATION=30
MAX_ENTRIES=100000

get_current_username() {
    curl -s -u "anonymous:$GITHUB_TOKEN" "$GITHUB_API_URL/user" | jq -r '.login'
}

check_current_username() {
    username=$(get_current_username)
    if [ "$username" != "$GITHUB_USER" ]; then
        token=$(grep GITHUB_TOKEN "$ENV_FILE" | cut -d'=' -f2)
        update_env_file $username $token
    fi
}

update_env_file() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "GitHub username and token are required to update .env file."
        exit 1
    fi
    echo "Updating .env file..."
    echo "GITHUB_USER=$1" > "$ENV_FILE"
    echo "GITHUB_TOKEN=$2" >> "$ENV_FILE"
}

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
    read -sp "Enter your GitHub token: " GITHUB_TOKEN
    echo
    GITHUB_USER=$(get_current_username)
    if [ -z "$GITHUB_USER" ]; then
        echo "Failed to fetch GitHub username. Please try again later."
        exit 1
    fi
    update_env_file $GITHUB_USER $GITHUB_TOKEN
    echo ".env file created with your GitHub credentials."
else
    export $(cat "$ENV_FILE" | xargs)
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "GitHub token is not set correctly. Please check your .env file in $CONFIG_DIR."
    exit 1
fi

if [ -z "$GITHUB_USER" ]; then
    echo "GitHub username not found in .env file. Trying to fetch it..."
    GITHUB_USER=$(get_current_username)
    if [ -z "$GITHUB_USER" ]; then
        echo "Failed to fetch GitHub username. Please check your .env file in $CONFIG_DIR."
        exit 1
    fi
    update_env_file $GITHUB_USER $GITHUB_TOKEN
else
    check_current_username
fi

menu_follow() { # uses argument as username if provided, otherwise asks for input
    username=""
    if [ -z "$1" ]; then
        echo "Enter the username you want to follow:"
        read -r username
    else
        username=$1
    fi
    echo -e "Following \e]8;;$GITHUB_URL/$username\a$username\e]8;;\a..."
    curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X PUT "$GITHUB_API_URL/user/following/$username" > /dev/null
}

menu_unfollow() { # uses argument as username if provided, otherwise asks for input
    username=""
    if [ -z "$1" ]; then
        echo "Enter the username you want to unfollow:"
        read -r username
    else
        username=$1
    fi
    echo -e "Unfollowing \e]8;;$GITHUB_URL/$username\a$username\e]8;;\a..."
    curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" -X DELETE "$GITHUB_API_URL/user/following/$username" > /dev/null
}

menu_follow_back() { # aks for confirmation before following back all followers, uses -y flag to skip confirmation
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following?per_page=$MAX_ENTRIES" | jq -r '.[].login')
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
        return
    fi

    if [ ${#not_following_back[@]} -gt $PAGINATION ]; then
        echo "You have too many followers to follow back to show them all."
    else
        echo "Users not followed back:"
        for user in "${not_following_back[@]}"; do
            echo -e "\e]8;;$GITHUB_URL/$user\a$user\e]8;;\a"
        done
    fi

    confirm=""
    if [ "$1" == "-y" ]; then
        confirm="y"
    else
        echo "Do you want to follow back all followers? [y/n]"
        read -r confirm
    fi
    if [ "$confirm" != "y" ]; then
        if [ ${#not_following_back[@]} -gt $PAGINATION ]; then
            echo "You have too many followers to follow back manually."
            return
        fi
        echo "Select a user to follow back or choose 0 to abort:"
        select user in "${not_following_back[@]}"; do
            if [ -n "$user" ]; then
                echo -e "Following \e]8;;$GITHUB_URL/$user\a$user\e]8;;\a..."
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

menu_unfollow_non_followers() { # asks for confirmation before unfollowing users who are not following back, uses -y flag to skip confirmation
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    
    non_followers=()
    for user in $following; do
        if ! echo "$followers" | grep -q "$user"; then
            non_followers+=("$user")
        fi
    done
    echo "There are $(echo "$following" | wc -l) users you are following and $(echo "${non_followers[@]}" | wc -w) of them are not following you back."
    if [ ${#non_followers[@]} -eq 0 ]; then
        echo "No users to unfollow."
        return
    fi

    if [ ${#non_followers[@]} -gt $PAGINATION ]; then
        echo "You have too many users to unfollow to show them all."
    else
        echo "Users who are not following you back:"
        for user in "${non_followers[@]}"; do
            echo -e "\e]8;;$GITHUB_URL/$user\a$user\e]8;;\a"
        done
    fi
    
    confirm=""
    if [ "$1" == "-y" ]; then
        confirm="y"
    else
        echo "Do you want to unfollow all users who are not following you back? [y/n]"
        read -r confirm
    fi
    if [ "$confirm" != "y" ]; then
        if [ ${#non_followers[@]} -gt $PAGINATION ]; then
            echo "You have too many users to unfollow manually."
            return
        fi
        echo "Select a user to unfollow or choose 0 to abort:"
        select user in "${non_followers[@]}"; do
            if [ -n "$user" ]; then
                echo -e "Unfollowing \e]8;;$GITHUB_URL/$user\a$user\e]8;;\a..."
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

paginate() { # takes an array of users and paginates them
    if [ "$#" -eq 0 ]; then
        echo "Invalid usage of arguments in paginate function."
    fi
    local users=("$@")
    local total=${#users[@]}
    local pages=$(( (total + PAGINATION - 1) / PAGINATION ))

    for ((page=0; page<pages; page++)); do
        start=$((page * PAGINATION))
        end=$((start + PAGINATION))
        if [ $end -gt $total ]; then
            end=$total
        fi

        echo "Page $((page + 1))/$pages:"
        for ((i=start; i<end; i++)); do
            user=${users[i]}
            echo -e "\e]8;;$GITHUB_URL/$user\a$user\e]8;;\a"
        done

        if [ $page -lt $((pages - 1)) ]; then
            read -p "Press Enter to continue to the next page..." -r
        fi
    done
}

menu_list_followers() { # lists all followers and paginates them
    if [ "$#" -eq 0 ]; then
        echo "Invalid usage of arguments in list_followers function."
    fi
    echo "Followers:"
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    IFS=$'\n' read -rd '' -a followers_array <<<"$followers"
    paginate "${followers_array[@]}"
}

menu_list_following() { # lists all following users and paginates them
    if [ "$#" -eq 0 ]; then
        echo "Invalid usage of arguments in list_following function."
    fi
    echo "Following:"
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    IFS=$'\n' read -rd '' -a following_array <<<"$following"
    paginate "${following_array[@]}"
}

menu_list_not_following_back() { # lists users who are not following back and paginates them
    if [ "$#" -eq 0 ]; then
        echo "Invalid usage of arguments in list_not_following_back function."
    fi
    echo "Users who are not following you back:"
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    IFS=$'\n' read -rd '' -a following_array <<<"$following"
    IFS=$'\n' read -rd '' -a followers_array <<<"$followers"
    not_following_back=()
    for user in "${following_array[@]}"; do
        if ! echo "${followers_array[@]}" | grep -q "$user"; then
            not_following_back+=("$user")
        fi
    done
    paginate "${not_following_back[@]}"
}

menu_list_not_followed_back() { # lists users who you are not following back and paginates them
    if [ "$#" -eq 0 ]; then
        echo "Invalid usage of arguments in list_not_followed_back function."
    fi
    echo "Users you are not following back:"
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    IFS=$'\n' read -rd '' -a following_array <<<"$following"
    IFS=$'\n' read -rd '' -a followers_array <<<"$followers"
    not_followed_back=()
    for user in "${followers_array[@]}"; do
        if ! echo "${following_array[@]}" | grep -q "$user"; then
            not_followed_back+=("$user")
        fi
    done
    paginate "${not_followed_back[@]}"
}

display_current_follower_count() { # displays the current follower count
    followers=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/followers?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    following=$(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "$GITHUB_API_URL/users/$GITHUB_USER/following?per_page=$MAX_ENTRIES" | jq -r '.[].login')
    echo "You have $(echo "$followers" | wc -l) followers and you are following $(echo "$following" | wc -l) users."
}

usage() { # displays usage information
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "  follow <username>: Follow a user"
    echo "  unfollow <username>: Unfollow a user"
    echo "  follow-back: Follow back all followers"
    echo "  unfollow-non-followers: Unfollow users who are not following you back"
    echo "  list-followers: List all followers"
    echo "  list-following: List all following users"
    echo "  list-not-following-back: List users who are not following you back"
    echo "  list-not-followed-back: List users who you are not following back"
}

display_menu() { # displays the main menu
    echo "Select an option:"
    echo "0) Abort"
    echo "1) Follow a user"
    echo "2) Unfollow a user"
    echo "3) Follow back all or choose a follower"
    echo "4) Unfollow all non-followers or choose a user"
    echo "5) List followers"
    echo "6) List following"
    echo "7) List not-following back"
    echo "8) List not-followed back"
}

if [ $# -eq 0 ]; then
    while true; do
        display_current_follower_count
        display_menu
        read -p "Enter your choice: " choice
        case $choice in
            0)
                echo "Aborting..."
                exit 0
                ;;
            1)
                menu_follow
                ;;
            2)
                menu_unfollow
                ;;
            3)
                menu_follow_back
                ;;
            4)
                menu_unfollow_non_followers
                ;;
            5)
                menu_list_followers
                ;;
            6)
                menu_list_following
                ;;
            7)
                menu_list_not_following_back
                ;;
            8)
                menu_list_not_followed_back
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
fi

case "$1" in
    follow)
        menu_follow "${@:2}"
        ;;
    unfollow)
        menu_unfollow "${@:2}"
        ;;
    follow-back)
        menu_follow_back "${@:2}"
        ;;
    unfollow-non-followers)
        menu_unfollow_non_followers "${@:2}"
        ;;
    list-followers)
        menu_list_followers "${@:2}"
        ;;
    list-following)
        menu_list_following "${@:2}"
        ;;
    list-not-following-back)
        menu_list_not_following_back "${@:2}"
        ;;
    list-not-followed-back)
        menu_list_not_followed_back "${@:2}"
        ;;
    *)
        usage
        exit 1
        ;;
esac

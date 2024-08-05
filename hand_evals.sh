#!/bin/bash

# Helper function to convert card values to numeric values
card_value() {
    case $1 in
        A) echo 14 ;;
        K) echo 13 ;;
        Q) echo 12 ;;
        J) echo 11 ;;
        T) echo 10 ;;
        *) echo $1 ;;
    esac
}

evaluate_hand() {
    local hand=("$@")
    local values=()
    local suits=()
    
    for card in "${hand[@]}"; do
        if [[ -n "$card" && "$card" != "folded" ]]; then
            if [[ ${#card} -eq 2 ]]; then
                local value="${card:0:1}"
                local suit="${card:1:1}"
            else
                local value="${card:0:2}"
                local suit="${card:2:1}"
            fi
            values+=($(card_value "$value"))
            suits+=("$suit")
        fi
    done

    # Sort values in descending order
    IFS=$'\n' sorted=($(printf "%s\n" "${values[@]}" | sort -nr))
    unset IFS

    # Check for flush
    if [ $(printf "%s\n" "${suits[@]}" | sort | uniq | wc -l) -eq 1 ]; then
        flush=true
    else
        flush=false
    fi

    # Check for straight
    straight=true
    for i in {1..4}; do
        if [ "${#sorted[@]}" -lt 5 ] || [ $((sorted[i-1] - sorted[i])) -ne 1 ]; then
            straight=false
            break
        fi
    done

    # Count occurrences of each value
    local count_str=$(printf "%s\n" "${values[@]}" | sort | uniq -c | sort -nr)

    # Determine hand ranking
    local rank
    local max_count=$(echo "$count_str" | awk '{print $1}' | head -n1)
    local pair_count=$(echo "$count_str" | awk '$1 == 2' | wc -l)

    if $flush && $straight && [ "${#sorted[@]}" -ge 5 ]; then
        if [ ${sorted[0]} -eq 14 ]; then
            rank="10" # Royal Flush
        else
            rank="9"  # Straight Flush
        fi
    elif [ "$max_count" -eq 4 ]; then
        rank="8"  # Four of a Kind
    elif [ "$max_count" -eq 3 ] && [ "$pair_count" -ge 1 ]; then
        rank="7"  # Full House
    elif $flush; then
        rank="6"  # Flush
    elif $straight && [ "${#sorted[@]}" -ge 5 ]; then
        rank="5"  # Straight
    elif [ "$max_count" -eq 3 ]; then
        rank="4"  # Three of a Kind
    elif [ "$pair_count" -eq 2 ]; then
        rank="3"  # Two Pair
    elif [ "$pair_count" -eq 1 ]; then
        rank="2"  # One Pair
    else
        rank="1"  # High Card
    fi

    echo "$rank ${sorted[@]}"
}

# Function to compare two hands
compare_hands() {
    local hand1=($1)
    local hand2=($2)

    # Compare hand ranks first
    if [ ${hand1[0]} -gt ${hand2[0]} ]; then
        echo 1
        return
    elif [ ${hand1[0]} -lt ${hand2[0]} ]; then
        echo 2
        return
    fi

    # If ranks are equal, we need to compare the values differently based on the hand type
    local rank=${hand1[0]}
    case $rank in
        7|3) # Full House or Two Pair
            # Compare the first pair (higher pair for Two Pair, three of a kind for Full House)
            if [ ${hand1[1]} -gt ${hand2[1]} ]; then
                echo 1
                return
            elif [ ${hand1[1]} -lt ${hand2[1]} ]; then
                echo 2
                return
            fi
            # If first pair is equal, compare the second pair
            if [ ${hand1[3]} -gt ${hand2[3]} ]; then
                echo 1
                return
            elif [ ${hand1[3]} -lt ${hand2[3]} ]; then
                echo 2
                return
            fi
            # If both pairs are equal, compare the kicker
            if [ ${hand1[5]} -gt ${hand2[5]} ]; then
                echo 1
                return
            elif [ ${hand1[5]} -lt ${hand2[5]} ]; then
                echo 2
                return
            fi
            ;;
        *)  # For all other hands, compare kickers in order
            for i in {1..5}; do
                if [ ${hand1[$i]} -gt ${hand2[$i]} ]; then
                    echo 1
                    return
                elif [ ${hand1[$i]} -lt ${hand2[$i]} ]; then
                    echo 2
                    return
                fi
            done
            ;;
    esac
    echo 0  # Tie
}

# Helper function to describe a hand
describe_hand() {
    local hand=($@)
    local rank=${hand[0]}
    local description
    case $rank in
        10) description="Royal Flush" ;;
        9) description="Straight Flush" ;;
        8) description="Four of a Kind" ;;
        7) description="Full House" ;;
        6) description="Flush" ;;
        5) description="Straight" ;;
        4) description="Three of a Kind" ;;
        3) description="Two Pair" ;;
        2) description="One Pair" ;;
        1) description="High Card" ;;
    esac
    echo "$description (${hand[@]:1})"
}
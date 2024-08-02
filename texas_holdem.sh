#!/bin/bash

# Color functions
red() { echo -e "\033[1;31m$*\033[0m"; }
green() { echo -e "\033[1;32m$*\033[0m"; }
blue() { echo -e "\033[1;34m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
cyan() { echo -e "\033[1;36m$*\033[0m"; }

# Define card suits and values
suits=("♠" "♥" "♦" "♣")
values=("2" "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K" "A")

# Initialize deck
deck=()
current_card_index=0
opponents=()
num_opponents=0

get_num_opponents() {
    while true; do
        green "How many opponents do you want to play against? (1-3): "
        read -r num_opponents
        if [[ "$num_opponents" =~ ^[1-3]$ ]]; then
            break
        else
            red "Invalid input. Please enter a number between 1 and 3."
        fi
    done
}

# Function to initialize opponents
initialize_opponents() {
    for ((i=1; i<=num_opponents; i++)); do
        opponents+=("Opponent $i:1000::")  # Format: name:chips:card1:card2
    done
}


# Function to create a full 52-card deck
create_deck() {
    deck=()
    for suit in "${suits[@]}"; do
        for value in "${values[@]}"; do
            deck+=("$value$suit")
        done
    done
    echo "Deck created with ${#deck[@]} cards."
}

# Function to shuffle the deck
shuffle_deck() {
    local i j temp
    for ((i = ${#deck[@]} - 1; i > 0; i--)); do
        j=$(($RANDOM % (i + 1)))
        temp="${deck[$i]}"
        deck[$i]="${deck[$j]}"
        deck[$j]="$temp"
    done
    echo "Deck shuffled. First 5 cards: ${deck[0]} ${deck[1]} ${deck[2]} ${deck[3]} ${deck[4]}"
}

# Function to deal a card
deal_card() {
    local index=$(<current_card_index.txt)
    if [ $index -ge ${#deck[@]} ]; then
        echo "Error: No more cards in the deck" >&2
        return 1
    fi
    local card="${deck[$index]}"
    index=$((index + 1))
    echo $index > current_card_index.txt
    echo "$card"
}

deal_to_opponents() {
    for i in "${!opponents[@]}"; do
        IFS=':' read -r name chips card1 card2 <<< "${opponents[$i]}"
        card1=$(deal_card)
        card2=$(deal_card)
        opponents[$i]="$name:$chips:$card1:$card2"
    done
}

draw_card() {
    local value=$1
    local suit=$2
    local color=$3
    local padding=""
    if [[ ${#value} -eq 1 ]]; then
        padding=" "
    fi
    echo -e "${color}┌─────┐"
    echo -e "${color}│${padding}${value}   │"
    echo -e "${color}│  ${suit}  │"
    echo -e "${color}│   ${padding}${value}│"
    echo -e "${color}└─────┘"
}

draw_card_back() {
    local color=$1
    echo -e "${color}┌─────┐"
    echo -e "${color}│☆ ★ ☆│"
    echo -e "${color}│ ★ ★ │"
    echo -e "${color}│☆ ★ ☆│"
    echo -e "${color}└─────┘"
}

# Function to display a card
display_card() {
    local card=$1
    local card_type=$2
    local value=${card:0:${#card}-1}
    local suit=${card: -1}
    local color

    case $card_type in
        "player") color="\033[1;32m" ;;  # Green for player cards
        "community") color="\033[1;34m" ;;  # Blue for community cards
        "opponent") color="\033[1;31m" ;;  # Red for opponent cards
        *) color="\033[1;37m" ;;  # White for any other case
    esac

    draw_card "$value" "$suit" "$color"
}

# Function to display cards side by side
display_cards_row() {
    local cards=("$@")
    local lines=()
    for i in {0..4}; do
        lines[i]=""
    done

    for card in "${cards[@]}"; do
        if [[ -z "$card" ]]; then
            for i in {0..4}; do
                lines[i]+="      "
            done
        elif [[ "$card" == "folded" ]]; then
            local color="\033[1;90m"  # Gray for folded cards
            IFS=$'\n' read -d '' -ra card_lines < <(draw_card_back "$color")
            for i in "${!card_lines[@]}"; do
                lines[i]+="${card_lines[i]}"
            done
        elif [[ "$card" == "BACK" ]]; then
            IFS=$'\n' read -d '' -ra card_lines < <(draw_card_back "\033[1;31m")  # Red for opponent cards back
            for i in "${!card_lines[@]}"; do
                lines[i]+="${card_lines[i]}"
            done
        else
            local card_type
            if [[ "${card:0:1}" == "P" ]]; then
                card_type="player"
                card="${card:1}"  # Remove the 'P' prefix
            elif [[ "${card:0:1}" == "C" ]]; then
                card_type="community"
                card="${card:1}"  # Remove the 'C' prefix
            else
                card_type="opponent"
            fi
            IFS=$'\n' read -d '' -ra card_lines < <(display_card "$card" "$card_type")
            for i in "${!card_lines[@]}"; do
                lines[i]+="${card_lines[i]}"
            done
        fi
    done
    
    printf '%s\n' "${lines[@]}"
}


# Function to generate cyan spaces
cyan_spaces() {
    printf "\033[1;36m%*s" "$1" ""
}

opponent_bet() {
    local opponent_index=$1
    local current_bet=$2
    IFS=':' read -r name chips card1 card2 <<< "${opponents[$opponent_index]}"
    local action
    local bet_amount=0

    # Simple AI: 70% chance to call/check, 20% chance to raise, 10% chance to fold
    local random_num=$((RANDOM % 100))
    if ((random_num < 70)); then
        if [[ $current_bet -eq 0 ]]; then
            action="check"
        else
            action="call"
        fi
    elif ((random_num < 90)); then
        action="raise"
        bet_amount=$((current_bet + RANDOM % 50 + 10))  # Random raise between 10 and 60 above current bet
    else
        action="fold"
    fi

    case $action in
        check)
            echo "$name checks."
            ;;
        call)
            if ((current_bet <= chips)); then
                echo "$name calls $current_bet."
                chips=$((chips - current_bet))
                pot=$((pot + current_bet))
            else
                echo "$name doesn't have enough chips to call. $name folds."
                action="fold"
            fi
            ;;
        raise)
            if ((bet_amount <= chips)); then
                echo "$name raises to $bet_amount."
                chips=$((chips - bet_amount))
                pot=$((pot + bet_amount))
                current_bet=$bet_amount
            else
                echo "$name doesn't have enough chips to raise. $name calls instead."
                action="call"
                chips=$((chips - current_bet))
                pot=$((pot + current_bet))
            fi
            ;;
        fold)
            echo "$name folds."
            opponents[$opponent_index]="$name:$chips:folded:folded"
            return 1
            ;;
    esac

    opponents[$opponent_index]="$name:$chips:$card1:$card2"
    if [[ $action == "raise" ]]; then
        return 2
    fi
    return 0
}

handle_betting() {
    local current_bet=0
    local folded_players=0

    for i in "${!opponents[@]}"; do
        IFS=':' read -r name chips card1 card2 <<< "${opponents[$i]}"
        if [[ "$card1" != "folded" ]]; then
            local result
            opponent_bet $i $current_bet
            result=$?
            if [[ $result -eq 1 ]]; then
                # Opponent folded
                opponents[$i]="$name:$chips:folded:folded"
                ((folded_players++))
            elif [[ $result -eq 2 ]]; then
                # Opponent raised
                current_bet=$bet_amount
            fi
        else
            ((folded_players++))
        fi
    done

    # Check if all opponents have folded
    if [[ $folded_players -eq ${#opponents[@]} ]]; then
        echo "All opponents have folded. You win the pot!"
        player_chips=$((player_chips + pot))
        pot=0
        return 2
    fi

    local action
    while true; do
        green "Your action (check/call/bet/fold): "
        read -r action
        case $action in
            check)
                if [[ $current_bet -eq 0 ]]; then
                    echo "You checked."
                    break
                else
                    red "You can't check. The current bet is $current_bet."
                fi
                ;;
            call)
                if [[ $current_bet -gt 0 ]]; then
                    if ((current_bet <= player_chips)); then
                        player_chips=$((player_chips - current_bet))
                        pot=$((pot + current_bet))
                        echo "You called $current_bet."
                        break
                    else
                        red "You don't have enough chips to call."
                    fi
                else
                    red "There's no bet to call. You can check or bet."
                fi
                ;;
            bet)
                green "How much do you want to bet? "
                read -r bet_amount
                if ((bet_amount > current_bet && bet_amount <= player_chips)); then
                    player_chips=$((player_chips - bet_amount))
                    pot=$((pot + bet_amount))
                    current_bet=$bet_amount
                    echo "You bet $bet_amount."
                    break
                else
                    red "Invalid bet amount. It must be greater than the current bet ($current_bet) and not exceed your chips."
                fi
                ;;
            fold)
                echo "You folded."
                return 1
                ;;
            *)
                red "Invalid action. Try again."
                ;;
        esac
    done
    return 0
}


display_folded_or_cards() {
    local cards=("$@")
    local lines=()
    for i in {0..4}; do
        lines[i]=""
    done
    
    for card in "${cards[@]}"; do
        if [[ -z "$card" ]]; then
            # Display empty space for missing cards
            for i in {0..4}; do
                lines[i]+="      "
            done
        elif [[ "$card" == "BACK" ]]; then
            IFS=$'\n' read -d '' -ra card_lines < <(draw_card_back "\033[1;31m")  # Red for opponent cards
            for i in "${!card_lines[@]}"; do
                lines[i]+="${card_lines[i]}"
            done
        elif [[ "$card" == "folded" ]]; then
            # Display gray card back for folded hands
            IFS=$'\n' read -d '' -ra card_lines < <(draw_card_back "\033[1;90m")  # Gray for folded cards
            for i in "${!card_lines[@]}"; do
                lines[i]+="${card_lines[i]}"
            done
        else
            local color
            if [[ "${card:0:1}" == "P" ]]; then  # Player card
                color="\033[1;32m"  # Green
                card="${card:1}"  # Remove the 'P' prefix
            elif [[ "${card:0:1}" == "C" ]]; then  # Community card
                color="\033[1;34m"  # Blue
                card="${card:1}"  # Remove the 'C' prefix
            fi
            IFS=$'\n' read -d '' -ra card_lines < <(display_card "$card" "$color")
            for i in "${!card_lines[@]}"; do
                lines[i]+="${card_lines[i]}"
            done
        fi
    done
    
    printf '%s\n' "${lines[@]}"
}

display_all_hands() {
    echo
    cyan "Final Hands:"
    echo

    for ((i = 0; i < num_opponents; i++)); do
        IFS=':' read -r name chips card1 card2 <<< "${opponents[$i]}"
        if [[ "$card1" != "folded" ]]; then
            cyan "$name's Hand:"
            display_cards_row "$card1" "$card2"
            echo
        else
            cyan "$name folded."
            echo
        fi
    done

    cyan "Your Hand:"
    display_cards_row "${player_hand[@]}"
    echo
}

# Update evaluate_hands function (simplified for now)
evaluate_hands() {
    echo "Revealing all hands..."
    display_table "true"
    echo

    echo "Hand evaluation not implemented. Splitting pot equally."
    local active_players=1  # Start with 1 for the human player
    for opponent in "${opponents[@]}"; do
        IFS=':' read -r name chips card1 card2 <<< "$opponent"
        if [[ "$card1" != "folded" ]]; then
            ((active_players++))
        fi
    done
    
    local split_amount=$((pot / active_players))
    player_chips=$((player_chips + split_amount))
    
    for i in "${!opponents[@]}"; do
        IFS=':' read -r name chips card1 card2 <<< "${opponents[$i]}"
        if [[ "$card1" != "folded" ]]; then
            chips=$((chips + split_amount))
            opponents[$i]="$name:$chips:$card1:$card2"
        fi
    done
    
    echo "Pot split equally among $active_players players. Each player receives $split_amount chips."
    echo
}

# Main game loop
main_game_loop() {
    get_num_opponents
    initialize_opponents
    player_chips=1000
    echo "0" > current_card_index.txt

    while true; do
        create_deck
        shuffle_deck
        player_hand=()
        community_cards=()
        pot=0
        echo "0" > current_card_index.txt

        player_hand+=("$(deal_card)")
        player_hand+=("$(deal_card)")
        deal_to_opponents

        # Pre-flop betting round
        display_table "false"
        if ! handle_betting; then continue; fi

        echo "Dealing flop..."
        community_cards[0]=$(deal_card)
        community_cards[1]=$(deal_card)
        community_cards[2]=$(deal_card)

        # Post-flop betting round
        display_table "false"
        if ! handle_betting; then continue; fi

        echo "Dealing turn..."
        community_cards[3]=$(deal_card)

        # Post-turn betting round
        display_table "false"
        if ! handle_betting; then continue; fi

        echo "Dealing river..."
        community_cards[4]=$(deal_card)

        # Final betting round
        display_table "false"
        if ! handle_betting; then continue; fi

        # Ensure all community cards are dealt
        while [ ${#community_cards[@]} -lt 5 ]; do
            community_cards+=("$(deal_card)")
        done

        # Evaluate hands and determine winner
        evaluate_hands

        yellow "Play another hand? (y/n)"
        read -r choice
        if [[ $choice != "y" ]]; then
            break
        fi
    done
}

# Update the display_table function to always show 5 card positions
display_table() {
    local reveal_hands=$1

    clear
    figlet -f slant "Texas Hold'em" | lolcat
    echo
    cyan "Community Cards:"
    display_cards_row "${community_cards[@]/#/C}" "" "" "" ""
    echo

    # Display opponent hands in a square formation
    for ((i = 0; i < 2 && i < num_opponents; i+=2)); do
        opponent1="${opponents[$i]}"
        IFS=':' read -r name1 chips1 card11 card12 <<< "$opponent1"
        
        if ((i+1 < num_opponents)); then
            opponent2="${opponents[$i+1]}"
            IFS=':' read -r name2 chips2 card21 card22 <<< "$opponent2"
            
            cyan "$name1's Hand:$(cyan_spaces $((34 - ${#name1})))$name2's Hand:"
            if [[ "$reveal_hands" == "true" ]]; then
                display_cards_row "$card11" "$card12" "" "" "" "" "" "$card21" "$card22"
            else
                if [[ "$card11" == "folded" ]]; then
                    display_cards_row "folded" "folded" "" "" "" "" "" "${card21:-BACK}" "${card22:-BACK}"
                elif [[ "$card21" == "folded" ]]; then
                    display_cards_row "BACK" "BACK" "" "" "" "" "" "folded" "folded"
                else
                    display_cards_row "BACK" "BACK" "" "" "" "" "" "BACK" "BACK"
                fi
            fi
            echo
            cyan "$name1's Chips: $(yellow "$chips1")$(cyan_spaces $((15 - ${#chips1})))$name2's Chips: $(yellow "$chips2")"
        else
            cyan "$name1's Hand:"
            if [[ "$reveal_hands" == "true" ]]; then
                display_cards_row "$card11" "$card12"
            else
                if [[ "$card11" == "folded" ]]; then
                    display_cards_row "folded" "folded"
                else
                    display_cards_row "BACK" "BACK"
                fi
            fi
            echo
            cyan "$name1's Chips: $(yellow "$chips1")"
        fi
        echo
    done

    # Display your hand and the third opponent's hand (if exists)
    if ((num_opponents == 3)); then
        opponent3="${opponents[2]}"
        IFS=':' read -r name3 chips3 card31 card32 <<< "$opponent3"
        cyan "Your Hand:$(cyan_spaces $((32)))$name3's Hand:"  
        if [[ "$reveal_hands" == "true" ]]; then
            display_cards_row "${player_hand[@]/#/P}" "" "" "" "" "" "$card31" "$card32"
        else
            if [[ "$card31" == "folded" ]]; then
                display_cards_row "${player_hand[@]/#/P}" "" "" "" "" "" "folded" "folded"
            else
                display_cards_row "${player_hand[@]/#/P}" "" "" "" "" "" "BACK" "BACK"
            fi
        fi
        echo
        cyan "Your Chips: $(yellow "$player_chips")$(cyan_spaces $((23 - ${#player_chips})))$name3's Chips: $(yellow "$chips3")"
    else
        cyan "Your Hand:"
        display_cards_row "${player_hand[@]/#/P}"
        echo
        cyan "Your Chips: $(yellow "$player_chips")"
    fi
    echo

    cyan "┌─────────────────────────────────────────────────────────┐"
    cyan "│ Pot: $(yellow "$pot")$(cyan_spaces $((51 - ${#pot})))│"
    cyan "└─────────────────────────────────────────────────────────┘"
    echo
}

# Start the game
main_game_loop
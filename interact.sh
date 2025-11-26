#!/bin/bash

# P2P Lending Platform - Interactive Helper Script
# Usage: ./interact.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo -e "${GREEN}✓ Loaded .env file${NC}"
else
    echo -e "${RED}✗ .env file not found${NC}"
    exit 1
fi

# Set addresses
export YOUR_ADDRESS=$(~/.foundry/bin/cast wallet address --private-key $PRIVATE_KEY)
export FORGE=~/.foundry/bin/forge
export CAST=~/.foundry/bin/cast

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     P2P Lending Matching Engine - Interactive Helper${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Your Address:${NC} $YOUR_ADDRESS"
echo -e "${YELLOW}Contract:${NC} $ENGINE_ADDRESS"
echo ""

# Function to check balances
check_balances() {
    echo -e "${BLUE}📊 Checking your balances...${NC}"

    ETH_BALANCE=$($CAST balance $YOUR_ADDRESS --rpc-url sepolia --ether)
    USDC_BALANCE=$($CAST call $USDC_ADDRESS "balanceOf(address)(uint256)" $YOUR_ADDRESS --rpc-url sepolia)
    USDC_BALANCE_READABLE=$(echo "scale=2; $USDC_BALANCE / 1000000" | bc)

    WITHDRAWABLE=$($CAST call $ENGINE_ADDRESS "getWithdrawableBalance(address)(uint96)" $YOUR_ADDRESS --rpc-url sepolia)
    WITHDRAWABLE_READABLE=$(echo "scale=2; $WITHDRAWABLE / 1000000" | bc)

    AAVE_BALANCE=$($CAST call $ENGINE_ADDRESS "getAaveBalance()(uint256)" --rpc-url sepolia)
    AAVE_BALANCE_READABLE=$(echo "scale=2; $AAVE_BALANCE / 1000000" | bc)

    echo ""
    echo -e "${GREEN}ETH Balance:${NC} $ETH_BALANCE ETH"
    echo -e "${GREEN}USDC Balance:${NC} $USDC_BALANCE_READABLE USDC"
    echo -e "${GREEN}Withdrawable in Contract:${NC} $WITHDRAWABLE_READABLE USDC"
    echo -e "${GREEN}Total in Aave:${NC} $AAVE_BALANCE_READABLE USDC"
    echo ""
}

# Function to deposit as lender
deposit_lender() {
    echo -e "${BLUE}💰 Deposit as Lender${NC}"
    echo ""

    read -p "Amount (USDC, e.g., 1000): " amount
    read -p "Minimum rate (bps, e.g., 500 for 5%): " rate
    echo "Select term:"
    echo "  0 = 7 days"
    echo "  1 = 30 days"
    echo "  2 = 90 days"
    read -p "Term: " term

    amount_wei=$((amount * 1000000))

    echo ""
    echo -e "${YELLOW}Approving USDC...${NC}"
    $CAST send $USDC_ADDRESS "approve(address,uint256)" $ENGINE_ADDRESS $amount_wei \
        --rpc-url sepolia --private-key $PRIVATE_KEY --legacy

    echo -e "${YELLOW}Depositing...${NC}"
    $CAST send $ENGINE_ADDRESS "depositLender(uint96,uint16,uint8)" $amount_wei $rate $term \
        --rpc-url sepolia --private-key $PRIVATE_KEY --legacy

    echo -e "${GREEN}✓ Deposit successful! Your funds are now earning Aave yield.${NC}"
}

# Function to request borrow
request_borrow() {
    echo -e "${BLUE}💳 Request Borrow${NC}"
    echo ""

    read -p "Amount to borrow (USDC, e.g., 1000): " amount
    read -p "Maximum rate (bps, e.g., 600 for 6%): " rate
    echo "Select term:"
    echo "  0 = 7 days"
    echo "  1 = 30 days"
    echo "  2 = 90 days"
    read -p "Term: " term

    amount_wei=$((amount * 1000000))
    collateral=$((amount * 1333 / 1000))
    collateral_wei=$((collateral * 1000000))

    echo ""
    echo -e "${YELLOW}Required collateral: $collateral USDC (75% LTV)${NC}"
    echo -e "${YELLOW}Approving collateral...${NC}"
    $CAST send $USDC_ADDRESS "approve(address,uint256)" $ENGINE_ADDRESS $collateral_wei \
        --rpc-url sepolia --private-key $PRIVATE_KEY --legacy

    echo -e "${YELLOW}Requesting borrow...${NC}"
    $CAST send $ENGINE_ADDRESS "requestBorrow(uint96,uint16,uint8,uint96)" \
        $amount_wei $rate $term $collateral_wei \
        --rpc-url sepolia --private-key $PRIVATE_KEY --legacy

    echo -e "${GREEN}✓ Borrow request created! Waiting for match...${NC}"
}

# Function to match orders
match_orders() {
    echo -e "${BLUE}🔄 Match Orders (Keeper)${NC}"
    echo ""

    read -p "Maximum number of matches (e.g., 10): " max_matches

    echo -e "${YELLOW}Matching orders...${NC}"
    $CAST send $ENGINE_ADDRESS "matchOrders(uint256)" $max_matches \
        --rpc-url sepolia --private-key $PRIVATE_KEY --legacy

    echo -e "${GREEN}✓ Matching complete! Check events for details.${NC}"
}

# Function to repay loan
repay_loan() {
    echo -e "${BLUE}💸 Repay Loan${NC}"
    echo ""

    read -p "Loan ID: " loan_id

    echo -e "${YELLOW}Approving USDC for repayment...${NC}"
    $CAST send $USDC_ADDRESS "approve(address,uint256)" $ENGINE_ADDRESS 10000000000 \
        --rpc-url sepolia --private-key $PRIVATE_KEY --legacy

    echo -e "${YELLOW}Repaying loan...${NC}"
    $CAST send $ENGINE_ADDRESS "repayLoan(uint256)" $loan_id \
        --rpc-url sepolia --private-key $PRIVATE_KEY --legacy

    echo -e "${GREEN}✓ Loan repaid! Collateral returned.${NC}"
}

# Function to withdraw
withdraw() {
    echo -e "${BLUE}💵 Withdraw Funds${NC}"
    echo ""

    WITHDRAWABLE=$($CAST call $ENGINE_ADDRESS "getWithdrawableBalance(address)(uint96)" $YOUR_ADDRESS --rpc-url sepolia)
    WITHDRAWABLE_READABLE=$(echo "scale=2; $WITHDRAWABLE / 1000000" | bc)

    echo -e "${YELLOW}Available to withdraw: $WITHDRAWABLE_READABLE USDC${NC}"

    if [ "$WITHDRAWABLE" -eq 0 ]; then
        echo -e "${RED}Nothing to withdraw${NC}"
        return
    fi

    read -p "Proceed with withdrawal? (y/n): " confirm

    if [ "$confirm" == "y" ]; then
        echo -e "${YELLOW}Withdrawing...${NC}"
        $CAST send $ENGINE_ADDRESS "withdraw()" \
            --rpc-url sepolia --private-key $PRIVATE_KEY --legacy

        echo -e "${GREEN}✓ Withdrawal successful!${NC}"
    fi
}

# Main menu
while true; do
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Main Menu:${NC}"
    echo "  1) Check Balances"
    echo "  2) Deposit as Lender"
    echo "  3) Request Borrow"
    echo "  4) Match Orders (Keeper)"
    echo "  5) Repay Loan"
    echo "  6) Withdraw"
    echo "  7) View Contract on Etherscan"
    echo "  8) Get USDC from Faucet"
    echo "  0) Exit"
    echo ""
    read -p "Select option: " option

    case $option in
        1) check_balances ;;
        2) deposit_lender ;;
        3) request_borrow ;;
        4) match_orders ;;
        5) repay_loan ;;
        6) withdraw ;;
        7)
            echo "Opening Etherscan..."
            echo "https://sepolia.etherscan.io/address/$ENGINE_ADDRESS"
            ;;
        8)
            echo "Opening Aave Faucet..."
            echo "https://staging.aave.com/faucet/"
            echo "Use your address: $YOUR_ADDRESS"
            ;;
        0)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
done

#!/bin/bash
# Full flow test for P2P Lending Platform

set -e
source .env

echo "=================================="
echo "P2P Lending Platform - Full Test"
echo "=================================="
echo ""
echo "Contract: $ENGINE_ADDRESS"
echo "LINK: $LINK_ADDRESS"
echo ""

# Get user address
export YOUR_ADDRESS=$(~/.foundry/bin/cast wallet address --private-key $PRIVATE_KEY)
echo "Your address: $YOUR_ADDRESS"
echo ""

# Check LINK balance
echo "1. Checking LINK balance..."
LINK_BALANCE=$(~/.foundry/bin/cast call $LINK_ADDRESS "balanceOf(address)(uint256)" $YOUR_ADDRESS --rpc-url $SEPOLIA_RPC_URL)
echo "LINK Balance: $LINK_BALANCE"
echo ""

# Deposit as lender
echo "2. Depositing 1000 LINK as lender (5% APR, 7 days)..."
~/.foundry/bin/cast send $LINK_ADDRESS "approve(address,uint256)" $ENGINE_ADDRESS 1000000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy
~/.foundry/bin/cast send $ENGINE_ADDRESS "depositLender(uint96,uint16,uint8)" 1000000000000000000000 500 0 \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy
echo "✓ Lender deposit successful"
echo ""

# Request borrow
echo "3. Requesting to borrow 500 LINK (6% max APR, 7 days)..."
~/.foundry/bin/cast send $LINK_ADDRESS "approve(address,uint256)" $ENGINE_ADDRESS 667000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy
~/.foundry/bin/cast send $ENGINE_ADDRESS "requestBorrow(uint96,uint16,uint8,uint96)" \
    500000000000000000000 600 0 667000000000000000000 \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy
echo "✓ Borrow request successful"
echo ""

# Match orders
echo "4. Matching orders..."
~/.foundry/bin/cast send $ENGINE_ADDRESS "matchOrders(uint256)" 10 \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy
echo "✓ Matching successful!"
echo ""

# Check Aave balance
echo "5. Checking contract's Aave balance..."
AAVE_BALANCE=$(~/.foundry/bin/cast call $ENGINE_ADDRESS "getAaveBalance()(uint256)" --rpc-url $SEPOLIA_RPC_URL)
echo "Aave Balance: $AAVE_BALANCE"
echo ""

# Check withdrawable balance
echo "6. Checking your withdrawable balance..."
WITHDRAWABLE=$(~/.foundry/bin/cast call $ENGINE_ADDRESS "getWithdrawableBalance(address)(uint96)" $YOUR_ADDRESS --rpc-url $SEPOLIA_RPC_URL)
echo "Withdrawable: $WITHDRAWABLE"
echo ""

echo "=================================="
echo "✓ Full flow test completed!"
echo "=================================="

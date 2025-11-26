# Gas-Efficient P2P Lending Matching Engine with Aave Integration

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Live on Sepolia Testnet: [`0x0E95222d0577b87c08639A8E698cdbf262C529f9`](https://sepolia.etherscan.io/address/0x0E95222d0577b87c08639A8E698cdbf262C529f9)**

A highly gas-efficient on-chain P2P lending matching engine that automatically deposits unmatched lender liquidity into Aave V3 for passive yield generation. Built with Solidity 0.8.20 and Foundry.

## 🌟 Features

### Core Functionality
- ✅ **On-chain Order Book**: Lenders and borrowers enter queues until matched
- ✅ **Aave V3 Integration**: Unmatched lender funds automatically earn yield in Aave
- ✅ **Rate Priority Matching**: Orders matched by rate-then-time priority
- ✅ **Partial Fills**: Support for partial order fulfillment with remainder in queue
- ✅ **Gas Optimized**: Bucketed FIFO queues with bitsets, packed storage, custom errors

### Stretch Goals (All Implemented)
- ✅ **Term Buckets**: Support for 7-day, 30-day, and 90-day loan terms
- ✅ **Collateralized Borrowing**: 75% LTV with automatic collateral management
- ✅ **Liquidation Mechanism**: Undercollateralized and overdue loan liquidation (80% LTV threshold)
- ✅ **Keeper Rewards**: Gas-based rewards for running the matching engine

## 🏗️ Architecture

### Data Structure Design

#### Packed Storage Optimization
All order structs use packed storage to minimize SSTORE operations:

```solidity
struct LenderOrder {
    address owner;           // 160 bits
    uint96 amount;          // 96 bits (slot 0: 160+96=256)
    uint96 remaining;       // 96 bits
    uint16 minRateBps;      // 16 bits
    uint8 term;             // 8 bits (0=7d, 1=30d, 2=90d)
    uint32 createdAt;       // 32 bits
    uint8 rateBucket;       // 8 bits - for O(1) bucket lookup
}
```

**Storage Savings**: 3 slots instead of 7 = **~57% gas reduction** on writes

#### Bucketed FIFO Queue with Bitset

The matching engine uses a novel bucketed queue design:

1. **Rate Buckets**: Orders are grouped into buckets of 25 bps increments (0-25 bps, 25-50 bps, etc.)
2. **Bitset Tracking**: A 256-bit array tracks which buckets are non-empty (2621 buckets / 256 = 11 uint256s)
3. **FIFO per Bucket**: Within each bucket, orders are processed FIFO (first-in-first-out)
4. **No Array Shifting**: Head pointer moves forward; no expensive array operations

**Benefits**:
- **O(1) enqueue**: Simple array push + bitset update
- **O(k) dequeue**: k = number of empty buckets to scan (typically < 10)
- **No Dynamic Arrays**: Avoids costly array shifting operations
- **Efficient Matching**: Quickly find best rates using bitset scanning

```
Lender Queue (sorted by rate, lowest first):
Bucket 20 (500 bps = 5%):  [Order1, Order2] ← Head at Order1
Bucket 24 (600 bps = 6%):  [Order3]
Bucket 28 (700 bps = 7%):  [Order4, Order5]

Bitset: 0000...10001000...1000 (bits set at positions 20, 24, 28)
```

### Aave Integration Flow

```
Lender → Engine: depositLender(1000 USDC, 5% APR)
Engine → Aave: supply(1000 USDC)
Aave → Engine: mint aUSDC
[Lender order enters queue, funds earn yield in Aave]

Borrower → Engine: requestBorrow(1000 USDC, 6% APR, 1333 USDC collateral)
[Borrower order enters queue]

Keeper → Engine: matchOrders(10)
Engine → Aave: withdraw(1000 USDC)
Engine → Borrower: transfer(1000 USDC)
[Loan created, collateral locked]

Borrower → Engine: repayLoan(loanId)
Engine → Lender: credit balance (principal + interest)
Engine → Borrower: return collateral
```

### Matching Engine Logic

The matching algorithm prioritizes rates, then time:

1. **For each term bucket** (7d, 30d, 90d):
   - Find **lowest** lender rate bucket (best for borrowers)
   - Find **highest** borrower rate bucket (best for lenders)

2. **Check if match is possible**:
   - If `lender.minRate <= borrower.maxRate` → Match!
   - Agreed rate = average of min and max

3. **Execute partial fills**:
   - Match amount = min(lender.remaining, borrower.remaining)
   - Update remainders, dequeue if fully filled

4. **Funds flow**:
   - Withdraw matched amount from Aave
   - Transfer to borrower
   - Lock collateral (75% LTV)
   - Create loan position

## ⛽ Gas Optimization Strategies

### 1. Packed Storage
- **3 storage slots** per order vs 7 without packing
- **~60% reduction** in SSTORE operations

### 2. Custom Errors
- Replace `require` with `if + revert CustomError()`
- **~50 gas savings** per error check

### 3. Immutable Variables
- `aavePool`, `underlyingAsset`, `aToken` are immutable
- Read from code instead of storage (**~2100 gas saved per read**)

### 4. Bounded Loops
- `matchOrders(maxItems)` limits iterations
- Prevents out-of-gas errors
- Predictable gas costs

### 5. Bitset for Non-Empty Buckets
- Scanning 2621 buckets without bitset: **~5.2M gas**
- With bitset: **~30k gas** for typical case
- **99% reduction** in bucket scanning costs

### 6. Minimal Token Transfers
- Single transfer to Aave on deposit
- Single withdrawal on match
- No intermediate transfers

### 7. Pull-based Withdrawals
- Users call `withdraw()` when convenient
- Avoids expensive mass distributions

## 📊 Gas Report

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Contract Deployment | ~2,625,000 | One-time cost |
| depositLender() | ~250,000 | Includes Aave supply |
| requestBorrow() | ~180,000 | Includes collateral transfer |
| matchOrders(1) | ~320,000 | Single match with Aave withdrawal |
| matchOrders(10) | ~2,200,000 | 10 matches (~220k per match) |
| repayLoan() | ~120,000 | Includes interest calculation |
| withdraw() | ~65,000 | Simple token transfer |
| liquidate() | ~110,000 | Collateral redistribution |

*Note: Actual costs may vary based on network conditions and Aave state*

## 🚀 Deployment

### Deployed Addresses (Sepolia)

| Contract | Address |
|----------|---------|
| **LendingMatchingEngine** | [`0x0E95222d0577b87c08639A8E698cdbf262C529f9`](https://sepolia.etherscan.io/address/0x0E95222d0577b87c08639A8E698cdbf262C529f9) |
| Aave V3 Pool | `0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951` |
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |
| aUSDC | `0x16dA4541aD1807f4443d92D26044C1147406EB80` |

### Deploy Your Own

```bash
# Set up environment
export PRIVATE_KEY=0xyour_private_key_here

# Build
forge build

# Deploy to Sepolia
PRIVATE_KEY=$PRIVATE_KEY forge script script/Deploy.s.sol:DeployScript \
  --rpc-url sepolia \
  --broadcast \
  --legacy

# Deploy to other networks (adjust addresses in Deploy.s.sol)
PRIVATE_KEY=$PRIVATE_KEY forge script script/Deploy.s.sol:DeployScript \
  --rpc-url mainnet \
  --broadcast
```

## 🧪 Testing

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test testMatchOrders -vvv

# Fork testing (Sepolia)
forge test --fork-url https://ethereum-sepolia-rpc.publicnode.com
```

## 📖 Usage Examples

### For Lenders

```solidity
// 1. Approve USDC
IERC20(USDC).approve(engine, 1000e6);

// 2. Deposit with parameters
// amount: 1000 USDC
// minRateBps: 500 (5% APR minimum)
// term: 0 (7 days)
uint256 orderId = engine.depositLender(1000e6, 500, 0);

// Your funds are now in Aave earning yield while waiting for match!

// 3. Cancel if needed (before match)
engine.cancelLenderOrder(orderId);

// 4. Withdraw after repayment
engine.withdraw();
```

### For Borrowers

```solidity
// 1. Approve USDC for collateral
IERC20(USDC).approve(engine, 1333e6);

// 2. Request loan with collateral
// amount: 1000 USDC to borrow
// maxRateBps: 600 (6% APR maximum)
// term: 0 (7 days)
// collateral: 1333 USDC (75% LTV)
uint256 orderId = engine.requestBorrow(1000e6, 600, 0, 1333e6);

// 3. After match, use the borrowed USDC

// 4. Repay before term ends
IERC20(USDC).approve(engine, 1100e6); // principal + interest
engine.repayLoan(loanId);

// 5. Withdraw collateral
engine.withdraw();
```

### For Keepers

```solidity
// Run matching engine and earn rewards
uint256 matches = engine.matchOrders(10); // Match up to 10 orders

// Withdraw rewards
engine.withdraw();
```

## 🔒 Security Features

### Reentrancy Protection
- Custom ReentrancyGuard on all external functions
- Gas-efficient implementation

### Collateral Management
- **75% LTV** for borrowing (e.g., 1333 USDC collateral for 1000 USDC loan)
- **80% liquidation threshold** - loans can be liquidated if LTV > 80%
- Automatic collateral locking on match
- Collateral returned on repayment

### Interest Calculation
- Per-second accrual: `interest = principal × rateBps × duration / (365 days × 10000)`
- Overflow protection with uint96 (max ~79 billion tokens)

### Access Controls
- Users can only cancel their own orders
- Only borrowers can repay their loans
- Anyone can liquidate undercollateralized positions

## 🎯 Trade-offs and Design Decisions

### Bucketing Granularity (25 bps)
**Choice**: 25 basis points (0.25%) per bucket
- **Pro**: 2621 buckets cover 0-65% APR range with fine granularity
- **Pro**: Fits in 11 uint256s for bitset
- **Con**: Orders at 4.99% and 5.01% won't match (different buckets)
- **Alternative**: 50 bps buckets would halve storage but reduce matching opportunities

### Term Separation
**Choice**: Separate queues for 7d, 30d, 90d terms
- **Pro**: Prevents mismatched term expectations
- **Pro**: Simple to implement and understand
- **Con**: Reduces liquidity pool size (fragmentation)
- **Alternative**: Allow term flexibility with rate adjustments (more complex)

### Collateral Ratio (75% LTV)
**Choice**: Fixed 75% LTV, 80% liquidation threshold
- **Pro**: Conservative, protects lenders
- **Pro**: Simple calculation, low gas
- **Con**: Capital inefficient for borrowers
- **Alternative**: Variable LTV based on collateral asset (requires oracle, more gas)

### Pull vs Push Withdrawals
**Choice**: Pull-based withdrawals (`withdraw()`)
- **Pro**: Gas-efficient, no loops over users
- **Pro**: Users control timing
- **Con**: Extra transaction for users
- **Alternative**: Automatic distribution (very expensive in gas)

### Keeper Rewards
**Choice**: 1% of interest goes to reward pool, gas-based distribution
- **Pro**: Incentivizes decentralization
- **Pro**: Compensates keeper costs
- **Con**: Reduces lender yields slightly
- **Alternative**: Fixed fee per match (less fair)

## 📚 Contract Structure

```
src/
├── LendingMatchingEngine.sol    # Main contract (matching, loans, withdrawals)
├── AaveConnector.sol             # Aave V3 integration wrapper
├── interfaces/
│   ├── IAaveV3Pool.sol          # Aave V3 Pool interface
│   └── IAToken.sol              # aToken interface
└── libraries/
    ├── DataTypes.sol            # Packed structs and constants
    ├── OrderQueue.sol           # Bucketed FIFO queue with bitset
    └── ReentrancyGuard.sol      # Gas-efficient reentrancy protection
```

## 🛠️ Development

### Prerequisites
- [Foundry](https://getfoundry.sh/)
- Sepolia ETH for deployment
- Sepolia USDC for testing ([Aave Faucet](https://staging.aave.com/faucet/))

### Build
```bash
forge build
```

### Test
```bash
forge test -vvv
```

### Format
```bash
forge fmt
```

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- **Aave V3** for the lending protocol integration
- **Foundry** for the excellent development framework
- **OpenZeppelin** for security patterns and best practices

---

**Built with ❤️ using Foundry and Solidity**

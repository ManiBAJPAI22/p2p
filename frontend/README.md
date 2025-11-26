# P2P Lending Platform - Frontend

A beautiful, modern web interface for the P2P Lending Platform on Sepolia testnet.

## Features

- 💰 **Lend LINK** - Deposit LINK and earn interest
- 💳 **Borrow LINK** - Request loans with collateral
- 🔄 **Match Orders** - Automatic order matching
- 💸 **Repay Loans** - Repay with interest to get collateral back
- 💵 **Withdraw** - Withdraw your available balance
- 📊 **Real-time Balances** - See your LINK, Aave, and withdrawable balances
- 🔗 **Aave Integration** - Funds earn yield in Aave when unmatched

## Setup Instructions

### 1. Install Dependencies

```bash
cd frontend
npm install
```

### 2. Run Development Server

```bash
npm run dev
```

The app will be available at [http://localhost:3000](http://localhost:3000)

### 3. Connect Your Wallet

1. Open the app in your browser
2. Click "Connect MetaMask"
3. Approve the connection
4. The app will automatically switch to Sepolia testnet

### 4. Get LINK Tokens

Visit the [Aave Faucet](https://staging.aave.com/faucet/) to get test LINK tokens on Sepolia.

## Usage Guide

### As a Lender

1. Enter amount of LINK to lend
2. Set minimum APR (in basis points, e.g., 500 = 5%)
3. Choose loan term (7, 30, or 90 days)
4. Click "Deposit as Lender"
5. Confirm two transactions:
   - Approve LINK spending
   - Deposit to contract
6. Your funds will earn yield in Aave until matched

### As a Borrower

1. Enter amount of LINK to borrow
2. Set maximum APR (in basis points, e.g., 600 = 6%)
3. Collateral is auto-calculated at 133% (75% LTV)
4. Choose loan term
5. Click "Request Borrow"
6. Confirm two transactions:
   - Approve collateral
   - Submit borrow request

### Matching Orders

Click "Match Now" to match pending lender and borrower orders. The contract will:
- Find compatible orders (overlapping rates and matching terms)
- Negotiate an agreed rate (average of min and max)
- Create loans and transfer funds
- Return excess collateral

### Repaying Loans

1. Enter your loan ID
2. Click "Repay Loan"
3. Confirm two transactions:
   - Approve repayment amount
   - Repay loan
4. Your collateral will be returned

### Withdrawing Funds

Click "Withdraw All" to withdraw your available balance (repaid principal, interest, and excess collateral).

## Contract Addresses (Sepolia)

- **Engine:** `0x622728dECdf3D473F40548da26688A24b4bED2AA`
- **LINK Token:** `0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5`
- **Aave Pool:** `0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951`

## Build for Production

```bash
npm run build
npm start
```

## Technology Stack

- **Next.js 14** - React framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **ethers.js v6** - Ethereum interaction
- **MetaMask** - Wallet connection

## Troubleshooting

### MetaMask not detected
- Make sure MetaMask is installed
- Refresh the page after installing

### Wrong network
- The app will automatically prompt you to switch to Sepolia
- Or manually switch in MetaMask

### Transaction failed
- Check you have enough LINK tokens
- Check you have enough ETH for gas
- Make sure your wallet is connected

### Insufficient allowance
- The app handles approvals automatically
- If issues persist, try increasing gas limit

## Support

For issues or questions, check the contract on [Sepolia Etherscan](https://sepolia.etherscan.io/address/0x622728dECdf3D473F40548da26688A24b4bED2AA).

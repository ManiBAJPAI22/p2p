# Full Architecture Guide: Frontend ↔ Smart Contracts

This document explains how the entire P2P Lending system works together - frontend, smart contracts, and scripts.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER'S BROWSER                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │           Frontend (Next.js App)                          │  │
│  │  • React Components                                       │  │
│  │  • ethers.js Library                                      │  │
│  │  • MetaMask Integration                                   │  │
│  └───────────────────┬───────────────────────────────────────┘  │
└────────────────────────┼──────────────────────────────────────────┘
                         │
                         │ 1. User connects MetaMask
                         │ 2. Signs transactions
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ETHEREUM SEPOLIA NETWORK                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         Smart Contracts (THE "BACKEND")                   │  │
│  │                                                            │  │
│  │  LendingMatchingEngine.sol (0xeDab...930c)               │  │
│  │  • depositLender()                                        │  │
│  │  • requestBorrow()                                        │  │
│  │  • matchOrders()                                          │  │
│  │  • repayLoan()                                            │  │
│  │  • withdraw()                                             │  │
│  │                                                            │  │
│  │  ┌─────────────────────────────────────────────┐         │  │
│  │  │   Aave V3 Pool (0x6Ae4...f738951)          │         │  │
│  │  │   • supply()                                │         │  │
│  │  │   • withdraw()                              │         │  │
│  │  └─────────────────────────────────────────────┘         │  │
│  │                                                            │  │
│  │  ┌─────────────────────────────────────────────┐         │  │
│  │  │   LINK Token (0xf8Fb...EBE5)               │         │  │
│  │  │   • transfer()                              │         │  │
│  │  │   • approve()                               │         │  │
│  │  └─────────────────────────────────────────────┘         │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                         ▲
                         │
                         │ Deployment & Testing
                         │
┌─────────────────────────────────────────────────────────────────┐
│              DEVELOPMENT MACHINE (Your Computer)                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │   Foundry Scripts (script/*.sol)                          │  │
│  │   • Deploy.s.sol - Deploys contracts                      │  │
│  │   • Interact.s.sol - Test interactions                    │  │
│  │                                                            │  │
│  │   Tests (test/*.sol)                                      │  │
│  │   • Unit tests                                            │  │
│  │   • Integration tests                                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 📊 How It All Works Together

### 1. **Smart Contracts = Backend**

In blockchain applications, **there is NO traditional backend server**. The smart contracts deployed on Ethereum ARE your backend:

- **Storage**: Contract state variables store all data
- **Business Logic**: Contract functions execute all operations
- **Security**: Blockchain consensus ensures integrity
- **Always On**: No server to maintain or restart

Your deployed contract at `0xeDab44412d8bdA5fc9b6bec393C5B2F117cB930c` is:
- ✅ Live 24/7 on Sepolia testnet
- ✅ Accessible from anywhere
- ✅ Immutable and secure
- ✅ No hosting costs (users pay gas)

### 2. **Frontend = User Interface**

The Next.js frontend ([frontend/app/page.tsx](frontend/app/page.tsx#L1)) is a **pure client-side application** that:

```typescript
// 1. Connects to user's wallet (MetaMask)
const provider = new ethers.BrowserProvider(window.ethereum)
const signer = await provider.getSigner()

// 2. Creates contract instance with ABI
const engineContract = new ethers.Contract(
  CONTRACTS.ENGINE_ADDRESS,        // Contract address on blockchain
  LendingMatchingEngineABI,         // Function signatures (ABI)
  signer                            // User's wallet to sign transactions
)

// 3. Calls contract functions directly
const depositTx = await engineContract.depositLender(amount, rate, term)
await depositTx.wait()  // Wait for blockchain confirmation
```

**Key Points:**
- Frontend talks **directly** to blockchain
- No API server in between
- Uses ethers.js library for blockchain communication
- MetaMask signs transactions with user's private key
- All data comes from reading blockchain state

### 3. **The ABI: Contract's "API Documentation"**

The ABI (Application Binary Interface) at [frontend/abi/LendingMatchingEngine.json](frontend/abi/LendingMatchingEngine.json) is like an API specification:

```json
{
  "name": "depositLender",
  "type": "function",
  "inputs": [
    {"name": "amount", "type": "uint96"},
    {"name": "minRateBps", "type": "uint16"},
    {"name": "term", "type": "uint8"}
  ],
  "outputs": [{"name": "orderId", "type": "uint256"}]
}
```

This tells the frontend:
- What functions exist
- What parameters they need
- What types to use
- What they return

**How to generate/update ABI:**
```bash
# After changing contracts, rebuild to get new ABI
cd /home/manibajpai/sup/p2p-lending
forge build

# Copy new ABI to frontend
cat out/LendingMatchingEngine.sol/LendingMatchingEngine.json | jq .abi > frontend/abi/LendingMatchingEngine.json
```

### 4. **Scripts = Development Tools**

The Foundry scripts ([script/](script/)) are **NOT part of the deployed system**. They're development tools:

#### [script/Deploy.s.sol](script/Deploy.s.sol)
```solidity
// Used ONCE to deploy contracts to Sepolia
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url sepolia \
  --broadcast \
  --private-key $PRIVATE_KEY
```

**Purpose:**
- Deploy `LendingMatchingEngine.sol` to blockchain
- Set up constructor parameters
- Connect to Aave V3
- Returns deployed contract address

**After deployment, this script is never used again** - the contract lives on blockchain forever.

#### [script/Interact.s.sol](script/Interact.s.sol)
```solidity
// For testing interactions from command line
forge script script/Interact.s.sol:InteractScript \
  --rpc-url sepolia \
  --broadcast
```

**Purpose:**
- Test contract functions without frontend
- Useful for debugging
- Can deposit/borrow/match orders via CLI
- **Not used by end users** - they use the frontend

### 5. **Configuration Files**

#### [frontend/config/contracts.ts](frontend/config/contracts.ts)
```typescript
export const CONTRACTS = {
  ENGINE_ADDRESS: '0xeDab44412d8bdA5fc9b6bec393C5B2F117cB930c',  // YOUR deployed contract
  LINK_ADDRESS: '0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5',     // Sepolia LINK token
  AAVE_POOL_ADDRESS: '0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951', // Sepolia Aave V3
  ALINK_ADDRESS: '0x3FfAf50D4F4E96eB78f2407c090b72e86eCaed24',    // Sepolia aLINK
}
```

**This file tells the frontend WHERE to find contracts on blockchain.**

If you deploy a new version of your contract, you'd update `ENGINE_ADDRESS` here.

## 🔄 Complete Data Flow Example

Let's trace what happens when a user deposits as a lender:

### Step 1: User Interaction
```
User enters:
- Amount: 1000 LINK
- Minimum APR: 5% (500 bps)
- Term: 7 days

User clicks "Deposit as Lender" button
```

### Step 2: Frontend Processing
```typescript
// frontend/app/page.tsx:114-143
const depositLender = async () => {
  // 1. Get user's wallet signer
  const signer = await provider.getSigner()

  // 2. Create contract instances
  const linkContract = new ethers.Contract(LINK_ADDRESS, ERC20_ABI, signer)
  const engineContract = new ethers.Contract(ENGINE_ADDRESS, ABI, signer)

  // 3. Convert to blockchain format
  const amount = ethers.parseEther('1000')  // 1000 * 10^18 wei

  // 4. Approve LINK spending (required for ERC20)
  const approveTx = await linkContract.approve(ENGINE_ADDRESS, amount)
  await approveTx.wait()  // Wait for confirmation

  // 5. Call contract function
  const depositTx = await engineContract.depositLender(amount, 500, 0)
  await depositTx.wait()  // Wait for confirmation

  // 6. Update UI with new balances
  await loadBalances()
}
```

### Step 3: MetaMask Popup
```
┌───────────────────────────────────┐
│  MetaMask Transaction Request    │
├───────────────────────────────────┤
│  Contract: LendingMatchingEngine  │
│  Function: depositLender          │
│  Gas Fee: ~0.002 ETH             │
│                                   │
│  [ Reject ]      [ Confirm ]     │
└───────────────────────────────────┘

User clicks "Confirm"
```

### Step 4: Blockchain Execution
```
Transaction sent to Sepolia network
↓
Miners/Validators include it in a block
↓
LendingMatchingEngine.depositLender() executes:
  1. Transfer 1000 LINK from user to contract
  2. Supply 1000 LINK to Aave (earn yield)
  3. Add order to lender queue
  4. Update bitset for bucket tracking
  5. Emit LenderDeposited event
↓
Transaction confirmed in ~12 seconds
```

### Step 5: Frontend Updates
```typescript
// Listen for confirmation
const receipt = await depositTx.wait()

// Show success
setTxHash(receipt.hash)  // Display on UI
alert('✅ Lender deposit successful!')

// Fetch new balances from blockchain
const balance = await engineContract.getWithdrawableBalance(account)
setWithdrawableBalance(ethers.formatEther(balance))
```

### Step 6: User Sees Result
```
✅ Transaction Successful!
View on Etherscan: 0xabc123...

Updated Balances:
- LINK Balance: 9000 LINK
- In Aave: 1000 LINK
- Withdrawable: 0 LINK
```

## 🚀 Complete Deployment Workflow

Here's the **full process** from development to live production:

### Phase 1: Development (Local)
```bash
# 1. Write smart contracts
vim src/LendingMatchingEngine.sol

# 2. Write tests
vim test/LendingMatchingEngine.t.sol

# 3. Run tests locally
forge test -vvv

# 4. Build contracts
forge build

# This generates ABI in out/LendingMatchingEngine.sol/LendingMatchingEngine.json
```

### Phase 2: Deploy Smart Contracts (Once)
```bash
# 1. Deploy to Sepolia testnet
PRIVATE_KEY=$PRIVATE_KEY forge script script/Deploy.s.sol:DeployScript \
  --rpc-url sepolia \
  --broadcast

# Output: Contract deployed at 0xeDab44412d8bdA5fc9b6bec393C5B2F117cB930c

# 2. Copy ABI to frontend
cat out/LendingMatchingEngine.sol/LendingMatchingEngine.json | jq .abi > frontend/abi/LendingMatchingEngine.json

# 3. Update contract address in frontend config
vim frontend/config/contracts.ts
# Set ENGINE_ADDRESS to your deployed address
```

**IMPORTANT: This step is done ONCE. The contract now lives on blockchain forever.**

### Phase 3: Deploy Frontend (Multiple Times)
```bash
# 1. Navigate to frontend
cd frontend

# 2. Test locally
npm install
npm run dev
# Visit http://localhost:3000

# 3. Push to GitHub
git add .
git commit -m "Update contract address"
git push origin main

# 4. Deploy to Vercel
# • Import repo on vercel.com
# • Set root directory: frontend
# • Add env var: NEXT_PUBLIC_RPC_URL
# • Deploy

# 5. OR Deploy to Railway
# • Import repo on railway.app
# • Set root directory: frontend
# • Add env vars
# • Deploy
```

**You can redeploy the frontend anytime** - it just reconnects to the existing contract on blockchain.

### Phase 4: Updates and Iterations

**If you update frontend code (UI changes, bug fixes):**
```bash
# Just redeploy frontend
git commit -am "Fix UI bug"
git push
# Vercel/Railway auto-deploys
```

**If you update smart contract code:**
```bash
# 1. Deploy NEW contract to blockchain
forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast
# Get new address: 0xNEW_ADDRESS...

# 2. Update frontend to use new contract
vim frontend/config/contracts.ts
# Change ENGINE_ADDRESS to new address

# 3. Copy new ABI
cat out/LendingMatchingEngine.sol/LendingMatchingEngine.json | jq .abi > frontend/abi/LendingMatchingEngine.json

# 4. Redeploy frontend
git commit -am "Update to new contract"
git push
```

**Note:** You can't modify existing deployed contracts - you must deploy new ones.

## 🔌 RPC Connection: The Bridge

The RPC (Remote Procedure Call) URL is how the frontend communicates with blockchain:

```typescript
// In frontend
const provider = new ethers.JsonRpcProvider(NETWORK.rpcUrl)
// OR
const provider = new ethers.BrowserProvider(window.ethereum)
```

**What RPC does:**
- Sends transactions to blockchain
- Reads contract state
- Listens for events
- Checks balances

**RPC Providers:**
1. **MetaMask**: Uses user's configured RPC (usually Infura)
2. **Alchemy**: Professional RPC service (recommended)
3. **Infura**: Popular RPC service
4. **Public RPCs**: Free but rate-limited

**For production deployment:**
```bash
# Vercel/Railway environment variable
NEXT_PUBLIC_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
```

The frontend reads this and uses it to connect to blockchain.

## 🧪 Testing the Full Stack

### Local Testing (Before Deployment)
```bash
# 1. Start local blockchain (optional)
anvil

# 2. Deploy contracts to local chain
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast

# 3. Update frontend config with local address
# frontend/config/contracts.ts: ENGINE_ADDRESS = <local_address>

# 4. Start frontend
cd frontend
npm run dev

# 5. Connect MetaMask to localhost:8545
# 6. Test all functions
```

### Testnet Testing (Recommended)
```bash
# 1. Contracts already deployed to Sepolia ✅
# 2. Start frontend locally
cd frontend
npm run dev

# 3. Connect MetaMask to Sepolia
# 4. Get test LINK from faucet
# 5. Test all functions with real blockchain
```

### Production Testing (After Deployment)
```bash
# 1. Deploy frontend to Vercel/Railway
# 2. Visit your live URL
# 3. Connect MetaMask
# 4. Test with real users
```

## 📁 File Structure Summary

```
p2p-lending/
├── src/                          # Smart contracts (backend)
│   └── LendingMatchingEngine.sol # Main contract
│
├── script/                       # Deployment & test scripts
│   ├── Deploy.s.sol             # Deploy to blockchain (run once)
│   └── Interact.s.sol           # CLI interactions (for testing)
│
├── test/                        # Contract unit tests
│   └── *.t.sol                  # Foundry tests
│
├── frontend/                    # User interface (client-side)
│   ├── app/
│   │   └── page.tsx            # Main UI (calls contracts)
│   ├── config/
│   │   └── contracts.ts        # Contract addresses & config
│   ├── abi/
│   │   └── LendingMatchingEngine.json  # Contract interface
│   └── package.json            # Frontend dependencies
│
├── out/                         # Compiled contracts
│   └── LendingMatchingEngine.sol/
│       └── LendingMatchingEngine.json  # Compiled output with ABI
│
├── .env                         # Private keys (NEVER commit!)
├── foundry.toml                 # Foundry config
└── README.md                    # Documentation
```

## 🔐 Security Considerations

### Frontend (Public Code)
- ✅ Can be open source
- ✅ No secrets stored
- ✅ Users sign transactions with their own keys
- ✅ Can't steal funds (no private keys in frontend)

### Smart Contracts (Immutable)
- ✅ Deployed once, can't be changed
- ✅ Code is public on blockchain
- ✅ Security audits recommended
- ✅ All operations verified by blockchain

### Environment Variables
- ❌ NEVER commit `PRIVATE_KEY` to git
- ❌ Don't hardcode private keys in code
- ✅ Use `.env` files (in `.gitignore`)
- ✅ RPC URLs can be public (no security risk)

## 🎯 Summary: How It All Works

1. **Smart contracts** are deployed to Sepolia blockchain (done once)
2. **Frontend** is deployed to Vercel/Railway (can redeploy anytime)
3. **Users** visit your frontend URL in their browser
4. **MetaMask** connects user's wallet to the frontend
5. **ethers.js** sends transactions from frontend to blockchain
6. **Smart contracts** execute logic and store state on blockchain
7. **Frontend** reads results and updates UI
8. **No traditional backend server** - blockchain IS the backend

**The "backend" is always available at:**
`https://sepolia.etherscan.io/address/0xeDab44412d8bdA5fc9b6bec393C5B2F117cB930c`

**Your frontend will be available at:**
- Vercel: `https://your-project.vercel.app`
- Railway: `https://your-project.up.railway.app`

**Scripts are only used by developers** for deployment and testing - never by end users.

---

## 📚 Additional Resources

- [ethers.js Documentation](https://docs.ethers.org/v6/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Foundry Book](https://book.getfoundry.sh/)
- [Ethereum Development](https://ethereum.org/en/developers/)

**Questions?** Check [DEPLOYMENT.md](DEPLOYMENT.md) and [FRONTEND_DEPLOYMENT.md](FRONTEND_DEPLOYMENT.md)

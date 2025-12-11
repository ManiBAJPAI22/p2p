# Frontend Deployment Guide

This guide explains how to deploy the P2P Lending frontend to **Vercel** (recommended) and **Railway**.

## 📋 Prerequisites

Before deploying, ensure you have:
- Your GitHub repository set up
- Contract addresses (already configured in `frontend/config/contracts.ts`)
- An RPC provider (Alchemy, Infura, or public RPC)

## 🚀 Deploy to Vercel (Recommended)

Vercel is optimized for Next.js and provides the best performance.

### Step 1: Prepare Your Repository

1. Push your code to GitHub:
```bash
git add .
git commit -m "Prepare for deployment"
git push origin main
```

### Step 2: Connect to Vercel

1. Go to [vercel.com](https://vercel.com)
2. Sign up/Login with GitHub
3. Click **"Add New Project"**
4. Import your `p2p-lending` repository

### Step 3: Configure Build Settings

In the Vercel project configuration:

**Framework Preset**: Next.js
**Root Directory**: `frontend`
**Build Command**: `npm run build`
**Output Directory**: `.next` (default)
**Install Command**: `npm install`

### Step 4: Set Environment Variables

Add these environment variables in Vercel dashboard:

| Variable Name | Value | Description |
|--------------|-------|-------------|
| `NEXT_PUBLIC_RPC_URL` | `https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY` | Sepolia RPC URL |

**Note**: Contract addresses are already hardcoded in `config/contracts.ts` - no need to add them as env variables.

#### Getting RPC URLs:

**Option 1: Alchemy (Recommended)**
1. Go to [alchemy.com](https://www.alchemy.com/)
2. Create free account
3. Create a new app for "Sepolia" network
4. Copy the HTTPS URL

**Option 2: Infura**
1. Go to [infura.io](https://infura.io/)
2. Create project
3. Use: `https://sepolia.infura.io/v3/YOUR_PROJECT_ID`

**Option 3: Public RPC (No signup)**
- `https://ethereum-sepolia-rpc.publicnode.com`
- Note: Public RPCs have rate limits

### Step 5: Deploy

1. Click **"Deploy"**
2. Wait 2-3 minutes for build to complete
3. Vercel will provide you with a URL like: `https://your-project.vercel.app`

### Step 6: Custom Domain (Optional)

1. Go to Project Settings → Domains
2. Add your custom domain
3. Follow DNS configuration instructions

## 🚂 Deploy to Railway

Railway is great for full-stack applications and provides easy database integration if needed later.

### Step 1: Prepare Your Repository

Same as Vercel - push your code to GitHub.

### Step 2: Create Railway Project

1. Go to [railway.app](https://railway.app/)
2. Sign up/Login with GitHub
3. Click **"New Project"**
4. Select **"Deploy from GitHub repo"**
5. Choose your `p2p-lending` repository

### Step 3: Configure Build Settings

Railway will auto-detect Next.js. If not, add a `nixpacks.toml` file to your **frontend** directory:

```toml
[phases.setup]
nixPkgs = ["nodejs-18_x"]

[phases.install]
cmds = ["npm install"]

[phases.build]
cmds = ["npm run build"]

[start]
cmd = "npm start"
```

### Step 4: Set Root Directory

1. In Railway dashboard, go to **Settings** → **General**
2. Set **Root Directory**: `frontend`
3. Set **Start Command**: `npm start`

### Step 5: Set Environment Variables

1. Go to **Variables** tab
2. Add these variables:

| Variable Name | Value |
|--------------|-------|
| `NEXT_PUBLIC_RPC_URL` | `https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY` |
| `PORT` | `3000` |

### Step 6: Deploy

1. Railway automatically deploys after configuration
2. Get your URL from the **Settings** tab
3. URL format: `https://your-project.up.railway.app`

### Step 7: Custom Domain (Optional)

1. Go to Settings → Domains
2. Add custom domain
3. Configure DNS records

## 🔧 Update Contract Configuration (If Using Different Network)

If you deployed contracts to a different network or addresses changed:

Edit `frontend/config/contracts.ts`:

```typescript
export const CONTRACTS = {
  ENGINE_ADDRESS: 'YOUR_NEW_ENGINE_ADDRESS',
  LINK_ADDRESS: 'YOUR_TOKEN_ADDRESS',
  AAVE_POOL_ADDRESS: 'YOUR_AAVE_POOL_ADDRESS',
  ALINK_ADDRESS: 'YOUR_ATOKEN_ADDRESS',
}

export const NETWORK = {
  chainId: 11155111, // Change if using different network
  name: 'Sepolia',
  rpcUrl: process.env.NEXT_PUBLIC_RPC_URL || 'FALLBACK_RPC_URL',
  blockExplorer: 'https://sepolia.etherscan.io',
}
```

Then commit and push to trigger redeployment.

## 🧪 Test Your Deployment

After deployment:

1. **Visit your URL**
2. **Open browser console** (F12)
3. **Check for errors**
4. **Connect wallet** (MetaMask, WalletConnect, etc.)
5. **Switch to Sepolia network**
6. **Test basic functionality**:
   - View order books
   - Place lender order
   - Place borrower order
   - Check matching

## 🐛 Troubleshooting

### Build Fails on Vercel/Railway

**Problem**: Build fails with TypeScript errors

**Solution**:
```bash
# Test build locally first
cd frontend
npm run build

# Fix any errors, then commit and push
```

### RPC Connection Issues

**Problem**: "Could not connect to network" error

**Solution**:
1. Check RPC URL is correct in environment variables
2. Try using a different RPC provider
3. Check Alchemy/Infura dashboard for API key limits

### Wallet Connection Issues

**Problem**: MetaMask shows wrong network

**Solution**:
1. Make sure you're on Sepolia testnet
2. Add Sepolia to MetaMask manually:
   - Network Name: Sepolia
   - RPC URL: Your RPC URL
   - Chain ID: 11155111
   - Currency: ETH

### Environment Variables Not Working

**Problem**: RPC URL not loading

**Solution**:
1. **Must prefix with `NEXT_PUBLIC_`** for client-side access
2. Redeploy after adding env variables
3. Check Vercel/Railway logs for errors

## 📊 Monitoring

### Vercel Analytics

1. Go to Analytics tab in Vercel dashboard
2. See visitor stats, performance metrics

### Railway Metrics

1. Go to Metrics tab
2. Monitor CPU, memory, requests

## 🔐 Security Best Practices

1. **Never commit private keys** - Use .gitignore
2. **Use environment variables** for sensitive data
3. **Enable HTTPS** (automatic on Vercel/Railway)
4. **Set CORS policies** if you add a backend API later
5. **Rate limit RPC calls** to avoid hitting API limits

## 💰 Cost Estimates

### Vercel
- **Hobby Plan (Free)**:
  - 100GB bandwidth/month
  - Unlimited projects
  - Perfect for this project
- **Pro Plan ($20/mo)**:
  - For production apps with high traffic

### Railway
- **Free Tier**:
  - $5 credit/month
  - ~500 hours runtime
  - Good for testing
- **Developer Plan ($5/mo)**:
  - For production deployments

## 🎉 Next Steps

After deployment:

1. **Share your live URL** with users
2. **Monitor logs** for errors
3. **Get Sepolia ETH** from faucet for testing
4. **Add more features** to frontend (stats, charts, etc.)
5. **Consider mainnet deployment** when ready

## 📚 Additional Resources

- [Next.js Deployment Docs](https://nextjs.org/docs/deployment)
- [Vercel Documentation](https://vercel.com/docs)
- [Railway Documentation](https://docs.railway.app/)
- [Sepolia Faucet](https://sepoliafaucet.com/)
- [Alchemy Dashboard](https://dashboard.alchemy.com/)

---

**Your P2P Lending platform is now live! 🚀**

Need help? Check the logs in Vercel/Railway dashboard or open an issue on GitHub.

'use client'

import { useState, useEffect } from 'react'
import { ethers } from 'ethers'
import { CONTRACTS, NETWORK, TERMS, COLLATERAL_RATIO } from '../config/contracts'
import LendingMatchingEngineABI from '../abi/LendingMatchingEngine.json'

const ERC20_ABI = [
  'function balanceOf(address owner) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
]

export default function Home() {
  const [account, setAccount] = useState<string>('')
  const [provider, setProvider] = useState<ethers.BrowserProvider | null>(null)
  const [linkBalance, setLinkBalance] = useState<string>('0')
  const [withdrawableBalance, setWithdrawableBalance] = useState<string>('0')
  const [aaveBalance, setAaveBalance] = useState<string>('0')
  const [loading, setLoading] = useState(false)
  const [txHash, setTxHash] = useState<string>('')

  // Form states
  const [lendAmount, setLendAmount] = useState<string>('1000')
  const [lendRate, setLendRate] = useState<string>('500')
  const [lendTerm, setLendTerm] = useState<number>(0)

  const [borrowAmount, setBorrowAmount] = useState<string>('500')
  const [borrowRate, setBorrowRate] = useState<string>('600')
  const [borrowTerm, setBorrowTerm] = useState<number>(0)
  const [borrowCollateral, setBorrowCollateral] = useState<string>('667')

  const [loanId, setLoanId] = useState<string>('0')

  useEffect(() => {
    const initProvider = async () => {
      if (typeof window !== 'undefined') {
        const ethereum = (window as any).ethereum
        if (ethereum) {
          try {
            const prov = new ethers.BrowserProvider(ethereum)
            setProvider(prov)
            console.log('Provider initialized')

            // Listen for account changes
            ethereum.on('accountsChanged', (accounts: string[]) => {
              if (accounts.length > 0) {
                setAccount(accounts[0])
                console.log('Account changed:', accounts[0])
              } else {
                setAccount('')
              }
            })

            // Listen for chain changes
            ethereum.on('chainChanged', () => {
              window.location.reload()
            })
          } catch (error) {
            console.error('Error initializing provider:', error)
          }
        }
      }
    }

    initProvider()
  }, [])

  useEffect(() => {
    if (account && provider) {
      loadBalances()
    }
  }, [account, provider])

  // Calculate collateral automatically (same formula as contract: amount * 10000 / 7500)
  useEffect(() => {
    if (borrowAmount) {
      // Calculate exact required collateral (matching contract logic)
      const amount = parseFloat(borrowAmount)
      const requiredCollateral = (amount * 10000) / 7500
      // Add tiny buffer (0.001 LINK) to ensure we always have enough
      const collateralWithBuffer = requiredCollateral + 0.001
      setBorrowCollateral(collateralWithBuffer.toFixed(4))
    }
  }, [borrowAmount])

  const connectWallet = async () => {
    if (typeof window === 'undefined') {
      alert('Please use a web3-enabled browser!')
      return
    }

    // Detect MetaMask specifically
    const ethereum = (window as any).ethereum

    if (!ethereum) {
      alert('Please install MetaMask!')
      return
    }

    try {
      // Request accounts
      const accounts = await ethereum.request({
        method: 'eth_requestAccounts'
      })

      if (!accounts || accounts.length === 0) {
        alert('No accounts found. Please unlock MetaMask.')
        return
      }

      setAccount(accounts[0])
      console.log('Connected account:', accounts[0])

      // Switch to Sepolia if not already
      const chainId = '0x' + NETWORK.chainId.toString(16)

      try {
        await ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId }],
        })
        console.log('Switched to Sepolia')
      } catch (switchError: any) {
        // This error code indicates that the chain has not been added to MetaMask
        if (switchError.code === 4902) {
          try {
            await ethereum.request({
              method: 'wallet_addEthereumChain',
              params: [{
                chainId,
                chainName: NETWORK.name,
                rpcUrls: [NETWORK.rpcUrl],
                blockExplorerUrls: [NETWORK.blockExplorer],
                nativeCurrency: {
                  name: 'ETH',
                  symbol: 'ETH',
                  decimals: 18,
                },
              }],
            })
            console.log('Added Sepolia network')
          } catch (addError) {
            console.error('Error adding network:', addError)
            alert('Failed to add Sepolia network. Please add it manually.')
          }
        } else {
          console.error('Error switching network:', switchError)
          alert('Failed to switch to Sepolia network.')
        }
      }
    } catch (error: any) {
      console.error('Error connecting wallet:', error)
      alert('Failed to connect wallet: ' + (error.message || 'Unknown error'))
    }
  }

  const loadBalances = async () => {
    if (!provider || !account) return

    try {
      const linkContract = new ethers.Contract(CONTRACTS.LINK_ADDRESS, ERC20_ABI, provider)
      const engineContract = new ethers.Contract(CONTRACTS.ENGINE_ADDRESS, LendingMatchingEngineABI, provider)

      const linkBal = await linkContract.balanceOf(account)
      setLinkBalance(ethers.formatEther(linkBal))

      const withdrawable = await engineContract.getWithdrawableBalance(account)
      setWithdrawableBalance(ethers.formatEther(withdrawable))

      const aaveBal = await engineContract.getAaveBalance()
      setAaveBalance(ethers.formatEther(aaveBal))
    } catch (error) {
      console.error('Error loading balances:', error)
    }
  }

  const depositLender = async () => {
    if (!provider || !account) return
    setLoading(true)
    setTxHash('')

    try {
      const signer = await provider.getSigner()
      const linkContract = new ethers.Contract(CONTRACTS.LINK_ADDRESS, ERC20_ABI, signer)
      const engineContract = new ethers.Contract(CONTRACTS.ENGINE_ADDRESS, LendingMatchingEngineABI, signer)

      const amount = ethers.parseEther(lendAmount)

      // Approve LINK
      const approveTx = await linkContract.approve(CONTRACTS.ENGINE_ADDRESS, amount)
      await approveTx.wait()

      // Deposit
      const depositTx = await engineContract.depositLender(amount, parseInt(lendRate), lendTerm)
      const receipt = await depositTx.wait()

      setTxHash(receipt.hash)
      await loadBalances()
      alert('✅ Lender deposit successful!')
    } catch (error: any) {
      console.error('Error:', error)
      alert('Error: ' + (error.reason || error.message))
    } finally {
      setLoading(false)
    }
  }

  const requestBorrow = async () => {
    if (!provider || !account) return
    setLoading(true)
    setTxHash('')

    try {
      const signer = await provider.getSigner()
      const linkContract = new ethers.Contract(CONTRACTS.LINK_ADDRESS, ERC20_ABI, signer)
      const engineContract = new ethers.Contract(CONTRACTS.ENGINE_ADDRESS, LendingMatchingEngineABI, signer)

      const amount = ethers.parseEther(borrowAmount)
      const collateral = ethers.parseEther(borrowCollateral)

      // Approve collateral
      const approveTx = await linkContract.approve(CONTRACTS.ENGINE_ADDRESS, collateral)
      await approveTx.wait()

      // Request borrow
      const borrowTx = await engineContract.requestBorrow(amount, parseInt(borrowRate), borrowTerm, collateral)
      const receipt = await borrowTx.wait()

      setTxHash(receipt.hash)
      await loadBalances()
      alert('✅ Borrow request successful!')
    } catch (error: any) {
      console.error('Error:', error)
      alert('Error: ' + (error.reason || error.message))
    } finally {
      setLoading(false)
    }
  }

  const matchOrders = async () => {
    if (!provider || !account) return
    setLoading(true)
    setTxHash('')

    try {
      const signer = await provider.getSigner()
      const engineContract = new ethers.Contract(CONTRACTS.ENGINE_ADDRESS, LendingMatchingEngineABI, signer)

      const matchTx = await engineContract.matchOrders(10)
      const receipt = await matchTx.wait()

      setTxHash(receipt.hash)
      await loadBalances()
      alert('✅ Orders matched successfully!')
    } catch (error: any) {
      console.error('Error:', error)
      alert('Error: ' + (error.reason || error.message))
    } finally {
      setLoading(false)
    }
  }

  const repayLoan = async () => {
    if (!provider || !account) return
    setLoading(true)
    setTxHash('')

    try {
      const signer = await provider.getSigner()
      const linkContract = new ethers.Contract(CONTRACTS.LINK_ADDRESS, ERC20_ABI, signer)
      const engineContract = new ethers.Contract(CONTRACTS.ENGINE_ADDRESS, LendingMatchingEngineABI, signer)

      // Approve large amount
      const approveTx = await linkContract.approve(CONTRACTS.ENGINE_ADDRESS, ethers.parseEther('10000'))
      await approveTx.wait()

      // Repay loan
      const repayTx = await engineContract.repayLoan(parseInt(loanId))
      const receipt = await repayTx.wait()

      setTxHash(receipt.hash)
      await loadBalances()
      alert('✅ Loan repaid successfully!')
    } catch (error: any) {
      console.error('Error:', error)
      alert('Error: ' + (error.reason || error.message))
    } finally {
      setLoading(false)
    }
  }

  const withdraw = async () => {
    if (!provider || !account) return
    setLoading(true)
    setTxHash('')

    try {
      const signer = await provider.getSigner()
      const engineContract = new ethers.Contract(CONTRACTS.ENGINE_ADDRESS, LendingMatchingEngineABI, signer)

      const withdrawTx = await engineContract.withdraw()
      const receipt = await withdrawTx.wait()

      setTxHash(receipt.hash)
      await loadBalances()
      alert('✅ Withdrawal successful!')
    } catch (error: any) {
      console.error('Error:', error)
      alert('Error: ' + (error.reason || error.message))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-12 px-4 text-gray-900">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-5xl font-bold text-gray-900 mb-4">
            🏦 P2P Lending Platform
          </h1>
          <p className="text-xl text-gray-600">
            Decentralized peer-to-peer lending with Aave integration on Sepolia
          </p>
        </div>

        {/* Connect Wallet */}
        {!account ? (
          <div className="bg-white rounded-2xl shadow-xl p-8 text-center max-w-md mx-auto">
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Connect Your Wallet</h2>
            <p className="text-gray-600 mb-6">Connect your MetaMask wallet to get started</p>
            <button
              onClick={connectWallet}
              className="w-full bg-indigo-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-indigo-700 transition"
            >
              Connect MetaMask
            </button>
          </div>
        ) : (
          <>
            {/* Balances */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
              <div className="bg-white rounded-xl shadow-lg p-6">
                <div className="text-sm text-gray-600 mb-1">Connected Wallet</div>
                <div className="text-lg font-mono text-gray-900">
                  {account.slice(0, 6)}...{account.slice(-4)}
                </div>
              </div>
              <div className="bg-white rounded-xl shadow-lg p-6">
                <div className="text-sm text-gray-600 mb-1">LINK Balance</div>
                <div className="text-2xl font-bold text-indigo-600">
                  {parseFloat(linkBalance).toFixed(2)} LINK
                </div>
              </div>
              <div className="bg-white rounded-xl shadow-lg p-6">
                <div className="text-sm text-gray-600 mb-1">In Aave</div>
                <div className="text-2xl font-bold text-green-600">
                  {parseFloat(aaveBalance).toFixed(2)} LINK
                </div>
              </div>
              <div className="bg-white rounded-xl shadow-lg p-6">
                <div className="text-sm text-gray-600 mb-1">Withdrawable</div>
                <div className="text-2xl font-bold text-purple-600">
                  {parseFloat(withdrawableBalance).toFixed(2)} LINK
                </div>
              </div>
            </div>

            {/* Main Actions */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
              {/* Lender Section */}
              <div className="bg-white rounded-2xl shadow-xl p-8">
                <h2 className="text-3xl font-bold text-gray-900 mb-6">💰 Lend LINK</h2>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Amount (LINK)
                    </label>
                    <input
                      type="number"
                      value={lendAmount}
                      onChange={(e) => setLendAmount(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                      placeholder="1000"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Minimum APR (bps) - {(parseInt(lendRate) / 100).toFixed(2)}%
                    </label>
                    <input
                      type="number"
                      value={lendRate}
                      onChange={(e) => setLendRate(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                      placeholder="500"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Term
                    </label>
                    <select
                      value={lendTerm}
                      onChange={(e) => setLendTerm(parseInt(e.target.value))}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                    >
                      <option value={0}>7 days</option>
                      <option value={1}>30 days</option>
                      <option value={2}>90 days</option>
                    </select>
                  </div>
                  <button
                    onClick={depositLender}
                    disabled={loading}
                    className="w-full bg-green-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-green-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {loading ? '⏳ Processing...' : '✅ Deposit as Lender'}
                  </button>
                </div>
              </div>

              {/* Borrower Section */}
              <div className="bg-white rounded-2xl shadow-xl p-8">
                <h2 className="text-3xl font-bold text-gray-900 mb-6">💳 Borrow LINK</h2>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Amount (LINK)
                    </label>
                    <input
                      type="number"
                      value={borrowAmount}
                      onChange={(e) => setBorrowAmount(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                      placeholder="500"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Maximum APR (bps) - {(parseInt(borrowRate) / 100).toFixed(2)}%
                    </label>
                    <input
                      type="number"
                      value={borrowRate}
                      onChange={(e) => setBorrowRate(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                      placeholder="600"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Collateral (LINK) - Required for 75% LTV
                    </label>
                    <input
                      type="number"
                      value={borrowCollateral}
                      onChange={(e) => setBorrowCollateral(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent bg-gray-50"
                      placeholder="667"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Term
                    </label>
                    <select
                      value={borrowTerm}
                      onChange={(e) => setBorrowTerm(parseInt(e.target.value))}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                    >
                      <option value={0}>7 days</option>
                      <option value={1}>30 days</option>
                      <option value={2}>90 days</option>
                    </select>
                  </div>
                  <button
                    onClick={requestBorrow}
                    disabled={loading}
                    className="w-full bg-blue-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {loading ? '⏳ Processing...' : '🔒 Request Borrow'}
                  </button>
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
              <div className="bg-white rounded-xl shadow-lg p-6">
                <h3 className="text-xl font-bold text-gray-900 mb-4">🔄 Match Orders</h3>
                <p className="text-sm text-gray-600 mb-4">
                  Match pending lender and borrower orders
                </p>
                <button
                  onClick={matchOrders}
                  disabled={loading}
                  className="w-full bg-indigo-600 text-white py-2 px-4 rounded-lg font-semibold hover:bg-indigo-700 transition disabled:opacity-50"
                >
                  Match Now
                </button>
              </div>

              <div className="bg-white rounded-xl shadow-lg p-6">
                <h3 className="text-xl font-bold text-gray-900 mb-4">💸 Repay Loan</h3>
                <input
                  type="number"
                  value={loanId}
                  onChange={(e) => setLoanId(e.target.value)}
                  placeholder="Loan ID"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg mb-4 focus:ring-2 focus:ring-indigo-500"
                />
                <button
                  onClick={repayLoan}
                  disabled={loading}
                  className="w-full bg-purple-600 text-white py-2 px-4 rounded-lg font-semibold hover:bg-purple-700 transition disabled:opacity-50"
                >
                  Repay Loan
                </button>
              </div>

              <div className="bg-white rounded-xl shadow-lg p-6">
                <h3 className="text-xl font-bold text-gray-900 mb-4">💵 Withdraw</h3>
                <p className="text-sm text-gray-600 mb-4">
                  Withdraw your available balance
                </p>
                <button
                  onClick={withdraw}
                  disabled={loading || parseFloat(withdrawableBalance) === 0}
                  className="w-full bg-green-600 text-white py-2 px-4 rounded-lg font-semibold hover:bg-green-700 transition disabled:opacity-50"
                >
                  Withdraw All
                </button>
              </div>
            </div>

            {/* Transaction Hash */}
            {txHash && (
              <div className="bg-green-50 border border-green-200 rounded-xl p-6 mb-8">
                <h3 className="text-lg font-semibold text-green-900 mb-2">✅ Transaction Successful!</h3>
                <a
                  href={`${NETWORK.blockExplorer}/tx/${txHash}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-green-600 hover:text-green-700 font-mono text-sm break-all"
                >
                  {txHash}
                </a>
              </div>
            )}

            {/* Contract Info */}
            <div className="bg-gray-900 text-white rounded-2xl shadow-xl p-8">
              <h3 className="text-2xl font-bold mb-4">📋 Contract Information</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm font-mono">
                <div>
                  <span className="text-gray-400">Engine:</span>
                  <br />
                  <a
                    href={`${NETWORK.blockExplorer}/address/${CONTRACTS.ENGINE_ADDRESS}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-indigo-400 hover:text-indigo-300"
                  >
                    {CONTRACTS.ENGINE_ADDRESS}
                  </a>
                </div>
                <div>
                  <span className="text-gray-400">LINK Token:</span>
                  <br />
                  <a
                    href={`${NETWORK.blockExplorer}/address/${CONTRACTS.LINK_ADDRESS}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-indigo-400 hover:text-indigo-300"
                  >
                    {CONTRACTS.LINK_ADDRESS}
                  </a>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

declare global {
  interface Window {
    ethereum?: any
  }
}

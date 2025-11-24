# Prediction Market System Documentation

## Overview

This prediction market system is an orderbook-based platform with a sophisticated dual-settlement mechanism that combines primary market liquidity creation (JIT minting) with secondary market trading (token swaps).

### Key Innovations

- **Dual-Settlement Mode**: Automatically switches between JIT minting and token swaps based on participant inventory
- **Just-In-Time Minting**: Creates liquidity on-demand from opposing market views with proportional collateral contributions
- **Token Swaps**: Enables efficient secondary market trading without additional minting
- **Time-Based Epoch Rolling**: Markets advance epochs automatically based on time
- **Professional Market Making**: Supports inventory-based instant fills for retail users
- **Batch Operations**: Gas-efficient multi-market operations
- **Multi-Chain Deployment**: Identical addresses across all supported chains via Create2
- **Upgradeable Architecture**: UUPS proxy pattern for seamless system improvements
- **Flexible Fee System**: Separate trade and claim fees with tiered rates

## Architecture Overview

```
┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ MarketController │────│     Market      │────│ MarketResolver  │
│  (Central Hub)   │    │   (Metadata)    │    │  (Resolution)   │
└─────────┬────────┘    └─────────────────┘    └─────────────────┘
          │
    ┌─────┴─────┐
    │           │
┌───▼───┐   ┌───▼────┐
│ Vault │   │Position│
│       │   │ Tokens │
└───────┘   └────────┘
```

### Core Components

1. **MarketController**: Central orchestrator implementing dual-settlement logic
2. **Market**: Metadata and configuration management with automatic epoch rolling
3. **MarketResolver**: Market resolution with merkle proof verification
4. **PositionTokens**: ERC1155 tokens representing market positions
5. **Vault**: ERC20 collateral management with user-to-user transfers

## Smart Contracts

### MarketController

The central hub that coordinates all market activities with intelligent settlement mode detection.

**Key Features:**
- Automatic JIT minting vs token swap detection
- EIP-712 signed order matching
- Dual fee collection: trade fees (on execution) and claim fees (on payout)
- Trading hours control (global and per-market)
- Batch claims processing
- Emergency resolution capabilities

**Main Functions:**
```solidity
// Order Execution (Auto-detects settlement mode)
executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, fillAmount)
executeSingleOrder(order, signature, fillAmount, counterparty)

// Market Management  
createMarket(questionId, outcomeCount, resolutionTime, epochDuration)
setMarketTradingPaused(questionId, paused)

// Claims
claimWinnings(questionId, epoch, outcome, merkleProof)
batchClaimWinnings(claims[])

// Fee Management
setFeeRate(feeRate)                      // Claim fee rate
setTradeFeeRate(tradeFeeRate)            // Trade fee rate
setUserFeeRate(user, feeRate)            // Custom claim fee
setUserTradeFeeRate(user, tradeFeeRate)  // Custom trade fee
```

### Market

Manages market metadata and timing controls with automatic epoch advancement.

**Key Features:**
- Market lifecycle management
- Automatic time-based epoch rolling
- Manual epoch advancement (legacy mode)
- Time-based or manual resolution
- Condition ID generation

**Main Functions:**
```solidity
// Market Creation
createMarket(questionId, outcomeCount, resolutionTime, epochDuration)
updateResolutionTime(questionId, resolutionTime)
advanceEpoch(questionId)  // Only for manual epoch markets

// State Queries
isMarketOpen(questionId)
isMarketReadyForResolution(questionId)
getCurrentEpoch(questionId)  // Calculates from time for automatic markets
getConditionId(oracle, questionId, numberOfOutcomes, epoch)
getEpochDuration(questionId)
getEpochStartTime(questionId, epoch)
getEpochEndTime(questionId, epoch)
```

### MarketResolver

Handles market resolution using merkle proofs for gas-efficient outcome verification.

**Key Features:**
- Merkle proof-based resolution
- Batch market resolution
- Oracle and emergency resolver support

**Main Functions:**
```solidity
// Resolution
resolveMarketEpoch(questionId, epoch, numberOfOutcomes, merkleRoot)
batchResolveMarkets(questionIds[], epochs[], numberOfOutcomes[], merkleRoots[])

// Verification
verifyProof(conditionId, selectedOutcome, merkleProof)
getResolutionStatus(conditionId)
```

### PositionTokens

ERC1155 tokens representing positions in prediction markets.

**Key Features:**
- Deterministic token ID generation
- Market controller restricted minting/burning
- Standard ERC1155 transfers

**Main Functions:**
```solidity
// Token Operations
mintBatch(to, ids[], amounts[])
burn(from, id, amount)
burnBatch(from, ids[], amounts[])

// Utilities
getTokenId(conditionId, selectedOutcome)
```

### Vault

Manages ERC20 collateral deposits, withdrawals, and market operations.

**Key Features:**
- User deposit/withdrawal system
- Collateral locking for active positions
- User-to-user USDC transfers for token swaps
- Batch operations for efficiency
- Market payout distribution

**Main Functions:**
```solidity
// User Operations
depositCollateral(amount)
withdrawCollateral(amount)

// Market Operations (MarketController only)
lockCollateral(conditionId, user, amount)
unlockCollateral(conditionId, user, amount)
transferBetweenUsers(conditionId, from, to, amount)
batchLockCollateral(conditionIds[], users[], amounts[])
batchUnlockCollateral(conditionIds[], users[], amounts[])

// Queries
getAvailableBalance(user)
getTotalLocked(conditionId)
```

## Trading Mechanisms

### Dual-Settlement System

The system automatically detects the optimal settlement mode based on participant inventory:

#### Mode 1: JIT (Just-In-Time) Minting

**When**: Neither buyer nor seller has existing tokens
**How**: Creates complete set with proportional contributions

```
Alice: "Buy YES at 60%"
Bob:   "Sell YES at 60%"

Contributions:
- Alice pays: $600 (60% of $1000)
- Bob pays:   $400 (40% of $1000)
- Total:      $1000

Trade Fees (1% each):
- Alice fee:  $6 (1% of $600)
- Bob fee:    $4 (1% of $400)
- Total fees: $10 → Treasury

Result:
- Alice receives: 1000 YES tokens
- Bob receives:   1000 NO tokens
- Total locked:   $1000
- Total spent:    $1010 (including fees)
```

**Economic Logic**:
- Each party's contribution matches their implied probability
- Trade fees paid proportionally at execution time
- Total always equals full collateral amount plus fees
- Both parties have "skin in the game"
- Natural liquidity creation from opposing views

#### Mode 2: Token Swaps

**When**: Seller already holds the tokens
**How**: Direct transfer with USDC payment

```
Bob holds: 1000 YES tokens (from previous trade at 50%)
Alice: "Buy YES at 65%"

Execution:
- Bob's 1000 YES tokens burned
- 1000 new YES tokens minted to Alice
- Alice pays $650 to Bob
- Trade fee: $6.50 (1% of $650) → Treasury
- Bob receives: $643.50 net

Result:
- Bob exits position with $643.50 (profit: $143.50)
- Alice enters position with 1000 YES tokens
- Alice paid: $656.50 total (including fee)
- No additional collateral locked
```

**Economic Logic**:
- Secondary market for existing positions
- Trade fee collected from buyer at execution
- Immediate profit realization without waiting for resolution
- No new token creation, just transfer
- More capital efficient

### Settlement Mode Detection

The system automatically determines settlement mode:

```solidity
function _executeTrade(...) internal {
    // Check if seller has existing tokens
    uint256 sellerBalance = positionTokens.balanceOf(sellOrder.user, tokenId);
    
    if (sellerBalance >= fillAmount) {
        // SWAP MODE: Direct token-for-USDC trade
        _executeTokenSwap(...);
    } else {
        // JIT MINTING MODE: Create complete set
        _executeJITMinting(...);
    }
}
```

## Epoch Management

Markets support two epoch modes for different use cases:

### Automatic Time-Based Epochs

Markets automatically advance to new epochs based on time, eliminating the need for manual intervention.

```javascript
// Create daily continuous market (recommended for 24/7 markets)
await marketController.createMarket(
  questionId,
  2,           // binary outcomes
  0,           // resolutionTime=0 (never closes)
  86400        // epochDuration=86400 (24 hours)
);

// Epochs advance automatically:
// Day 1: Epoch 1 (0-24h)
// Day 2: Epoch 2 (24-48h)
// Day 3: Epoch 3 (48-72h)
// ... forever, no transactions needed
```

**Use Cases:**
- Daily price predictions (BTC daily close)
- Weekly sports outcomes
- Hourly volatility markets
- Any continuous market

**Benefits:**
- No cron jobs required
- No gas costs for epoch advancement
- Markets never break from missed transactions
- Simpler backend infrastructure

### Manual Epoch Mode

For markets requiring explicit control over epoch transitions.

```javascript
// Create manual epoch market
await marketController.createMarket(
  questionId,
  2,    // binary outcomes
  0,    // manual resolution
  0     // epochDuration=0 (manual mode)
);

// Manually advance when ready
await marketController.advanceMarketEpoch(questionId);
```

**Use Cases:**
- Event-based markets (match outcomes)
- Markets with irregular timing
- Legacy compatibility

### Querying Epoch Information

```javascript
// Get current epoch (calculated from time or manual)
const currentEpoch = await market.getCurrentEpoch(questionId);

// Get epoch duration (0 = manual, >0 = automatic)
const duration = await market.getEpochDuration(questionId);

// Get epoch time boundaries (for time-based markets)
const startTime = await market.getEpochStartTime(questionId, epochNumber);
const endTime = await market.getEpochEndTime(questionId, epochNumber);
```

## Trading Flow

### 1. Market Creation

Markets are created with specific parameters:

```javascript
// Continuous daily market (time-based epochs)
await marketController.createMarket(
  questionId,
  2,      // binary outcomes
  0,      // resolutionTime=0 (never closes)
  86400   // epochDuration=86400 (daily epochs)
);

// Weekly continuous market
await marketController.createMarket(
  questionId,
  2,      // binary outcomes
  0,      // never closes
  604800  // 7 days
);

// Manual epoch market (legacy)
await marketController.createMarket(
  questionId,
  2,    // binary outcomes
  0,    // manual resolution
  0     // manual epochs
);

// One-time event with auto-close
await marketController.createMarket(
  questionId,
  4,                  // 4 possible outcomes
  futureTimestamp,    // closes at this time
  0                   // no epochs
);
```

### 2. Order Placement & Matching

Users create EIP-712 signed orders for secure off-chain order books:

```javascript
// Create order structure
const order = {
  user: userAddress,
  questionId: questionId,
  outcome: 1,  // YES outcome
  amount: ethers.parseEther("1000"),
  price: 6000,  // 60% in basis points
  nonce: 1,
  expiration: Math.floor(Date.now() / 1000) + 3600,
  isBuyOrder: true
};

// Sign with EIP-712
const signature = await signer.signTypedData(domain, types, order);

// Backend executes match
await marketController.executeOrderMatch(
  buyOrder, sellOrder, 
  buySignature, sellSignature,
  fillAmount
);
```

### 3. Settlement Execution

**Scenario A: JIT Minting**

When Alice (buyer) and Bob (seller) match at 60%:

```javascript
// System automatically detects Bob has no tokens
// Executes JIT minting:

// 1. Lock proportional collateral
vault.lockCollateral(conditionId, alice, 600);  // 60%
vault.lockCollateral(conditionId, bob, 400);    // 40%

// 2. Collect trade fees from both parties
vault.transferBetweenUsers(conditionId, alice, treasury, 6);   // 1% of 600
vault.transferBetweenUsers(conditionId, bob, treasury, 4);     // 1% of 400

// 3. Mint complete set
positionTokens.mintBatch(alice, [yesTokenId], [1000]);
positionTokens.mintBatch(bob, [noTokenId], [1000]);
```

**Scenario B: Token Swap**

When Bob already holds tokens:

```javascript
// System detects Bob has 1000 YES tokens
// Executes token swap:

// 1. Burn Bob's tokens and mint to Alice
positionTokens.burn(bob, yesTokenId, 1000);
positionTokens.mintBatch(alice, [yesTokenId], [1000]);

// 2. Calculate payment and trade fee
const payment = 600;          // 60% of 1000
const tradeFee = 6;           // 1% of 600
const netPayment = 594;       // Payment minus fee

// 3. Transfer USDC
vault.transferBetweenUsers(conditionId, alice, treasury, tradeFee);
vault.transferBetweenUsers(conditionId, alice, bob, netPayment);
```

### 4. Market Maker Liquidity

Professional market makers provide instant fills:

```javascript
// Market maker pre-mints inventory
await marketController.executeOrderMatch(
  matcherBuyOrder,  // Matcher buys at 50%
  userSellOrder,    // User sells at 50%
  ...
);
// Matcher now has 10,000 YES tokens in inventory

// User gets instant fill
await marketController.executeSingleOrder(
  userBuyOrder,     // User buys at 62%
  signature,
  1000,
  matcherAddress    // Matcher sells from inventory
);
// User pays 1% trade fee on $620 = $6.20
// Matcher earns 12% spread (50% → 62%) minus user's trade fee
```

### 5. Market Resolution

Markets resolve via merkle proofs:

```javascript
// For time-based markets, resolve completed epochs
const currentEpoch = await market.getCurrentEpoch(questionId);
const lastCompletedEpoch = currentEpoch - 1;

// Oracle resolves the last completed epoch
const winningOutcome = 1;  // YES wins
const leaf = ethers.keccak256(
  ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [winningOutcome])
);
const merkleRoot = leaf;

await marketResolver.resolveMarketEpoch(
  questionId,
  lastCompletedEpoch,  // Resolve yesterday's epoch
  numberOfOutcomes,
  merkleRoot
);

// Market continues trading on current epoch
// No epoch advancement needed
```

### 6. Claims Processing

Winners claim payouts with merkle proofs and pay claim fees:

```javascript
// Single claim
const proof = [];  // Empty for single leaf
const payout = await marketController.claimWinnings(
  questionId,
  epoch, 
  winningOutcome,
  proof
);
// Claim fee (e.g., 4%) deducted from payout

// Batch claims (gas efficient)
const claims = [
  { questionId: id1, epoch: 1, outcome: 1, merkleProof: proof1 },
  { questionId: id2, epoch: 1, outcome: 2, merkleProof: proof2 }
];
const totalPayout = await marketController.batchClaimWinnings(claims);
// Claim fees deducted from each winning claim
```

## Complete User Journeys

### Example 1: P2P Trade with JIT Minting (Including All Fees)

**Alice's Journey:**
1. Deposits $10,000 USDC to vault
2. Creates "Buy YES at 65%" order for 1000 tokens
3. Signs order with MetaMask
4. Backend matches with Bob's "Sell YES at 62%" order
5. **Trade executes at 62%:**
   - Alice's contribution: $620 (62% of $1000)
   - Alice's trade fee: $6.20 (1% of $620)
   - **Alice pays total: $626.20**
6. Alice receives 1000 YES tokens
7. Market resolves: YES wins
8. Alice claims $1000 with 4% claim fee = $40
9. **Alice receives: $960**
10. **Net profit: $960 - $626.20 = $333.80**

**Bob's Journey:**
1. Deposits $10,000 USDC to vault
2. Creates "Sell YES at 62%" order (implicitly: buy NO at 38%)
3. Signs order
4. Gets matched with Alice
5. **Trade executes at 62%:**
   - Bob's contribution: $380 (38% of $1000)
   - Bob's trade fee: $3.80 (1% of $380)
   - **Bob pays total: $383.80**
6. Bob receives 1000 NO tokens
7. Market resolves: YES wins (Bob loses)
8. Bob's tokens worthless
9. **Net loss: $383.80**

**Total System Check:**
- Collateral locked: $620 + $380 = $1000 ✓
- Trade fees collected: $6.20 + $3.80 = $10 ✓
- Claim fee collected: $40 ✓
- Total fees: $50 ✓
- Alice profit + Bob loss: $333.80 + $383.80 = $717.60
- Total fees: $50
- Alice net + fees: $333.80 + $50 = $383.80 = Bob's loss ✓

### Example 2: Secondary Market Exit (Token Swap with Fees)

**Bob Changes Mind:**
1. Bob holds 1000 YES tokens (bought at 50% = $500 + $5 trade fee)
2. Price moves to 70%
3. Bob creates "Sell YES at 68%" order
4. Charlie creates "Buy YES at 70%" order
5. Orders match at 68%
6. **Bob's tokens burned, new tokens minted to Charlie**
7. **Charlie pays $680:**
   - Trade fee: $6.80 (1% of $680)
   - Net to Bob: $673.20
8. **Bob's realized profit: $673.20 - $505 = $168.20**
9. No waiting for market resolution
10. No claim fees (Bob exited before resolution)

**Key Insight:**
- Bob exits early with locked-in profit
- Trade fee paid by Charlie (buyer) at execution
- Bob avoids claim fee by exiting early
- Charlie now holds position that could win $1000 (minus 4% claim fee)

### Example 3: Instant Fill via Market Maker (With All Fees)

**Alice Wants Speed:**
1. Alice sees BTC market, wants instant entry
2. Requests "Buy YES at 65%" with instant fill
3. Backend routes to market maker with inventory
4. Market maker's YES tokens burned → minted to Alice
5. **Alice pays $650:**
   - Trade fee: $6.50 (1% of $650)
   - Net to market maker: $643.50
6. **Trade executes in single transaction**
7. Market maker earned:
   - Bought at 50% = $500 cost (+ $5 trade fee when acquired)
   - Sold at 65% = $643.50 received
   - Gross profit: $138.50 (27.7% return)

**Why This Matters:**
- No waiting for opposing orders
- Better user experience
- Market makers provide consistent liquidity
- Trade fees collected at execution, claim fees at resolution
- Competing with centralized platforms requires this

## Fee System

The system implements two distinct fee types collected at different stages:

### Fee Types

1. **Trade Fees** (Collected at execution time)
   - Applied when orders are matched
   - Paid by buyers in both JIT minting and token swap modes
   - In JIT minting: both parties pay proportionally
   - Default: 1% (100 basis points)
   - Custom rates available for market makers: 0.25-0.5%

2. **Claim Fees** (Collected at payout time)
   - Applied when winners claim payouts
   - Deducted from winning token redemptions
   - Default: 4% (400 basis points)
   - Custom rates available for whales: 1-2%

### Fee Collection

**Trade Fee Collection:**
```javascript
// Token Swap Example (buyer pays)
const payment = 600;           // 60% of 1000 tokens
const tradeFeeRate = 100;      // 1%
const tradeFee = 6;            // 1% of 600
const netPayment = 594;        // Payment minus trade fee

// JIT Minting Example (both parties pay proportionally)
const aliceContribution = 600;  // 60%
const bobContribution = 400;    // 40%
const aliceTradeFee = 6;        // 1% of 600
const bobTradeFee = 4;          // 1% of 400
```

**Claim Fee Collection:**
```javascript
// Gross payout: 1000 tokens worth $1000
// Claim fee rate: 4% (400 basis points)
// Fee amount: $1000 * 400 / 10000 = $40
// Net payout: $1000 - $40 = $960

// User receives $960
// Treasury receives $40
```

### Fee Configuration

```javascript
// Set trade fee rates
await marketController.setTradeFeeRate(100);  // 1% default trade fee

// Set claim fee rates
await marketController.setFeeRate(400);  // 4% default claim fee

// Set treasury address (receives all fees)
await marketController.setTreasury(treasuryAddress);

// Set custom trade fee for market maker (0.25%)
await marketController.setUserTradeFeeRate(marketMakerAddress, 25);

// Set custom claim fee for whale (2%)
await marketController.setUserFeeRate(whaleAddress, 200);
```

### Multi-Tier Example

```javascript
// Regular User
- Trade fee: 1% (on execution)
- Claim fee: 4% (on payout)
- Total max fees: 5%

// Market Maker
- Trade fee: 0.25% (on execution)
- Claim fee: 1% (on payout)
- Total max fees: 1.25%

// Whale Trader
- Trade fee: 0.5% (on execution)
- Claim fee: 2% (on payout)
- Total max fees: 2.5%
```

## Trading Hours Control

Flexible trading controls for different market types:

### Global Controls
```javascript
// Emergency stop - pauses all trading
await marketController.setGlobalTradingPaused(true);

// Resume all trading
await marketController.setGlobalTradingPaused(false);
```

### Market-Specific Controls
```javascript
// Pause specific market (e.g., outside trading hours)
await marketController.setMarketTradingPaused(questionId, true);

// Batch pause multiple markets
await marketController.batchSetMarketTradingPaused(
  [stockMarket1, stockMarket2, stockMarket3], 
  true  // Pause during market close
);

// Resume trading for stock markets
await marketController.batchSetMarketTradingPaused(
  [stockMarket1, stockMarket2, stockMarket3], 
  false  // Resume during market hours
);
```

### Priority System
- Global pause overrides all market-specific settings
- Market-specific pause only affects that market
- Both global AND market must be active for trading

### Important Note
Claims are always allowed regardless of trading hours. Users can claim winnings even when trading is paused.

## Multi-Chain Deployment

The system uses Create2 for identical addresses across all chains.

### Supported Networks

- Ethereum (Mainnet & Sepolia)
- Arbitrum (One & Sepolia)  
- BSC (Mainnet & Testnet)
- Sonic (Mainnet & Testnet)
- Polygon, Base, Optimism (ready)

### Deployment Process

```bash
# Predict addresses (same on all chains)
make predict-addresses

# Deploy to testnet
make deploy-sepolia

# Deploy to additional chains (identical addresses)
make deploy-arbitrum-sepolia
make deploy-bsc-testnet

# Verify address consistency
make verify-addresses
```

## Integration Guide

### Frontend Integration

#### 1. Contract Setup

```javascript
import { ethers } from 'ethers';

// Universal addresses (same on all chains)
const ADDRESSES = {
  MARKET_CONTROLLER: '0x...',
  VAULT: '0x...',
  POSITION_TOKENS: '0x...',
  MARKET: '0x...',
  MARKET_RESOLVER: '0x...'
};

const marketController = new ethers.Contract(
  ADDRESSES.MARKET_CONTROLLER,
  MarketControllerABI,
  signer
);
```

#### 2. Market Data Fetching

```javascript
// Get market info
const outcomeCount = await market.getOutcomeCount(questionId);
const currentEpoch = await market.getCurrentEpoch(questionId);
const epochDuration = await market.getEpochDuration(questionId);
const isOpen = await market.isMarketOpen(questionId);
const isTradingActive = await marketController.isTradingActive(questionId);

// Check market type
if (epochDuration > 0) {
  // Time-based market - epochs advance automatically
  const epochStartTime = await market.getEpochStartTime(questionId, currentEpoch);
  const epochEndTime = await market.getEpochEndTime(questionId, currentEpoch);
  console.log(`Current epoch ${currentEpoch} ends at ${new Date(epochEndTime * 1000)}`);
} else {
  // Manual epoch market
  console.log(`Manual epoch market at epoch ${currentEpoch}`);
}

// Get user positions
const conditionId = await market.getConditionId(
  oracle, questionId, outcomeCount, 0  // 0 = current epoch
);
const yesTokenId = await positionTokens.getTokenId(conditionId, 1);
const userBalance = await positionTokens.balanceOf(user, yesTokenId);

// Check if user can sell (has inventory)
const canSellDirectly = userBalance >= desiredSellAmount;

// Get fee information
const tradeFeeRate = await marketController.tradeFeeRate();
const claimFeeRate = await marketController.feeRate();
const userTradeFeeRate = await marketController.getEffectiveTradeFeeRate(user);
const userClaimFeeRate = await marketController.getEffectiveFeeRate(user);
```

#### 3. Order Creation & Signing

```javascript
// EIP-712 setup
const domain = {
  name: 'PredictionMarketOrders',
  version: '1',
  chainId: await signer.getChainId(),
  verifyingContract: marketController.address
};

const types = {
  Order: [
    { name: 'user', type: 'address' },
    { name: 'questionId', type: 'bytes32' },
    { name: 'outcome', type: 'uint256' },
    { name: 'amount', type: 'uint256' },
    { name: 'price', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'expiration', type: 'uint256' },
    { name: 'isBuyOrder', type: 'bool' }
  ]
};

// Create buy order
const buyOrder = {
  user: await signer.getAddress(),
  questionId: questionId,
  outcome: 1,  // YES
  amount: ethers.parseEther("1000"),
  price: 6000,  // 60%
  nonce: 1,
  expiration: Math.floor(Date.now() / 1000) + 3600,
  isBuyOrder: true
};

// Sign order
const signature = await signer.signTypedData(domain, types, buyOrder);
```

#### 4. Understanding Settlement Modes and Fees

```javascript
// For UI display: Show expected settlement mode and all fees
async function predictSettlementAndFees(sellOrder, userAddress) {
  const tokenId = await positionTokens.getTokenId(conditionId, sellOrder.outcome);
  const sellerBalance = await positionTokens.balanceOf(sellOrder.user, tokenId);
  
  // Get user's fee rates
  const tradeFeeRate = await marketController.getEffectiveTradeFeeRate(userAddress);
  const claimFeeRate = await marketController.getEffectiveFeeRate(userAddress);
  
  const buyerPayment = (sellOrder.amount * sellOrder.price) / 10000;
  const tradeFee = (buyerPayment * tradeFeeRate) / 10000;
  
  if (sellerBalance >= sellOrder.amount) {
    return {
      mode: 'TOKEN_SWAP',
      description: 'Seller has tokens - Direct transfer',
      buyerPays: buyerPayment + tradeFee,
      buyerTradeFee: tradeFee,
      sellerReceives: buyerPayment,
      newCollateralLocked: 0,
      potentialClaimFee: (sellOrder.amount * claimFeeRate) / 10000,  // If buyer wins
      totalFeesIfWin: tradeFee + ((sellOrder.amount * claimFeeRate) / 10000)
    };
  } else {
    const sellerPayment = sellOrder.amount - buyerPayment;
    const sellerTradeFee = (sellerPayment * tradeFeeRate) / 10000;
    
    return {
      mode: 'JIT_MINTING',
      description: 'Creating new position - Both contribute',
      buyerPays: buyerPayment + tradeFee,
      buyerTradeFee: tradeFee,
      sellerPays: sellerPayment + sellerTradeFee,
      sellerTradeFee: sellerTradeFee,
      newCollateralLocked: sellOrder.amount,
      potentialClaimFee: (sellOrder.amount * claimFeeRate) / 10000,  // If buyer wins
      totalFeesIfWin: tradeFee + ((sellOrder.amount * claimFeeRate) / 10000)
    };
  }
}

// Display in UI
const feeInfo = await predictSettlementAndFees(order, userAddress);
console.log(`Settlement Mode: ${feeInfo.mode}`);
console.log(`Trade Fee: ${ethers.formatEther(feeInfo.buyerTradeFee)} USDC`);
console.log(`Potential Claim Fee: ${ethers.formatEther(feeInfo.potentialClaimFee)} USDC`);
console.log(`Total if you win: ${ethers.formatEther(feeInfo.totalFeesIfWin)} USDC in fees`);
```

#### 5. User Balance Management

```javascript
// Check user's available collateral
const availableBalance = await vault.getAvailableBalance(userAddress);
const requiredForTrade = (orderAmount * orderPrice) / 10000;

// Get user's trade fee rate
const tradeFeeRate = await marketController.getEffectiveTradeFeeRate(userAddress);
const tradeFee = (requiredForTrade * tradeFeeRate) / 10000;
const totalRequired = requiredForTrade + tradeFee;

if (availableBalance < totalRequired) {
  // Show deposit prompt
  const shortfall = totalRequired - availableBalance;
  alert(`Please deposit ${ethers.formatEther(shortfall)} USDC (includes ${ethers.formatEther(tradeFee)} trade fee)`);
}

// Deposit collateral
await collateralToken.approve(vault.address, amount);
await vault.depositCollateral(amount);

// Withdraw collateral (only available balance, not locked)
await vault.withdrawCollateral(amount);
```

### Backend Integration

#### 1. Order Matching Engine

```javascript
// Basic order matching logic
async function matchOrders() {
  const buyOrders = await getOpenBuyOrders();
  const sellOrders = await getOpenSellOrders();
  
  for (const buy of buyOrders) {
    for (const sell of sellOrders) {
      // Check if orders can match
      if (
        buy.questionId === sell.questionId &&
        buy.outcome === sell.outcome &&
        buy.price >= sell.price &&
        !buy.isBuyOrder === sell.isBuyOrder
      ) {
        // Calculate fill amount
        const fillAmount = Math.min(
          buy.amount - buy.filled,
          sell.amount - sell.filled
        );
        
        // Execute match at seller's price (better for buyer)
        await marketController.executeOrderMatch(
          buy,
          sell,
          buy.signature,
          sell.signature,
          fillAmount
        );
        
        // Update order book
        await updateOrderFills(buy.hash, sell.hash, fillAmount);
      }
    }
  }
}
```

#### 2. Market Resolution Cron (Simplified for Time-Based Markets)

```javascript
// Resolution cron for time-based markets
async function resolveCompletedEpochs() {
  const markets = await getActiveMarkets();
  
  for (const market of markets) {
    const epochDuration = await marketContract.getEpochDuration(market.questionId);
    
    // Skip manual epoch markets
    if (epochDuration === 0n) continue;
    
    const currentEpoch = await marketContract.getCurrentEpoch(market.questionId);
    const lastCompletedEpoch = currentEpoch - 1n;
    
    // Check if epoch is already resolved
    const conditionId = await marketContract.getConditionId(
      oracle,
      market.questionId,
      market.outcomeCount,
      lastCompletedEpoch
    );
    
    const isResolved = await marketResolver.getResolutionStatus(conditionId);
    
    if (!isResolved && lastCompletedEpoch > 0n) {
      // Fetch result for completed epoch
      const result = await getMarketResult(market.questionId, lastCompletedEpoch);
      
      // Resolve the epoch
      await marketResolver.resolveMarketEpoch(
        market.questionId,
        lastCompletedEpoch,
        market.outcomeCount,
        result.merkleRoot
      );
      
      console.log(`Resolved ${market.name} epoch ${lastCompletedEpoch}`);
    }
    
    // No epoch advancement needed - it's automatic!
  }
}

// Run every hour
setInterval(resolveCompletedEpochs, 3600000);
```

#### 3. Market Maker Bot

```javascript
// Professional market making strategy
class MarketMaker {
  async maintainInventory(questionId, targetInventory) {
    // Get current inventory
    const yesBalance = await this.getYesTokens(questionId);
    const noBalance = await this.getNoTokens(questionId);
    
    // Rebalance if needed
    if (yesBalance < targetInventory) {
      await this.mintInventory(questionId, 'YES', targetInventory - yesBalance);
    }
    if (noBalance < targetInventory) {
      await this.mintInventory(questionId, 'NO', targetInventory - noBalance);
    }
  }
  
  async mintInventory(questionId, outcome, amount) {
    // Create matching orders to mint complete set
    const matcherBuy = createOrder({
      user: this.address,
      outcome: outcome === 'YES' ? 1 : 2,
      amount: amount,
      price: 5000,  // Mint at 50%
      isBuyOrder: true
    });
    
    const counterpartySell = await this.findCounterparty(matcherBuy);
    
    await marketController.executeOrderMatch(
      matcherBuy,
      counterpartySell,
      await this.signOrder(matcherBuy),
      counterpartySell.signature,
      amount
    );
  }
  
  async provideLiquidity(questionId) {
    // Quote both sides with spread
    const midPrice = await this.calculateFairPrice(questionId);
    const spread = 0.04;  // 4% spread
    
    // Account for trade fees in spread
    const tradeFeeRate = await marketController.getEffectiveTradeFeeRate(this.address);
    const effectiveSpread = spread + (tradeFeeRate / 10000) * 2;  // Account for both sides
    
    await this.postOrders([
      {
        side: 'BUY',
        price: midPrice - (effectiveSpread / 2),
        amount: this.maxPositionSize
      },
      {
        side: 'SELL', 
        price: midPrice + (effectiveSpread / 2),
        amount: this.maxPositionSize
      }
    ]);
  }
}
```

#### 4. The Graph Integration

```javascript
// Query user's trading history with fee tracking
const USER_TRADES_QUERY = `
  query GetUserTrades($userAddress: ID!) {
    user(id: $userAddress) {
      totalBets
      totalBetAmount
      totalClaimed
      
      bets(orderBy: createdAt, orderDirection: desc, first: 50) {
        orderHash
        outcome
        fillAmount
        price
        isBuyOrder
        settlementMode  // 'JIT_MINTING' or 'TOKEN_SWAP'
        market {
          questionId
        }
        createdAt
      }
      
      tokenBalances(where: { balance_gt: "0" }) {
        balance
        token {
          outcome
          market {
            questionId
          }
        }
      }
    }
  }
`;

// Query market liquidity depth with fee info
const MARKET_DEPTH_QUERY = `
  query GetMarketDepth($questionId: ID!) {
    market(id: $questionId) {
      questionId
      totalVolume
      totalTradeFees
      totalClaimFees
      epochDuration
      currentEpoch
      defaultTradeFeeRate
      defaultClaimFeeRate
      
      # Get recent settlement modes distribution
      rounds(first: 1, orderBy: epoch, orderDirection: desc) {
        bets(first: 100) {
          settlementMode
          fillAmount
          tradeFeeAmount
        }
      }
    }
  }
`;
```

## Testing

The system includes comprehensive test coverage:

### Test Suites

1. **Integration Tests** (`Integration.t.sol`)
   - Full lifecycle: Creation → Trading → Resolution → Claims
   - JIT minting with proportional contributions
   - Token swaps for secondary market
   - Fee collection (both trade and claim)
   - Batch operations

2. **Settlement Modes** (`SettlementModes.t.sol`)
   - JIT minting at various prices (40%, 60%, 80%)
   - Token swap verification
   - Partial fills for both modes
   - Insufficient balance edge cases
   - Single order execution with mode detection

3. **Fee System** (`Fee.t.sol`)
   - Trade fees in token swaps
   - Trade fees in JIT minting
   - Claim fees on payouts
   - Custom user rates for both fee types
   - Multi-tier fee structures
   - Batch claim fee collection
   - Zero fee scenarios
   - Full lifecycle with both fee types

4. **Time-Based Epochs** (`TimeBasedEpochs.t.sol`)
   - Automatic epoch advancement
   - Daily, weekly, hourly markets
   - Epoch boundary precision
   - Trading across epochs
   - Resolution of past epochs
   - Manual vs automatic mode

5. **Trading Hours** (`TradingHours.t.sol`)
   - Global pause enforcement
   - Per-market pause
   - Batch pause operations
   - Claims work during pause

6. **Unit Tests**
   - Market metadata management
   - Token minting/burning
   - Vault collateral operations
   - Resolution and proof verification

### Running Tests

```bash
# Run all tests
forge test

# Run specific suite
forge test --match-contract FeeTest -vv

# Run with gas reporting
forge test --gas-report

# Run specific test with detailed trace
forge test --match-test test_TokenSwap_WithTradeFees -vvvv
```

## Security Considerations

### Settlement Mode Security

1. **Balance Checks**: System verifies seller has tokens before attempting swap
2. **Atomic Operations**: Burn and mint happen in single transaction
3. **No Double-Spend**: Each token can only be swapped once
4. **Fair Pricing**: Proportional contributions prevent arbitrage
5. **Fee Protection**: Trade fees collected before any transfers

### Access Controls

1. **Owner Functions**: Market creation, fee rates, trading hours
2. **Authorized Matchers**: Order execution, market management, fee configuration
3. **Oracle Functions**: Market resolution  
4. **User Functions**: Order signing, claims, transfers

### Key Security Features

1. **EIP-712 Signatures**: Prevents replay attacks
2. **Nonce Management**: Each nonce used only once per user
3. **Merkle Proofs**: Gas-efficient outcome verification
4. **Reentrancy Guards**: Protect against reentrancy
5. **Input Validation**: Comprehensive parameter checking
6. **Upgrade Controls**: Only owner can authorize upgrades
7. **Fee Validation**: Maximum fee caps (10% for both types)

## Economic Model

### Primary Market (JIT Minting)

Creates new liquidity from opposing market views:

```
Market: "Will BTC hit $100k by EOY?"

Participant A believes: 70% chance YES
Participant B believes: 30% chance YES

They can transact at any price between 30% and 70%
System mints complete set when they agree on price
Both pay proportional trade fees (1% each)
Both have proportional exposure to their belief
```

### Secondary Market (Token Swaps)

Allows position exits before resolution:

```
Trader bought YES at 50% ($500 + $5 trade fee)
Market moves to 70% (positive for trader)
Trader wants to lock in profit

Sells YES at 68% (buyer pays $6.80 trade fee)
Trader receives $680 net
Realized profit: $175.20 (35% return including fees)
No waiting for market resolution
No claim fee (exited before resolution)
```

### Market Maker Economics

Professional liquidity providers:

```
Market maker strategy:
- Maintains inventory of both YES and NO tokens
- Buys at 58%, sells at 62% (4% spread)
- Pays 0.25% trade fee (preferential rate)
- Earns spread on every trade
- Takes on inventory risk

Example:
- Pre-mint 10,000 YES tokens at 50% ($5,000 cost + $12.50 fee)
- Sell to users at 62% over time ($6,200 revenue)
- Users pay 1% trade fee ($62 to treasury)
- Market maker gross profit: $1,187.50 (23.6% return)
```
```

## Troubleshooting

### Common Issues

1. **"Matcher insufficient inventory"**
   - Market maker doesn't have required tokens
   - Solution: Use executeOrderMatch for P2P, or market maker needs to mint inventory

2. **"Market is closed for betting"**
   - Resolution time has passed (for time-based close markets)
   - Solution: Update resolutionTime to 0 for continuous markets, or create with epochDuration > 0

3. **"Cannot manually advance time-based epochs"**
   - Trying to call advanceEpoch on automatic market
   - Solution: Not needed! Epochs advance automatically based on time

4. **"Nonce already used"** 
   - Order already executed or cancelled
   - Solution: Increment nonce for new orders

5. **"Insufficient balance"**
   - User doesn't have enough available collateral
   - For JIT minting: Need full proportional amount plus trade fee
   - For swaps: Buyer needs purchase price plus trade fee
   - Solution: Deposit more collateral

6. **"Invalid proof"**
   - Merkle proof doesn't match resolution
   - Solution: Get correct proof from resolution data

7. **Trade fee higher than expected**
   - User may not be using custom fee tier
   - Solution: Check getEffectiveTradeFeeRate() and contact admin for tier adjustment

## API Reference

### MarketController Events

```solidity
event OrderFilled(
  bytes32 indexed orderHash,
  address indexed user,
  bytes32 indexed questionId,
  uint256 outcome,
  uint256 fillAmount,
  uint256 price,
  bool isBuyOrder,
  uint256 epoch,
  address taker
);

event TradeFeeCollected(
  address indexed user,
  bytes32 indexed questionId,
  uint256 feeAmount,
  uint256 netAmount
);

event CollateralTransferred(
  bytes32 indexed conditionId,
  address indexed from,
  address indexed to,
  uint256 amount
);

event CollateralLocked(
  bytes32 indexed conditionId,
  address indexed user,
  uint256 amount
);

event WinningsClaimed(
  address indexed user,
  bytes32 indexed questionId,
  uint256 epoch,
  uint256 outcome,
  uint256 payout
);

event FeeCollected(
  address indexed user,
  bytes32 indexed questionId,
  uint256 feeAmount,
  uint256 netPayout
);

event TradeFeeRateUpdated(
  uint256 oldRate,
  uint256 newRate
);

event UserTradeFeeRateSet(
  address indexed user,
  uint256 feeRate
);
```

### Error Codes

```solidity
// Settlement Errors
"Matcher insufficient inventory"  // Market maker needs tokens
"Insufficient tokens"             // User trying to sell without tokens
"Insufficient balance"            // Not enough available collateral (including fees)

// Trading Restrictions
"Market is closed for betting"
"Global trading paused" 
"Market trading paused"

// Order Validation  
"Order expired"
"Nonce already used"
"Invalid signature"
"Price mismatch"
"Order overfilled"

// Market Operations
"Market does not exist"
"Market not resolved"
"Invalid proof"
"No tokens to claim"

// Fee Management
"Fee rate exceeds maximum"        // Max 10% for both fee types

// Epoch Management
"Cannot manually advance time-based epochs"  // Trying to advance automatic market
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

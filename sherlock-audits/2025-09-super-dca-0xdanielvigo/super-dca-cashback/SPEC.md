# Super DCA Cashback

Super DCA Cashback is a program that allows traders to claim cashback on their trades over time-based epochs. The contract operates with a single campaign configuration set at deployment, dividing time into fixed-duration epochs. Users can claim rewards for each epoch their trades meet eligibility criteria.

The campaign is configured with parameters like:
- Cashback percentage (in basis points)
- Epoch duration (e.g., 30 days)
- Flow rate bounds (minimum and maximum monthly amounts)
- Campaign start time

All cashback is delivered as USDC on trades that use USDC.

## How it works
- Start a trade on Super DCA (https://superdca.org) with flow rates within the configured range
- Keep your trade running through complete epochs
- Claim your cashback for each completed epoch your trade was eligible
- Continue earning rewards for additional epochs as long as your trade remains active

## Contract Specifications

### Constants
- `USDC` - The USDC token that is used for cashback payments
- `superDCATrade` - The SuperDCATrade contract (`ISuperDCATrade`)
- `ADMIN_ROLE` - Role identifier for administrative functions

### Structs
- `CashbackClaim` - Single campaign configuration
    - `cashbackBips` - Cashback percentage in basis points (e.g., 25 = 0.25%)
    - `duration` - Epoch duration in seconds
    - `minRate` - Minimum flow rate for eligibility (int96)
    - `maxRate` - Maximum flow rate for eligibility (uint256)
    - `startTime` - Start time of epoch 0
    - `timestamp` - When the campaign was configured

### State Variables
- `cashbackClaim` - Single campaign configuration struct
- `claimedTrades mapping(uint256 tradeId => mapping(uint256 epochId => bool claimed))` - Mapping of tradeId to epochIds that have been claimed

### Events
- `CashbackClaimed(address indexed user, uint256 indexed tradeId, uint256 indexed epochId, uint256 amount)` - Emitted when cashback is claimed for an epoch
- `TokensWithdrawn(address indexed token, address indexed to, uint256 amount)` - Emitted when admin withdraws tokens

### Errors
- `InvalidParams(uint256 paramIndex)` - Emitted when a parameter is invalid during deployment
- `NotClaimable()` - Emitted when a claim is not claimable
- `NotAuthorized()` - Emitted when a user is not authorized to claim cashback

### Constructor
- `constructor(address _usdc, address _superDCATrade, address _admin, CashbackClaim memory _cashbackClaim)`
    - Args
        - `_usdc` - The USDC token contract address
        - `_superDCATrade` - The SuperDCATrade contract address
        - `_admin` - Initial admin address (receives DEFAULT_ADMIN_ROLE and ADMIN_ROLE)
        - `_cashbackClaim` - Campaign configuration struct
    - Validation
        - `cashbackBips` must be ≤ 10,000 (100%)
        - `maxRate` must be ≤ type(int96).max
        - `minRate` must be < `maxRate`
        - `duration` must be > 0
    - Post
        - Campaign configuration is stored
        - Admin roles are granted
        - Contract is ready for epoch-based claiming

### Mutating Functions
- **Note:** There is no deposit function. Transfer USDC to the contract to fund cashback payments.

- `claimCashback(uint256 tradeId, uint256 epochId)` - Claim cashback for a trade for a specific epoch
    - Args
        - `tradeId` - The tradeId to claim cashback for
        - `epochId` - The epoch ID to claim cashback for
    - Pre
        - `tradeId` must be a valid tradeId for `SuperDCATrade` contract
        - Caller must own the trade (ERC-721 ownership)
        - Epoch must have completed
        - Trade must have been eligible for the entire epoch duration
        - Trade must not have already claimed this epoch
    - Post
        - `claimedTrades[tradeId][epochId]` is set to true
        - Calculated cashback amount is transferred to the user
        - Amount is based on: min(flowRate, maxRate) × epochDuration × cashbackBips / 10,000
    - Emits
        - `CashbackClaimed(user, tradeId, epochId, amount)`

- `withdrawTokens(address token, address to, uint256 amount)` - Withdraw any ERC20 token from the contract (admin only)
    - Args
        - `token` - The token contract address to withdraw
        - `to` - The address to send the tokens to
        - `amount` - The amount of tokens to withdraw
    - Pre
        - Role required = `ADMIN_ROLE`
        - `to` must not be address(0)
        - `amount` must be > 0
    - Post
        - Tokens are transferred to the specified address
    - Emits
        - `TokensWithdrawn(token, to, amount)`

### View Functions
- `getEligibleEpochs(uint256 tradeId) view` - Get all eligible epoch IDs for a trade
    - Args
        - `tradeId` - The tradeId to check eligibility for
    - Returns
        - Array of eligible epoch IDs that haven't been claimed yet
    - Logic
        - Only returns completed epochs
        - Filters out already claimed epochs
        - Checks trade eligibility for each epoch

- `getCashbackClaim() view` - Get the campaign configuration
    - Returns
        - The complete CashbackClaim struct with campaign parameters

- `getEpochTimes(uint256 epochId) view` - Get start and end times for a specific epoch
    - Args
        - `epochId` - The epoch ID to get times for
    - Returns
        - `epochStart` - The start timestamp of the epoch
        - `epochEnd` - The end timestamp of the epoch
    - Logic
        - `epochStart = startTime + (duration × epochId)`
        - `epochEnd = epochStart + duration - 1`

### Epoch Calculation
Epochs are calculated as fixed-duration periods starting from the campaign `startTime`:
- Epoch 0: `[startTime, startTime + duration - 1]`
- Epoch 1: `[startTime + duration, startTime + (2 × duration) - 1]`
- Epoch N: `[startTime + (N × duration), startTime + ((N+1) × duration) - 1]`

### Trade Eligibility Criteria
A trade is eligible for cashback in an epoch if:
1. Trade flow rate ≥ minimum required rate
2. Trade started before or at the epoch start time
3. Trade was active for the entire epoch duration (not ended before epoch end)
4. Epoch has completed (current time > epoch end time)
5. User owns the trade (ERC-721 ownership)
6. User hasn't already claimed this epoch for this trade
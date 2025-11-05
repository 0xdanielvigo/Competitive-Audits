## 1. Summary (What, Who, How)
- **What the system does:** SuperDCACashback issues USDC rebates to Super DCA traders for fully-completed epochs of eligible continuous trades, enforcing campaign parameters that cap rewards and track prior claims on-chain.
- **Who uses it:**
  1. **Trade owners** – Holders of SuperDCATrade NFTs who accrue and claim cashback.
  2. **Protocol administrators** – Addresses with `DEFAULT_ADMIN_ROLE`/`ADMIN_ROLE` that deploy, fund, and recover tokens.
  3. **Auditors/reviewers** – Read-only actors validating invariants and balances (no on-chain rights).
- **How at a high level:** A non-upgradeable Solidity contract holds a single campaign configuration, queries trade metadata from the external SuperDCATrade ERC-721, and pays USDC via SafeERC20; AccessControl restricts administrative withdrawals while claim logic enforces epoch completion, flow-rate bounds, and idempotent accounting.

- **Audit scope freeze:** Repository `super-dca-cashback` at tag `audit-freeze-20250922`.

## 2. Architecture Overview
- **Module map:**

Contract / Module | Responsibility | Key external funcs | Critical invariants
-- | -- | -- | --
`src/SuperDCACashback.sol` | Custodies USDC, computes epoch cashback, enforces claims & admin withdrawals | `claimAllCashback`, `getTradeStatus`, `getCashbackClaim`, `withdrawTokens` | Claimed totals ≤ computed entitlement; flow-rate capped; completed epochs only
`src/interfaces/ISuperDCATrade.sol` | Defines trade metadata & ownership surface used for eligibility | `trades`, `ownerOf` (via ERC-721) | Honest trade data; immutable IDs
`test/mock/SuperDCATrade.sol` | Local harness mimicking SuperDCATrade for tests | `startTrade`, `endTrade` | Owner-only mutation; deterministic timestamps

- **Entry points:**
  - `claimAllCashback(uint256 tradeId)` – Pays all matured cashback for a trade and records total claimed.
  - `getTradeStatus(uint256 tradeId)` – Returns (claimable, pending, claimed) USDC amounts for inspection tools.
  - `getCashbackClaim()` – Exposes immutable campaign parameters and activation timestamp.
  - `withdrawTokens(address token, address to, uint256 amount)` – Admin-controlled escape hatch for any ERC-20 balance.

- **Data flows (high level):**
  1. Trade metadata flows from `SuperDCATrade.trades()` into cashback eligibility checks.
  2. Epoch math converts flow-rate (1e18 precision) into USDC (1e6) for claimable/pending balances.
  3. Successful claims transfer USDC from the contract to the trade owner and increment `claimedAmounts`.
  4. Administrators can relocate idle ERC-20 balances via SafeERC20 transfers to treasury wallets.

## 3. Actors, Roles & Privileges
- **Roles:**

Role | Capabilities
-- | --
Trade owner | Call `getTradeStatus`, `claimAllCashback` for owned trades; receives USDC
Protocol administrator (`ADMIN_ROLE`) | Call `withdrawTokens`; manage treasury funds
Role admin (`DEFAULT_ADMIN_ROLE`) | Grant/revoke `ADMIN_ROLE` and `DEFAULT_ADMIN_ROLE`
Observer (read-only) | Inspect storage, events, view functions

- **Access control design:** OpenZeppelin `AccessControl` assigns both `DEFAULT_ADMIN_ROLE` and `ADMIN_ROLE` to the deployer; role checks happen via `onlyRole(ADMIN_ROLE)` and `hasRole` lookups, with no timelock or delay layer.
- **Emergency controls:** No pausable modifier or circuit breaker; administrators can only move funds out via `withdrawTokens`, so halting claims requires pausing trade creation off-chain or draining rewards to a safe wallet.

## 4. User Flows (Primary Workflows)

### Flow A – Claim completed-epoch cashback
- **User story:** As a trade owner, I claim all matured cashback for my Super DCA trade to receive USDC rewards.
- **Preconditions:**
  - Caller owns the `tradeId` NFT; `ownerOf(tradeId) == msg.sender`.
  - Trade exists with `startTime > 0`, `flowRate ≥ minRate`, and ran through ≥1 full epoch with no prior claim.
  - Contract holds enough USDC to satisfy the payout.
- **Happy path steps:**
  1. User calls `claimAllCashback(tradeId)`.
  2. Contract fetches trade via `SuperDCATrade.trades(tradeId)` and validates existence.
  3. `_getTradeOwner` confirms ownership and handles ERC-721 errors.
  4. `_getTradeStatusInternal` calculates claimable amount (completed epochs × capped flow-rate).
  5. Function reverts if claimable == 0; else increments `claimedAmounts[tradeId]` and transfers USDC.
  6. Emits `CashbackClaimed` event.
- **Alternates / edge cases:**
  - `NotClaimable` revert if trade ended mid-epoch, below min rate, or epochs already claimed.
  - `NotAuthorized` revert if caller is not owner or if `ownerOf` fails.
  - SafeERC20 transfer can bubble failure (e.g., insufficient USDC balance or non-compliant token).
- **On-chain ↔ off-chain interactions:** On-chain only; depends on external `SuperDCATrade` and USDC contracts. Off-chain monitoring should ensure balance sufficiency.
- **Linked diagram:** `./diagrams/claim-completed-epochs.md`
- **Linked tests:**
  - `ClaimAllCashback.testFuzz_ClaimsAllAvailableCashback`
  - `ClaimAllCashback.test_RevertIf_NoClaimableAmount`
  - `ClaimAllCashback.test_RevertIf_CallerNotTradeOwner`
  - `ClaimAllCashback.testFuzz_ClaimCashback_AdditionalEpochs_WithForfeiture`

### Flow B – Inspect trade accrual status
- **User story:** As a monitoring tool, I query trade status to surface claimable and pending cashback for a trader.
- **Preconditions:**
  - Trade exists in `SuperDCATrade`; contract view callable without permissions.
  - Caller has read access (any address).
- **Happy path steps:**
  1. Caller invokes `getTradeStatus(tradeId)`.
  2. Contract loads trade struct and validates minimal eligibility (`startTime > 0`, `flowRate ≥ minRate`).
  3. `_calculateEpochData` splits elapsed time into completed vs. in-progress epochs, respecting `endTime` forfeiture.
  4. `_calculateCompletedEpochsCashback` sums eligible epochs; `_calculatePendingCashback` handles current partial epoch if trade still active.
  5. Function returns `(claimable, pending, claimed)` in USDC precision for UI/off-chain use.
- **Alternates / edge cases:**
  - Returns `(0,0,0)` for nonexistent trades or those below min rate.
  - Pending returns 0 when trade ended or no partial epoch progress.
  - Completed epochs truncated to exclude partially elapsed period at `endTime`.
- **On-chain ↔ off-chain interactions:** Read-only call to `SuperDCATrade`; no token transfers; output informs off-chain dashboards.
- **Linked diagram:** `./diagrams/query-trade-status.md`
- **Linked tests:**
  - `GetTradeStatus.testFuzz_ReturnsCorrectStatusForValidTrade`
  - `GetTradeStatus.test_HandlesEndedTrade`
  - `GetTradeStatus.test_CapsFlowRateAtMaxRate`
  - `GetTradeStatus.testFuzz_ReturnsCorrectStatusAfterClaim`

### Flow C – Admin withdraws idle tokens
- **User story:** As a protocol administrator, I retrieve excess USDC or other ERC-20 tokens from the cashback contract back to treasury.
- **Preconditions:**
  - Caller holds `ADMIN_ROLE` (granted via AccessControl).
  - `to` address is non-zero and distinct from the contract.
  - `amount > 0` and token balance suffices.
- **Happy path steps:**
  1. Admin calls `withdrawTokens(token, to, amount)`.
  2. AccessControl verifies caller has `ADMIN_ROLE`.
  3. Function checks parameters (non-zero recipient, amount) and uses SafeERC20 to transfer tokens.
  4. Emits `TokensWithdrawn` event for bookkeeping.
- **Alternates / edge cases:**
  - Reverts with `InvalidParams(1)` if recipient is zero.
  - Reverts with `InvalidParams(2)` if amount is zero.
  - SafeERC20 bubbles revert if balance insufficient or token misbehaves.
  - Non-admin callers revert via AccessControl (custom revert string).
- **On-chain ↔ off-chain interactions:** ERC-20 transfer only; off-chain governance should log withdrawals and rebalance budgets.
- **Linked diagram:** `./diagrams/admin-withdrawal.md`
- **Linked tests:**
  - `WithdrawTokens.testFuzz_WithdrawsTokensSuccessfully`
  - `WithdrawTokens.testFuzz_RevertIf_CalledByNonAdmin`
  - `WithdrawTokens.testFuzz_RevertIf_RecipientIsZeroAddress`
  - `WithdrawTokens.testFuzz_RevertIf_InsufficientTokenBalance`

## 5. State, Invariants & Properties
- **Critical state variables:**
  - `USDC` (immutable IERC20) – payout token address.
  - `SUPER_DCA_TRADE` (immutable ISuperDCATrade) – trade registry queried for eligibility.
  - `cashbackClaim` – campaign parameters (duration, flow-rate bounds, cashback rate, startTime, timestamp).
  - `claimedAmounts[tradeId]` – cumulative USDC claimed per trade (6 decimals).

- **Invariants (must always hold):**

Invariant | Description | Enforced / Checked by
-- | -- | --
Campaign bounds | `cashbackBips ≤ 10_000`, `duration > 0`, `minRate < maxRate ≤ int96.max` | Constructor guards; `Constructor.testFuzz_RevertIf_InvalidCashbackBips`; `Constructor.test_RevertIf_ZeroDuration`
Claim monotonicity | `claimedAmounts[tradeId]` only increases and never exceeds computed entitlement | `ClaimAllCashback` updates mapping after positive claim; validated by `ClaimAllCashback.testFuzz_ClaimsAllAvailableCashback`
Epoch completeness | Claims include only fully-completed epochs; partial epochs forfeited on trade end | `_calculateCompletedEpochsCashback`; tests `ClaimAllCashback.testFuzz_ClaimCashback_AdditionalEpochs_WithForfeiture`, `InternalFunctionCoverage.test_TradeEndingInFirstEpoch_PartialDuration`
Flow-rate cap | Effective flow rate = `min(flowRate, maxRate)` to bound payouts | `_getEffectiveFlowRate`; `GetTradeStatus.test_CapsFlowRateAtMaxRate`
Access segregation | Only `ADMIN_ROLE` can call `withdrawTokens` | AccessControl + `WithdrawTokens.testFuzz_RevertIf_CalledByNonAdmin`
Precision conversion | 1e18 → 1e6 conversion prevents rounding up to > entitlement | `_convertToUSDCPrecision`; covered by fuzz tests asserting balances

- **Property checks / assertions:** Fuzz tests in `test/SuperDCACashback.t.sol` target constructor parameter space, claim eligibility, forfeiture handling, and withdrawal access control. CI profile (`foundry.toml`) increases fuzz runs to 5000 for additional assurance.

## 6. Economic & External Assumptions
- **Token assumptions:**
  - Payout token behaves like standard USDC (6 decimals, no fee-on-transfer, `safeTransfer` compatible).
  - Contract must be pre-funded with sufficient USDC; otherwise claims revert during transfer.
- **Oracle assumptions:** No oracle dependencies; relies on `SuperDCATrade` for deterministic trade metadata.
- **Liquidity/MEV/DoS assumptions:**
  - Claim transactions are low-value and not MEV-attractive; DoS mainly possible via admin draining funds.
  - Continuous-flow updates rely on off-chain keepers ending trades promptly; stale `endTime` delays forfeiture recognition.
  - Gas usage scales linearly with completed epochs count but is bounded by arithmetic on `uint256` (no loops).

## 7. Upgradeability & Initialization
- **Pattern:** None (contract is non-upgradeable; state initialized in constructor).
- **Initialization path:** Constructor sets immutable token/trade addresses, validates campaign parameters, writes `cashbackClaim`, and assigns roles. No reinitialization entry points.
- **Migration & upgrade safety checks:** Any new deployment must repeat constructor validation; governance should verify campaign parameters offline and migrate funds by transferring residual USDC via `withdrawTokens`.

## 8. Parameters & Admin Procedures
- **Config surface:**

Parameter | Units | Safe range guidance | Default in repo
-- | -- | -- | --
`cashbackBips` | basis points | 1–10_000 (capped by constructor) | 100 (1%)
`duration` | seconds | ≥3,600; align to marketing epoch (<= 365 days recommended) | 86,400 (1 day)
`minRate` | wei/sec (int96) | ≥100 (post-precision) | 1
`maxRate` | wei/sec | ≤ int96.max; > `minRate` | 1,000,000
`startTime` | unix seconds | ≥ deployment timestamp | `block.timestamp` at deploy

- **Authorized actors and processes:**
  - Role setup: deployer receives both roles; use multisig to hold `DEFAULT_ADMIN_ROLE` and delegate `ADMIN_ROLE` as needed.
  - Parameter changes require redeploying the contract; existing instance immutable.
  - Token withdrawals: `ADMIN_ROLE` executes `withdrawTokens`, ideally via governance proposal or multisig with off-chain approval logs.
- **Runbooks:**
  - **Pause claims:** Drain USDC via `withdrawTokens`, notify users; there is no on-chain pause.
  - **Unpause / resume:** Re-fund contract, ensure campaign parameters still valid.
  - **Role rotation:** `DEFAULT_ADMIN_ROLE` uses `grantRole`/`revokeRole` on AccessControl (exposed via inherited functions) to rotate keys; verify events.
  - **Failure recovery:** If USDC transfer fails, top up balance or investigate token behavior; if SuperDCATrade compromised, consider migrating users to new deployment.

## 9. External Integrations
- **Addresses / versions:**
  - **USDC:** Expected to point to canonical deployment per network (e.g., Ethereum mainnet `0xA0b86991C6218b36c1d19D4a2e9Eb0cE3606eB48`). Replace with network-specific address before deployment.
  - **SuperDCATrade:** Project-owned ERC-721 contract supplying trade metadata; address varies per environment and must expose `trades`/`ownerOf` consistent with interface.
  - **OpenZeppelin AccessControl & SafeERC20:** Imported from `openzeppelin-contracts@c64a1edb`.
- **Failure assumptions & mitigations:**
  - If `SuperDCATrade` reverts or returns malformed data, claims revert (`NotClaimable`) but funds remain in contract.
  - If USDC reverts or enforces fees, SafeERC20 propagates revert; administrators should pre-test token behavior on target chain.
  - External contract upgrades (if any) are out of scope; rely on governance to maintain compatibility.

## 10. Build, Test & Reproduction
- **Environment prerequisites:**
  - Unix-like OS (Linux/macOS).
  - [Foundry](https://book.getfoundry.sh) toolchain installed via `foundryup` (ensures `forge` + `cast` with solc 0.8.29 per `foundry.toml`).
  - Git ≥2.40, curl, and `make` (for optional scripts).
- **Clean-machine setup:**
  ```bash
  # Toolchain bootstrap
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.foundry/bin/foundryup
  foundryup --version  # confirm installer

  # Clone frozen revision
  git clone https://github.com/<org>/super-dca-cashback.git
  cd super-dca-cashback
  git checkout f1193550f68cb9794200b069305f2ba9b16a0378
  git submodule update --init --recursive

  # Environment configuration
  cp .env.example .env  # fill RPC, keys only if deploying/scripts
  ```
- **Build:**
  ```bash
  forge --version         # shows solc 0.8.29 per foundry.toml
  forge build             # deterministic build using Cancun EVM
  ```
- **Tests:**
  ```bash
  forge test              # default fuzz runs (256)
  forge test -vv          # verbose traces for debugging
  forge test --profile ci # matches CI fuzz/invariant intensity
  forge test --match-test testFuzz_ClaimsAllAvailableCashback  # single test example
  ```
- **Coverage / fuzzing:**
  - Coverage summary: `forge coverage --report summary` (optional; slower).
  - Adjust fuzz runs via profiles (`foundry.toml` defines `ci`, `coverage`, `lite`).

## 11. Known Issues & Areas of Concern
- **No circuit breaker:** Contract lacks pause; mitigation is emergency withdrawal of funds, which also blocks honest users.
- **Admin key risk:** `ADMIN_ROLE` can drain all tokens; enforce multisig + monitoring.
- **External dependency trust:** Malicious or buggy `SuperDCATrade` could misreport `startTime`/`flowRate`, inflating rewards—off-chain governance must validate trade data integrity.
- **USDC balance exhaustion:** Claims revert if balance insufficient; consider automated top-ups and alerts.
- **Precision floor:** `_convertToUSDCPrecision` truncates <1e12 results, so very small flow rates yield zero cashback; document to users.

## 13. Appendix
- **Glossary:**
  - **Epoch:** Fixed-length time window (seconds) after campaign `startTime`.
  - **Flow rate:** Continuous token streaming rate in wei/sec from Superfluid trades.
  - **Cashback bips:** Basis points (1/10,000) used to compute reward percentage.
  - **Forfeiture:** Loss of pending rewards when a trade ends before completing an epoch.
- **Diagrams:**
  - [Claim completed epochs](./diagrams/claim-completed-epochs.md)
  - [Query trade status](./diagrams/query-trade-status.md)
  - [Admin withdrawal](./diagrams/admin-withdrawal.md)
- **Scopelint Spec:** Last updated 2025-09-22.
```
Contract Specification: SuperDCACashback
├── constructor
│   ├──  Sets Configuration Parameters
│   ├──  Sets Configuration Parameters To Arbitrary Values
│   ├──  Revert If: Invalid Cashback Bips
│   ├──  Revert If: Invalid Rates
│   ├──  Revert If: Zero Duration
│   └──  Revert If: Max Rate Exceeds Int96 Max
├── getTradeStatus
│   ├──  Returns Correct Status For Valid Trade
│   ├──  Returns Zeros For Non Existent Trade
│   ├──  Returns Correct Status After Claim
│   ├──  Handles Ended Trade
│   ├──  Handles Flow Rate Below Minimum
│   ├──  Caps Flow Rate At Max Rate
│   └──  Get Trade Status: Immediately After Trade Start
├── _getTradeStatusInternal
├── _isTradeValid
├── _calculateEpochData
├── _getEffectiveFlowRate
├── _convertToUSDCPrecision
├── _calculateCompletedEpochsCashback
├── _calculatePendingCashback
├── claimAllCashback
│   ├──  Claims All Available Cashback
│   ├──  Emits Cashback Claimed Event
│   ├──  Revert If: No Claimable Amount
│   ├──  Revert If: Trade Does Not Exist
│   ├──  Revert If: Caller Not Trade Owner
│   ├──  Handles Partial Duration Trade
│   ├──  Caps Flow Rate At Max Rate
│   ├──  Revert If: All Amounts Claimed
│   ├──  Handles Flow Rate Below Minimum
│   ├──  Claim Cashback: Trade Ends During First Epoch
│   ├──  Revert If: Get Trade Owner Fails
│   ├──  Claim Cashback: Multiple Epochs: No Forfeiture
│   ├──  Claim Cashback: Additional Epochs: With Forfeiture
│   └──  Claim Cashback: Additional Epochs: Fully Forfeited
├── getCashbackClaim
│   ├──  Returns Claim Information
│   └──  Returns Default Claim Information
├── withdrawTokens
│   ├──  Withdraws Tokens Successfully
│   ├──  Withdraws U S D C Successfully
│   ├──  Emits Tokens Withdrawn Event
│   ├──  Revert If: Called By Non Admin
│   ├──  Revert If: Recipient Is Zero Address
│   ├──  Revert If: Amount Is Zero
│   ├──  Revert If: Insufficient Token Balance
│   ├──  Withdraws Partial Balance
│   ├──  Withdraws Entire Balance
│   └──  Withdraws Different Tokens Sequentially
└── _getTradeOwner
```

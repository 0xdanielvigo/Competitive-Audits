# Super DCA Liquidity Network contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
OP, Unichain, Base, Arbitrum, Polygon, BNB, Ethereum, Ink (when Uniswap V4 will be deployed on Ink)
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
The Super DCA Gauge is design to work with any ERC20 token. There's a Listing System that allows any token to be listed as long as there is a listing fee paid and Uniswap V4 supports the token. You can read more about the listing system in this section of the Super DCA Whitepaper: https://github.com/Super-DCA-Tech/super-dca-whitepaper/tree/main?tab=readme-ov-file#listing-fee.

As such, it's a critical priority to make sure that the contract safely handles tokens. There are not any weird tokens that come to mind, but the system is supposed to allow permissionless listing for any token. This may not be safe and it's something I would consider addressing by adding an allowlist since weird token traits can and have caused problems for protocols.

Only tokens that are supported by UniswapV4 and can be used to make a UniswapV4 pool are considered in scope.
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
Manager is trusted. They can tune the fees. 
Keeper is not trusted. They have a lower fee when using pools with the Super DCA gauge applied.
Listing agent (i.e., the one calling `list`) is not trusted.
Stakers are not trusted.
All the untrusted roles can be considered malicious and harm the protocol/users.
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No
___

### Q: Is the codebase expected to comply with any specific EIPs?
No
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
No. The keeper role is designed to be assumed by the Super DCA team running a bot off-chain. But, the keeper can be no one and the protocol works fine. The keeper has the right, but not the obligation, to swap through pools with the Super DCA Gauge hook. Therefore, the protocol does not misbehave if the Keeper is offline or not set. 
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
Global DCA token accounting
- Gauge DCA balance conservation:
  - IERC20(superDCAToken).balanceOf(address(this)) == totalStakedAmount + keeperDeposit after any external call completes.
  - Stake/unstake/becomeKeeper are the only sources/sinks for the gauge’s own DCA balance; distribution mints to poolManager/developer never change this equality.
- Aggregate stake consistency:
  - totalStakedAmount equals the sum over all tokens of tokenRewardInfos[token].stakedAmount (trackable in tests via a ghost set of seen tokens).

Reward index and accrual
- Monotonicity and timing:
  - rewardIndex is non-decreasing and only increases when totalStakedAmount > 0 and time has elapsed since lastMinted.
  - lastMinted is non-decreasing and never exceeds block.timestamp.
- Exact increment formula:
  - On any call that triggers _updateRewardIndex() with elapsed = block.timestamp - lastMinted and totalStakedAmount > 0:
    - rewardIndex increases by Math.mulDiv(elapsed * mintRate, 1e18, totalStakedAmount) exactly.
- Last index safety and isolation:
  - For every token, tokenRewardInfos[token].lastRewardIndex <= rewardIndex at all times.
  - Distribution for one token never changes tokenRewardInfos[otherToken].lastRewardIndex (per-token isolation of accrual capture).
- View-to-effect consistency:
  - If a distribution for token T is triggered at time t, the rewardAmount used equals getPendingRewards(T) computed immediately prior at time t (same block timestamp and totalStakedAmount), and after distribution tokenRewardInfos[T].lastRewardIndex == rewardIndex.
- No accrual leakage on stake/unstake:
  - Immediately after stake/unstake for token T, tokenRewardInfos[T].lastRewardIndex == rewardIndex, so getPendingRewards(T) == 0 until time advances.

Distribution and settlement
- Split correctness:
  - rewardAmount = developerShare + communityShare with:
    - developerShare = floor(rewardAmount / 2)
    - communityShare = rewardAmount - developerShare
  - Odd amounts give the extra unit to the community share.
- Liquidity-gated community distribution:
  - If pool liquidity (from IPoolManager(msg.sender)) == 0 at distribution time:
    - The entire rewardAmount is attempted to be minted to developer only; no donation attempted; no settle called.
- Mint-failure resilience:
  - Even if developer mint and/or community mint fail, lastMinted and rewardIndex still advance; tokenRewardInfos[token].lastRewardIndex is updated, preventing double counting on future distributions.

Staking bookkeeping
- Set membership matches amounts:
  - userStakes[user][token] > 0 if and only if token is present in userStakedTokens[user]; when it drops to zero, the token is removed from the set.
- Aggregate consistency per token and global:
  - info.stakedAmount for a token equals the sum of userStakes across all users for that token (trackable in tests).
  - Changes to totalStakedAmount are exactly the sum of deltas applied to info.stakedAmount across tokens in the same transaction.

Keeper system
- Strictly-increasing deposit sequence:
  - Across successful becomeKeeper calls, the sequence of keeperDeposit values is strictly increasing.
- Single keeper and conservation:
  - After becomeKeeper(amount):
    - keeper == msg.sender and keeperDeposit == amount.
    - The previous keeper (if any) is refunded exactly the old keeperDeposit.
    - Gauge DCA balance changes by (amount - oldDeposit), preserving the global balance invariant.


Role-independent behavior and failure scenarios
- Ownership transfer impact:
  - After returnSuperDCATokenOwnership, subsequent distributions attempt mints that fail; yet rewardIndex and lastMinted still advance, and per-token lastRewardIndex is updated on distribution attempts (no double counting later).
- Zero mintRate:
  - With mintRate == 0, rewardIndex never changes via _updateRewardIndex and getPendingRewards always returns 0, regardless of time.
___

### Q: Please discuss any design choices you made.
1. The Super DCA token is an ERC20 mintable token owned by, and mintable by, the Super DCA Gauge.
2. We keep the swap related hooks minimal in their role so that the gas to execute swaps is not expensive, we want swaps to be very cheap through the hook.
3. The Super DCA Gauge Staking system is attached to the gauge to keep the logic in the same contract, this could be a bad design choice and I do worry some issues related to this decsions could be surfaces.
4. Similarly, the Super DCA Listing system is included in the gauge to keep the logic in the same contract, I have the same concern about this design choice as well.
5. The rewards distribution logic using the native Uniswap `donate` function. Each pool's donation is triggered when liquidity is added or removed. Each pool's rewards math is computed seperately and this might lead to some unintended ways to game the protocol's DCA rewards emissions. 
___

### Q: Please provide links to previous audits (if any) and all the known issues or acceptable risks.
We don't have any prior audits.
___

### Q: Please list any relevant protocol resources.
Super DCA Whitepaper: https://github.com/Super-DCA-Tech/super-dca-whitepaper

This is written for the version that was deployed to Uniswap V3, but the version we're deploying to v4 works very similar. 
___

### Q: Additional audit information.
The Super DCA Token is deployed at: op/base/unichain/arb:0xb1599cde32181f48f89683d3c5db5c5d2c7c93cc


# Audit scope

[super-dca-cashback @ e9fd71d431af2da205a924547bce5484daa5e9df](https://github.com/Super-DCA-Tech/super-dca-cashback/tree/e9fd71d431af2da205a924547bce5484daa5e9df)
- [super-dca-cashback/src/interfaces/ISuperDCATrade.sol](super-dca-cashback/src/interfaces/ISuperDCATrade.sol)
- [super-dca-cashback/src/SuperDCACashback.sol](super-dca-cashback/src/SuperDCACashback.sol)

[super-dca-gauge @ 3a15b6c145c72c97ca00f56bb07fe727e2f49330](https://github.com/Super-DCA-Tech/super-dca-gauge/tree/3a15b6c145c72c97ca00f56bb07fe727e2f49330)
- [super-dca-gauge/src/interfaces/ISuperDCAStaking.sol](super-dca-gauge/src/interfaces/ISuperDCAStaking.sol)
- [super-dca-gauge/src/SuperDCAGauge.sol](super-dca-gauge/src/SuperDCAGauge.sol)
- [super-dca-gauge/src/SuperDCAListing.sol](super-dca-gauge/src/SuperDCAListing.sol)
- [super-dca-gauge/src/SuperDCAStaking.sol](super-dca-gauge/src/SuperDCAStaking.sol)
- [super-dca-gauge/src/SuperDCAToken.sol](super-dca-gauge/src/SuperDCAToken.sol)



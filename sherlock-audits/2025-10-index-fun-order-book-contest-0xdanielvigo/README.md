# Index Fun Order Book contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Sonic
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
We will use USDC as the primary currency for placing bets

We also use a forked conditional token standard (https://conditional-tokens.readthedocs.io/en/latest/developer-guide.html) for our outcome tokens - this is a version of ERC-1155. 
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
Owner/Admin Roles are TRUSTED with limitations:

VALUE RESTRICTIONS IN PLACE:
- Fee rates (feeRate, tradeFeeRate, userFeeRate): Maximum 10% (1000 basis points)
- Outcome count: 1-256 outcomes
- Resolution time: Must be future timestamp when set
- Batch claim operations: Maximum 50 claims per transaction

NO VALUE RESTRICTIONS (Admin fully trusted):
- All contract address updates (collateralToken, marketController, vault, etc.)
- Treasury address
- Oracle address
- Authorized matcher addresses

HARDCODED VALUES:
- MAX_FEE_RATE = 1000 (10%) - no plans to change
- Max batch claims = 50 - may increase if gas optimization needed
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No
___

### Q: Is the codebase expected to comply with any specific EIPs?
We use EIP-712 for signature validation in the Market Controller -> _verifyOrder

We use EIP-1155 for Conditional Tokens

We use EIP 1967 Upgradable Proxy

If there are issues violating “MUST” statements from these EIP, they can be considered Medium severity.
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
Yes we use an off-chain orderbook system to efficiently matching user orders, we use a special role, authorizedMatchers to allow matching user orders
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
The number of tokens minted when creating conditional tokens must = vault collateral (for this specific token) * number of conditions

For example: 

If there is 100 YES tokens and 100 NO tokens, the vault must contain $100

Equally, the number of YES tokens must exactly match the number of NO tokens
___

### Q: Please discuss any design choices you made.
IT Minting vs Token Swaps:
_executeTrade() intelligently detects if seller has inventory
If yes: direct token transfer (swap)
If no: JIT mints complementary positions


___

### Q: Please provide links to previous audits (if any) and all the known issues or acceptable risks.
N/A
___

### Q: Please list any relevant protocol resources.
https://conditional-tokens.readthedocs.io/en/latest/developer-guide.html

https://staging.index.fun/index_orderbook/nancy-pelosi-index-pelosi
___

### Q: Additional audit information.
We are using inspiration from Polymarket & open zeppelin conditional contracts to build the structure of this platform

Ensuring the logic of these is correct and the matching logic cannot be tampered with is vital for the success of the project so focusing of these elements will be the #1 priority 


# Audit scope

[orderbook-solidity @ 9571684a0dbd724933c7e48a3be94f08193e1a2a](https://github.com/index-fun/orderbook-solidity/tree/9571684a0dbd724933c7e48a3be94f08193e1a2a)
- [orderbook-solidity/src/Market/IMarketController.sol](orderbook-solidity/src/Market/IMarketController.sol)
- [orderbook-solidity/src/Market/MarketController.sol](orderbook-solidity/src/Market/MarketController.sol)
- [orderbook-solidity/src/Market/MarketResolver.sol](orderbook-solidity/src/Market/MarketResolver.sol)
- [orderbook-solidity/src/Market/Market.sol](orderbook-solidity/src/Market/Market.sol)
- [orderbook-solidity/src/Token/PositionTokens.sol](orderbook-solidity/src/Token/PositionTokens.sol)
- [orderbook-solidity/src/Vault/Vault.sol](orderbook-solidity/src/Vault/Vault.sol)



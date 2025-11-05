# SuperDCACashback

A smart contract that distributes USDC cashback rewards to users of the Super DCA trading protocol over time-based epochs. Users can claim cashback for each epoch their trades meet specific duration and flow rate criteria configured at deployment.

## Overview

The SuperDCACashback contract allows:
- **Deployment**: Configure a single cashback campaign with parameters (epoch duration, flow rates, cashback percentage)
- **Users**: Claim USDC rewards for each eligible epoch of their Super DCA trades
- **Admins**: Withdraw tokens and manage the contract

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for any frontend integration)

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd super-dca-cashback

# Install dependencies
forge install

# Build the project
forge build
```

### Running Tests

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run coverage report
forge coverage --report summary

# Run specific test contract
forge test --match-contract SuperDCACashback
```

### Formatting & Linting

```bash
# Format Solidity files
forge fmt

# Run scopelint checks (if installed)
scopelint check
```

## Project Structure

```
src/
├── SuperDCACashback.sol          # Main cashback contract
└── interfaces/
    └── ISuperDCATrade.sol         # Interface for Super DCA trades

test/
├── SuperDCACashback.t.sol        # Comprehensive test suite
├── helpers/
│   └── TestHelpers.sol           # Test utilities
├── mock/
│   └── SuperDCATrade.sol         # Mock Super DCA contract
└── mocks/
    └── MockERC20Token.sol        # Mock ERC20 for testing

script/
├── Deploy.s.sol                  # Generic deployment script
└── DeployOptimism.s.sol          # Optimism-specific deployment
```

## Key Features

### For Administrators
- **Withdraw Tokens**: Move any ERC-20 (including USDC) out of the contract in an emergency
- **Role Management**: Grant or revoke the `ADMIN_ROLE` and other roles via OpenZeppelin `AccessControl`

### For Users
- **Claim Cashback** (`claimAllCashback`): Claim all completed-epoch cashback for a given trade in a single call  
- **Check Status** (`getTradeStatus`): View how much cashback is *claimable*, *pending* (current epoch), and already *claimed*  
- **One-time Claims per Epoch**: Each trade can claim every epoch at most once – enforced on-chain

## Core Concepts

### Cashback Campaign
A single immutable campaign is configured at deployment through the `CashbackClaim` struct:
- `cashbackBips` – Reward percentage in basis-points (0-10 000)
- `duration` – Length of every epoch in seconds
- `minRate` – Minimum trade flow-rate required to be eligible
- `maxRate` – Maximum flow-rate considered in the calculation (higher rates are **capped**, not rejected)
- `startTime` – Timestamp of epoch 0

### Trade Eligibility
A trade can earn cashback if **all** of the following hold:
1. `flowRate` ≥ `minRate`
2. `startTime` > 0 (trade has been opened)
3. Caller owns the trade (ERC-721 `ownerOf`)
4. The trade has not already claimed the relevant epochs

### Epoch & Forfeiture Rules
• Only **fully completed epochs** are eligible for cashback rewards.
• If a trade ends before completing an epoch, that epoch (and any subsequent ones) are **forfeited**.  
• While a trade is active, a partial (current) epoch accrues *pending* cashback that can be claimed once the epoch completes.
• Rewards become claimable only after the complete epoch duration has elapsed.

### Effective Flow-Rate
If a trade’s `flowRate` exceeds `maxRate`, the calculation uses `maxRate`. This prevents whales from exhausting the budget while keeping the mechanism simple.

### Precision
The contract works with 18-decimals flow-rates and converts results to the 6-decimals used by USDC before transfers.

## Development

### Adding New Features

1. Write tests first in `test/SuperDCACashback.t.sol`
2. Implement the feature in `src/SuperDCACashback.sol`
3. Run tests: `forge test`
4. Update documentation

### Testing Strategy

The test suite covers:
- **Unit Tests**: Individual function behavior
- **Fuzz Tests**: Edge cases with random inputs
- **Integration Tests**: End-to-end workflows
- **Access Control**: Permission checks
- **Edge Cases**: Boundary conditions and error states

### Gas Optimization

- Use `immutable` for constructor-set values
- Pack structs efficiently
- Minimize external calls
- Use custom errors instead of string reverts

## Deployment

### Local Deployment

```bash
# Start local anvil node
anvil

# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Mainnet Deployment

```bash
# Deploy to mainnet (example)
forge script script/Deploy.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

## Configuration

### Constructor Parameters
- `_usdc`: USDC token contract address
- `_superDCATrade`: Super DCA trade contract address  
- `_admin`: Initial admin address (receives DEFAULT_ADMIN_ROLE and ADMIN_ROLE)
- `_cashbackClaim`: Campaign configuration (cashback %, epoch duration, flow rate bounds, start time)

### Environment Variables
Create a `.env` file:
```
MAINNET_RPC_URL=your_mainnet_rpc_url
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Security Considerations

- Contract is **non-upgradeable** - deploy carefully
- Admin roles have significant power - use multisig
- USDC balance must cover expected claims
- All external calls are to trusted contracts (USDC, SuperDCATrade)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Documentation

- [README.md](README.md) - Developer documentation (this file)
- [WHITEPAPER.md](WHITEPAPER.md) - Detailed technical analysis and security review
- [SPEC.md](SPEC.md) - Technical specification

## License

[Add your license here]

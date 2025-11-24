-include .env

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

# Clean build artifacts
clean:
	forge clean

# Install dependencies
install:
	forge install foundry-rs/forge-std@v1.9.3 --no-git
	forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-git
	forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.2 --no-git

# Update dependencies
update:
	forge update

# Build contracts
build:
	forge build

# Run tests
test:
	forge test

# Run tests with verbosity
test-v:
	forge test -vvv

# Run tests with gas report
test-gas:
	forge test --gas-report

# Run specific test
test-contract:
	forge test --match-contract $(contract)

test-function:
	forge test --match-test $(function)

# Format code
format:
	forge fmt

# Lint code
lint:
	forge fmt --check

# Generate documentation
doc:
	forge doc

# Start local node
anvil:
	anvil

# Create deployments directory
create-deployments-dir:
	@mkdir -p deployments
	@echo "$(GREEN)✅ Deployments directory created$(NC)"

# ============================================================================
# ADDRESS PREDICTION (Run before deployment)
# ============================================================================

# Predict addresses for Create2 deployment
predict-addresses:
	@echo "$(BLUE)🔮 Predicting Create2 deployment addresses...$(NC)"
	forge script script/PredictAddresses.s.sol:PredictAddresses --fork-url $(SEPOLIA_RPC_URL) -vv

predict-addresses-local:
	@echo "$(BLUE)🔮 Predicting addresses for local deployment...$(NC)"
	forge script script/PredictAddresses.s.sol:PredictAddresses --fork-url http://localhost:8545 -vv

# Verify addresses match across chains
verify-addresses:
	@echo "$(BLUE)🔍 Verifying address consistency across chains...$(NC)"
	forge script script/VerifyAddresses.s.sol:VerifyAddresses -vv

# ============================================================================
# CREATE2 DEPLOYMENT COMMANDS (Deterministic addresses)
# ============================================================================

# Deploy to local network with Create2
deploy-local: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying to Local Anvil Network (Create2)...$(NC)"
	@echo "$(YELLOW)📍 Addresses will be deterministic and consistent across chains$(NC)"
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url http://localhost:8545 \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		-vvvv

# Deploy to Sepolia testnet with Create2
deploy-sepolia: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying to Sepolia Testnet (Create2)...$(NC)"
	@echo "$(YELLOW)📍 Addresses will match other chains if using same deployer$(NC)"
	@echo "$(YELLOW)⚡ Using 2 gwei gas price for Sepolia$(NC)"
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--gas-price 2000000000 \
		--legacy \
		-vvvv

# Deploy to Sonic Mainnet
deploy-sonic: create-deployments-dir
	@echo "$(RED)⚠️  SONIC MAINNET DEPLOYMENT$(NC)"
	@echo "$(YELLOW)This will deploy to Sonic mainnet with real tokens!$(NC)"
	@read -p "Type 'DEPLOY_TO_SONIC_MAINNET' to continue: " confirm && [ "$$confirm" = "DEPLOY_TO_SONIC_MAINNET" ]
	@echo "$(BLUE)🚀 Deploying to Sonic Mainnet...$(NC)"
	@echo "$(YELLOW)⚡ Using 1 gwei gas price for Sonic$(NC)"
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(SONIC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(SONIC_API_KEY) \
		--gas-price 1000000000 \
		--legacy \
		-vvvv

# Deploy to Sonic Testnet
deploy-sonic-testnet: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying to Sonic Testnet...$(NC)"
	@echo "$(YELLOW)⚡ Using 1 gwei gas price for Sonic Testnet$(NC)"
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(SONIC_TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(SONIC_API_KEY) \
		--gas-price 1000000000 \
		--legacy \
		-vvvv

# Deploy to BSC Mainnet
deploy-bsc: create-deployments-dir
	@echo "$(RED)⚠️  BSC MAINNET DEPLOYMENT$(NC)"
	@echo "$(YELLOW)This will deploy to BSC mainnet with real BNB and tokens!$(NC)"
	@read -p "Type 'DEPLOY_TO_BSC_MAINNET' to continue: " confirm && [ "$$confirm" = "DEPLOY_TO_BSC_MAINNET" ]
	@echo "$(BLUE)🚀 Deploying to BSC Mainnet...$(NC)"
	@echo "$(YELLOW)⚡ Using 5 gwei gas price for BSC$(NC)"
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(BSCSCAN_API_KEY) \
		--gas-price 5000000000 \
		--legacy \
		-vvvv

# Deploy to BSC Testnet
deploy-bsc-testnet: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying to BSC Testnet...$(NC)"
	@echo "$(YELLOW)⚡ Using 10 gwei gas price for BSC Testnet$(NC)"
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(BSC_TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(BSCSCAN_API_KEY) \
		--gas-price 10000000000 \
		--legacy \
		-vvvv

# Deploy to Arbitrum Mainnet
deploy-arbitrum: create-deployments-dir
	@echo "$(RED)⚠️  ARBITRUM MAINNET DEPLOYMENT$(NC)"
	@echo "$(YELLOW)This will deploy to Arbitrum mainnet with real ETH and tokens!$(NC)"
	@read -p "Type 'DEPLOY_TO_ARBITRUM_MAINNET' to continue: " confirm && [ "$$confirm" = "DEPLOY_TO_ARBITRUM_MAINNET" ]
	@echo "$(BLUE)🚀 Deploying to Arbitrum Mainnet...$(NC)"
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(ARBITRUM_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ARBISCAN_API_KEY) \
		--legacy \
		-vvvv

# Deploy to Arbitrum Sepolia
deploy-arbitrum-sepolia: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying to Arbitrum Sepolia...$(NC)"
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ARBISCAN_API_KEY) \
		--legacy \
		-vvvv

# ============================================================================
# SETUP COMMANDS (Post-deployment configuration)
# ============================================================================

# Run setup script for different networks
setup-sepolia:
	@echo "$(BLUE)⚙️ Running setup on Sepolia...$(NC)"
	forge script script/Setup.s.sol:Setup --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

setup-sonic:
	@echo "$(BLUE)⚙️ Running setup on Sonic Mainnet...$(NC)"
	forge script script/Setup.s.sol:Setup --rpc-url $(SONIC_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

setup-sonic-testnet:
	@echo "$(BLUE)⚙️ Running setup on Sonic Testnet...$(NC)"
	forge script script/Setup.s.sol:Setup --rpc-url $(SONIC_TESTNET_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

setup-bsc:
	@echo "$(BLUE)⚙️ Running setup on BSC Mainnet...$(NC)"
	forge script script/Setup.s.sol:Setup --rpc-url $(BSC_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

setup-bsc-testnet:
	@echo "$(BLUE)⚙️ Running setup on BSC Testnet...$(NC)"
	forge script script/Setup.s.sol:Setup --rpc-url $(BSC_TESTNET_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

setup-arbitrum:
	@echo "$(BLUE)⚙️ Running setup on Arbitrum Mainnet...$(NC)"
	forge script script/Setup.s.sol:Setup --rpc-url $(ARBITRUM_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

setup-arbitrum-sepolia:
	@echo "$(BLUE)⚙️ Running setup on Arbitrum Sepolia...$(NC)"
	forge script script/Setup.s.sol:Setup --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

# ============================================================================
# VERIFICATION COMMANDS
# ============================================================================

# Generate verification commands and proxy guidance
verification-guide:
	@echo "$(BLUE)📋 Getting verification guide...$(NC)"
	@if [ -f "deployments/sepolia.json" ]; then \
		echo "$(GREEN)Found Sepolia deployment$(NC)"; \
		forge script script/ProxyVerification.s.sol:ProxyVerification --fork-url $(SEPOLIA_RPC_URL) -vv; \
	elif [ -f "deployments/bsc-testnet.json" ]; then \
		echo "$(GREEN)Found BSC testnet deployment$(NC)"; \
		forge script script/ProxyVerification.s.sol:ProxyVerification --fork-url $(BSC_TESTNET_RPC_URL) -vv; \
	elif [ -f "deployments/sonic-testnet.json" ]; then \
		echo "$(GREEN)Found Sonic testnet deployment$(NC)"; \
		forge script script/ProxyVerification.s.sol:ProxyVerification --fork-url $(SONIC_TESTNET_RPC_URL) -vv; \
	elif [ -f "deployments/arbitrum-sepolia.json" ]; then \
		echo "$(GREEN)Found Arbitrum Sepolia deployment$(NC)"; \
		forge script script/ProxyVerification.s.sol:ProxyVerification --fork-url $(ARBITRUM_SEPOLIA_RPC_URL) -vv; \
	elif [ -f "deployments/bsc.json" ]; then \
		echo "$(GREEN)Found BSC mainnet deployment$(NC)"; \
		forge script script/ProxyVerification.s.sol:ProxyVerification --fork-url $(BSC_RPC_URL) -vv; \
	elif [ -f "deployments/sonic.json" ]; then \
		echo "$(GREEN)Found Sonic mainnet deployment$(NC)"; \
		forge script script/ProxyVerification.s.sol:ProxyVerification --fork-url $(SONIC_RPC_URL) -vv; \
	elif [ -f "deployments/arbitrum.json" ]; then \
		echo "$(GREEN)Found Arbitrum mainnet deployment$(NC)"; \
		forge script script/ProxyVerification.s.sol:ProxyVerification --fork-url $(ARBITRUM_RPC_URL) -vv; \
	else \
		echo "$(YELLOW)⚠️  No deployment found. Please deploy contracts first.$(NC)"; \
		echo "$(BLUE)Available deployment commands:$(NC)"; \
		echo "  make deploy-sepolia           # Deploy to Sepolia testnet"; \
		echo "  make deploy-sonic-testnet     # Deploy to Sonic testnet"; \
		echo "  make deploy-bsc-testnet       # Deploy to BSC testnet"; \
		echo "  make deploy-arbitrum-sepolia  # Deploy to Arbitrum Sepolia"; \
		echo ""; \
		echo "$(YELLOW)Or check what deployment files exist:$(NC)"; \
		ls -la deployments/ 2>/dev/null || echo "No deployments directory found"; \
	fi

# Verify all implementation contracts automatically
verify-implementations:
	@echo "$(BLUE)🔍 Verifying all implementation contracts...$(NC)"
	@if [ -f "deployments/sepolia.json" ]; then \
		echo "$(GREEN)Using Sepolia deployment$(NC)"; \
		forge script script/VerifyContracts.s.sol:VerifyContracts --fork-url $(SEPOLIA_RPC_URL) --ffi -vv; \
	elif [ -f "deployments/bsc-testnet.json" ]; then \
		echo "$(GREEN)Using BSC testnet deployment$(NC)"; \
		forge script script/VerifyContracts.s.sol:VerifyContracts --fork-url $(BSC_TESTNET_RPC_URL) --ffi -vv; \
	elif [ -f "deployments/sonic-testnet.json" ]; then \
		echo "$(GREEN)Using Sonic testnet deployment$(NC)"; \
		forge script script/VerifyContracts.s.sol:VerifyContracts --fork-url $(SONIC_TESTNET_RPC_URL) --ffi -vv; \
	elif [ -f "deployments/arbitrum-sepolia.json" ]; then \
		echo "$(GREEN)Using Arbitrum Sepolia deployment$(NC)"; \
		forge script script/VerifyContracts.s.sol:VerifyContracts --fork-url $(ARBITRUM_SEPOLIA_RPC_URL) --ffi -vv; \
	elif [ -f "deployments/bsc.json" ]; then \
		echo "$(GREEN)Using BSC mainnet deployment$(NC)"; \
		forge script script/VerifyContracts.s.sol:VerifyContracts --fork-url $(BSC_RPC_URL) --ffi -vv; \
	elif [ -f "deployments/sonic.json" ]; then \
		echo "$(GREEN)Using Sonic mainnet deployment$(NC)"; \
		forge script script/VerifyContracts.s.sol:VerifyContracts --fork-url $(SONIC_RPC_URL) --ffi -vv; \
	elif [ -f "deployments/arbitrum.json" ]; then \
		echo "$(GREEN)Using Arbitrum mainnet deployment$(NC)"; \
		forge script script/VerifyContracts.s.sol:VerifyContracts --fork-url $(ARBITRUM_RPC_URL) --ffi -vv; \
	else \
		echo "$(YELLOW)⚠️  No deployment found. Please deploy contracts first.$(NC)"; \
		echo "$(BLUE)Available deployment commands:$(NC)"; \
		echo "  make deploy-sepolia           # Deploy to Sepolia testnet"; \
		echo "  make deploy-sonic-testnet     # Deploy to Sonic testnet"; \
		echo "  make deploy-bsc-testnet       # Deploy to BSC testnet"; \
		echo "  make deploy-arbitrum-sepolia  # Deploy to Arbitrum Sepolia"; \
	fi

# Quick verification for specific contracts
verify-market-controller:
	@echo "$(BLUE)🔍 Verifying MarketController implementation...$(NC)"
	@$(call verify-implementation,marketControllerImpl,src/Market/MarketController.sol:MarketController)

verify-market:
	@echo "$(BLUE)🔍 Verifying Market implementation...$(NC)"
	@$(call verify-implementation,marketImpl,src/Market/Market.sol:MarketContract)

verify-vault:
	@echo "$(BLUE)🔍 Verifying Vault implementation...$(NC)"
	@$(call verify-implementation,vaultImpl,src/Vault/Vault.sol:Vault)

verify-position-tokens:
	@echo "$(BLUE)🔍 Verifying PositionTokens implementation...$(NC)"
	@$(call verify-implementation,positionTokensImpl,src/Token/PositionTokens.sol:PositionTokens)

verify-market-resolver:
	@echo "$(BLUE)🔍 Verifying MarketResolver implementation...$(NC)"
	@$(call verify-implementation,marketResolverImpl,src/Market/MarketResolver.sol:MarketResolver)

# Function to verify implementations
define verify-implementation
	@DEPLOYMENT_FILE=""; \
	RPC_URL=""; \
	API_KEY=""; \
	if [ -f "deployments/sepolia.json" ]; then \
		DEPLOYMENT_FILE="deployments/sepolia.json"; \
		RPC_URL="$(SEPOLIA_RPC_URL)"; \
		API_KEY="$(ETHERSCAN_API_KEY)"; \
	elif [ -f "deployments/bsc-testnet.json" ]; then \
		DEPLOYMENT_FILE="deployments/bsc-testnet.json"; \
		RPC_URL="$(BSC_TESTNET_RPC_URL)"; \
		API_KEY="$(BSCSCAN_API_KEY)"; \
	elif [ -f "deployments/bsc.json" ]; then \
		DEPLOYMENT_FILE="deployments/bsc.json"; \
		RPC_URL="$(BSC_RPC_URL)"; \
		API_KEY="$(BSCSCAN_API_KEY)"; \
	elif [ -f "deployments/arbitrum.json" ]; then \
		DEPLOYMENT_FILE="deployments/arbitrum.json"; \
		RPC_URL="$(ARBITRUM_RPC_URL)"; \
		API_KEY="$(ARBISCAN_API_KEY)"; \
	elif [ -f "deployments/arbitrum-sepolia.json" ]; then \
		DEPLOYMENT_FILE="deployments/arbitrum-sepolia.json"; \
		RPC_URL="$(ARBITRUM_SEPOLIA_RPC_URL)"; \
		API_KEY="$(ARBISCAN_API_KEY)"; \
	fi; \
	if [ "$$DEPLOYMENT_FILE" != "" ]; then \
		ADDRESS=$$(jq -r '.$(1)' $$DEPLOYMENT_FILE 2>/dev/null || echo ""); \
		if [ "$$ADDRESS" != "" ] && [ "$$ADDRESS" != "null" ]; then \
			CHAIN_ID=$$(cast chain-id --rpc-url $$RPC_URL 2>/dev/null || echo "1"); \
			echo "Verifying contract at $$ADDRESS"; \
			forge verify-contract $$ADDRESS $(2) \
				--chain-id $$CHAIN_ID \
				--etherscan-api-key $$API_KEY \
				--watch; \
		else \
			echo "$(RED)❌ $(1) address not found$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ No deployment file found$(NC)"; \
	fi
endef

# Check verification status
check-verification:
	@echo "$(BLUE)📋 Checking verification status...$(NC)"
	@echo "$(YELLOW)Implementation contracts:$(NC)"
	@$(call check-contract-verification,MarketController Implementation,marketControllerImpl)
	@$(call check-contract-verification,Market Implementation,marketImpl)
	@$(call check-contract-verification,Vault Implementation,vaultImpl)
	@$(call check-contract-verification,PositionTokens Implementation,positionTokensImpl)
	@$(call check-contract-verification,MarketResolver Implementation,marketResolverImpl)
	@echo "$(YELLOW)Proxy contracts:$(NC)"
	@$(call check-contract-verification,MarketController Proxy,marketController)
	@$(call check-contract-verification,Market Proxy,market)
	@$(call check-contract-verification,Vault Proxy,vault)

define check-contract-verification
	@DEPLOYMENT_FILE=""; \
	RPC_URL=""; \
	if [ -f "deployments/sepolia.json" ]; then \
		DEPLOYMENT_FILE="deployments/sepolia.json"; \
		RPC_URL="$(SEPOLIA_RPC_URL)"; \
	elif [ -f "deployments/bsc-testnet.json" ]; then \
		DEPLOYMENT_FILE="deployments/bsc-testnet.json"; \
		RPC_URL="$(BSC_TESTNET_RPC_URL)"; \
	elif [ -f "deployments/bsc.json" ]; then \
		DEPLOYMENT_FILE="deployments/bsc.json"; \
		RPC_URL="$(BSC_RPC_URL)"; \
	elif [ -f "deployments/arbitrum.json" ]; then \
		DEPLOYMENT_FILE="deployments/arbitrum.json"; \
		RPC_URL="$(ARBITRUM_RPC_URL)"; \
	fi; \
	if [ "$$DEPLOYMENT_FILE" != "" ]; then \
		ADDRESS=$$(jq -r '.$(2)' $$DEPLOYMENT_FILE 2>/dev/null || echo ""); \
		if [ "$$ADDRESS" != "" ] && [ "$$ADDRESS" != "null" ]; then \
			printf "$(1): "; \
			if cast code $$ADDRESS --rpc-url $$RPC_URL 2>/dev/null | grep -q "0x" && [ "$$(cast code $$ADDRESS --rpc-url $$RPC_URL 2>/dev/null)" != "0x" ]; then \
				echo "$(GREEN)✅ Deployed$(NC)"; \
			else \
				echo "$(RED)❌ Not found$(NC)"; \
			fi; \
		else \
			echo "$(1): $(YELLOW)⚠️  No deployment found$(NC)"; \
		fi; \
	else \
		echo "$(1): $(YELLOW)⚠️  No deployment file found$(NC)"; \
	fi
endef

# ============================================================================
# COMBINED COMMANDS (Deploy + Setup + Verify)
# ============================================================================

# Full deployment flow for testnets (Create2)
full-deploy-sepolia: deploy-sepolia setup-sepolia verify-addresses
	@echo "$(GREEN)✅ Sepolia deployment complete! Addresses verified for consistency.$(NC)"
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  make verification-guide  # Verify contracts on block explorer"
	@echo "  make deploy-<network>    # Deploy to more networks with same addresses"

full-deploy-sonic-testnet: deploy-sonic-testnet setup-sonic-testnet verify-addresses
	@echo "$(GREEN)✅ Sonic Testnet deployment complete! Addresses verified for consistency.$(NC)"
	@echo "$(BLUE)Next steps: make verification-guide$(NC)"

full-deploy-bsc-testnet: deploy-bsc-testnet setup-bsc-testnet verify-addresses
	@echo "$(GREEN)✅ BSC Testnet deployment complete! Addresses verified for consistency.$(NC)"
	@echo "$(BLUE)Next steps: make verification-guide$(NC)"

full-deploy-arbitrum-sepolia: deploy-arbitrum-sepolia setup-arbitrum-sepolia verify-addresses
	@echo "$(GREEN)✅ Arbitrum Sepolia deployment complete! Addresses verified for consistency.$(NC)"
	@echo "$(BLUE)Next steps: make verification-guide$(NC)"

# Full deployment flow for mainnets (with confirmations)
full-deploy-sonic: deploy-sonic setup-sonic verify-addresses
	@echo "$(GREEN)✅ Sonic Mainnet deployment complete! Addresses verified for consistency.$(NC)"
	@echo "$(BLUE)Next steps: make verification-guide$(NC)"

full-deploy-bsc: deploy-bsc setup-bsc verify-addresses
	@echo "$(GREEN)✅ BSC Mainnet deployment complete! Addresses verified for consistency.$(NC)"
	@echo "$(BLUE)Next steps: make verification-guide$(NC)"

full-deploy-arbitrum: deploy-arbitrum setup-arbitrum verify-addresses
	@echo "$(GREEN)✅ Arbitrum Mainnet deployment complete! Addresses verified for consistency.$(NC)"
	@echo "$(BLUE)Next steps: make verification-guide$(NC)"

# Multi-chain deployment workflow
deploy-all-testnets:
	@echo "$(BLUE)🌐 Deploying to all testnets with identical addresses...$(NC)"
	@echo "$(YELLOW)This will deploy to: Sepolia, Sonic Testnet, BSC Testnet, Arbitrum Sepolia$(NC)"
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ]
	@make deploy-sepolia
	@make deploy-sonic-testnet  
	@make deploy-bsc-testnet
	@make deploy-arbitrum-sepolia
	@make verify-addresses
	@echo "$(GREEN)🎉 Multi-chain deployment complete!$(NC)"

deploy-all-mainnets:
	@echo "$(RED)⚠️  MAINNET DEPLOYMENT TO ALL CHAINS$(NC)"
	@echo "$(YELLOW)This will deploy to: Sonic Mainnet, BSC Mainnet, Arbitrum Mainnet$(NC)"
	@echo "$(YELLOW)Using identical addresses across all chains$(NC)"
	@read -p "Type 'DEPLOY_TO_ALL_MAINNETS' to continue: " confirm && [ "$$confirm" = "DEPLOY_TO_ALL_MAINNETS" ]
	@make deploy-sonic
	@make deploy-bsc
	@make deploy-arbitrum
	@make verify-addresses
	@echo "$(GREEN)🎉 Multi-chain mainnet deployment complete!$(NC)"

# ============================================================================
# UPGRADE COMMANDS (UUPS Proxy Upgrades)
# ============================================================================

# Upgrade contracts on different networks
upgrade-sepolia:
	@echo "$(BLUE)🔄 Upgrading contracts on Sepolia...$(NC)"
	@echo "$(YELLOW)⚠️ This will upgrade contract implementations while preserving state$(NC)"
	@read -p "Continue with upgrade? (y/N): " confirm && [ "$$confirm" = "y" ]
	forge script script/Upgrade.s.sol:Upgrade \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

upgrade-arbitrum-sepolia:
	@echo "$(BLUE)🔄 Upgrading contracts on Arbitrum Sepolia...$(NC)"
	@echo "$(YELLOW)⚠️ This will upgrade contract implementations while preserving state$(NC)"
	@read -p "Continue with upgrade? (y/N): " confirm && [ "$$confirm" = "y" ]
	forge script script/Upgrade.s.sol:Upgrade \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ARBISCAN_API_KEY) \
		-vvvv

upgrade-sonic:
	@echo "$(RED)⚠️ SONIC MAINNET UPGRADE$(NC)"
	@echo "$(YELLOW)This will upgrade contracts on Sonic mainnet!$(NC)"
	@read -p "Type 'UPGRADE_SONIC_MAINNET' to continue: " confirm && [ "$$confirm" = "UPGRADE_SONIC_MAINNET" ]
	@echo "$(BLUE)🔄 Upgrading contracts on Sonic Mainnet...$(NC)"
	forge script script/Upgrade.s.sol:Upgrade \
		--rpc-url $(SONIC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(SONIC_API_KEY) \
		-vvvv

upgrade-sonic-testnet:
	@echo "$(BLUE)🔄 Upgrading contracts on Sonic Testnet...$(NC)"
	@echo "$(YELLOW)⚠️ This will upgrade contract implementations while preserving state$(NC)"
	@read -p "Continue with upgrade? (y/N): " confirm && [ "$$confirm" = "y" ]
	forge script script/Upgrade.s.sol:Upgrade \
		--rpc-url $(SONIC_TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(SONIC_API_KEY) \
		-vvvv

upgrade-bsc:
	@echo "$(RED)⚠️ BSC MAINNET UPGRADE$(NC)"
	@echo "$(YELLOW)This will upgrade contracts on BSC mainnet!$(NC)"
	@read -p "Type 'UPGRADE_BSC_MAINNET' to continue: " confirm && [ "$$confirm" = "UPGRADE_BSC_MAINNET" ]
	@echo "$(BLUE)🔄 Upgrading contracts on BSC Mainnet...$(NC)"
	forge script script/Upgrade.s.sol:Upgrade \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(BSCSCAN_API_KEY) \
		-vvvv

upgrade-bsc-testnet:
	@echo "$(BLUE)🔄 Upgrading contracts on BSC Testnet...$(NC)"
	@echo "$(YELLOW)⚠️ This will upgrade contract implementations while preserving state$(NC)"
	@read -p "Continue with upgrade? (y/N): " confirm && [ "$$confirm" = "y" ]
	forge script script/Upgrade.s.sol:Upgrade \
		--rpc-url $(BSC_TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(BSCSCAN_API_KEY) \
		-vvvv

upgrade-arbitrum:
	@echo "$(RED)⚠️ ARBITRUM MAINNET UPGRADE$(NC)"
	@echo "$(YELLOW)This will upgrade contracts on Arbitrum mainnet!$(NC)"
	@read -p "Type 'UPGRADE_ARBITRUM_MAINNET' to continue: " confirm && [ "$$confirm" = "UPGRADE_ARBITRUM_MAINNET" ]
	@echo "$(BLUE)🔄 Upgrading contracts on Arbitrum Mainnet...$(NC)"
	forge script script/Upgrade.s.sol:Upgrade \
		--rpc-url $(ARBITRUM_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ARBISCAN_API_KEY) \
		-vvvv

# Selective upgrades (upgrade only specific contracts)
upgrade-market-controller-only:
	@echo "$(BLUE)🔄 Upgrading only MarketController...$(NC)"
	@echo "$(YELLOW)Setting environment variables for selective upgrade$(NC)"
	UPGRADE_MARKET=false \
	UPGRADE_MARKET_RESOLVER=false \
	UPGRADE_POSITION_TOKENS=false \
	UPGRADE_VAULT=false \
	UPGRADE_MARKET_CONTROLLER=true \
	make upgrade-sepolia

upgrade-all-testnets:
	@echo "$(BLUE)🌍 Upgrading all testnet deployments...$(NC)"
	@echo "$(YELLOW)This will upgrade: Sepolia, Arbitrum Sepolia$(NC)"
	@read -p "Continue with all testnet upgrades? (y/N): " confirm && [ "$$confirm" = "y" ]
	@make upgrade-sepolia
	@make upgrade-arbitrum-sepolia
	@echo "$(GREEN)🎉 All testnet upgrades complete!$(NC)"

# Check upgrade readiness
check-upgrade-readiness:
	@echo "$(BLUE)🔍 Checking upgrade readiness...$(NC)"
	@echo "$(YELLOW)Current deployment status:$(NC)"
	@if [ -f "deployments/sepolia.json" ]; then \
		echo "$(GREEN)✅ Sepolia deployment found$(NC)"; \
		CONTROLLER=$$(jq -r '.marketController' deployments/sepolia.json); \
		echo "  MarketController: $$CONTROLLER"; \
	fi
	@if [ -f "deployments/arbitrum-sepolia.json" ]; then \
		echo "$(GREEN)✅ Arbitrum Sepolia deployment found$(NC)"; \
		CONTROLLER=$$(jq -r '.marketController' deployments/arbitrum-sepolia.json); \
		echo "  MarketController: $$CONTROLLER"; \
	fi
	@echo "$(YELLOW)Checking if deployer is owner...$(NC)"
	@echo "$(BLUE)Ready for upgrade!$(NC)"

# View upgrade history
view-upgrade-history:
	@echo "$(BLUE)📜 Upgrade History$(NC)"
	@echo "$(YELLOW)Recent upgrade files:$(NC)"
	@ls -la deployments/*upgrade*.json 2>/dev/null || echo "$(YELLOW)No upgrade history found$(NC)"

# ============================================================================
# TESTUSDC DEPLOYMENT COMMANDS (Add these to your existing Makefile)
# ============================================================================

# Deploy TestUSDC to Sepolia
deploy-test-usdc-sepolia: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying TestUSDC to Sepolia...$(NC)"
	@echo "$(YELLOW)📍 Address will be deterministic and consistent across chains$(NC)"
	forge script script/DeployTestUSDC.s.sol:DeployTestUSDC \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--gas-price 2000000000 \
		--legacy \
		-vvvv

# Deploy TestUSDC to Arbitrum Sepolia
deploy-test-usdc-arbitrum-sepolia: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying TestUSDC to Arbitrum Sepolia...$(NC)"
	@echo "$(YELLOW)📍 Address will match Sepolia if using same deployer$(NC)"
	forge script script/DeployTestUSDC.s.sol:DeployTestUSDC \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ARBISCAN_API_KEY) \
		--legacy \
		-vvvv

# Deploy TestUSDC to Sonic Testnet
deploy-test-usdc-sonic-testnet: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying TestUSDC to Sonic Testnet...$(NC)"
	forge script script/DeployTestUSDC.s.sol:DeployTestUSDC \
		--rpc-url $(SONIC_TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(SONIC_API_KEY) \
		--gas-price 1000000000 \
		--legacy \
		-vvvv

# Deploy TestUSDC to BSC Testnet
deploy-test-usdc-bsc-testnet: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying TestUSDC to BSC Testnet...$(NC)"
	forge script script/DeployTestUSDC.s.sol:DeployTestUSDC \
		--rpc-url $(BSC_TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(BSCSCAN_API_KEY) \
		--gas-price 10000000000 \
		--legacy \
		-vvvv

# Deploy TestUSDC to local network
deploy-test-usdc-local: create-deployments-dir
	@echo "$(BLUE)🚀 Deploying TestUSDC to Local Anvil Network...$(NC)"
	forge script script/DeployTestUSDC.s.sol:DeployTestUSDC \
		--rpc-url http://localhost:8545 \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		-vvvv

# Verify TestUSDC addresses are consistent across chains
verify-test-usdc-addresses:
	@echo "$(BLUE)🔍 Verifying TestUSDC address consistency across chains...$(NC)"
	@if [ -f "deployments/test-usdc-sepolia.json" ] && [ -f "deployments/test-usdc-arbitrum-sepolia.json" ]; then \
		SEPOLIA_ADDR=$$(jq -r '.testUSDC' deployments/test-usdc-sepolia.json); \
		ARBITRUM_ADDR=$$(jq -r '.testUSDC' deployments/test-usdc-arbitrum-sepolia.json); \
		echo "Sepolia TestUSDC:         $$SEPOLIA_ADDR"; \
		echo "Arbitrum Sepolia TestUSDC: $$ARBITRUM_ADDR"; \
		if [ "$$SEPOLIA_ADDR" = "$$ARBITRUM_ADDR" ]; then \
			echo "$(GREEN)✅ Addresses match across chains!$(NC)"; \
		else \
			echo "$(RED)❌ Addresses do not match!$(NC)"; \
		fi; \
	else \
		echo "$(YELLOW)⚠️ Deploy to both networks first$(NC)"; \
	fi

# Verify TestUSDC contract on block explorer
verify-test-usdc-sepolia:
	@echo "$(BLUE)🔍 Verifying TestUSDC on Sepolia...$(NC)"
	@if [ -f "deployments/test-usdc-sepolia.json" ]; then \
		ADDR=$$(jq -r '.testUSDC' deployments/test-usdc-sepolia.json); \
		forge verify-contract $$ADDR src/Mocks/TestUSDC.sol:TestUSDC \
			--chain-id 11155111 \
			--etherscan-api-key $(ETHERSCAN_API_KEY) \
			--constructor-args $$(cast abi-encode "constructor(string,string,address)" "Test USDC" "TUSDC" $$(cast wallet address --private-key $(PRIVATE_KEY))) \
			--watch; \
	else \
		echo "$(RED)❌ TestUSDC not deployed on Sepolia$(NC)"; \
	fi

verify-test-usdc-arbitrum-sepolia:
	@echo "$(BLUE)🔍 Verifying TestUSDC on Arbitrum Sepolia...$(NC)"
	@if [ -f "deployments/test-usdc-arbitrum-sepolia.json" ]; then \
		ADDR=$$(jq -r '.testUSDC' deployments/test-usdc-arbitrum-sepolia.json); \
		forge verify-contract $$ADDR src/Mocks/TestUSDC.sol:TestUSDC \
			--chain-id 421614 \
			--etherscan-api-key $(ARBISCAN_API_KEY) \
			--constructor-args $$(cast abi-encode "constructor(string,string,address)" "Test USDC" "TUSDC" $$(cast wallet address --private-key $(PRIVATE_KEY))) \
			--watch; \
	else \
		echo "$(RED)❌ TestUSDC not deployed on Arbitrum Sepolia$(NC)"; \
	fi

# List TestUSDC deployments
list-test-usdc-deployments:
	@echo "$(BLUE)📋 Available TestUSDC deployments:$(NC)"
	@ls -la deployments/test-usdc-*.json 2>/dev/null || echo "$(YELLOW)No TestUSDC deployments found$(NC)"


# ============================================================================
# UTILITY COMMANDS
# ============================================================================

# Check network connectivity
check-networks:
	@echo "$(BLUE)🌐 Checking network connectivity...$(NC)"
	@echo "$(YELLOW)Sepolia:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $(SEPOLIA_RPC_URL) | grep -q "0xaa36a7" && echo "$(GREEN)✅ Connected$(NC)" || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)Sonic Mainnet:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $(SONIC_RPC_URL) | grep -q "0x92" && echo "$(GREEN)✅ Connected$(NC)" || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)Sonic Testnet:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $(SONIC_TESTNET_RPC_URL) | grep -q "0xdeae" && echo "$(GREEN)✅ Connected$(NC)" || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)BSC Mainnet:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $(BSC_RPC_URL) | grep -q "0x38" && echo "$(GREEN)✅ Connected$(NC)" || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)BSC Testnet:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $(BSC_TESTNET_RPC_URL) | grep -q "0x61" && echo "$(GREEN)✅ Connected$(NC)" || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)Arbitrum Mainnet:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $(ARBITRUM_RPC_URL) | grep -q "0xa4b1" && echo "$(GREEN)✅ Connected$(NC)" || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)Arbitrum Sepolia:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $(ARBITRUM_SEPOLIA_RPC_URL) | grep -q "0x66eee" && echo "$(GREEN)✅ Connected$(NC)" || echo "$(RED)❌ Failed$(NC)"

# Check balances
check-balance:
	@echo "$(BLUE)💰 Checking deployer balance...$(NC)"
	@echo "$(YELLOW)Sepolia:$(NC)"
	@cast balance $(shell cast wallet address --private-key $(PRIVATE_KEY)) --rpc-url $(SEPOLIA_RPC_URL) --ether || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)Sonic Mainnet:$(NC)"
	@cast balance $(shell cast wallet address --private-key $(PRIVATE_KEY)) --rpc-url $(SONIC_RPC_URL) --ether || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)BSC Mainnet:$(NC)"
	@cast balance $(shell cast wallet address --private-key $(PRIVATE_KEY)) --rpc-url $(BSC_RPC_URL) --ether || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)Arbitrum Mainnet:$(NC)"
	@cast balance $(shell cast wallet address --private-key $(PRIVATE_KEY)) --rpc-url $(ARBITRUM_RPC_URL) --ether || echo "$(RED)❌ Failed$(NC)"

# Check gas prices
check-gas:
	@echo "$(BLUE)⛽ Checking current gas prices...$(NC)"
	@echo "$(YELLOW)Sepolia:$(NC)"
	@cast gas-price --rpc-url $(SEPOLIA_RPC_URL) | awk '{print $1/1000000000 " gwei"}' || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)Sonic Mainnet:$(NC)"
	@cast gas-price --rpc-url $(SONIC_RPC_URL) | awk '{print $1/1000000000 " gwei"}' || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)BSC Mainnet:$(NC)"
	@cast gas-price --rpc-url $(BSC_RPC_URL) | awk '{print $1/1000000000 " gwei"}' || echo "$(RED)❌ Failed$(NC)"
	@echo "$(YELLOW)Arbitrum Mainnet:$(NC)"
	@cast gas-price --rpc-url $(ARBITRUM_RPC_URL) | awk '{print $1/1000000000 " gwei"}' || echo "$(RED)❌ Failed$(NC)"

# List deployments
list-deployments:
	@echo "$(BLUE)📋 Available deployments:$(NC)"
	@ls -la deployments/ 2>/dev/null || echo "$(YELLOW)No deployments found$(NC)"

# Coverage report
coverage:
	forge coverage

# Generate coverage report in lcov format
coverage-report:
	forge coverage --report lcov

# Gas optimization check
gas-check:
	forge test --match-test $(function) --gas-report

# Environment check
check-env:
	@echo "$(BLUE)🔧 Checking environment variables...$(NC)"
	@echo "$(YELLOW)Required variables:$(NC)"
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "$(RED)❌ PRIVATE_KEY not set$(NC)"; else echo "$(GREEN)✅ PRIVATE_KEY set$(NC)"; fi
	@echo "$(YELLOW)RPC URLs:$(NC)"
	@if [ -z "$(SEPOLIA_RPC_URL)" ]; then echo "$(RED)❌ SEPOLIA_RPC_URL not set$(NC)"; else echo "$(GREEN)✅ SEPOLIA_RPC_URL set$(NC)"; fi
	@if [ -z "$(BSC_TESTNET_RPC_URL)" ]; then echo "$(RED)❌ BSC_TESTNET_RPC_URL not set$(NC)"; else echo "$(GREEN)✅ BSC_TESTNET_RPC_URL set$(NC)"; fi
	@if [ -z "$(SONIC_TESTNET_RPC_URL)" ]; then echo "$(RED)❌ SONIC_TESTNET_RPC_URL not set$(NC)"; else echo "$(GREEN)✅ SONIC_TESTNET_RPC_URL set$(NC)"; fi
	@if [ -z "$(ARBITRUM_SEPOLIA_RPC_URL)" ]; then echo "$(RED)❌ ARBITRUM_SEPOLIA_RPC_URL not set$(NC)"; else echo "$(GREEN)✅ ARBITRUM_SEPOLIA_RPC_URL set$(NC)"; fi
	@echo "$(YELLOW)API Keys:$(NC)"
	@if [ -z "$(ETHERSCAN_API_KEY)" ]; then echo "$(RED)❌ ETHERSCAN_API_KEY not set$(NC)"; else echo "$(GREEN)✅ ETHERSCAN_API_KEY set$(NC)"; fi
	@if [ -z "$(BSCSCAN_API_KEY)" ]; then echo "$(RED)❌ BSCSCAN_API_KEY not set$(NC)"; else echo "$(GREEN)✅ BSCSCAN_API_KEY set$(NC)"; fi
	@if [ -z "$(ARBISCAN_API_KEY)" ]; then echo "$(RED)❌ ARBISCAN_API_KEY not set$(NC)"; else echo "$(GREEN)✅ ARBISCAN_API_KEY set$(NC)"; fi

# ============================================================================
# HELP
# ============================================================================

help:
	@echo "$(BLUE)🛠️ Prediction Market Deployment Commands (Create2 Enabled)$(NC)"
	@echo ""
	@echo "$(GREEN)📦 Setup:$(NC)"
	@echo "  make install              - Install dependencies"
	@echo "  make build                - Compile contracts"
	@echo "  make test                 - Run tests"
	@echo "  make clean                - Clean build artifacts"
	@echo "  make check-env            - Check environment variables"
	@echo ""
	@echo "$(GREEN)🔮 Address Prediction (Create2):$(NC)"
	@echo "  make predict-addresses    - Predict deployment addresses (same on all chains)"
	@echo "  make verify-addresses     - Verify address consistency across deployed chains"
	@echo ""
	@echo "$(GREEN)🚀 Single Network Deployment:$(NC)"
	@echo "  make deploy-sepolia       - Deploy to Sepolia testnet"
	@echo "  make deploy-sonic-testnet - Deploy to Sonic testnet"
	@echo "  make deploy-bsc-testnet   - Deploy to BSC testnet"
	@echo "  make deploy-arbitrum-sepolia - Deploy to Arbitrum Sepolia"
	@echo "  make deploy-sonic         - Deploy to Sonic mainnet (⚠️ with confirmation)"
	@echo "  make deploy-bsc           - Deploy to BSC mainnet (⚠️ with confirmation)"
	@echo "  make deploy-arbitrum      - Deploy to Arbitrum mainnet (⚠️ with confirmation)"
	@echo ""
	@echo "$(GREEN)🌐 Multi-Chain Deployment:$(NC)"
	@echo "  make deploy-all-testnets  - Deploy to all testnets (identical addresses)"
	@echo "  make deploy-all-mainnets  - Deploy to all mainnets (⚠️ with confirmation)"
	@echo ""
	@echo "$(GREEN)🔧 Contract Verification:$(NC)"
	@echo "  make verification-guide   - Get verification commands and proxy setup guide"
	@echo "  make verify-implementations - Verify all implementation contracts"
	@echo "  make check-verification   - Check current verification status"
	@echo ""
	@echo "$(GREEN)🔄 Contract Upgrades (UUPS):$(NC)"
	@echo "  make upgrade-sepolia      - Upgrade contracts on Sepolia testnet"
	@echo "  make upgrade-arbitrum-sepolia - Upgrade contracts on Arbitrum Sepolia"
	@echo "  make upgrade-sonic-testnet - Upgrade contracts on Sonic testnet"
	@echo "  make upgrade-bsc-testnet  - Upgrade contracts on BSC testnet"
	@echo "  make upgrade-sonic        - Upgrade contracts on Sonic mainnet (⚠️ with confirmation)"
	@echo "  make upgrade-bsc          - Upgrade contracts on BSC mainnet (⚠️ with confirmation)"
	@echo "  make upgrade-arbitrum     - Upgrade contracts on Arbitrum mainnet (⚠️ with confirmation)"
	@echo "  make upgrade-all-testnets - Upgrade all testnet deployments"
	@echo "  make check-upgrade-readiness - Verify upgrade prerequisites"
	@echo "  make view-upgrade-history - View past upgrade history"
	@echo ""
	help-test-usdc:
	@echo "$(GREEN)🪙 TestUSDC Deployment:$(NC)"
	@echo "  make deploy-test-usdc-sepolia              - Deploy TestUSDC to Sepolia"
	@echo "  make deploy-test-usdc-arbitrum-sepolia     - Deploy TestUSDC to Arbitrum Sepolia"
	@echo "  make deploy-test-usdc-sonic-testnet        - Deploy TestUSDC to Sonic Testnet"
	@echo "  make deploy-test-usdc-bsc-testnet          - Deploy TestUSDC to BSC Testnet"
	@echo ""
	@echo "$(GREEN)🔍 TestUSDC Verification:$(NC)"
	@echo "  make verify-test-usdc-sepolia              - Verify TestUSDC on Sepolia"
	@echo "  make verify-test-usdc-arbitrum-sepolia     - Verify TestUSDC on Arbitrum Sepolia"
	@echo "  make verify-test-usdc-addresses            - Verify address consistency"
	@echo ""
	@echo "$(GREEN)📊 TestUSDC Status:$(NC)"
	@echo "  make list-test-usdc-deployments            - List deployment files"
	@echo ""
	@echo "$(GREEN)⚙️ Setup & Management:$(NC)"
	@echo "  make setup-<network>      - Run post-deployment setup"
	@echo "  make full-deploy-<network> - Deploy + Setup + Verify"
	@echo ""
	@echo "$(GREEN)🔧 Utilities:$(NC)"
	@echo "  make check-networks       - Check RPC connectivity"
	@echo "  make check-balance        - Check deployer balances"
	@echo "  make check-gas            - Check current gas prices"
	@echo "  make list-deployments     - List deployment files"
	@echo "  make check-env            - Check environment setup"
	@echo ""
	@echo "$(GREEN)📋 Create2 Quick Start Examples:$(NC)"
	@echo "  make check-env                     # Check your environment first"
	@echo "  make predict-addresses             # See what addresses you'll get"
	@echo "  make full-deploy-sepolia           # Deploy to first testnet"
	@echo "  make deploy-sonic-testnet          # Deploy to second testnet (same addresses!)"
	@echo "  make verify-addresses              # Confirm addresses match"
	@echo ""
	@echo "$(GREEN)🔄 UUPS Upgrade Examples:$(NC)"
	@echo "  make check-upgrade-readiness       # Check if ready to upgrade"
	@echo "  make upgrade-sepolia               # Upgrade testnet contracts"
	@echo "  make upgrade-all-testnets          # Upgrade all testnet deployments"
	@echo "  make view-upgrade-history          # Check upgrade history"
	@echo ""
	@echo "$(YELLOW)💡 Create2 Benefits:$(NC)"
	@echo "  ✅ Same contract addresses on ALL supported chains"
	@echo "  ✅ Easier frontend integration (one config for all chains)"
	@echo "  ✅ Better user experience (familiar addresses everywhere)"
	@echo "  ✅ Simplified multi-chain operations"
	@echo ""
	@echo "$(YELLOW)🌐 Supported Networks:$(NC)"
	@echo "  • Ethereum (Mainnet & Sepolia)"
	@echo "  • Arbitrum (One & Sepolia)"  
	@echo "  • BSC (Mainnet & Testnet)"
	@echo "  • Sonic (Mainnet & Testnet)"
	@echo "  • Polygon, Base, Optimism"
	@echo ""
	@echo "$(YELLOW)🔑 First time setup:$(NC)"
	@echo "  1. Copy .env.example to .env and fill in your keys"
	@echo "  2. Run 'make check-env' to verify setup"
	@echo "  3. Run 'make predict-addresses' to see your future addresses"
	@echo "  4. Run 'make full-deploy-sepolia' to deploy to first testnet"
	@echo "  5. Run 'make deploy-sonic-testnet' to get same addresses on another chain"
	@echo "  6. Run 'make verify-addresses' to confirm consistency"

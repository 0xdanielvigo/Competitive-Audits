// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 * @title ProxyVerification
 * @notice Script to help with proxy contract verification on block explorers
 * @dev Provides commands and guidance for UUPS proxy verification
 */
contract ProxyVerification is Script {
    using stdJson for string;

    struct DeployedContracts {
        address collateralToken;
        address marketImpl;
        address marketResolverImpl;
        address positionTokensImpl;
        address vaultImpl;
        address marketControllerImpl;
        address market;
        address marketResolver;
        address positionTokens;
        address vault;
        address marketController;
    }

    function run() external view {
        string memory network = getNetworkName();
        console.log("=== UUPS Proxy Verification Guide ===");
        console.log("Network:", network);
        
        // Load deployed contract addresses
        DeployedContracts memory contracts = loadDeployedContracts();
        
        // Generate verification commands
        generateVerificationCommands(contracts);
        
        // Provide manual verification steps
        provideManualVerificationSteps(contracts);
        
        // Show interaction examples
        showInteractionExamples(contracts);
    }

    function loadDeployedContracts() internal view returns (DeployedContracts memory contracts) {
        string memory networkName = getNetworkName();
        string memory fileName = string.concat("deployments/", networkName, ".json");
        
        string memory json = vm.readFile(fileName);
        
        contracts.collateralToken = json.readAddress(".collateralToken");
        contracts.marketImpl = json.readAddress(".marketImpl");
        contracts.marketResolverImpl = json.readAddress(".marketResolverImpl");
        contracts.positionTokensImpl = json.readAddress(".positionTokensImpl");
        contracts.vaultImpl = json.readAddress(".vaultImpl");
        contracts.marketControllerImpl = json.readAddress(".marketControllerImpl");
        contracts.market = json.readAddress(".market");
        contracts.marketResolver = json.readAddress(".marketResolver");
        contracts.positionTokens = json.readAddress(".positionTokens");
        contracts.vault = json.readAddress(".vault");
        contracts.marketController = json.readAddress(".marketController");
    }

    function generateVerificationCommands(DeployedContracts memory contracts) internal view {
        console.log("\n=== Forge Verification Commands ===");
        console.log("Run these commands to verify implementation contracts:");
        console.log("");
        
        string memory apiKeyFlag = getApiKeyFlag();
        uint256 chainId = block.chainid;
        
        // MarketContract Implementation
        console.log("# MarketContract Implementation");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(contracts.marketImpl),
            " src/Market/Market.sol:MarketContract",
            " --chain-id ", vm.toString(chainId),
            " ", apiKeyFlag,
            " --watch"
        ));
        console.log("");
        
        // MarketResolver Implementation
        console.log("# MarketResolver Implementation");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(contracts.marketResolverImpl),
            " src/Market/MarketResolver.sol:MarketResolver",
            " --chain-id ", vm.toString(chainId),
            " ", apiKeyFlag,
            " --watch"
        ));
        console.log("");
        
        // PositionTokens Implementation
        console.log("# PositionTokens Implementation");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(contracts.positionTokensImpl),
            " src/Token/PositionTokens.sol:PositionTokens",
            " --chain-id ", vm.toString(chainId),
            " ", apiKeyFlag,
            " --watch"
        ));
        console.log("");
        
        // Vault Implementation
        console.log("# Vault Implementation");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(contracts.vaultImpl),
            " src/Vault/Vault.sol:Vault",
            " --chain-id ", vm.toString(chainId),
            " ", apiKeyFlag,
            " --watch"
        ));
        console.log("");
        
        // MarketController Implementation
        console.log("# MarketController Implementation");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(contracts.marketControllerImpl),
            " src/Market/MarketController.sol:MarketController",
            " --chain-id ", vm.toString(chainId),
            " ", apiKeyFlag,
            " --watch"
        ));
        console.log("");
    }

    function provideManualVerificationSteps(DeployedContracts memory contracts) internal view {
        string memory explorerUrl = getExplorerBaseUrl();
        
        console.log("=== Manual Proxy Verification Steps ===");
        console.log("After verifying implementations, verify proxies manually:");
        console.log("");
        
        console.log("1. MarketController Proxy (MAIN CONTRACT):");
        console.log(string.concat("   URL: ", explorerUrl, "/address/", vm.toString(contracts.marketController)));
        console.log(string.concat("   Implementation: ", vm.toString(contracts.marketControllerImpl)));
        console.log("  Steps:");
        console.log("  a) Go to proxy address");
        console.log("  b) Click 'Contract' tab");
        console.log("  c) Click 'More Options' and then 'Is this a proxy?'");
        console.log("  d) Select 'Verify' and enter implementation address");
        console.log("");
        
        console.log("2. Market Proxy:");
        console.log(string.concat("   URL: ", explorerUrl, "/address/", vm.toString(contracts.market)));
        console.log(string.concat("   Implementation: ", vm.toString(contracts.marketImpl)));
        console.log("");
        
        console.log("3. Vault Proxy:");
        console.log(string.concat("   URL: ", explorerUrl, "/address/", vm.toString(contracts.vault)));
        console.log(string.concat("   Implementation: ", vm.toString(contracts.vaultImpl)));
        console.log("");
        
        console.log("4. PositionTokens Proxy:");
        console.log(string.concat("   URL: ", explorerUrl, "/address/", vm.toString(contracts.positionTokens)));
        console.log(string.concat("   Implementation: ", vm.toString(contracts.positionTokensImpl)));
        console.log("");
        
        console.log("5. MarketResolver Proxy:");
        console.log(string.concat("   URL: ", explorerUrl, "/address/", vm.toString(contracts.marketResolver)));
        console.log(string.concat("   Implementation: ", vm.toString(contracts.marketResolverImpl)));
        console.log("");
    }

    function showInteractionExamples(DeployedContracts memory contracts) internal view {
        console.log("=== Contract Interaction Examples ===");
        console.log("After verification, you can interact via block explorer:");
        console.log("");
        
        console.log("MarketController (Main Entry Point):");
        console.log(string.concat("   ", vm.toString(contracts.marketController)));
        console.log("   Available functions:");
        console.log(" - createMarket(questionId, outcomeCount, resolutionTime)");
        console.log(" - placeBet(questionId, outcome, amount)");
        console.log(" - splitPosition(questionId, amount)");
        console.log(" - claimWinnings(questionId, epoch, outcome, merkleProof)");
        console.log(" - setGlobalTradingPaused(paused)");
        console.log(" - setMarketTradingPaused(questionId, paused)");
        console.log("");
        
        console.log("Vault (Collateral Management):");
        console.log(string.concat("   ", vm.toString(contracts.vault)));
        console.log("   Available functions:");
        console.log(" - depositCollateral(amount)");
        console.log(" - withdrawCollateral(amount)");
        console.log(" - getAvailableBalance(user)");
        console.log("");
        
        console.log("Market (Market Info):");
        console.log(string.concat("   ", vm.toString(contracts.market)));
        console.log("   Available functions:");
        console.log(" - getOutcomeCount(questionId)");
        console.log(" - getCurrentEpoch(questionId)");
        console.log(" - isMarketOpen(questionId)");
        console.log(" - getMarketExists(questionId)");
        console.log("");
        
        console.log("PositionTokens (ERC1155 Tokens):");
        console.log(string.concat("   ", vm.toString(contracts.positionTokens)));
        console.log("   Available functions:");
        console.log(" - balanceOf(account, tokenId)");
        console.log(" - safeTransferFrom(from, to, tokenId, amount, data)");
        console.log(" - setApprovalForAll(operator, approved)");
        console.log("");
        
        console.log("MarketResolver (Market Resolution):");
        console.log(string.concat("   ", vm.toString(contracts.marketResolver)));
        console.log("   Available functions:");
        console.log(" - resolveMarketEpoch(questionId, epoch, outcomeCount, merkleRoot)");
        console.log(" - verifyProof(conditionId, outcome, merkleProof)");
        console.log(" - getResolutionStatus(conditionId)");
        console.log("");
    }

    function getApiKeyFlag() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1 || chainId == 11155111) {
            return "--etherscan-api-key $ETHERSCAN_API_KEY";
        } else if (chainId == 56 || chainId == 97) {
            return "--etherscan-api-key $BSCSCAN_API_KEY";
        } else if (chainId == 137 || chainId == 80001) {
            return "--etherscan-api-key $POLYGONSCAN_API_KEY";
        } else if (chainId == 42161 || chainId == 421614) {
            return "--etherscan-api-key $ARBISCAN_API_KEY";
        } else if (chainId == 10 || chainId == 11155420) {
            return "--etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY";
        } else if (chainId == 8453 || chainId == 84532) {
            return "--etherscan-api-key $BASESCAN_API_KEY";
        }
        
        return "--etherscan-api-key $ETHERSCAN_API_KEY";
    }

    function getExplorerBaseUrl() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) return "https://etherscan.io";
        if (chainId == 11155111) return "https://sepolia.etherscan.io";
        if (chainId == 56) return "https://bscscan.com";
        if (chainId == 97) return "https://testnet.bscscan.com";
        if (chainId == 137) return "https://polygonscan.com";
        if (chainId == 80001) return "https://mumbai.polygonscan.com";
        if (chainId == 42161) return "https://arbiscan.io";
        if (chainId == 421614) return "https://sepolia.arbiscan.io";
        if (chainId == 10) return "https://optimistic.etherscan.io";
        if (chainId == 11155420) return "https://sepolia-optimism.etherscan.io";
        if (chainId == 8453) return "https://basescan.org";
        if (chainId == 84532) return "https://sepolia.basescan.org";
        if (chainId == 146) return "https://sonicscan.org";
        if (chainId == 57054) return "https://testnet.sonicscan.org";
        
        return "https://sepolia.etherscan.io";
    }

    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) return "mainnet";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 17000) return "holesky";
        if (chainId == 137) return "polygon";
        if (chainId == 80001) return "mumbai";
        if (chainId == 42161) return "arbitrum";
        if (chainId == 421614) return "arbitrum-sepolia";
        if (chainId == 10) return "optimism";
        if (chainId == 11155420) return "optimism-sepolia";
        if (chainId == 8453) return "base";
        if (chainId == 84532) return "base-sepolia";
        if (chainId == 56) return "bsc";
        if (chainId == 97) return "bsc-testnet";
        if (chainId == 146) return "sonic";
        if (chainId == 57054) return "sonic-testnet";
        if (chainId == 31337) return "anvil";
        
        return string.concat("chain-", vm.toString(chainId));
    }
}

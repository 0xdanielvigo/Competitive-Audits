// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 * @title VerifyAddresses
 * @notice Verify that deployed addresses match across multiple chains
 * @dev Compares deployed addresses across different networks to ensure Create2 worked correctly
 */
contract VerifyAddresses is Script {
    using stdJson for string;

    struct DeployedContracts {
        string networkName;
        uint256 chainId;
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
        bool deterministicDeployment;
    }

    string[] supportedNetworks = [
        "mainnet",
        "sepolia", 
        "arbitrum",
        "arbitrum-sepolia",
        "bsc",
        "bsc-testnet",
        "sonic",
        "sonic-testnet",
        "polygon",
        "base",
        "optimism"
    ];

    function run() external view {
        console.log("=== Cross-Chain Address Verification ===");
        console.log("Checking deployed addresses across all networks...");
        
        DeployedContracts[] memory deployments = loadAllDeployments();
        
        if (deployments.length == 0) {
            console.log("No deployments found. Deploy to at least one network first.");
            return;
        }
        
        if (deployments.length == 1) {
            console.log("Only one deployment found. Deploy to more networks to verify consistency.");
            logSingleDeployment(deployments[0]);
            return;
        }
        
        console.log("Found", deployments.length, "deployments. Verifying address consistency...");
        
        bool allMatch = verifyAddressConsistency(deployments);
        
        if (allMatch) {
            console.log("\nSUCCESS: All addresses match across chains!");
            console.log("Create2 deployment worked perfectly");
            logUniversalAddresses(deployments[0]);
        } else {
            console.log("\nERROR: Address mismatch detected!");
            console.log("This indicates Create2 deployment issues or different deployer addresses");
        }
        
        generateDeploymentReport(deployments);
    }

    function loadAllDeployments() internal view returns (DeployedContracts[] memory) {
        DeployedContracts[] memory tempDeployments = new DeployedContracts[](supportedNetworks.length);
        uint256 foundCount = 0;
        
        for (uint256 i = 0; i < supportedNetworks.length; i++) {
            string memory networkName = supportedNetworks[i];
            string memory fileName = string.concat("deployments/", networkName, ".json");
            
            try vm.readFile(fileName) returns (string memory json) {
                DeployedContracts memory deployment;
                deployment.networkName = networkName;
                
                deployment.chainId = json.readUint(".chainId");
                deployment.collateralToken = json.readAddress(".collateralToken");
                deployment.marketImpl = json.readAddress(".marketImpl");
                deployment.marketResolverImpl = json.readAddress(".marketResolverImpl");
                deployment.positionTokensImpl = json.readAddress(".positionTokensImpl");
                deployment.vaultImpl = json.readAddress(".vaultImpl");
                deployment.marketControllerImpl = json.readAddress(".marketControllerImpl");
                deployment.market = json.readAddress(".market");
                deployment.marketResolver = json.readAddress(".marketResolver");
                deployment.positionTokens = json.readAddress(".positionTokens");
                deployment.vault = json.readAddress(".vault");
                deployment.marketController = json.readAddress(".marketController");
                
                // Check if this was a deterministic deployment
                deployment.deterministicDeployment = json.readBool(".deterministicDeployment");
                
                tempDeployments[foundCount] = deployment;
                foundCount++;
                
                console.log("Loaded deployment for", networkName);
                console.log("Chain ID:", deployment.chainId);
            } catch {
                // File not found, skip this network
            }
        }
        
        // Create properly sized array
        DeployedContracts[] memory deployments = new DeployedContracts[](foundCount);
        for (uint256 i = 0; i < foundCount; i++) {
            deployments[i] = tempDeployments[i];
        }
        
        return deployments;
    }

    function verifyAddressConsistency(DeployedContracts[] memory deployments) internal pure returns (bool) {
        if (deployments.length < 2) return true;
        
        console.log("\n--- Address Consistency Check ---");
        
        DeployedContracts memory referenceDeployment = deployments[0];
        bool allMatch = true;
        
        console.log("Using", referenceDeployment.networkName, "as reference");
        
        for (uint256 i = 1; i < deployments.length; i++) {
            DeployedContracts memory current = deployments[i];
            console.log("\nComparing with", current.networkName, ":");
            
            bool networkMatch = true;
            
            // Check implementation contracts
            if (current.marketImpl != referenceDeployment.marketImpl) {
                console.log("MarketImpl mismatch");
                networkMatch = false;
            } else {
                console.log("MarketImpl matches");
            }
            
            if (current.marketResolverImpl != referenceDeployment.marketResolverImpl) {
                console.log("MarketResolverImpl mismatch");
                networkMatch = false;
            } else {
                console.log("MarketResolverImpl matches");
            }
            
            if (current.positionTokensImpl != referenceDeployment.positionTokensImpl) {
                console.log("PositionTokensImpl mismatch");
                networkMatch = false;
            } else {
                console.log("PositionTokensImpl matches");
            }
            
            if (current.vaultImpl != referenceDeployment.vaultImpl) {
                console.log("VaultImpl mismatch");
                networkMatch = false;
            } else {
                console.log("VaultImpl matches");
            }
            
            if (current.marketControllerImpl != referenceDeployment.marketControllerImpl) {
                console.log("MarketControllerImpl mismatch");
                networkMatch = false;
            } else {
                console.log("MarketControllerImpl matches");
            }
            
            // Check proxy contracts
            if (current.market != referenceDeployment.market) {
                console.log("Market proxy mismatch");
                networkMatch = false;
            } else {
                console.log("Market proxy matches");
            }
            
            if (current.marketResolver != referenceDeployment.marketResolver) {
                console.log("MarketResolver proxy mismatch");
                networkMatch = false;
            } else {
                console.log("MarketResolver proxy matches");
            }
            
            if (current.positionTokens != referenceDeployment.positionTokens) {
                console.log("PositionTokens proxy mismatch");
                networkMatch = false;
            } else {
                console.log("PositionTokens proxy matches");
            }
            
            if (current.vault != referenceDeployment.vault) {
                console.log("Vault proxy mismatch");
                networkMatch = false;
            } else {
                console.log("Vault proxy matches");
            }
            
            if (current.marketController != referenceDeployment.marketController) {
                console.log("MarketController proxy mismatch");
                networkMatch = false;
            } else {
                console.log("MarketController proxy matches");
            }
            
            // Note: Collateral token may differ between networks (e.g., USDC addresses)
            if (current.collateralToken != referenceDeployment.collateralToken) {
                console.log("CollateralToken differs (expected for different tokens)");
            } else {
                console.log("CollateralToken matches");
            }
            
            if (!networkMatch) {
                allMatch = false;
                console.log("  Overall:", current.networkName, "has mismatched addresses");
            } else {
                console.log("  Overall:", current.networkName, "addresses match perfectly");
            }
        }
        
        return allMatch;
    }

    function logSingleDeployment(DeployedContracts memory deployment) internal pure {
        console.log("\n--- Single Deployment Found ---");
        console.log("Network:", deployment.networkName);
        console.log("Chain ID:", deployment.chainId);
        console.log("Deterministic:", deployment.deterministicDeployment);
        
        console.log("\nAddresses:");
        console.log("MarketController:", deployment.marketController);
        console.log("Market:", deployment.market);
        console.log("MarketResolver:", deployment.marketResolver);
        console.log("PositionTokens:", deployment.positionTokens);
        console.log("Vault:", deployment.vault);
        console.log("CollateralToken:", deployment.collateralToken);
        
        console.log("\nTo verify consistency:");
        console.log("1. Deploy to another network using the same deployer address");
        console.log("2. Run this verification script again");
    }

    function logUniversalAddresses(DeployedContracts memory referenceDeployment) internal pure {
        console.log("\n--- UNIVERSAL ADDRESSES (Same on all chains) ---");
        console.log("MarketController:    ", referenceDeployment.marketController);
        console.log("Market:              ", referenceDeployment.market);
        console.log("MarketResolver:      ", referenceDeployment.marketResolver);
        console.log("PositionTokens:      ", referenceDeployment.positionTokens);
        console.log("Vault:               ", referenceDeployment.vault);
        console.log("MarketImpl:          ", referenceDeployment.marketImpl);
        console.log("MarketResolverImpl:  ", referenceDeployment.marketResolverImpl);
        console.log("PositionTokensImpl:  ", referenceDeployment.positionTokensImpl);
        console.log("VaultImpl:           ", referenceDeployment.vaultImpl);
        console.log("MarketControllerImpl:", referenceDeployment.marketControllerImpl);
        
        console.log("\nThese addresses can be used in frontend configs");
        console.log("   for all supported chains!");
    }

    function generateDeploymentReport(DeployedContracts[] memory deployments) internal view {
        console.log("\n=== DEPLOYMENT REPORT ===");
        
        uint256 deterministicCount = 0;
        uint256 totalDeployments = deployments.length;
        
        console.log("Total Deployments:", totalDeployments);
        
        console.log("\nNetwork Status:");
        for (uint256 i = 0; i < deployments.length; i++) {
            DeployedContracts memory deployment = deployments[i];
            string memory status = deployment.deterministicDeployment ? "Deterministic" : "Standard";
            console.log("  ", deployment.networkName);
            console.log("(Chain", deployment.chainId, "):", status);
            
            if (deployment.deterministicDeployment) {
                deterministicCount++;
            }
        }
        
        console.log("\nDeployment Type Summary:");
        console.log("  Deterministic (Create2):", deterministicCount);
        console.log("  Standard:", totalDeployments - deterministicCount);
        
        if (deterministicCount == totalDeployments && totalDeployments > 1) {
            console.log("\nPerfect! All deployments use Create2 deterministic addresses");
        } else if (deterministicCount > 0) {
            console.log("\nMixed deployment types detected");
            console.log("   Consider redeploying non-deterministic contracts with Create2");
        } else {
            console.log("\nConsider upgrading to Create2 deployments for address consistency");
        }
        
        console.log("\nNext Steps:");
        if (totalDeployments < supportedNetworks.length) {
            console.log("  1. Deploy to more networks using: make deploy-<network>");
        }
        console.log("  2. Verify contracts using: make verification-guide");
        console.log("  3. Set up post-deployment configs using: make setup-<network>");
        
        console.log("\nFor frontend integration, use MarketController address:");
        if (deployments.length > 0) {
            console.log("  ", deployments[0].marketController);
        }
    }
}

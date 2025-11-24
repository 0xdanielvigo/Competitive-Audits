// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 * @title VerifyTestUSDC.s
 * @notice Script to automatically verify all deployed contracts on block explorers
 * @dev Handles both implementation and proxy contract verification
 */
contract VerifyTestUSDC is Script {
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

    function run() external {
        string memory network = getNetworkName();
        console.log("=== Automatic Contract Verification ===");
        console.log("Network:", network);
        
        // Load deployed contract addresses
        DeployedContracts memory contracts = loadDeployedContracts();
        
        // Get verification parameters
        string memory etherscanApiKey = getEtherscanApiKey();
        uint256 chainId = block.chainid;
        
        if (bytes(etherscanApiKey).length == 0) {
            console.log("Warning: No API key found for this network");
            console.log("Verification may not be supported or manual verification required");
            logContractAddresses(contracts);
            return;
        }
        
        console.log("Starting automatic verification process...");
        console.log("Chain ID:", chainId);
        
        // Verify implementation contracts
        verifyImplementationContracts(contracts, etherscanApiKey, chainId);
        
        // Provide proxy verification guidance
        provideProxyVerificationGuidance(contracts);
        
        console.log("\n=== Verification Process Complete ===");
    }

    function loadDeployedContracts() internal view returns (DeployedContracts memory contracts) {
        string memory networkName = getNetworkName();
        string memory fileName = string.concat("deployments/", networkName, ".json");
        
        console.log("Loading deployment from:", fileName);
        
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
        
        console.log("Loaded contract addresses");
    }

    function verifyImplementationContracts(
        DeployedContracts memory contracts,
        string memory etherscanApiKey,
        uint256 chainId
    ) internal {
        console.log("\n--- Verifying Implementation Contracts ---");
        
        // Verify MarketContract Implementation
        console.log("1. Verifying MarketContract implementation...");
        verifyContract(
            contracts.marketImpl,
            "src/Market/Market.sol:MarketContract",
            etherscanApiKey,
            chainId
        );
        
        // Verify MarketResolver Implementation
        console.log("2. Verifying MarketResolver implementation...");
        verifyContract(
            contracts.marketResolverImpl,
            "src/Market/MarketResolver.sol:MarketResolver",
            etherscanApiKey,
            chainId
        );
        
        // Verify PositionTokens Implementation
        console.log("3. Verifying PositionTokens implementation...");
        verifyContract(
            contracts.positionTokensImpl,
            "src/Token/PositionTokens.sol:PositionTokens",
            etherscanApiKey,
            chainId
        );
        
        // Verify Vault Implementation
        console.log("4. Verifying Vault implementation...");
        verifyContract(
            contracts.vaultImpl,
            "src/Vault/Vault.sol:Vault",
            etherscanApiKey,
            chainId
        );
        
        // Verify MarketController Implementation
        console.log("5. Verifying MarketController implementation...");
        verifyContract(
            contracts.marketControllerImpl,
            "src/Market/MarketController.sol:MarketController",
            etherscanApiKey,
            chainId
        );
        
        console.log("Implementation contract verification commands executed");
        console.log("Note: Verification may take a few minutes to complete");
    }

    function verifyContract(
        address contractAddress,
        string memory contractPath,
        string memory etherscanApiKey,
        uint256 chainId
    ) internal {
        string[] memory verifyCmd = new string[](8);
        verifyCmd[0] = "forge";
        verifyCmd[1] = "verify-contract";
        verifyCmd[2] = vm.toString(contractAddress);
        verifyCmd[3] = contractPath;
        verifyCmd[4] = "--chain-id";
        verifyCmd[5] = vm.toString(chainId);
        verifyCmd[6] = "--etherscan-api-key";
        verifyCmd[7] = etherscanApiKey;
        
        try vm.ffi(verifyCmd) {
            console.log(string.concat(contractPath, " verification started"));
        } catch {
            console.log(string.concat(contractPath, " verification failed"));
            console.log("   Command:", string.concat(
                "forge verify-contract ", vm.toString(contractAddress),
                " ", contractPath,
                " --chain-id ", vm.toString(chainId),
                " --etherscan-api-key [API_KEY]"
            ));
        }
    }

    function provideProxyVerificationGuidance(DeployedContracts memory contracts) internal view {
        console.log("\n--- Proxy Verification Required ---");
        console.log("Manual step required: Verify proxy contracts in block explorer");
        console.log("");
        
        string memory explorerUrl = getExplorerBaseUrl();
        
        console.log("Proxy contracts to verify manually:");
        console.log("");
        
        console.log("1. MarketController Proxy (MOST IMPORTANT):");
        console.log(string.concat(explorerUrl, "/address/", vm.toString(contracts.marketController)));
        console.log(string.concat("    Implementation: ", vm.toString(contracts.marketControllerImpl)));
        console.log("");
        
        console.log("2. Market Proxy:");
        console.log(string.concat(explorerUrl, "/address/", vm.toString(contracts.market)));
        console.log(string.concat("    Implementation: ", vm.toString(contracts.marketImpl)));
        console.log("");
        
        console.log("3. Vault Proxy:");
        console.log(string.concat(explorerUrl, "/address/", vm.toString(contracts.vault)));
        console.log(string.concat("    Implementation: ", vm.toString(contracts.vaultImpl)));
        console.log("");
        
        console.log("4. PositionTokens Proxy:");
        console.log(string.concat(explorerUrl, "/address/", vm.toString(contracts.positionTokens)));
        console.log(string.concat("    Implementation: ", vm.toString(contracts.positionTokensImpl)));
        console.log("");
        
        console.log("5. MarketResolver Proxy:");
        console.log(string.concat(explorerUrl, "/address/", vm.toString(contracts.marketResolver)));
        console.log(string.concat("    Implementation: ", vm.toString(contracts.marketResolverImpl)));
        console.log("");
        
        console.log("Steps for each proxy:");
        console.log("   1. Click the proxy URL above");
        console.log("   2. Go to 'Contract' tab");
        console.log("   3. Click 'More Options' and then 'Is this a proxy?'");
        console.log("   4. Verify with implementation address");
        console.log("   5. Look for 'Read as Proxy' and 'Write as Proxy' tabs");
        console.log("");
        
        console.log("After verification, you can interact with contracts via block explorer!");
    }

    function logContractAddresses(DeployedContracts memory contracts) internal view {
        console.log("\n--- Contract Addresses (For Manual Verification) ---");
        
        console.log("Implementation Contracts:");
        console.log("MarketController:", vm.toString(contracts.marketControllerImpl));
        console.log("Market:", vm.toString(contracts.marketImpl));
        console.log("MarketResolver:", vm.toString(contracts.marketResolverImpl));
        console.log("PositionTokens:", vm.toString(contracts.positionTokensImpl));
        console.log("Vault:", vm.toString(contracts.vaultImpl));
        console.log("");
        
        console.log("Proxy Contracts (Main Interfaces):");
        console.log("MarketController:", vm.toString(contracts.marketController));
        console.log("Market:", vm.toString(contracts.market));
        console.log("MarketResolver:", vm.toString(contracts.marketResolver));
        console.log("PositionTokens:", vm.toString(contracts.positionTokens));
        console.log("Vault:", vm.toString(contracts.vault));
        console.log("");
        
        console.log("Other:");
        console.log("Collateral Token:", vm.toString(contracts.collateralToken));
    }

function getEtherscanApiKey() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        // Check each chain and try to get the appropriate API key
        if (chainId == 1 || chainId == 11155111) {
            // Ethereum mainnet or Sepolia
            try vm.envString("ETHERSCAN_API_KEY") returns (string memory key) {
                return key;
            } catch {
                return "";
            }
        } else if (chainId == 56 || chainId == 97) {
            // BSC mainnet or testnet
            try vm.envString("BSCSCAN_API_KEY") returns (string memory key) {
                return key;
            } catch {
                return "";
            }
        } else if (chainId == 137 || chainId == 80001) {
            // Polygon mainnet or Mumbai
            try vm.envString("POLYGONSCAN_API_KEY") returns (string memory key) {
                return key;
            } catch {
                return "";
            }
        } else if (chainId == 42161 || chainId == 421614) {
            // Arbitrum mainnet or testnet
            try vm.envString("ARBISCAN_API_KEY") returns (string memory key) {
                return key;
            } catch {
                return "";
            }
        } else if (chainId == 10 || chainId == 11155420) {
            // Optimism mainnet or testnet
            try vm.envString("OPTIMISM_ETHERSCAN_API_KEY") returns (string memory key) {
                return key;
            } catch {
                return "";
            }
        } else if (chainId == 8453 || chainId == 84532) {
            // Base mainnet or testnet
            try vm.envString("BASESCAN_API_KEY") returns (string memory key) {
                return key;
            } catch {
                return "";
            }
        } else if (chainId == 146 || chainId == 57054) {
            // Sonic mainnet or testnet
            try vm.envString("SONIC_API_KEY") returns (string memory key) {
                return key;
            } catch {
                return "";
            }
        }
        
        return "";
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

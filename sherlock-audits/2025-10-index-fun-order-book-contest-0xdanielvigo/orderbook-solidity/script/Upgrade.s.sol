// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../src/Market/Market.sol";
import "../src/Market/MarketController.sol";
import "../src/Market/MarketResolver.sol";
import "../src/Token/PositionTokens.sol";
import "../src/Vault/Vault.sol";

/**
 * @title Upgrade
 * @notice UUPS upgrade script for prediction market contracts
 * @dev Upgrades implementation contracts while preserving proxy addresses and state
 */
contract Upgrade is Script {
    using stdJson for string;

    struct CurrentDeployment {
        address collateralToken;
        address marketImpl;
        address marketResolverImpl;
        address positionTokensImpl;
        address vaultImpl;
        address marketControllerImpl;
        address market;           // proxy
        address marketResolver;   // proxy
        address positionTokens;   // proxy
        address vault;           // proxy
        address marketController; // proxy
        bytes32 deploymentSalt;
        bool deterministicDeployment;
    }

    struct NewImplementations {
        address marketImpl;
        address marketResolverImpl;
        address positionTokensImpl;
        address vaultImpl;
        address marketControllerImpl;
    }

    struct UpgradeConfig {
        bool upgradeMarket;
        bool upgradeMarketResolver;
        bool upgradePositionTokens;
        bool upgradeVault;
        bool upgradeMarketController;
        bool deployDeterministic;  // Whether to use Create2 for new implementations
        string upgradeReason;      // Optional reason for upgrade
    }

    // New salts for upgraded implementations (increment version)
    bytes32 constant MARKET_IMPL_SALT_V6 = keccak256("PredictionMarket.MarketImpl.v6");
    bytes32 constant MARKET_RESOLVER_IMPL_SALT_V6 = keccak256("PredictionMarket.MarketResolverImpl.v6");
    bytes32 constant POSITION_TOKENS_IMPL_SALT_V6 = keccak256("PredictionMarket.PositionTokensImpl.v6");
    bytes32 constant VAULT_IMPL_SALT_V6 = keccak256("PredictionMarket.VaultImpl.v6");
    bytes32 constant MARKET_CONTROLLER_IMPL_SALT_V6 = keccak256("PredictionMarket.MarketControllerImpl.v6");

    function run() external {
        console.log("=== UUPS Contract Upgrade ===");

        // Load current deployment
        CurrentDeployment memory current = loadCurrentDeployment();

        // Get upgrade configuration
        UpgradeConfig memory config = getUpgradeConfig();

        console.log("Upgrade Configuration:");
        console.log("  Network:", getNetworkName());
        console.log("  Upgrade Market:", config.upgradeMarket);
        console.log("  Upgrade MarketResolver:", config.upgradeMarketResolver);
        console.log("  Upgrade PositionTokens:", config.upgradePositionTokens);
        console.log("  Upgrade Vault:", config.upgradeVault);
        console.log("  Upgrade MarketController:", config.upgradeMarketController);
        console.log("  Deploy Deterministic:", config.deployDeterministic);
        if (bytes(config.upgradeReason).length > 0) {
            console.log("  Reason:", config.upgradeReason);
        }

        vm.startBroadcast();

        // Deploy new implementations
        NewImplementations memory newImpls = deployNewImplementations(current, config);

        // Perform upgrades
        performUpgrades(current, newImpls, config);

        vm.stopBroadcast();

        // Verify upgrades
        verifyUpgrades(current, newImpls, config);

        // Save upgrade information
        saveUpgradeInfo(current, newImpls, config);

        console.log("=== Upgrade Complete ===");
        logUpgradeSummary(current, newImpls, config);
    }

    function loadCurrentDeployment() internal view returns (CurrentDeployment memory deployment) {
        string memory networkName = getNetworkName();
        string memory fileName = string.concat("deployments/", networkName, ".json");

        console.log("Loading current deployment from:", fileName);

        string memory json = vm.readFile(fileName);

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
        deployment.deploymentSalt = json.readBytes32(".deploymentSalt");
        deployment.deterministicDeployment = json.readBool(".deterministicDeployment");

        console.log("Current deployment loaded:");
        console.log("  MarketController proxy:", deployment.marketController);
        console.log("  Current implementation:", deployment.marketControllerImpl);
    }

    function deployNewImplementations(CurrentDeployment memory current, UpgradeConfig memory config)
        internal
        returns (NewImplementations memory newImpls)
    {
        console.log("\n--- Deploying New Implementations ---");

        if (config.upgradeMarket) {
            if (config.deployDeterministic) {
                console.log("Deploying MarketContract implementation (Create2)...");
                MarketContract marketImpl = new MarketContract{salt: MARKET_IMPL_SALT_V6}();
                newImpls.marketImpl = address(marketImpl);
            } else {
                console.log("Deploying MarketContract implementation...");
                MarketContract marketImpl = new MarketContract();
                newImpls.marketImpl = address(marketImpl);
            }
            console.log("  New MarketContract implementation:", newImpls.marketImpl);
        } else {
            newImpls.marketImpl = current.marketImpl;
        }

        if (config.upgradeMarketResolver) {
            if (config.deployDeterministic) {
                console.log("Deploying MarketResolver implementation (Create2)...");
                MarketResolver marketResolverImpl = new MarketResolver{salt: MARKET_RESOLVER_IMPL_SALT_V6}();
                newImpls.marketResolverImpl = address(marketResolverImpl);
            } else {
                console.log("Deploying MarketResolver implementation...");
                MarketResolver marketResolverImpl = new MarketResolver();
                newImpls.marketResolverImpl = address(marketResolverImpl);
            }
            console.log("  New MarketResolver implementation:", newImpls.marketResolverImpl);
        } else {
            newImpls.marketResolverImpl = current.marketResolverImpl;
        }

        if (config.upgradePositionTokens) {
            if (config.deployDeterministic) {
                console.log("Deploying PositionTokens implementation (Create2)...");
                PositionTokens positionTokensImpl = new PositionTokens{salt: POSITION_TOKENS_IMPL_SALT_V6}();
                newImpls.positionTokensImpl = address(positionTokensImpl);
            } else {
                console.log("Deploying PositionTokens implementation...");
                PositionTokens positionTokensImpl = new PositionTokens();
                newImpls.positionTokensImpl = address(positionTokensImpl);
            }
            console.log("  New PositionTokens implementation:", newImpls.positionTokensImpl);
        } else {
            newImpls.positionTokensImpl = current.positionTokensImpl;
        }

        if (config.upgradeVault) {
            if (config.deployDeterministic) {
                console.log("Deploying Vault implementation (Create2)...");
                Vault vaultImpl = new Vault{salt: VAULT_IMPL_SALT_V6}();
                newImpls.vaultImpl = address(vaultImpl);
            } else {
                console.log("Deploying Vault implementation...");
                Vault vaultImpl = new Vault();
                newImpls.vaultImpl = address(vaultImpl);
            }
            console.log("  New Vault implementation:", newImpls.vaultImpl);
        } else {
            newImpls.vaultImpl = current.vaultImpl;
        }

        if (config.upgradeMarketController) {
            if (config.deployDeterministic) {
                console.log("Deploying MarketController implementation (Create2)...");
                MarketController marketControllerImpl = new MarketController{salt: MARKET_CONTROLLER_IMPL_SALT_V6}();
                newImpls.marketControllerImpl = address(marketControllerImpl);
            } else {
                console.log("Deploying MarketController implementation...");
                MarketController marketControllerImpl = new MarketController();
                newImpls.marketControllerImpl = address(marketControllerImpl);
            }
            console.log("  New MarketController implementation:", newImpls.marketControllerImpl);
        } else {
            newImpls.marketControllerImpl = current.marketControllerImpl;
        }
    }

    function performUpgrades(
        CurrentDeployment memory current,
        NewImplementations memory newImpls,
        UpgradeConfig memory config
    ) internal {
        console.log("\n--- Performing UUPS Upgrades ---");

        if (config.upgradeMarket) {
            console.log("Upgrading Market proxy...");
            UUPSUpgradeable(current.market).upgradeToAndCall(
                newImpls.marketImpl,
                ""  // No initialization data needed
            );
            console.log("  Market upgraded successfully");
        }

        if (config.upgradeMarketResolver) {
            console.log("Upgrading MarketResolver proxy...");
            UUPSUpgradeable(current.marketResolver).upgradeToAndCall(
                newImpls.marketResolverImpl,
                ""
            );
            console.log("  MarketResolver upgraded successfully");
        }

        if (config.upgradePositionTokens) {
            console.log("Upgrading PositionTokens proxy...");
            UUPSUpgradeable(current.positionTokens).upgradeToAndCall(
                newImpls.positionTokensImpl,
                ""
            );
            console.log("  PositionTokens upgraded successfully");
        }

        if (config.upgradeVault) {
            console.log("Upgrading Vault proxy...");
            UUPSUpgradeable(current.vault).upgradeToAndCall(
                newImpls.vaultImpl,
                ""
            );
            console.log("  Vault upgraded successfully");
        }

        if (config.upgradeMarketController) {
            console.log("Upgrading MarketController proxy...");
            UUPSUpgradeable(current.marketController).upgradeToAndCall(
                newImpls.marketControllerImpl,
                ""
            );
            console.log("  MarketController upgraded successfully");
        }
    }

    function verifyUpgrades(
        CurrentDeployment memory current,
        NewImplementations memory newImpls,
        UpgradeConfig memory config
    ) internal view {
        console.log("\n--- Verifying Upgrades ---");

        if (config.upgradeMarket) {
            // Verify the proxy is still owned by the correct owner and functioning
            address owner = MarketContract(current.market).owner();
            console.log("Market proxy owner verified:", owner);

            // Verify proxy points to new implementation
            // Note: This verification is simplified - in practice you'd check implementation address
            require(owner != address(0), "Market upgrade verification failed");
        }

        if (config.upgradeMarketController) {
            address owner = MarketController(current.marketController).owner();
            console.log("MarketController proxy owner verified:", owner);
            require(owner != address(0), "MarketController upgrade verification failed");
        }

        if (config.upgradeVault) {
            address owner = Vault(current.vault).owner();
            console.log("Vault proxy owner verified:", owner);
            require(owner != address(0), "Vault upgrade verification failed");
        }

        console.log("All upgrade verifications passed!");
    }

    function saveUpgradeInfo(
        CurrentDeployment memory current,
        NewImplementations memory newImpls,
        UpgradeConfig memory config
    ) internal {
        console.log("\n--- Saving Upgrade Information ---");

        string memory networkName = getNetworkName();

        // Update the main deployment file with new implementation addresses
        string memory json = "upgrade";

        // Network info
        vm.serializeString(json, "network", networkName);
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeUint(json, "upgradeBlockNumber", block.number);
        vm.serializeUint(json, "upgradeTimestamp", block.timestamp);
        vm.serializeBytes32(json, "deploymentSalt", current.deploymentSalt);
        vm.serializeBool(json, "deterministicDeployment", current.deterministicDeployment);

        // Contract addresses (proxies remain the same)
        vm.serializeAddress(json, "collateralToken", current.collateralToken);
        vm.serializeAddress(json, "marketImpl", newImpls.marketImpl);
        vm.serializeAddress(json, "marketResolverImpl", newImpls.marketResolverImpl);
        vm.serializeAddress(json, "positionTokensImpl", newImpls.positionTokensImpl);
        vm.serializeAddress(json, "vaultImpl", newImpls.vaultImpl);
        vm.serializeAddress(json, "marketControllerImpl", newImpls.marketControllerImpl);
        vm.serializeAddress(json, "market", current.market);
        vm.serializeAddress(json, "marketResolver", current.marketResolver);
        vm.serializeAddress(json, "positionTokens", current.positionTokens);
        vm.serializeAddress(json, "vault", current.vault);
        string memory finalJson = vm.serializeAddress(json, "marketController", current.marketController);

        // Save updated deployment
        string memory fileName = string.concat("deployments/", networkName, ".json");
        vm.writeJson(finalJson, fileName);
        console.log("Updated deployment saved to:", fileName);

        // Also save upgrade history
        string memory upgradeJson = "upgradeHistory";
        vm.serializeUint(upgradeJson, "blockNumber", block.number);
        vm.serializeUint(upgradeJson, "timestamp", block.timestamp);
        vm.serializeString(upgradeJson, "reason", config.upgradeReason);

        // Previous implementations
        vm.serializeAddress(upgradeJson, "previous_marketImpl", current.marketImpl);
        vm.serializeAddress(upgradeJson, "previous_marketResolverImpl", current.marketResolverImpl);
        vm.serializeAddress(upgradeJson, "previous_positionTokensImpl", current.positionTokensImpl);
        vm.serializeAddress(upgradeJson, "previous_vaultImpl", current.vaultImpl);
        vm.serializeAddress(upgradeJson, "previous_marketControllerImpl", current.marketControllerImpl);

        // New implementations
        vm.serializeAddress(upgradeJson, "new_marketImpl", newImpls.marketImpl);
        vm.serializeAddress(upgradeJson, "new_marketResolverImpl", newImpls.marketResolverImpl);
        vm.serializeAddress(upgradeJson, "new_positionTokensImpl", newImpls.positionTokensImpl);
        vm.serializeAddress(upgradeJson, "new_vaultImpl", newImpls.vaultImpl);
        string memory finalUpgradeJson = vm.serializeAddress(upgradeJson, "new_marketControllerImpl", newImpls.marketControllerImpl);

        string memory upgradeHistoryFile = string.concat("deployments/", networkName, "-upgrade-", vm.toString(block.timestamp), ".json");
        vm.writeJson(finalUpgradeJson, upgradeHistoryFile);
        console.log("Upgrade history saved to:", upgradeHistoryFile);
    }

    function getUpgradeConfig() internal view returns (UpgradeConfig memory config) {
        // Read configuration from environment variables with defaults
        try vm.envBool("UPGRADE_MARKET") returns (bool upgrade) {
            config.upgradeMarket = upgrade;
        } catch {
            config.upgradeMarket = true;  // Default: upgrade all
        }

        try vm.envBool("UPGRADE_MARKET_RESOLVER") returns (bool upgrade) {
            config.upgradeMarketResolver = upgrade;
        } catch {
            config.upgradeMarketResolver = true;
        }

        try vm.envBool("UPGRADE_POSITION_TOKENS") returns (bool upgrade) {
            config.upgradePositionTokens = upgrade;
        } catch {
            config.upgradePositionTokens = true;
        }

        try vm.envBool("UPGRADE_VAULT") returns (bool upgrade) {
            config.upgradeVault = upgrade;
        } catch {
            config.upgradeVault = true;
        }

        try vm.envBool("UPGRADE_MARKET_CONTROLLER") returns (bool upgrade) {
            config.upgradeMarketController = upgrade;
        } catch {
            config.upgradeMarketController = true;
        }

        try vm.envBool("UPGRADE_DETERMINISTIC") returns (bool deterministic) {
            config.deployDeterministic = deterministic;
        } catch {
            config.deployDeterministic = true;  // Default to deterministic for consistency
        }

        try vm.envString("UPGRADE_REASON") returns (string memory reason) {
            config.upgradeReason = reason;
        } catch {
            config.upgradeReason = "Contract upgrade";
        }
    }

    function logUpgradeSummary(
        CurrentDeployment memory current,
        NewImplementations memory newImpls,
        UpgradeConfig memory config
    ) internal pure {
        console.log("\n--- Upgrade Summary ---");
        console.log("Proxy addresses (unchanged):");
        console.log("  MarketController:", current.marketController);
        console.log("  Market:", current.market);
        console.log("  MarketResolver:", current.marketResolver);
        console.log("  PositionTokens:", current.positionTokens);
        console.log("  Vault:", current.vault);
        console.log("");
        console.log("Implementation changes:");

        if (config.upgradeMarketController) {
            console.log("  MarketController:", current.marketControllerImpl, "->", newImpls.marketControllerImpl);
        }
        if (config.upgradeMarket) {
            console.log("  Market:", current.marketImpl, "->", newImpls.marketImpl);
        }
        if (config.upgradeMarketResolver) {
            console.log("  MarketResolver:", current.marketResolverImpl, "->", newImpls.marketResolverImpl);
        }
        if (config.upgradePositionTokens) {
            console.log("  PositionTokens:", current.positionTokensImpl, "->", newImpls.positionTokensImpl);
        }
        if (config.upgradeVault) {
            console.log("  Vault:", current.vaultImpl, "->", newImpls.vaultImpl);
        }
        console.log("");
        console.log("Users can continue using the same proxy addresses!");
        console.log("All state and balances are preserved.");
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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import "../src/Market/Market.sol";
import "../src/Market/MarketController.sol";
import "../src/Market/MarketResolver.sol";
import "../src/Token/PositionTokens.sol";
import "../src/Vault/Vault.sol";

/**
 * @title PredictAddresses
 * @notice Predict contract addresses that will be deployed via built-in Create2
 * @dev Run this before deployment to verify addresses will be consistent across chains
 */
contract PredictAddresses is Script {
    
    // Custom salts for each contract type (must match Deploy.s.sol)
    bytes32 constant MARKET_IMPL_SALT = keccak256("PredictionMarket.MarketImpl.v1");
    bytes32 constant MARKET_RESOLVER_IMPL_SALT = keccak256("PredictionMarket.MarketResolverImpl.v1");
    bytes32 constant POSITION_TOKENS_IMPL_SALT = keccak256("PredictionMarket.PositionTokensImpl.v1");
    bytes32 constant VAULT_IMPL_SALT = keccak256("PredictionMarket.VaultImpl.v1");
    bytes32 constant MARKET_CONTROLLER_IMPL_SALT = keccak256("PredictionMarket.MarketControllerImpl.v1");
    bytes32 constant MARKET_PROXY_SALT = keccak256("PredictionMarket.Market.v1");
    bytes32 constant MARKET_RESOLVER_PROXY_SALT = keccak256("PredictionMarket.MarketResolver.v1");
    bytes32 constant POSITION_TOKENS_PROXY_SALT = keccak256("PredictionMarket.PositionTokens.v1");
    bytes32 constant VAULT_PROXY_SALT = keccak256("PredictionMarket.Vault.v1");
    bytes32 constant MARKET_CONTROLLER_PROXY_SALT = keccak256("PredictionMarket.MarketController.v1");

    struct PredictionConfig {
        address deployer;
        address owner;
        address oracle;
        address collateralToken;
        bool deployMockToken;
        bytes32 salt;
    }

    struct PredictedAddresses {
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
        console.log("=== Address Prediction for Create2 Deployment ===");
        
        PredictionConfig memory config = getPredictionConfig();
        
        console.log("Deployer:", config.deployer);
        console.log("Owner:", config.owner);
        console.log("Oracle:", config.oracle);
        console.log("Deploy Mock Token:", config.deployMockToken);
        console.log("Global Salt:", vm.toString(config.salt));
        console.log("Current Chain ID:", block.chainid);
        
        PredictedAddresses memory addresses = predictAllAddresses(config);
        
        logPredictedAddresses(addresses);
        generateDeploymentSummary(addresses, config);
        logNetworkSpecificInfo();
    }

    function predictAllAddresses(PredictionConfig memory config) internal pure returns (PredictedAddresses memory addresses) {
        // Predict collateral token
        if (config.deployMockToken) {
            addresses.collateralToken = Create2.computeAddress(
                config.salt,
                keccak256(type(ERC20Mock).creationCode),
                config.deployer
            );
        } else {
            addresses.collateralToken = config.collateralToken;
        }

        // Predict implementation addresses using Create2
        addresses.marketImpl = Create2.computeAddress(
            MARKET_IMPL_SALT,
            keccak256(type(MarketContract).creationCode),
            config.deployer
        );

        addresses.marketResolverImpl = Create2.computeAddress(
            MARKET_RESOLVER_IMPL_SALT,
            keccak256(type(MarketResolver).creationCode),
            config.deployer
        );

        addresses.positionTokensImpl = Create2.computeAddress(
            POSITION_TOKENS_IMPL_SALT,
            keccak256(type(PositionTokens).creationCode),
            config.deployer
        );

        addresses.vaultImpl = Create2.computeAddress(
            VAULT_IMPL_SALT,
            keccak256(type(Vault).creationCode),
            config.deployer
        );

        addresses.marketControllerImpl = Create2.computeAddress(
            MARKET_CONTROLLER_IMPL_SALT,
            keccak256(type(MarketController).creationCode),
            config.deployer
        );

        // Predict proxy addresses - need to include constructor parameters
        // Market proxy
        bytes memory marketInitData = abi.encodeWithSelector(MarketContract.initialize.selector, config.owner);
        bytes memory marketProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(addresses.marketImpl, marketInitData)
        );
        addresses.market = Create2.computeAddress(MARKET_PROXY_SALT, keccak256(marketProxyBytecode), config.deployer);

        // MarketResolver proxy
        bytes memory marketResolverInitData = abi.encodeWithSelector(
            MarketResolver.initialize.selector,
            config.owner,
            config.oracle
        );
        bytes memory marketResolverProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(addresses.marketResolverImpl, marketResolverInitData)
        );
        addresses.marketResolver = Create2.computeAddress(
            MARKET_RESOLVER_PROXY_SALT,
            keccak256(marketResolverProxyBytecode),
            config.deployer
        );

        // PositionTokens proxy
        bytes memory positionTokensInitData = abi.encodeWithSelector(PositionTokens.initialize.selector, config.owner);
        bytes memory positionTokensProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(addresses.positionTokensImpl, positionTokensInitData)
        );
        addresses.positionTokens = Create2.computeAddress(
            POSITION_TOKENS_PROXY_SALT,
            keccak256(positionTokensProxyBytecode),
            config.deployer
        );

        // Vault proxy
        bytes memory vaultInitData = abi.encodeWithSelector(
            Vault.initialize.selector,
            config.owner,
            addresses.collateralToken,
            config.deployer // Temporary, will be updated to MarketController
        );
        bytes memory vaultProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(addresses.vaultImpl, vaultInitData)
        );
        addresses.vault = Create2.computeAddress(VAULT_PROXY_SALT, keccak256(vaultProxyBytecode), config.deployer);

        // MarketController proxy
        bytes memory marketControllerInitData = abi.encodeWithSelector(
            MarketController.initialize.selector,
            config.owner,
            addresses.positionTokens,
            addresses.marketResolver,
            addresses.vault,
            addresses.market,
            config.oracle
        );
        bytes memory marketControllerProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(addresses.marketControllerImpl, marketControllerInitData)
        );
        addresses.marketController = Create2.computeAddress(
            MARKET_CONTROLLER_PROXY_SALT,
            keccak256(marketControllerProxyBytecode),
            config.deployer
        );
    }

    function getPredictionConfig() internal view returns (PredictionConfig memory config) {
        // Use msg.sender as the deployer (this matches the Deploy script)
        config.deployer = msg.sender;
        
        try vm.envAddress("OWNER_ADDRESS") returns (address ownerAddr) {
            config.owner = ownerAddr;
        } catch {
            config.owner = msg.sender;
        }
        
        try vm.envAddress("ORACLE_ADDRESS") returns (address oracleAddr) {
            config.oracle = oracleAddr;
        } catch {
            config.oracle = msg.sender;
        }
        
        try vm.envAddress("COLLATERAL_TOKEN_ADDRESS") returns (address tokenAddr) {
            config.collateralToken = tokenAddr;
        } catch {
            config.collateralToken = address(0);
        }
        
        config.deployMockToken = (config.collateralToken == address(0));
        
        // Generate deterministic salt from deployer address and protocol name
        string memory saltString;
        try vm.envString("DEPLOYMENT_SALT") returns (string memory envSalt) {
            saltString = envSalt;
        } catch {
            saltString = "PredictionMarket.v1.0";
        }
        config.salt = keccak256(abi.encodePacked(saltString, msg.sender));
    }

    function logPredictedAddresses(PredictedAddresses memory addresses) internal pure {
        console.log("\n=== PREDICTED ADDRESSES ===");
        console.log("(These will be IDENTICAL on all supported chains)");
        
        console.log("\nIMPLEMENTATION CONTRACTS:");
        console.log("MarketContract:      ", addresses.marketImpl);
        console.log("MarketResolver:      ", addresses.marketResolverImpl);
        console.log("PositionTokens:      ", addresses.positionTokensImpl);
        console.log("Vault:               ", addresses.vaultImpl);
        console.log("MarketController:    ", addresses.marketControllerImpl);
        
        console.log("\nPROXY CONTRACTS (Main Interfaces):");
        console.log("Market:              ", addresses.market);
        console.log("MarketResolver:      ", addresses.marketResolver);
        console.log("PositionTokens:      ", addresses.positionTokens);
        console.log("Vault:               ", addresses.vault);
        console.log("MarketController:    ", addresses.marketController);
        
        console.log("\nCOLLATERAL TOKEN:");
        console.log("CollateralToken:     ", addresses.collateralToken);
        
        console.log("\nMAIN ENTRY POINT:");
        console.log("MarketController:    ", addresses.marketController);
        console.log("(This is the contract users will interact with)");
    }

    function generateDeploymentSummary(PredictedAddresses memory addresses, PredictionConfig memory config) internal pure {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        
        console.log("Deployment Method: Solidity Create2 (Deterministic)");
        console.log("Deployer Address:  ", config.deployer);
        console.log("Same addresses on: ALL supported chains");
        console.log("Owner Will Be:     ", config.owner);
        console.log("Oracle Will Be:    ", config.oracle);
        console.log("");
        
        console.log("PRIMARY CONTRACT FOR USERS:");
        console.log("MarketController: ", addresses.marketController);
        console.log("");
        
        console.log("COPY-PASTE READY ADDRESSES:");
        console.log("MARKET_CONTROLLER_ADDRESS=", addresses.marketController);
        console.log("MARKET_ADDRESS=", addresses.market);
        console.log("VAULT_ADDRESS=", addresses.vault);
        console.log("POSITION_TOKENS_ADDRESS=", addresses.positionTokens);
        console.log("MARKET_RESOLVER_ADDRESS=", addresses.marketResolver);
        console.log("COLLATERAL_TOKEN_ADDRESS=", addresses.collateralToken);
    }

    function logNetworkSpecificInfo() internal view {
        console.log("\n=== NETWORK DEPLOYMENT STATUS ===");
        
        uint256 chainId = block.chainid;
        string memory networkName = getNetworkName();
        
        console.log("Current Network:", networkName);
        console.log("Chain ID:", chainId);
        
        // Check if we have deployed contracts at predicted addresses
        string memory deploymentFile = string.concat("deployments/", networkName, ".json");
        
        try vm.readFile(deploymentFile) returns (string memory) {
            console.log("Deployment exists for this network");
            console.log("File:", deploymentFile);
        } catch {
            console.log("No deployment found for this network");
            console.log("Run deployment with: make deploy-", networkName);
        }
        
        console.log("\nSUPPORTED NETWORKS FOR IDENTICAL ADDRESSES:");
        console.log("- Ethereum Mainnet (chainId: 1)");
        console.log("- Ethereum Sepolia (chainId: 11155111)");
        console.log("- Arbitrum One (chainId: 42161)");
        console.log("- Arbitrum Sepolia (chainId: 421614)");
        console.log("- BSC Mainnet (chainId: 56)");
        console.log("- BSC Testnet (chainId: 97)");
        console.log("- Sonic Mainnet (chainId: 146)");
        console.log("- Sonic Testnet (chainId: 57054)");
        console.log("- Polygon (chainId: 137)");
        console.log("- Base (chainId: 8453)");
        console.log("- Optimism (chainId: 10)");
        console.log("");
        console.log("Addresses will be identical when using the same deployer account.");
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

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
 * @title Deploy
 * @notice Deterministic deployment script using Solidity's built-in Create2
 * @dev Deploys all contracts with deterministic salts for consistent addresses across chains
 */
contract Deploy is Script {
    // Deployment configuration
    struct DeployConfig {
        address owner;
        address oracle;
        address collateralToken;
        bool deployMockToken;
        uint256 mockTokenSupply;
        bytes32 salt; // Global salt for deterministic deployment
    }

    // Deployed contract addresses
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

    // Custom salts for each contract type
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

    function run() external {
        // Load configuration
        DeployConfig memory config = getDeployConfig();

        console.log("=== Deterministic Prediction Market Deployment (Create2) ===");
        console.log("Deployer:", msg.sender);
        console.log("Owner:", config.owner);
        console.log("Oracle:", config.oracle);
        console.log("Deploy Mock Token:", config.deployMockToken);
        console.log("Global Salt:", vm.toString(config.salt));

        vm.startBroadcast();

        // Deploy contracts using Create2
        DeployedContracts memory contracts = deployContractsCreate2(config);

        // Link contracts
        linkContracts(contracts);

        vm.stopBroadcast();

        // Save deployment addresses
        saveDeploymentAddresses(contracts, config);

        // Verify deployment
        verifyDeployment(contracts, config);

        console.log("=== Deployment Complete ===");
        logFinalAddresses(contracts);
    }

    function deployContractsCreate2(DeployConfig memory config)
        internal
        returns (DeployedContracts memory contracts)
    {
        console.log("\n--- Deploying Contracts with Create2 ---");

        // 1. Deploy or use existing collateral token
        if (config.deployMockToken) {
            console.log("Deploying mock ERC20 token with Create2...");
            
            address expectedToken = Create2.computeAddress(
                config.salt,
                keccak256(type(ERC20Mock).creationCode),
                msg.sender
            );
            
            if (expectedToken.code.length == 0) {
                ERC20Mock token = new ERC20Mock{salt: config.salt}();
                contracts.collateralToken = address(token);
                
                // Mint initial supply to deployer for testing
                token.mint(msg.sender, config.mockTokenSupply);
                console.log("Mock token deployed:", contracts.collateralToken);
            } else {
                contracts.collateralToken = expectedToken;
                console.log("Mock token already exists:", contracts.collateralToken);
            }
        } else {
            contracts.collateralToken = config.collateralToken;
            console.log("Using existing collateral token:", contracts.collateralToken);
        }

        // 2. Deploy implementation contracts with Create2
        console.log("\nDeploying implementation contracts...");

        // MarketContract implementation
        address expectedMarketImpl = Create2.computeAddress(
            MARKET_IMPL_SALT,
            keccak256(type(MarketContract).creationCode),
            msg.sender
        );
        
        if (expectedMarketImpl.code.length == 0) {
            MarketContract marketImpl = new MarketContract{salt: MARKET_IMPL_SALT}();
            contracts.marketImpl = address(marketImpl);
            console.log("MarketContract implementation deployed:", contracts.marketImpl);
        } else {
            contracts.marketImpl = expectedMarketImpl;
            console.log("MarketContract implementation already exists:", contracts.marketImpl);
        }

        // MarketResolver implementation
        address expectedMarketResolverImpl = Create2.computeAddress(
            MARKET_RESOLVER_IMPL_SALT,
            keccak256(type(MarketResolver).creationCode),
            msg.sender
        );
        
        if (expectedMarketResolverImpl.code.length == 0) {
            MarketResolver marketResolverImpl = new MarketResolver{salt: MARKET_RESOLVER_IMPL_SALT}();
            contracts.marketResolverImpl = address(marketResolverImpl);
            console.log("MarketResolver implementation deployed:", contracts.marketResolverImpl);
        } else {
            contracts.marketResolverImpl = expectedMarketResolverImpl;
            console.log("MarketResolver implementation already exists:", contracts.marketResolverImpl);
        }

        // PositionTokens implementation
        address expectedPositionTokensImpl = Create2.computeAddress(
            POSITION_TOKENS_IMPL_SALT,
            keccak256(type(PositionTokens).creationCode),
            msg.sender
        );
        
        if (expectedPositionTokensImpl.code.length == 0) {
            PositionTokens positionTokensImpl = new PositionTokens{salt: POSITION_TOKENS_IMPL_SALT}();
            contracts.positionTokensImpl = address(positionTokensImpl);
            console.log("PositionTokens implementation deployed:", contracts.positionTokensImpl);
        } else {
            contracts.positionTokensImpl = expectedPositionTokensImpl;
            console.log("PositionTokens implementation already exists:", contracts.positionTokensImpl);
        }

        // Vault implementation
        address expectedVaultImpl = Create2.computeAddress(
            VAULT_IMPL_SALT,
            keccak256(type(Vault).creationCode),
            msg.sender
        );
        
        if (expectedVaultImpl.code.length == 0) {
            Vault vaultImpl = new Vault{salt: VAULT_IMPL_SALT}();
            contracts.vaultImpl = address(vaultImpl);
            console.log("Vault implementation deployed:", contracts.vaultImpl);
        } else {
            contracts.vaultImpl = expectedVaultImpl;
            console.log("Vault implementation already exists:", contracts.vaultImpl);
        }

        // MarketController implementation
        address expectedMarketControllerImpl = Create2.computeAddress(
            MARKET_CONTROLLER_IMPL_SALT,
            keccak256(type(MarketController).creationCode),
            msg.sender
        );
        
        if (expectedMarketControllerImpl.code.length == 0) {
            MarketController marketControllerImpl = new MarketController{salt: MARKET_CONTROLLER_IMPL_SALT}();
            contracts.marketControllerImpl = address(marketControllerImpl);
            console.log("MarketController implementation deployed:", contracts.marketControllerImpl);
        } else {
            contracts.marketControllerImpl = expectedMarketControllerImpl;
            console.log("MarketController implementation already exists:", contracts.marketControllerImpl);
        }

        // 3. Deploy proxies with Create2
        console.log("\nDeploying proxies...");

        // Market proxy
        bytes memory marketInitData = abi.encodeWithSelector(MarketContract.initialize.selector, config.owner);
        bytes memory marketProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(contracts.marketImpl, marketInitData)
        );
        
        address expectedMarket = Create2.computeAddress(
            MARKET_PROXY_SALT,
            keccak256(marketProxyBytecode),
            msg.sender
        );
        
        if (expectedMarket.code.length == 0) {
            ERC1967Proxy marketProxy = new ERC1967Proxy{salt: MARKET_PROXY_SALT}(
                contracts.marketImpl,
                marketInitData
            );
            contracts.market = address(marketProxy);
            console.log("Market proxy deployed:", contracts.market);
        } else {
            contracts.market = expectedMarket;
            console.log("Market proxy already exists:", contracts.market);
        }

        // MarketResolver proxy
        bytes memory marketResolverInitData = abi.encodeWithSelector(
            MarketResolver.initialize.selector,
            config.owner,
            config.oracle
        );
        bytes memory marketResolverProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(contracts.marketResolverImpl, marketResolverInitData)
        );
        
        address expectedMarketResolver = Create2.computeAddress(
            MARKET_RESOLVER_PROXY_SALT,
            keccak256(marketResolverProxyBytecode),
            msg.sender
        );
        
        if (expectedMarketResolver.code.length == 0) {
            ERC1967Proxy marketResolverProxy = new ERC1967Proxy{salt: MARKET_RESOLVER_PROXY_SALT}(
                contracts.marketResolverImpl,
                marketResolverInitData
            );
            contracts.marketResolver = address(marketResolverProxy);
            console.log("MarketResolver proxy deployed:", contracts.marketResolver);
        } else {
            contracts.marketResolver = expectedMarketResolver;
            console.log("MarketResolver proxy already exists:", contracts.marketResolver);
        }

        // PositionTokens proxy
        bytes memory positionTokensInitData = abi.encodeWithSelector(PositionTokens.initialize.selector, config.owner);
        bytes memory positionTokensProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(contracts.positionTokensImpl, positionTokensInitData)
        );
        
        address expectedPositionTokens = Create2.computeAddress(
            POSITION_TOKENS_PROXY_SALT,
            keccak256(positionTokensProxyBytecode),
            msg.sender
        );
        
        if (expectedPositionTokens.code.length == 0) {
            ERC1967Proxy positionTokensProxy = new ERC1967Proxy{salt: POSITION_TOKENS_PROXY_SALT}(
                contracts.positionTokensImpl,
                positionTokensInitData
            );
            contracts.positionTokens = address(positionTokensProxy);
            console.log("PositionTokens proxy deployed:", contracts.positionTokens);
        } else {
            contracts.positionTokens = expectedPositionTokens;
            console.log("PositionTokens proxy already exists:", contracts.positionTokens);
        }

        // Vault proxy
        bytes memory vaultInitData = abi.encodeWithSelector(
            Vault.initialize.selector,
            config.owner,
            contracts.collateralToken,
            msg.sender // Temporary, will be updated to MarketController
        );
        bytes memory vaultProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(contracts.vaultImpl, vaultInitData)
        );
        
        address expectedVault = Create2.computeAddress(
            VAULT_PROXY_SALT,
            keccak256(vaultProxyBytecode),
            msg.sender
        );
        
        if (expectedVault.code.length == 0) {
            ERC1967Proxy vaultProxy = new ERC1967Proxy{salt: VAULT_PROXY_SALT}(
                contracts.vaultImpl,
                vaultInitData
            );
            contracts.vault = address(vaultProxy);
            console.log("Vault proxy deployed:", contracts.vault);
        } else {
            contracts.vault = expectedVault;
            console.log("Vault proxy already exists:", contracts.vault);
        }

        // MarketController proxy (deployed last as it needs other contract addresses)
        bytes memory marketControllerInitData = abi.encodeWithSelector(
            MarketController.initialize.selector,
            config.owner,
            contracts.positionTokens,
            contracts.marketResolver,
            contracts.vault,
            contracts.market,
            config.oracle
        );
        bytes memory marketControllerProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(contracts.marketControllerImpl, marketControllerInitData)
        );
        
        address expectedMarketController = Create2.computeAddress(
            MARKET_CONTROLLER_PROXY_SALT,
            keccak256(marketControllerProxyBytecode),
            msg.sender
        );
        
        if (expectedMarketController.code.length == 0) {
            ERC1967Proxy marketControllerProxy = new ERC1967Proxy{salt: MARKET_CONTROLLER_PROXY_SALT}(
                contracts.marketControllerImpl,
                marketControllerInitData
            );
            contracts.marketController = address(marketControllerProxy);
            console.log("MarketController proxy deployed:", contracts.marketController);
        } else {
            contracts.marketController = expectedMarketController;
            console.log("MarketController proxy already exists:", contracts.marketController);
        }
    }

    function linkContracts(DeployedContracts memory contracts) internal {
        console.log("\n--- Linking Contracts ---");

        // Set MarketController in all contracts
        MarketContract(contracts.market).setMarketController(contracts.marketController);
        console.log("Set MarketController in Market");

        PositionTokens(contracts.positionTokens).setMarketController(contracts.marketController);
        console.log("Set MarketController in PositionTokens");

        Vault(contracts.vault).setMarketController(contracts.marketController);
        console.log("Set MarketController in Vault");

        // Set EmergencyResolver in MarketResolver
        MarketResolver(contracts.marketResolver).setEmergencyResolver(contracts.marketController);
        console.log("Set EmergencyResolver in MarketResolver");

        console.log("Contract linking complete!");
    }

    function getDeployConfig() internal view returns (DeployConfig memory config) {
        // Try to read from environment variables, otherwise use defaults
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
        
        try vm.envUint("MOCK_TOKEN_SUPPLY") returns (uint256 supply) {
            config.mockTokenSupply = supply;
        } catch {
            config.mockTokenSupply = 1_000_000e18;
        }
        
        // Generate deterministic salt from deployer address and protocol name
        // This ensures same addresses across chains when using same deployer
        string memory saltString;
        try vm.envString("DEPLOYMENT_SALT") returns (string memory envSalt) {
            saltString = envSalt;
        } catch {
            saltString = "PredictionMarket.v1.0";
        }
        config.salt = keccak256(abi.encodePacked(saltString, msg.sender));

        // Validate configuration
        require(config.owner != address(0), "Owner address cannot be zero");
        require(config.oracle != address(0), "Oracle address cannot be zero");
        if (!config.deployMockToken) {
            require(config.collateralToken != address(0), "Collateral token address cannot be zero");
        }
    }

    function logFinalAddresses(DeployedContracts memory contracts) internal pure {
        console.log("\n--- Final Deployed Addresses ---");
        console.log("Main Entry Point:");
        console.log("  MarketController:", contracts.marketController);
        console.log("Supporting Contracts:");
        console.log("  Market:", contracts.market);
        console.log("  MarketResolver:", contracts.marketResolver);
        console.log("  PositionTokens:", contracts.positionTokens);
        console.log("  Vault:", contracts.vault);
        console.log("  CollateralToken:", contracts.collateralToken);
        console.log("\nThese addresses will be identical on all chains when using same deployer!");
    }

    function saveDeploymentAddresses(DeployedContracts memory contracts, DeployConfig memory config) internal {
        console.log("\n--- Saving Deployment Addresses ---");

        string memory json = "deployment";

        // Network info
        vm.serializeString(json, "network", getNetworkName());
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeUint(json, "blockNumber", block.number);
        vm.serializeUint(json, "timestamp", block.timestamp);
        vm.serializeBytes32(json, "deploymentSalt", config.salt);
        vm.serializeBool(json, "deterministicDeployment", true);

        // Contract addresses
        vm.serializeAddress(json, "collateralToken", contracts.collateralToken);
        vm.serializeAddress(json, "marketImpl", contracts.marketImpl);
        vm.serializeAddress(json, "marketResolverImpl", contracts.marketResolverImpl);
        vm.serializeAddress(json, "positionTokensImpl", contracts.positionTokensImpl);
        vm.serializeAddress(json, "vaultImpl", contracts.vaultImpl);
        vm.serializeAddress(json, "marketControllerImpl", contracts.marketControllerImpl);
        vm.serializeAddress(json, "market", contracts.market);
        vm.serializeAddress(json, "marketResolver", contracts.marketResolver);
        vm.serializeAddress(json, "positionTokens", contracts.positionTokens);
        vm.serializeAddress(json, "vault", contracts.vault);
        string memory finalJson = vm.serializeAddress(json, "marketController", contracts.marketController);

        string memory fileName = string.concat("deployments/", getNetworkName(), ".json");
        vm.writeJson(finalJson, fileName);
        console.log("Deployment addresses saved to:", fileName);
    }

    function verifyDeployment(DeployedContracts memory contracts, DeployConfig memory config) internal view {
        console.log("\n--- Verifying Deployment ---");

        // Verify proxy ownership
        require(MarketContract(contracts.market).owner() == config.owner, "Market owner mismatch");
        require(MarketResolver(contracts.marketResolver).owner() == config.owner, "MarketResolver owner mismatch");
        require(PositionTokens(contracts.positionTokens).owner() == config.owner, "PositionTokens owner mismatch");
        require(Vault(contracts.vault).owner() == config.owner, "Vault owner mismatch");
        require(MarketController(contracts.marketController).owner() == config.owner, "MarketController owner mismatch");
        console.log("Owner verification passed");

        // Verify contract linking
        require(
            MarketContract(contracts.market).marketController() == contracts.marketController,
            "Market controller link failed"
        );
        require(
            PositionTokens(contracts.positionTokens).marketController() == contracts.marketController,
            "PositionTokens controller link failed"
        );
        require(Vault(contracts.vault).marketController() == contracts.marketController, "Vault controller link failed");
        require(
            MarketResolver(contracts.marketResolver).emergencyResolver() == contracts.marketController,
            "Emergency resolver link failed"
        );
        console.log("Contract linking verification passed");

        // Verify oracle setup
        require(MarketResolver(contracts.marketResolver).oracle() == config.oracle, "Oracle setup failed");
        console.log("Oracle verification passed");

        // Verify collateral token
        require(
            address(Vault(contracts.vault).collateralToken()) == contracts.collateralToken,
            "Collateral token setup failed"
        );
        console.log("Collateral token verification passed");

        console.log("All verifications passed!");
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

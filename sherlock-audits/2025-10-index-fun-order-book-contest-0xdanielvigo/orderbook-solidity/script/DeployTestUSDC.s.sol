// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import "../src/Mocks/TestUSDC.sol";

/**
 * @title DeployTestUSDC
 * @notice Deterministic deployment script for TestUSDC using Solidity's built-in Create2
 * @dev Deploys TestUSDC with deterministic salt for consistent addresses across chains
 */
contract DeployTestUSDC is Script {
    // Deployment configuration
    struct DeployConfig {
        address owner;
        string name;
        string symbol;
        bytes32 salt; // Global salt for deterministic deployment
    }

    // Deployed contract addresses
    struct DeployedContracts {
        address testUSDC;
    }

    // Custom salt for TestUSDC
    bytes32 constant TESTUSDC_SALT = keccak256("PredictionMarket.TestUDC.v1");

    function run() external {
        // Load configuration
        DeployConfig memory config = getDeployConfig();

        console.log("=== Deterministic TestUSDC Deployment (Create2) ===");
        console.log("Deployer:", msg.sender);
        console.log("Owner:", config.owner);
        console.log("Name:", config.name);
        console.log("Symbol:", config.symbol);
        console.log("Global Salt:", vm.toString(config.salt));

        vm.startBroadcast();

        // Deploy TestUSDC using Create2
        DeployedContracts memory contracts = deployContractsCreate2(config);

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
        console.log("\n--- Deploying TestUSDC with Create2 ---");

        // Deploy TestUSDC with Create2
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(TestUSDC).creationCode,
                abi.encode(config.name, config.symbol, config.owner)
            )
        );

        // Foundry/Anvil default deterministic deployer
        address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

        address expectedTestUSDC = Create2.computeAddress(
            TESTUSDC_SALT,
            initCodeHash,
            create2Deployer
        );
        
        console.log("Expected TestUSDC address:", expectedTestUSDC);
        
        if (expectedTestUSDC.code.length == 0) {
            TestUSDC testUSDC = new TestUSDC{salt: TESTUSDC_SALT}(
                config.name,
                config.symbol,
                config.owner
            );
            contracts.testUSDC = address(testUSDC);
            console.log("TestUSDC deployed:", contracts.testUSDC);
        } else {
            contracts.testUSDC = expectedTestUSDC;
            console.log("TestUSDC already exists:", contracts.testUSDC);
        }

        require(contracts.testUSDC == expectedTestUSDC, "Address prediction failed");
    }

    function getDeployConfig() internal view returns (DeployConfig memory config) {
        // Try to read from environment variables, otherwise use defaults
        try vm.envAddress("OWNER_ADDRESS") returns (address ownerAddr) {
            config.owner = ownerAddr;
        } catch {
            config.owner = msg.sender;
        }
        
        try vm.envString("TOKEN_NAME") returns (string memory tokenName) {
            config.name = tokenName;
        } catch {
            config.name = "Test USDC";
        }
        
        try vm.envString("TOKEN_SYMBOL") returns (string memory tokenSymbol) {
            config.symbol = tokenSymbol;
        } catch {
            config.symbol = "TUSDC";
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
        require(bytes(config.name).length > 0, "Token name cannot be empty");
        require(bytes(config.symbol).length > 0, "Token symbol cannot be empty");
    }

    function logFinalAddresses(DeployedContracts memory contracts) internal pure {
        console.log("\n--- Final Deployed Addresses ---");
        console.log("TestUSDC:", contracts.testUSDC);
        console.log("\nThis address will be identical on all chains when using same deployer!");
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
        string memory finalJson = vm.serializeAddress(json, "testUSDC", contracts.testUSDC);

        string memory fileName = string.concat("deployments/test-usdc-", getNetworkName(), ".json");
        vm.writeJson(finalJson, fileName);
        console.log("Deployment addresses saved to:", fileName);
    }

    function verifyDeployment(DeployedContracts memory contracts, DeployConfig memory config) internal view {
        console.log("\n--- Verifying Deployment ---");

        TestUSDC testUSDC = TestUSDC(contracts.testUSDC);

        // Verify contract properties
        require(testUSDC.owner() == config.owner, "TestUSDC owner mismatch");
        require(
            keccak256(bytes(testUSDC.name())) == keccak256(bytes(config.name)), 
            "TestUSDC name mismatch"
        );
        require(
            keccak256(bytes(testUSDC.symbol())) == keccak256(bytes(config.symbol)), 
            "TestUSDC symbol mismatch"
        );
        require(testUSDC.decimals() == 6, "TestUSDC decimals mismatch");

        console.log("Owner verification passed");
        console.log("Token properties verification passed");
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

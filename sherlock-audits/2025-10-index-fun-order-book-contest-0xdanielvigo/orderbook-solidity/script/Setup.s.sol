// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "../src/Market/Market.sol";
import "../src/Market/MarketController.sol";
import "../src/Market/MarketResolver.sol";
import "../src/Token/PositionTokens.sol";
import "../src/Vault/Vault.sol";

/**
 * @title Setup
 * @notice Post-deployment setup script for prediction market contracts
 * @dev Handles initial configuration, test markets, and user setup
 */
contract Setup is Script {
    using stdJson for string;

    struct DeployedContracts {
        address collateralToken;
        address market;
        address marketResolver;
        address positionTokens;
        address vault;
        address marketController;
    }

    struct SetupConfig {
        bool createTestMarkets;
        bool setupTestUsers;
        bool setAuthorizedMatchers;
        address[] testUsers;
        address[] authorizedMatchers;
        uint256 testTokenAmount;
    }

    function run() external {
        console.log("=== Post-Deployment Setup ===");

        // Load deployed contract addresses
        DeployedContracts memory contracts = loadDeployedContracts();

        // Load setup configuration
        SetupConfig memory config = getSetupConfig();

        vm.startBroadcast();

        // Execute setup steps
        if (config.createTestMarkets) {
            createTestMarkets(contracts);
        }

        if (config.setupTestUsers) {
            setupTestUsers(contracts, config);
        }

        if (config.setAuthorizedMatchers) {
            setAuthorizedMatchers(contracts, config);
        }

        vm.stopBroadcast();

        // Verify setup
        verifySetup(contracts, config);

        console.log("=== Setup Complete ===");
    }

    function loadDeployedContracts() internal view returns (DeployedContracts memory contracts) {
        string memory networkName = getNetworkName();
        string memory fileName = string.concat("deployments/", networkName, ".json");

        console.log("Loading deployment from:", fileName);

        string memory json = vm.readFile(fileName);

        contracts.collateralToken = json.readAddress(".collateralToken");
        contracts.market = json.readAddress(".market");
        contracts.marketResolver = json.readAddress(".marketResolver");
        contracts.positionTokens = json.readAddress(".positionTokens");
        contracts.vault = json.readAddress(".vault");
        contracts.marketController = json.readAddress(".marketController");

        console.log("Loaded deployment addresses:");
        console.log("  Market:", contracts.market);
        console.log("  MarketController:", contracts.marketController);
        console.log("  Vault:", contracts.vault);
    }

    function createTestMarkets(DeployedContracts memory contracts) internal {
        console.log("\n--- Creating Test Markets ---");

        MarketController controller = MarketController(contracts.marketController);

        // Create various test markets
        bytes32[] memory questionIds = new bytes32[](5);
        string[] memory descriptions = new string[](5);
        uint256[] memory outcomeCounts = new uint256[](5);
        uint256[] memory resolutionTimes = new uint256[](5);

        // Market 1: Bitcoin price binary (manual resolution)
        questionIds[0] = keccak256("BTC_USD_50000");
        descriptions[0] = "Will Bitcoin price exceed $50,000 by end of month?";
        outcomeCounts[0] = 2;
        resolutionTimes[0] = 0; // Manual resolution

        // Market 2: Ethereum price binary (time-based resolution)
        questionIds[1] = keccak256("ETH_USD_3000");
        descriptions[1] = "Will Ethereum price exceed $3,000 by end of week?";
        outcomeCounts[1] = 2;
        resolutionTimes[1] = block.timestamp + 7 days;

        // Market 3: Stock market direction (multi-outcome)
        questionIds[2] = keccak256("SPY_DIRECTION");
        descriptions[2] = "S&P 500 direction next week: Up, Down, Sideways, Volatile";
        outcomeCounts[2] = 4;
        resolutionTimes[2] = block.timestamp + 7 days;

        // Market 4: Weather prediction
        questionIds[3] = keccak256("WEATHER_NYC");
        descriptions[3] = "NYC weather tomorrow: Sunny, Cloudy, Rainy";
        outcomeCounts[3] = 3;
        resolutionTimes[3] = block.timestamp + 1 days;

        // Market 5: Sports outcome
        questionIds[4] = keccak256("SPORTS_MATCH");
        descriptions[4] = "Next major game outcome: Team A, Team B";
        outcomeCounts[4] = 2;
        resolutionTimes[4] = block.timestamp + 3 days;

        for (uint256 i = 0; i < questionIds.length; i++) {
            try controller.createMarket(questionIds[i], outcomeCounts[i], resolutionTimes[i], 0) {
                console.log("Created market:", descriptions[i]);
                console.log("  Question ID:", vm.toString(questionIds[i]));
                console.log("  Outcomes:", outcomeCounts[i]);
                if (resolutionTimes[i] > 0) {
                    console.log("  Resolution time:", resolutionTimes[i]);
                } else {
                    console.log("  Manual resolution");
                }
            } catch {
                console.log("Failed to create market:", descriptions[i]);
            }
        }

        // Save test market info
        saveTestMarketInfo(questionIds, descriptions, outcomeCounts, resolutionTimes);
    }

    function setupTestUsers(DeployedContracts memory contracts, SetupConfig memory config) internal {
        console.log("\n--- Setting Up Test Users ---");

        // Only setup test users if we have a mock token (development environment)
        if (config.testUsers.length == 0) {
            console.log("No test users specified, skipping...");
            return;
        }

        ERC20Mock collateralToken = ERC20Mock(contracts.collateralToken);
        // Vault vault = Vault(contracts.vault);

        // Check if this is a mock token by trying to mint (will revert if not mock)
        try collateralToken.mint(address(this), 1) {
            // This is a mock token, we can mint for test users
            for (uint256 i = 0; i < config.testUsers.length; i++) {
                address user = config.testUsers[i];

                // Mint test tokens
                collateralToken.mint(user, config.testTokenAmount);
                console.log("Minted", config.testTokenAmount, "tokens for user:", user);

                // Note: Users will need to approve and deposit manually or via frontend
            }
        } catch {
            console.log("Not a mock token, skipping test user setup");
        }
    }

    function setAuthorizedMatchers(DeployedContracts memory contracts, SetupConfig memory config) internal {
        console.log("\n--- Setting Authorized Matchers ---");

        if (config.authorizedMatchers.length == 0) {
            console.log("No authorized matchers specified, skipping...");
            return;
        }

        MarketController controller = MarketController(contracts.marketController);

        for (uint256 i = 0; i < config.authorizedMatchers.length; i++) {
            address matcher = config.authorizedMatchers[i];
            controller.setAuthorizedMatcher(matcher, true);
            console.log("Authorized matcher:", matcher);
        }
    }

    function getSetupConfig() internal view returns (SetupConfig memory config) {
        // Read configuration from environment variables with try/catch
        try vm.envBool("CREATE_TEST_MARKETS") returns (bool createMarkets) {
            config.createTestMarkets = createMarkets;
        } catch {
            config.createTestMarkets = true;
        }
        
        try vm.envBool("SETUP_TEST_USERS") returns (bool setupUsers) {
            config.setupTestUsers = setupUsers;
        } catch {
            config.setupTestUsers = false;
        }
        
        try vm.envBool("SET_AUTHORIZED_MATCHERS") returns (bool setMatchers) {
            config.setAuthorizedMatchers = setMatchers;
        } catch {
            config.setAuthorizedMatchers = false;
        }
        
        try vm.envUint("TEST_TOKEN_AMOUNT") returns (uint256 tokenAmount) {
            config.testTokenAmount = tokenAmount;
        } catch {
            config.testTokenAmount = 10000e18;
        }

        // Parse test user addresses (comma-separated)
        try vm.envString("TEST_USER_ADDRESSES") returns (string memory userAddresses) {
            if (bytes(userAddresses).length > 0) {
                config.testUsers = parseAddresses(userAddresses);
            }
        } catch {
            // No test users specified
        }

        // Parse authorized matcher addresses (comma-separated)
        try vm.envString("AUTHORIZED_MATCHER_ADDRESSES") returns (string memory matcherAddresses) {
            if (bytes(matcherAddresses).length > 0) {
                config.authorizedMatchers = parseAddresses(matcherAddresses);
            }
        } catch {
            // No matchers specified
        }

        console.log("Setup configuration:");
        console.log("  Create test markets:", config.createTestMarkets);
        console.log("  Setup test users:", config.setupTestUsers);
        console.log("  Set authorized matchers:", config.setAuthorizedMatchers);
        console.log("  Test users count:", config.testUsers.length);
        console.log("  Authorized matchers count:", config.authorizedMatchers.length);
    }

    function parseAddresses(string memory addressString) internal pure returns (address[] memory addresses) {
        // Simple comma-separated address parser
        // In practice, you might want a more robust parser
        bytes memory data = bytes(addressString);
        uint256 count = 1;

        // Count commas to determine array size
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == bytes1(",")) {
                count++;
            }
        }

        addresses = new address[](count);
        // Note: This is a simplified implementation
        // For production, use a proper CSV parser or JSON format
    }

    function saveTestMarketInfo(
        bytes32[] memory questionIds,
        string[] memory descriptions,
        uint256[] memory outcomeCounts,
        uint256[] memory resolutionTimes
    ) internal {
        console.log("\n--- Saving Test Market Info ---");

        string memory json = "testMarkets";

        for (uint256 i = 0; i < questionIds.length; i++) {
            string memory marketKey = string.concat("market", vm.toString(i));

            vm.serializeBytes32(json, string.concat(marketKey, ".questionId"), questionIds[i]);
            vm.serializeString(json, string.concat(marketKey, ".description"), descriptions[i]);
            vm.serializeUint(json, string.concat(marketKey, ".outcomeCount"), outcomeCounts[i]);
            vm.serializeUint(json, string.concat(marketKey, ".resolutionTime"), resolutionTimes[i]);
        }

        string memory finalJson = vm.serializeUint(json, "count", questionIds.length);

        string memory fileName = string.concat("deployments/", getNetworkName(), "-test-markets.json");
        vm.writeJson(finalJson, fileName);
        console.log("Test market info saved to:", fileName);
    }

    function verifySetup(DeployedContracts memory contracts, SetupConfig memory config) internal view {
        console.log("\n--- Verifying Setup ---");

        MarketContract market = MarketContract(contracts.market);

        if (config.createTestMarkets) {
            // Verify at least one test market was created
            bytes32 testQuestionId = keccak256("BTC_USD_50000");
            require(market.getMarketExists(testQuestionId), "Test market creation failed");
            console.log("Test markets verified");
        }

        console.log("Setup verification complete!");
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

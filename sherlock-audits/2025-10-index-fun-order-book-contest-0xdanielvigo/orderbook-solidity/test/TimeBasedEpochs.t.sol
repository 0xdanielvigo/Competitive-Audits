// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/Market/Market.sol";
import "../src/Market/MarketController.sol";
import "../src/Market/MarketResolver.sol";
import "../src/Token/PositionTokens.sol";
import "../src/Vault/Vault.sol";

/**
 * @title TimeBasedEpochsTest
 * @notice Tests for automatic time-based epoch rolling feature
 */
contract TimeBasedEpochsTest is Test {
    MarketContract public market;
    MarketController public marketController;
    MarketResolver public marketResolver;
    PositionTokens public positionTokens;
    Vault public vault;
    ERC20Mock public collateralToken;

    address public owner = makeAddr("owner");
    address public oracle = makeAddr("oracle");
    address public treasury = makeAddr("treasury");
    address public alice;
    address public bob;
    address public matcher;

    bytes32 public dailyMarketId = keccak256("DAILY_BTC_PRICE");
    bytes32 public weeklyMarketId = keccak256("WEEKLY_ETH_PRICE");
    bytes32 public hourlyMarketId = keccak256("HOURLY_SOL_PRICE");
    bytes32 public manualMarketId = keccak256("MANUAL_MARKET");
    
    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant BET_AMOUNT = 1000e18;
    uint256 public constant INITIAL_BALANCE = 10000e18;
    
    uint256 public constant HOUR = 3600;
    uint256 public constant DAY = 86400;
    uint256 public constant WEEK = 604800;

    uint256 private alicePrivateKey = 0xa11ce;
    uint256 private bobPrivateKey = 0xb0b;
    uint256 private matcherPrivateKey = 0xdead;

    function setUp() public {
        vm.startPrank(owner);

        collateralToken = new ERC20Mock();

        // Deploy implementations
        MarketContract marketImpl = new MarketContract();
        MarketResolver marketResolverImpl = new MarketResolver();
        PositionTokens positionTokensImpl = new PositionTokens();
        Vault vaultImpl = new Vault();
        MarketController marketControllerImpl = new MarketController();

        // Deploy proxies
        bytes memory marketInitData = abi.encodeWithSelector(MarketContract.initialize.selector, owner);
        market = MarketContract(address(new ERC1967Proxy(address(marketImpl), marketInitData)));

        bytes memory marketResolverInitData = abi.encodeWithSelector(MarketResolver.initialize.selector, owner, oracle);
        marketResolver = MarketResolver(address(new ERC1967Proxy(address(marketResolverImpl), marketResolverInitData)));

        bytes memory positionTokensInitData = abi.encodeWithSelector(PositionTokens.initialize.selector, owner);
        positionTokens = PositionTokens(address(new ERC1967Proxy(address(positionTokensImpl), positionTokensInitData)));

        bytes memory vaultInitData = abi.encodeWithSelector(Vault.initialize.selector, owner, address(collateralToken), owner);
        vault = Vault(address(new ERC1967Proxy(address(vaultImpl), vaultInitData)));

        bytes memory marketControllerInitData = abi.encodeWithSelector(
            MarketController.initialize.selector,
            owner,
            address(positionTokens),
            address(marketResolver),
            address(vault),
            address(market),
            oracle
        );
        marketController = MarketController(address(new ERC1967Proxy(address(marketControllerImpl), marketControllerInitData)));

        // Link contracts
        market.setMarketController(address(marketController));
        positionTokens.setMarketController(address(marketController));
        vault.setMarketController(address(marketController));
        marketResolver.setEmergencyResolver(address(marketController));

        vm.stopPrank();

        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);
        matcher = vm.addr(matcherPrivateKey);

        vm.startPrank(owner);
        marketController.setAuthorizedMatcher(matcher, true);
        marketController.setAuthorizedMatcher(owner, true);
        marketController.setFeeRate(0); // No fees for simpler testing
        vm.stopPrank();

        // Fund users
        collateralToken.mint(alice, INITIAL_BALANCE);
        collateralToken.mint(bob, INITIAL_BALANCE);
        collateralToken.mint(matcher, INITIAL_BALANCE);

        vm.startPrank(alice);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(bob);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(matcher);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();
    }

    // ============ Basic Time-Based Epoch Tests ============

    function test_CreateTimeBasedMarket_Daily() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        assertEq(market.getEpochDuration(dailyMarketId), DAY);
        assertEq(market.getCurrentEpoch(dailyMarketId), 1);
        assertTrue(market.isMarketOpen(dailyMarketId));
    }

    function test_CreateTimeBasedMarket_Weekly() public {
        vm.prank(owner);
        marketController.createMarket(weeklyMarketId, BINARY_OUTCOMES, 0, WEEK);

        assertEq(market.getEpochDuration(weeklyMarketId), WEEK);
        assertEq(market.getCurrentEpoch(weeklyMarketId), 1);
    }

    function test_CreateTimeBasedMarket_Hourly() public {
        vm.prank(owner);
        marketController.createMarket(hourlyMarketId, BINARY_OUTCOMES, 0, HOUR);

        assertEq(market.getEpochDuration(hourlyMarketId), HOUR);
        assertEq(market.getCurrentEpoch(hourlyMarketId), 1);
    }

    function test_CreateManualMarket_BackwardCompatible() public {
        vm.prank(owner);
        marketController.createMarket(manualMarketId, BINARY_OUTCOMES, 0, 0);

        assertEq(market.getEpochDuration(manualMarketId), 0);
        assertEq(market.getCurrentEpoch(manualMarketId), 1);
    }

    // ============ Automatic Epoch Advancement Tests ============

    function test_EpochAdvancement_Daily() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        // Use the market's actual start time, not block.timestamp
        uint256 startTime = market.getEpochStartTime(dailyMarketId, 1);
        
        // Should be epoch 1 at start
        assertEq(market.getCurrentEpoch(dailyMarketId), 1);

        // Fast forward 1 day - should be epoch 2
        vm.warp(startTime + DAY);
        assertEq(market.getCurrentEpoch(dailyMarketId), 2);

        // Fast forward 2 more days - should be epoch 4
        vm.warp(startTime + (3 * DAY));
        assertEq(market.getCurrentEpoch(dailyMarketId), 4);

        // Fast forward to exactly 10 days - should be epoch 11
        vm.warp(startTime + (10 * DAY));
        assertEq(market.getCurrentEpoch(dailyMarketId), 11);
    }

    function test_EpochAdvancement_PartialTime() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        uint256 startTime = market.getEpochStartTime(dailyMarketId, 1);
        
        // 12 hours later - still epoch 1
        vm.warp(startTime + (DAY / 2));
        assertEq(market.getCurrentEpoch(dailyMarketId), 1);

        // 23 hours later - still epoch 1
        vm.warp(startTime + DAY - 1);
        assertEq(market.getCurrentEpoch(dailyMarketId), 1);

        // Exactly 24 hours - now epoch 2
        vm.warp(startTime + DAY);
        assertEq(market.getCurrentEpoch(dailyMarketId), 2);
    }

    function test_ManualEpochDoesNotAdvanceWithTime() public {
        vm.prank(owner);
        marketController.createMarket(manualMarketId, BINARY_OUTCOMES, 0, 0);

        assertEq(market.getCurrentEpoch(manualMarketId), 1);

        // Fast forward time - epoch should NOT change
        vm.warp(block.timestamp + (10 * DAY));
        assertEq(market.getCurrentEpoch(manualMarketId), 1);

        // Manual advancement still works
        vm.prank(owner);
        marketController.advanceMarketEpoch(manualMarketId);
        assertEq(market.getCurrentEpoch(manualMarketId), 2);
    }

    function test_CannotManuallyAdvanceTimeBasedMarket() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        vm.prank(owner);
        vm.expectRevert("Cannot manually advance time-based epochs");
        marketController.advanceMarketEpoch(dailyMarketId);
    }

    // ============ Epoch Time Calculation Tests ============

    function test_GetEpochStartTime() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        uint256 marketStartTime = block.timestamp;

        // Epoch 1 starts at market creation
        assertEq(market.getEpochStartTime(dailyMarketId, 1), marketStartTime);

        // Epoch 2 starts 1 day later
        assertEq(market.getEpochStartTime(dailyMarketId, 2), marketStartTime + DAY);

        // Epoch 10 starts 9 days later
        assertEq(market.getEpochStartTime(dailyMarketId, 10), marketStartTime + (9 * DAY));
    }

    function test_GetEpochEndTime() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        uint256 marketStartTime = block.timestamp;

        // Epoch 1 ends 1 day after start
        assertEq(market.getEpochEndTime(dailyMarketId, 1), marketStartTime + DAY);

        // Epoch 2 ends 2 days after start
        assertEq(market.getEpochEndTime(dailyMarketId, 2), marketStartTime + (2 * DAY));

        // Epoch 10 ends 10 days after start
        assertEq(market.getEpochEndTime(dailyMarketId, 10), marketStartTime + (10 * DAY));
    }

    function test_ManualMarket_NoEpochTimes() public {
        vm.prank(owner);
        marketController.createMarket(manualMarketId, BINARY_OUTCOMES, 0, 0);

        // Manual markets return 0 for epoch times
        assertEq(market.getEpochStartTime(manualMarketId, 1), 0);
        assertEq(market.getEpochEndTime(manualMarketId, 1), 0);
    }

    // ============ Trading Across Epoch Boundaries ============

    function test_TradingContinuesAcrossEpochs() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        uint256 startTime = market.getEpochStartTime(dailyMarketId, 1);

        // Trade in epoch 1
        _executeTrade(dailyMarketId, 1, 1);
        
        bytes32 conditionId1 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 1);
        uint256 yesTokenId1 = positionTokens.getTokenId(conditionId1, 1); // YES tokens
        uint256 noTokenId1 = positionTokens.getTokenId(conditionId1, 2);  // NO tokens
        
        // Alice bought YES, Bob sold YES (so Bob gets NO)
        assertEq(positionTokens.balanceOf(alice, yesTokenId1), BET_AMOUNT);
        assertEq(positionTokens.balanceOf(bob, noTokenId1), BET_AMOUNT);

        // Fast forward to epoch 2
        vm.warp(startTime + DAY);
        assertEq(market.getCurrentEpoch(dailyMarketId), 2);

        // Trade in epoch 2 should work
        _executeTrade(dailyMarketId, 2, 2);
        
        bytes32 conditionId2 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 2);
        uint256 yesTokenId2 = positionTokens.getTokenId(conditionId2, 1); // YES tokens
        uint256 noTokenId2 = positionTokens.getTokenId(conditionId2, 2);  // NO tokens
        
        // Alice bought YES again, Bob sold YES again (so Bob gets NO)
        assertEq(positionTokens.balanceOf(alice, yesTokenId2), BET_AMOUNT);
        assertEq(positionTokens.balanceOf(bob, noTokenId2), BET_AMOUNT);

        // All token IDs should be unique
        assertTrue(yesTokenId1 != yesTokenId2);
        assertTrue(noTokenId1 != noTokenId2);
        assertTrue(yesTokenId1 != noTokenId1);
    }

    function test_ResolutionOfPastEpochs() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        uint256 startTime = block.timestamp;

        // Trade in epoch 1
        _executeTrade(dailyMarketId, 1, 1);

        // Move to epoch 3
        vm.warp(startTime + (2 * DAY));
        assertEq(market.getCurrentEpoch(dailyMarketId), 3);

        // Resolve epoch 1 (in the past)
        bytes32 conditionId1 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 1);
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;

        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(dailyMarketId, 1, BINARY_OUTCOMES, merkleRoot);

        assertTrue(marketResolver.getResolutionStatus(conditionId1));

        // Alice can claim from epoch 1 even though we're in epoch 3
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(alice);
        uint256 payout = marketController.claimWinnings(dailyMarketId, 1, 1, proof);
        assertEq(payout, BET_AMOUNT);
    }

    function test_MultipleEpochResolution() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        uint256 startTime = block.timestamp;

        // Trade in epochs 1, 2, and 3
        _executeTrade(dailyMarketId, 1, 1);
        
        vm.warp(startTime + DAY);
        _executeTrade(dailyMarketId, 2, 2);
        
        vm.warp(startTime + (2 * DAY));
        _executeTrade(dailyMarketId, 3, 3);

        // Move to epoch 4
        vm.warp(startTime + (3 * DAY));

        // Resolve all three past epochs
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;

        vm.startPrank(oracle);
        marketResolver.resolveMarketEpoch(dailyMarketId, 1, BINARY_OUTCOMES, merkleRoot);
        marketResolver.resolveMarketEpoch(dailyMarketId, 2, BINARY_OUTCOMES, merkleRoot);
        marketResolver.resolveMarketEpoch(dailyMarketId, 3, BINARY_OUTCOMES, merkleRoot);
        vm.stopPrank();

        // Verify all resolved
        bytes32 conditionId1 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 1);
        bytes32 conditionId2 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 2);
        bytes32 conditionId3 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 3);

        assertTrue(marketResolver.getResolutionStatus(conditionId1));
        assertTrue(marketResolver.getResolutionStatus(conditionId2));
        assertTrue(marketResolver.getResolutionStatus(conditionId3));
    }

    // ============ Edge Cases ============

    function test_EpochBoundaryPrecision() public {
        vm.prank(owner);
        marketController.createMarket(hourlyMarketId, BINARY_OUTCOMES, 0, HOUR);

        uint256 startTime = market.getEpochStartTime(hourlyMarketId, 1);

        // 1 second before epoch 2
        vm.warp(startTime + HOUR - 1);
        assertEq(market.getCurrentEpoch(hourlyMarketId), 1);

        // Exactly at epoch 2 boundary
        vm.warp(startTime + HOUR);
        assertEq(market.getCurrentEpoch(hourlyMarketId), 2);

        // 1 second into epoch 2
        vm.warp(startTime + HOUR + 1);
        assertEq(market.getCurrentEpoch(hourlyMarketId), 2);
    }

    function test_VeryLongEpochDuration() public {
        uint256 yearlyEpoch = 365 * DAY;
        bytes32 yearlyMarketId = keccak256("YEARLY_MARKET");

        vm.prank(owner);
        marketController.createMarket(yearlyMarketId, BINARY_OUTCOMES, 0, yearlyEpoch);

        uint256 startTime = market.getEpochStartTime(yearlyMarketId, 1);

        assertEq(market.getCurrentEpoch(yearlyMarketId), 1);

        // 6 months - still epoch 1
        vm.warp(startTime + (180 * DAY));
        assertEq(market.getCurrentEpoch(yearlyMarketId), 1);

        // 1 year - epoch 2
        vm.warp(startTime + yearlyEpoch);
        assertEq(market.getCurrentEpoch(yearlyMarketId), 2);

        // 10 years - epoch 11
        vm.warp(startTime + (10 * yearlyEpoch));
        assertEq(market.getCurrentEpoch(yearlyMarketId), 11);
    }

    function test_MarketAlwaysOpen() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        // Should be open in epoch 1
        assertTrue(market.isMarketOpen(dailyMarketId));

        // Still open in epoch 100
        vm.warp(block.timestamp + (100 * DAY));
        assertTrue(market.isMarketOpen(dailyMarketId));

        // Always ready for resolution (manual mode)
        assertTrue(market.isMarketReadyForResolution(dailyMarketId));
    }

    function test_ConditionIdUniquenessAcrossEpochs() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        bytes32 conditionId1 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 1);
        bytes32 conditionId2 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 2);
        bytes32 conditionId3 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 3);

        // All should be unique
        assertTrue(conditionId1 != conditionId2);
        assertTrue(conditionId2 != conditionId3);
        assertTrue(conditionId1 != conditionId3);
    }

    function test_GetConditionIdWithZeroEpoch() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        uint256 startTime = block.timestamp;

        // epoch 0 means "current epoch"
        bytes32 conditionIdCurrent = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 0);
        bytes32 conditionIdExplicit1 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 1);
        
        // Should match epoch 1
        assertEq(conditionIdCurrent, conditionIdExplicit1);

        // Move to epoch 2
        vm.warp(startTime + DAY);
        
        bytes32 conditionIdCurrent2 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 0);
        bytes32 conditionIdExplicit2 = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, 2);
        
        // Should now match epoch 2
        assertEq(conditionIdCurrent2, conditionIdExplicit2);
        assertTrue(conditionIdCurrent != conditionIdCurrent2);
    }

    // ============ Integration with Resolution ============

    function test_ResolveLastCompletedEpoch() public {
        vm.prank(owner);
        marketController.createMarket(dailyMarketId, BINARY_OUTCOMES, 0, DAY);

        uint256 startTime = block.timestamp;

        // Trade in epoch 1
        _executeTrade(dailyMarketId, 1, 1);

        // Move to epoch 2
        vm.warp(startTime + DAY);
        uint256 currentEpoch = market.getCurrentEpoch(dailyMarketId);
        assertEq(currentEpoch, 2);

        // Resolve the last completed epoch (epoch 1)
        uint256 lastCompleted = currentEpoch - 1;
        
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;

        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(dailyMarketId, lastCompleted, BINARY_OUTCOMES, merkleRoot);

        bytes32 conditionId = market.getConditionId(oracle, dailyMarketId, BINARY_OUTCOMES, lastCompleted);
        assertTrue(marketResolver.getResolutionStatus(conditionId));

        // Trading continues in epoch 2
        assertTrue(market.isMarketOpen(dailyMarketId));
        _executeTrade(dailyMarketId, 2, 4); // New trade in epoch 2
    }

    // ============ Helper Functions ============

    function _executeTrade(bytes32 questionId, uint256 nonce, uint256 nonce2) internal {
        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: nonce,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: nonce2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory buySignature = _signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = _signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
    }

    function _signOrder(uint256 privateKey, IMarketController.Order memory order) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Order(address user,bytes32 questionId,uint256 outcome,uint256 amount,uint256 price,uint256 nonce,uint256 expiration,bool isBuyOrder)"),
            order.user,
            order.questionId,
            order.outcome,
            order.amount,
            order.price,
            order.nonce,
            order.expiration,
            order.isBuyOrder
        ));

        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("PredictionMarketOrders"),
            keccak256("1"),
            block.chainid,
            address(marketController)
        ));

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }
}

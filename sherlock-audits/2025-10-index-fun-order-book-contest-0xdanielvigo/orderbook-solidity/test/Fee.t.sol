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

contract FeeTest is Test {
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
    address public charlie;
    address public whale;
    address public marketMaker;
    address public matcher;

    bytes32 public questionId1 = keccak256("BTC_PRICE_BINARY");
    bytes32 public questionId2 = keccak256("ETH_PRICE_BINARY");
    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant BET_AMOUNT = 1000e18;
    uint256 public constant INITIAL_BALANCE = 10000e18;
    uint256 public constant DEFAULT_FEE_RATE = 400; // 4% claim fee
    uint256 public constant DEFAULT_TRADE_FEE_RATE = 100; // 1% trade fee
    uint256 public constant WHALE_FEE_RATE = 200; // 2% for whales
    uint256 public constant WHALE_TRADE_FEE_RATE = 50; // 0.5% trade fee for whales
    uint256 public constant MM_FEE_RATE = 100; // 1% for market makers
    uint256 public constant MM_TRADE_FEE_RATE = 25; // 0.25% trade fee for MMs

    uint256 private alicePrivateKey = 0xa11ce;
    uint256 private bobPrivateKey = 0xb0b;
    uint256 private charliePrivateKey = 0xcc;
    uint256 private whalePrivateKey = 0xcc0c;
    uint256 private marketMakerPrivateKey = 0xdd0d;
    uint256 private matcherPrivateKey = 0xdead;

    event FeeCollected(address indexed user, bytes32 indexed questionId, uint256 feeAmount, uint256 netPayout);
    event TradeFeeCollected(address indexed user, bytes32 indexed questionId, uint256 feeAmount, uint256 netAmount);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event TradeFeeRateUpdated(uint256 oldRate, uint256 newRate);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event UserFeeRateSet(address indexed user, uint256 feeRate);
    event UserTradeFeeRateSet(address indexed user, uint256 feeRate);
    event WinningsClaimed(
        address indexed user, bytes32 indexed questionId, uint256 epoch, uint256 outcome, uint256 payout
    );
    event BatchWinningsClaimed(
        address indexed user, uint256 totalPayout, uint256 claimsProcessed
    );

    function setUp() public {
        vm.startPrank(owner);

        // Deploy collateral token
        collateralToken = new ERC20Mock();

        // Deploy implementation contracts
        MarketContract marketImpl = new MarketContract();
        MarketResolver marketResolverImpl = new MarketResolver();
        PositionTokens positionTokensImpl = new PositionTokens();
        Vault vaultImpl = new Vault();
        MarketController marketControllerImpl = new MarketController();

        // Deploy proxies with initialization
        bytes memory marketInitData = abi.encodeWithSelector(MarketContract.initialize.selector, owner);
        market = MarketContract(address(new ERC1967Proxy(address(marketImpl), marketInitData)));

        bytes memory marketResolverInitData = abi.encodeWithSelector(MarketResolver.initialize.selector, owner, oracle);
        marketResolver = MarketResolver(address(new ERC1967Proxy(address(marketResolverImpl), marketResolverInitData)));

        bytes memory positionTokensInitData = abi.encodeWithSelector(PositionTokens.initialize.selector, owner);
        positionTokens = PositionTokens(address(new ERC1967Proxy(address(positionTokensImpl), positionTokensInitData)));

        bytes memory vaultInitData = abi.encodeWithSelector(
            Vault.initialize.selector,
            owner,
            address(collateralToken),
            owner // temporary, will be updated
        );
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
        marketController =
            MarketController(address(new ERC1967Proxy(address(marketControllerImpl), marketControllerInitData)));

        // Link contracts
        market.setMarketController(address(marketController));
        positionTokens.setMarketController(address(marketController));
        vault.setMarketController(address(marketController));
        marketResolver.setEmergencyResolver(address(marketController));

        vm.stopPrank();

        // Setup user addresses from private keys
        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);
        charlie = vm.addr(charliePrivateKey);
        whale = vm.addr(whalePrivateKey);
        marketMaker = vm.addr(marketMakerPrivateKey);
        matcher = vm.addr(matcherPrivateKey);

        // Set up matcher authorization
        vm.startPrank(owner);
        marketController.setAuthorizedMatcher(matcher, true);
        marketController.setAuthorizedMatcher(owner, true);

        // Set up fee system (claim fees)
        marketController.setFeeRate(DEFAULT_FEE_RATE);
        marketController.setTreasury(treasury);
        
        // Set up trade fee system
        marketController.setTradeFeeRate(DEFAULT_TRADE_FEE_RATE);

        vm.stopPrank();
        
        // Setup user balances
        collateralToken.mint(alice, INITIAL_BALANCE);
        collateralToken.mint(bob, INITIAL_BALANCE);
        collateralToken.mint(charlie, INITIAL_BALANCE);
        collateralToken.mint(whale, INITIAL_BALANCE);
        collateralToken.mint(marketMaker, INITIAL_BALANCE);
        collateralToken.mint(matcher, INITIAL_BALANCE);

        // Users deposit collateral
        vm.startPrank(alice);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(bob);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(charlie);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(whale);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(marketMaker);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(matcher);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();
    }

    // ============ Trade Fee Management Tests ============

    function test_SetTradeFeeRate() public {
        uint256 newTradeFeeRate = 150; // 1.5%

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit TradeFeeRateUpdated(DEFAULT_TRADE_FEE_RATE, newTradeFeeRate);
        
        marketController.setTradeFeeRate(newTradeFeeRate);

        assertEq(marketController.tradeFeeRate(), newTradeFeeRate);
    }

    function test_SetTradeFeeRate_OnlyAuthorizedMatcher() public {
        vm.prank(alice);
        vm.expectRevert();
        marketController.setTradeFeeRate(150);
    }

    function test_SetTradeFeeRate_ExceedsMaximum() public {
        vm.prank(owner);
        vm.expectRevert("Fee rate exceeds maximum");
        marketController.setTradeFeeRate(1001); // > 10%
    }

    function test_SetUserTradeFeeRate() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit UserTradeFeeRateSet(whale, WHALE_TRADE_FEE_RATE);
        
        marketController.setUserTradeFeeRate(whale, WHALE_TRADE_FEE_RATE);

        assertEq(marketController.userTradeFeeRate(whale), WHALE_TRADE_FEE_RATE);
    }

    function test_SetUserTradeFeeRate_OnlyAuthorizedMatcher() public {
        vm.prank(alice);
        vm.expectRevert();
        marketController.setUserTradeFeeRate(whale, WHALE_TRADE_FEE_RATE);
    }

    function test_SetUserTradeFeeRate_ExceedsMaximum() public {
        vm.prank(owner);
        vm.expectRevert("Fee rate exceeds maximum");
        marketController.setUserTradeFeeRate(whale, 1001); // > 10%
    }

    function test_GetEffectiveTradeFeeRate() public {
        // Default user should get default rate
        assertEq(marketController.getEffectiveTradeFeeRate(alice), DEFAULT_TRADE_FEE_RATE);

        // Set custom rate for whale
        vm.prank(owner);
        marketController.setUserTradeFeeRate(whale, WHALE_TRADE_FEE_RATE);

        // Whale should get custom rate
        assertEq(marketController.getEffectiveTradeFeeRate(whale), WHALE_TRADE_FEE_RATE);

        // Alice should still get default rate
        assertEq(marketController.getEffectiveTradeFeeRate(alice), DEFAULT_TRADE_FEE_RATE);
    }

    function test_GetEffectiveTradeFeeRate_ZeroCustomRate() public {
        // Set custom rate to 0 (should use default)
        vm.prank(owner);
        marketController.setUserTradeFeeRate(whale, 0);

        // Should return default rate
        assertEq(marketController.getEffectiveTradeFeeRate(whale), DEFAULT_TRADE_FEE_RATE);
    }

    // ============ Trade Fee Collection Tests - Token Swap ============

    function test_TokenSwap_WithTradeFees() public {
        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10000, 10001);

        // Alice buys from matcher (token swap scenario)
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 matcherBalanceBefore = vault.getAvailableBalance(matcher);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        IMarketController.Order memory order = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000, // 60%
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, order);

        // Calculate expected values
        uint256 paymentAmount = (BET_AMOUNT * 6000) / 10000; // 600
        uint256 expectedTradeFee = (paymentAmount * DEFAULT_TRADE_FEE_RATE) / 10000; // 6
        uint256 expectedNetPayment = paymentAmount - expectedTradeFee; // 594

        vm.prank(matcher);
        vm.expectEmit(true, true, false, true);
        emit TradeFeeCollected(alice, questionId1, expectedTradeFee, expectedNetPayment);
        
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        // Verify balances
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - paymentAmount);
        assertEq(vault.getAvailableBalance(matcher), matcherBalanceBefore + expectedNetPayment);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + expectedTradeFee);
    }

    function test_TokenSwap_WithCustomTradeFeeRate() public {
        // Set whale with lower trade fee rate
        vm.prank(owner);
        marketController.setUserTradeFeeRate(whale, WHALE_TRADE_FEE_RATE);

        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10002, 10003);

        uint256 whaleBalanceBefore = vault.getAvailableBalance(whale);
        uint256 matcherBalanceBefore = vault.getAvailableBalance(matcher);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        IMarketController.Order memory order = IMarketController.Order({
            user: whale,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(whalePrivateKey, order);

        // Calculate expected values with custom rate
        uint256 paymentAmount = (BET_AMOUNT * 6000) / 10000; // 600
        uint256 expectedTradeFee = (paymentAmount * WHALE_TRADE_FEE_RATE) / 10000; // 3 (0.5% of 600)
        uint256 expectedNetPayment = paymentAmount - expectedTradeFee; // 597

        vm.prank(matcher);
        vm.expectEmit(true, true, false, true);
        emit TradeFeeCollected(whale, questionId1, expectedTradeFee, expectedNetPayment);
        
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        // Verify whale paid lower fee
        assertEq(vault.getAvailableBalance(whale), whaleBalanceBefore - paymentAmount);
        assertEq(vault.getAvailableBalance(matcher), matcherBalanceBefore + expectedNetPayment);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + expectedTradeFee);
    }

    function test_TokenSwap_NoFeesWhenRateZero() public {
        // Set trade fee rate to 0
        vm.prank(owner);
        marketController.setTradeFeeRate(0);

        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10004, 10005);

        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 matcherBalanceBefore = vault.getAvailableBalance(matcher);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        IMarketController.Order memory order = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, order);

        uint256 paymentAmount = (BET_AMOUNT * 6000) / 10000;

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        // Should have no fees
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - paymentAmount);
        assertEq(vault.getAvailableBalance(matcher), matcherBalanceBefore + paymentAmount);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore); // No change
    }

    // ============ Trade Fee Collection Tests - JIT Minting ============

    function test_JITMinting_WithTradeFees() public {
        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 bobBalanceBefore = vault.getAvailableBalance(bob);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Create matching orders (JIT minting scenario - neither has tokens)
        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000, // Alice pays 60%
            nonce: 3,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000, // Bob pays 40%
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        // Calculate expected values
        uint256 aliceContribution = (BET_AMOUNT * 6000) / 10000; // 600
        uint256 bobContribution = BET_AMOUNT - aliceContribution; // 400
        uint256 aliceTradeFee = (aliceContribution * DEFAULT_TRADE_FEE_RATE) / 10000; // 6
        uint256 bobTradeFee = (bobContribution * DEFAULT_TRADE_FEE_RATE) / 10000; // 4
        uint256 totalTradeFees = aliceTradeFee + bobTradeFee; // 10

        vm.prank(matcher);
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);

        // Verify both parties paid their contributions + fees
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - aliceContribution - aliceTradeFee);
        assertEq(vault.getAvailableBalance(bob), bobBalanceBefore - bobContribution - bobTradeFee);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + totalTradeFees);

        // Verify collateral locked (contributions only, not fees)
        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        assertEq(vault.getTotalLocked(conditionId), BET_AMOUNT);
    }

    function test_JITMinting_WithMixedCustomRates() public {
        // Set custom rates
        vm.startPrank(owner);
        marketController.setUserTradeFeeRate(whale, WHALE_TRADE_FEE_RATE); // 0.5%
        marketController.setUserTradeFeeRate(marketMaker, MM_TRADE_FEE_RATE); // 0.25%
        vm.stopPrank();

        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        uint256 whaleBalanceBefore = vault.getAvailableBalance(whale);
        uint256 mmBalanceBefore = vault.getAvailableBalance(marketMaker);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Whale buys, MM sells
        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: whale,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 7000, // Whale pays 70%
            nonce: 2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: marketMaker,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 7000, // MM pays 30%
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory buySignature = signOrder(whalePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(marketMakerPrivateKey, sellOrder);

        // Calculate expected values
        uint256 whaleContribution = (BET_AMOUNT * 7000) / 10000; // 700
        uint256 mmContribution = BET_AMOUNT - whaleContribution; // 300
        uint256 whaleTradeFee = (whaleContribution * WHALE_TRADE_FEE_RATE) / 10000; // 3.5
        uint256 mmTradeFee = (mmContribution * MM_TRADE_FEE_RATE) / 10000; // 0.75
        uint256 totalTradeFees = whaleTradeFee + mmTradeFee;

        vm.prank(matcher);
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);

        // Verify both parties paid their custom fee rates
        assertEq(vault.getAvailableBalance(whale), whaleBalanceBefore - whaleContribution - whaleTradeFee);
        assertEq(vault.getAvailableBalance(marketMaker), mmBalanceBefore - mmContribution - mmTradeFee);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + totalTradeFees);
    }

    function test_JITMinting_NoFeesWhenRateZero() public {
        // Set trade fee rate to 0
        vm.prank(owner);
        marketController.setTradeFeeRate(0);

        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 bobBalanceBefore = vault.getAvailableBalance(bob);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 4,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        uint256 aliceContribution = (BET_AMOUNT * 6000) / 10000; // 600
        uint256 bobContribution = BET_AMOUNT - aliceContribution; // 400

        vm.prank(matcher);
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);

        // Should have no fees
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - aliceContribution);
        assertEq(vault.getAvailableBalance(bob), bobBalanceBefore - bobContribution);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore); // No change
    }

    // ============ Trade Fee Collection Tests - Order Match ============

    function test_OrderMatch_TokenSwap_WithTradeFees() public {
        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Setup: Bob gets tokens first via JIT minting
        IMarketController.Order memory setupBuyOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5000,
            nonce: 3,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory setupSellOrder = IMarketController.Order({
            user: charlie,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory setupBuySignature = signOrder(bobPrivateKey, setupBuyOrder);
        bytes memory setupSellSignature = signOrder(charliePrivateKey, setupSellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(setupBuyOrder, setupSellOrder, setupBuySignature, setupSellSignature, BET_AMOUNT);

        // Now Bob has tokens and sells to Alice (token swap)
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 bobBalanceBefore = vault.getAvailableBalance(bob);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6500, // Alice willing to pay 65%
            nonce: 5,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000, // Bob sells at 60%
            nonce: 4,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobSellOrder);

        // Calculate expected values (executes at Bob's price: 60%)
        uint256 paymentAmount = (BET_AMOUNT * 6000) / 10000; // 600
        uint256 expectedTradeFee = (paymentAmount * DEFAULT_TRADE_FEE_RATE) / 10000; // 6
        uint256 expectedNetPayment = paymentAmount - expectedTradeFee; // 594

        vm.prank(matcher);
        marketController.executeOrderMatch(aliceBuyOrder, bobSellOrder, aliceSignature, bobSignature, BET_AMOUNT);

        // Verify balances
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - paymentAmount);
        assertEq(vault.getAvailableBalance(bob), bobBalanceBefore + expectedNetPayment);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + expectedTradeFee);
    }

    // ============ Full Lifecycle Tests (Trade Fees + Claim Fees) ============

    function test_FullLifecycle_BothFeeTypes() public {
        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10006, 10007);

        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Step 1: Alice buys (pays trade fee)
        IMarketController.Order memory order = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 6,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, order);

        // Calculate trade fee
        uint256 paymentAmount = (BET_AMOUNT * 6000) / 10000; // 600
        uint256 tradeFee = (paymentAmount * DEFAULT_TRADE_FEE_RATE) / 10000; // 6

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        uint256 aliceAfterTrade = vault.getAvailableBalance(alice);
        uint256 treasuryAfterTrade = vault.getAvailableBalance(treasury);

        // Verify trade fee was collected
        assertEq(aliceAfterTrade, aliceBalanceBefore - paymentAmount);
        assertEq(treasuryAfterTrade, treasuryBalanceBefore + tradeFee);

        // Step 2: Resolve market (outcome 1 wins)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // Step 3: Alice claims winnings (pays claim fee)
        bytes32[] memory proof = new bytes32[](0);

        // Calculate claim fee
        uint256 claimFee = (BET_AMOUNT * DEFAULT_FEE_RATE) / 10000; // 40 (4%)
        uint256 netPayout = BET_AMOUNT - claimFee; // 960

        vm.prank(alice);
        uint256 actualPayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        // Verify claim fee was collected
        assertEq(actualPayout, netPayout);
        assertEq(vault.getAvailableBalance(alice), aliceAfterTrade + netPayout);
        assertEq(vault.getAvailableBalance(treasury), treasuryAfterTrade + claimFee);

        // Total fees collected: tradeFee + claimFee
        uint256 totalFeesCollected = tradeFee + claimFee; // 6 + 40 = 46
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + totalFeesCollected);

        // Alice's net profit: netPayout - paymentAmount
        // 960 - 600 = 360 profit
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - paymentAmount + netPayout);
    }

    function test_FullLifecycle_WithCustomRates() public {
        // Set whale with custom rates for both fees
        vm.startPrank(owner);
        marketController.setUserTradeFeeRate(whale, WHALE_TRADE_FEE_RATE); // 0.5% trade fee
        marketController.setUserFeeRate(whale, WHALE_FEE_RATE); // 2% claim fee
        vm.stopPrank();

        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10008, 10009);

        uint256 whaleBalanceBefore = vault.getAvailableBalance(whale);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Step 1: Whale buys (pays lower trade fee)
        IMarketController.Order memory order = IMarketController.Order({
            user: whale,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 3,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(whalePrivateKey, order);

        uint256 paymentAmount = (BET_AMOUNT * 6000) / 10000; // 600
        uint256 tradeFee = (paymentAmount * WHALE_TRADE_FEE_RATE) / 10000; // 3 (0.5%)

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        uint256 whaleAfterTrade = vault.getAvailableBalance(whale);
        uint256 treasuryAfterTrade = vault.getAvailableBalance(treasury);

        assertEq(whaleAfterTrade, whaleBalanceBefore - paymentAmount);
        assertEq(treasuryAfterTrade, treasuryBalanceBefore + tradeFee);

        // Step 2: Resolve and claim (pays lower claim fee)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        bytes32[] memory proof = new bytes32[](0);

        uint256 claimFee = (BET_AMOUNT * WHALE_FEE_RATE) / 10000; // 20 (2%)
        uint256 netPayout = BET_AMOUNT - claimFee; // 980

        vm.prank(whale);
        uint256 actualPayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        assertEq(actualPayout, netPayout);

        // Total fees: 3 (trade) + 20 (claim) = 23 (vs 46 for regular users)
        uint256 totalFeesCollected = tradeFee + claimFee;
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + totalFeesCollected);

        // Whale saves: (6-3) + (40-20) = 23 in fees
    }

    // ============ Claim Fee Management Tests ============

    function test_SetFeeRate() public {
        uint256 newFeeRate = 500; // 5%

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit FeeRateUpdated(DEFAULT_FEE_RATE, newFeeRate);
        
        marketController.setFeeRate(newFeeRate);

        assertEq(marketController.feeRate(), newFeeRate);
    }

    function test_SetFeeRate_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        marketController.setFeeRate(500);
    }

    function test_SetFeeRate_ExceedsMaximum() public {
        vm.prank(owner);
        vm.expectRevert("Fee rate exceeds maximum");
        marketController.setFeeRate(1001); // > 10%
    }

    function test_SetTreasury() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit TreasuryUpdated(treasury, newTreasury);
        
        marketController.setTreasury(newTreasury);

        assertEq(marketController.treasury(), newTreasury);
    }

    function test_SetTreasury_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        marketController.setTreasury(makeAddr("newTreasury"));
    }

    function test_SetTreasury_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid treasury address");
        marketController.setTreasury(address(0));
    }

    function test_SetUserFeeRate() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit UserFeeRateSet(whale, WHALE_FEE_RATE);
        
        marketController.setUserFeeRate(whale, WHALE_FEE_RATE);

        assertEq(marketController.userFeeRate(whale), WHALE_FEE_RATE);
    }

    function test_SetUserFeeRate_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        marketController.setUserFeeRate(whale, WHALE_FEE_RATE);
    }

    function test_SetUserFeeRate_ExceedsMaximum() public {
        vm.prank(owner);
        vm.expectRevert("Fee rate exceeds maximum");
        marketController.setUserFeeRate(whale, 1001); // > 10%
    }

    function test_GetEffectiveFeeRate() public {
        // Default user should get default rate
        assertEq(marketController.getEffectiveFeeRate(alice), DEFAULT_FEE_RATE);

        // Set custom rate for whale
        vm.prank(owner);
        marketController.setUserFeeRate(whale, WHALE_FEE_RATE);

        // Whale should get custom rate
        assertEq(marketController.getEffectiveFeeRate(whale), WHALE_FEE_RATE);

        // Alice should still get default rate
        assertEq(marketController.getEffectiveFeeRate(alice), DEFAULT_FEE_RATE);
    }

    function test_GetEffectiveFeeRate_ZeroCustomRate() public {
        // Set custom rate to 0 (should use default)
        vm.prank(owner);
        marketController.setUserFeeRate(whale, 0);

        // Should return default rate
        assertEq(marketController.getEffectiveFeeRate(whale), DEFAULT_FEE_RATE);
    }

    // ============ Single Claim Fee Tests ============

    function test_ClaimWinnings_WithFees() public {
        // Create and resolve market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10010, 10011);

        // Alice places a bet
        IMarketController.Order memory order = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 7,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, order);

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        // Resolve market (outcome 1 wins)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // Check balances before claim
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Calculate expected fee and net payout
        uint256 expectedFee = (BET_AMOUNT * DEFAULT_FEE_RATE) / 10000;
        uint256 expectedNetPayout = BET_AMOUNT - expectedFee;

        // Alice claims winnings
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit FeeCollected(alice, questionId1, expectedFee, expectedNetPayout);
        
        uint256 actualPayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        // Verify payout amount
        assertEq(actualPayout, expectedNetPayout);

        // Verify balances after claim
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + expectedNetPayout);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + expectedFee);
    }

    function test_ClaimWinnings_WithCustomFeeRate() public {
        // Set whale with lower fee rate
        vm.prank(owner);
        marketController.setUserFeeRate(whale, WHALE_FEE_RATE);

        // Create and resolve market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10012, 10013);

        // Whale places a bet
        IMarketController.Order memory order = IMarketController.Order({
            user: whale,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 4,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(whalePrivateKey, order);

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        // Resolve market
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // Calculate expected fee with custom rate
        uint256 expectedFee = (BET_AMOUNT * WHALE_FEE_RATE) / 10000;
        uint256 expectedNetPayout = BET_AMOUNT - expectedFee;

        // Check balances before claim
        uint256 whaleBalanceBefore = vault.getAvailableBalance(whale);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Whale claims winnings
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(whale);
        vm.expectEmit(true, true, false, true);
        emit FeeCollected(whale, questionId1, expectedFee, expectedNetPayout);
        
        uint256 actualPayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        // Verify lower fee was applied
        assertEq(actualPayout, expectedNetPayout);
        assertEq(vault.getAvailableBalance(whale), whaleBalanceBefore + expectedNetPayout);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + expectedFee);
    }

    function test_ClaimWinnings_NoFeesWithoutTreasury() public {
        // Set fee rate to 0
        vm.prank(owner);
        marketController.setFeeRate(0);

        // Create and resolve market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10014, 10015);

        // Alice places a bet
        IMarketController.Order memory order = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 8,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, order);

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        // Resolve market
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // Check balances before claim
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Alice claims winnings
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(alice);
        uint256 actualPayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        // Should get full amount with no fees
        assertEq(actualPayout, BET_AMOUNT);
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + BET_AMOUNT);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore); // No change
    }

    // ============ Batch Claim Fee Tests ============

    function test_BatchClaimWinnings_WithFees() public {
        // Create multiple markets
        vm.startPrank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);
        marketController.createMarket(questionId2, BINARY_OUTCOMES, 0, 0);
        vm.stopPrank();

        // Give matcher inventory for both markets
        _giveMatcherInventory(questionId1, 10016, 10017);
        _giveMatcherInventory(questionId2, 10018, 10019);

        // Alice places bets on both markets
        vm.startPrank(matcher);
        
        // Market 1
        IMarketController.Order memory order1 = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 9,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });
        bytes memory signature1 = signOrder(alicePrivateKey, order1);
        marketController.executeSingleOrder(order1, signature1, BET_AMOUNT, matcher);

        // Market 2
        IMarketController.Order memory order2 = IMarketController.Order({
            user: alice,
            questionId: questionId2,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 10,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });
        bytes memory signature2 = signOrder(alicePrivateKey, order2);
        marketController.executeSingleOrder(order2, signature2, BET_AMOUNT, matcher);
        
        vm.stopPrank();

        // Resolve both markets
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.startPrank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);
        marketResolver.resolveMarketEpoch(questionId2, 1, BINARY_OUTCOMES, merkleRoot);
        vm.stopPrank();

        // Check balances before batch claim
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Calculate expected totals
        uint256 totalGross = BET_AMOUNT * 2;
        uint256 totalFees = (totalGross * DEFAULT_FEE_RATE) / 10000;
        uint256 totalNet = totalGross - totalFees;

        // Prepare batch claim
        bytes32[] memory proof = new bytes32[](0);
        IMarketController.ClaimRequest[] memory claims = new IMarketController.ClaimRequest[](2);
        
        claims[0] = IMarketController.ClaimRequest({
            questionId: questionId1,
            epoch: 1,
            outcome: 1,
            merkleProof: proof
        });
        
        claims[1] = IMarketController.ClaimRequest({
            questionId: questionId2,
            epoch: 1,
            outcome: 1,
            merkleProof: proof
        });

        // Execute batch claim
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit BatchWinningsClaimed(alice, totalNet, 2);
        
        uint256 actualTotalPayout = marketController.batchClaimWinnings(claims);

        // Verify results
        assertEq(actualTotalPayout, totalNet);
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + totalNet);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + totalFees);
    }

    function test_BatchClaimWinnings_MixedFeeRates() public {
        // Set whale with lower fee rate
        vm.prank(owner);
        marketController.setUserFeeRate(whale, WHALE_FEE_RATE);

        // Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Give matcher inventory
        _giveMatcherInventory(questionId1, 10020, 10021);

        // Whale bets
        vm.startPrank(matcher);
        
        IMarketController.Order memory whaleOrder = IMarketController.Order({
            user: whale,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 5,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });
        bytes memory whaleSignature = signOrder(whalePrivateKey, whaleOrder);
        marketController.executeSingleOrder(whaleOrder, whaleSignature, BET_AMOUNT, matcher);

        vm.stopPrank();

        // Resolve market (outcome 1 wins)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // Whale claims
        bytes32[] memory proof = new bytes32[](0);

        // Check whale gets lower fee
        uint256 whaleExpectedFee = (BET_AMOUNT * WHALE_FEE_RATE) / 10000;
        uint256 whaleExpectedNet = BET_AMOUNT - whaleExpectedFee;
        
        uint256 whaleBalanceBefore = vault.getAvailableBalance(whale);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        vm.prank(whale);
        uint256 whalePayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        assertEq(whalePayout, whaleExpectedNet);
        assertEq(vault.getAvailableBalance(whale), whaleBalanceBefore + whaleExpectedNet);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + whaleExpectedFee);
    }

    // ============ Edge Cases and Error Conditions ============

    function test_ClaimWinnings_ZeroAmount() public {
        // Create and resolve market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Don't place any bets

        // Resolve market
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // Try to claim with no tokens
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(alice);
        vm.expectRevert("No tokens to claim");
        marketController.claimWinnings(questionId1, 1, 1, proof);
    }

    function test_SetFeeRate_BoundaryValues() public {
        vm.startPrank(owner);

        // Test maximum allowed fee (10%)
        marketController.setFeeRate(1000);
        assertEq(marketController.feeRate(), 1000);

        // Test zero fee
        marketController.setFeeRate(0);
        assertEq(marketController.feeRate(), 0);

        // Test just over maximum
        vm.expectRevert("Fee rate exceeds maximum");
        marketController.setFeeRate(1001);

        vm.stopPrank();
    }

    function test_FeeCalculation_Precision() public {
        // Test fee calculations don't lose precision
        vm.prank(owner);
        marketController.setFeeRate(333); // 3.33%

        // Create and resolve market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Use odd amounts to test precision
        uint256 oddAmount = 1001e18;

        // Give matcher inventory
        _giveMatcherInventoryAmount(questionId1, 10022, 10023, oddAmount);

        // Alice places odd-sized bet
        IMarketController.Order memory order = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: oddAmount,
            price: 6000,
            nonce: 11,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, order);

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, oddAmount, matcher);

        // Resolve market
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // Calculate expected values
        uint256 expectedFee = (oddAmount * 333) / 10000; // Should be precise
        uint256 expectedNet = oddAmount - expectedFee;

        // Claim and verify
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(alice);
        uint256 actualPayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        assertEq(actualPayout, expectedNet);
        
        // Verify the fee + net equals original amount (no precision loss)
        assertEq(expectedFee + expectedNet, oddAmount);
    }

    function test_MultiTierFeeSystem() public {
        // Set up different fee tiers for both trade and claim fees
        vm.startPrank(owner);
        // Claim fees
        marketController.setUserFeeRate(whale, WHALE_FEE_RATE); // 2%
        marketController.setUserFeeRate(marketMaker, MM_FEE_RATE); // 1%
        // Trade fees
        marketController.setUserTradeFeeRate(whale, WHALE_TRADE_FEE_RATE); // 0.5%
        marketController.setUserTradeFeeRate(marketMaker, MM_TRADE_FEE_RATE); // 0.25%
        vm.stopPrank();

        // Verify different users get different rates for both fee types
        // Claim fees
        assertEq(marketController.getEffectiveFeeRate(alice), DEFAULT_FEE_RATE); // 4%
        assertEq(marketController.getEffectiveFeeRate(whale), WHALE_FEE_RATE); // 2%
        assertEq(marketController.getEffectiveFeeRate(marketMaker), MM_FEE_RATE); // 1%
        
        // Trade fees
        assertEq(marketController.getEffectiveTradeFeeRate(alice), DEFAULT_TRADE_FEE_RATE); // 1%
        assertEq(marketController.getEffectiveTradeFeeRate(whale), WHALE_TRADE_FEE_RATE); // 0.5%
        assertEq(marketController.getEffectiveTradeFeeRate(marketMaker), MM_TRADE_FEE_RATE); // 0.25%
    }

    // ============ Helper Functions ============

    function _giveMatcherInventory(bytes32 questionId, uint256 nonce1, uint256 nonce2) internal {
        _giveMatcherInventoryAmount(questionId, nonce1, nonce2, BET_AMOUNT * 2);
    }

    function _giveMatcherInventoryAmount(bytes32 questionId, uint256 nonce1, uint256 nonce2, uint256 amount) internal {
        IMarketController.Order memory matcherBuyOrder = IMarketController.Order({
            user: matcher,
            questionId: questionId,
            outcome: 1,
            amount: amount,
            price: 5000,
            nonce: nonce1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId,
            outcome: 1,
            amount: amount,
            price: 5000,
            nonce: nonce2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory matcherSig = signOrder(matcherPrivateKey, matcherBuyOrder);
        bytes memory bobSig = signOrder(bobPrivateKey, bobSellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(matcherBuyOrder, bobSellOrder, matcherSig, bobSig, amount);
    }

    function signOrder(uint256 privateKey, IMarketController.Order memory order) internal view returns (bytes memory) {
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

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

contract TradingHoursTest is Test {
    MarketContract public market;
    MarketController public marketController;
    MarketResolver public marketResolver;
    PositionTokens public positionTokens;
    Vault public vault;
    ERC20Mock public collateralToken;

    address public owner = makeAddr("owner");
    address public oracle = makeAddr("oracle");
    address public alice;
    address public bob;
    address public matcher;

    bytes32 public stockQuestionId = keccak256("AAPL_STOCK_PRICE");
    bytes32 public cryptoQuestionId = keccak256("BTC_CRYPTO_PRICE");
    bytes32 public forexQuestionId = keccak256("EURUSD_FOREX");
    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant BET_AMOUNT = 1000e18;
    uint256 public constant INITIAL_BALANCE = 10000e18;

    uint256 private alicePrivateKey = 0xa11ce;
    uint256 private bobPrivateKey = 0xb0b;
    uint256 private matcherPrivateKey = 0xdead;

    event GlobalTradingPauseChanged(bool paused);
    event MarketTradingPauseChanged(bytes32 indexed questionId, bool paused);
    event BatchMarketTradingPauseChanged(bytes32[] questionIds, bool paused);

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

        // Market proxy
        bytes memory marketInitData = abi.encodeWithSelector(MarketContract.initialize.selector, owner);
        market = MarketContract(address(new ERC1967Proxy(address(marketImpl), marketInitData)));

        // MarketResolver proxy
        bytes memory marketResolverInitData = abi.encodeWithSelector(MarketResolver.initialize.selector, owner, oracle);
        marketResolver = MarketResolver(address(new ERC1967Proxy(address(marketResolverImpl), marketResolverInitData)));

        // PositionTokens proxy
        bytes memory positionTokensInitData = abi.encodeWithSelector(PositionTokens.initialize.selector, owner);
        positionTokens = PositionTokens(address(new ERC1967Proxy(address(positionTokensImpl), positionTokensInitData)));

        // Vault proxy
        bytes memory vaultInitData = abi.encodeWithSelector(
            Vault.initialize.selector,
            owner,
            address(collateralToken),
            owner // temporary, will be updated
        );
        vault = Vault(address(new ERC1967Proxy(address(vaultImpl), vaultInitData)));

        // MarketController proxy
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

        // Set up user addresses from private keys
        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);
        matcher = vm.addr(matcherPrivateKey);

        // Authorize matcher and owner before creating markets
        vm.startPrank(owner);
        marketController.setAuthorizedMatcher(matcher, true);
        marketController.setAuthorizedMatcher(owner, true);

        // Create test markets
        marketController.createMarket(stockQuestionId, BINARY_OUTCOMES, 0, 0);
        marketController.createMarket(cryptoQuestionId, BINARY_OUTCOMES, 0, 0);
        marketController.createMarket(forexQuestionId, BINARY_OUTCOMES, 0, 0);

        vm.stopPrank();

        // Setup user balances
        collateralToken.mint(alice, INITIAL_BALANCE);
        collateralToken.mint(bob, INITIAL_BALANCE);
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

        vm.startPrank(matcher);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();
    }

    // ============ Basic Trading Hours Tests ============

    function test_InitialTradingState() public view {
        // All markets should be active by default
        assertFalse(marketController.globalTradingPaused());
        assertFalse(marketController.marketTradingPaused(stockQuestionId));
        assertFalse(marketController.marketTradingPaused(cryptoQuestionId));
        assertFalse(marketController.marketTradingPaused(forexQuestionId));

        assertTrue(marketController.isTradingActive(stockQuestionId));
        assertTrue(marketController.isTradingActive(cryptoQuestionId));
        assertTrue(marketController.isTradingActive(forexQuestionId));
    }

    function test_SetGlobalTradingPaused() public {
        // Only owner can set global pause
        vm.prank(alice);
        vm.expectRevert();
        marketController.setGlobalTradingPaused(true);

        // Owner can set global pause
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit GlobalTradingPauseChanged(true);
        marketController.setGlobalTradingPaused(true);

        assertTrue(marketController.globalTradingPaused());
        assertFalse(marketController.isTradingActive(stockQuestionId));
        assertFalse(marketController.isTradingActive(cryptoQuestionId));
        assertFalse(marketController.isTradingActive(forexQuestionId));

        // Resume trading
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit GlobalTradingPauseChanged(false);
        marketController.setGlobalTradingPaused(false);

        assertFalse(marketController.globalTradingPaused());
        assertTrue(marketController.isTradingActive(stockQuestionId));
        assertTrue(marketController.isTradingActive(cryptoQuestionId));
        assertTrue(marketController.isTradingActive(forexQuestionId));
    }

    function test_SetMarketTradingPaused() public {
        // Only owner can set market pause
        vm.prank(alice);
        vm.expectRevert();
        marketController.setMarketTradingPaused(stockQuestionId, true);

        // Owner can pause specific market
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit MarketTradingPauseChanged(stockQuestionId, true);
        marketController.setMarketTradingPaused(stockQuestionId, true);

        assertTrue(marketController.marketTradingPaused(stockQuestionId));
        assertFalse(marketController.isTradingActive(stockQuestionId));

        // Other markets still active
        assertFalse(marketController.marketTradingPaused(cryptoQuestionId));
        assertTrue(marketController.isTradingActive(cryptoQuestionId));

        // Resume specific market
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit MarketTradingPauseChanged(stockQuestionId, false);
        marketController.setMarketTradingPaused(stockQuestionId, false);

        assertFalse(marketController.marketTradingPaused(stockQuestionId));
        assertTrue(marketController.isTradingActive(stockQuestionId));
    }

    function test_BatchSetMarketTradingPaused() public {
        bytes32[] memory questionIds = new bytes32[](2);
        questionIds[0] = stockQuestionId;
        questionIds[1] = forexQuestionId;

        // Only owner can batch pause
        vm.prank(alice);
        vm.expectRevert();
        marketController.batchSetMarketTradingPaused(questionIds, true);

        // Owner can batch pause markets
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit BatchMarketTradingPauseChanged(questionIds, true);
        marketController.batchSetMarketTradingPaused(questionIds, true);

        assertTrue(marketController.marketTradingPaused(stockQuestionId));
        assertTrue(marketController.marketTradingPaused(forexQuestionId));
        assertFalse(marketController.marketTradingPaused(cryptoQuestionId));

        assertFalse(marketController.isTradingActive(stockQuestionId));
        assertFalse(marketController.isTradingActive(forexQuestionId));
        assertTrue(marketController.isTradingActive(cryptoQuestionId));

        // Batch resume
        vm.prank(owner);
        marketController.batchSetMarketTradingPaused(questionIds, false);

        assertFalse(marketController.marketTradingPaused(stockQuestionId));
        assertFalse(marketController.marketTradingPaused(forexQuestionId));
        assertTrue(marketController.isTradingActive(stockQuestionId));
        assertTrue(marketController.isTradingActive(forexQuestionId));
    }

    // ============ Trading Function Tests with Hours Control ============

    function test_ExecuteOrderMatch_WhenTradingActive() public {
        // Should work when trading is active
        IMarketController.Order memory buyOrder = createBuyOrder(alice, stockQuestionId, 1);
        IMarketController.Order memory sellOrder = createSellOrder(bob, stockQuestionId, 2);

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);

        // Verify order was executed
        bytes32 buyOrderHash = marketController.getOrderHash(buyOrder);
        assertEq(marketController.getOrderFillAmount(buyOrderHash), BET_AMOUNT);
    }

    function test_ExecuteOrderMatch_WhenMarketPaused() public {
        // Pause specific market
        vm.prank(owner);
        marketController.setMarketTradingPaused(stockQuestionId, true);

        // Should revert when market is paused
        IMarketController.Order memory buyOrder = createBuyOrder(alice, stockQuestionId, 3);
        IMarketController.Order memory sellOrder = createSellOrder(bob, stockQuestionId, 4);

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        vm.expectRevert("Market trading paused");
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);

        // Other markets should still work
        IMarketController.Order memory buyOrder2 = createBuyOrder(alice, cryptoQuestionId, 5);
        IMarketController.Order memory sellOrder2 = createSellOrder(bob, cryptoQuestionId, 6);

        bytes memory buySignature2 = signOrder(alicePrivateKey, buyOrder2);
        bytes memory sellSignature2 = signOrder(bobPrivateKey, sellOrder2);

        vm.prank(matcher);
        marketController.executeOrderMatch(buyOrder2, sellOrder2, buySignature2, sellSignature2, BET_AMOUNT);
    }

    function test_ExecuteOrderMatch_WhenGloballyPaused() public {
        // Pause all trading
        vm.prank(owner);
        marketController.setGlobalTradingPaused(true);

        // Should revert for all markets
        IMarketController.Order memory buyOrder = createBuyOrder(alice, stockQuestionId, 7);
        IMarketController.Order memory sellOrder = createSellOrder(bob, stockQuestionId, 8);

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        vm.expectRevert("Global trading paused");
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);

        IMarketController.Order memory buyOrder2 = createBuyOrder(alice, cryptoQuestionId, 9);
        IMarketController.Order memory sellOrder2 = createSellOrder(bob, cryptoQuestionId, 10);

        bytes memory buySignature2 = signOrder(alicePrivateKey, buyOrder2);
        bytes memory sellSignature2 = signOrder(bobPrivateKey, sellOrder2);

        vm.prank(matcher);
        vm.expectRevert("Global trading paused");
        marketController.executeOrderMatch(buyOrder2, sellOrder2, buySignature2, sellSignature2, BET_AMOUNT);
    }

    function test_ExecuteSingleOrder_WhenTradingActive() public {
        // Give matcher inventory first
        _giveMatcherInventory(stockQuestionId, 9990, 9991);

        // Should work when trading is active
        IMarketController.Order memory order = createBuyOrder(alice, stockQuestionId, 11);
        bytes memory signature = signOrder(alicePrivateKey, order);

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        // Verify order was executed
        bytes32 orderHash = marketController.getOrderHash(order);
        assertEq(marketController.getOrderFillAmount(orderHash), BET_AMOUNT);
    }

    function test_ExecuteSingleOrder_WhenMarketPaused() public {
        // Pause specific market
        vm.prank(owner);
        marketController.setMarketTradingPaused(stockQuestionId, true);

        // Should revert when market is paused
        IMarketController.Order memory order = createBuyOrder(alice, stockQuestionId, 12);
        bytes memory signature = signOrder(alicePrivateKey, order);

        vm.prank(matcher);
        vm.expectRevert("Market trading paused");
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);
    }

    function test_ClaimWinnings_IgnoresTradingHours() public {
        // Give matcher inventory
        _giveMatcherInventory(stockQuestionId, 9992, 9993);

        // Place order first
        IMarketController.Order memory order = createBuyOrder(alice, stockQuestionId, 13);
        bytes memory signature = signOrder(alicePrivateKey, order);

        vm.prank(matcher);
        marketController.executeSingleOrder(order, signature, BET_AMOUNT, matcher);

        // Resolve market
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1))); // YES outcome
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(stockQuestionId, 1, BINARY_OUTCOMES, merkleRoot);

        // Pause the market
        vm.prank(owner);
        marketController.setMarketTradingPaused(stockQuestionId, true);

        // Claims should still work
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(alice);
        uint256 payout = marketController.claimWinnings(stockQuestionId, 1, 1, proof);
        assertEq(payout, BET_AMOUNT);
    }

    // ============ Priority Tests (Global vs Market-Specific) ============

    function test_GlobalPauseTakesPrecedence() public {
        // Set market as active but global as paused
        vm.startPrank(owner);
        marketController.setMarketTradingPaused(stockQuestionId, false);
        marketController.setGlobalTradingPaused(true);
        vm.stopPrank();

        // Market should not be tradable due to global pause
        assertFalse(marketController.isTradingActive(stockQuestionId));

        IMarketController.Order memory buyOrder = createBuyOrder(alice, stockQuestionId, 14);
        IMarketController.Order memory sellOrder = createSellOrder(bob, stockQuestionId, 15);

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        vm.expectRevert("Global trading paused");
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
    }

    function test_MarketPauseWhenGlobalActive() public {
        // Global is active but market is paused
        vm.startPrank(owner);
        marketController.setGlobalTradingPaused(false);
        marketController.setMarketTradingPaused(stockQuestionId, true);
        vm.stopPrank();

        // Market should not be tradable due to market-specific pause
        assertFalse(marketController.isTradingActive(stockQuestionId));

        IMarketController.Order memory buyOrder = createBuyOrder(alice, stockQuestionId, 16);
        IMarketController.Order memory sellOrder = createSellOrder(bob, stockQuestionId, 17);

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        vm.expectRevert("Market trading paused");
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
    }

    function test_BothActiveRequired() public {
        // Both global and market must be active for trading
        vm.startPrank(owner);
        marketController.setGlobalTradingPaused(false);
        marketController.setMarketTradingPaused(stockQuestionId, false);
        vm.stopPrank();

        assertTrue(marketController.isTradingActive(stockQuestionId));

        // Trading should work
        IMarketController.Order memory buyOrder = createBuyOrder(alice, stockQuestionId, 18);
        IMarketController.Order memory sellOrder = createSellOrder(bob, stockQuestionId, 19);

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
    }

    // ============ Helper Functions ============

    function _giveMatcherInventory(bytes32 questionId, uint256 nonce1, uint256 nonce2) internal {
        IMarketController.Order memory matcherBuyOrder = IMarketController.Order({
            user: matcher,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT * 2, // Give extra inventory
            price: 5000,
            nonce: nonce1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT * 2,
            price: 5000,
            nonce: nonce2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory matcherSig = signOrder(matcherPrivateKey, matcherBuyOrder);
        bytes memory bobSig = signOrder(bobPrivateKey, bobSellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(matcherBuyOrder, bobSellOrder, matcherSig, bobSig, BET_AMOUNT * 2);
    }

    function createBuyOrder(address user, bytes32 questionId, uint256 nonce) internal view returns (IMarketController.Order memory) {
        return IMarketController.Order({
            user: user,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: nonce,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });
    }

    function createSellOrder(address user, bytes32 questionId, uint256 nonce) internal view returns (IMarketController.Order memory) {
        return IMarketController.Order({
            user: user,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5500,
            nonce: nonce,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });
    }

    // Helper functions for EIP-712 signing
    function getOrderHash(IMarketController.Order memory order) internal view returns (bytes32) {
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

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function signOrder(uint256 privateKey, IMarketController.Order memory order) internal view returns (bytes memory) {
        bytes32 hash = getOrderHash(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }
}

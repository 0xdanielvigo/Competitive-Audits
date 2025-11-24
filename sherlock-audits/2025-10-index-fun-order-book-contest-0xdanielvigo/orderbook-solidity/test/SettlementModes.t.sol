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
 * @title SettlementModesTest
 * @notice Comprehensive tests for JIT minting vs token swap settlement modes
 */
contract SettlementModesTest is Test {
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
    address public charlie;
    address public matcher;

    bytes32 public questionId1 = keccak256("TEST_MARKET_1");
    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant TRADE_AMOUNT = 1000e18;
    uint256 public constant INITIAL_BALANCE = 10000e18;

    uint256 private alicePrivateKey = 0xa11ce;
    uint256 private bobPrivateKey = 0xb0b;
    uint256 private charliePrivateKey = 0xcc;
    uint256 private matcherPrivateKey = 0xdead;

    event CollateralTransferred(bytes32 indexed conditionId, address indexed from, address indexed to, uint256 amount);
    event CollateralLocked(bytes32 indexed conditionId, address indexed user, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy collateral token
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

        bytes memory vaultInitData = abi.encodeWithSelector(
            Vault.initialize.selector, owner, address(collateralToken), owner
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
        marketController = MarketController(address(new ERC1967Proxy(address(marketControllerImpl), marketControllerInitData)));

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
        matcher = vm.addr(matcherPrivateKey);

        // authorize after addresses are set
        vm.startPrank(owner);
        marketController.setAuthorizedMatcher(matcher, true);
        marketController.setAuthorizedMatcher(owner, true);

        // Create test market
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        vm.stopPrank();

        // Fund users
        collateralToken.mint(alice, INITIAL_BALANCE);
        collateralToken.mint(bob, INITIAL_BALANCE);
        collateralToken.mint(charlie, INITIAL_BALANCE);
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

        vm.startPrank(matcher);
        collateralToken.approve(address(vault), INITIAL_BALANCE);
        vault.depositCollateral(INITIAL_BALANCE);
        vm.stopPrank();
    }

    // ============ JIT Minting Scenario Tests ============

    function test_JITMinting_ProportionalContributions() public {
        // Scenario: Neither Alice nor Bob have tokens
        // Alice wants to buy YES at 60% → pays $600
        // Bob wants to sell YES at 60% (= buy NO at 40%) → pays $400
        // Total: $1000 creates complete set

        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 bobBalanceBefore = vault.getAvailableBalance(bob);

        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1, // YES
            amount: TRADE_AMOUNT,
            price: 6000, // 60%
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1, // YES
            amount: TRADE_AMOUNT,
            price: 6000, // 60%
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobSellOrder);

        // Execute match
        vm.prank(matcher);
        marketController.executeOrderMatch(aliceBuyOrder, bobSellOrder, aliceSignature, bobSignature, TRADE_AMOUNT);

        // Verify proportional contributions
        uint256 aliceExpectedPayment = (TRADE_AMOUNT * 6000) / 10000; // $600
        uint256 bobExpectedPayment = TRADE_AMOUNT - aliceExpectedPayment; // $400

        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - aliceExpectedPayment, "Alice should pay $600");
        assertEq(vault.getAvailableBalance(bob), bobBalanceBefore - bobExpectedPayment, "Bob should pay $400");

        // Verify token distribution
        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 yesTokenId = positionTokens.getTokenId(conditionId, 1);
        uint256 noTokenId = positionTokens.getTokenId(conditionId, 2);

        assertEq(positionTokens.balanceOf(alice, yesTokenId), TRADE_AMOUNT, "Alice should have YES tokens");
        assertEq(positionTokens.balanceOf(alice, noTokenId), 0, "Alice should not have NO tokens");
        assertEq(positionTokens.balanceOf(bob, yesTokenId), 0, "Bob should not have YES tokens");
        assertEq(positionTokens.balanceOf(bob, noTokenId), TRADE_AMOUNT, "Bob should have NO tokens");

        // Verify total locked equals contributions
        assertEq(vault.getTotalLocked(conditionId), TRADE_AMOUNT, "Total locked should equal $1000");
    }

    function test_JITMinting_DifferentPrices() public {
        // Scenario: Trade at 40% price point
        // Alice buys YES at 40% → pays $400
        // Bob sells YES at 40% → pays $600

        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 4000, // 40%
            nonce: 2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 4000, // 40%
            nonce: 2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobSellOrder);

        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 bobBalanceBefore = vault.getAvailableBalance(bob);

        vm.prank(matcher);
        marketController.executeOrderMatch(aliceBuyOrder, bobSellOrder, aliceSignature, bobSignature, TRADE_AMOUNT);

        uint256 aliceExpectedPayment = (TRADE_AMOUNT * 4000) / 10000; // $400
        uint256 bobExpectedPayment = TRADE_AMOUNT - aliceExpectedPayment; // $600

        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - aliceExpectedPayment);
        assertEq(vault.getAvailableBalance(bob), bobBalanceBefore - bobExpectedPayment);
    }

    // ============ Token Swap Scenario Tests ============

    function test_TokenSwap_SellerHasTokens() public {
        // Setup: First trade creates tokens for Bob via JIT minting (order match)
        IMarketController.Order memory bobBuyOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 3,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory charlieSellOrder = IMarketController.Order({
            user: charlie,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 3,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory bobSetupSignature = signOrder(bobPrivateKey, bobBuyOrder);
        bytes memory charlieSetupSignature = signOrder(charliePrivateKey, charlieSellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(bobBuyOrder, charlieSellOrder, bobSetupSignature, charlieSetupSignature, TRADE_AMOUNT);

        // Verify Bob has YES tokens
        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 yesTokenId = positionTokens.getTokenId(conditionId, 1);
        assertEq(positionTokens.balanceOf(bob, yesTokenId), TRADE_AMOUNT, "Bob should have YES tokens");

        // Now Bob sells to Alice (Token Swap mode)
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 bobBalanceBefore = vault.getAvailableBalance(bob);

        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000, // 60%
            nonce: 4,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 4,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobSellOrder);

        // Expect transfer event (burn+mint, not transfer)
        vm.expectEmit(true, true, true, true);
        emit CollateralTransferred(conditionId, alice, bob, (TRADE_AMOUNT * 6000) / 10000);

        vm.prank(matcher);
        marketController.executeOrderMatch(aliceBuyOrder, bobSellOrder, aliceSignature, bobSignature, TRADE_AMOUNT);

        // Verify token swap occurred (now via burn+mint)
        assertEq(positionTokens.balanceOf(alice, yesTokenId), TRADE_AMOUNT, "Alice should have YES tokens");
        assertEq(positionTokens.balanceOf(bob, yesTokenId), 0, "Bob should have transferred all YES tokens");

        // Verify USDC transfer
        uint256 paymentAmount = (TRADE_AMOUNT * 6000) / 10000; // $600
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - paymentAmount, "Alice should pay $600");
        assertEq(vault.getAvailableBalance(bob), bobBalanceBefore + paymentAmount, "Bob should receive $600");
    }

    function test_TokenSwap_NoNewMinting() public {
        // Setup: Create tokens via initial order match
        IMarketController.Order memory bobBuyOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 5,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory charlieSellOrder = IMarketController.Order({
            user: charlie,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 5,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory bobSetupSignature = signOrder(bobPrivateKey, bobBuyOrder);
        bytes memory charlieSetupSignature = signOrder(charliePrivateKey, charlieSellOrder);
        
        vm.prank(matcher);
        marketController.executeOrderMatch(bobBuyOrder, charlieSellOrder, bobSetupSignature, charlieSetupSignature, TRADE_AMOUNT);

        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 totalLockedBefore = vault.getTotalLocked(conditionId);

        // Execute swap
        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 6,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 6,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobSellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(aliceBuyOrder, bobSellOrder, aliceSignature, bobSignature, TRADE_AMOUNT);

        // Verify no new collateral was locked (swap doesn't create new positions)
        assertEq(vault.getTotalLocked(conditionId), totalLockedBefore, "Total locked should not change in swap");
    }

    // ============ Partial Fill Scenarios ============

    function test_PartialFill_JITMinting() public {
        uint256 partialAmount = TRADE_AMOUNT / 2; // 500 tokens

        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 7,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 7,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobSellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(aliceBuyOrder, bobSellOrder, aliceSignature, bobSignature, partialAmount);

        // Verify partial contributions
        uint256 aliceExpectedPayment = (partialAmount * 6000) / 10000; // $300
        uint256 bobExpectedPayment = partialAmount - aliceExpectedPayment; // $200

        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 yesTokenId = positionTokens.getTokenId(conditionId, 1);

        assertEq(positionTokens.balanceOf(alice, yesTokenId), partialAmount, "Alice should have 500 YES tokens");
        assertEq(vault.getTotalLocked(conditionId), partialAmount, "Should lock only $500");
    }

    function test_PartialFill_TokenSwap() public {
        // Setup: Bob gets tokens via order match
        IMarketController.Order memory setupBuyOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 8,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory setupSellOrder = IMarketController.Order({
            user: charlie,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 8,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory setupBuySignature = signOrder(bobPrivateKey, setupBuyOrder);
        bytes memory setupSellSignature = signOrder(charliePrivateKey, setupSellOrder);
        vm.prank(matcher);
        marketController.executeOrderMatch(setupBuyOrder, setupSellOrder, setupBuySignature, setupSellSignature, TRADE_AMOUNT);

        // Partial swap
        uint256 partialAmount = TRADE_AMOUNT / 2;

        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 9,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 9,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobSellOrder);

        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 bobBalanceBefore = vault.getAvailableBalance(bob);

        vm.prank(matcher);
        marketController.executeOrderMatch(aliceBuyOrder, bobSellOrder, aliceSignature, bobSignature, partialAmount);

        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 yesTokenId = positionTokens.getTokenId(conditionId, 1);

        // Verify partial swap
        assertEq(positionTokens.balanceOf(alice, yesTokenId), partialAmount);
        assertEq(positionTokens.balanceOf(bob, yesTokenId), TRADE_AMOUNT - partialAmount, "Bob should have 500 left");

        uint256 paymentAmount = (partialAmount * 6000) / 10000; // $300
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - paymentAmount);
        assertEq(vault.getAvailableBalance(bob), bobBalanceBefore + paymentAmount);
    }

    // ============ Single Order with Matcher Tests ============

    function test_SingleOrder_BuyFromMatcherInventory() public {
        // Setup: First, give matcher inventory via order match (JIT minting)
        IMarketController.Order memory matcherBuyOrder = IMarketController.Order({
            user: matcher,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT * 2, // Matcher gets inventory
            price: 5000,
            nonce: 1000,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory charlieOrder = IMarketController.Order({
            user: charlie,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT * 2,
            price: 5000,
            nonce: 1000,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory matcherSig = signOrder(matcherPrivateKey, matcherBuyOrder);
        bytes memory charlieSig = signOrder(charliePrivateKey, charlieOrder);

        // Execute match to give matcher YES tokens
        vm.prank(matcher);
        marketController.executeOrderMatch(matcherBuyOrder, charlieOrder, matcherSig, charlieSig, TRADE_AMOUNT * 2);

        // Verify matcher has inventory
        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 yesTokenId = positionTokens.getTokenId(conditionId, 1);
        assertEq(positionTokens.balanceOf(matcher, yesTokenId), TRADE_AMOUNT * 2, "Matcher should have inventory");

        // Now Alice buys from matcher's inventory
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);

        IMarketController.Order memory aliceOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 10,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, aliceOrder);

        // Matcher sells from inventory
        vm.prank(matcher);
        marketController.executeSingleOrder(aliceOrder, signature, TRADE_AMOUNT, matcher);

        // Verify Alice paid 60% to matcher
        uint256 paymentAmount = (TRADE_AMOUNT * 6000) / 10000;
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore - paymentAmount);

        // Verify tokens transferred
        assertEq(positionTokens.balanceOf(alice, yesTokenId), TRADE_AMOUNT);
        assertEq(positionTokens.balanceOf(matcher, yesTokenId), TRADE_AMOUNT); // Matcher has 1000 left
    }

    function test_SingleOrder_SellRequiresTokens() public {
        // Alice tries to sell without having tokens - should fail

        IMarketController.Order memory aliceOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 11,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory signature = signOrder(alicePrivateKey, aliceOrder);

        vm.prank(matcher);
        vm.expectRevert("Insufficient tokens");
        marketController.executeSingleOrder(aliceOrder, signature, TRADE_AMOUNT, matcher);
    }

    function test_SingleOrder_SellWithTokens() public {
        // Setup: Alice gets tokens first via order match
        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 12,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 12,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceBuySignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSellSignature = signOrder(bobPrivateKey, bobSellOrder);
        
        vm.prank(matcher);
        marketController.executeOrderMatch(aliceBuyOrder, bobSellOrder, aliceBuySignature, bobSellSignature, TRADE_AMOUNT);

        // Now Alice sells to matcher
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 matcherBalanceBefore = vault.getAvailableBalance(matcher);

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 13,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory sellSignature = signOrder(alicePrivateKey, sellOrder);

        vm.prank(matcher);
        marketController.executeSingleOrder(sellOrder, sellSignature, TRADE_AMOUNT, matcher);

        // Verify Alice received payment from matcher
        uint256 paymentAmount = (TRADE_AMOUNT * 6000) / 10000;
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + paymentAmount);
        assertEq(vault.getAvailableBalance(matcher), matcherBalanceBefore - paymentAmount);

        // Verify tokens transferred
        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 yesTokenId = positionTokens.getTokenId(conditionId, 1);
        assertEq(positionTokens.balanceOf(alice, yesTokenId), 0);
        assertEq(positionTokens.balanceOf(matcher, yesTokenId), TRADE_AMOUNT);
    }

    // ============ Edge Cases ============

    function test_InsufficientBalance_JITMinting() public {
        // Alice tries to buy but doesn't have enough collateral
        vm.prank(alice);
        vault.withdrawCollateral(INITIAL_BALANCE - 100); // Leave only $100

        IMarketController.Order memory aliceOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT, // Needs $600
            price: 6000,
            nonce: 14,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 14,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobOrder);

        vm.prank(matcher);
        vm.expectRevert("Insufficient balance");
        marketController.executeOrderMatch(aliceOrder, bobOrder, aliceSignature, bobSignature, TRADE_AMOUNT);
    }

    function test_InsufficientBalance_TokenSwap() public {
        // Alice tries to buy but doesn't have enough for payment
        vm.prank(alice);
        vault.withdrawCollateral(INITIAL_BALANCE - 100); // Leave only $100

        // Bob has tokens to sell - give him tokens via order match
        IMarketController.Order memory bobSetupBuy = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 15,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory charlieSetupSell = IMarketController.Order({
            user: charlie,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 5000,
            nonce: 15,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory bobSetupSignature = signOrder(bobPrivateKey, bobSetupBuy);
        bytes memory charlieSetupSignature = signOrder(charliePrivateKey, charlieSetupSell);
        vm.prank(matcher);
        marketController.executeOrderMatch(bobSetupBuy, charlieSetupSell, bobSetupSignature, charlieSetupSignature, TRADE_AMOUNT);

        // Alice tries to buy from Bob
        IMarketController.Order memory aliceOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000, // Needs $600 but only has $100
            nonce: 16,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory bobOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: 1,
            amount: TRADE_AMOUNT,
            price: 6000,
            nonce: 16,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobOrder);

        vm.prank(matcher);
        vm.expectRevert("Insufficient balance");
        marketController.executeOrderMatch(aliceOrder, bobOrder, aliceSignature, bobSignature, TRADE_AMOUNT);
    }

    // ============ Helper Functions ============

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

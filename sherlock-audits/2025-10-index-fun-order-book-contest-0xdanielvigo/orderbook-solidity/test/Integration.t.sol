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

contract IntegrationTest is Test {
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

    bytes32 public questionId1 = keccak256("BTC_PRICE_BINARY");
    bytes32 public questionId2 = keccak256("ETH_PRICE_BINARY");
    bytes32 public questionId3 = keccak256("SOL_PRICE_BINARY");
    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant BET_AMOUNT = 1000e18;
    uint256 public constant INITIAL_BALANCE = 10000e18;
    uint256 public constant DEFAULT_FEE_RATE = 400; // 4%

    // EIP-712 Domain separator will be calculated by contract
    uint256 private alicePrivateKey = 0xa11ce;
    uint256 private bobPrivateKey = 0xb0b;
    uint256 private matcherPrivateKey = 0xdead;
    
    event WinningsClaimed(
        address indexed user, bytes32 indexed questionId, uint256 epoch, uint256 outcome, uint256 payout
    );
    
    event BatchWinningsClaimed(
        address indexed user, uint256 totalPayout, uint256 claimsProcessed
    );

    event FeeCollected(address indexed user, bytes32 indexed questionId, uint256 feeAmount, uint256 netPayout);
    
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

        // Setup user addresses from private keys
        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);
        matcher = vm.addr(matcherPrivateKey);

        // Now authorize after addresses are set
        vm.startPrank(owner);
        marketController.setAuthorizedMatcher(matcher, true);
        marketController.setAuthorizedMatcher(owner, true);

        // Set up fee system
        marketController.setFeeRate(DEFAULT_FEE_RATE);
        marketController.setTreasury(treasury);

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

    function test_FullOrderMatchingLifecycle() public {
        // 1. Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Verify market exists
        assertEq(market.getOutcomeCount(questionId1), BINARY_OUTCOMES);
        assertTrue(market.getMarketExists(questionId1));
        assertTrue(market.isMarketOpen(questionId1));

        // 2. Create orders using EIP-712
        uint256 outcome = 1; // YES outcome
        uint256 price = 6000; // 60% price in basis points
        uint256 expiration = block.timestamp + 1 hours;
        
        // Alice creates a buy order (wants to buy YES at 60%)
        IMarketController.Order memory aliceBuyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: outcome,
            amount: BET_AMOUNT,
            price: price,
            nonce: 1,
            expiration: expiration,
            isBuyOrder: true
        });

        // Bob creates a sell order (wants to sell YES at 55%)
        IMarketController.Order memory bobSellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId1,
            outcome: outcome,
            amount: BET_AMOUNT,
            price: 5500, // 55% - lower than Alice's buy price, so they can match
            nonce: 1,
            expiration: expiration,
            isBuyOrder: false
        });

        // 3. Sign the orders
        bytes32 aliceOrderHash = getOrderHash(aliceBuyOrder);
        bytes32 bobOrderHash = getOrderHash(bobSellOrder);
        
        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceBuyOrder);
        bytes memory bobSignature = signOrder(bobPrivateKey, bobSellOrder);

        // Verify signatures work with contract
        vm.prank(alice);
        bytes32 contractAliceHash = marketController.getOrderHash(aliceBuyOrder);
        assertEq(aliceOrderHash, contractAliceHash);

        // 4. Execute the match
        vm.prank(matcher);
        marketController.executeOrderMatch(
            aliceBuyOrder,
            bobSellOrder,
            aliceSignature,
            bobSignature,
            BET_AMOUNT
        );

        // 5. Verify the trade executed with complete set minting
        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 yesTokenId = positionTokens.getTokenId(conditionId, 1); // YES tokens
        uint256 noTokenId = positionTokens.getTokenId(conditionId, 2);  // NO tokens

        // Alice (buyer) should have the YES tokens she wanted
        assertEq(positionTokens.balanceOf(alice, yesTokenId), BET_AMOUNT);
        // Alice should NOT have NO tokens
        assertEq(positionTokens.balanceOf(alice, noTokenId), 0);
        
        // Bob (seller) should have received the NO tokens as payment
        assertEq(positionTokens.balanceOf(bob, noTokenId), BET_AMOUNT);
        // Bob should NOT have YES tokens (he sold his position)
        assertEq(positionTokens.balanceOf(bob, yesTokenId), 0);
        
        // Verify the orders were filled
        assertEq(marketController.getOrderFillAmount(aliceOrderHash), BET_AMOUNT);
        assertEq(marketController.getOrderFillAmount(bobOrderHash), BET_AMOUNT);

        // Verify collateral is properly locked (should equal total token amount)
        assertEq(vault.getTotalLocked(conditionId), BET_AMOUNT);

        // 6. Resolve market (YES wins)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1))); // YES outcome
        bytes32 merkleRoot = leaf;

        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        assertTrue(marketResolver.getResolutionStatus(conditionId));

        // 7. Alice claims winnings (she has winning YES tokens) WITH FEES
        bytes32[] memory proof = new bytes32[](0); // Empty proof for single leaf
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Calculate expected fee and net payout
        uint256 expectedFee = (BET_AMOUNT * DEFAULT_FEE_RATE) / 10000;
        uint256 expectedNetPayout = BET_AMOUNT - expectedFee;

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit FeeCollected(alice, questionId1, expectedFee, expectedNetPayout);
        
        uint256 alicePayout = marketController.claimWinnings(questionId1, 1, 1, proof);
        assertEq(alicePayout, expectedNetPayout);

        // Verify Alice received the net payout and treasury received the fee
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + expectedNetPayout);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + expectedFee);

        // Verify Alice's tokens were burned
        assertEq(positionTokens.balanceOf(alice, yesTokenId), 0);
        
        // Bob cannot claim because he holds NO tokens and YES won
        // His NO tokens are now worthless
        assertEq(positionTokens.balanceOf(bob, noTokenId), BET_AMOUNT); // Still has them
        
        // If Bob tried to claim NO tokens, it should fail
        vm.prank(bob);
        bytes32 noLeaf = keccak256(abi.encodePacked(uint256(2)));
        bytes32[] memory noProof = new bytes32[](0);
        vm.expectRevert(); // Should fail because NO didn't win
        marketController.claimWinnings(questionId1, 1, 2, noProof);
    }

    function test_BatchClaimWinnings_MultipleMarkets_WithFees() public {
        // 1. Create multiple markets
        vm.startPrank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);
        marketController.createMarket(questionId2, BINARY_OUTCOMES, 0, 0);
        marketController.createMarket(questionId3, BINARY_OUTCOMES, 0, 0);
        vm.stopPrank();

        uint256 expiration = block.timestamp + 1 hours;
        
        // 2. Give matcher inventory for all markets via order matches
        _giveMatcherInventory(questionId1, 9990, 9991);
        _giveMatcherInventory(questionId2, 9992, 9993);
        _giveMatcherInventory(questionId3, 9994, 9995);
        
        // 3. Alice places orders on multiple markets
        vm.startPrank(matcher);
        
        // Market 1
        IMarketController.Order memory aliceOrder1 = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 3,
            expiration: expiration,
            isBuyOrder: true
        });
        bytes memory aliceSignature1 = signOrder(alicePrivateKey, aliceOrder1);
        marketController.executeSingleOrder(aliceOrder1, aliceSignature1, BET_AMOUNT, matcher);

        // Market 2
        IMarketController.Order memory aliceOrder2 = IMarketController.Order({
            user: alice,
            questionId: questionId2,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 4,
            expiration: expiration,
            isBuyOrder: true
        });
        bytes memory aliceSignature2 = signOrder(alicePrivateKey, aliceOrder2);
        marketController.executeSingleOrder(aliceOrder2, aliceSignature2, BET_AMOUNT, matcher);

        // Market 3
        IMarketController.Order memory aliceOrder3 = IMarketController.Order({
            user: alice,
            questionId: questionId3,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 5,
            expiration: expiration,
            isBuyOrder: true
        });
        bytes memory aliceSignature3 = signOrder(alicePrivateKey, aliceOrder3);
        marketController.executeSingleOrder(aliceOrder3, aliceSignature3, BET_AMOUNT, matcher);
        
        vm.stopPrank();

        // 4. Resolve all markets (YES wins in all)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1))); // YES outcome
        bytes32 merkleRoot = leaf;

        vm.startPrank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);
        marketResolver.resolveMarketEpoch(questionId2, 1, BINARY_OUTCOMES, merkleRoot);
        marketResolver.resolveMarketEpoch(questionId3, 1, BINARY_OUTCOMES, merkleRoot);
        vm.stopPrank();

        // 5. Check balances before batch claim
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);
        
        // Calculate expected totals with fees
        uint256 totalGross = BET_AMOUNT * 3;
        uint256 totalFees = (totalGross * DEFAULT_FEE_RATE) / 10000;
        uint256 totalNet = totalGross - totalFees;
        
        // 6. Prepare batch claim
        bytes32[] memory proof = new bytes32[](0); // Empty proof for single leaf
        IMarketController.ClaimRequest[] memory claims = new IMarketController.ClaimRequest[](3);
        
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
        
        claims[2] = IMarketController.ClaimRequest({
            questionId: questionId3,
            epoch: 1,
            outcome: 1,
            merkleProof: proof
        });

        // 7. Execute batch claim with fees
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit BatchWinningsClaimed(alice, totalNet, 3);
        
        uint256 totalPayout = marketController.batchClaimWinnings(claims);
        
        // 8. Verify results with fees
        assertEq(totalPayout, totalNet);
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + totalNet);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + totalFees);
        
        // Verify tokens were burned
        bytes32 conditionId1 = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 1);
        bytes32 conditionId2 = market.getConditionId(oracle, questionId2, BINARY_OUTCOMES, 1);
        bytes32 conditionId3 = market.getConditionId(oracle, questionId3, BINARY_OUTCOMES, 1);
        
        uint256 tokenId1 = positionTokens.getTokenId(conditionId1, 1);
        uint256 tokenId2 = positionTokens.getTokenId(conditionId2, 1);
        uint256 tokenId3 = positionTokens.getTokenId(conditionId3, 1);
        
        assertEq(positionTokens.balanceOf(alice, tokenId1), 0);
        assertEq(positionTokens.balanceOf(alice, tokenId2), 0);
        assertEq(positionTokens.balanceOf(alice, tokenId3), 0);
    }

    function test_FeeSystemWithPreferentialRates() public {
        // Set up preferential rate for Alice (whale treatment)
        uint256 preferentialRate = 200; // 2% instead of 4%
        vm.prank(owner);
        marketController.setUserFeeRate(alice, preferentialRate);

        // Verify Alice gets preferential rate
        assertEq(marketController.getEffectiveFeeRate(alice), preferentialRate);
        assertEq(marketController.getEffectiveFeeRate(bob), DEFAULT_FEE_RATE);

        // 1. Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        uint256 expiration = block.timestamp + 1 hours;
        
        // Give matcher inventory
        _giveMatcherInventory(questionId1, 9996, 9997);
        
        // 2. Alice places bet with preferential rate
        vm.startPrank(matcher);
        IMarketController.Order memory aliceOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: expiration,
            isBuyOrder: true
        });
        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceOrder);
        marketController.executeSingleOrder(aliceOrder, aliceSignature, BET_AMOUNT, matcher);
        vm.stopPrank();

        // 3. Resolve market (YES wins)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // 4. Alice claims with preferential rate
        bytes32[] memory proof = new bytes32[](0);
        
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        // Calculate expected values with preferential rate
        uint256 expectedFee = (BET_AMOUNT * preferentialRate) / 10000;
        uint256 expectedNetPayout = BET_AMOUNT - expectedFee;

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit FeeCollected(alice, questionId1, expectedFee, expectedNetPayout);
        
        uint256 alicePayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        // 5. Verify Alice paid lower fee
        assertEq(alicePayout, expectedNetPayout);
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + expectedNetPayout);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + expectedFee);
        
        // Verify fee was lower than default
        uint256 defaultFeeWouldBe = (BET_AMOUNT * DEFAULT_FEE_RATE) / 10000;
        assertTrue(expectedFee < defaultFeeWouldBe);
    }

    function test_NoFeesWhenFeeRateZero() public {
        // Set fee rate to 0
        vm.prank(owner);
        marketController.setFeeRate(0);

        // 1. Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);
        
        // Give matcher inventory
        _giveMatcherInventory(questionId1, 9998, 9999);
        
        // 2. Alice places bet
        vm.startPrank(matcher);
        IMarketController.Order memory aliceOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });
        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceOrder);
        marketController.executeSingleOrder(aliceOrder, aliceSignature, BET_AMOUNT, matcher);
        vm.stopPrank();

        // 3. Resolve market (YES wins)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1)));
        bytes32 merkleRoot = leaf;
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // 4. Alice claims with no fees
        bytes32[] memory proof = new bytes32[](0);
        
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);

        vm.prank(alice);
        uint256 alicePayout = marketController.claimWinnings(questionId1, 1, 1, proof);

        // 5. Verify Alice got full amount with no fees
        assertEq(alicePayout, BET_AMOUNT);
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + BET_AMOUNT);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore); // No change
    }

    function test_BatchClaimWinnings_PartialSuccess() public {
        // 1. Create markets
        vm.startPrank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);
        marketController.createMarket(questionId2, BINARY_OUTCOMES, 0, 0);
        vm.stopPrank();

        uint256 expiration = block.timestamp + 1 hours;
        
        // Give matcher inventory for market 1
        _giveMatcherInventory(questionId1, 10000, 10001);
        
        // 2. Alice only bets on market 1
        vm.startPrank(matcher);
        IMarketController.Order memory aliceOrder1 = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: expiration,
            isBuyOrder: true
        });
        bytes memory aliceSignature1 = signOrder(alicePrivateKey, aliceOrder1);
        marketController.executeSingleOrder(aliceOrder1, aliceSignature1, BET_AMOUNT, matcher);
        vm.stopPrank();

        // 3. Resolve only market 1 (YES wins)
        bytes32 leaf = keccak256(abi.encodePacked(uint256(1))); // YES outcome
        bytes32 merkleRoot = leaf;
        
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot);

        // 4. Batch claim includes both markets (one valid, one invalid)
        bytes32[] memory proof = new bytes32[](0);
        IMarketController.ClaimRequest[] memory claims = new IMarketController.ClaimRequest[](2);
        
        claims[0] = IMarketController.ClaimRequest({
            questionId: questionId1,
            epoch: 1,
            outcome: 1,
            merkleProof: proof
        });
        
        claims[1] = IMarketController.ClaimRequest({
            questionId: questionId2, // Not resolved
            epoch: 1,
            outcome: 1,
            merkleProof: proof
        });

        // 5. Execute batch claim - should only process valid claim with fees
        uint256 aliceBalanceBefore = vault.getAvailableBalance(alice);
        uint256 treasuryBalanceBefore = vault.getAvailableBalance(treasury);
        
        // Calculate expected values for only one market
        uint256 expectedFee = (BET_AMOUNT * DEFAULT_FEE_RATE) / 10000;
        uint256 expectedNetPayout = BET_AMOUNT - expectedFee;
        
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit BatchWinningsClaimed(alice, expectedNetPayout, 1); // Only 1 valid claim
        
        uint256 totalPayout = marketController.batchClaimWinnings(claims);
        
        // 6. Verify results
        assertEq(totalPayout, expectedNetPayout); // Only one market claimed
        assertEq(vault.getAvailableBalance(alice), aliceBalanceBefore + expectedNetPayout);
        assertEq(vault.getAvailableBalance(treasury), treasuryBalanceBefore + expectedFee);
    }

    function test_BatchClaimWinnings_EmptyArray() public {
        IMarketController.ClaimRequest[] memory emptyClaims = new IMarketController.ClaimRequest[](0);
        
        vm.prank(alice);
        vm.expectRevert("No claims provided");
        marketController.batchClaimWinnings(emptyClaims);
    }

    function test_BatchClaimWinnings_TooManyClaims() public {
        IMarketController.ClaimRequest[] memory tooManyClaims = new IMarketController.ClaimRequest[](51);
        
        vm.prank(alice);
        vm.expectRevert("Too many claims");
        marketController.batchClaimWinnings(tooManyClaims);
    }

    function test_BatchClaimWinnings_NoValidClaims() public {
        // Create a claim for non-existent market
        bytes32[] memory proof = new bytes32[](0);
        IMarketController.ClaimRequest[] memory claims = new IMarketController.ClaimRequest[](1);
        
        claims[0] = IMarketController.ClaimRequest({
            questionId: keccak256("NON_EXISTENT_MARKET"),
            epoch: 1,
            outcome: 1,
            merkleProof: proof
        });

        vm.prank(alice);
        vm.expectRevert("No valid claims found");
        marketController.batchClaimWinnings(claims);
    }

    function test_SingleOrderExecution() public {
        // 1. Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // 2. Give matcher inventory for outcome 1 (YES tokens)
        _giveMatcherInventory(questionId1, 10002, 10003);

        // 3. Create a buy order from Alice for outcome 1 (YES) - matching what matcher has
        uint256 outcome = 1; // YES outcome (matcher has this)
        uint256 price = 4000; // 40% price
        uint256 expiration = block.timestamp + 1 hours;

        IMarketController.Order memory aliceOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: outcome,
            amount: BET_AMOUNT,
            price: price,
            nonce: 2,
            expiration: expiration,
            isBuyOrder: true
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceOrder);

        // 4. Matcher executes against their own liquidity
        vm.prank(matcher);
        marketController.executeSingleOrder(
            aliceOrder,
            aliceSignature,
            BET_AMOUNT,
            matcher
        );

        // 5. Verify execution
        bytes32 conditionId = market.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        uint256 noTokenId = positionTokens.getTokenId(conditionId, outcome);

        // Alice should have the NO tokens
        assertEq(positionTokens.balanceOf(alice, noTokenId), BET_AMOUNT);

        // Order should be fully filled
        bytes32 orderHash = getOrderHash(aliceOrder);
        assertEq(marketController.getOrderFillAmount(orderHash), BET_AMOUNT);
    }

    function test_OrderCancellation() public {
        // 1. Create market
        vm.prank(owner);
        marketController.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // 2. Create an order
        IMarketController.Order memory aliceOrder = IMarketController.Order({
            user: alice,
            questionId: questionId1,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5000,
            nonce: 3,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory aliceSignature = signOrder(alicePrivateKey, aliceOrder);

        // 3. Alice cancels her own order
        vm.prank(alice);
        marketController.cancelOrder(aliceOrder, aliceSignature);

        // 4. Verify order is cancelled (filled amount equals order amount)
        bytes32 orderHash = getOrderHash(aliceOrder);
        assertEq(marketController.getOrderFillAmount(orderHash), BET_AMOUNT);

        // 5. Try to execute the cancelled order - should fail with "Nonce already used"
        // because cancelOrder marks the nonce as used in _verifyOrder
        vm.prank(matcher);
        vm.expectRevert("Nonce already used");
        marketController.executeSingleOrder(
            aliceOrder,
            aliceSignature,
            BET_AMOUNT,
            matcher
        );
    }

    // Helper function to give matcher inventory
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

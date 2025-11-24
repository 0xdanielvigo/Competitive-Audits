// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MarketController} from "../../src/Market/MarketController.sol";
import {IMarketController} from "../../src/Market/IMarketController.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

contract MarketControllerTest is Test {
    MarketController public marketController;

    address public mockPositionTokens = makeAddr("mockPositionTokens");
    address public mockMarketResolver = makeAddr("mockMarketResolver");
    address public mockVault = makeAddr("mockVault");
    address public mockMarketContract = makeAddr("mockMarketContract");
    address public oracle = makeAddr("oracle");
    address public treasury = makeAddr("treasury");

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public matcher = makeAddr("matcher");

    bytes32 public questionId = keccak256("BTC_PRICE_BINARY");
    bytes32 public conditionId = keccak256("CONDITION_ID");
    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant BET_AMOUNT = 1000e18;
    uint256 public constant DEFAULT_FEE_RATE = 400; // 4%
    uint256 public tokenId1 = 12345;
    uint256 public tokenId2 = 67890;

    uint256 private alicePrivateKey = 0xa11ce;
    uint256 private bobPrivateKey = 0xb0b;

    event OrderFilled(bytes32 indexed orderHash, address indexed taker, uint256 fillAmount, uint256 price);
    event WinningsClaimed(
        address indexed user, bytes32 indexed questionId, uint256 epoch, uint256 outcome, uint256 payout
    );
    event FeeCollected(address indexed user, bytes32 indexed questionId, uint256 feeAmount, uint256 netPayout);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event UserFeeRateSet(address indexed user, uint256 feeRate);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation contract
        MarketController marketControllerImpl = new MarketController();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            MarketController.initialize.selector,
            owner,
            mockPositionTokens,
            mockMarketResolver,
            mockVault,
            mockMarketContract,
            oracle
        );
        marketController = MarketController(address(new ERC1967Proxy(address(marketControllerImpl), initData)));

        // Set up authorized matcher
        marketController.setAuthorizedMatcher(matcher, true);
        marketController.setAuthorizedMatcher(owner, true);

        // Set up fee system
        marketController.setFeeRate(DEFAULT_FEE_RATE);
        marketController.setTreasury(treasury);

        vm.stopPrank();

        // Set up user addresses from private keys
        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);
    }

    //// ============ Initialization Tests ============

    function test_InitialSetup() public view {
        assertEq(marketController.owner(), owner);
        assertEq(address(marketController.positionTokens()), mockPositionTokens);
        assertEq(address(marketController.marketResolver()), mockMarketResolver);
        assertEq(address(marketController.vault()), mockVault);
        assertEq(address(marketController.market()), mockMarketContract);
        assertEq(marketController.oracle(), oracle);
        assertEq(marketController.feeRate(), DEFAULT_FEE_RATE);
        assertEq(marketController.treasury(), treasury);
    }

    // ============ Fee Management Tests ============

    //function test_SetFeeRate() public {
    //    uint256 newFeeRate = 500; // 5%

    //    vm.prank(owner);
    //    vm.expectEmit(false, false, false, true);
    //    emit FeeRateUpdated(DEFAULT_FEE_RATE, newFeeRate);
        
    //    marketController.setFeeRate(newFeeRate);
    //    assertEq(marketController.feeRate(), newFeeRate);
    //}

    //function test_SetFeeRate_OnlyOwner() public {
    //    vm.prank(alice);
    //    vm.expectRevert();
    //    marketController.setFeeRate(500);
    //}

    //function test_SetFeeRate_ExceedsMaximum() public {
    //    vm.prank(owner);
    //    vm.expectRevert("Fee rate exceeds maximum");
    //    marketController.setFeeRate(1001); // > 10%
    //}

    //function test_SetTreasury() public {
    //    address newTreasury = makeAddr("newTreasury");

    //    vm.prank(owner);
    //    vm.expectEmit(true, true, false, false);
    //    emit TreasuryUpdated(treasury, newTreasury);
        
    //    marketController.setTreasury(newTreasury);
    //    assertEq(marketController.treasury(), newTreasury);
    //}

    //function test_SetTreasury_OnlyOwner() public {
    //    vm.prank(alice);
    //    vm.expectRevert();
    //    marketController.setTreasury(makeAddr("newTreasury"));
    //}

    //function test_SetTreasury_InvalidAddress() public {
    //    vm.prank(owner);
    //    vm.expectRevert("Invalid treasury address");
    //    marketController.setTreasury(address(0));
    //}

    //function test_SetUserFeeRate() public {
    //    uint256 customRate = 200; // 2%

    //    vm.prank(owner);
    //    vm.expectEmit(true, false, false, true);
    //    emit UserFeeRateSet(alice, customRate);
        
    //    marketController.setUserFeeRate(alice, customRate);
    //    assertEq(marketController.userFeeRate(alice), customRate);
    //}

    //function test_SetUserFeeRate_OnlyOwner() public {
    //    vm.prank(alice);
    //    vm.expectRevert();
    //    marketController.setUserFeeRate(bob, 200);
    //}

    //function test_SetUserFeeRate_ExceedsMaximum() public {
    //    vm.prank(owner);
    //    vm.expectRevert("Fee rate exceeds maximum");
    //    marketController.setUserFeeRate(alice, 1001); // > 10%
    //}

    //function test_GetEffectiveFeeRate() public {
    //    // Default user should get default rate
    //    assertEq(marketController.getEffectiveFeeRate(alice), DEFAULT_FEE_RATE);

    //    // Set custom rate
    //    uint256 customRate = 200;
    //    vm.prank(owner);
    //    marketController.setUserFeeRate(alice, customRate);

    //    // Should get custom rate
    //    assertEq(marketController.getEffectiveFeeRate(alice), customRate);

    //    // Other users should still get default
    //    assertEq(marketController.getEffectiveFeeRate(bob), DEFAULT_FEE_RATE);
    //}

    //function test_GetEffectiveFeeRate_ZeroCustomRate() public {
    //    // Set custom rate to 0 (should use default)
    //    vm.prank(owner);
    //    marketController.setUserFeeRate(alice, 0);

    //    // Should return default rate
    //    assertEq(marketController.getEffectiveFeeRate(alice), DEFAULT_FEE_RATE);
    //}

    // ============ Order Execution Tests ============

    function test_ExecuteOrderMatch() public {
        // Mock that market is open
        vm.mockCall(mockMarketContract, abi.encodeWithSignature("isMarketOpen(bytes32)", questionId), abi.encode(true));

        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature("getOutcomeCount(bytes32)", questionId),
            abi.encode(BINARY_OUTCOMES)
        );

        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature(
                "getConditionId(address,bytes32,uint256,uint256)", oracle, questionId, BINARY_OUTCOMES, 0
            ),
            abi.encode(conditionId)
        );

        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("getTokenId(bytes32,uint256)", conditionId, 1),
            abi.encode(tokenId1)
        );

        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("getTokenId(bytes32,uint256)", conditionId, 2),
            abi.encode(tokenId2)
        );

        // Mock that seller has NO tokens (triggers JIT minting)
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("balanceOf(address,uint256)", bob, tokenId1),
            abi.encode(0)
        );

        // Calculate proportional payments for JIT minting
        uint256 buyerPayment = (BET_AMOUNT * 6000) / 10000; // Alice pays 60%
        uint256 sellerPayment = BET_AMOUNT - buyerPayment;  // Bob pays 40%
        
        // Mock vault lock calls for BOTH parties (JIT minting mode)
        vm.mockCall(
            mockVault,
            abi.encodeWithSignature("lockCollateral(bytes32,address,uint256)", conditionId, alice, buyerPayment),
            abi.encode()
        );

        vm.mockCall(
            mockVault,
            abi.encodeWithSignature("lockCollateral(bytes32,address,uint256)", conditionId, bob, sellerPayment),
            abi.encode()
        );

        // Mock mintBatch calls for both buyer and seller
        uint256[] memory buyerTokenIds = new uint256[](1);
        uint256[] memory buyerAmounts = new uint256[](1);
        buyerTokenIds[0] = tokenId1;
        buyerAmounts[0] = BET_AMOUNT;

        uint256[] memory sellerTokenIds = new uint256[](1);
        uint256[] memory sellerAmounts = new uint256[](1);
        sellerTokenIds[0] = tokenId2;
        sellerAmounts[0] = BET_AMOUNT;

        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("mintBatch(address,uint256[],uint256[])", alice, buyerTokenIds, buyerAmounts),
            abi.encode()
        );

        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("mintBatch(address,uint256[],uint256[])", bob, sellerTokenIds, sellerAmounts),
            abi.encode()
        );

        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature("getCurrentEpoch(bytes32)", questionId),
            abi.encode(1)
        );

        // Create orders
        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5500,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        // Sign orders
        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
    }

    function test_ExecuteSingleOrder() public {
        // Mock that market is open
        vm.mockCall(mockMarketContract, abi.encodeWithSignature("isMarketOpen(bytes32)", questionId), abi.encode(true));

        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature("getOutcomeCount(bytes32)", questionId),
            abi.encode(BINARY_OUTCOMES)
        );

        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature(
                "getConditionId(address,bytes32,uint256,uint256)", oracle, questionId, BINARY_OUTCOMES, 0
            ),
            abi.encode(conditionId)
        );

        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("getTokenId(bytes32,uint256)", conditionId, 1),
            abi.encode(tokenId1)
        );

        // Mock that matcher has inventory
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("balanceOf(address,uint256)", matcher, tokenId1),
            abi.encode(BET_AMOUNT)
        );

        // Mock burn from matcher
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("burn(address,uint256,uint256)", matcher, tokenId1, BET_AMOUNT),
            abi.encode()
        );

        // Mock mint to user 
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = tokenId1;
        amounts[0] = BET_AMOUNT;

        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("mintBatch(address,uint256[],uint256[])", alice, tokenIds, amounts),
            abi.encode()
        );

        // Mock vault transfer between users
        uint256 paymentAmount = (BET_AMOUNT * 6000) / 10000;
        vm.mockCall(
            mockVault,
            abi.encodeWithSignature("transferBetweenUsers(bytes32,address,address,uint256)", conditionId, alice, matcher, paymentAmount),
            abi.encode()
        );

        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature("getCurrentEpoch(bytes32)", questionId),
            abi.encode(1)
        );

        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 2,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, buyOrder);

        vm.prank(matcher);
        marketController.executeSingleOrder(buyOrder, signature, BET_AMOUNT, matcher);
    }

    // ============ Claims with Fee Tests ============

    function test_ClaimWinnings_WithFees() public {
        // Mock market state
        vm.mockCall(mockMarketContract, abi.encodeWithSignature("getCurrentEpoch(bytes32)", questionId), abi.encode(1));
        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature("getOutcomeCount(bytes32)", questionId),
            abi.encode(BINARY_OUTCOMES)
        );
        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature(
                "getConditionId(address,bytes32,uint256,uint256)", oracle, questionId, BINARY_OUTCOMES, 1
            ),
            abi.encode(conditionId)
        );

        // Mock resolver state
        vm.mockCall(
            mockMarketResolver, abi.encodeWithSignature("getResolutionStatus(bytes32)", conditionId), abi.encode(true)
        );

        // Mock token state
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("getTokenId(bytes32,uint256)", conditionId, 1),
            abi.encode(tokenId1)
        );
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("balanceOf(address,uint256)", alice, tokenId1),
            abi.encode(BET_AMOUNT)
        );

        // Mock proof verification
        bytes32[] memory proof = new bytes32[](0);
        vm.mockCall(
            mockMarketResolver,
            abi.encodeWithSignature("verifyProof(bytes32,uint256,bytes32[])", conditionId, 1, proof),
            abi.encode(true)
        );

        // Mock token burn
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("burn(address,uint256,uint256)", alice, tokenId1, BET_AMOUNT),
            abi.encode()
        );

        // Calculate expected fee and net payout
        uint256 expectedFee = (BET_AMOUNT * DEFAULT_FEE_RATE) / 10000;
        uint256 expectedNetPayout = BET_AMOUNT - expectedFee;

        // Mock vault unlocks for both user and treasury
        vm.mockCall(
            mockVault,
            abi.encodeWithSignature("unlockCollateral(bytes32,address,uint256)", conditionId, alice, expectedNetPayout),
            abi.encode()
        );
        vm.mockCall(
            mockVault,
            abi.encodeWithSignature("unlockCollateral(bytes32,address,uint256)", conditionId, treasury, expectedFee),
            abi.encode()
        );

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit FeeCollected(alice, questionId, expectedFee, expectedNetPayout);
        
        uint256 payout = marketController.claimWinnings(questionId, 1, 1, proof);
        assertEq(payout, expectedNetPayout);
    }

    function test_ClaimWinnings_CustomFeeRate() public {
        // Set custom fee rate for alice
        uint256 customRate = 200; // 2%
        vm.prank(owner);
        marketController.setUserFeeRate(alice, customRate);

        // Mock market state
        vm.mockCall(mockMarketContract, abi.encodeWithSignature("getCurrentEpoch(bytes32)", questionId), abi.encode(1));
        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature("getOutcomeCount(bytes32)", questionId),
            abi.encode(BINARY_OUTCOMES)
        );
        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature(
                "getConditionId(address,bytes32,uint256,uint256)", oracle, questionId, BINARY_OUTCOMES, 1
            ),
            abi.encode(conditionId)
        );

        // Mock resolver state
        vm.mockCall(
            mockMarketResolver, abi.encodeWithSignature("getResolutionStatus(bytes32)", conditionId), abi.encode(true)
        );

        // Mock token state
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("getTokenId(bytes32,uint256)", conditionId, 1),
            abi.encode(tokenId1)
        );
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("balanceOf(address,uint256)", alice, tokenId1),
            abi.encode(BET_AMOUNT)
        );

        // Mock proof verification
        bytes32[] memory proof = new bytes32[](0);
        vm.mockCall(
            mockMarketResolver,
            abi.encodeWithSignature("verifyProof(bytes32,uint256,bytes32[])", conditionId, 1, proof),
            abi.encode(true)
        );

        // Mock token burn
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("burn(address,uint256,uint256)", alice, tokenId1, BET_AMOUNT),
            abi.encode()
        );

        // Calculate expected fee with custom rate
        uint256 expectedFee = (BET_AMOUNT * customRate) / 10000;
        uint256 expectedNetPayout = BET_AMOUNT - expectedFee;

        // Mock vault unlocks
        vm.mockCall(
            mockVault,
            abi.encodeWithSignature("unlockCollateral(bytes32,address,uint256)", conditionId, alice, expectedNetPayout),
            abi.encode()
        );
        vm.mockCall(
            mockVault,
            abi.encodeWithSignature("unlockCollateral(bytes32,address,uint256)", conditionId, treasury, expectedFee),
            abi.encode()
        );

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit FeeCollected(alice, questionId, expectedFee, expectedNetPayout);
        
        uint256 payout = marketController.claimWinnings(questionId, 1, 1, proof);
        assertEq(payout, expectedNetPayout);
    }

    function test_ClaimWinnings_NoFeeWhenRateZero() public {
        // Set fee rate to 0
        vm.prank(owner);
        marketController.setFeeRate(0);

        // Mock market state
        vm.mockCall(mockMarketContract, abi.encodeWithSignature("getCurrentEpoch(bytes32)", questionId), abi.encode(1));
        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature("getOutcomeCount(bytes32)", questionId),
            abi.encode(BINARY_OUTCOMES)
        );
        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature(
                "getConditionId(address,bytes32,uint256,uint256)", oracle, questionId, BINARY_OUTCOMES, 1
            ),
            abi.encode(conditionId)
        );

        // Mock resolver state
        vm.mockCall(
            mockMarketResolver, abi.encodeWithSignature("getResolutionStatus(bytes32)", conditionId), abi.encode(true)
        );

        // Mock token state
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("getTokenId(bytes32,uint256)", conditionId, 1),
            abi.encode(tokenId1)
        );
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("balanceOf(address,uint256)", alice, tokenId1),
            abi.encode(BET_AMOUNT)
        );

        // Mock proof verification
        bytes32[] memory proof = new bytes32[](0);
        vm.mockCall(
            mockMarketResolver,
            abi.encodeWithSignature("verifyProof(bytes32,uint256,bytes32[])", conditionId, 1, proof),
            abi.encode(true)
        );

        // Mock token burn
        vm.mockCall(
            mockPositionTokens,
            abi.encodeWithSignature("burn(address,uint256,uint256)", alice, tokenId1, BET_AMOUNT),
            abi.encode()
        );

        // Mock vault unlock for full amount (no fee)
        vm.mockCall(
            mockVault,
            abi.encodeWithSignature("unlockCollateral(bytes32,address,uint256)", conditionId, alice, BET_AMOUNT),
            abi.encode()
        );

        vm.prank(alice);
        uint256 payout = marketController.claimWinnings(questionId, 1, 1, proof);
        assertEq(payout, BET_AMOUNT); // Full amount, no fees
    }

    // ============ Existing Order Tests ============

    function test_ExecuteOrderMatch_InvalidAmount() public {
        vm.mockCall(mockMarketContract, abi.encodeWithSignature("isMarketOpen(bytes32)", questionId), abi.encode(true));

        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5500,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        vm.expectRevert("Invalid fill amount");
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, 0);
    }

    function test_ExecuteOrderMatch_MarketClosed() public {
        // Mock that market is closed
        vm.mockCall(mockMarketContract, abi.encodeWithSignature("isMarketOpen(bytes32)", questionId), abi.encode(false));

        IMarketController.Order memory buyOrder = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        IMarketController.Order memory sellOrder = IMarketController.Order({
            user: bob,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 5500,
            nonce: 1,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: false
        });

        bytes memory buySignature = signOrder(alicePrivateKey, buyOrder);
        bytes memory sellSignature = signOrder(bobPrivateKey, sellOrder);

        vm.prank(matcher);
        vm.expectRevert("Market is closed for betting");
        marketController.executeOrderMatch(buyOrder, sellOrder, buySignature, sellSignature, BET_AMOUNT);
    }

    function test_CreateMarket() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.mockCall(
            mockMarketContract,
            abi.encodeWithSignature(
                "createMarket(bytes32,uint256,uint256)", questionId, BINARY_OUTCOMES, resolutionTime
            ),
            abi.encode()
        );

        vm.prank(owner);
        marketController.createMarket(questionId, BINARY_OUTCOMES, resolutionTime, 0);
    }

    function test_CancelOrder() public {
        IMarketController.Order memory order = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 3,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes memory signature = signOrder(alicePrivateKey, order);

        vm.prank(alice);
        marketController.cancelOrder(order, signature);

        // Check that order is marked as fully filled
        bytes32 orderHash = marketController.getOrderHash(order);
        assertEq(marketController.getOrderFillAmount(orderHash), BET_AMOUNT);
    }

    function test_GetOrderHash() public view {
        IMarketController.Order memory order = IMarketController.Order({
            user: alice,
            questionId: questionId,
            outcome: 1,
            amount: BET_AMOUNT,
            price: 6000,
            nonce: 4,
            expiration: block.timestamp + 1 hours,
            isBuyOrder: true
        });

        bytes32 hash = marketController.getOrderHash(order);
        assertTrue(hash != bytes32(0));
    }

    //// Helper functions for EIP-712 signing
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


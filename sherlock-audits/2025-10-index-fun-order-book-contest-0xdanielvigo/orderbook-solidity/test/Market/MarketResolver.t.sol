// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../../src/Market/MarketResolver.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

contract MarketResolverTest is Test {
    MarketResolver public marketResolver;

    address public owner = makeAddr("owner");
    address public oracle = makeAddr("oracle");
    address public unauthorized = makeAddr("unauthorized");

    bytes32 public questionId1 = keccak256("BTC_PRICE_BINARY");
    bytes32 public questionId2 = keccak256("ETH_PRICE_BINARY");
    bytes32 public conditionId1;
    bytes32 public conditionId2;

    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant MULTI_OUTCOMES = 4;
    uint256 public constant EPOCH_1 = 1;
    uint256 public constant EPOCH_2 = 2;

    bytes32 public merkleRoot1 = keccak256("merkle_root_1");
    bytes32 public merkleRoot2 = keccak256("merkle_root_2");

    event ConditionResolved(
        bytes32 indexed conditionId, 
        bytes32 indexed questionId, 
        uint256 indexed epoch, 
        bytes32 merkleRoot
    );

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation contract
        MarketResolver marketResolverImpl = new MarketResolver();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(MarketResolver.initialize.selector, owner, oracle);
        marketResolver = MarketResolver(address(new ERC1967Proxy(address(marketResolverImpl), initData)));

        vm.stopPrank();

        conditionId1 = marketResolver.getConditionId(oracle, questionId1, BINARY_OUTCOMES, EPOCH_1);
        conditionId2 = marketResolver.getConditionId(oracle, questionId2, MULTI_OUTCOMES, EPOCH_2);

        vm.label(address(marketResolver), "MarketResolver");
        vm.label(owner, "Owner");
        vm.label(oracle, "Oracle");
        vm.label(unauthorized, "Unauthorized");
    }

    // ============ Setup Tests ============

    function test_InitialSetup() public view {
        assertEq(marketResolver.owner(), owner);
        assertEq(marketResolver.oracle(), oracle);
    }

    function test_SetOracle() public {
        address newOracle = makeAddr("newOracle");

        vm.prank(owner);
        marketResolver.setOracle(newOracle);

        assertEq(marketResolver.oracle(), newOracle);
    }

    function test_SetOracle_OnlyOwner() public {
        address newOracle = makeAddr("newOracle");

        vm.prank(unauthorized);
        vm.expectRevert();
        marketResolver.setOracle(newOracle);
    }

    function test_SetOracle_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid oracle address");
        marketResolver.setOracle(address(0));
    }

    // ============ Condition ID Generation Tests ============

    function test_GetConditionId() public view {
        bytes32 expectedId = keccak256(abi.encodePacked(oracle, questionId1, BINARY_OUTCOMES, EPOCH_1));
        assertEq(conditionId1, expectedId);
    }

    function test_GetConditionId_DifferentEpochs() public view {
        bytes32 conditionIdEpoch1 = marketResolver.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 1);
        bytes32 conditionIdEpoch2 = marketResolver.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 2);

        assertTrue(conditionIdEpoch1 != conditionIdEpoch2);
    }

    function test_GetConditionId_DifferentOracles() public {
        address oracle2 = makeAddr("oracle2");
        bytes32 conditionId_oracle1 = marketResolver.getConditionId(oracle, questionId1, BINARY_OUTCOMES, EPOCH_1);
        bytes32 conditionId_oracle2 = marketResolver.getConditionId(oracle2, questionId1, BINARY_OUTCOMES, EPOCH_1);

        assertTrue(conditionId_oracle1 != conditionId_oracle2);
    }

    // ============ Market Resolution Tests ============

    function test_ResolveMarketEpoch() public {
        vm.prank(oracle);
        vm.expectEmit(true, true, true, true);
        emit ConditionResolved(conditionId1, questionId1, EPOCH_1, merkleRoot1);

        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, BINARY_OUTCOMES, merkleRoot1);

        assertEq(marketResolver.resolutionMerkleRoots(conditionId1), merkleRoot1);
        assertTrue(marketResolver.isResolved(conditionId1));
        assertTrue(marketResolver.getResolutionStatus(conditionId1));
        assertEq(marketResolver.getResolutionRoot(conditionId1), merkleRoot1);
    }

    function test_ResolveMarketEpoch_OnlyOracle() public {
        vm.prank(unauthorized);
        vm.expectRevert("Not authorized to resolve");
        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, BINARY_OUTCOMES, merkleRoot1);
    }

    function test_ResolveMarketEpoch_InvalidEpoch() public {
        vm.prank(oracle);
        vm.expectRevert("Invalid epoch");
        marketResolver.resolveMarketEpoch(questionId1, 0, BINARY_OUTCOMES, merkleRoot1);
    }

    function test_ResolveMarketEpoch_InvalidOutcomeCount() public {
        vm.prank(oracle);
        vm.expectRevert("Invalid outcome count");
        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, 0, merkleRoot1);
    }

    function test_ResolveMarketEpoch_InvalidMerkleRoot() public {
        vm.prank(oracle);
        vm.expectRevert("Invalid merkle root");
        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, BINARY_OUTCOMES, bytes32(0));
    }

    function test_ResolveMarketEpoch_AlreadyResolved() public {
        vm.startPrank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, BINARY_OUTCOMES, merkleRoot1);

        vm.expectRevert("Already resolved");
        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, BINARY_OUTCOMES, merkleRoot2);
        vm.stopPrank();
    }

    function test_ResolveMarketEpoch_MultipleMarkets() public {
        vm.startPrank(oracle);

        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, BINARY_OUTCOMES, merkleRoot1);
        marketResolver.resolveMarketEpoch(questionId2, EPOCH_2, MULTI_OUTCOMES, merkleRoot2);

        vm.stopPrank();

        assertTrue(marketResolver.getResolutionStatus(conditionId1));
        assertTrue(marketResolver.getResolutionStatus(conditionId2));
        assertEq(marketResolver.getResolutionRoot(conditionId1), merkleRoot1);
        assertEq(marketResolver.getResolutionRoot(conditionId2), merkleRoot2);
    }

    // ============ Proof Verification Tests ============

    function test_VerifyProof_ValidProof() public {
        // Create a simple merkle proof (single leaf case)
        uint256 outcome = 1;
        bytes32 leaf = keccak256(abi.encodePacked(outcome));
        bytes32 singleLeafRoot = leaf;

        // Resolve the market with the correct oracle
        bytes32 testQuestionId = keccak256("TEST_PROOF");
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(testQuestionId, EPOCH_1, BINARY_OUTCOMES, singleLeafRoot);

        bytes32 conditionIdForProof = marketResolver.getConditionId(oracle, testQuestionId, BINARY_OUTCOMES, EPOCH_1);
        bytes32[] memory proof = new bytes32[](0);

        bool isValid = marketResolver.verifyProof(conditionIdForProof, outcome, proof);
        assertTrue(isValid);
    }

    function test_VerifyProof_ConditionNotResolved() public {
        uint256 outcome = 1;
        bytes32[] memory proof = new bytes32[](0);

        vm.expectRevert("Condition not resolved");
        marketResolver.verifyProof(conditionId1, outcome, proof);
    }

    function test_VerifyProof_InvalidProof() public {
        // Resolve market first
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, BINARY_OUTCOMES, merkleRoot1);

        uint256 outcome = 1;
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256("invalid_proof");

        bool isValid = marketResolver.verifyProof(conditionId1, outcome, proof);
        assertFalse(isValid);
    }

    // ============ Batch Resolution Tests ============

    function test_BatchResolveMarkets() public {
        bytes32[] memory questionIds = new bytes32[](2);
        uint256[] memory epochs = new uint256[](2);
        uint256[] memory outcomesCounts = new uint256[](2);
        bytes32[] memory merkleRoots = new bytes32[](2);

        questionIds[0] = questionId1;
        questionIds[1] = questionId2;
        epochs[0] = EPOCH_1;
        epochs[1] = EPOCH_2;
        outcomesCounts[0] = BINARY_OUTCOMES;
        outcomesCounts[1] = MULTI_OUTCOMES;
        merkleRoots[0] = merkleRoot1;
        merkleRoots[1] = merkleRoot2;

        vm.prank(oracle);
        marketResolver.batchResolveMarkets(questionIds, epochs, outcomesCounts, merkleRoots);

        assertTrue(marketResolver.getResolutionStatus(conditionId1));
        assertTrue(marketResolver.getResolutionStatus(conditionId2));
        assertEq(marketResolver.getResolutionRoot(conditionId1), merkleRoot1);
        assertEq(marketResolver.getResolutionRoot(conditionId2), merkleRoot2);
    }

    function test_BatchResolveMarkets_OnlyOracle() public {
        bytes32[] memory questionIds = new bytes32[](1);
        uint256[] memory epochs = new uint256[](1);
        uint256[] memory outcomesCounts = new uint256[](1);
        bytes32[] memory merkleRoots = new bytes32[](1);

        questionIds[0] = questionId1;
        epochs[0] = EPOCH_1;
        outcomesCounts[0] = BINARY_OUTCOMES;
        merkleRoots[0] = merkleRoot1;

        vm.prank(unauthorized);
        vm.expectRevert("Not authorized to resolve");
        marketResolver.batchResolveMarkets(questionIds, epochs, outcomesCounts, merkleRoots);
    }

    function test_BatchResolveMarkets_ArrayLengthMismatch() public {
        bytes32[] memory questionIds = new bytes32[](2);
        uint256[] memory epochs = new uint256[](1); // Different length
        uint256[] memory outcomesCounts = new uint256[](2);
        bytes32[] memory merkleRoots = new bytes32[](2);

        questionIds[0] = questionId1;
        questionIds[1] = questionId2;
        epochs[0] = EPOCH_1;
        outcomesCounts[0] = BINARY_OUTCOMES;
        outcomesCounts[1] = MULTI_OUTCOMES;
        merkleRoots[0] = merkleRoot1;
        merkleRoots[1] = merkleRoot2;

        vm.prank(oracle);
        vm.expectRevert("Array length mismatch");
        marketResolver.batchResolveMarkets(questionIds, epochs, outcomesCounts, merkleRoots);
    }

    function test_BatchResolveMarkets_EmptyArrays() public {
        bytes32[] memory questionIds = new bytes32[](0);
        uint256[] memory epochs = new uint256[](0);
        uint256[] memory outcomesCounts = new uint256[](0);
        bytes32[] memory merkleRoots = new bytes32[](0);

        vm.prank(oracle);
        marketResolver.batchResolveMarkets(questionIds, epochs, outcomesCounts, merkleRoots);

        // Should not revert but also not resolve anything
        assertFalse(marketResolver.getResolutionStatus(conditionId1));
    }

    // ============ View Function Tests ============

    function test_GetResolutionRoot_UnresolvedCondition() public view {
        assertEq(marketResolver.getResolutionRoot(conditionId1), bytes32(0));
    }

    function test_GetResolutionStatus_UnresolvedCondition() public view {
        assertFalse(marketResolver.getResolutionStatus(conditionId1));
    }

    // ============ Integration Tests ============

    function test_CompleteResolutionFlow() public {
        // Resolve market
        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, BINARY_OUTCOMES, merkleRoot1);

        // Verify resolution
        assertTrue(marketResolver.getResolutionStatus(conditionId1));
        assertEq(marketResolver.getResolutionRoot(conditionId1), merkleRoot1);

        // Verify the condition is properly resolved
        assertTrue(marketResolver.isResolved(conditionId1));
        assertEq(marketResolver.resolutionMerkleRoots(conditionId1), merkleRoot1);
    }

    function test_MultipleEpochsForSameQuestion() public {
        bytes32 conditionIdEpoch1 = marketResolver.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 1);
        bytes32 conditionIdEpoch2 = marketResolver.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 2);

        vm.startPrank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, 1, BINARY_OUTCOMES, merkleRoot1);
        marketResolver.resolveMarketEpoch(questionId1, 2, BINARY_OUTCOMES, merkleRoot2);
        vm.stopPrank();

        assertTrue(marketResolver.getResolutionStatus(conditionIdEpoch1));
        assertTrue(marketResolver.getResolutionStatus(conditionIdEpoch2));
        assertEq(marketResolver.getResolutionRoot(conditionIdEpoch1), merkleRoot1);
        assertEq(marketResolver.getResolutionRoot(conditionIdEpoch2), merkleRoot2);
    }

    // ============ Edge Cases ============

    function test_LargeEpochNumber() public {
        uint256 largeEpoch = 1000000;
        bytes32 conditionIdLarge = marketResolver.getConditionId(oracle, questionId1, BINARY_OUTCOMES, largeEpoch);

        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, largeEpoch, BINARY_OUTCOMES, merkleRoot1);

        assertTrue(marketResolver.getResolutionStatus(conditionIdLarge));
    }

    function test_LargeOutcomeCount() public {
        uint256 largeOutcomeCount = 256;

        vm.prank(oracle);
        marketResolver.resolveMarketEpoch(questionId1, EPOCH_1, largeOutcomeCount, merkleRoot1);

        bytes32 conditionIdLarge = marketResolver.getConditionId(oracle, questionId1, largeOutcomeCount, EPOCH_1);
        assertTrue(marketResolver.getResolutionStatus(conditionIdLarge));
    }
}

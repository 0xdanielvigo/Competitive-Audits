// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MarketContract} from "../../src/Market/Market.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

contract MarketContractTest is Test {
    MarketContract public marketContract;

    address public owner = makeAddr("owner");
    address public marketController = makeAddr("marketController");
    address public oracle = makeAddr("oracle");
    address public unauthorized = makeAddr("unauthorized");

    bytes32 public questionId1 = keccak256("BTC_PRICE_BINARY");
    bytes32 public questionId2 = keccak256("ETH_PRICE_BINARY");
    bytes32 public invalidQuestionId = bytes32(0);

    uint256 public constant BINARY_OUTCOMES = 2;
    uint256 public constant MULTI_OUTCOMES = 4;

    event MarketCreated(bytes32 indexed questionId, uint256 outcomeCount, uint256 initialEpoch, uint256 resolutionTime);

    event EpochAdvanced(bytes32 indexed questionId, uint256 previousEpoch, uint256 newEpoch);

    event ResolutionTimeUpdated(bytes32 indexed questionId, uint256 oldResolutionTime, uint256 newResolutionTime);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation contract
        MarketContract marketImpl = new MarketContract();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(MarketContract.initialize.selector, owner);
        marketContract = MarketContract(address(new ERC1967Proxy(address(marketImpl), initData)));

        marketContract.setMarketController(marketController);

        vm.stopPrank();

        vm.label(address(marketContract), "MarketContract");
        vm.label(owner, "Owner");
        vm.label(marketController, "MarketController");
        vm.label(oracle, "Oracle");
        vm.label(unauthorized, "Unauthorized");
    }

    // ============ Setup Tests ============

    function test_InitialSetup() public view {
        assertEq(marketContract.owner(), owner);
        assertEq(marketContract.marketController(), marketController);
    }

    function test_SetMarketController() public {
        address newController = makeAddr("newController");

        vm.prank(owner);
        marketContract.setMarketController(newController);

        assertEq(marketContract.marketController(), newController);
    }

    function test_SetMarketController_OnlyOwner() public {
        address newController = makeAddr("newController");

        vm.prank(unauthorized);
        vm.expectRevert();
        marketContract.setMarketController(newController);
    }

    function test_SetMarketController_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid MarketController address");
        marketContract.setMarketController(address(0));
    }

    // ============ Market Creation Tests ============

    function test_CreateMarket_Binary_ManualResolution() public {
        uint256 resolutionTime = 0; // Manual resolution

        vm.prank(marketController);
        vm.expectEmit(true, false, false, true);
        emit MarketCreated(questionId1, BINARY_OUTCOMES, 1, resolutionTime);

        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        assertEq(marketContract.getOutcomeCount(questionId1), BINARY_OUTCOMES);
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        assertEq(marketContract.getResolutionTime(questionId1), resolutionTime);
        assertTrue(marketContract.getMarketExists(questionId1));
        assertTrue(marketContract.isMarketOpen(questionId1));
        assertTrue(marketContract.isMarketReadyForResolution(questionId1));
    }

    function test_CreateMarket_Binary_TimeResolution() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        vm.expectEmit(true, false, false, true);
        emit MarketCreated(questionId1, BINARY_OUTCOMES, 1, resolutionTime);

        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        assertEq(marketContract.getOutcomeCount(questionId1), BINARY_OUTCOMES);
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        assertEq(marketContract.getResolutionTime(questionId1), resolutionTime);
        assertTrue(marketContract.getMarketExists(questionId1));
        assertTrue(marketContract.isMarketOpen(questionId1));
        assertFalse(marketContract.isMarketReadyForResolution(questionId1));
    }

    function test_CreateMarket_MultiOutcome() public {
        uint256 resolutionTime = block.timestamp + 2 hours;

        vm.prank(marketController);
        vm.expectEmit(true, false, false, true);
        emit MarketCreated(questionId1, MULTI_OUTCOMES, 1, resolutionTime);

        marketContract.createMarket(questionId1, MULTI_OUTCOMES, resolutionTime, 0);

        assertEq(marketContract.getOutcomeCount(questionId1), MULTI_OUTCOMES);
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        assertEq(marketContract.getResolutionTime(questionId1), resolutionTime);
        assertTrue(marketContract.getMarketExists(questionId1));
    }

    function test_CreateMarket_OnlyMarketController() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(unauthorized);
        vm.expectRevert("Only MarketController can call this function");
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);
    }

    function test_CreateMarket_InvalidQuestionId() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        vm.expectRevert("Invalid question ID");
        marketContract.createMarket(invalidQuestionId, BINARY_OUTCOMES, resolutionTime, 0);
    }

    function test_CreateMarket_InvalidOutcomeCount() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        vm.expectRevert("Must have at least 2 outcomes");
        marketContract.createMarket(questionId1, 1, resolutionTime, 0);

        vm.prank(marketController);
        vm.expectRevert("Must have at least 2 outcomes");
        marketContract.createMarket(questionId1, 0, resolutionTime, 0);
    }

    function test_CreateMarket_InvalidResolutionTime() public {
        // Use a safe past time that won't underflow
        uint256 pastTime;
        if (block.timestamp > 1 hours) {
            pastTime = block.timestamp - 1 hours;
        } else {
            pastTime = 1; // Use timestamp 1 (clearly in the past)
        }

        vm.prank(marketController);
        vm.expectRevert("Resolution time must be in the future");
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, pastTime, 0);
    }

    function test_CreateMarket_AlreadyExists() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.startPrank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        vm.expectRevert("Market already exists");
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);
        vm.stopPrank();
    }

    function test_CreateMarket_MultipleMarkets() public {
        uint256 resolutionTime1 = block.timestamp + 1 hours;
        uint256 resolutionTime2 = block.timestamp + 2 hours;

        vm.startPrank(marketController);

        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime1, 0);
        marketContract.createMarket(questionId2, MULTI_OUTCOMES, resolutionTime2, 0);

        vm.stopPrank();

        assertEq(marketContract.getOutcomeCount(questionId1), BINARY_OUTCOMES);
        assertEq(marketContract.getOutcomeCount(questionId2), MULTI_OUTCOMES);
        assertEq(marketContract.getResolutionTime(questionId1), resolutionTime1);
        assertEq(marketContract.getResolutionTime(questionId2), resolutionTime2);
        assertTrue(marketContract.getMarketExists(questionId1));
        assertTrue(marketContract.getMarketExists(questionId2));
    }

    // ============ Time Resolution Tests ============

    function test_MarketOpenStatus() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        // Market should be open before resolution time
        assertTrue(marketContract.isMarketOpen(questionId1));
        assertFalse(marketContract.isMarketReadyForResolution(questionId1));

        // Fast forward past resolution time
        vm.warp(resolutionTime + 1);

        // Market should be closed after resolution time
        assertFalse(marketContract.isMarketOpen(questionId1));
        assertTrue(marketContract.isMarketReadyForResolution(questionId1));
    }

    function test_ManualResolutionMarket() public {
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Manual resolution markets are always open and ready for resolution
        assertTrue(marketContract.isMarketOpen(questionId1));
        assertTrue(marketContract.isMarketReadyForResolution(questionId1));

        // Even after time passes
        vm.warp(block.timestamp + 365 days);
        assertTrue(marketContract.isMarketOpen(questionId1));
        assertTrue(marketContract.isMarketReadyForResolution(questionId1));
    }

    function test_UpdateResolutionTime() public {
        uint256 initialTime = block.timestamp + 1 hours;
        uint256 newTime = block.timestamp + 2 hours;

        vm.startPrank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, initialTime, 0);

        vm.expectEmit(true, false, false, true);
        emit ResolutionTimeUpdated(questionId1, initialTime, newTime);

        marketContract.updateResolutionTime(questionId1, newTime);
        vm.stopPrank();

        assertEq(marketContract.getResolutionTime(questionId1), newTime);
    }

    function test_UpdateResolutionTime_OnlyMarketController() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        vm.prank(unauthorized);
        vm.expectRevert("Only MarketController can call this function");
        marketContract.updateResolutionTime(questionId1, block.timestamp + 2 hours);
    }

    function test_UpdateResolutionTime_MarketNotExists() public {
        vm.prank(marketController);
        vm.expectRevert("Market does not exist");
        marketContract.updateResolutionTime(questionId1, block.timestamp + 1 hours);
    }

    function test_UpdateResolutionTime_InvalidTime() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        // Use a safe past time that won't underflow
        uint256 pastTime;
        if (block.timestamp > 1 hours) {
            pastTime = block.timestamp - 1 hours;
        } else {
            pastTime = 1; // Use timestamp 1 (clearly in the past)
        }

        vm.prank(marketController);
        vm.expectRevert("Resolution time must be in the future");
        marketContract.updateResolutionTime(questionId1, pastTime);
    }

    function test_UpdateResolutionTime_ToManual() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.startPrank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        // Update to manual resolution (0)
        marketContract.updateResolutionTime(questionId1, 0);
        vm.stopPrank();

        assertEq(marketContract.getResolutionTime(questionId1), 0);
        assertTrue(marketContract.isMarketOpen(questionId1));
        assertTrue(marketContract.isMarketReadyForResolution(questionId1));
    }

    // ============ Epoch Management Tests ============

    function test_AdvanceEpoch() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.startPrank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        vm.expectEmit(true, false, false, true);
        emit EpochAdvanced(questionId1, 1, 2);

        marketContract.advanceEpoch(questionId1);
        vm.stopPrank();

        assertEq(marketContract.getCurrentEpoch(questionId1), 2);
    }

    function test_AdvanceEpoch_Multiple() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.startPrank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        for (uint256 i = 1; i <= 5; i++) {
            marketContract.advanceEpoch(questionId1);
            assertEq(marketContract.getCurrentEpoch(questionId1), i + 1);
        }
        vm.stopPrank();

        assertEq(marketContract.getCurrentEpoch(questionId1), 6);
    }

    function test_AdvanceEpoch_OnlyMarketController() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        vm.prank(unauthorized);
        vm.expectRevert("Only MarketController can call this function");
        marketContract.advanceEpoch(questionId1);
    }

    function test_AdvanceEpoch_MarketNotExists() public {
        vm.prank(marketController);
        vm.expectRevert("Market does not exist");
        marketContract.advanceEpoch(questionId1);
    }

    // ============ Condition ID Generation Tests ============

    function test_GetConditionId_CurrentEpoch() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        bytes32 conditionId = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        bytes32 expectedId = keccak256(abi.encodePacked(oracle, questionId1, BINARY_OUTCOMES, uint256(1)));

        assertEq(conditionId, expectedId);
    }

    function test_GetConditionId_SpecificEpoch() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        uint256 specificEpoch = 5;
        bytes32 conditionId = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, specificEpoch);
        bytes32 expectedId = keccak256(abi.encodePacked(oracle, questionId1, BINARY_OUTCOMES, specificEpoch));

        assertEq(conditionId, expectedId);
    }

    function test_GetConditionId_DifferentEpochs() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.startPrank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);
        marketContract.advanceEpoch(questionId1);
        vm.stopPrank();

        bytes32 conditionId1 = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 1);
        bytes32 conditionId2 = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 2);
        bytes32 conditionIdCurrent = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);

        assertTrue(conditionId1 != conditionId2);
        assertEq(conditionId2, conditionIdCurrent); // Current epoch is 2
    }

    function test_GetConditionId_DifferentOracles() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        address oracle2 = makeAddr("oracle2");
        bytes32 conditionId1 = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 1);
        bytes32 conditionId2 = marketContract.getConditionId(oracle2, questionId1, BINARY_OUTCOMES, 1);

        assertTrue(conditionId1 != conditionId2);
    }

    // ============ View Function Tests ============

    function test_GetOutcomeCount_NonExistentMarket() public view {
        assertEq(marketContract.getOutcomeCount(questionId1), 0);
    }

    function test_GetCurrentEpoch_NonExistentMarket() public view {
        assertEq(marketContract.getCurrentEpoch(questionId1), 0);
    }

    function test_GetMarketExists_NonExistentMarket() public view {
        assertFalse(marketContract.getMarketExists(questionId1));
    }

    function test_GetResolutionTime_NonExistentMarket() public view {
        assertEq(marketContract.getResolutionTime(questionId1), 0);
    }

    function test_GetCreationTime() public {
        uint256 beforeCreation = block.timestamp;
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        uint256 creationTime = marketContract.getCreationTime(questionId1);
        assertGe(creationTime, beforeCreation);
        assertLe(creationTime, block.timestamp);
    }

    // ============ Integration Tests ============

    function test_CompleteMarketLifecycle() public {
        uint256 resolutionTime = block.timestamp + 2 hours;

        // Create market
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        // Verify initial state
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        assertTrue(marketContract.getMarketExists(questionId1));
        assertTrue(marketContract.isMarketOpen(questionId1));
        assertFalse(marketContract.isMarketReadyForResolution(questionId1));

        // Advance through multiple epochs
        vm.startPrank(marketController);
        for (uint256 i = 1; i <= 3; i++) {
            marketContract.advanceEpoch(questionId1);
            assertEq(marketContract.getCurrentEpoch(questionId1), i + 1);
        }
        vm.stopPrank();

        // Fast forward past resolution time
        vm.warp(resolutionTime + 1);

        // Market should now be closed
        assertFalse(marketContract.isMarketOpen(questionId1));
        assertTrue(marketContract.isMarketReadyForResolution(questionId1));

        // Generate condition IDs for different epochs
        bytes32 epoch1Id = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 1);
        bytes32 epoch4Id = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 4);
        bytes32 currentId = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);

        assertTrue(epoch1Id != epoch4Id);
        assertEq(epoch4Id, currentId);
    }

    function test_MultipleMarketsIndependentTiming() public {
        uint256 resolutionTime1 = block.timestamp + 1 hours;
        uint256 resolutionTime2 = block.timestamp + 2 hours;

        vm.startPrank(marketController);

        // Create two markets with different resolution times
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime1, 0);
        marketContract.createMarket(questionId2, MULTI_OUTCOMES, resolutionTime2, 0);

        // Advance epochs independently
        marketContract.advanceEpoch(questionId1);
        marketContract.advanceEpoch(questionId1);
        marketContract.advanceEpoch(questionId2);

        vm.stopPrank();

        // Verify independent epoch tracking
        assertEq(marketContract.getCurrentEpoch(questionId1), 3);
        assertEq(marketContract.getCurrentEpoch(questionId2), 2);

        // Verify timing
        assertTrue(marketContract.isMarketOpen(questionId1));
        assertTrue(marketContract.isMarketOpen(questionId2));

        // Fast forward to first resolution time
        vm.warp(resolutionTime1 + 1);

        assertFalse(marketContract.isMarketOpen(questionId1));
        assertTrue(marketContract.isMarketOpen(questionId2)); // Still open

        // Fast forward to second resolution time
        vm.warp(resolutionTime2 + 1);

        assertFalse(marketContract.isMarketOpen(questionId1));
        assertFalse(marketContract.isMarketOpen(questionId2)); // Now closed
    }

    // ============ Outcome Bounds Validation Tests ============

    function test_CreateMarket_MaxOutcomesSupported() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        vm.expectEmit(true, false, false, true);
        emit MarketCreated(questionId1, 256, 1, resolutionTime);

        marketContract.createMarket(questionId1, 256, resolutionTime, 0);

        assertEq(marketContract.getOutcomeCount(questionId1), 256);
        assertTrue(marketContract.getMarketExists(questionId1));
    }

    function test_CreateMarket_ExceedsMaxOutcomes() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        vm.expectRevert("Maximum 256 outcomes supported");
        marketContract.createMarket(questionId1, 257, resolutionTime, 0);
    }

    function test_CreateMarket_LargeOutcomeCount() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        vm.expectRevert("Maximum 256 outcomes supported");
        marketContract.createMarket(questionId1, 1000, resolutionTime, 0);
    }

    function test_CreateMarket_OutcomeBoundsEdgeCases() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.startPrank(marketController);

        // Test edge cases around the boundary
        marketContract.createMarket(questionId1, 255, resolutionTime, 0);
        assertEq(marketContract.getOutcomeCount(questionId1), 255);

        marketContract.createMarket(questionId2, 256, resolutionTime, 0);
        assertEq(marketContract.getOutcomeCount(questionId2), 256);

        // Should fail for 257
        vm.expectRevert("Maximum 256 outcomes supported");
        bytes32 questionId3 = keccak256("QUESTION_3");
        marketContract.createMarket(questionId3, 257, resolutionTime, 0);

        vm.stopPrank();
    }

    function testFuzz_CreateMarket_ValidOutcomeCounts(uint256 outcomeCount) public {
        vm.assume(outcomeCount >= 2 && outcomeCount <= 256);

        uint256 resolutionTime = block.timestamp + 1 hours;
        bytes32 testQuestionId = keccak256(abi.encodePacked("FUZZ_QUESTION", outcomeCount));

        vm.prank(marketController);
        marketContract.createMarket(testQuestionId, outcomeCount, resolutionTime, 0);

        assertEq(marketContract.getOutcomeCount(testQuestionId), outcomeCount);
        assertTrue(marketContract.getMarketExists(testQuestionId));
    }

    function testFuzz_CreateMarket_InvalidOutcomeCounts(uint256 outcomeCount) public {
        vm.assume(outcomeCount > 256 || outcomeCount < 2);

        uint256 resolutionTime = block.timestamp + 1 hours;
        bytes32 testQuestionId = keccak256(abi.encodePacked("FUZZ_INVALID", outcomeCount));

        vm.prank(marketController);

        if (outcomeCount > 256) {
            vm.expectRevert("Maximum 256 outcomes supported");
        } else {
            vm.expectRevert("Must have at least 2 outcomes");
        }

        marketContract.createMarket(testQuestionId, outcomeCount, resolutionTime, 0);
    }

    // ============ Edge Cases ============

    function test_MaxEpochAdvancement() public {
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.startPrank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, 0);

        // Advance to a large epoch number
        uint256 targetEpoch = 1000;
        for (uint256 i = 1; i < targetEpoch; i++) {
            marketContract.advanceEpoch(questionId1);
        }

        vm.stopPrank();

        assertEq(marketContract.getCurrentEpoch(questionId1), targetEpoch);
    }

    function test_LargeOutcomeCount() public {
        uint256 largeOutcomeCount = 256;
        uint256 resolutionTime = block.timestamp + 1 hours;

        vm.prank(marketController);
        marketContract.createMarket(questionId1, largeOutcomeCount, resolutionTime, 0);

        assertEq(marketContract.getOutcomeCount(questionId1), largeOutcomeCount);
    }

    // ============ Epoch Duration Tests ============

    function test_CreateMarket_WithEpochDuration() public {
        uint256 resolutionTime = 0; // Manual resolution
        uint256 epochDuration = 86400; // Daily epochs

        vm.prank(marketController);
        vm.expectEmit(true, false, false, true);
        emit MarketCreated(questionId1, BINARY_OUTCOMES, 1, resolutionTime);

        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, epochDuration);

        assertEq(marketContract.getOutcomeCount(questionId1), BINARY_OUTCOMES);
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        assertEq(marketContract.getEpochDuration(questionId1), epochDuration);
        assertTrue(marketContract.getMarketExists(questionId1));
    }

    function test_CreateMarket_ManualEpochs() public {
        uint256 resolutionTime = 0;
        uint256 epochDuration = 0; // Manual epochs

        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, resolutionTime, epochDuration);

        assertEq(marketContract.getEpochDuration(questionId1), 0);
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
    }

    function test_GetEpochDuration_NonExistentMarket() public view {
        assertEq(marketContract.getEpochDuration(questionId1), 0);
    }

    function test_GetEpochStartTime_TimeBasedMarket() public {
        uint256 epochDuration = 86400;
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);

        uint256 creationTime = block.timestamp;
        
        // Epoch 1 starts at creation
        assertEq(marketContract.getEpochStartTime(questionId1, 1), creationTime);
        
        // Epoch 2 starts 1 day later
        assertEq(marketContract.getEpochStartTime(questionId1, 2), creationTime + epochDuration);
        
        // Epoch 5 starts 4 days later
        assertEq(marketContract.getEpochStartTime(questionId1, 5), creationTime + (4 * epochDuration));
    }

    function test_GetEpochStartTime_ManualMarket() public {
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Manual markets return 0 for epoch times
        assertEq(marketContract.getEpochStartTime(questionId1, 1), 0);
        assertEq(marketContract.getEpochStartTime(questionId1, 10), 0);
    }

    function test_GetEpochEndTime_TimeBasedMarket() public {
        uint256 epochDuration = 86400;
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);

        uint256 creationTime = block.timestamp;
        
        // Epoch 1 ends 1 day after creation
        assertEq(marketContract.getEpochEndTime(questionId1, 1), creationTime + epochDuration);
        
        // Epoch 2 ends 2 days after creation
        assertEq(marketContract.getEpochEndTime(questionId1, 2), creationTime + (2 * epochDuration));
    }

    function test_GetEpochEndTime_ManualMarket() public {
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        // Manual markets return 0 for epoch times
        assertEq(marketContract.getEpochEndTime(questionId1, 1), 0);
        assertEq(marketContract.getEpochEndTime(questionId1, 10), 0);
    }

    function test_GetCurrentEpoch_TimeBasedAdvancement() public {
        uint256 epochDuration = 3600; // 1 hour epochs
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);

        uint256 startTime = marketContract.getEpochStartTime(questionId1, 1);
        
        // Initially epoch 1
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        
        // After 1 hour - epoch 2
        vm.warp(startTime + epochDuration);
        assertEq(marketContract.getCurrentEpoch(questionId1), 2);
        
        // After 5 hours - epoch 6
        vm.warp(startTime + (5 * epochDuration));
        assertEq(marketContract.getCurrentEpoch(questionId1), 6);
        
        // After 24 hours - epoch 25
        vm.warp(startTime + (24 * epochDuration));
        assertEq(marketContract.getCurrentEpoch(questionId1), 25);
    }

    function test_GetCurrentEpoch_PartialEpoch() public {
        uint256 epochDuration = 86400; // Daily
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);

        uint256 startTime = marketContract.getEpochStartTime(questionId1, 1);
        
        // 12 hours - still epoch 1
        vm.warp(startTime + (epochDuration / 2));
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        
        // 23 hours 59 minutes - still epoch 1
        vm.warp(startTime + epochDuration - 1);
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        
        // Exactly 24 hours - epoch 2
        vm.warp(startTime + epochDuration);
        assertEq(marketContract.getCurrentEpoch(questionId1), 2);
    }

    function test_AdvanceEpoch_FailsForTimeBasedMarket() public {
        uint256 epochDuration = 86400;
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);

        vm.prank(marketController);
        vm.expectRevert("Cannot manually advance time-based epochs");
        marketContract.advanceEpoch(questionId1);
    }

    function test_AdvanceEpoch_WorksForManualMarket() public {
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, 0);

        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        
        vm.prank(marketController);
        marketContract.advanceEpoch(questionId1);
        
        assertEq(marketContract.getCurrentEpoch(questionId1), 2);
    }

    function test_TimeBasedMarketAlwaysOpen() public {
        uint256 epochDuration = 86400;
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);

        // Should be open initially
        assertTrue(marketContract.isMarketOpen(questionId1));
        
        // Still open after many epochs
        vm.warp(block.timestamp + (100 * epochDuration));
        assertTrue(marketContract.isMarketOpen(questionId1));
    }

    function test_GetConditionId_UsesCurrentEpochForTimeBasedMarket() public {
        uint256 epochDuration = 86400;
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);

        uint256 startTime = block.timestamp;
        
        // In epoch 1, passing 0 should use epoch 1
        bytes32 conditionId1a = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        bytes32 conditionId1b = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 1);
        assertEq(conditionId1a, conditionId1b);
        
        // Move to epoch 2
        vm.warp(startTime + epochDuration);
        
        // Now passing 0 should use epoch 2
        bytes32 conditionId2a = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 0);
        bytes32 conditionId2b = marketContract.getConditionId(oracle, questionId1, BINARY_OUTCOMES, 2);
        assertEq(conditionId2a, conditionId2b);
        
        // Should be different from epoch 1
        assertTrue(conditionId1a != conditionId2a);
    }

    function test_MixedMarkets_IndependentBehavior() public {
        // Create time-based market
        vm.startPrank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, 86400);
        
        // Create manual market
        marketContract.createMarket(questionId2, BINARY_OUTCOMES, 0, 0);
        vm.stopPrank();
        
        uint256 startTime = block.timestamp;
        
        // Both start at epoch 1
        assertEq(marketContract.getCurrentEpoch(questionId1), 1);
        assertEq(marketContract.getCurrentEpoch(questionId2), 1);
        
        // Fast forward time
        vm.warp(startTime + (5 * 86400));
        
        // Time-based advances automatically
        assertEq(marketContract.getCurrentEpoch(questionId1), 6);
        
        // Manual stays at 1
        assertEq(marketContract.getCurrentEpoch(questionId2), 1);
        
        // Can manually advance manual market
        vm.prank(marketController);
        marketContract.advanceEpoch(questionId2);
        assertEq(marketContract.getCurrentEpoch(questionId2), 2);
        
        // Cannot manually advance time-based market
        vm.prank(marketController);
        vm.expectRevert("Cannot manually advance time-based epochs");
        marketContract.advanceEpoch(questionId1);
    }

    // ============ Fuzz Tests ============

    function testFuzz_EpochCalculation(uint256 epochDuration, uint256 timeElapsed) public {
        // Bound to reasonable values
        epochDuration = bound(epochDuration, 1, 365 days);
        timeElapsed = bound(timeElapsed, 0, 1000 * epochDuration);
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);
        
        uint256 startTime = block.timestamp;
        vm.warp(startTime + timeElapsed);
        
        uint256 expectedEpoch = 1 + (timeElapsed / epochDuration);
        assertEq(marketContract.getCurrentEpoch(questionId1), expectedEpoch);
    }

    function testFuzz_EpochTimes(uint256 epochDuration, uint256 epochNumber) public {
        epochDuration = bound(epochDuration, 1, 365 days);
        epochNumber = bound(epochNumber, 1, 1000);
        
        vm.prank(marketController);
        marketContract.createMarket(questionId1, BINARY_OUTCOMES, 0, epochDuration);
        
        uint256 startTime = block.timestamp;
        uint256 expectedStartTime = startTime + (epochDuration * (epochNumber - 1));
        uint256 expectedEndTime = startTime + (epochDuration * epochNumber);
        
        assertEq(marketContract.getEpochStartTime(questionId1, epochNumber), expectedStartTime);
        assertEq(marketContract.getEpochEndTime(questionId1, epochNumber), expectedEndTime);
    }
}

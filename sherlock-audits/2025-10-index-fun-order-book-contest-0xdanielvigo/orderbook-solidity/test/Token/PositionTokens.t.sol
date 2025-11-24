// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../../src/Token/PositionTokens.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

contract PositionTokensTest is Test {
    PositionTokens public positionTokens;

    address public owner = makeAddr("owner");
    address public marketController = makeAddr("marketController");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public unauthorized = makeAddr("unauthorized");

    bytes32 public conditionId = keccak256("TEST_CONDITION");
    uint256 public outcome1 = 1;
    uint256 public outcome2 = 2;
    uint256 public tokenId1;
    uint256 public tokenId2;
    uint256 public mintAmount = 1000e18;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation contract
        PositionTokens positionTokensImpl = new PositionTokens();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(PositionTokens.initialize.selector, owner);
        positionTokens = PositionTokens(address(new ERC1967Proxy(address(positionTokensImpl), initData)));

        positionTokens.setMarketController(marketController);

        vm.stopPrank();

        tokenId1 = positionTokens.getTokenId(conditionId, outcome1);
        tokenId2 = positionTokens.getTokenId(conditionId, outcome2);

        vm.label(address(positionTokens), "PositionTokens");
        vm.label(owner, "Owner");
        vm.label(marketController, "MarketController");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(unauthorized, "Unauthorized");
    }

    // ============ Setup Tests ============

    function test_InitialSetup() public view {
        assertEq(positionTokens.owner(), owner);
        assertEq(positionTokens.marketController(), marketController);
    }

    function test_SetMarketController() public {
        address newController = makeAddr("newController");

        vm.prank(owner);
        positionTokens.setMarketController(newController);

        assertEq(positionTokens.marketController(), newController);
    }

    function test_SetMarketController_OnlyOwner() public {
        address newController = makeAddr("newController");

        vm.prank(unauthorized);
        vm.expectRevert();
        positionTokens.setMarketController(newController);
    }

    function test_SetMarketController_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid MarketController address");
        positionTokens.setMarketController(address(0));
    }

    // ============ Token ID Generation Tests ============

    function test_GetTokenId() public view {
        uint256 calculatedId1 = uint256(keccak256(abi.encodePacked(conditionId, outcome1)));
        uint256 calculatedId2 = uint256(keccak256(abi.encodePacked(conditionId, outcome2)));

        assertEq(tokenId1, calculatedId1);
        assertEq(tokenId2, calculatedId2);
        assertTrue(tokenId1 != tokenId2);
    }

    function test_GetTokenId_DifferentConditions() public view {
        bytes32 conditionId2 = keccak256("DIFFERENT_CONDITION");

        uint256 token1_condition1 = positionTokens.getTokenId(conditionId, outcome1);
        uint256 token1_condition2 = positionTokens.getTokenId(conditionId2, outcome1);

        assertTrue(token1_condition1 != token1_condition2);
    }

    function test_GetTokenId_DifferentOutcomes() public view {
        uint256 token_outcome1 = positionTokens.getTokenId(conditionId, outcome1);
        uint256 token_outcome2 = positionTokens.getTokenId(conditionId, outcome2);

        assertTrue(token_outcome1 != token_outcome2);
    }

    // ============ Minting Tests ============

    function test_MintBatch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = tokenId1;
        ids[1] = tokenId2;
        amounts[0] = mintAmount;
        amounts[1] = mintAmount;

        vm.prank(marketController);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(marketController, address(0), alice, ids, amounts);

        positionTokens.mintBatch(alice, ids, amounts);

        assertEq(positionTokens.balanceOf(alice, tokenId1), mintAmount);
        assertEq(positionTokens.balanceOf(alice, tokenId2), mintAmount);
    }

    function test_MintBatch_OnlyMarketController() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        ids[0] = tokenId1;
        amounts[0] = mintAmount;

        vm.prank(unauthorized);
        vm.expectRevert("Only MarketController can call this function");
        positionTokens.mintBatch(alice, ids, amounts);
    }

    function test_MintBatch_EmptyArrays() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(marketController);
        positionTokens.mintBatch(alice, ids, amounts);

        // Should not revert but also not mint anything
        assertEq(positionTokens.balanceOf(alice, tokenId1), 0);
    }

    // ============ Burning Tests ============

    function test_Burn() public {
        // First mint tokens
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = tokenId1;
        amounts[0] = mintAmount;

        vm.prank(marketController);
        positionTokens.mintBatch(alice, ids, amounts);

        // Then burn them
        vm.prank(marketController);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(marketController, alice, address(0), tokenId1, mintAmount);

        positionTokens.burn(alice, tokenId1, mintAmount);

        assertEq(positionTokens.balanceOf(alice, tokenId1), 0);
    }

    function test_Burn_OnlyMarketController() public {
        vm.prank(unauthorized);
        vm.expectRevert("Only MarketController can call this function");
        positionTokens.burn(alice, tokenId1, mintAmount);
    }

    function test_Burn_InsufficientBalance() public {
        vm.prank(marketController);
        vm.expectRevert();
        positionTokens.burn(alice, tokenId1, mintAmount);
    }

    function test_Burn_PartialAmount() public {
        // Mint tokens
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = tokenId1;
        amounts[0] = mintAmount;

        vm.prank(marketController);
        positionTokens.mintBatch(alice, ids, amounts);

        // Burn partial amount
        uint256 burnAmount = mintAmount / 2;
        vm.prank(marketController);
        positionTokens.burn(alice, tokenId1, burnAmount);

        assertEq(positionTokens.balanceOf(alice, tokenId1), mintAmount - burnAmount);
    }

    // ============ Integration Tests ============

    function test_MintAndBurn_MultipleUsers() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = tokenId1;
        ids[1] = tokenId2;
        amounts[0] = mintAmount;
        amounts[1] = mintAmount;

        // Mint to Alice
        vm.prank(marketController);
        positionTokens.mintBatch(alice, ids, amounts);

        // Mint to Bob
        vm.prank(marketController);
        positionTokens.mintBatch(bob, ids, amounts);

        // Verify balances
        assertEq(positionTokens.balanceOf(alice, tokenId1), mintAmount);
        assertEq(positionTokens.balanceOf(bob, tokenId1), mintAmount);

        // Burn Alice's tokens
        vm.prank(marketController);
        positionTokens.burn(alice, tokenId1, mintAmount);

        // Verify Alice's balance is 0, Bob's unchanged
        assertEq(positionTokens.balanceOf(alice, tokenId1), 0);
        assertEq(positionTokens.balanceOf(bob, tokenId1), mintAmount);
    }

    function test_TokenTransfer() public {
        // Mint tokens to Alice
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = tokenId1;
        amounts[0] = mintAmount;

        vm.prank(marketController);
        positionTokens.mintBatch(alice, ids, amounts);

        // Alice transfers to Bob
        vm.prank(alice);
        positionTokens.safeTransferFrom(alice, bob, tokenId1, mintAmount / 2, "");

        assertEq(positionTokens.balanceOf(alice, tokenId1), mintAmount / 2);
        assertEq(positionTokens.balanceOf(bob, tokenId1), mintAmount / 2);
    }

    // ============ Edge Cases ============

    function test_ZeroAmountMint() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = tokenId1;
        amounts[0] = 0;

        vm.prank(marketController);
        positionTokens.mintBatch(alice, ids, amounts);

        assertEq(positionTokens.balanceOf(alice, tokenId1), 0);
    }

    function test_ZeroAmountBurn() public {
        vm.prank(marketController);
        positionTokens.burn(alice, tokenId1, 0);

        // Should not revert
        assertEq(positionTokens.balanceOf(alice, tokenId1), 0);
    }

    function test_LargeTokenAmounts() public {
        uint256 largeAmount = type(uint256).max / 2;
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = tokenId1;
        amounts[0] = largeAmount;

        vm.prank(marketController);
        positionTokens.mintBatch(alice, ids, amounts);

        assertEq(positionTokens.balanceOf(alice, tokenId1), largeAmount);
    }

    // ============ Access Control Edge Cases ============

    function test_MarketControllerNotSet() public {
        vm.startPrank(owner);

        // Deploy new implementation
        PositionTokens newTokensImpl = new PositionTokens();

        // Deploy proxy with initialization but no market controller set
        bytes memory initData = abi.encodeWithSelector(PositionTokens.initialize.selector, owner);
        PositionTokens newTokens = PositionTokens(address(new ERC1967Proxy(address(newTokensImpl), initData)));

        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = tokenId1;
        amounts[0] = mintAmount;

        vm.prank(unauthorized);
        vm.expectRevert("Only MarketController can call this function");
        newTokens.mintBatch(alice, ids, amounts);
    }

    // ============ Interface Support Tests ============

    function test_SupportsInterface() public view {
        // ERC1155 interface
        assertTrue(positionTokens.supportsInterface(0xd9b67a26));
        // ERC165 interface
        assertTrue(positionTokens.supportsInterface(0x01ffc9a7));
    }

    // ============ Batch Operation Tests ============

    function test_MintBatch_LargeArray() public {
        uint256 arraySize = 100;
        uint256[] memory ids = new uint256[](arraySize);
        uint256[] memory amounts = new uint256[](arraySize);

        for (uint256 i = 0; i < arraySize; i++) {
            ids[i] = positionTokens.getTokenId(conditionId, i + 1);
            amounts[i] = mintAmount;
        }

        vm.prank(marketController);
        positionTokens.mintBatch(alice, ids, amounts);

        // Verify a few random tokens
        assertEq(positionTokens.balanceOf(alice, ids[0]), mintAmount);
        assertEq(positionTokens.balanceOf(alice, ids[50]), mintAmount);
        assertEq(positionTokens.balanceOf(alice, ids[99]), mintAmount);
    }
}

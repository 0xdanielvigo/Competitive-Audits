// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../../src/Vault/Vault.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {StdChains} from "forge-std/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";

contract VaultTest is Test {
    Vault public vault;
    ERC20Mock public collateralToken;

    address public owner = address(0x1);
    address public marketController = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public unauthorized = address(0x5);

    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 public constant DEPOSIT_AMOUNT = 1000e18;

    bytes32 public constant CONDITION_ID_1 = keccak256("condition1");
    bytes32 public constant CONDITION_ID_2 = keccak256("condition2");

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CollateralLocked(bytes32 indexed conditionId, address indexed user, uint256 amount);
    event CollateralUnlocked(bytes32 indexed conditionId, address indexed user, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);

        collateralToken = new ERC20Mock();

        // Deploy implementation contract
        Vault vaultImpl = new Vault();

        // Deploy proxy with initialization
        bytes memory initData =
            abi.encodeWithSelector(Vault.initialize.selector, owner, address(collateralToken), marketController);
        vault = Vault(address(new ERC1967Proxy(address(vaultImpl), initData)));

        collateralToken.mint(user1, INITIAL_SUPPLY);
        collateralToken.mint(user2, INITIAL_SUPPLY);

        vm.stopPrank();
    }

    function testConstructor() public view {
        assertEq(address(vault.collateralToken()), address(collateralToken));
        assertEq(vault.marketController(), marketController);
        assertEq(vault.owner(), owner);
        assertFalse(vault.paused());
    }

    function testConstructorInvalidCollateralToken() public {
        vm.startPrank(owner);

        Vault vaultImpl = new Vault();

        bytes memory initData = abi.encodeWithSelector(Vault.initialize.selector, owner, address(0), marketController);

        vm.expectRevert("Invalid collateral token");
        new ERC1967Proxy(address(vaultImpl), initData);

        vm.stopPrank();
    }

    function testConstructorInvalidMarketController() public {
        vm.startPrank(owner);

        Vault vaultImpl = new Vault();

        bytes memory initData =
            abi.encodeWithSelector(Vault.initialize.selector, owner, address(collateralToken), address(0));

        vm.expectRevert("Invalid market controller");
        new ERC1967Proxy(address(vaultImpl), initData);

        vm.stopPrank();
    }

    function testDepositCollateral() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit CollateralDeposited(user1, DEPOSIT_AMOUNT);

        vault.depositCollateral(DEPOSIT_AMOUNT);

        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT);
        assertEq(collateralToken.balanceOf(address(vault)), DEPOSIT_AMOUNT);
        assertEq(collateralToken.balanceOf(user1), INITIAL_SUPPLY - DEPOSIT_AMOUNT);

        vm.stopPrank();
    }

    function testDepositCollateralZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid amount");
        vault.depositCollateral(0);
        vm.stopPrank();
    }

    function testDepositCollateralInsufficientApproval() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT - 1);

        vm.expectRevert();
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testDepositCollateralWhenPaused() public {
        vm.prank(owner);
        vault.setPaused(true);

        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);

        vm.expectRevert("Contract paused");
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testWithdrawCollateral() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);

        uint256 withdrawAmount = 500e18;
        uint256 expectedBalance = INITIAL_SUPPLY - DEPOSIT_AMOUNT + withdrawAmount;

        vm.expectEmit(true, false, false, true);
        emit CollateralWithdrawn(user1, withdrawAmount);

        vault.withdrawCollateral(withdrawAmount);

        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT - withdrawAmount);
        assertEq(collateralToken.balanceOf(user1), expectedBalance);
        assertEq(collateralToken.balanceOf(address(vault)), DEPOSIT_AMOUNT - withdrawAmount);

        vm.stopPrank();
    }

    function testWithdrawCollateralZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid amount");
        vault.withdrawCollateral(0);
        vm.stopPrank();
    }

    function testWithdrawCollateralInsufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("Insufficient balance");
        vault.withdrawCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testWithdrawCollateralWhenPaused() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.prank(owner);
        vault.setPaused(true);

        vm.startPrank(user1);
        vm.expectRevert("Contract paused");
        vault.withdrawCollateral(100e18);
        vm.stopPrank();
    }

    function testLockCollateral() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 lockAmount = 300e18;

        vm.startPrank(marketController);

        vm.expectEmit(true, true, false, true);
        emit CollateralLocked(CONDITION_ID_1, user1, lockAmount);

        vault.lockCollateral(CONDITION_ID_1, user1, lockAmount);

        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT - lockAmount);
        assertEq(vault.getTotalLocked(CONDITION_ID_1), lockAmount);

        vm.stopPrank();
    }

    function testLockCollateralUnauthorized() public {
        vm.startPrank(unauthorized);
        vm.expectRevert("Unauthorized caller");
        vault.lockCollateral(CONDITION_ID_1, user1, 100e18);
        vm.stopPrank();
    }

    function testLockCollateralInsufficientBalance() public {
        vm.startPrank(marketController);
        vm.expectRevert("Insufficient balance");
        vault.lockCollateral(CONDITION_ID_1, user1, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testUnlockCollateral() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 lockAmount = 500e18;
        uint256 unlockAmount = 200e18;

        vm.startPrank(marketController);
        vault.lockCollateral(CONDITION_ID_1, user1, lockAmount);

        vm.expectEmit(true, true, false, true);
        emit CollateralUnlocked(CONDITION_ID_1, user2, unlockAmount);

        vault.unlockCollateral(CONDITION_ID_1, user2, unlockAmount);

        assertEq(vault.getTotalLocked(CONDITION_ID_1), lockAmount - unlockAmount);
        assertEq(vault.getAvailableBalance(user2), unlockAmount);
        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT - lockAmount);

        vm.stopPrank();
    }

    function testUnlockCollateralUnauthorized() public {
        vm.startPrank(unauthorized);
        vm.expectRevert("Unauthorized caller");
        vault.unlockCollateral(CONDITION_ID_1, user1, 100e18);
        vm.stopPrank();
    }

    function testUnlockCollateralInvalidAmount() public {
        vm.startPrank(marketController);
        vm.expectRevert("Invalid unlock amount");
        vault.unlockCollateral(CONDITION_ID_1, user1, 100e18);
        vm.stopPrank();
    }

    function testMultipleUsersMultipleConditions() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 lockAmount1 = 300e18;
        uint256 lockAmount2 = 400e18;

        vm.startPrank(marketController);

        vault.lockCollateral(CONDITION_ID_1, user1, lockAmount1);
        vault.lockCollateral(CONDITION_ID_2, user2, lockAmount2);

        assertEq(vault.getTotalLocked(CONDITION_ID_1), lockAmount1);
        assertEq(vault.getTotalLocked(CONDITION_ID_2), lockAmount2);
        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT - lockAmount1);
        assertEq(vault.getAvailableBalance(user2), DEPOSIT_AMOUNT - lockAmount2);

        vm.stopPrank();
    }

    function testBatchLockCollateral() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        bytes32[] memory conditionIds = new bytes32[](2);
        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        conditionIds[0] = CONDITION_ID_1;
        conditionIds[1] = CONDITION_ID_2;
        users[0] = user1;
        users[1] = user2;
        amounts[0] = 200e18;
        amounts[1] = 300e18;

        vm.startPrank(marketController);
        vault.batchLockCollateral(conditionIds, users, amounts);

        assertEq(vault.getTotalLocked(CONDITION_ID_1), 200e18);
        assertEq(vault.getTotalLocked(CONDITION_ID_2), 300e18);
        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT - 200e18);
        assertEq(vault.getAvailableBalance(user2), DEPOSIT_AMOUNT - 300e18);

        vm.stopPrank();
    }

    function testBatchUnlockCollateral() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(marketController);

        // Lock first
        vault.lockCollateral(CONDITION_ID_1, user1, 200e18);
        vault.lockCollateral(CONDITION_ID_2, user2, 300e18);

        // Prepare batch unlock - market payouts
        bytes32[] memory conditionIds = new bytes32[](2);
        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        conditionIds[0] = CONDITION_ID_1;
        conditionIds[1] = CONDITION_ID_2;
        users[0] = user1;
        users[1] = user2;
        amounts[0] = 100e18;
        amounts[1] = 150e18;

        vault.batchUnlockCollateral(conditionIds, users, amounts);

        // Total locked should be reduced
        assertEq(vault.getTotalLocked(CONDITION_ID_1), 100e18);
        assertEq(vault.getTotalLocked(CONDITION_ID_2), 150e18);

        // Users should receive their payouts
        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT - 200e18 + 100e18);
        assertEq(vault.getAvailableBalance(user2), DEPOSIT_AMOUNT - 300e18 + 150e18);

        vm.stopPrank();
    }

    function testBatchUnlockCollateralArrayMismatch() public {
        bytes32[] memory conditionIds = new bytes32[](2);
        address[] memory users = new address[](1); // Different length
        uint256[] memory amounts = new uint256[](2);

        vm.startPrank(marketController);
        vm.expectRevert("Array length mismatch");
        vault.batchUnlockCollateral(conditionIds, users, amounts);
        vm.stopPrank();
    }

    function testBatchLockCollateralArrayMismatch() public {
        bytes32[] memory conditionIds = new bytes32[](2);
        address[] memory users = new address[](1); // Different length
        uint256[] memory amounts = new uint256[](2);

        vm.startPrank(marketController);
        vm.expectRevert("Array length mismatch");
        vault.batchLockCollateral(conditionIds, users, amounts);
        vm.stopPrank();
    }

    function testBatchUnlockExceedsTotalLocked() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(marketController);

        // Lock amount
        vault.lockCollateral(CONDITION_ID_1, user1, 200e18);

        // Try to batch unlock more than total locked
        bytes32[] memory conditionIds = new bytes32[](1);
        address[] memory users = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        conditionIds[0] = CONDITION_ID_1;
        users[0] = user1;
        amounts[0] = 300e18; // More than total locked

        vm.expectRevert("Invalid unlock amount");
        vault.batchUnlockCollateral(conditionIds, users, amounts);

        vm.stopPrank();
    }

    function testMarketPayoutScenario() public {
        // Simulate a prediction market scenario where user1 and user2 both lock collateral
        // but user1 wins most of the pool
        
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 lockAmount1 = 200e18;
        uint256 lockAmount2 = 300e18;

        vm.startPrank(marketController);

        // Both users lock collateral for the same condition (market)
        vault.lockCollateral(CONDITION_ID_1, user1, lockAmount1);
        vault.lockCollateral(CONDITION_ID_1, user2, lockAmount2);

        assertEq(vault.getTotalLocked(CONDITION_ID_1), lockAmount1 + lockAmount2);

        // Market resolves: user1 wins and gets most of the pool (450e18), user2 gets small amount (50e18)
        vault.unlockCollateral(CONDITION_ID_1, user1, 450e18);
        vault.unlockCollateral(CONDITION_ID_1, user2, 50e18);

        // Verify total locked is now zero
        assertEq(vault.getTotalLocked(CONDITION_ID_1), 0);
        
        // Verify payouts
        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT - lockAmount1 + 450e18);
        assertEq(vault.getAvailableBalance(user2), DEPOSIT_AMOUNT - lockAmount2 + 50e18);

        vm.stopPrank();
    }

    function testSetMarketController() public {
        address newController = address(0x6);

        vm.startPrank(owner);
        vault.setMarketController(newController);
        assertEq(vault.marketController(), newController);
        vm.stopPrank();
    }

    function testSetMarketControllerInvalidAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid address");
        vault.setMarketController(address(0));
        vm.stopPrank();
    }

    function testSetMarketControllerUnauthorized() public {
        vm.startPrank(unauthorized);
        vm.expectRevert();
        vault.setMarketController(address(0x6));
        vm.stopPrank();
    }

    function testSetPaused() public {
        vm.startPrank(owner);

        vault.setPaused(true);
        assertTrue(vault.paused());

        vault.setPaused(false);
        assertFalse(vault.paused());

        vm.stopPrank();
    }

    function testSetPausedUnauthorized() public {
        vm.startPrank(unauthorized);
        vm.expectRevert();
        vault.setPaused(true);
        vm.stopPrank();
    }

    function testCompleteFlow() public {
        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 lockAmount = 600e18;
        uint256 unlockAmount = 400e18;

        vm.startPrank(marketController);
        vault.lockCollateral(CONDITION_ID_1, user1, lockAmount);
        vault.unlockCollateral(CONDITION_ID_1, user1, unlockAmount);
        vm.stopPrank();

        uint256 expectedBalance = DEPOSIT_AMOUNT - lockAmount + unlockAmount;
        assertEq(vault.getAvailableBalance(user1), expectedBalance);

        vm.startPrank(user1);
        vault.withdrawCollateral(expectedBalance);
        assertEq(vault.getAvailableBalance(user1), 0);
        vm.stopPrank();
    }

    function testFuzzDepositWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_SUPPLY);

        vm.startPrank(user1);
        collateralToken.approve(address(vault), amount);
        vault.depositCollateral(amount);

        assertEq(vault.getAvailableBalance(user1), amount);

        vault.withdrawCollateral(amount);
        assertEq(vault.getAvailableBalance(user1), 0);

        vm.stopPrank();
    }

    function testFuzzLockUnlock(uint256 lockAmount, uint256 unlockAmount) public {
        vm.assume(lockAmount > 0 && lockAmount <= DEPOSIT_AMOUNT);
        vm.assume(unlockAmount > 0 && unlockAmount <= lockAmount);

        vm.startPrank(user1);
        collateralToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositCollateral(DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(marketController);
        vault.lockCollateral(CONDITION_ID_1, user1, lockAmount);
        vault.unlockCollateral(CONDITION_ID_1, user1, unlockAmount);

        assertEq(vault.getTotalLocked(CONDITION_ID_1), lockAmount - unlockAmount);
        assertEq(vault.getAvailableBalance(user1), DEPOSIT_AMOUNT - lockAmount + unlockAmount);

        vm.stopPrank();
    }
}

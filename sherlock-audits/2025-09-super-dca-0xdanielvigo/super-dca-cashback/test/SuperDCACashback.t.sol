// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {console2} from "forge-std/Test.sol";
import {SuperDCACashback} from "src/SuperDCACashback.sol";
import {ISuperDCATrade} from "src/interfaces/ISuperDCATrade.sol";
import {TestHelpers} from "test/helpers/TestHelpers.sol";
import {MockERC20Token} from "test/mocks/MockERC20Token.sol";
import {SuperDCATrade} from "test/mocks/SuperDCATrade.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice Mock contract that fails on ownerOf calls to test _getTradeOwner catch block
contract FailingSuperDCATrade {
  struct Trade {
    uint256 tradeId;
    uint256 startTime;
    uint256 endTime;
    int96 flowRate;
    uint256 startIdaIndex;
    uint256 endIdaIndex;
    uint256 units;
    uint256 refunded;
  }

  mapping(uint256 => Trade) public trades;

  function createFailingTrade(uint256 tradeId, int96 flowRate) external {
    trades[tradeId] = Trade({
      tradeId: tradeId,
      startTime: block.timestamp,
      endTime: 0,
      flowRate: flowRate,
      startIdaIndex: 100,
      endIdaIndex: 0,
      units: 1000,
      refunded: 0
    });
  }

  // This will revert when called by _getTradeOwner
  function ownerOf(uint256) external pure returns (address) {
    revert("ownerOf always fails");
  }
}

/// @notice Base test contract for SuperDCACashback
abstract contract SuperDCACashbackTest is TestHelpers {
  /// @notice Minimum flow rate to ensure cashback after precision conversion (1e18 -> 1e6) is > 0
  /// @dev This value ensures that after dividing by 1e12, the result is at least 1 (minimum USDC
  /// unit)
  uint256 internal constant MINIMUM_FLOW_RATE_FOR_CASHBACK = 1_200_000_000;

  SuperDCACashback internal cashbackContract;
  MockERC20Token internal usdc;
  SuperDCATrade internal superDCATrade;
  address internal admin;
  address internal user;
  address internal trader;

  function setUp() public virtual {
    admin = makeAddr("Admin");
    user = makeAddr("User");
    trader = makeAddr("Trader");

    // Deploy contracts with admin as owner of SuperDCATrade
    usdc = new MockERC20Token();
    vm.prank(admin);
    superDCATrade = new SuperDCATrade();

    // Create default cashback claim configuration
    SuperDCACashback.CashbackClaim memory defaultClaim = SuperDCACashback.CashbackClaim({
      cashbackBips: 100, // 1%
      duration: 86_400, // 1 day epochs
      minRate: 1,
      maxRate: 1_000_000,
      startTime: block.timestamp,
      timestamp: 0 // Will be set in constructor
    });

    cashbackContract =
      new SuperDCACashback(address(usdc), address(superDCATrade), admin, defaultClaim);

    // Fund the cashback contract with USDC for payouts (6 decimals)
    usdc.mint(address(cashbackContract), 1_000_000 * 10 ** 6);

    // Warp to non-zero timestamp
    vm.warp(1);
  }

  function _deployContractWithClaim(
    uint256 cashbackBips,
    uint256 duration,
    int96 minRate,
    uint256 maxRate,
    uint256 startTime
  ) internal returns (SuperDCACashback) {
    SuperDCACashback.CashbackClaim memory claim = SuperDCACashback.CashbackClaim({
      cashbackBips: cashbackBips,
      duration: duration,
      minRate: minRate,
      maxRate: maxRate,
      startTime: startTime,
      timestamp: 0
    });

    SuperDCACashback newContract =
      new SuperDCACashback(address(usdc), address(superDCATrade), admin, claim);

    // Fund the new contract
    usdc.mint(address(newContract), 1_000_000 * 10 ** 6);

    return newContract;
  }

  function _createTrade(address shareholder, int96 flowRate, uint256 indexValue, uint256 units)
    internal
    returns (uint256 tradeId)
  {
    vm.prank(admin);
    superDCATrade.startTrade(shareholder, flowRate, indexValue, units);
    return superDCATrade.tradesByUser(shareholder, superDCATrade.tradeCountsByUser(shareholder) - 1);
  }

  function _endTrade(address shareholder, uint256 indexValue, uint256 refunded) internal {
    vm.prank(admin);
    superDCATrade.endTrade(shareholder, indexValue, refunded);
  }
}

contract Constructor is SuperDCACashbackTest {
  function test_SetsConfigurationParameters() public view {
    assertEq(address(cashbackContract.USDC()), address(usdc));
    assertEq(address(cashbackContract.SUPER_DCA_TRADE()), address(superDCATrade));
    assertTrue(cashbackContract.hasRole(cashbackContract.DEFAULT_ADMIN_ROLE(), admin));
    assertTrue(cashbackContract.hasRole(cashbackContract.ADMIN_ROLE(), admin));

    // Check cashback claim configuration
    SuperDCACashback.CashbackClaim memory claim = cashbackContract.getCashbackClaim();
    assertEq(claim.cashbackBips, 100);
    assertEq(claim.duration, 86_400);
    assertEq(claim.minRate, 1);
    assertEq(claim.maxRate, 1_000_000);
    assertEq(claim.startTime, 1); // Timestamp at setup
  }

  function testFuzz_SetsConfigurationParametersToArbitraryValues(
    address _usdc,
    address _superDCATrade,
    address _admin,
    uint256 _cashbackBips,
    uint256 _duration,
    int96 _minRate,
    uint256 _maxRate,
    uint256 _startTime
  ) public {
    _assumeSafeAddress(_usdc);
    _assumeSafeAddress(_superDCATrade);
    _assumeSafeAddress(_admin);
    _cashbackBips = _boundToCashbackBips(_cashbackBips);
    _duration = _boundToReasonableDuration(_duration);
    _minRate = _boundToReasonableFlowRate(_minRate);
    _maxRate = _boundToReasonableMaxRate(_maxRate, _minRate);
    _startTime = _boundToReasonableTime(_startTime);

    SuperDCACashback.CashbackClaim memory claim = SuperDCACashback.CashbackClaim({
      cashbackBips: _cashbackBips,
      duration: _duration,
      minRate: _minRate,
      maxRate: _maxRate,
      startTime: _startTime,
      timestamp: 0
    });

    SuperDCACashback _cashbackContract = new SuperDCACashback(_usdc, _superDCATrade, _admin, claim);

    assertEq(address(_cashbackContract.USDC()), _usdc);
    assertEq(address(_cashbackContract.SUPER_DCA_TRADE()), _superDCATrade);
    assertTrue(_cashbackContract.hasRole(_cashbackContract.DEFAULT_ADMIN_ROLE(), _admin));
    assertTrue(_cashbackContract.hasRole(_cashbackContract.ADMIN_ROLE(), _admin));

    SuperDCACashback.CashbackClaim memory storedClaim = _cashbackContract.getCashbackClaim();
    assertEq(storedClaim.cashbackBips, _cashbackBips);
    assertEq(storedClaim.duration, _duration);
    assertEq(storedClaim.minRate, _minRate);
    assertEq(storedClaim.maxRate, _maxRate);
    assertEq(storedClaim.startTime, _startTime);
  }

  function testFuzz_RevertIf_InvalidCashbackBips(uint256 _cashbackBips) public {
    _cashbackBips = _boundToInvalidCashbackBips(_cashbackBips);

    SuperDCACashback.CashbackClaim memory claim = SuperDCACashback.CashbackClaim({
      cashbackBips: _cashbackBips,
      duration: 86_400,
      minRate: 1,
      maxRate: 1000,
      startTime: block.timestamp,
      timestamp: 0
    });

    vm.expectRevert(abi.encodeWithSelector(SuperDCACashback.InvalidParams.selector, 0));
    new SuperDCACashback(address(usdc), address(superDCATrade), admin, claim);
  }

  function testFuzz_RevertIf_InvalidRates(int96 _minRate, uint256 _maxRate) public {
    _minRate = _boundToReasonableFlowRate(_minRate);
    _maxRate = bound(_maxRate, 0, uint256(int256(_minRate)));

    SuperDCACashback.CashbackClaim memory claim = SuperDCACashback.CashbackClaim({
      cashbackBips: 100,
      duration: 86_400,
      minRate: _minRate,
      maxRate: _maxRate,
      startTime: block.timestamp,
      timestamp: 0
    });

    vm.expectRevert(abi.encodeWithSelector(SuperDCACashback.InvalidParams.selector, 2));
    new SuperDCACashback(address(usdc), address(superDCATrade), admin, claim);
  }

  function test_RevertIf_ZeroDuration() public {
    SuperDCACashback.CashbackClaim memory claim = SuperDCACashback.CashbackClaim({
      cashbackBips: 100,
      duration: 0,
      minRate: 1,
      maxRate: 1000,
      startTime: block.timestamp,
      timestamp: 0
    });

    vm.expectRevert(abi.encodeWithSelector(SuperDCACashback.InvalidParams.selector, 1));
    new SuperDCACashback(address(usdc), address(superDCATrade), admin, claim);
  }

  function test_RevertIf_MaxRateExceedsInt96Max() public {
    // Test maxRate overflow validation - when maxRate > uint256(uint96(type(int96).max))
    uint256 invalidMaxRate = uint256(uint96(type(int96).max)) + 1;

    SuperDCACashback.CashbackClaim memory claim = SuperDCACashback.CashbackClaim({
      cashbackBips: 100,
      duration: 86_400,
      minRate: 1,
      maxRate: invalidMaxRate,
      startTime: block.timestamp,
      timestamp: 0
    });

    vm.expectRevert(abi.encodeWithSelector(SuperDCACashback.InvalidParams.selector, 2));
    new SuperDCACashback(address(usdc), address(superDCATrade), admin, claim);
  }
}

/// @notice Tests for getTradeStatus function
contract GetTradeStatus is SuperDCACashbackTest {
  function testFuzz_ReturnsCorrectStatusForValidTrade(
    int96 _flowRate,
    uint256 _duration,
    uint256 _cashbackBips
  ) public {
    _flowRate = _boundToReasonableFlowRate(_flowRate);
    _duration = _boundToReasonableDuration(_duration);
    _cashbackBips = _boundToCashbackBips(_cashbackBips);

    uint256 maxRate = uint256(int256(_flowRate)) + 1000;
    uint256 epochStartTime = block.timestamp + 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(_cashbackBips, _duration, _flowRate, maxRate, epochStartTime);

    // Create trade before epoch starts
    vm.warp(epochStartTime - 500);
    uint256 tradeId = _createTrade(trader, _flowRate, 100, 1000);

    // Move to middle of first epoch
    vm.warp(epochStartTime + (_duration / 2));

    // Get trade status
    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // No epochs completed yet, so claimable should be 0
    assertEq(claimable, 0);

    // Calculate expected pending amount matching contract logic
    uint256 tradeStartTime = epochStartTime - 500; // we warped -500s before startTrade
    uint256 timeElapsed = block.timestamp - tradeStartTime;
    uint256 incompleteEpochTime = timeElapsed % _duration;
    uint256 pendingAmount = uint256(int256(_flowRate)) * incompleteEpochTime;
    uint256 expectedPending = (pendingAmount * _cashbackBips) / 10_000 / 1e12;

    assertEq(pending, expectedPending);
    assertEq(claimed, 0);
  }

  function testFuzz_ReturnsZerosForNonExistentTrade(uint256 _tradeId) public {
    _tradeId = _boundToReasonableTradeId(_tradeId);

    (uint256 claimable, uint256 pending, uint256 claimed) =
      cashbackContract.getTradeStatus(_tradeId);

    assertEq(claimable, 0);
    assertEq(pending, 0);
    assertEq(claimed, 0);
  }

  function testFuzz_ReturnsCorrectStatusAfterClaim(int96 _flowRate) public {
    _flowRate = _boundToReasonableFlowRate(_flowRate);

    // Ensure flowRate is large enough so that cashback after precision conversion is > 0
    vm.assume(uint256(int256(_flowRate)) >= MINIMUM_FLOW_RATE_FOR_CASHBACK);

    uint256 maxRate = uint256(int256(_flowRate)) + 1000;
    uint256 epochStartTime = block.timestamp + 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, 86_400, _flowRate, maxRate, epochStartTime);

    // Create trade before epoch starts
    vm.warp(epochStartTime - 500);
    uint256 tradeId = _createTrade(trader, _flowRate, 100, 1000);

    // Move to after first epoch
    vm.warp(epochStartTime + 86_400);

    // Claim cashback
    vm.prank(trader);
    uint256 claimedAmount = testContract.claimAllCashback(tradeId);

    // Check status after claim
    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    assertEq(claimable, 0);
    assertEq(claimed, claimedAmount);

    // Calculate expected pending for the second (incomplete) epoch
    uint256 tradeStartTime = epochStartTime - 500; // Based on warp before starting the trade
    uint256 timeElapsed = block.timestamp - tradeStartTime;
    uint256 incompleteEpochTime = timeElapsed % 86_400;
    uint256 pendingAmount = uint256(int256(_flowRate)) * incompleteEpochTime;
    uint256 expectedPending = (pendingAmount * 100) / 10_000 / 1e12;

    assertEq(pending, expectedPending);
  }

  function test_HandlesEndedTrade() public {
    uint256 epochStartTime = block.timestamp + 1000;
    uint256 duration = 86_400;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, 1_000_000_000_000_000_000, epochStartTime);

    // Create trade before epoch starts
    vm.warp(epochStartTime - 500);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade during first epoch
    vm.warp(epochStartTime + 1000);
    _endTrade(trader, 110, 0);

    // Move to after first epoch
    vm.warp(epochStartTime + duration);

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // The trade ended before a full epoch elapsed, so no rewards should be claimable.
    assertEq(claimable, 0);
    assertEq(pending, 0);
    assertEq(claimed, 0);
  }

  function test_HandlesFlowRateBelowMinimum() public {
    uint256 epochStartTime = block.timestamp + 1000;
    SuperDCACashback testContract = _deployContractWithClaim(
      100,
      86_400,
      100, // minRate = 100
      1000,
      epochStartTime
    );

    // Create trade with flow rate below minimum
    vm.warp(epochStartTime - 500);
    uint256 tradeId = _createTrade(trader, 50, 100, 1000);

    // Move to after first epoch
    vm.warp(epochStartTime + 86_400);

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    assertEq(claimable, 0);
    assertEq(pending, 0);
    assertEq(claimed, 0);
  }

  function test_CapsFlowRateAtMaxRate() public {
    int96 highFlowRate = 2000 * 1e15;
    uint256 maxRate = 1000 * 1e15;
    uint256 epochStartTime = block.timestamp + 1000;
    uint256 duration = 86_400;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, maxRate, epochStartTime);

    // Create trade with flow rate above maximum
    vm.warp(epochStartTime - 500);
    uint256 tradeId = _createTrade(trader, highFlowRate, 100, 1000);

    // Move to after first epoch
    vm.warp(epochStartTime + duration);

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // Calculate expected claimable using capped rate
    uint256 cappedTradeAmount = maxRate * duration;
    uint256 expectedClaimable = (cappedTradeAmount * 100) / 10_000 / 1e12;

    assertEq(claimable, expectedClaimable);

    // Verify amount is less than what it would be without capping
    uint256 uncappedTradeAmount = uint256(int256(highFlowRate)) * duration;
    uint256 uncappedClaimable = (uncappedTradeAmount * 100) / 10_000 / 1e12;
    assertLt(claimable, uncappedClaimable);
  }

  // -------------------------------------------------------------
  // Additional edge-case test for getTradeStatus
  // -------------------------------------------------------------
  function testFuzz_GetTradeStatus_ImmediatelyAfterTradeStart(int96 _flowRate) public {
    _flowRate = _boundToReasonableFlowRate(_flowRate);
    uint256 tradeId = _createTrade(trader, _flowRate, 100, 1000);
    (uint256 claimable, uint256 pending, uint256 claimed) = cashbackContract.getTradeStatus(tradeId);
    assertEq(claimable, 0);
    assertEq(pending, 0);
    assertEq(claimed, 0);
  }
}

/// @notice Tests for claimAllCashback function
contract ClaimAllCashback is SuperDCACashbackTest {
  function testFuzz_ClaimsAllAvailableCashback(
    int96 _flowRate,
    uint256 _duration,
    uint256 _cashbackBips
  ) public {
    _flowRate = _boundToReasonableFlowRate(_flowRate);
    _duration = _boundToReasonableDuration(_duration);
    _cashbackBips = _boundToCashbackBips(_cashbackBips);

    uint256 maxRate = uint256(int256(_flowRate)) + 1000;
    uint256 startTime = block.timestamp + 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(_cashbackBips, _duration, _flowRate, maxRate, startTime);

    // Create trade before start time
    vm.warp(startTime - 500);
    uint256 tradeId = _createTrade(trader, _flowRate, 100, 1000);

    // Move to some time after start
    vm.warp(startTime + _duration);

    uint256 initialBalance = usdc.balanceOf(trader);

    // Get expected claimable amount
    (uint256 expectedClaimable,,) = testContract.getTradeStatus(tradeId);
    vm.assume(expectedClaimable > 0);

    vm.prank(trader);
    uint256 actualCashback = testContract.claimAllCashback(tradeId);

    // Verify return value matches expected
    assertEq(actualCashback, expectedClaimable);

    // Verify balance was updated correctly
    assertEq(usdc.balanceOf(trader), initialBalance + expectedClaimable);

    // Verify amount was tracked in claimedAmounts
    assertEq(testContract.claimedAmounts(tradeId), expectedClaimable);
  }

  function test_EmitsCashbackClaimedEvent() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 86_400;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime - 500);
    int96 flowRate = 1e15;
    uint256 tradeId = _createTrade(trader, flowRate, 100, 1000);

    vm.warp(startTime + duration);

    (uint256 expectedClaimable,,) = testContract.getTradeStatus(tradeId);
    vm.assume(expectedClaimable > 0);

    vm.prank(trader);
    vm.expectEmit();
    emit SuperDCACashback.CashbackClaimed(trader, tradeId, expectedClaimable);
    testContract.claimAllCashback(tradeId);
  }

  function test_RevertIf_NoClaimableAmount() public {
    uint256 startTime = block.timestamp + 1000;
    SuperDCACashback testContract = _deployContractWithClaim(100, 86_400, 1, 1000, startTime);

    vm.warp(startTime - 500);
    uint256 tradeId = _createTrade(trader, 100, 100, 1000);

    // Move to middle of duration (no completed time yet)
    vm.warp(startTime + 1000);

    vm.prank(trader);
    vm.expectRevert(SuperDCACashback.NotClaimable.selector);
    testContract.claimAllCashback(tradeId);
  }

  function test_RevertIf_TradeDoesNotExist() public {
    uint256 nonExistentTradeId = 999;

    vm.prank(trader);
    vm.expectRevert(SuperDCACashback.NotClaimable.selector);
    cashbackContract.claimAllCashback(nonExistentTradeId);
  }

  function test_RevertIf_CallerNotTradeOwner() public {
    uint256 startTime = block.timestamp + 1000;
    SuperDCACashback testContract = _deployContractWithClaim(100, 86_400, 1, 1000, startTime);

    vm.warp(startTime - 500);
    uint256 tradeId = _createTrade(trader, 100, 100, 1000);

    vm.warp(startTime + 86_400);

    address nonOwner = makeAddr("NonOwner");
    vm.prank(nonOwner);
    vm.expectRevert(SuperDCACashback.NotAuthorized.selector);
    testContract.claimAllCashback(tradeId);
  }

  function test_HandlesPartialDurationTrade() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 100;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, 1_000_000_000_000_000_000, startTime);

    // Start trade after start time
    vm.warp(startTime + 50);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade after some time
    vm.warp(startTime + 150);
    _endTrade(trader, 110, 0);

    // Move to later time
    vm.warp(startTime + 200);

    uint256 initialBalance = usdc.balanceOf(trader);

    vm.prank(trader);
    uint256 totalCashback = testContract.claimAllCashback(tradeId);

    // Calculate expected cashback for active duration
    uint256 activeTime = (startTime + 150) - (startTime + 50); // endTime - startTime
    uint256 tradeAmount = uint256(1e15) * activeTime;
    uint256 expectedCashback = (tradeAmount * 100) / 10_000 / 1e12;

    assertEq(totalCashback, expectedCashback);
    assertEq(usdc.balanceOf(trader), initialBalance + expectedCashback);
  }

  function test_CapsFlowRateAtMaxRate() public {
    int96 highFlowRate = 2000 * 1e15;
    uint256 maxRate = 1000 * 1e15;
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 86_400;
    SuperDCACashback testContract = _deployContractWithClaim(100, duration, 1, maxRate, startTime);

    vm.warp(startTime - 500);
    uint256 tradeId = _createTrade(trader, highFlowRate, 100, 1000);

    vm.warp(startTime + duration);

    uint256 initialBalance = usdc.balanceOf(trader);

    vm.prank(trader);
    uint256 totalCashback = testContract.claimAllCashback(tradeId);

    // Calculate expected cashback using capped rate
    uint256 cappedTradeAmount = maxRate * duration;
    uint256 expectedCashback = (cappedTradeAmount * 100) / 10_000 / 1e12;

    assertEq(totalCashback, expectedCashback);
    assertEq(usdc.balanceOf(trader), initialBalance + expectedCashback);
  }

  function test_RevertIf_AllAmountsClaimed() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 86_400;
    int96 flowRate = 1e15; // sufficiently large to yield non-zero cashback
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime - 500);
    uint256 tradeId = _createTrade(trader, flowRate, 100, 1000);

    vm.warp(startTime + duration);

    // Claim all available cashback first time
    vm.prank(trader);
    uint256 claimed = testContract.claimAllCashback(tradeId);
    assertGt(claimed, 0);

    // Second attempt should revert because everything is already claimed
    vm.prank(trader);
    vm.expectRevert(SuperDCACashback.NotClaimable.selector);
    testContract.claimAllCashback(tradeId);
  }

  function test_HandlesFlowRateBelowMinimum() public {
    uint256 startTime = block.timestamp + 1000;
    SuperDCACashback testContract = _deployContractWithClaim(
      100,
      86_400,
      100, // minRate = 100
      1000,
      startTime
    );

    vm.warp(startTime - 500);
    uint256 tradeId = _createTrade(trader, 50, 100, 1000);

    vm.warp(startTime + 86_400);

    vm.prank(trader);
    vm.expectRevert(SuperDCACashback.NotClaimable.selector);
    testContract.claimAllCashback(tradeId);
  }

  function testFuzz_ClaimCashback_TradeEndsDuringFirstEpoch(
    int96 _flowRate,
    uint256 _duration,
    uint256 _stopOffset
  ) public {
    _flowRate = _boundToReasonableFlowRate(_flowRate);
    _duration = _boundToReasonableDuration(_duration);
    _stopOffset = bound(_stopOffset, 1, _duration - 1);

    uint256 startTime = block.timestamp + 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, _duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, _flowRate, 100, 1000);

    // End trade during first epoch
    vm.warp(startTime + _stopOffset);
    _endTrade(trader, 110, 0);

    // Move past first epoch so it becomes claimable
    vm.warp(startTime + _duration + 10);

    vm.prank(trader);
    vm.expectRevert(SuperDCACashback.NotClaimable.selector);
    testContract.claimAllCashback(tradeId);
  }

  function testFuzz_RevertIf_GetTradeOwnerFails(uint256 _cashbackBips, uint256 _duration) public {
    _cashbackBips = _boundToCashbackBips(_cashbackBips);
    _duration = _boundToReasonableDuration(_duration);

    MockERC20Token token = new MockERC20Token();
    FailingSuperDCATrade failingTrade = new FailingSuperDCATrade();

    SuperDCACashback.CashbackClaim memory claim = SuperDCACashback.CashbackClaim({
      cashbackBips: _cashbackBips,
      duration: _duration,
      minRate: 1,
      maxRate: 1000,
      startTime: block.timestamp,
      timestamp: 0
    });

    SuperDCACashback testContract =
      new SuperDCACashback(address(token), address(failingTrade), admin, claim);
    token.mint(address(testContract), 1_000_000 * 10 ** 6);

    failingTrade.createFailingTrade(1, 100);

    vm.expectRevert(SuperDCACashback.NotAuthorized.selector);
    testContract.claimAllCashback(1);
  }

  function testFuzz_ClaimCashback_MultipleEpochs_NoForfeiture(
    int96 _flowRate,
    uint256 _duration,
    uint8 _epochs
  ) public {
    _flowRate = _boundToReasonableFlowRate(_flowRate);
    _duration = _boundToReasonableDuration(_duration);
    _epochs = uint8(bound(_epochs, 2, 10));

    uint256 startTime = block.timestamp + 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, _duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, _flowRate, 100, 1000);

    vm.warp(startTime + (_duration * _epochs));

    (uint256 expected,,) = testContract.getTradeStatus(tradeId);
    vm.assume(expected > 0);

    vm.prank(trader);
    uint256 claimedAmount = testContract.claimAllCashback(tradeId);

    assertEq(claimedAmount, expected);
  }

  function testFuzz_ClaimCashback_AdditionalEpochs_WithForfeiture(
    int96 _flowRate,
    uint256 _duration,
    uint8 _totalEpochs,
    uint256 _partialOffset
  ) public {
    // Covers branch where maxCompletedEpochs > 1 (eligibleAdditionalEpochs > 0)
    _flowRate = _boundToReasonableFlowRate(_flowRate);
    _duration = _boundToReasonableDuration(_duration);
    _totalEpochs = uint8(bound(_totalEpochs, 3, 10));

    uint256 startTime = block.timestamp + 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, _duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, _flowRate, 100, 1000);

    // End trade somewhere in the second epoch
    _partialOffset = bound(_partialOffset, 1, _duration - 1);
    uint256 tradeEndTime = startTime + (_duration * 2) + _partialOffset;
    vm.warp(tradeEndTime);
    _endTrade(trader, 110, 0);

    // Warp to after the chosen number of epochs
    vm.warp(startTime + (_duration * _totalEpochs) + 10);

    (uint256 expected,,) = testContract.getTradeStatus(tradeId);
    vm.assume(expected > 0);

    vm.prank(trader);
    uint256 claimedAmount = testContract.claimAllCashback(tradeId);

    assertEq(claimedAmount, expected);
  }

  function testFuzz_ClaimCashback_AdditionalEpochs_FullyForfeited(
    int96 _flowRate,
    uint256 _duration,
    uint8 _warpEpochs,
    uint256 _partialOffset
  ) public {
    _flowRate = _boundToReasonableFlowRate(_flowRate);
    _duration = _boundToReasonableDuration(_duration);
    _warpEpochs = uint8(bound(_warpEpochs, 3, 10));
    _partialOffset = bound(_partialOffset, 1, _duration - 1);

    uint256 startTime = block.timestamp + 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, _duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, _flowRate, 100, 1000);

    // End trade within the first epoch
    vm.warp(startTime + _partialOffset);
    _endTrade(trader, 110, 0);

    // Warp past several epochs so completedEpochs > 1
    vm.warp(startTime + (_duration * _warpEpochs));

    // The trade ended within the first epoch, so rewards are forfeited.
    vm.prank(trader);
    vm.expectRevert(SuperDCACashback.NotClaimable.selector);
    testContract.claimAllCashback(tradeId);
  }
}

/// @notice Tests for coverage of internal functions and edge cases
contract InternalFunctionCoverage is SuperDCACashbackTest {
  function test_TradeEndingInFirstEpoch_PartialDuration() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    // Start trade at epoch start
    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade partway through first epoch (covers _calculateFirstEpochCashback lines 232-237)
    vm.warp(startTime + 500); // End after 500 seconds of 1000 second epoch
    _endTrade(trader, 110, 0);

    // Move to after first epoch completes
    vm.warp(startTime + duration + 100);

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // Since trade ended before first epoch completed, no rewards
    assertEq(claimable, 0);
    assertEq(pending, 0);
    assertEq(claimed, 0);
  }

  function test_TradeWithMultipleEpochs_EndingInLaterEpoch() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    // Start trade at epoch start
    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade partway through third epoch (2.5 epochs total)
    // This covers _getEligibleAdditionalEpochs logic for maxCompletedEpochs > 1
    vm.warp(startTime + (duration * 2) + 500);
    _endTrade(trader, 110, 0);

    // Move to after multiple epochs
    vm.warp(startTime + (duration * 5));

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // Should get rewards for 2 completed epochs only
    uint256 expectedPerEpoch = (uint256(1e15) * duration * 100) / 10_000 / 1e12;
    uint256 expectedTotal = expectedPerEpoch * 2;

    assertEq(claimable, expectedTotal);
    assertEq(pending, 0);
  }

  function test_TradeEndingExactlyAtEpochBoundary() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade exactly at end of second epoch
    vm.warp(startTime + (duration * 2));
    _endTrade(trader, 110, 0);

    // Move to later time
    vm.warp(startTime + (duration * 5));

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // Should get rewards for exactly 2 completed epochs
    uint256 expectedPerEpoch = (uint256(1e15) * duration * 100) / 10_000 / 1e12;
    uint256 expectedTotal = expectedPerEpoch * 2;

    assertEq(claimable, expectedTotal);
  }

  function test_LongRunningTrade_ManyEpochs() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 100; // Short epochs for testing
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade after many epochs (covers large epoch calculations)
    vm.warp(startTime + (duration * 10) + 50); // 10.5 epochs
    _endTrade(trader, 110, 0);

    // Move to much later time
    vm.warp(startTime + (duration * 20));

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // Should get rewards for 10 completed epochs
    uint256 expectedPerEpoch = (uint256(1e15) * duration * 100) / 10_000 / 1e12;
    uint256 expectedTotal = expectedPerEpoch * 10;

    assertEq(claimable, expectedTotal);
  }

  function testFuzz_MaxEligibleAdditionalEpochs_VariousScenarios(
    uint8 _totalEpochs,
    uint8 _endEpochFraction
  ) public {
    _totalEpochs = uint8(bound(_totalEpochs, 1, 20));
    _endEpochFraction = uint8(bound(_endEpochFraction, 1, 99));

    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 100;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade partway through a later epoch
    uint256 endTime = startTime + (duration * _totalEpochs) + (duration * _endEpochFraction / 100);
    vm.warp(endTime);
    _endTrade(trader, 110, 0);

    // Move to much later to see all possible rewards
    vm.warp(startTime + (duration * 50));

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // Calculate expected epochs: floor(tradeDuration / epochDuration)
    uint256 tradeDuration = endTime - startTime;
    uint256 expectedEpochs = tradeDuration / duration;

    if (expectedEpochs > 0) {
      uint256 expectedPerEpoch = (uint256(1e15) * duration * 100) / 10_000 / 1e12;
      uint256 expectedTotal = expectedPerEpoch * expectedEpochs;
      assertEq(claimable, expectedTotal);
    } else {
      assertEq(claimable, 0);
    }
  }

  function test_TradeEndingInFirstEpoch_NoRewards() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade very early in first epoch (covers maxCompletedEpochs <= 1 branch)
    vm.warp(startTime + 100);
    _endTrade(trader, 110, 0);

    // Move to after many epochs
    vm.warp(startTime + (duration * 10));

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // No completed epochs, so no rewards
    assertEq(claimable, 0);
    assertEq(pending, 0);
  }

  function test_EdgeCase_RequestedEpochsVsMaxEligible() public {
    uint256 startTime = block.timestamp + 1000;
    uint256 duration = 1000;
    SuperDCACashback testContract =
      _deployContractWithClaim(100, duration, 1, uint256(uint96(type(int96).max)), startTime);

    vm.warp(startTime);
    uint256 tradeId = _createTrade(trader, 1e15, 100, 1000);

    // End trade after exactly 3 epochs (covers min logic in _getEligibleAdditionalEpochs)
    vm.warp(startTime + (duration * 3));
    _endTrade(trader, 110, 0);

    // Move to much later time that would suggest more epochs if trade was active
    vm.warp(startTime + (duration * 10));

    (uint256 claimable, uint256 pending, uint256 claimed) = testContract.getTradeStatus(tradeId);

    // Should get exactly 3 epochs worth of rewards
    uint256 expectedPerEpoch = (uint256(1e15) * duration * 100) / 10_000 / 1e12;
    uint256 expectedTotal = expectedPerEpoch * 3;

    assertEq(claimable, expectedTotal);
  }
}

/// @notice Tests for getCashbackClaim function
contract GetCashbackClaim is SuperDCACashbackTest {
  function testFuzz_ReturnsClaimInformation(
    uint256 _cashbackBips,
    uint256 _duration,
    int96 _minRate,
    uint256 _maxRate,
    uint256 _startTime
  ) public {
    _cashbackBips = _boundToCashbackBips(_cashbackBips);
    _duration = _boundToReasonableDuration(_duration);
    _minRate = _boundToReasonableFlowRate(_minRate);
    _maxRate = _boundToReasonableMaxRate(_maxRate, _minRate);
    _startTime = _boundToReasonableTime(_startTime);

    SuperDCACashback testContract =
      _deployContractWithClaim(_cashbackBips, _duration, _minRate, _maxRate, _startTime);

    SuperDCACashback.CashbackClaim memory claim = testContract.getCashbackClaim();

    assertEq(claim.cashbackBips, _cashbackBips);
    assertEq(claim.duration, _duration);
    assertEq(claim.minRate, _minRate);
    assertEq(claim.maxRate, _maxRate);
    assertEq(claim.startTime, _startTime);
    assertGt(claim.timestamp, 0); // Should be set to block.timestamp in constructor
  }

  function test_ReturnsDefaultClaimInformation() public view {
    SuperDCACashback.CashbackClaim memory claim = cashbackContract.getCashbackClaim();

    assertEq(claim.cashbackBips, 100);
    assertEq(claim.duration, 86_400);
    assertEq(claim.minRate, 1);
    assertEq(claim.maxRate, 1_000_000);
    assertEq(claim.startTime, 1);
    assertGt(claim.timestamp, 0);
  }
}

/// @notice Tests for withdrawTokens function
contract WithdrawTokens is SuperDCACashbackTest {
  MockERC20Token internal testToken;
  address internal recipient;

  function setUp() public override {
    super.setUp();
    recipient = makeAddr("Recipient");
    testToken = new MockERC20Token();
  }

  function testFuzz_WithdrawsTokensSuccessfully(uint256 _amount, address _recipient) public {
    _assumeSafeAddress(_recipient);
    vm.assume(_recipient != address(0));
    vm.assume(_recipient != address(cashbackContract)); // Don't withdraw to self
    _amount = bound(_amount, 1, 1_000_000 * 10 ** 6);

    // Fund the contract with test tokens
    testToken.mint(address(cashbackContract), _amount);

    uint256 initialRecipientBalance = testToken.balanceOf(_recipient);
    uint256 initialContractBalance = testToken.balanceOf(address(cashbackContract));

    vm.prank(admin);
    cashbackContract.withdrawTokens(address(testToken), _recipient, _amount);

    assertEq(testToken.balanceOf(_recipient), initialRecipientBalance + _amount);
    assertEq(testToken.balanceOf(address(cashbackContract)), initialContractBalance - _amount);
  }

  function testFuzz_WithdrawsUSDCSuccessfully(uint256 _amount) public {
    _amount = bound(_amount, 1, 500_000 * 10 ** 6);

    uint256 initialRecipientBalance = usdc.balanceOf(recipient);
    uint256 initialContractBalance = usdc.balanceOf(address(cashbackContract));

    vm.prank(admin);
    cashbackContract.withdrawTokens(address(usdc), recipient, _amount);

    assertEq(usdc.balanceOf(recipient), initialRecipientBalance + _amount);
    assertEq(usdc.balanceOf(address(cashbackContract)), initialContractBalance - _amount);
  }

  function testFuzz_EmitsTokensWithdrawnEvent(uint256 _amount, address _recipient) public {
    _assumeSafeAddress(_recipient);
    vm.assume(_recipient != address(0));
    _amount = bound(_amount, 1, 1_000_000 * 10 ** 6);

    testToken.mint(address(cashbackContract), _amount);

    vm.prank(admin);
    vm.expectEmit();
    emit SuperDCACashback.TokensWithdrawn(address(testToken), _recipient, _amount);
    cashbackContract.withdrawTokens(address(testToken), _recipient, _amount);
  }

  function testFuzz_RevertIf_CalledByNonAdmin(address _caller, uint256 _amount) public {
    _assumeNotAdmin(_caller, admin);
    _amount = bound(_amount, 1, 1_000_000 * 10 ** 6);

    testToken.mint(address(cashbackContract), _amount);

    vm.prank(_caller);
    vm.expectRevert();
    cashbackContract.withdrawTokens(address(testToken), recipient, _amount);
  }

  function testFuzz_RevertIf_RecipientIsZeroAddress(uint256 _amount) public {
    _amount = bound(_amount, 1, 1_000_000 * 10 ** 6);

    testToken.mint(address(cashbackContract), _amount);

    vm.prank(admin);
    vm.expectRevert(abi.encodeWithSelector(SuperDCACashback.InvalidParams.selector, 1));
    cashbackContract.withdrawTokens(address(testToken), address(0), _amount);
  }

  function testFuzz_RevertIf_AmountIsZero(address _recipient) public {
    _assumeSafeAddress(_recipient);
    vm.assume(_recipient != address(0));

    testToken.mint(address(cashbackContract), 1000);

    vm.prank(admin);
    vm.expectRevert(abi.encodeWithSelector(SuperDCACashback.InvalidParams.selector, 2));
    cashbackContract.withdrawTokens(address(testToken), _recipient, 0);
  }

  function testFuzz_RevertIf_InsufficientTokenBalance(uint256 _amount) public {
    _amount = bound(_amount, 1, 1_000_000 * 10 ** 6);

    // Don't mint any tokens to the contract

    vm.prank(admin);
    vm.expectRevert();
    cashbackContract.withdrawTokens(address(testToken), recipient, _amount);
  }

  function test_WithdrawsPartialBalance() public {
    uint256 totalAmount = 1000 * 10 ** 6;
    uint256 withdrawAmount = 400 * 10 ** 6;

    testToken.mint(address(cashbackContract), totalAmount);

    vm.prank(admin);
    cashbackContract.withdrawTokens(address(testToken), recipient, withdrawAmount);

    assertEq(testToken.balanceOf(recipient), withdrawAmount);
    assertEq(testToken.balanceOf(address(cashbackContract)), totalAmount - withdrawAmount);
  }

  function test_WithdrawsEntireBalance() public {
    uint256 totalAmount = 1000 * 10 ** 6;

    testToken.mint(address(cashbackContract), totalAmount);

    vm.prank(admin);
    cashbackContract.withdrawTokens(address(testToken), recipient, totalAmount);

    assertEq(testToken.balanceOf(recipient), totalAmount);
    assertEq(testToken.balanceOf(address(cashbackContract)), 0);
  }

  function test_WithdrawsDifferentTokensSequentially() public {
    MockERC20Token secondToken = new MockERC20Token();
    uint256 amount1 = 500 * 10 ** 6;
    uint256 amount2 = 300 * 10 ** 6;

    testToken.mint(address(cashbackContract), amount1);
    secondToken.mint(address(cashbackContract), amount2);

    vm.startPrank(admin);

    cashbackContract.withdrawTokens(address(testToken), recipient, amount1);
    cashbackContract.withdrawTokens(address(secondToken), recipient, amount2);

    vm.stopPrank();

    assertEq(testToken.balanceOf(recipient), amount1);
    assertEq(secondToken.balanceOf(recipient), amount2);
  }
}

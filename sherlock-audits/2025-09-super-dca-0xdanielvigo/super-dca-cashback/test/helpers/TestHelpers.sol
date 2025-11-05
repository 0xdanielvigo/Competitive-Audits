// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";

abstract contract TestHelpers is Test {
  /// @notice Helper to assume safe address (non-zero, non-precompile, non-VM)
  function _assumeSafeAddress(address _address) internal pure {
    vm.assume(_address != address(0));
    _assumeSafeMockAddress(_address);
  }

  /// @notice Helper to assume safe mock address (avoid VM addresses)
  function _assumeSafeMockAddress(address _address) internal pure {
    vm.assume(_address > address(0x9));
    vm.assume(_address != address(0x000000000000000000636F6e736F6c652e6c6f67)); // console.log
    vm.assume(_address != address(0x4e59b44847b379578588920cA78FbF26c0B4956C)); // CREATE2
  }

  /// @notice Helper to bound cashback basis points to reasonable values (0-100%)
  function _boundToCashbackBips(uint256 _bips) internal pure returns (uint256) {
    return bound(_bips, 1, 1000); // 0.01% to 10%
  }

  /// @notice Helper to bound cashback basis points to invalid values (>100%)
  function _boundToInvalidCashbackBips(uint256 _bips) internal pure returns (uint256) {
    return bound(_bips, 10_001, type(uint256).max);
  }

  /// @notice Helper to bound duration to reasonable values (1 second to 1 year)
  function _boundToReasonableDuration(uint256 _duration) internal pure returns (uint256) {
    return bound(_duration, 3600, 365 days); // 1 hour to 1 year
  }

  /// @notice Helper to bound flow rate to reasonable positive values
  function _boundToReasonableFlowRate(int96 _flowRate) internal pure returns (int96) {
    return int96(bound(int256(_flowRate), 100, int256(type(int96).max / 1e15)));
  }

  /// @notice Helper to bound max rate to reasonable values above min rate
  function _boundToReasonableMaxRate(uint256 _maxRate, int96 _minRate)
    internal
    pure
    returns (uint256)
  {
    uint256 minVal = uint256(int256(_minRate)) + 1;
    uint256 maxVal = uint256(int256(type(int96).max / 1e15));
    // Ensure we don't have invalid bounds
    if (minVal >= maxVal) return minVal + 1;
    return bound(_maxRate, minVal, maxVal);
  }

  /// @notice Helper to bound time periods
  function _boundToReasonableTime(uint256 _time) internal view returns (uint256) {
    return bound(_time, block.timestamp, block.timestamp + 365 days);
  }

  /// @notice Helper to bound extra time for warping
  function _boundToExtraTime(uint256 _extraTime) internal pure returns (uint256) {
    return bound(_extraTime, 1, 365 days);
  }

  /// @notice Helper to assume address is not admin
  function _assumeNotAdmin(address _address, address _admin) internal pure {
    vm.assume(_address != _admin);
  }

  /// @notice Helper to bound trade ID to reasonable values
  function _boundToReasonableTradeId(uint256 _tradeId) internal pure returns (uint256) {
    return bound(_tradeId, 1, 1000);
  }

  /// @notice Helper to bound epoch ID to reasonable values
  function _boundToReasonableEpochId(uint256 _epochId) internal pure returns (uint256) {
    return bound(_epochId, 0, 100);
  }
}

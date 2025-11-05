// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20Token is ERC20 {
  address private _lastTransferTo;
  uint256 private _lastTransferAmount;

  constructor() ERC20("Mock USDC", "USDC") {
    _mint(address(this), 1_000_000 * 10 ** 6); // 1M tokens with 6 decimals
  }

  function decimals() public pure override returns (uint8) {
    return 6; // USDC has 6 decimals
  }

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  function transfer(address to, uint256 amount) public override returns (bool) {
    _lastTransferTo = to;
    _lastTransferAmount = amount;
    return super.transfer(to, amount);
  }

  function lastParam__transfer_to() external view returns (address) {
    return _lastTransferTo;
  }

  function lastParam__transfer_amount() external view returns (uint256) {
    return _lastTransferAmount;
  }
}

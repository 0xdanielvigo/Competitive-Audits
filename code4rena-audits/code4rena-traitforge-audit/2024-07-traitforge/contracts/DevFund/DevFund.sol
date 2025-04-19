// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import './IDevFund.sol';

contract DevFund is IDevFund, Ownable, ReentrancyGuard, Pausable {
  uint256 public totalDevWeight;
  uint256 public totalRewardDebt;
  mapping(address => DevInfo) public devInfo;

  receive() external payable {
    if (totalDevWeight > 0) {
      uint256 amountPerWeight = msg.value / totalDevWeight;
      
      uint256 remaining = msg.value - (amountPerWeight * totalDevWeight);
      
      totalRewardDebt += amountPerWeight;
      if (remaining > 0) {
        (bool success, ) = payable(owner()).call{ value: remaining }('');
        require(success, 'Failed to send Ether to owner');
      }
    } else {
      (bool success, ) = payable(owner()).call{ value: msg.value }('');
      require(success, 'Failed to send Ether to owner');
    }
    emit FundReceived(msg.sender, msg.value);
  }

//@audit-informational, missing natspac
  function addDev(address user, uint256 weight) external onlyOwner {
    //@audit-informational, do not check if 'user' is a 0 address
    DevInfo storage info = devInfo[user];
    require(weight > 0, 'Invalid weight');
    require(info.weight == 0, 'Already registered');
    info.rewardDebt = totalRewardDebt;
    info.weight = weight;
    //@audit-informational, possible overflow here
    //this function may be called multiples times and 'totalDevWeight' may surpass type(uint256).max, causing an overflow problem
    totalDevWeight += weight;
    emit AddDev(user, weight);
  }

//@audit-informational, missing natspac
  function updateDev(address user, uint256 weight) external onlyOwner {
    //@audit-informational, do not check if 'user' is a 0 address
    //@audit-note, can update an existent dev
    DevInfo storage info = devInfo[user];
    require(weight > 0, 'Invalid weight');
    require(info.weight > 0, 'Not dev address');
    //ok
    //@audit-informational, possible overflow here
    //this function may be called multiples times and 'totalDevWeight' may surpass type(uint256).max, causing an overflow problem
    totalDevWeight = totalDevWeight - info.weight + weight;
    //@audit-informational, possible overflow here
    //' info.pendingRewards' may surpass type(uint256).max, causing an overflow problem
    info.pendingRewards += (totalRewardDebt - info.rewardDebt) * info.weight;
    info.rewardDebt = totalRewardDebt;
    info.weight = weight;
    emit UpdateDev(user, weight);
  }

//@audit-informational, missing natspac
  function removeDev(address user) external onlyOwner {
    //@audit-informational, do not check if 'user' is a 0 address
    DevInfo storage info = devInfo[user];
    require(info.weight > 0, 'Not dev address');
    totalDevWeight -= info.weight;
     //@audit-informational, possible overflow here
    //'info.pendingRewards' may surpass type(uint256).max, causing an overflow problem
    info.pendingRewards += (totalRewardDebt - info.rewardDebt) * info.weight;
    info.rewardDebt = totalRewardDebt;
    info.weight = 0;
    emit RemoveDev(user);
  }

//@audit-informational, missing natspac
  function claim() external whenNotPaused nonReentrant {
    DevInfo storage info = devInfo[msg.sender];

    uint256 pending = info.pendingRewards +
      (totalRewardDebt - info.rewardDebt) *
      info.weight;

    if (pending > 0) {
      uint256 claimedAmount = safeRewardTransfer(msg.sender, pending);
      info.pendingRewards = pending - claimedAmount;
      emit Claim(msg.sender, claimedAmount);
    }

    info.rewardDebt = totalRewardDebt;
  }

//@audit-informational, missing natspac
  function pendingRewards(address user) external view returns (uint256) {
    DevInfo storage info = devInfo[user];
    return
      info.pendingRewards + (totalRewardDebt - info.rewardDebt) * info.weight;
  }

//@audit-informational, missing natspac
  function safeRewardTransfer(
    address to,
    uint256 amount
  ) internal returns (uint256) {
    uint256 _rewardBalance = payable(address(this)).balance;
    if (amount > _rewardBalance) amount = _rewardBalance;
    (bool success, ) = payable(to).call{ value: amount }('');
    require(success, 'Failed to send Reward');
    return amount;
  }
}

// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.29;

import {DeploySuperDCACashbackBaseImpl} from "./Deploy.s.sol";

contract DeployOptimism is DeploySuperDCACashbackBaseImpl {
  function getDeploymentConfiguration()
    public
    pure
    override
    returns (DeploymentConfiguration memory)
  {
    return DeploymentConfiguration({
      admin: 0xC07E21c78d6Ad0917cfCBDe8931325C392958892,
      usdc: 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85,
      // Using SuperDCA Trade for USDC>>ETH market
      superDCATrade: 0x56F028e4EFc36DbDf2885A7B79a8af2cbc43Df66
    });
  }

  function getCashbackClaimConfiguration()
    public
    pure
    override
    returns (CashbackClaimConfiguration memory)
  {
    return CashbackClaimConfiguration({
      cashbackBips: 50, // 0.5% in basis points
      duration: 10 minutes, // epoch duration 10 minutes
      minRate: 385_802_469_136, // minRate (1) (1e18/30/24/60/60)
      maxRate: 386_802_469_135_800, // maxRate (1000) (1000e18/30/24/60/60)
      startTime: 0, // Will be set to block.timestamp during deployment
      timestamp: 0
    });
  }

  function run() public override returns (DeployedContracts memory) {
    return super.run();
  }
}

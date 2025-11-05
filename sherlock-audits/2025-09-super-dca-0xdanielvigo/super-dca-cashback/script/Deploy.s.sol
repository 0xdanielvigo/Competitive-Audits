// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {SuperDCACashback} from "src/SuperDCACashback.sol";

abstract contract DeploySuperDCACashbackBaseImpl is Script {
  struct DeploymentConfiguration {
    address admin;
    address usdc;
    address superDCATrade;
  }

  struct CashbackClaimConfiguration {
    uint256 cashbackBips;
    uint256 duration;
    int96 minRate;
    uint256 maxRate;
    uint256 startTime;
    uint256 timestamp;
  }

  struct DeployedContracts {
    SuperDCACashback superDCACashback;
  }

  address public deployer;
  uint256 public deployerPrivateKey;

  function setUp() public virtual {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
    deployer = vm.addr(deployerPrivateKey);
  }

  function getDeploymentConfiguration() public virtual returns (DeploymentConfiguration memory);

  function getCashbackClaimConfiguration()
    public
    virtual
    returns (CashbackClaimConfiguration memory);

  function run() public virtual returns (DeployedContracts memory) {
    DeploymentConfiguration memory config = getDeploymentConfiguration();
    CashbackClaimConfiguration memory cashbackConfig = getCashbackClaimConfiguration();

    // Start broadcast
    vm.startBroadcast(deployerPrivateKey);

    // Create the cashback claim configuration
    SuperDCACashback.CashbackClaim memory cashbackClaim = SuperDCACashback.CashbackClaim({
      cashbackBips: cashbackConfig.cashbackBips,
      duration: cashbackConfig.duration,
      minRate: cashbackConfig.minRate,
      maxRate: cashbackConfig.maxRate,
      startTime: cashbackConfig.startTime == 0 ? block.timestamp : cashbackConfig.startTime,
      timestamp: cashbackConfig.timestamp
    });

    // Deploy SuperDCACashback with cashback claim configuration
    SuperDCACashback superDCACashback =
      new SuperDCACashback(config.usdc, config.superDCATrade, config.admin, cashbackClaim);
    console2.log(
      "SuperDCACashback deployed with cashback claim configuration", address(superDCACashback)
    );

    // Log important addresses and information
    console2.log("Admin:", config.admin);
    console2.log("USDC:", config.usdc);
    console2.log("SuperDCATrade:", config.superDCATrade);

    console2.log("\nIMPORTANT: Deployment configuration values:");
    console2.log("- Admin:", config.admin);
    console2.log("- USDC Token:", config.usdc);
    console2.log("- SuperDCATrade Contract:", config.superDCATrade);

    vm.stopBroadcast();

    return DeployedContracts({superDCACashback: superDCACashback});
  }
}

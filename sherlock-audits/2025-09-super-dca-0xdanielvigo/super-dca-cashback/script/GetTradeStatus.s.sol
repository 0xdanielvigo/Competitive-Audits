// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {ISuperDCATrade} from "src/interfaces/ISuperDCATrade.sol";
import {SuperDCACashback} from "src/SuperDCACashback.sol";

contract GetTradeStatus is Script {
  function run() public {
    // Get trade ID from environment variable
    uint256 tradeId = vm.envOr("TRADE_ID", uint256(0));
    require(tradeId > 0, "TRADE_ID environment variable must be set and greater than 0");

    // Get SuperDCATrade contract address from environment variable
    address superDCATradeAddress =
      vm.envOr("SUPER_DCA_TRADE_ADDRESS", address(0x0000000000000000000000000000000000000000));
    require(
      superDCATradeAddress != address(0), "SUPER_DCA_TRADE_ADDRESS environment variable must be set"
    );

    // Get SuperDCACashback contract address from environment variable
    address superDCACashbackAddress =
      vm.envOr("SUPER_DCA_CASHBACK_ADDRESS", address(0x0000000000000000000000000000000000000000));
    require(
      superDCACashbackAddress != address(0),
      "SUPER_DCA_CASHBACK_ADDRESS environment variable must be set"
    );

    ISuperDCATrade superDCATrade = ISuperDCATrade(superDCATradeAddress);
    SuperDCACashback superDCACashback = SuperDCACashback(superDCACashbackAddress);

    // Get trade information
    ISuperDCATrade.Trade memory trade = superDCATrade.trades(tradeId);

    // Get cashback information
    (uint256 claimable, uint256 pending, uint256 claimed) = superDCACashback.getTradeStatus(tradeId);

    // Display trade status
    console2.log("=== Trade Status for Trade ID:", tradeId, "===");
    console2.log("Trade ID:", trade.tradeId);
    console2.log("Start Time:", trade.startTime);
    console2.log("End Time:", trade.endTime);
    console2.log("Flow Rate:", uint256(int256(trade.flowRate)));
    console2.log("Start IDA Index:", trade.startIdaIndex);
    console2.log("End IDA Index:", trade.endIdaIndex);
    console2.log("Units:", trade.units);
    console2.log("Refunded:", trade.refunded);

    // Determine trade status
    string memory status;
    if (trade.tradeId == 0) status = "TRADE NOT FOUND";
    else if (trade.endTime == 0) status = "ACTIVE";
    else status = "COMPLETED";
    console2.log("Status:", status);

    console2.log("");
    console2.log("=== Cashback Information ===");
    console2.log("Claimable Amount (USDC):", claimable);
    console2.log("Pending Amount (USDC):", pending);
    console2.log("Already Claimed (USDC):", claimed);
    console2.log("Total Potential (USDC):", claimable + pending + claimed);

    console2.log("===============================");
  }

  function getTradeStatusWithCashback(
    address superDCATradeAddress,
    address superDCACashbackAddress,
    uint256 tradeId
  )
    public
    view
    returns (
      ISuperDCATrade.Trade memory trade,
      string memory status,
      uint256 claimable,
      uint256 pending,
      uint256 claimed
    )
  {
    ISuperDCATrade superDCATrade = ISuperDCATrade(superDCATradeAddress);
    SuperDCACashback superDCACashback = SuperDCACashback(superDCACashbackAddress);

    trade = superDCATrade.trades(tradeId);
    (claimable, pending, claimed) = superDCACashback.getTradeStatus(tradeId);

    if (trade.tradeId == 0) status = "TRADE NOT FOUND";
    else if (trade.endTime == 0) status = "ACTIVE";
    else status = "COMPLETED";
  }

  function getTradeStatus(address superDCATradeAddress, uint256 tradeId)
    public
    view
    returns (ISuperDCATrade.Trade memory trade, string memory status)
  {
    ISuperDCATrade superDCATrade = ISuperDCATrade(superDCATradeAddress);
    trade = superDCATrade.trades(tradeId);

    if (trade.tradeId == 0) status = "TRADE NOT FOUND";
    else if (trade.endTime == 0) status = "ACTIVE";
    else status = "COMPLETED";
  }
}

// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.29;

interface ISuperDCATrade {
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

  event TradeStarted(address indexed trader, uint256 indexed tradeId);
  event TradeEnded(address indexed trader, uint256 indexed tradeId);

  function trades(uint256 tradeId) external view returns (Trade memory);
  function tradesByUser(address user, uint256 index) external view returns (uint256);
  function tradeCountsByUser(address user) external view returns (uint256);

  function startTrade(address _shareholder, int96 _flowRate, uint256 _indexValue, uint256 _units)
    external;
  function endTrade(address _shareholder, uint256 _indexValue, uint256 _refunded) external;
  function getLatestTrade(address _trader) external view returns (Trade memory trade);
  function getTradeInfo(address _trader, uint256 _index) external view returns (Trade memory trade);
}

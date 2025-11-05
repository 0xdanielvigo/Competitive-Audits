// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.29;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "./interfaces/ISuperDCATrade.sol";

/// @title SuperDCACashback
/// @notice A contract that distributes USDC cashback rewards to users of the Super DCA
/// trading protocol over time-based epochs.
//@audit-q, does the Ink blockchain implement all the ETH OPCODES?  
contract SuperDCACashback is AccessControl {
  using SafeERC20 for IERC20;

  /// @notice The USDC token used for cashback payments
  IERC20 public immutable USDC;

  /// @notice The SuperDCATrade contract interface
  ISuperDCATrade public immutable SUPER_DCA_TRADE;

  /// @notice Admin role identifier
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  /// @notice Struct representing a cashback claim
  struct CashbackClaim {
    uint256 cashbackBips; // Cashback percentage in basis points (e.g., 25 = 0.25%)
    uint256 duration; // Epoch duration in seconds
    int96 minRate; // Minimum flow rate for eligibility
    uint256 maxRate; // Maximum flow rate for eligibility
    uint256 startTime; // Start time of epoch 0
    uint256 timestamp; // When the claim was created
  }

  /// @notice The single cashback claim configuration for this contract
  CashbackClaim public cashbackClaim;

  /// @notice Mapping of tradeId to total claimed amount in USDC (6 decimals)
  mapping(uint256 tradeId => uint256 claimedAmount) public claimedAmounts;

  /// @notice Emitted when cashback is claimed
  event CashbackClaimed(address indexed user, uint256 indexed tradeId, uint256 amount);

  /// @notice Emitted when tokens are withdrawn by admin
  event TokensWithdrawn(address indexed token, address indexed to, uint256 amount);

  /// @notice Emitted when a parameter is invalid
  /// @param paramIndex The index of the invalid parameter
  error InvalidParams(uint256 paramIndex);

  /// @notice Emitted when a claim is not claimable
  error NotClaimable();

  /// @notice Emitted when a user is not authorized to claim cashback
  error NotAuthorized();

  /// @notice Constructor
  /// @param _usdc The USDC token contract address
  /// @param _superDCATrade The SuperDCATrade contract address
  /// @param _admin The initial admin address
  /// @param _cashbackClaim The cashback claim configuration
  constructor(
    address _usdc,
    address _superDCATrade,
    address _admin,
    CashbackClaim memory _cashbackClaim
  ) {
    // Validate parameters
    if (_cashbackClaim.cashbackBips > 10_000) revert InvalidParams(0); // Max 100%
    if (_cashbackClaim.maxRate > uint256(uint96(type(int96).max))) revert InvalidParams(2);
    if (_cashbackClaim.minRate >= int96(int256(_cashbackClaim.maxRate))) revert InvalidParams(2);
    if (_cashbackClaim.duration == 0) revert InvalidParams(1);

    USDC = IERC20(_usdc);
    SUPER_DCA_TRADE = ISuperDCATrade(_superDCATrade);
    cashbackClaim = _cashbackClaim;
    cashbackClaim.timestamp = block.timestamp;

    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(ADMIN_ROLE, _admin);
  }

  /// @notice Get trade cashback status showing claimable, pending, and claimed amounts
  /// @param tradeId The trade ID to check
  /// @return claimable Amount that can be claimed from completed epochs (USDC 6 decimals)
  /// @return pending Amount pending in the current incomplete epoch (USDC 6 decimals)
  /// @return claimed Amount already claimed for this trade (USDC 6 decimals)
  function getTradeStatus(uint256 tradeId)
    external
    view
    returns (uint256 claimable, uint256 pending, uint256 claimed)
  {
    ISuperDCATrade.Trade memory trade = SUPER_DCA_TRADE.trades(tradeId);

    // If trade doesn't exist or doesn't meet requirements, return zeros
    if (!_isTradeValid(trade)) return (0, 0, 0);

    claimed = claimedAmounts[tradeId];

    // Calculate epoch timing data
    (uint256 completedEpochs, uint256 incompleteEpochTime) = _calculateEpochData(trade);
    if (completedEpochs == 0 && incompleteEpochTime == 0) return (0, 0, claimed);

    // Get effective flow rate (capped at maxRate)
    uint256 effectiveFlowRate = _getEffectiveFlowRate(trade.flowRate);

    // Calculate claimable amount from completed epochs
    uint256 totalCompletedAmount =
      _calculateCompletedEpochsCashback(trade, effectiveFlowRate, completedEpochs);

    if (totalCompletedAmount > claimed) claimable = totalCompletedAmount - claimed;

    // Calculate pending amount from incomplete epoch
    pending = _calculatePendingCashback(trade, effectiveFlowRate, incompleteEpochTime);
  }

  /// @notice Internal version of getTradeStatus to avoid external call overhead
  /// @param tradeId The trade ID to check
  /// @param trade The trade data (fetched externally to avoid double SLOAD)
  function _getTradeStatusInternal(uint256 tradeId, ISuperDCATrade.Trade memory trade)
    internal
    view
    returns (uint256 claimable, uint256 pending, uint256 claimed)
  {
    // If trade doesn't exist or doesn't meet requirements, return zeros
    if (!_isTradeValid(trade)) return (0, 0, 0);

    claimed = claimedAmounts[tradeId];

    // Calculate epoch timing data
    (uint256 completedEpochs, uint256 incompleteEpochTime) = _calculateEpochData(trade);

    if (completedEpochs == 0 && incompleteEpochTime == 0) return (0, 0, claimed);

    // Get effective flow rate (capped at maxRate)
    uint256 effectiveFlowRate = _getEffectiveFlowRate(trade.flowRate);

    // Calculate claimable amount from completed epochs
    uint256 totalCompletedAmount =
      _calculateCompletedEpochsCashback(trade, effectiveFlowRate, completedEpochs);

    if (totalCompletedAmount > claimed) claimable = totalCompletedAmount - claimed;

    // Calculate pending amount from incomplete epoch
    pending = _calculatePendingCashback(trade, effectiveFlowRate, incompleteEpochTime);
  }

  /// @notice Check if trade is valid for cashback calculations
  /// @param trade The trade data
  /// @return valid True if trade meets all requirements
  function _isTradeValid(ISuperDCATrade.Trade memory trade) internal view returns (bool valid) {
    return trade.startTime > 0 && trade.flowRate >= int96(cashbackClaim.minRate);
  }

  /// @notice Calculate epoch timing data for a trade
  /// @param trade The trade data
  /// @return completedEpochs Number of complete epochs
  /// @return incompleteEpochTime Time elapsed in current incomplete epoch
  function _calculateEpochData(ISuperDCATrade.Trade memory trade)
    internal
    view
    returns (uint256 completedEpochs, uint256 incompleteEpochTime)
  {
    uint256 currentTime = block.timestamp;
    if (currentTime <= trade.startTime) return (0, 0);

    uint256 timeElapsed = currentTime - trade.startTime;
    completedEpochs = timeElapsed / cashbackClaim.duration;
    incompleteEpochTime = timeElapsed % cashbackClaim.duration;
  }

  /// @notice Get effective flow rate capped at maximum rate
  /// @param flowRate The original flow rate
  /// @return effectiveFlowRate The capped flow rate
  function _getEffectiveFlowRate(int96 flowRate) internal view returns (uint256 effectiveFlowRate) {
    effectiveFlowRate = uint256(int256(flowRate));
    if (effectiveFlowRate > cashbackClaim.maxRate) effectiveFlowRate = cashbackClaim.maxRate;
  }

  /// @notice Convert an amount from 1e18 precision (flow rate) to 1e6 precision (USDC)
  /// @param amount The amount in 1e18 precision
  /// @return convertedAmount The amount converted to 1e6 precision
  function _convertToUSDCPrecision(uint256 amount) internal pure returns (uint256 convertedAmount) {
    convertedAmount = amount / 1e12;
  }


  /// @notice Calculate cashback from completed epochs. Only fully completed
  /// epochs are eligible for rewards. If a trade ends before an epoch is
  /// finished, that incomplete epoch at trade end is forfeited (not eligible for rewards).
  /// @param trade The trade data
  /// @param effectiveFlowRate The effective (capped) flow rate
  /// @param completedEpochs Number of completed epochs at the current block timestamp
  /// @return totalAmount Total cashback amount in USDC (6 decimals)
  function _calculateCompletedEpochsCashback(
    ISuperDCATrade.Trade memory trade,
    uint256 effectiveFlowRate,
    uint256 completedEpochs
  ) internal view returns (uint256 totalAmount) {
    if (completedEpochs == 0) return 0;

    // When the trade has already ended, cap the completedEpochs to the number
    // of epochs that fully elapsed before the end time. Any epoch that was
    // still in progress at the moment of `endTime` is not eligible.
    if (trade.endTime > 0) {
      uint256 tradeDuration = trade.endTime - trade.startTime;
      // Integer division intentionally truncates any partial epoch.
      // Only fully completed epochs before endTime are eligible for cashback.
      uint256 epochsBeforeEnd = tradeDuration / cashbackClaim.duration;
      if (epochsBeforeEnd < completedEpochs) completedEpochs = epochsBeforeEnd;
    }

    if (completedEpochs == 0) return 0;

    // Reward for all eligible completed epochs
    uint256 completedAmount = effectiveFlowRate * cashbackClaim.duration * completedEpochs;
    totalAmount = (completedAmount * cashbackClaim.cashbackBips) / 10_000;

    // Convert from 1e18 precision (flow rate) to 1e6 precision (USDC)
    totalAmount = _convertToUSDCPrecision(totalAmount);
  }

  /// @notice Calculate pending cashback from incomplete epoch
  /// @param trade The trade data
  /// @param effectiveFlowRate The effective flow rate
  /// @param incompleteEpochTime Time elapsed in incomplete epoch
  /// @return pending Pending cashback amount in USDC (6 decimals)
  function _calculatePendingCashback(
    ISuperDCATrade.Trade memory trade,
    uint256 effectiveFlowRate,
    uint256 incompleteEpochTime
  ) internal view returns (uint256 pending) {
    // Only calculate pending if trade is still active and there's incomplete time
    if ((trade.endTime == 0 || trade.endTime > block.timestamp) && incompleteEpochTime > 0) {
      uint256 pendingAmount = effectiveFlowRate * incompleteEpochTime;
      pending = (pendingAmount * cashbackClaim.cashbackBips) / 10_000;
      pending = _convertToUSDCPrecision(pending); // Convert to USDC precision
    }
  }

  /// @notice Claim all available cashback for a trade
  /// @param tradeId The trade ID to claim cashback for
  /// @return totalCashback The total amount of cashback claimed
  function claimAllCashback(uint256 tradeId) external returns (uint256 totalCashback) {
    // Get trade information
    ISuperDCATrade.Trade memory trade = SUPER_DCA_TRADE.trades(tradeId);

    // Verify trade exists
    if (trade.startTime == 0) revert NotClaimable();

    // Verify the caller owns this trade
    address tradeOwner = _getTradeOwner(tradeId);
    if (tradeOwner != msg.sender) revert NotAuthorized();

    // Get claimable amount using the same logic as getTradeStatus
    (uint256 claimable,,) = _getTradeStatusInternal(tradeId, trade);

    // If no claimable amount, revert
    if (claimable == 0) revert NotClaimable();

    totalCashback = claimable;

    // Update claimed amount tracking
    claimedAmounts[tradeId] += totalCashback;

    // Transfer cashback to user
    USDC.safeTransfer(msg.sender, totalCashback);
    //@audit-informational, CEI not followed
    // Emit event for the claim
    emit CashbackClaimed(msg.sender, tradeId, totalCashback);
  }

  /// @notice Get information about the cashback claim configuration
  /// @return claim The cashback claim information
  function getCashbackClaim() external view returns (CashbackClaim memory claim) {
    claim = cashbackClaim;
  }

  /// @notice Withdraw any ERC20 token from the contract
  /// @param token The token contract address to withdraw
  /// @param to The address to send the tokens to
  /// @param amount The amount of tokens to withdraw
  function withdrawTokens(address token, address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
    if (to == address(0)) revert InvalidParams(1);
    if (amount == 0) revert InvalidParams(2);

    IERC20(token).safeTransfer(to, amount);
    //@audit-informational, CEI not followed
    emit TokensWithdrawn(token, to, amount);
  }

  /// @notice Internal function to get the owner of a trade
  /// @param tradeId The trade ID
  /// @return owner The owner address
  function _getTradeOwner(uint256 tradeId) internal view returns (address owner) {
    // Assuming SuperDCATrade is an ERC721 contract where trades are NFTs
    // We'll need to use a try-catch in case the interface doesn't support ownerOf
    try IERC721(address(SUPER_DCA_TRADE)).ownerOf(tradeId) returns (address _owner) {
      return _owner;
    } catch {
      // If ownerOf fails, we could implement alternative logic
      // For now, we'll revert to indicate the trade ownership couldn't be determined
      revert NotAuthorized();
    }
  }
}

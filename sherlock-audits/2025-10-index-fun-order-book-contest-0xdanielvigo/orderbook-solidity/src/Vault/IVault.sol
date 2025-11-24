// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IVault
 * @notice Interface for collateral management in prediction markets
 */
interface IVault {
    /// @notice Emitted when user deposits collateral to their account
    event CollateralDeposited(address indexed user, uint256 amount);

    /// @notice Emitted when user withdraws available collateral
    event CollateralWithdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when collateral is locked for a specific condition
    event CollateralLocked(bytes32 indexed conditionId, address indexed user, uint256 amount);

    /// @notice Emitted when collateral is unlocked from a resolved condition
    event CollateralUnlocked(bytes32 indexed conditionId, address indexed user, uint256 amount);

    /// @notice Emitted when multiple collateral locks are processed in batch
    event BatchCollateralLocked(bytes32[] conditionIds, address[] users, uint256[] amounts);

    /// @notice Emitted when multiple collateral unlocks are processed in batch
    event BatchCollateralUnlocked(bytes32[] conditionIds, address[] users, uint256[] amounts);
    
    /// @notice Emitted when collateral is transferred between users during token swaps
    event CollateralTransferred(bytes32 indexed conditionId, address indexed from, address indexed to, uint256 amount);

    /**
     * @notice Deposits ERC20 collateral tokens into user's available balance
     * @param amount Number of collateral tokens to deposit
     * @dev Requires prior ERC20 approval for vault contract
     */
    function depositCollateral(uint256 amount) external;

    /**
     * @notice Withdraws available collateral tokens to user's wallet
     * @param amount Number of tokens to withdraw
     * @dev Only withdraws from unlocked balance, reverts on insufficient funds
     */
    function withdrawCollateral(uint256 amount) external;

    /**
     * @notice Locks user's available collateral for position token minting
     * @param conditionId Market condition identifier
     * @param user Address whose collateral to lock
     * @param amount Collateral amount to lock
     * @dev Called by MarketController contract during position creation
     */
    function lockCollateral(bytes32 conditionId, address user, uint256 amount) external;

    /**
     * @notice Unlocks collateral from resolved condition to user's available balance
     * @param conditionId Resolved condition identifier
     * @param user User redeeming position tokens
     * @param amount Payout amount determined by market resolution
     * @dev Called by MarketController contract after successful claim verification
     */
    function unlockCollateral(bytes32 conditionId, address user, uint256 amount) external;

    /**
     * @notice Transfers collateral between users' vault balances (for token swaps)
     * @param conditionId Market condition identifier for tracking
     * @param from User sending collateral
     * @param to User receiving collateral
     * @param amount Amount to transfer
     * @dev Called by MarketController during token swap settlements
     */
    function transferBetweenUsers(bytes32 conditionId, address from, address to, uint256 amount) external;

    /**
     * @notice Locks collateral for multiple conditions in a single transaction
     * @param conditionIds Array of market condition identifiers
     * @param users Array of addresses whose collateral to lock
     * @param amounts Array of collateral amounts to lock
     * @dev Arrays must have equal length, called by MarketController for batch operations
     */
    function batchLockCollateral(bytes32[] calldata conditionIds, address[] calldata users, uint256[] calldata amounts)
        external;

    /**
     * @notice Unlocks collateral from multiple resolved conditions in a single transaction
     * @param conditionIds Array of resolved condition identifiers
     * @param users Array of users redeeming position tokens
     * @param amounts Array of payout amounts determined by market resolution
     * @dev Arrays must have equal length, called by MarketController for batch operations
     */
    function batchUnlockCollateral(
        bytes32[] calldata conditionIds,
        address[] calldata users,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice Returns user's available collateral balance
     * @param user Address to query
     * @return Available balance for withdrawal or position creation
     */
    function getAvailableBalance(address user) external view returns (uint256);

    /**
     * @notice Returns total locked collateral for specific condition
     * @param conditionId Condition identifier
     * @return Total locked amount across all participants
     */
    function getTotalLocked(bytes32 conditionId) external view returns (uint256);

    /**
     * @notice Updates authorized MarketController contract address
     * @param _contract New authorized contract address
     * @dev Only callable by contract owner
     */
    function setMarketController(address _contract) external;

    /**
     * @notice Sets contract pause state for emergency situations
     * @param _paused Pause state boolean
     * @dev Only callable by contract owner, affects user-facing operations
     */
    function setPaused(bool _paused) external;

    /**
     * @notice Returns the authorized MarketController address
     * @return Address of the MarketController contract
     */
    function marketController() external view returns (address);

    /**
     * @notice Returns whether the contract is currently paused
     * @return True if contract operations are paused
     */
    function paused() external view returns (bool);
}

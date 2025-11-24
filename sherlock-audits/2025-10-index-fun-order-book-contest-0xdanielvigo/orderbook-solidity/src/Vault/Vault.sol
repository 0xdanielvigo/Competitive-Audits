// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./IVault.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Vault
 * @notice Upgradeable version managing collateral deposits, withdrawals, and position funding for conditional token markets
 * @dev Handles ERC20 collateral for prediction market positions across multiple conditions with UUPS upgradeability
 */
contract Vault is Initializable, UUPSUpgradeable, IVault, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice The ERC20 token used as collateral for all positions
    IERC20 public collateralToken;

    /// @notice Address of the MarketController contract authorized to lock/unlock funds
    address public marketController;

    /// @notice Available collateral balance per user address
    mapping(address => uint256) private userBalances;

    /// @notice Total collateral locked per condition ID (market + epoch combination)
    mapping(bytes32 => uint256) private totalLockedPerCondition;

    /// @notice Emergency pause state for contract operations
    bool public paused;

    /// @dev Gap for future storage variables - increased by 1 to account for removed mapping
    uint256[44] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable contract
     * @param _initialOwner Initial owner of the contract
     * @param _collateralToken ERC20 token address for collateral
     * @param _marketController Address authorized to lock/unlock collateral
     */
    function initialize(address _initialOwner, address _collateralToken, address _marketController)
        public
        initializer
    {
        require(_collateralToken != address(0), "Invalid collateral token");
        require(_marketController != address(0), "Invalid market controller");

        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        collateralToken = IERC20(_collateralToken);
        marketController = _marketController;
    }

    /// @dev Restricts function access to the MarketController contract only
    modifier onlyMarketController() {
        require(msg.sender == marketController, "Unauthorized caller");
        _;
    }

    /// @dev Prevents function execution when contract is paused
    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    /**
     * @notice Authorizes contract upgrades
     * @param newImplementation Address of the new implementation
     * @dev Only callable by contract owner
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============ Contract Management Functions ============

    /**
     * @notice Updates the collateral token address
     * @param _collateralToken New collateral token address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateCollateralToken(address _collateralToken) external onlyOwner {
        require(_collateralToken != address(0), "Invalid collateral token");
        collateralToken = IERC20(_collateralToken);
    }

    /**
     * @notice Updates the market controller address
     * @param _marketController New market controller address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateMarketController(address _marketController) external onlyOwner {
        require(_marketController != address(0), "Invalid market controller");
        marketController = _marketController;
    }

    /**
     * @notice Deposits ERC20 collateral tokens into user's available balance
     * @param amount Number of collateral tokens to deposit
     * @dev Requires prior ERC20 approval for vault contract
     */
    function depositCollateral(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");

        collateralToken.safeTransferFrom(_msgSender(), address(this), amount);
        userBalances[_msgSender()] += amount;

        emit CollateralDeposited(_msgSender(), amount);
    }

    /**
     * @notice Withdraws available collateral tokens to user's wallet
     * @param amount Number of tokens to withdraw
     * @dev Only withdraws from unlocked balance, reverts on insufficient funds
     */
    function withdrawCollateral(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(userBalances[_msgSender()] >= amount, "Insufficient balance");

        userBalances[_msgSender()] -= amount;
        collateralToken.safeTransfer(_msgSender(), amount);

        emit CollateralWithdrawn(_msgSender(), amount);
    }

    /**
     * @notice Locks user's available collateral for position token minting
     * @param conditionId Market condition identifier
     * @param user Address whose collateral to lock
     * @param amount Collateral amount to lock
     * @dev Called by MarketController contract during position creation
     */
    function lockCollateral(bytes32 conditionId, address user, uint256 amount)
        external
        onlyMarketController
        nonReentrant
    {
        require(userBalances[user] >= amount, "Insufficient balance");

        userBalances[user] -= amount;
        totalLockedPerCondition[conditionId] += amount;

        emit CollateralLocked(conditionId, user, amount);
    }

    /**
     * @notice Unlocks collateral from resolved condition to user's available balance
     * @param conditionId Resolved condition identifier
     * @param user User redeeming position tokens
     * @param amount Payout amount determined by market resolution
     * @dev Called by MarketController contract after successful claim verification
     * @dev Allows unlocking to any user for proper market payout distribution
     */
    function unlockCollateral(bytes32 conditionId, address user, uint256 amount)
        external
        onlyMarketController
        nonReentrant
    {
        require(totalLockedPerCondition[conditionId] >= amount, "Invalid unlock amount");

        totalLockedPerCondition[conditionId] -= amount;
        userBalances[user] += amount;

        emit CollateralUnlocked(conditionId, user, amount);
    }

    /**
     * @notice Transfers collateral between users' vault balances (for token swaps)
     * @param conditionId Market condition identifier for tracking
     * @param from User sending collateral
     * @param to User receiving collateral
     * @param amount Amount to transfer
     * @dev Called by MarketController during token swap settlements
     */
    function transferBetweenUsers(bytes32 conditionId, address from, address to, uint256 amount)
        external
        onlyMarketController
        nonReentrant
    {
        require(userBalances[from] >= amount, "Insufficient balance");
        require(to != address(0), "Invalid recipient");

        userBalances[from] -= amount;
        userBalances[to] += amount;

        emit CollateralTransferred(conditionId, from, to, amount);
    }

    /**
     * @notice Locks collateral for multiple conditions in a single transaction
     * @param conditionIds Array of market condition identifiers
     * @param users Array of addresses whose collateral to lock
     * @param amounts Array of collateral amounts to lock
     * @dev Arrays must have equal length, called by MarketController for batch operations
     */
    function batchLockCollateral(bytes32[] calldata conditionIds, address[] calldata users, uint256[] calldata amounts)
        external
        onlyMarketController
        nonReentrant
    {
        require(conditionIds.length == users.length && users.length == amounts.length, "Array length mismatch");

        for (uint256 i = 0; i < conditionIds.length; i++) {
            require(userBalances[users[i]] >= amounts[i], "Insufficient balance");

            userBalances[users[i]] -= amounts[i];
            totalLockedPerCondition[conditionIds[i]] += amounts[i];

            emit CollateralLocked(conditionIds[i], users[i], amounts[i]);
        }
    }

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
    ) external onlyMarketController nonReentrant {
        require(conditionIds.length == users.length && users.length == amounts.length, "Array length mismatch");

        for (uint256 i = 0; i < conditionIds.length; i++) {
            require(totalLockedPerCondition[conditionIds[i]] >= amounts[i], "Invalid unlock amount");

            totalLockedPerCondition[conditionIds[i]] -= amounts[i];
            userBalances[users[i]] += amounts[i];

            emit CollateralUnlocked(conditionIds[i], users[i], amounts[i]);
        }
    }

    /**
     * @notice Returns user's available collateral balance
     * @param user Address to query
     * @return Available balance for withdrawal or position creation
     */
    function getAvailableBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }

    /**
     * @notice Returns total locked collateral for specific condition
     * @param conditionId Condition identifier
     * @return Total locked amount across all participants
     */
    function getTotalLocked(bytes32 conditionId) external view returns (uint256) {
        return totalLockedPerCondition[conditionId];
    }

    /**
     * @notice Updates authorized MarketController contract address
     * @param _contract New authorized contract address
     * @dev Only callable by contract owner
     */
    function setMarketController(address _contract) external onlyOwner {
        require(_contract != address(0), "Invalid address");
        marketController = _contract;
    }

    /**
     * @notice Sets contract pause state for emergency situations
     * @param _paused Pause state boolean
     * @dev Only callable by contract owner, affects user-facing operations
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
}

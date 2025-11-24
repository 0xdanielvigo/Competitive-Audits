// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IMarketController
 * @notice Interface for orderbook-based market operations with EIP-712 order matching
 */
interface IMarketController {
    // Order structure for EIP-712
    struct Order {
        address user;           // User placing the order
        bytes32 questionId;     // Market question ID
        uint256 outcome;        // Specific outcome (1, 2, 4, 8, etc.)
        uint256 amount;         // Amount of tokens
        uint256 price;          // Price per token (in basis points, 10000 = 100%)
        uint256 nonce;          // Unique nonce for replay protection
        uint256 expiration;     // Order expiration timestamp
        bool isBuyOrder;        // true = buy, false = sell
    }

    // Batch claim structure
    struct ClaimRequest {
        bytes32 questionId;     // Market question ID
        uint256 epoch;          // Specific epoch for the claim
        uint256 outcome;        // Winning outcome being claimed
        bytes32[] merkleProof;  // Proof of winning outcome
    }

    /// @notice Emitted when user claims winnings from resolved market
    event WinningsClaimed(
        address indexed user, bytes32 indexed questionId, uint256 epoch, uint256 outcome, uint256 payout
    );

    /// @notice Emitted when user claims winnings from multiple markets in batch
    event BatchWinningsClaimed(
        address indexed user, uint256 totalPayout, uint256 claimsProcessed
    );

    /// @notice Emitted when emergency resolution is triggered
    event EmergencyResolution(bytes32 indexed questionId, uint256 indexed epoch, bytes32 merkleRoot);

    /// @notice Emitted when global trading pause state changes
    event GlobalTradingPauseChanged(bool paused);

    /// @notice Emitted when market-specific trading pause state changes
    event MarketTradingPauseChanged(bytes32 indexed questionId, bool paused);

    /// @notice Emitted when multiple markets' trading pause state changes
    event BatchMarketTradingPauseChanged(bytes32[] questionIds, bool paused);

    /// @notice Emitted when an order is filled
    event OrderFilled(
        bytes32 indexed orderHash,
        address indexed user,           // User who placed the order
        bytes32 indexed questionId,     // Market question ID
        uint256 outcome,                // Outcome being traded
        uint256 fillAmount,             // Amount filled
        uint256 price,                  // Execution price
        bool isBuyOrder,                // Order direction
        uint256 epoch,                  // Market epoch
        address taker                   // Address that matched/took the order
    );

    /// @notice Emitted when an order is cancelled
    event OrderCancelled(bytes32 indexed orderHash, address indexed user);

    /// @notice Emitted when fee is collected on winnings
    event FeeCollected(address indexed user, bytes32 indexed questionId, uint256 feeAmount, uint256 netPayout);

    /// @notice Emitted when default fee rate is updated
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);

    /// @notice Emitted when treasury address is updated
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when custom user fee rate is set
    event UserFeeRateSet(address indexed user, uint256 feeRate);

    /// @notice Emitted when trade fee is collected
    event TradeFeeCollected(
        address indexed user,
        bytes32 indexed questionId,
        uint256 feeAmount,
        uint256 netAmount
    );

    /// @notice Emitted when trade fee rate is updated
    event TradeFeeRateUpdated(uint256 oldRate, uint256 newRate);

    /// @notice Emitted when custom user trade fee rate is set
    event UserTradeFeeRateSet(address indexed user, uint256 feeRate);

    // ============ Trading Hours Control Functions ============

    /**
     * @notice Sets global trading pause state (emergency stop)
     * @param paused True to pause all trading, false to resume
     * @dev Only callable by contract owner, affects all markets
     */
    function setGlobalTradingPaused(bool paused) external;

    /**
     * @notice Sets trading pause state for specific market
     * @param questionId Market question identifier
     * @param paused True to pause trading, false to resume
     * @dev Only callable by contract owner, for trading hours control
     */
    function setMarketTradingPaused(bytes32 questionId, bool paused) external;

    /**
     * @notice Sets trading pause state for multiple markets (batch operation)
     * @param questionIds Array of market question identifiers
     * @param paused True to pause trading, false to resume
     * @dev Only callable by contract owner, gas-efficient for bulk updates
     */
    function batchSetMarketTradingPaused(bytes32[] calldata questionIds, bool paused) external;

    /**
     * @notice Checks if trading is active for a specific market
     * @param questionId Market question identifier
     * @return True if trading is active (not paused globally or for this market)
     */
    function isTradingActive(bytes32 questionId) external view returns (bool);

    /**
     * @notice Returns global trading pause state
     * @return True if all trading is paused
     */
    function globalTradingPaused() external view returns (bool);

    /**
     * @notice Returns market-specific trading pause state
     * @param questionId Market question identifier
     * @return True if trading is paused for this market
     */
    function marketTradingPaused(bytes32 questionId) external view returns (bool);

    // ============ Market Management Functions ============

    /**
     * @notice Creates a new prediction market with optional time-based resolution
     * @param questionId Unique market question identifier
     * @param outcomeCount Number of possible outcomes for this market
     * @param resolutionTime Timestamp when market should resolve (0 for manual resolution)
     * @param epochDuration Duration of each epoch in seconds (0 for manual epoch advancement)
     * @dev Only callable by contract owner
     * @dev For continuous markets, set resolutionTime=0 and epochDuration>0 (e.g., 86400 for daily)
     */
    function createMarket(bytes32 questionId, uint256 outcomeCount, uint256 resolutionTime, uint256 epochDuration) external;

    /**
     * @notice Updates resolution time for existing market
     * @param questionId Market question identifier
     * @param resolutionTime New resolution timestamp (0 for manual resolution)
     * @dev Only callable by contract owner, only before current resolution time
     */
    function updateMarketResolutionTime(bytes32 questionId, uint256 resolutionTime) external;

    /**
     * @notice Advances market to next epoch for continuous markets
     * @param questionId Market question identifier
     * @dev Only callable by contract owner
     * @dev Only works for manual epoch markets (epochDuration = 0)
     */
    function advanceMarketEpoch(bytes32 questionId) external;

    // ============ Order Matching Functions ============

    /**
     * @notice Executes a trade using EIP-712 signed orders
     * @param buyOrder The buy order details
     * @param sellOrder The sell order details
     * @param buySignature The buyer's signature
     * @param sellSignature The seller's signature
     * @param fillAmount Amount to fill (must not exceed either order)
     */
    function executeOrderMatch(
        Order calldata buyOrder,
        Order calldata sellOrder,
        bytes calldata buySignature,
        bytes calldata sellSignature,
        uint256 fillAmount
    ) external;

    /**
     * @notice Executes a single signed order against matcher's liquidity
     * @param order The order to execute
     * @param signature The user's signature
     * @param fillAmount Amount to fill
     * @param counterparty Address providing liquidity (authorized matcher)
     */
    function executeSingleOrder(
        Order calldata order,
        bytes calldata signature,
        uint256 fillAmount,
        address counterparty
    ) external;

    /**
     * @notice Allows users to cancel their own orders
     * @param order The order to cancel
     * @param signature The user's signature (for verification)
     */
    function cancelOrder(Order calldata order, bytes calldata signature) external;

    /**
     * @notice Emergency function to resolve markets that have passed their resolution time
     * @param questionId Market question identifier
     * @param numberOfOutcomes Number of possible outcomes for validation
     * @param merkleRoot Root hash of merkle tree containing valid outcomes
     * @dev Can only be called after resolution time has passed, provides fallback resolution
     */
    function emergencyResolveMarket(bytes32 questionId, uint256 numberOfOutcomes, bytes32 merkleRoot) external;

    /**
     * @notice Sets authorization status for off-chain matching systems
     * @param matcher Address of the matching system
     * @param authorized Whether the matcher is authorized
     * @dev Only callable by contract owner
     */
    function setAuthorizedMatcher(address matcher, bool authorized) external;

    /**
     * @notice Claims winnings from resolved market
     * @param questionId Market question identifier
     * @param epoch Specific epoch for the claim
     * @param outcome Winning outcome being claimed
     * @param merkleProof Proof of winning outcome
     * @return Payout amount transferred to user (after fees)
     */
    function claimWinnings(bytes32 questionId, uint256 epoch, uint256 outcome, bytes32[] calldata merkleProof)
        external
        returns (uint256);

    /**
     * @notice Claims winnings from multiple resolved markets in a single transaction
     * @param claims Array of claim requests for different markets/epochs
     * @return totalPayout Total payout amount transferred to user across all claims (after fees)
     * @dev Processes all valid claims and skips invalid ones, enabling users to claim all winnings efficiently
     */
    function batchClaimWinnings(ClaimRequest[] calldata claims)
        external
        returns (uint256 totalPayout);

    // ============ Fee Management Functions ============

    /**
     * @notice Sets the default fee rate for winnings claims
     * @param _feeRate Fee rate in basis points (e.g., 400 = 4%)
     * @dev Only callable by contract owner, maximum 10000 basis points (100%)
     */
    function setFeeRate(uint256 _feeRate) external;

    /**
     * @notice Sets the treasury address where fees are sent
     * @param _treasury Address of the treasury
     * @dev Only callable by contract owner
     */
    function setTreasury(address _treasury) external;

    /**
     * @notice Sets a custom fee rate for specific user (fee tier system)
     * @param user Address of the user
     * @param _feeRate Custom fee rate in basis points (0 = use default rate)
     * @dev Only callable by contract owner, allows preferential rates for MMs/whales
     */
    function setUserFeeRate(address user, uint256 _feeRate) external;

    /**
     * @notice Gets the effective fee rate for a user
     * @param user Address of the user
     * @return Fee rate in basis points that will be applied to this user
     */
    function getEffectiveFeeRate(address user) external view returns (uint256);

    /**
     * @notice Returns the default fee rate
     * @return Fee rate in basis points
     */
    function feeRate() external view returns (uint256);

    /**
     * @notice Returns the treasury address
     * @return Address of the treasury
     */
    function treasury() external view returns (address);

    /**
     * @notice Returns custom fee rate for a user
     * @param user Address of the user
     * @return Custom fee rate (0 if using default)
     */
    function userFeeRate(address user) external view returns (uint256);

    // ============ Order Query Functions ============

    /**
     * @notice Get the EIP-712 hash for an order
     */
    function getOrderHash(Order calldata order) external view returns (bytes32);

    /**
     * @notice Check how much of an order has been filled
     */
    function getOrderFillAmount(bytes32 orderHash) external view returns (uint256);

    /**
     * @notice Check remaining amount for an order
     */
    function getOrderRemainingAmount(Order calldata order) external view returns (uint256);

    /**
     * @notice Checks if address is authorized to execute matching operations
     * @param matcher Address to check authorization for
     * @return True if matcher is authorized
     */
    function authorizedMatchers(address matcher) external view returns (bool);
}

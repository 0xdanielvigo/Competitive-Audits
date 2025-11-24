// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IMarketContract
 * @notice Interface for market metadata and configuration management
 */
interface IMarket {
    /// @notice Emitted when new market is created
    event MarketCreated(bytes32 indexed questionId, uint256 outcomeCount, uint256 initialEpoch, uint256 resolutionTime);

    /// @notice Emitted when market epoch is advanced
    event EpochAdvanced(bytes32 indexed questionId, uint256 previousEpoch, uint256 newEpoch);

    /// @notice Emitted when market resolution time is updated
    event ResolutionTimeUpdated(bytes32 indexed questionId, uint256 oldResolutionTime, uint256 newResolutionTime);

    /**
     * @notice Creates new market with specified outcomes and resolution time
     * @param questionId Unique market question identifier
     * @param outcomeCount Number of possible outcomes for this market
     * @param resolutionTime Timestamp when market should resolve (0 for manual resolution)
     * @param epochDuration Duration of each epoch in seconds (0 for manual epoch advancement)
     */
    function createMarket(bytes32 questionId, uint256 outcomeCount, uint256 resolutionTime, uint256 epochDuration)
        external;

    /**
     * @notice Updates resolution time for existing market
     * @param questionId Market question identifier
     * @param resolutionTime New resolution timestamp (0 for manual resolution)
     */
    function updateResolutionTime(bytes32 questionId, uint256 resolutionTime) external;

    /**
     * @notice Advances market to next epoch (manual mode only)
     * @param questionId Market question identifier
     */
    function advanceEpoch(bytes32 questionId) external;

    /**
     * @notice Checks if market is currently open for betting
     * @param questionId Market question identifier
     * @return True if market is open for betting
     */
    function isMarketOpen(bytes32 questionId) external view returns (bool);

    /**
     * @notice Checks if market is ready for resolution
     * @param questionId Market question identifier
     * @return True if market can be resolved
     */
    function isMarketReadyForResolution(bytes32 questionId) external view returns (bool);

    /**
     * @notice Gets resolution timestamp for market
     * @param questionId Market question identifier
     * @return Resolution timestamp (0 if manual resolution)
     */
    function getResolutionTime(bytes32 questionId) external view returns (uint256);

    /**
     * @notice Gets creation timestamp for market
     * @param questionId Market question identifier
     * @return Creation timestamp
     */
    function getCreationTime(bytes32 questionId) external view returns (uint256);

    /**
     * @notice Generates condition ID for market and epoch
     * @param oracle Oracle address
     * @param questionId Market question identifier
     * @param numberOfOutcomes Number of outcomes
     * @param epoch Specific epoch (0 for current)
     * @return Condition identifier
     */
    function getConditionId(address oracle, bytes32 questionId, uint256 numberOfOutcomes, uint256 epoch)
        external
        view
        returns (bytes32);

    /**
     * @notice Gets number of possible outcomes for market
     * @param questionId Market question identifier
     * @return Number of outcomes
     */
    function getOutcomeCount(bytes32 questionId) external view returns (uint256);

    /**
     * @notice Gets current epoch for market
     * @param questionId Market question identifier
     * @return Current epoch number
     */
    function getCurrentEpoch(bytes32 questionId) external view returns (uint256);

    /**
     * @notice Gets epoch duration for market
     * @param questionId Market question identifier
     * @return Epoch duration in seconds (0 if manual epochs)
     */
    function getEpochDuration(bytes32 questionId) external view returns (uint256);

    /**
     * @notice Gets the timestamp when a specific epoch starts
     * @param questionId Market question identifier
     * @param epoch The epoch number to query
     * @return Timestamp when the epoch starts (0 if manual epochs)
     */
    function getEpochStartTime(bytes32 questionId, uint256 epoch) external view returns (uint256);

    /**
     * @notice Gets the timestamp when a specific epoch ends
     * @param questionId Market question identifier
     * @param epoch The epoch number to query
     * @return Timestamp when the epoch ends (0 if manual epochs)
     */
    function getEpochEndTime(bytes32 questionId, uint256 epoch) external view returns (uint256);

    /**
     * @notice Checks if market exists
     * @param questionId Market question identifier
     * @return True if market exists
     */
    function getMarketExists(bytes32 questionId) external view returns (bool);

    /**
     * @notice Sets the authorized MarketController address
     * @param marketController Address of MarketController contract
     */
    function setMarketController(address marketController) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./IMarket.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title MarketContract
 * @notice Upgradeable version of MarketContract - manages market metadata and configuration with restricted write access
 * @dev Only MarketController can modify market data, implements UUPS upgradeability
 */
contract MarketContract is IMarket, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /// @notice Maps question ID to number of possible outcomes
    mapping(bytes32 => uint256) private outcomeCount;

    /// @notice Maps question ID to current epoch number (only used for manual epoch markets)
    mapping(bytes32 => uint256) private currentEpoch;

    /// @notice Maps question ID to market creation status
    mapping(bytes32 => bool) private marketExists;

    /// @notice Maps question ID to resolution timestamp
    mapping(bytes32 => uint256) private resolutionTime;

    /// @notice Maps question ID to market creation timestamp
    mapping(bytes32 => uint256) private creationTime;

    /// @notice Address of authorized MarketController contract
    address public marketController;

    /// @notice Maps question ID to epoch duration in seconds (0 = manual epochs)
    mapping(bytes32 => uint256) private epochDuration;

    /// @notice Maps question ID to the timestamp when epoch 1 started
    mapping(bytes32 => uint256) private epochStartTime;

    /// @dev Gap for future storage variables
    uint256[42] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable contract
     * @param _initialOwner Initial owner of the contract
     */
    function initialize(address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
    }

    /// @dev Restricts function access only to authorized MarketController
    modifier onlyMarketController() {
        require(msg.sender == marketController, "Only MarketController can call this function");
        _;
    }

    /**
     * @notice Authorizes contract upgrades
     * @param newImplementation Address of the new implementation
     * @dev Only callable by contract owner
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Sets the authorized MarketController address
     * @param _marketController Address of MarketController contract
     * @dev Only callable by contract owner, establishes access control
     */
    function setMarketController(address _marketController) external onlyOwner {
        require(_marketController != address(0), "Invalid MarketController address");
        marketController = _marketController;
    }

    /**
     * @notice Creates new market with specified outcomes and resolution time
     * @param questionId Unique market question identifier
     * @param _outcomeCount Number of possible outcomes for this market
     * @param _resolutionTime Timestamp when market should resolve (0 for manual resolution)
     * @param _epochDuration Duration of each epoch in seconds (0 for manual epoch advancement)
     * @dev Only MarketController can create markets
     * @dev If epochDuration > 0, market uses time-based automatic epoch rolling
     * @dev If epochDuration = 0, market uses manual epoch advancement (legacy behavior)
     */
    function createMarket(
        bytes32 questionId,
        uint256 _outcomeCount,
        uint256 _resolutionTime,
        uint256 _epochDuration
    ) external onlyMarketController {
        require(questionId != bytes32(0), "Invalid question ID");
        require(_outcomeCount > 1, "Must have at least 2 outcomes");
        require(_outcomeCount <= 256, "Maximum 256 outcomes supported");
        require(!marketExists[questionId], "Market already exists");

        // If resolution time is set, it must be in the future
        if (_resolutionTime > 0) {
            require(_resolutionTime > block.timestamp, "Resolution time must be in the future");
        }

        outcomeCount[questionId] = _outcomeCount;
        currentEpoch[questionId] = 1; // Initial epoch for manual mode
        marketExists[questionId] = true;
        resolutionTime[questionId] = _resolutionTime;
        creationTime[questionId] = block.timestamp;
        epochDuration[questionId] = _epochDuration;
        
        if (_epochDuration > 0) {
            epochStartTime[questionId] = block.timestamp;
        }

        emit MarketCreated(questionId, _outcomeCount, 1, _resolutionTime);
    }

    /**
     * @notice Updates resolution time for existing market
     * @param questionId Market question identifier
     * @param _resolutionTime New resolution timestamp (0 for manual resolution)
     * @dev Only MarketController can update resolution time
     */
    function updateResolutionTime(bytes32 questionId, uint256 _resolutionTime) external onlyMarketController {
        require(marketExists[questionId], "Market does not exist");
        // If setting a new resolution time, it must be in the future
        if (_resolutionTime > 0) {
            require(_resolutionTime > block.timestamp, "Resolution time must be in the future");
        }

        uint256 oldResolutionTime = resolutionTime[questionId];
        resolutionTime[questionId] = _resolutionTime;

        emit ResolutionTimeUpdated(questionId, oldResolutionTime, _resolutionTime);
    }

    /**
     * @notice Advances market to next epoch (manual mode only)
     * @param questionId Market question identifier
     * @dev Only MarketController can advance epochs
     * @dev For time-based markets (epochDuration > 0), this function does nothing
     */
    function advanceEpoch(bytes32 questionId) external onlyMarketController {
        require(marketExists[questionId], "Market does not exist");
        require(epochDuration[questionId] == 0, "Cannot manually advance time-based epochs");

        uint256 previousEpoch = currentEpoch[questionId];
        currentEpoch[questionId] = previousEpoch + 1;

        emit EpochAdvanced(questionId, previousEpoch, currentEpoch[questionId]);
    }

    /**
     * @notice Checks if market is currently open for betting
     * @param questionId Market question identifier
     * @return True if market is open for betting
     * @dev Market is open if it exists and resolution time hasn't passed (or is 0 for manual)
     */
    function isMarketOpen(bytes32 questionId) external view returns (bool) {
        if (!marketExists[questionId]) {
            return false;
        }

        uint256 resolveTime = resolutionTime[questionId];
        // If resolution time is 0, market is manually resolved (always open until manually closed)
        // If resolution time is set, market is open until that time
        return resolveTime == 0 || block.timestamp < resolveTime;
    }

    /**
     * @notice Checks if market is ready for resolution
     * @param questionId Market question identifier
     * @return True if market can be resolved
     * @dev Market is ready for resolution if resolution time has passed (or is manual)
     */
    function isMarketReadyForResolution(bytes32 questionId) external view returns (bool) {
        if (!marketExists[questionId]) {
            return false;
        }

        uint256 resolveTime = resolutionTime[questionId];
        // If resolution time is 0, market can be resolved manually anytime
        // If resolution time is set, market can only be resolved after that time
        return resolveTime == 0 || block.timestamp >= resolveTime;
    }

    /**
     * @notice Gets resolution timestamp for market
     * @param questionId Market question identifier
     * @return Resolution timestamp (0 if manual resolution)
     */
    function getResolutionTime(bytes32 questionId) external view returns (uint256) {
        return resolutionTime[questionId];
    }

    /**
     * @notice Gets creation timestamp for market
     * @param questionId Market question identifier
     * @return Creation timestamp
     */
    function getCreationTime(bytes32 questionId) external view returns (uint256) {
        return creationTime[questionId];
    }

    /**
     * @notice Gets number of possible outcomes for market
     * @param questionId Market question identifier
     * @return Number of outcomes
     */
    function getOutcomeCount(bytes32 questionId) external view returns (uint256) {
        return outcomeCount[questionId];
    }

    /**
     * @notice Gets current epoch for market (time-based or manual)
     * @param questionId Market question identifier
     * @return Current epoch number
     * @dev For time-based markets (epochDuration > 0), calculates current epoch from time elapsed
     * @dev For manual markets (epochDuration = 0), returns stored epoch value
     */
    function getCurrentEpoch(bytes32 questionId) public view returns (uint256) {
        if (!marketExists[questionId]) {
            return 0;
        }

        uint256 duration = epochDuration[questionId];
        
        // Manual epoch mode (legacy behavior)
        if (duration == 0) {
            return currentEpoch[questionId];
        }

        // Time-based epoch mode (automatic rolling)
        uint256 elapsed = block.timestamp - epochStartTime[questionId];
        return 1 + (elapsed / duration);
    }

    /**
     * @notice Gets epoch duration for market
     * @param questionId Market question identifier
     * @return Epoch duration in seconds (0 if manual epochs)
     */
    function getEpochDuration(bytes32 questionId) external view returns (uint256) {
        return epochDuration[questionId];
    }

    /**
     * @notice Gets the timestamp when a specific epoch starts
     * @param questionId Market question identifier
     * @param epoch The epoch number to query
     * @return Timestamp when the epoch starts (0 if manual epochs)
     */
    function getEpochStartTime(bytes32 questionId, uint256 epoch) external view returns (uint256) {
        uint256 duration = epochDuration[questionId];
        if (duration == 0 || epoch == 0) {
            return 0;
        }
        return epochStartTime[questionId] + (duration * (epoch - 1));
    }

    /**
     * @notice Gets the timestamp when a specific epoch ends
     * @param questionId Market question identifier
     * @param epoch The epoch number to query
     * @return Timestamp when the epoch ends (0 if manual epochs)
     */
    function getEpochEndTime(bytes32 questionId, uint256 epoch) external view returns (uint256) {
        uint256 duration = epochDuration[questionId];
        if (duration == 0 || epoch == 0) {
            return 0;
        }
        return epochStartTime[questionId] + (duration * epoch);
    }

    /**
     * @notice Generates condition ID for market and epoch
     * @param oracle Oracle address
     * @param questionId Market question identifier
     * @param numberOfOutcomes Number of outcomes
     * @param epoch Specific epoch (0 for current)
     * @return Condition identifier
     * @dev Centralizes condition ID generation logic in market metadata layer
     */
    function getConditionId(address oracle, bytes32 questionId, uint256 numberOfOutcomes, uint256 epoch)
        external
        view
        returns (bytes32)
    {
        require(numberOfOutcomes <= 256, "Maximum 256 outcomes supported");
        uint256 targetEpoch = epoch == 0 ? getCurrentEpoch(questionId) : epoch;
        return keccak256(abi.encodePacked(oracle, questionId, numberOfOutcomes, targetEpoch));
    }

    /**
     * @notice Checks if market exists
     * @param questionId Market question identifier
     * @return True if market exists
     */
    function getMarketExists(bytes32 questionId) external view returns (bool) {
        return marketExists[questionId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./IMarketResolver.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title MarketResolver
 * @notice Upgradeable version handling market resolution and merkle proof verification for prediction markets
 * @dev Manages resolution data and validates outcome proofs independently of token mechanics with UUPS upgradeability
 */
contract MarketResolver is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IMarketResolver
{
    /// @notice Maps condition ID to merkle root for outcome verification
    mapping(bytes32 => bytes32) public resolutionMerkleRoots;

    /// @notice Tracks which conditions have been resolved to prevent re-resolution
    mapping(bytes32 => bool) public isResolved;

    /// @notice Address authorized to resolve markets
    address public oracle;

    /// @notice Address authorized for emergency resolution
    address public emergencyResolver;

    /// @dev Gap for future storage variables
    uint256[46] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable contract
     * @param _initialOwner Initial owner of the contract
     * @param _oracle Initial oracle address
     */
    function initialize(address _initialOwner, address _oracle) public initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        oracle = _oracle;
    }

    /// @dev Restricts function access to contract owner (oracle)
    modifier onlyOracle() {
        require(msg.sender == oracle, "Caller is not the oracle");
        _;
    }

    /// @dev Restricts emergency resolution to authorized emergency resolver
    modifier onlyEmergencyResolver() {
        require(msg.sender == emergencyResolver, "Caller is not emergency resolver");
        _;
    }

    /// @dev Allows both oracle and emergency resolver to resolve markets
    modifier onlyAuthorizedResolver() {
        require(msg.sender == oracle || msg.sender == emergencyResolver, "Not authorized to resolve");
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
     * @notice Updates the oracle address
     * @param _oracle New oracle address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        oracle = _oracle;
    }

    /**
     * @notice Updates the emergency resolver address
     * @param _emergencyResolver New emergency resolver address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateEmergencyResolver(address _emergencyResolver) external onlyOwner {
        require(_emergencyResolver != address(0), "Invalid emergency resolver address");
        emergencyResolver = _emergencyResolver;
    }

    /**
     * @notice Sets the authorized oracle address
     * @param _oracle Address of oracle for market resolution
     * @dev Only callable by contract owner
     */
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        oracle = _oracle;
    }

    /**
     * @notice Sets the authorized emergency resolver address
     * @param _emergencyResolver Address of emergency resolver (usually MarketController)
     * @dev Only callable by contract owner
     */
    function setEmergencyResolver(address _emergencyResolver) external onlyOwner {
        require(_emergencyResolver != address(0), "Invalid emergency resolver address");
        emergencyResolver = _emergencyResolver;
    }

    /**
     * @notice Resolves specific market epoch by setting merkle root
     * @param questionId Market question identifier
     * @param epoch Specific epoch to resolve
     * @param numberOfOutcomes Number of possible outcomes for validation
     * @param merkleRoot Root hash of merkle tree containing valid outcomes
     * @dev Oracle can resolve any epoch, enables flexible resolution timing
     */
     //@audit-low, Market can be resolved before its resolution time if this function is not called by the MarketController
    function resolveMarketEpoch(bytes32 questionId, uint256 epoch, uint256 numberOfOutcomes, bytes32 merkleRoot)
        public
        onlyAuthorizedResolver
        nonReentrant
    {
        _resolveMarketEpochInternal(questionId, epoch, numberOfOutcomes, merkleRoot);
    }

    /**
     * @notice Verifies if outcome won
     * @param conditionId Condition identifier
     * @param selectedOutcome Outcome being verified (1 or 2 for binary)
     * @param merkleProof Proof data for verification
     * @return True if outcome won
     */
    function verifyProof(bytes32 conditionId, uint256 selectedOutcome, bytes32[] calldata merkleProof)
        external
        view
        returns (bool)
    {
        bytes32 merkleRoot = resolutionMerkleRoots[conditionId];
        require(merkleRoot != bytes32(0), "Condition not resolved");

        bytes32 leaf = keccak256(abi.encodePacked(selectedOutcome));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    /**
     * @notice Gets merkle root for resolved condition
     * @param conditionId Condition identifier
     * @return Merkle root hash, zero if not resolved
     */
    function getResolutionRoot(bytes32 conditionId) external view returns (bytes32) {
        return resolutionMerkleRoots[conditionId];
    }

    /**
     * @notice Checks if condition has been resolved
     * @param conditionId Condition identifier
     * @return True if condition is resolved
     */
    function getResolutionStatus(bytes32 conditionId) external view returns (bool) {
        return isResolved[conditionId];
    }

    /**
     * @notice Generates condition ID for market resolution
     * @param oracleAddr Oracle address resolving the condition
     * @param questionId Market question identifier
     * @param numberOfOutcomes Number of possible outcomes
     * @param epoch Specific epoch for the condition
     * @return Unique condition identifier
     * @dev Matches condition ID generation used in other contracts
     */
    function getConditionId(address oracleAddr, bytes32 questionId, uint256 numberOfOutcomes, uint256 epoch)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(oracleAddr, questionId, numberOfOutcomes, epoch));
    }

    /**
     * @notice Batch resolves multiple market epochs for gas efficiency
     * @param questionIds Array of market question identifiers
     * @param epochs Array of epochs to resolve
     * @param numberOfOutcomes Array of outcome counts
     * @param merkleRoots Array of merkle roots
     * @dev Arrays must have equal length, enables efficient bulk resolution
     */
    function batchResolveMarkets(
        bytes32[] calldata questionIds,
        uint256[] calldata epochs,
        uint256[] calldata numberOfOutcomes,
        bytes32[] calldata merkleRoots
    ) external onlyAuthorizedResolver {
        require(
            questionIds.length == epochs.length && epochs.length == numberOfOutcomes.length
                && numberOfOutcomes.length == merkleRoots.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < questionIds.length; i++) {
            _resolveMarketEpochInternal(questionIds[i], epochs[i], numberOfOutcomes[i], merkleRoots[i]);
        }
    }

    /**
     * @notice Internal function for resolving market epoch without reentrancy guard
     * @param questionId Market question identifier
     * @param epoch Specific epoch to resolve
     * @param numberOfOutcomes Number of possible outcomes for validation
     * @param merkleRoot Root hash of merkle tree containing valid outcomes
     */
    function _resolveMarketEpochInternal(
        bytes32 questionId,
        uint256 epoch,
        uint256 numberOfOutcomes,
        bytes32 merkleRoot
    ) internal {
        require(epoch > 0, "Invalid epoch");
        require(numberOfOutcomes > 0, "Invalid outcome count");
        require(merkleRoot != bytes32(0), "Invalid merkle root");

        bytes32 conditionId = getConditionId(oracle, questionId, numberOfOutcomes, epoch);

        require(!isResolved[conditionId], "Already resolved");

        resolutionMerkleRoots[conditionId] = merkleRoot;
        isResolved[conditionId] = true;

        emit ConditionResolved(conditionId, questionId, epoch, merkleRoot);
    }
}

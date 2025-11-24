// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IMarketResolver
 * @notice Interface for market resolution and merkle proof verification
 */
interface IMarketResolver {
    /// @notice Emitted when market condition is resolved with merkle root
    event ConditionResolved(
        bytes32 indexed conditionId,
        bytes32 indexed questionId,
        uint256 indexed epoch,
        bytes32 merkleRoot
    );

    /**
     * @notice Resolves specific market epoch by setting merkle root
     * @param questionId Market question identifier
     * @param epoch Specific epoch to resolve
     * @param numberOfOutcomes Number of possible outcomes for validation
     * @param merkleRoot Root hash of merkle tree containing valid outcomes
     */
    function resolveMarketEpoch(bytes32 questionId, uint256 epoch, uint256 numberOfOutcomes, bytes32 merkleRoot)
        external;

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
        returns (bool);

    /**
     * @notice Gets merkle root for resolved condition
     * @param conditionId Condition identifier
     * @return Merkle root hash, zero if not resolved
     */
    function getResolutionRoot(bytes32 conditionId) external view returns (bytes32);

    /**
     * @notice Checks if condition has been resolved
     * @param conditionId Condition identifier
     * @return True if condition is resolved
     */
    function getResolutionStatus(bytes32 conditionId) external view returns (bool);

    /**
     * @notice Batch resolves multiple market epochs for gas efficiency
     * @param questionIds Array of market question identifiers
     * @param epochs Array of epochs to resolve
     * @param numberOfOutcomes Array of outcome counts
     * @param merkleRoots Array of merkle roots
     */
    function batchResolveMarkets(
        bytes32[] calldata questionIds,
        uint256[] calldata epochs,
        uint256[] calldata numberOfOutcomes,
        bytes32[] calldata merkleRoots
    ) external;

    /**
     * @notice Sets the authorized oracle address
     * @param oracle Address of oracle for market resolution
     */
    function setOracle(address oracle) external;

    /**
     * @notice Sets the authorized emergency resolver address
     * @param emergencyResolver Address of emergency resolver (usually MarketController)
     */
    function setEmergencyResolver(address emergencyResolver) external;

    /**
     * @notice Returns the current oracle address
     * @return Address of the oracle
     */
    function oracle() external view returns (address);

    /**
     * @notice Returns the current emergency resolver address
     * @return Address of the emergency resolver
     */
    function emergencyResolver() external view returns (address);
}

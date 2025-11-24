// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title IPositionTokens
 * @notice ERC1155 conditional tokens for prediction market positions
 * @dev Extends ERC1155 with prediction market specific functionality
 */
interface IPositionTokens is IERC1155 {
    /// @notice Emitted when position tokens are minted for market positions
    event PositionTokensMinted(address indexed to, uint256[] ids, uint256[] amounts, bytes32 indexed conditionId);

    /// @notice Emitted when position tokens are burned during settlement
    event PositionTokensBurned(address indexed from, uint256[] ids, uint256[] amounts, bytes32 indexed conditionId);

    /**
     * @notice Mints position tokens for specific condition and outcomes
     * @param to Address to mint tokens to
     * @param ids Array of token IDs to mint
     * @param amounts Array of amounts to mint for each ID
     * @dev Only callable by authorized MarketController contract
     */
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts) external;

    /**
     * @notice Burns position tokens from holder
     * @param from Address to burn tokens from
     * @param id Token ID to burn
     * @param amount Amount to burn
     * @dev Only callable by authorized MarketController contract
     */
    function burn(address from, uint256 id, uint256 amount) external;

    /**
     * @notice Burns multiple position token types from holder in single transaction
     * @param from Address to burn tokens from
     * @param ids Array of token IDs to burn
     * @param amounts Array of amounts to burn for each ID
     * @dev Only callable by authorized MarketController contract, more gas efficient for multiple burns
     */
    function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts) external;

    /**
     * @notice Generates unique token ID for condition and outcome combination
     * @param conditionId Condition identifier from market resolution system
     * @param selectedOutcome Outcome index representing specific market result
     * @return Unique token ID for the condition-outcome pair
     * @dev Token ID is deterministic hash of condition and outcome
     */
    function getTokenId(bytes32 conditionId, uint256 selectedOutcome) external pure returns (uint256);

    /**
     * @notice Sets the authorized MarketController contract address
     * @param marketController Address of MarketController contract
     * @dev Only callable by contract owner, establishes minting/burning permissions
     */
    function setMarketController(address marketController) external;

    /**
     * @notice Returns the authorized MarketController address
     * @return Address of the MarketController contract
     */
    function marketController() external view returns (address);
}

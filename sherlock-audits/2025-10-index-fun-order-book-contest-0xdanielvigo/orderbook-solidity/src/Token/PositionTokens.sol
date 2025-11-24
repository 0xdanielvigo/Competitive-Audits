// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPositionTokens} from "./IPositionTokens.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

/**
 * @title PositionTokens
 * @notice Upgradeable ERC1155 conditional tokens for prediction market positions
 * @dev Pure token operations without business logic with UUPS upgradeability
 */
contract PositionTokens is Initializable, UUPSUpgradeable, ERC1155Upgradeable, OwnableUpgradeable, IPositionTokens {
    /// @notice Address authorized to mint/burn tokens
    address public marketController;

    /// @dev Gap for future storage variables
    uint256[49] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable contract
     * @param _initialOwner Initial owner of the contract
     */
    function initialize(address _initialOwner) public initializer {
        __ERC1155_init("");
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
    }

    /// @dev Restricts function access to authorized market controller
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

    // ============ Contract Management Functions ============

    /**
     * @notice Updates the market controller address
     * @param _marketController New market controller address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateMarketController(address _marketController) external onlyOwner {
        require(_marketController != address(0), "Invalid MarketController address");
        marketController = _marketController;
    }

    /**
     * @notice Sets the authorized MarketController address
     * @param _marketController Address of MarketController contract
     * @dev Only callable by contract owner
     */
    function setMarketController(address _marketController) external onlyOwner {
        require(_marketController != address(0), "Invalid MarketController address");
        marketController = _marketController;
    }

    /**
     * @notice Mints position tokens for specific condition and outcomes
     * @param to Address to mint tokens to
     * @param ids Array of token IDs to mint
     * @param amounts Array of amounts to mint for each ID
     */
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts) external onlyMarketController {
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @notice Burns position tokens from holder
     * @param from Address to burn tokens from
     * @param id Token ID to burn
     * @param amount Amount to burn
     */
    function burn(address from, uint256 id, uint256 amount) external onlyMarketController {
        _burn(from, id, amount);
    }

    /**
     * @notice Burns multiple position token types from holder in single transaction
     * @param from Address to burn tokens from
     * @param ids Array of token IDs to burn
     * @param amounts Array of amounts to burn for each ID
     * @dev Only callable by authorized MarketController contract, more gas efficient for multiple burns
     */
    function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts)
        external
        onlyMarketController
    {
        _burnBatch(from, ids, amounts);
    }

    /**
     * @notice Generates unique token ID for condition and outcome
     * @param conditionId Condition identifier
     * @param selectedOutcome Outcome index
     * @return Unique token ID
     */
    function getTokenId(bytes32 conditionId, uint256 selectedOutcome) external pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(conditionId, selectedOutcome)));
    }
}

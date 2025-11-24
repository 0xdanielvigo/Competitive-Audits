// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestUSDC
 * @notice Mintable ERC20 token for prediction market testing
 * @dev USDC-like token with 6 decimals that can be minted for testing purposes
 */
contract TestUSDC is ERC20, Ownable {
    uint8 private constant DECIMALS = 6;
    
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {}
    
    /**
     * @notice Returns the number of decimals used by the token
     * @return Number of decimals (6, like USDC)
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
    
    /**
     * @notice Mints tokens to specified address
     * @param to Address to mint tokens to
     * @param amount Amount to mint (in token units, not wei)
     * @dev Only callable by contract owner
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    /**
     * @notice Mints tokens to multiple addresses in a single transaction
     * @param recipients Array of addresses to mint tokens to
     * @param amounts Array of amounts to mint to each address
     * @dev Arrays must have equal length, only callable by contract owner
     */
    function mintBatch(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Array length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }
    
    /**
     * @notice Burns tokens from caller's balance
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
    
    /**
     * @notice Burns tokens from specified address (requires allowance)
     * @param from Address to burn tokens from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external {
        _spendAllowance(from, _msgSender(), amount);
        _burn(from, amount);
    }
}

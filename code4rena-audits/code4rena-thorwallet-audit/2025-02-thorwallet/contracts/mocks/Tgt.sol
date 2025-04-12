// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ITokenReceiver {
    function onTokenTransfer(address from, uint256 amount, bytes calldata data) external;
}

contract Tgt is ERC20, Ownable {
    constructor(
        string memory _name,
        string memory _symbol,
        address _delegate,
        uint256 initialMintAmount
    ) ERC20(_name, _symbol) Ownable(_delegate) {
        _mint(_delegate, initialMintAmount);
    }

    /**
     * @notice Transfer tokens and call the recipient contract
     * @param to The recipient address
     * @param amount The amount of tokens to transfer
     * @param data Additional data to pass to the recipient
     */
    function transferAndCall(address to, uint256 amount, bytes calldata data) external returns (bool) {
        _transfer(_msgSender(), to, amount); // Transfer tokens

        if (isContract(to)) {
            ITokenReceiver(to).onTokenTransfer(_msgSender(), amount, data); // Callback to recipient
        }

        return true;
    }

    /**
     * @notice Helper function to check if an address is a contract
     * @param addr The address to check
     * @return True if the address is a contract, false otherwise
     */
    function isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}

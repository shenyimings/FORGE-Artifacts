// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20, ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

interface IAntisnipe {
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external;
}

/// @title LITLABGAMES ERC20 token
/// @notice ERC20 token with gasless and burn options
contract LitlabGamesToken is ERC20Permit, Ownable {
    IAntisnipe public antisnipe;
    bool public antisnipeDisable;

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from == address(0) || to == address(0)) return;
        if (!antisnipeDisable && address(antisnipe) != address(0))
            antisnipe.assureCanTransfer(msg.sender, from, to, amount);
    }

    /**
     * @dev Disables antisnipe one-way!!! (only owner)
     */
    function setAntisnipeDisable() external onlyOwner {
        require(!antisnipeDisable);
        antisnipeDisable = true;
    }

    /**
     * @dev Sets new antisnipe address (only owner)
     */
    function setAntisnipeAddress(address addr) external onlyOwner {
        antisnipe = IAntisnipe(addr);
    }

    /**
     * @dev Burns `amount` tokens from the caller’s balance.
     */
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    /**
     * @dev Initializes the contract, setting the token's name and symbol,
     * and mints total supply of token to the deployer.
     */
    constructor() ERC20('LitlabToken', 'LITT') ERC20Permit('LitlabToken') {
        _mint(msg.sender, 3_000_000_000 * 10 ** 18);
    }
}

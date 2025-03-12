// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC20, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "../utils/Ownable.sol";

interface IAntisnipe {
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external;
}

/// @title LITLABGAMES ERC20 token
/// @notice ERC20 token with:
///    - EIP721 permit gasless
///    - Burnable
///    - Antisnipping tools (gobit)
contract LitlabGamesToken is ERC20Permit, Ownable {
    IAntisnipe public antisnipe;
    bool public antisnipeDisable;
    uint256 private constant MINT_AMOUNT = 3_000_000_000 * 10 ** 18;

    event AntisnipeDisabled();

    constructor(address _antisnipe) ERC20("LitLabToken", "LITT") ERC20Permit("LitlabToken") {  
        _mint(msg.sender, MINT_AMOUNT);

        // Change the set to the constructor to ensure nobody can call setAntisnipeAddress more than once
        // with a malicious code to intercept the transfers.
        if (_antisnipe != address(0)) antisnipe = IAntisnipe(_antisnipe);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function disableAntisnipe() external onlyOwner {
        require(!antisnipeDisable, "ASDisabled");
        antisnipeDisable = true;

        // Burn the token ownership. Will never activate the antisnipe again.
        // Token is more safe because if owner key is hacked, someone can modify the IAntisnipe contract
        // and change for instance, change the "to" address of every transfer to another one to steal the token.
        // Better be sure that antisnipe is only active at the beginning for the listing and forget about it
        // burning the owner key and assuring nobody can activate it again
        _transferOwnership(address(0));

        emit AntisnipeDisabled();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from == address(0) || to == address(0)) return;
        if (!antisnipeDisable && address(antisnipe) != address(0))
            antisnipe.assureCanTransfer(msg.sender, from, to, amount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

/// @title BetSwirl's ERC20 token
/// @author Romuald Hog
contract BetsToken is ERC20, Ownable, Multicall {
    constructor() ERC20("BetSwirl Token", "BETS") {
        _mint(msg.sender, 7_777_777_777 ether);
    }

    /**
     * @dev This function is here to ensure BEP-20 compatibility
     */
    function getOwner() external view returns (address) {
        return owner();
    }
}

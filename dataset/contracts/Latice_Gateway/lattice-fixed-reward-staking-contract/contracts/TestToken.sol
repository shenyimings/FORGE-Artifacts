//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TestToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    uint8 public immutable tokendecimals;

    constructor(
        uint8 _decimals
    )
        ERC20(
            string.concat("TestToken", Strings.toString(_decimals)),
            string.concat("TT", Strings.toString(_decimals))
        )
        Ownable()
    {
        tokendecimals = _decimals;
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return tokendecimals;
    }
}

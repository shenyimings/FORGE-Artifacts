pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ERC20Mock is ERC20 {

    uint8 immutable _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _mint(msg.sender, 10 ** (decimals_ + 9));
        _decimals = decimals_;
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount * 10**18);
    }

    function decimals() public view override returns(uint8) {
        return _decimals;
    }
}
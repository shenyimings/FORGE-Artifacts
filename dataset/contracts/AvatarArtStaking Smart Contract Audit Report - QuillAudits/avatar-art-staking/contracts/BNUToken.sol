// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC20Metadata.sol";
import "./core/Ownable.sol";
import "./core/ERC20.sol";

contract BNUToken is ERC20, Ownable{
    constructor() ERC20("ByteNext","BNU"){}
    
    function mint(address account, uint256 amount) external onlyOwner{
        _mint(account, amount);
    }
    
    function burn(address account, uint256 amount) external onlyOwner{
        _burn(account, amount);
    }
}
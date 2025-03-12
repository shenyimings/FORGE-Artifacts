pragma solidity =0.5.16;

import '../KokomoERC20.sol';

contract ERC20 is KokomoERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}

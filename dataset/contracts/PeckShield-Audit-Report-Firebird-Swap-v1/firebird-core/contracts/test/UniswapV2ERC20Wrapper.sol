pragma solidity >=0.5.16;

import '../FireBirdERC20.sol';

contract FireBirdERC20Wrapper is FireBirdERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}

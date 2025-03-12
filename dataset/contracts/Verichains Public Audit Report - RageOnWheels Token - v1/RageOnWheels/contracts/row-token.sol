// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RageOnWheels is ERC20 {

    uint8 _decimals;

    constructor(
        string memory name_, 
        string memory symbol_, 
        uint256 supply,
        uint8 decimals_,
        address holder
        )
    ERC20(name_,symbol_)
    {
        _decimals=decimals_;
        _mint(holder, supply*10**decimals_);
    }

    function transferMultiple(address[] memory receivers, uint256[] memory amount) public {
        require(receivers.length==amount.length, "Different receiver and amount array length");
        for(uint256 i = 0; i<receivers.length;i++){
            _transfer(msg.sender, receivers[i], amount[i]);
        }
    }

    function decimals() override public view returns(uint8){
        return _decimals;
    }
}


pragma solidity 0.4.25;

import "../Gold/Gold.sol";

contract GoldMock is Gold {

    constructor (address _treasure) Gold(_treasure) public { }

    function mint(address _who, uint256 _value) public {
        _mint(_who, _value);
    }
}

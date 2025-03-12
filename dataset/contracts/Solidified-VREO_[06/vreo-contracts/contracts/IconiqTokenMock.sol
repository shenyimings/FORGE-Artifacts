pragma solidity 0.4.24;

import "../zeppelin/math/SafeMath.sol";

// Only for testing purposes

contract IconiqTokenMock {
    using SafeMath for uint;

    mapping(address => uint) public balanceOf;
    uint public totalSupply;
    uint public freeAmount;

    constructor(uint _totalSupply) public {
        totalSupply = _totalSupply;
        freeAmount = _totalSupply;
    }

    function setBalance(address _holder, uint _amount) public {
        freeAmount = freeAmount.add(balanceOf[_holder]).sub(_amount);
        balanceOf[_holder] = _amount;
    }

}

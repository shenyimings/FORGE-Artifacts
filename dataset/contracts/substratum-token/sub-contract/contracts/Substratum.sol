pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";

contract Substratum is ERC20Burnable, Ownable {
    string public constant name = "Substratum";
    string public constant symbol = "SUB";
    uint8 public constant decimals = 18;

    // 472 million tokens * decimal places (10^18)
    uint256 public constant INITIAL_SUPPLY = 472000000000000000000000000;

    constructor() public {
        ERC20._mint(msg.sender, INITIAL_SUPPLY);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_value == 0 || allowance(msg.sender, _spender) == 0, "Use increaseApproval or decreaseApproval to prevent double-spend.");

        return ERC20.approve(_spender, _value);
    }
}
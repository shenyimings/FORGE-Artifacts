pragma solidity ^0.6.0;

import "../libraries/tokens/ERC20.sol";

contract TestERC20Mock is ERC20 {
    string public name = "DAI";
    string public symbol = "DAI";
    uint8 public decimals = 18;

    constructor() public {}

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}

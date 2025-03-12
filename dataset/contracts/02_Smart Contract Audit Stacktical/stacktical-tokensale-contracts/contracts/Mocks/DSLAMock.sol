pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";

contract DSLAMock is ERC20Burnable {
    uint256 public constant INITIAL_SUPPLY = 10000000000000000000000000000;

    /**
      * @dev Constructor
      */
    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}

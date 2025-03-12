pragma solidity 0.5.16;

import "./BEP20Token.sol";

contract Token is BEP20Token {
    constructor() public {
        _initialize("Hora Os", "HORA", 18, 10 * 10**9 * 10**18, false);
    }
}

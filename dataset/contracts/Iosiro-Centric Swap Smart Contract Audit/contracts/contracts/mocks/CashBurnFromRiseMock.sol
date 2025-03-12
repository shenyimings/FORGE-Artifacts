pragma solidity 0.4.25;

import '../Cash.sol';


contract CashBurnFromRiseMock is Cash {
    constructor(address _mintSaver) public Cash(_mintSaver) {}

    function burnFromRise(address tokensOwner, uint256 value) external returns (bool) {
        return false;
    }
}

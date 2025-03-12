pragma solidity ^0.6.12;

import "./libraries/TokenTimelock.sol";

contract ShibbyTokenLock is TokenTimelock {
    constructor(IERC20 token, address beneficiary, uint256 releaseTime)
        public
        TokenTimelock(token, beneficiary, releaseTime)
    {}
}

pragma solidity 0.6.11;

import "../LQTY/LQTYTreasury.sol";


contract LQTYTreasuryTester is LQTYTreasury {

    constructor(uint _startTime) public LQTYTreasury(_startTime) {
        issuanceStartTime = 0;
    }

    function setIssuanceStart(uint256 _startTime) external {
        require(issuanceStartTime == 0);
        require(_startTime > block.timestamp);
        issuanceStartTime = _startTime;
    }

}

// contracts/TokenVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.9;

import "../ico/payMETokenCrowdsale.sol";

/**
 * @title MockToken1Vesting
 * WARNING: use only for testing and debugging purpose
 */
contract MockCrowdsale is payMETokenCrowdsale{

    uint256 mockTime = 0;

    constructor(
        IERC20 _BUSDT,
        address _vestingAddress,
        uint256 rate,    // rate in PayME
        address payable wallet,
        IERC20 _token,
        uint256 _cap,
        uint256 _openingTime,
        uint256 _closingTime,
        uint256 _TGETime,
        uint256 _cliff,
        uint256 _duration
    ) 
      payMETokenCrowdsale(
        _BUSDT,
        _vestingAddress,
        rate,    // rate in PayME
        wallet,
        _token,
        _cap,
        _openingTime,
        _closingTime,
        _TGETime,
        _duration
      ){
    }

    function setCurrentTime(uint256 _time)
        external{
        mockTime = _time;
    }

    // function getCurrentTime()
    //     internal
    //     virtual
    //     override
    //     view
    //     returns(uint256){
    //     return mockTime;
    // }
}
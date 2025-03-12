// contracts/TokenVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../ico/payMETokenVesting.sol";

/**
 * @title MockToken1Vesting
 * WARNING: use only for testing and debugging purpose
 */
contract MockTokenVesting is payMETokenVesting{

    uint256 mockTime;

    // constructor(IERC20 token_,uint256 TGEPercent_,uint256 TGEOpeningTime_) payMETokenVesting(token_,TGEPercent_,TGEOpeningTime_){
    // }

    function setCurrentTime(uint256 _time)
        external{
        mockTime = _time;
    }

    function getCurrentTime()
        internal
        virtual
        override
        view
        returns(uint256){
        return mockTime;
    }
}
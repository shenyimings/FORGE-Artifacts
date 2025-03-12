// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../lib/DataTypes.sol";

interface ICampaign {
    function cancelCampaign() external;
    function daoMultiSigEmergencyWithdraw(address tokenAddress, address to, uint amount) external;
}



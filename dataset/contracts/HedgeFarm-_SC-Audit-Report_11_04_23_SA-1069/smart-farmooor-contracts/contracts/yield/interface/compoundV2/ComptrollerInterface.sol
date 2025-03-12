// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./CTokenInterface.sol";

interface ComptrollerInterface {
    function enterMarkets(address[] calldata qiTokens) external returns (uint[] memory);
    function exitMarket(address qiToken) external returns (uint);
    function checkMembership(address account, CTokenInterface qiToken) external view returns (bool);
    function claimReward(uint8 rewardType, address payable[] memory holders, CTokenInterface[] memory qiTokens, bool borrowers, bool suppliers) external payable;
}
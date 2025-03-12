// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IMasterChef {
    function settleLottery(bytes32 requestId, uint256 randomNumber) external;
}
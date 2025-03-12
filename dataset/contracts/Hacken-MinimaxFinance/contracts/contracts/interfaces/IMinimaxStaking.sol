// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMinimaxStaking {
    function getUserAmount(uint _pid, address _user) external view returns (uint);
}

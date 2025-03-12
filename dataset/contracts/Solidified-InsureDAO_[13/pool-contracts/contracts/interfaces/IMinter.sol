pragma solidity ^0.6.0;

//SPDX-License-Identifier: MIT
interface IMinter {
    function emergency_mint(uint256 _amount) external returns (bool);
}

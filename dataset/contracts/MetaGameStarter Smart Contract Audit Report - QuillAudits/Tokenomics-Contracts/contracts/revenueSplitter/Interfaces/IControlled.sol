// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IControlled {
    function controller() external view returns(address);
}
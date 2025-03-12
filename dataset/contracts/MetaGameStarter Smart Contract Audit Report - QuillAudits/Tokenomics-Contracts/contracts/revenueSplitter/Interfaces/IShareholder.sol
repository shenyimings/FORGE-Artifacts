// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IShareholder {
    function notifyShareholder(
        address token,
        uint256 amount
    ) external returns(bool);
}
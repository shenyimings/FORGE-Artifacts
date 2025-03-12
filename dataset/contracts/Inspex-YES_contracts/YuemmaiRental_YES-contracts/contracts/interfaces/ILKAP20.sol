//SPDX-License-Identifier: MIT
pragma solidity >= 0.5.0;

import "./ILToken.sol";

interface ILKAP20 is ILToken {
    function mint(uint mintAmount) external returns (uint);
    function withdraw(uint withdrawTokens) external returns (uint);
    function withdrawUnderlying(uint withdrawAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
}
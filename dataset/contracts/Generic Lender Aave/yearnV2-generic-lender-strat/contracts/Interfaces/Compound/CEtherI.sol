// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import "./CTokenI.sol";

interface CEtherI is CTokenI {
    function redeemUnderlying(uint256 redeemAmount) external;

    function redeem(uint256 redeemTokens) external;

    function liquidateBorrow(address borrower, CTokenI cTokenCollateral) external payable;

    function mint() external payable;
}

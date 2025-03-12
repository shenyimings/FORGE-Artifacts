// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '../libraries/BespokeTypes.sol';

interface ITransferAdapterCurrency {
    function transferOnLend(
        address asset,
        address from,
        address to,
        uint256 amount,
        BespokeTypes.Offer memory offerData
    ) external;

    function transferOnRepay(
        address asset,
        address from,
        address to,
        uint256 amount,
        BespokeTypes.LoanData memory loanData
    ) external;
}

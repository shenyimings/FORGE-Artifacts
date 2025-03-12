// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IDCAEquity {
    struct DCAEquityValuation {
        uint256 totalDepositToken;
        uint256 totalBluechipToken;
        address bluechipToken;
    }

    function equityValuation()
        external
        view
        returns (DCAEquityValuation[] memory);
}

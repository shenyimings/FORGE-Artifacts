// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../../../Treasury.sol";

contract TreasuryChangeInStorageAndLogic is Treasury {
    address public newTreasury;

    function updateStorageVar(address newTreasuryVal) public {
        newTreasury = newTreasuryVal;
    }
}

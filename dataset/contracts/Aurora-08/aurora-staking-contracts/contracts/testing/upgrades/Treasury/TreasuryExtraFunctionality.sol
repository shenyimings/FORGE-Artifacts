// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../../../Treasury.sol";

contract TreasuryExtraFunctionality is Treasury {
    function dummy() public view returns (uint256) {
        return 1;
    }
}

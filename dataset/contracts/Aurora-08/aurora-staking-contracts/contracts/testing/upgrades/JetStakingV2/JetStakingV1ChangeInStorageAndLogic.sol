// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../../../JetStakingV1.sol";

contract JetStakingV1ChangeInStorageAndLogic is JetStakingV1 {
    uint256 public storageVar;

    function updateStorageVar(uint256 newVal) public {
        storageVar = newVal;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../gov/user-keeper/GovUserKeeper.sol";

contract GovUserKeeperMock is GovUserKeeper {
    function setIndividualNftPower(uint256 newPower) external {
        _nftInfo.individualPower = newPower;
    }
}

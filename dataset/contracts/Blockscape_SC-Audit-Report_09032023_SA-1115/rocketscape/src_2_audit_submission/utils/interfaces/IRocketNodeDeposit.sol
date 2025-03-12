pragma solidity ^0.8.16;

// SPDX-License-Identifier: GPL-3.0-only

import "../types/MinipoolDeposit.sol";

interface RocketNodeDepositInterface {
    function deposit(
        uint256 _minimumNodeFee,
        bytes calldata _validatorPubkey,
        bytes calldata _validatorSignature,
        bytes32 _depositDataRoot,
        uint256 _salt,
        address _expectedMinipoolAddress
    ) external payable;

    function getDepositType(
        uint256 _amount
    ) external view returns (MinipoolDeposit);
}

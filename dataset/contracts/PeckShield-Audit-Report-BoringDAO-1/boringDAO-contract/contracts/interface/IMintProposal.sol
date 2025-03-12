// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IMintProposal {
    function approve(
        bytes32 _tunnelKey,
        string memory _txid,
        uint256 _amount,
        address  to,
        address trustee,
        uint256 trusteeCount
    ) external returns (bool);
}

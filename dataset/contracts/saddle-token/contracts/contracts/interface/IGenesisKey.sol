//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IGenesisKey {
    function claimKey(address recipient, uint256 _eth) external payable returns (bool);
}

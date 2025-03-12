// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IReferralStorage.sol";

// forked from https://github.com/gmx-io/gmx-contracts/blob/master/contracts/referrals/ReferralReader.sol
contract ReferralReader {
    function getCodeOwners(IReferralStorage _referralStorage, bytes32[] memory _codes) public view returns (address[] memory) {
        address[] memory owners = new address[](_codes.length);

        for (uint256 i = 0; i < _codes.length; i++) {
            bytes32 code = _codes[i];
            owners[i] = _referralStorage.codeOwners(code);
        }

        return owners;
    }
}
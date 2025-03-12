// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { AppStorage, LibAppStorage } from "src/diamonds/nayms/AppStorage.sol";
import { LibSimplePolicy } from "src/diamonds/nayms/libs/LibSimplePolicy.sol";

import { SimplePolicy } from "src/diamonds/nayms/interfaces/FreeStructs.sol";

contract SimplePolicyFixture {
    function getFullInfo(bytes32 _policyId) public returns (SimplePolicy memory) {
        return LibSimplePolicy._getSimplePolicyInfo(_policyId);
    }

    function update(bytes32 _policyId, SimplePolicy memory simplePolicy) public {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.simplePolicies[_policyId] = simplePolicy;
    }
}

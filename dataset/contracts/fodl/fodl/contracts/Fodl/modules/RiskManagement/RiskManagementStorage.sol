// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

contract RiskManagementStorage {
    bytes32 constant RISK_MANAGAMENT_STORAGE_POSITION = keccak256('folding.storage.risk');

    /**
     * whitelist:               list of addresses that can execute a stoploss on this account
     */
    struct RiskMagamentStore {
        mapping(address => bool) whitelist;
    }

    function riskMagamentStore() internal pure returns (RiskMagamentStore storage s) {
        bytes32 position = RISK_MANAGAMENT_STORAGE_POSITION;
        assembly {
            s_slot := position
        }
    }
}

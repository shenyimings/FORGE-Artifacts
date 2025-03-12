// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../utils/Initializable.sol";
import "../interfaces/IMarketSettings.sol";

/**
 * @dev Contract module which holds the setting params for all markets.
 */
contract MarketSettings is IMarketSettings, AccessControlEnumerable, Initializable {
    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    mapping(bytes32 => int) private intVals;

    function initialize() external onlyInitializeOnce {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*=== setters ===*/

    function setIntVals(bytes32[] memory _keys, int[] memory _values) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_keys.length == _values.length, "MarketSettings: length not match");
        uint len = _keys.length;
        for (uint i = 0; i < len; ++i) {
            intVals[_keys[i]] = _values[i];
            emit SetKey(_keys[i], _values[i]);
        }
    }

    /*=== getters ===*/

    function getIntVals(bytes32 _key) external view returns (int) {
        return intVals[_key];
    }

    function getIntValsByDomain(bytes32 _domainKey, bytes32 _key) external view returns (int) {
        return intVals[keccak256(abi.encodePacked([_domainKey, _key]))];
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "./Governable.sol";
import "./../interfaces/utils/IRegistry.sol";

/**
 * @title Registry
 * @author solace.fi
 * @notice Tracks the contracts of the Solaverse.
 *
 * [**Governance**](/docs/protocol/governance) can set the contract addresses and anyone can look them up.
 *
 * A key is a unique identifier for each contract. Use [`get(key)`](#get) or [`tryGet(key)`](#tryget) to get the address of the contract. Enumerate the keys with [`length()`](#length) and [`getKey(index)`](#getkey).
 */
contract Registry is IRegistry, Governable {

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    struct RegistryEntry {
        uint256 index;
        address value;
    }

    // contract name => contract address
    mapping(string => RegistryEntry) private _addresses;

    // index => key
    mapping(uint256 => string) private _keys;

    /// @notice The number of unique keys.
    uint256 public override length;

    /**
     * @notice Constructs the registry contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     */
    // solhint-disable-next-line no-empty-blocks
    constructor(address governance_) Governable(governance_) { }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Gets the `value` of a given `key`.
     * Reverts if the key is not in the mapping.
     * @param key The key to query.
     * @return value The value of the key.
     */
    function get(string calldata key) external view override returns (address value) {
        RegistryEntry memory entry = _addresses[key];
        require(entry.index != 0, "key not in mapping");
        return entry.value;
    }

    /**
     * @notice Gets the `value` of a given `key`.
     * Fails gracefully if the key is not in the mapping.
     * @param key The key to query.
     * @return success True if the key was found, false otherwise.
     * @return value The value of the key or zero if it was not found.
     */
    function tryGet(string calldata key) external view override returns (bool success, address value) {
        RegistryEntry memory entry = _addresses[key];
        return (entry.index == 0)
            ? (false, address(0x0))
            : (true, entry.value);
    }

    /**
     * @notice Gets the `key` of a given `index`.
     * @dev Iterable [1,length].
     * @param index The index to query.
     * @return key The key at that index.
     */
    function getKey(uint256 index) external view override returns (string memory key) {
        require(index != 0 && index <= length, "index out of range");
        return _keys[index];
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Sets keys and values.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param keys The keys to set.
     * @param values The values to set.
     */
    function set(string[] calldata keys, address[] calldata values) external override onlyGovernance {
        uint256 len = keys.length;
        require(len == values.length, "length mismatch");
        for(uint256 i = 0; i < len; i++) {
            require(values[i] != address(0), "cannot set zero address");
            string memory key = keys[i];
            address value = values[i];
            RegistryEntry memory entry = _addresses[key];
            // add new record
            if(entry.index == 0) {
                entry.index = ++length; // autoincrement from 1
                _keys[entry.index] = key;
            }
            // store record
            entry.value = value;
            _addresses[key] = entry;
            emit RecordSet(key, value);
        }
    }
}

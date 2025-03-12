// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {stdJson} from "@forge-std/StdJson.sol";

struct TestConfig {
    string json;
}

library TestConfigLib {
    using stdJson for string;

    string public constant RPC_ALIAS_PATH = "$.rpcAlias";
    string public constant FORK_BLOCK_NUMBER_PATH = "$.forkBlockNumber";
    string public constant ADDRESSES_PROVIDER_PATH = "$.addressesProvider";
    string public constant WRAPPED_NATIVE_PATH = "$.wrappedNative";
    string public constant MARKETS_PATH = "$.markets";

    function getAddress(TestConfig storage config, string memory key) internal view returns (address) {
        return config.json.readAddress(string.concat("$.", key));
    }

    function getRpcAlias(TestConfig storage config) internal view returns (string memory) {
        return config.json.readString(RPC_ALIAS_PATH);
    }

    function getForkBlockNumber(TestConfig storage config) internal view returns (uint256) {
        return config.json.readUint(FORK_BLOCK_NUMBER_PATH);
    }

    function getAddressesProvider(TestConfig storage config) internal view returns (address) {
        return config.json.readAddress(ADDRESSES_PROVIDER_PATH);
    }

    function getWrappedNative(TestConfig storage config) internal view returns (address) {
        return getAddress(config, config.json.readString(WRAPPED_NATIVE_PATH));
    }
}

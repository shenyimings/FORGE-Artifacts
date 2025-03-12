// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ISupportedChains.sol";

interface IEventLogger {
    struct EventData {
        uint256[2] chains; // [chainId, chainId]
        address[2] tokens; // where, ETH - address(0)
        address[2] parties; // address from - to [account, account on other side]
    }

    function log(EventData calldata data) external;

    function getAssetId(uint256 chainId, address tokenAddress)
        external
        pure
        returns (bytes32 id);
}

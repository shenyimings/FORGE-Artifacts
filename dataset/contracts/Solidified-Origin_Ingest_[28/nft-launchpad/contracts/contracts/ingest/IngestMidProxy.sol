// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Ingest Mid Proxy Contract
 * @author Origin Protocol Inc
 */

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "./IngestRegistry.sol";

contract IngestMidProxy is Proxy {
    IngestRegistry constant registry =
        IngestRegistry(0xFFbebEbeBEbeBeBEBeBebeBEbeBebebEAAaAaAAA);

    function _implementation() internal view override returns (address) {
        return registry.endpointImplementation();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IGatewayGuarded.sol";

/**
 * The management interface exposed to gateway.
 */
abstract contract GatewayGuarded is IGatewayGuarded {
    address public gateway;

    modifier onlyGateway() {
        require(msg.sender == gateway);
        _;
    }

    constructor(address _gateway) {
        gateway = _gateway;
    }

    /**
     * @inheritdoc IGatewayGuarded
     */
    function setGateway(address _gateway) external override onlyGateway {
        gateway = _gateway;
    }
}

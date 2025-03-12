// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "OpenZeppelin/openzeppelin-contracts@4.2.0/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @author psirex
/// @notice Proxy to use with UUPSUpgradable implementation contracts
contract ContractProxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) {}

    /// @notice Returns address of currently used implementation
    function __Proxy_implementation() external view returns (address) {
        return _implementation();
    }
}

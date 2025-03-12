// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "../interfaces/IEVMScriptFactory.sol";

/// @author psirex
/// @notice Helper contract with stub implementation of EVMScriptFactory
contract EVMScriptFactoryStub is IEVMScriptFactory {
    bytes public constant DEFAULT_EVM_SCRIPT =
        hex"00000001420b1099b9ef5baba6d92029594ef45e19a04a4a00000044ae962acf000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001f4";
    bytes public constant DEFAULT_PERMISSIONS =
        hex"420b1099B9eF5baba6D92029594eF45E19A04A4Aae962acf";
    bytes32 public constant DEFAULT_EVM_SCRIPT_HASH = keccak256(DEFAULT_EVM_SCRIPT);

    address public creator;
    bytes public evmScriptCallData;
    bytes public evmScript = DEFAULT_EVM_SCRIPT;

    function createEVMScript(address _creator, bytes memory _evmScriptCallData)
        external
        override
        returns (bytes memory)
    {
        creator = _creator;
        evmScriptCallData = _evmScriptCallData;
        return evmScript;
    }

    function setEVMScript(bytes memory _evmScript) external {
        evmScript = _evmScript;
    }
}

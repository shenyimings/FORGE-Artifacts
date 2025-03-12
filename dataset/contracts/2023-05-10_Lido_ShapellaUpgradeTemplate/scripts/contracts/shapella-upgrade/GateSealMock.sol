// SPDX-FileCopyrightText: 2023 Lido <info@lido.fi>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

contract GateSealMock {

    address[] _sealables;

    constructor(address withdrawalQueue, address validatorsExitBusOracle) {
        _sealables.push(withdrawalQueue);
        _sealables.push(validatorsExitBusOracle);
    }

    function get_sealables() external view returns (address[] memory) {
        return _sealables;
    }

}

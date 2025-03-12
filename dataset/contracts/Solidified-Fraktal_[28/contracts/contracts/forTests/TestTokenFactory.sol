pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: UNLICENSED

import './TestTokenUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol';

contract TestTokenFactory {
    address public implementation;
    event NewToken(address token);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createTestToken(string calldata name, string calldata symbol)
        external
        returns (address _clone)
    {
        _clone = ClonesUpgradeable.clone(implementation);
        TestTokenUpgradeable(_clone).init(name, symbol);
        emit NewToken(_clone);
    }
}

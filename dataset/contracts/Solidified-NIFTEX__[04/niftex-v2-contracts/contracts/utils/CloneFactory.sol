// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract CloneFactory
{
    address private _cloneFactoryMaster;

    event NewInstance(address instance);

    constructor(address master_) { _cloneFactoryMaster = master_; }

    function _clone()
    internal returns (address instance)
    {
        instance = Clones.clone(_cloneFactoryMaster);
        emit NewInstance(instance);
    }

    function _cloneDeterministic(bytes32 salt)
    internal returns (address instance)
    {
        instance = Clones.cloneDeterministic(_cloneFactoryMaster, salt);
        emit NewInstance(instance);
    }

    function _predictDeterministicAddress(bytes32 salt)
    internal view returns (address predicted)
    {
        predicted = Clones.predictDeterministicAddress(_cloneFactoryMaster, salt);
    }
}

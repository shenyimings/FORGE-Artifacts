// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleProxyFactory, MapleProxyFactory } from "../modules/maple-proxy-factory/contracts/MapleProxyFactory.sol";
import { IMapleProxied }                         from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleGlobalsLike } from "./interfaces/Interfaces.sol";

contract LiquidatorFactory is MapleProxyFactory {

    constructor(address globals_) MapleProxyFactory(globals_) { }

    function createInstance(bytes calldata arguments_, bytes32 salt_) override(MapleProxyFactory) public returns (address instance_) {
        address loanManagerFactory_ = IMapleProxied(msg.sender).factory();

        require(IMapleGlobalsLike(mapleGlobals).isFactory("LOAN_MANAGER", loanManagerFactory_), "LF:CI:INVALID_FACTORY");
        require(IMapleProxyFactory(loanManagerFactory_).isInstance(msg.sender),                 "LF:CI:INVALID_INSTANCE");

        instance_ = super.createInstance(arguments_, salt_);
    }

}

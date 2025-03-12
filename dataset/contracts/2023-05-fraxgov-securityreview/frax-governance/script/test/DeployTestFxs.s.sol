// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import { BaseScript } from "frax-std/BaseScript.sol";
import { console } from "frax-std/FraxTest.sol";
import { Constants } from "script/Constants.sol";
import "test/mock/FxsMock.sol";
import "src/interfaces/IVeFxs.sol";
import "test/utils/VyperDeployer.sol";

function deployMockFxs() returns (address _address, bytes memory _constructorParams, string memory _contractName) {
    _contractName = "MockFxs";
    string memory _symbol = "FXSM";
    _constructorParams = abi.encode(_contractName, _symbol);
    _address = address(new FxsMock(_contractName, _symbol));
}

// Deploy through remix for testnet deploys. See README.
function deployVeFxs(
    VyperDeployer vyperDeployer,
    address _mockFxs
) returns (address _address, bytes memory _constructorParams, string memory _contractName) {
    _contractName = "veFxs";
    _constructorParams = abi.encode(_mockFxs, _contractName, "1");
    _address = address(vyperDeployer.deployContract(_contractName, _constructorParams));
}

contract DeployTestFxs is BaseScript {
    function run()
        external
        broadcaster
        returns (address _address, bytes memory _constructorParams, string memory _contractName)
    {
        (_address, _constructorParams, _contractName) = deployMockFxs();
    }
}

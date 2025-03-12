// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Vm } from "@forge-std/Vm.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

library DeployHelper {
  Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  address public constant PROXY_ADMIN = address(9876);

  function deployContract(string memory contractName) internal returns (address addr) {
    return deployContract(contractName, abi.encode());
  }

  function deployContract(string memory contractName, bytes memory constructorArgs) internal returns (address addr) {
    string memory artifactPath = string(abi.encodePacked("./out/", contractName, ".sol/", contractName, ".json"));
    bytes memory bytecode = abi.encodePacked(vm.getCode(artifactPath), constructorArgs);
    assembly {
      addr := create(0, add(bytecode, 0x20), mload(bytecode))
    }
  }

  function deployUpgradeable(string memory contractName, bytes memory initializerData) internal returns (address proxy) {
    address implementation = deployContract(contractName);
    proxy = deployContract("TransparentUpgradeableProxy", abi.encode(implementation, PROXY_ADMIN, initializerData));
  }

  function deployUpgradeableFullPath(string memory implementationArtifactPath, bytes memory initializerData)
    internal
    returns (address proxy)
  {
    bytes memory bytecode = abi.encodePacked(vm.getCode(implementationArtifactPath));
    address implementation;
    assembly {
      implementation := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    proxy = deployContract("TransparentUpgradeableProxy", abi.encode(implementation, PROXY_ADMIN, initializerData));
  }

  function deployMockERC20(string memory symbol, uint8 decimals) internal returns (address) {
    return deployContract(
      "MockERC20", abi.encode(string(abi.encodePacked("mock", symbol)), abi.encodePacked("m", symbol), decimals)
    );
  }
}

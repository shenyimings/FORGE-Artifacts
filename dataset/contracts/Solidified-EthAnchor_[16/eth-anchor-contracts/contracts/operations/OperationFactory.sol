// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";

import { OperationACL } from "./OperationACL.sol";

interface OperationStandard {
  function initialize(bytes memory) external;

  function initPayload(
    address,
    address,
    bytes32
  ) external view returns (bytes memory);
}

interface IOperationFactory {
  event ContractDeployed(
    address indexed instance,
    address indexed controller,
    bytes32 indexed terraAddress
  );

  struct Standard {
    address router;
    address controller;
    address operation;
  }

  function pushTerraAddresses(bytes32[] memory _addrs) external;

  function fetchAddressBufferSize() external view returns (uint256);

  function fetchNextTerraAddress() external view returns (bytes32);

  function build(uint256 _optId) external returns (address);
}

contract OperationFactory is IOperationFactory, OperationACL {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // standard operations
  uint256 public standardIndex = 0;
  mapping(uint256 => Standard) public standards;

  function pushStandardOperation(
    address _router,
    address _controller,
    address _operation
  ) public onlyOwner returns (uint256) {
    uint256 optStdId = standardIndex;
    standards[optStdId] = Standard({
      router: _router,
      controller: _controller,
      operation: _operation
    });
    standardIndex += 1;
    return optStdId;
  }

  // terra address buffer
  EnumerableSet.Bytes32Set private terraAddresses;

  function pushTerraAddresses(bytes32[] memory _addrs)
    public
    override
    onlyOwner
  {
    for (uint256 i = 0; i < _addrs.length; i++) {
      terraAddresses.add(_addrs[i]);
    }
  }

  function fetchAddressBufferSize() public view override returns (uint256) {
    return terraAddresses.length();
  }

  function fetchNextTerraAddress() public view override returns (bytes32) {
    return terraAddresses.at(0);
  }

  function fetchTerraAddress() private returns (bytes32) {
    bytes32 addr = terraAddresses.at(0);
    terraAddresses.remove(addr);
    return addr;
  }

  function build(uint256 _optId) public override onlyGranted returns (address) {
    bytes32 terraAddr = fetchTerraAddress();
    Standard memory std = standards[_optId];

    address instance = Clones.clone(std.operation);
    bytes memory payload = OperationStandard(std.operation).initPayload(
      std.router,
      std.controller,
      terraAddr
    );
    OperationStandard(instance).initialize(payload);

    emit ContractDeployed(instance, std.controller, terraAddr);

    return instance;
  }
}

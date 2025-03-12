// Dependency file: contracts/interfaces/IRegistry.sol

// SPDX-License-Identifier: Apache-2.0
// pragma solidity >=0.8.4 <0.9.0;

interface IRegistry {
  event Registered(bytes32 domain, bytes32 indexed name, address indexed addr);

  function isExistRecord(bytes32 domain, bytes32 name) external view returns (bool);

  function set(
    bytes32 domain,
    bytes32 name,
    address addr
  ) external returns (bool);

  function batchSet(
    bytes32[] calldata domains,
    bytes32[] calldata names,
    address[] calldata addrs
  ) external returns (bool);

  function getAddress(bytes32 domain, bytes32 name) external view returns (address);

  function getDomainAndName(address addr) external view returns (bytes32, bytes32);
}


// Root file: contracts/libraries/User.sol

pragma solidity >=0.8.4 <0.9.0;

// import 'contracts/interfaces/IRegistry.sol';

abstract contract User {
  // Registry contract
  IRegistry internal _registry;

  // Active domain
  bytes32 internal _domain;

  // Initialized
  bool private _initialized = false;

  // Allow same domain calls
  modifier onlyAllowSameDomain(bytes32 name) {
    require(msg.sender == _registry.getAddress(_domain, name), 'User: Only allow call from same domain');
    _;
  }

  // Allow cross domain call
  modifier onlyAllowCrossDomain(bytes32 fromDomain, bytes32 name) {
    require(msg.sender == _registry.getAddress(fromDomain, name), 'User: Only allow call from allowed cross domain');
    _;
  }

  /*******************************************************
   * Internal section
   ********************************************************/

  // Constructing with registry address and its active domain
  function _registryUserInit(address registry_, bytes32 domain_) internal returns (bool) {
    require(!_initialized, "User: It's only able to initialize once");
    _registry = IRegistry(registry_);
    _domain = domain_;
    _initialized = true;
    return true;
  }

  // Get address in the same domain
  function _getAddressSameDomain(bytes32 name) internal view returns (address) {
    return _registry.getAddress(_domain, name);
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Return active domain
  function getDomain() external view returns (bytes32) {
    return _domain;
  }

  // Return registry address
  function getRegistry() external view returns (address) {
    return address(_registry);
  }
}

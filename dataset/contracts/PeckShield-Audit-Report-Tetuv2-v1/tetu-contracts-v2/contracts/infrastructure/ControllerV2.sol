// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/EnumerableMap.sol";
import "../interfaces/IProxyControlled.sol";
import "../proxy/ControllableV3.sol";

/// @title A central contract of the TETU platform.
///        Holds all important contract addresses.
///        Able to upgrade proxies with time-lock.
/// @author belbix
contract ControllerV2 is ControllableV3, IController {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableMap for EnumerableMap.UintToUintMap;
  using EnumerableMap for EnumerableMap.UintToAddressMap;
  using EnumerableMap for EnumerableMap.AddressToUintMap;

  enum AddressType {
    UNKNOWN, // 0
    GOVERNANCE, // 1
    TETU_VOTER, // 2
    PLATFORM_VOTER, // 3
    LIQUIDATOR, // 4
    FORWARDER, // 5
    INVEST_FUND, // 6
    VE_DIST // 7
  }

  struct AddressAnnounce {
    uint _type;
    address newAddress;
    uint timeLockAt;
  }

  struct ProxyAnnounce {
    address proxy;
    address implementation;
    uint timeLockAt;
  }

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant CONTROLLER_VERSION = "2.0.1";
  uint public constant TIME_LOCK = 18 hours;

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  // --- restrictions

  /// @dev Gnosis safe multi signature wallet with maximum power under the platform.
  address public override governance;
  /// @dev Operators can execute not-critical functions of the platform.
  EnumerableSet.AddressSet internal _operators;

  // --- dependency

  /// @dev Voter for distribute TETU to gauges.
  address public override voter;
  /// @dev External solution for sell any tokens with minimal gas usage.
  address public override liquidator;
  /// @dev Accumulate performance fees and distribute them properly.
  address public override forwarder;
  /// @dev Contract for holding assets for the Second Stage
  address public override investFund;
  /// @dev Contract for accumulate TETU rewards for veTETU and weekly distribute them.
  address public override veDistributor;
  /// @dev Special voter for platform attributes.
  address public override platformVoter;

  // --- elements

  /// @dev Set of valid vaults
  EnumerableSet.AddressSet internal _vaults;

  // --- time locks

  EnumerableMap.UintToUintMap internal _addressTimeLocks;
  EnumerableMap.UintToAddressMap internal _addressAnnounces;

  EnumerableMap.AddressToUintMap internal _proxyTimeLocks;
  mapping(address => address) public proxyAnnounces;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event AddressChangeAnnounced(uint _type, address value);
  event AddressChanged(uint _type, address oldAddress, address newAddress);
  event AddressAnnounceRemove(uint _type);
  event ProxyUpgradeAnnounced(address proxy, address implementation);
  event ProxyUpgraded(address proxy, address implementation);
  event ProxyAnnounceRemoved(address proxy);
  event RegisterVault(address vault);
  event VaultRemoved(address vault);
  event OperatorAdded(address operator);
  event OperatorRemoved(address operator);

  // *************************************************************
  //                        INIT
  // *************************************************************

  /// @dev Proxy initialization. Call it after contract deploy.
  function init(address _governance) external initializer {
    require(_governance != address(0), "WRONG_INPUT");
    governance = _governance;
    __Controllable_init(address(this));
    _operators.add(_governance);
  }

  // *************************************************************
  //                     RESTRICTIONS
  // *************************************************************

  function _onlyGovernance() internal view {
    require(msg.sender == governance, "DENIED");
  }

  function _onlyOperators() internal view {
    require(_operators.contains(msg.sender), "DENIED");
  }

  // *************************************************************
  //                        VIEWS
  // *************************************************************

  /// @dev Return all announced address changes.
  function addressAnnouncesList() external view returns (AddressAnnounce[] memory announces) {
    uint length = _addressTimeLocks.length();
    announces = new AddressAnnounce[](length);
    for (uint i; i < length; ++i) {
      (uint _type, uint timeLock) = _addressTimeLocks.at(i);
      address newAddress = _addressAnnounces.get(_type);
      announces[i] = AddressAnnounce(_type, newAddress, timeLock);
    }
  }

  /// @dev Return all announced proxy upgrades.
  function proxyAnnouncesList() external view returns (ProxyAnnounce[] memory announces) {
    uint length = _proxyTimeLocks.length();
    announces = new ProxyAnnounce[](length);
    for (uint i; i < length; ++i) {
      (address proxy, uint timeLock) = _proxyTimeLocks.at(i);
      address implementation = proxyAnnounces[proxy];
      announces[i] = ProxyAnnounce(proxy, implementation, timeLock);
    }
  }

  /// @dev Return true if the value exist in the operator set.
  function isOperator(address value) external view override returns (bool) {
    return _operators.contains(value);
  }

  /// @dev Return all operators. Expect the array will have reasonable size.
  function operatorsList() external view returns (address[] memory) {
    return _operators.values();
  }

  /// @dev Return all vaults. Array can be too big for use this function.
  function vaultsList() external view override returns (address[] memory) {
    return _vaults.values();
  }

  /// @dev Vault set size.
  function vaultsListLength() external view override returns (uint) {
    return _vaults.length();
  }

  /// @dev Return vault with given id. Ordering can be changed with time!
  function vaults(uint id) external view override returns (address) {
    return _vaults.at(id);
  }

  /// @dev Return true if the vault valid.
  function isValidVault(address _vault) external view override returns (bool) {
    return _vaults.contains(_vault);
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_CONTROLLER || super.supportsInterface(interfaceId);
  }

  // *************************************************************
  //          SET ADDRESSES WITH TIME-LOCK PROTECTION
  // *************************************************************

  /// @dev Add announce information for given address type.
  function announceAddressChange(AddressType _type, address value) external {
    _onlyGovernance();
    require(value != address(0), "ZERO_VALUE");
    require(_addressAnnounces.set(uint(_type), value), "ANNOUNCED");
    _addressTimeLocks.set(uint(_type), block.timestamp + TIME_LOCK);

    emit AddressChangeAnnounced(uint(_type), value);
  }

  /// @dev Change time-locked address and remove lock info.
  ///      Less strict for reduce governance actions.
  function changeAddress(AddressType _type) external {
    _onlyOperators();

    address newAddress = _addressAnnounces.get(uint(_type));
    uint timeLock = _addressTimeLocks.get(uint(_type));
    // no need to check values - get for non-exist values will be reverted
    address oldAddress;

    if (_type == AddressType.GOVERNANCE) {
      oldAddress = governance;
      governance = newAddress;

    } else if (_type == AddressType.TETU_VOTER) {
      oldAddress = voter;
      voter = newAddress;

    } else if (_type == AddressType.LIQUIDATOR) {
      oldAddress = liquidator;
      liquidator = newAddress;

    } else if (_type == AddressType.FORWARDER) {
      _requireInterface(newAddress, InterfaceIds.I_FORWARDER);
      oldAddress = forwarder;
      forwarder = newAddress;

    } else if (_type == AddressType.INVEST_FUND) {
      oldAddress = investFund;
      investFund = newAddress;

    } else if (_type == AddressType.VE_DIST) {
      _requireInterface(newAddress, InterfaceIds.I_VE_DISTRIBUTOR);
      oldAddress = veDistributor;
      veDistributor = newAddress;

    } else if (_type == AddressType.PLATFORM_VOTER) {
      _requireInterface(newAddress, InterfaceIds.I_PLATFORM_VOTER);
      oldAddress = platformVoter;
      platformVoter = newAddress;
    } else {
      revert("UNKNOWN");
    }

    // skip time-lock for initialization
    if (oldAddress != address(0)) {
      require(timeLock < block.timestamp, "LOCKED");
    }

    _addressAnnounces.remove(uint(_type));
    _addressTimeLocks.remove(uint(_type));

    emit AddressChanged(uint(_type), oldAddress, newAddress);
  }

  /// @dev Remove announced address change.
  function removeAddressAnnounce(AddressType _type) external {
    _onlyOperators();

    _addressAnnounces.remove(uint(_type));
    _addressTimeLocks.remove(uint(_type));

    emit AddressAnnounceRemove(uint(_type));
  }

  // *************************************************************
  //          UPGRADE PROXIES WITH TIME-LOCK PROTECTION
  // *************************************************************

  function announceProxyUpgrade(
    address[] memory proxies,
    address[] memory implementations
  ) external {
    _onlyGovernance();
    require(proxies.length == implementations.length, "WRONG_INPUT");

    for (uint i; i < proxies.length; i++) {
      address proxy = proxies[i];
      address implementation = implementations[i];

      require(implementation != address(0), "ZERO_IMPL");
      require(_proxyTimeLocks.set(proxy, block.timestamp + TIME_LOCK), "ANNOUNCED");
      proxyAnnounces[proxy] = implementation;

      emit ProxyUpgradeAnnounced(proxy, implementation);
    }
  }

  /// @dev Upgrade proxy. Less strict for reduce governance actions.
  function upgradeProxy(address[] memory proxies) external {
    _onlyOperators();

    for (uint i; i < proxies.length; i++) {
      address proxy = proxies[i];
      uint timeLock = _proxyTimeLocks.get(proxy);
      // Map get will revert on not exist key, no need to check to zero
      address implementation = proxyAnnounces[proxy];

      require(timeLock < block.timestamp, "LOCKED");

      IProxyControlled(proxy).upgrade(implementation);

      _proxyTimeLocks.remove(proxy);
      delete proxyAnnounces[proxy];

      emit ProxyUpgraded(proxy, implementation);
    }
  }

  function removeProxyAnnounce(address proxy) external {
    _onlyOperators();

    _proxyTimeLocks.remove(proxy);
    delete proxyAnnounces[proxy];

    emit ProxyAnnounceRemoved(proxy);
  }

  // *************************************************************
  //                     REGISTER ACTIONS
  // *************************************************************

  /// @dev Register vault in the system.
  ///      Operator should do it as part of deployment process.
  function registerVault(address vault) external {
    _onlyOperators();

    require(_vaults.add(vault), "EXIST");
    emit RegisterVault(vault);
  }

  /// @dev Remove vault from the system. Only for critical cases.
  function removeVault(address vault) external {
    _onlyGovernance();

    require(_vaults.remove(vault), "NOT_EXIST");
    emit VaultRemoved(vault);
  }

  /// @dev Register new operator.
  function registerOperator(address value) external {
    _onlyGovernance();

    require(_operators.add(value), "EXIST");
    emit OperatorAdded(value);
  }

  /// @dev Remove operator.
  function removeOperator(address value) external {
    _onlyGovernance();

    require(_operators.remove(value), "NOT_EXIST");
    emit OperatorRemoved(value);
  }

}

// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import 'hardhat/console.sol';
import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';
import {Errors} from '../tools/Errors.sol';

import {BitUtils} from '../tools/math/BitUtils.sol';

// prettier-ignore
import {InitializableImmutableAdminUpgradeabilityProxy} from '../tools/upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol';
import {IProxy} from '../tools/upgradeability/IProxy.sol';

import {IManagedAccessController} from './interfaces/IAccessController.sol';

contract AccessController is Ownable, IManagedAccessController {
  using BitUtils for uint256;

  mapping(uint256 => address) private _addresses;
  mapping(address => uint256) private _masks;
  mapping(uint256 => address[]) private _grantees;
  uint256 private _nonSingletons;
  uint256 private _singletons;
  uint256 private _proxies;

  address private _tempAdmin;
  uint256 private _expiresAt;

  uint8 private constant anyRoleBlocked = 1;
  uint8 private constant anyRoleEnabled = 2;
  uint8 private _anyRoleMode;

  constructor(
    uint256 singletons,
    uint256 nonSingletons,
    uint256 proxies
  ) public {
    require(singletons & nonSingletons == 0, 'mixed types');
    require(singletons & proxies == proxies, 'all proxies must be singletons');
    _singletons = singletons;
    _nonSingletons = nonSingletons;
    _proxies = proxies;
  }

  function _onlyAdmin() private view {
    require(
      _msgSender() == owner() || (_msgSender() == _tempAdmin && _expiresAt > block.number),
      Errors.TXT_OWNABLE_CALLER_NOT_OWNER
    );
  }

  modifier onlyAdmin {
    _onlyAdmin();
    _;
  }

  function queryAccessControlMask(address addr, uint256 filter)
    external
    view
    override
    returns (uint256 flags)
  {
    flags = _masks[addr];
    if (filter == 0) {
      return flags;
    }
    return flags & filter;
  }

  function setTemporaryAdmin(address admin, uint32 expiryBlocks) external override onlyOwner {
    if (_tempAdmin != address(0)) {
      _revokeAllRoles(_tempAdmin);
    }
    if (admin != address(0)) {
      _expiresAt = block.number + expiryBlocks;
    }
    _tempAdmin = admin;
  }

  function getTemporaryAdmin()
    external
    view
    override
    returns (address admin, uint256 expiresAtBlock)
  {
    if (admin != address(0)) {
      return (_tempAdmin, _expiresAt);
    }
    return (address(0), 0);
  }

  /// @dev Renouncement has no time limit and can be done either by the temporary admin at any time, or by anyone after the expiry.
  function renounceTemporaryAdmin() external override {
    if (_tempAdmin == address(0)) {
      return;
    }
    if (_msgSender() != _tempAdmin && _expiresAt > block.number) {
      return;
    }
    _revokeAllRoles(_tempAdmin);
    _tempAdmin = address(0);
  }

  function grantRoles(address addr, uint256 flags) public onlyAdmin returns (uint256) {
    require(_singletons & flags == 0, 'singleton should use setAddress');
    _grantRoles(addr, flags);
  }

  function setAnyRoleMode(bool blockOrEnable) public onlyAdmin {
    require(_anyRoleMode != anyRoleBlocked);
    if (blockOrEnable) {
      _anyRoleMode = anyRoleEnabled;
    } else {
      _anyRoleMode = anyRoleBlocked;
    }
  }

  function grantAnyRoles(address addr, uint256 flags) public onlyAdmin returns (uint256) {
    require(_anyRoleMode == anyRoleEnabled);
    _grantRoles(addr, flags);
  }

  function _grantRoles(address addr, uint256 flags) private returns (uint256) {
    uint256 m = _masks[addr];
    flags &= ~m;
    if (flags == 0) {
      return m;
    }

    _nonSingletons |= flags;
    m |= flags;
    _masks[addr] = m;

    for (uint8 i = 0; i <= 255; i++) {
      uint256 mask = uint256(1) << i;
      if (mask & flags == 0) {
        if (mask > flags) {
          break;
        }
        continue;
      }
      _grantees[mask].push(addr);
    }
    return m;
  }

  function revokeRoles(address addr, uint256 flags) external onlyAdmin returns (uint256) {
    require(_singletons & flags == 0, 'singleton should use setAddress');

    return _revokeRoles(addr, flags);
  }

  function revokeAllRoles(address addr) external onlyAdmin returns (uint256) {
    return _revokeAllRoles(addr);
  }

  function _revokeAllRoles(address addr) private returns (uint256) {
    uint256 m = _masks[addr];
    if (m == 0) {
      return 0;
    }
    delete (_masks[addr]);

    uint256 flags = m & _singletons;
    if (flags == 0) {
      return m;
    }

    for (uint8 i = 0; i <= 255; i++) {
      uint256 mask = uint256(1) << i;
      if (mask & flags == 0) {
        if (mask > flags) {
          break;
        }
        continue;
      }
      if (_addresses[mask] == addr) {
        delete (_addresses[mask]);
      }
    }

    return m;
  }

  function _revokeRoles(address addr, uint256 flags) private returns (uint256) {
    uint256 m = _masks[addr];
    if (m & flags != 0) {
      m &= ~flags;
      _masks[addr] = m;
    }
    return m;
  }

  function revokeRolesFromAll(uint256 flags, uint256 limit) public onlyAdmin returns (bool all) {
    all = true;

    for (uint8 i = 0; i <= 255; i++) {
      uint256 mask = uint256(1) << i;
      if (mask & flags == 0) {
        if (mask > flags) {
          break;
        }
        continue;
      }
      if (mask & _singletons != 0) {
        delete (_addresses[mask]);
      }

      if (!all) {
        continue;
      }

      address[] storage grantees = _grantees[mask];
      for (uint256 j = grantees.length; j > 0; ) {
        j--;
        if (limit == 0) {
          all = false;
          break;
        }
        limit--;
        _revokeRoles(grantees[j], mask);
        grantees.pop();
      }
    }
    return all;
  }

  function roleGrantees(uint256 id) external view returns (address[] memory addrList) {
    require(id.isPowerOf2nz(), 'only one role is allowed');

    if (_singletons & id == 0) {
      return _grantees[id];
    }

    address singleton = _addresses[id];
    if (singleton == address(0)) {
      return _grantees[id];
    }

    address[] storage grantees = _grantees[id];

    addrList = new address[](1 + grantees.length);
    addrList[0] = singleton;
    for (uint256 i = 1; i < addrList.length; i++) {
      addrList[i] = grantees[i - 1];
    }
    return addrList;
  }

  function roleActiveGrantees(uint256 id)
    external
    view
    returns (address[] memory addrList, uint256 count)
  {
    require(id.isPowerOf2nz(), 'only one role is allowed');

    address addr;
    if (_singletons & id != 0) {
      addr = _addresses[id];
    }

    address[] storage grantees = _grantees[id];

    if (addr == address(0)) {
      addrList = new address[](grantees.length);
    } else {
      addrList = new address[](1 + grantees.length);
      addrList[0] = addr;
      count++;
    }

    for (uint256 i = 0; i < grantees.length; i++) {
      addr = grantees[i];
      if (_masks[addr] & id != 0) {
        addrList[count] = addr;
        count++;
      }
    }
    return (addrList, count);
  }

  /**
   * @dev Sets a sigleton address, replaces previous value
   * IMPORTANT Use this function carefully, as it does a hard replacement
   * @param id The id
   * @param newAddress The address to set
   */
  function setAddress(uint256 id, address newAddress) public override onlyAdmin {
    require(_proxies & id == 0, 'use of setAddressAsProxy is required');
    _internalSetAddress(id, newAddress);
    emit AddressSet(id, newAddress, false);
  }

  function _internalSetAddress(uint256 id, address newAddress) private {
    require(id.isPowerOf2nz(), 'invalid singleton id');
    if (_singletons & id == 0) {
      require(_nonSingletons & id == 0, 'id is not a singleton');
      _singletons |= id;
      console.log('_internalSetAddress', newAddress, id);
    }

    address prev = _addresses[id];
    if (prev != address(0)) {
      _masks[prev] = _masks[prev] & ~id;
    }
    if (newAddress != address(0)) {
      _masks[newAddress] = _masks[newAddress] | id;
    }
    _addresses[id] = newAddress;
  }

  /**
   * @dev Returns a singleton address by id
   * @return addr The address
   */
  function getAddress(uint256 id) public view override returns (address addr) {
    addr = _addresses[id];

    if (addr == address(0)) {
      require(id.isPowerOf2nz(), 'invalid singleton id');
      require((_singletons & id != 0) || (_nonSingletons & id == 0), 'id is not a singleton');
    }
    return addr;
  }

  function isAddress(uint256 id, address addr) public view returns (bool) {
    // require(id.isPowerOf2nz(), 'only singleton id is accepted');
    return _masks[addr] & id != 0;
  }

  function markProxies(uint256 id) external onlyAdmin {
    _proxies |= id;
  }

  function unmarkProxies(uint256 id) external onlyAdmin {
    _proxies &= ~id;
  }

  /**
   * @dev General function to update the implementation of a proxy registered with
   * certain `id`. If there is no proxy registered, it will instantiate one and
   * set as implementation the `implementationAddress`
   * IMPORTANT Use this function carefully, only for ids that don't have an explicit
   * setter function, in order to avoid unexpected consequences
   * @param id The id
   * @param implementationAddress The address of the new implementation
   */
  function setAddressAsProxy(uint256 id, address implementationAddress) public override onlyAdmin {
    _updateImpl(
      id,
      implementationAddress,
      abi.encodeWithSignature('initialize(address)', address(this))
    );
    emit AddressSet(id, implementationAddress, true);
  }

  function setAddressAsProxyWithInit(
    uint256 id,
    address implementationAddress,
    bytes calldata params
  ) public override onlyAdmin {
    _updateImpl(id, implementationAddress, params);
    emit AddressSet(id, implementationAddress, true);
  }

  /**
   * @dev Internal function to update the implementation of a specific proxied component of the protocol
   * - If there is no proxy registered in the given `id`, it creates the proxy setting `newAdress`
   *   as implementation and calls a function on the proxy.
   * - If there is already a proxy registered, it updates the implementation to `newAddress` by
   *   the upgradeToAndCall() of the proxy.
   * @param id The id of the proxy to be updated
   * @param newAddress The address of the new implementation
   * @param params The address of the new implementation
   **/
  function _updateImpl(
    uint256 id,
    address newAddress,
    bytes memory params
  ) private {
    require(id.isPowerOf2nz(), 'invalid singleton id');
    address payable proxyAddress = payable(getAddress(id));

    if (proxyAddress != address(0)) {
      InitializableImmutableAdminUpgradeabilityProxy(proxyAddress).upgradeToAndCall(
        newAddress,
        params
      );
      return;
    }

    proxyAddress = payable(address(_createProxy(address(this), newAddress, params)));
    _internalSetAddress(id, proxyAddress);
    _proxies |= id;
    emit ProxyCreated(id, proxyAddress);
  }

  function _createProxy(
    address adminAddress,
    address implAddress,
    bytes memory params
  ) private returns (InitializableImmutableAdminUpgradeabilityProxy) {
    InitializableImmutableAdminUpgradeabilityProxy proxy =
      new InitializableImmutableAdminUpgradeabilityProxy(adminAddress);
    proxy.initialize(implAddress, params);
    return proxy;
  }

  function createProxy(
    address adminAddress,
    address implAddress,
    bytes calldata params
  ) public override returns (IProxy) {
    return _createProxy(adminAddress, implAddress, params);
  }
}

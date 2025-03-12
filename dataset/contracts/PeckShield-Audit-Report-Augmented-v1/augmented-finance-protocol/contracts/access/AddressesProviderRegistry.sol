// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';
import {IAddressesProviderRegistry} from '../interfaces/IAddressesProviderRegistry.sol';
import {Errors} from '../tools/Errors.sol';

/**
 * @title AddressesProviderRegistry contract
 * @dev Main registry of AddressesProvider of multiple protocol's markets
 * - Used for indexing purposes of protocol's markets
 * - The id assigned to an AddressesProvider refers to the market it is connected with,
 *   for example with `1` for the first market, `2` for the next one, etc
 **/
contract AddressesProviderRegistry is Ownable, IAddressesProviderRegistry {
  struct Entry {
    uint256 id;
    uint16 index;
  }
  mapping(address => Entry) private _index;
  address[] private _providers;

  address private _oneTimeRegistrar;
  uint256 private _oneTimeId;

  function setOneTimeRegistrar(address registrar, uint256 expectedId) external override onlyOwner {
    _oneTimeId = expectedId;
    _oneTimeRegistrar = registrar;
  }

  function renounceOneTimeRegistrar() external override {
    if (_oneTimeRegistrar == _msgSender()) {
      _oneTimeRegistrar = address(0);
    }
  }

  function getOneTimeRegistrar() external view override returns (address user, uint256 expectedId) {
    if (_oneTimeRegistrar == address(0)) {
      return (address(0), 0);
    }
    return (_oneTimeRegistrar, _oneTimeId);
  }

  /**
   * @dev Returns the list of registered addresses provider
   * @return activeProviders - list of addresses provider, potentially containing address(0) elements
   **/
  function getAddressesProvidersList()
    external
    view
    override
    returns (address[] memory activeProviders)
  {
    return _providers;
  }

  /**
   * @dev Registers an addresses provider
   * @param provider The address of the new AddressesProvider
   * @param id The id for the new AddressesProvider, referring to the market it belongs to
   **/
  function registerAddressesProvider(address provider, uint256 id) external override {
    if (_msgSender() == _oneTimeRegistrar) {
      require(_oneTimeId == 0 || _oneTimeId == id, Errors.LPAPR_INVALID_ADDRESSES_PROVIDER_ID);
      _oneTimeRegistrar = address(0);
    } else {
      require(_msgSender() == owner(), Errors.TXT_OWNABLE_CALLER_NOT_OWNER);
      require(id != 0, Errors.LPAPR_INVALID_ADDRESSES_PROVIDER_ID);
    }

    require(provider != address(0), Errors.LPAPR_PROVIDER_NOT_REGISTERED);

    if (_index[provider].index > 0) {
      _index[provider].id = id;
    } else {
      require(_providers.length < type(uint16).max);
      _providers.push(provider);
      _index[provider] = Entry(id, uint16(_providers.length));
    }

    emit AddressesProviderRegistered(provider);
  }

  /**
   * @dev Removes a AddressesProvider from the list of registered addresses provider
   * @param provider The AddressesProvider address
   **/
  function unregisterAddressesProvider(address provider) external override onlyOwner {
    uint256 idx = _index[provider].index;
    require(idx != 0, Errors.LPAPR_PROVIDER_NOT_REGISTERED);

    delete (_index[provider]);
    if (idx == _providers.length) {
      _providers.pop();
    } else {
      _providers[idx - 1] = address(0);
    }
    for (
      ;
      _providers.length > 0 && _providers[_providers.length - 1] == address(0);
      _providers.pop()
    ) {}

    emit AddressesProviderUnregistered(provider);
  }

  /**
   * @dev Returns the id on a registered AddressesProvider
   * @return The id or 0 if the AddressesProvider is not registered
   */
  function getAddressesProviderIdByAddress(address provider)
    external
    view
    override
    returns (uint256)
  {
    return _index[provider].id;
  }
}

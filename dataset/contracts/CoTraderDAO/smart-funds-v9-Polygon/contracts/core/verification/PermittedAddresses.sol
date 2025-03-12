pragma solidity ^0.6.12;

import "../../zeppelin-solidity/contracts/access/Ownable.sol";

/*
  The contract determines which addresses are permitted
*/
contract PermittedAddresses is Ownable {
  event AddNewPermittedAddress(address newAddress, uint256 addressType);
  event RemovePermittedAddress(address Address);

  // Mapping to permitted addresses
  mapping (address => bool) public permittedAddresses;
  mapping (address => uint256) public addressesTypes;

  enum Types { EMPTY, EXCHANGE_PORTAL, POOL_PORTAL, DEFI_PORTAL, STABLE_COIN }

  /**
  * @dev contructor
  *
  * @param _exchangePortal      Exchange portal contract
  * @param _stableCoin          Stable coins addresses to permitted
  */
  constructor(
    address _exchangePortal,
    address _stableCoin
  ) public
  {
    _enableAddress(_exchangePortal, uint256(Types.EXCHANGE_PORTAL));
    _enableAddress(_stableCoin, uint256(Types.STABLE_COIN));
  }


  /**
  * @dev adding a new address to permittedAddresses
  *
  * @param _newAddress    The new address to permit
  */
  function addNewAddress(address _newAddress, uint256 addressType) public onlyOwner {
    _enableAddress(_newAddress, addressType);
  }

  /**
  * @dev update address type as owner for case if wrong address type was set
  *
  * @param _newAddress    The new address to permit
  */
  function updateAddressType(address _newAddress, uint256 addressType) public onlyOwner {
    addressesTypes[_newAddress] = addressType;
  }

  /**
  * @dev Disables an address, meaning SmartFunds will no longer be able to connect to them
  * if they're not already connected
  *
  * @param _address    The address to disable
  */
  function disableAddress(address _address) public onlyOwner {
    permittedAddresses[_address] = false;
    emit RemovePermittedAddress(_address);
  }

  /**
  * @dev Enables/disables an address
  *
  * @param _newAddress    The new address to set
  * @param addressType    Address type
  */
  function _enableAddress(address _newAddress, uint256 addressType) private {
    permittedAddresses[_newAddress] = true;
    addressesTypes[_newAddress] = addressType;

    emit AddNewPermittedAddress(_newAddress, addressType);
  }

  /**
  * @dev check if input address has the same type as addressType
  */
  function isMatchTypes(address _address, uint256 addressType) public view returns(bool){
    return addressesTypes[_address] == addressType;
  }

  /**
  * @dev return address type
  */
  function getType(address _address) public view returns(uint256){
    return addressesTypes[_address];
  }
}

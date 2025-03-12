interface PermittedAddressesInterface {
  function permittedAddresses(address _address) external view returns(bool);
  function addressesTypes(address _address) external view returns(string memory);
  function isMatchTypes(address _address, uint256 addressType) external view returns(bool);
}

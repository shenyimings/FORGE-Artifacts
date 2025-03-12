pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

contract AAVELendingPoolAddressesProvider {

  mapping(bytes32 => address) private _addresses;
  bytes32 private constant LENDING_POOL = 'LENDING_POOL';

  function getAddress(bytes32 id) public view  returns (address) {
    return _addresses[id];
  }

  function getLendingPool() external view  returns (address) {
    return getAddress(LENDING_POOL);
  }

  function setLendingPool(address pool) external  {
    _addresses[LENDING_POOL] =pool;
  }
}

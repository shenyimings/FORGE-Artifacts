pragma solidity 0.8.10;

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
    function getReserveDataProvider() external view returns (address);

}

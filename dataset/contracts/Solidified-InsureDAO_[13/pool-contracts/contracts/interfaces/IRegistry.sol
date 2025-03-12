pragma solidity ^0.6.0;

interface IRegistry {
    function supportMarket(address _market) external;

    function isListed(address _market) external view returns (bool);

    function getCDS(address _address) external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IServerPriceFeed {

    //public read
    function getPrice(address _token) external view returns (uint256, uint256);
    function getPriceSpreadFactoe(address _token) external view returns (uint256, uint256, uint256);

    function setPriceSingleVerify(address _updater, address _token, uint256 _price, uint8 _priceType, uint256 _timestamp, bytes memory _updaterSignedMsg) external returns (bool);
    function updateTokenInfo(address _updater, address _token, uint256[] memory _paras, uint256 _timestamp, bytes memory _updaterSignedMsg) external returns (bool);
    function setPriceBitsVerify(address _updater, uint256[] memory _priceBits, uint256 _timestamp, bytes memory _updaterSignedMsg) external returns (bool);

    function setPriceSpreadFactor(address _token, uint256 _longPSF, uint256 _shortPSF, uint256 _timestamp) external;

    function setPricesWithBits(uint256[] memory _priceBits, uint256 _timestamp) external;

    function setPricesWithBitsSingle(address _token, uint256 _priceBits, uint256 _timestamp) external;

    function setPriceSingle(address _token, uint256 _price, uint256 _timestamp) external;
    function setPricesWithBitsVerify(uint256[] memory _priceBits, uint256 _timestamp) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ILiquityPriceFeed {
    event LastGoodPriceUpdated(uint256 _lastGoodPrice);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PriceFeedStatusChanged(uint8 newStatus);

    function DECIMAL_PRECISION() external view returns (uint256);

    function ETHUSD_TELLOR_REQ_ID() external view returns (uint256);

    function MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND() external view returns (uint256);

    function MAX_PRICE_DIFFERENCE_BETWEEN_ORACLES() external view returns (uint256);

    function NAME() external view returns (string memory);

    function TARGET_DIGITS() external view returns (uint256);

    function TELLOR_DIGITS() external view returns (uint256);

    function TIMEOUT() external view returns (uint256);

    function fetchPrice() external returns (uint256);

    function isOwner() external view returns (bool);

    function lastGoodPrice() external view returns (uint256);

    function owner() external view returns (address);

    function priceAggregator() external view returns (address);

    function setAddresses(address _priceAggregatorAddress, address _tellorCallerAddress) external;

    function status() external view returns (uint8);

    function tellorCaller() external view returns (address);
}

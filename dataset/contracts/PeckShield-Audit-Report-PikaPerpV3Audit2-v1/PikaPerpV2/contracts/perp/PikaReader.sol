pragma solidity ^0.8.0;

import "./IFundingManager.sol";
import "./FundingManager.sol";

contract PikaReader {

    address public pikaPerp;
    address public fundingManager;

    constructor(address _pikaPerp, address _fundingManager) public {
        pikaPerp = _pikaPerp;
        fundingManager = _fundingManager;
    }

    function getOpenInterest(uint256[] memory _productIds) external view returns(uint256[] memory openInterests) {
        uint256 length = _productIds.length;
        openInterests = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            (,,,,uint256 longOI, uint256 shortOI,,,)= IPikaPerp(pikaPerp).getProduct(_productIds[i]);
            openInterests[i] = longOI + shortOI;
        }
    }

    function getFundingRates(uint256[] memory _productIds) external view returns(int256[] memory fundingRates) {
        uint256 length = _productIds.length;
        fundingRates = new int256[](length);
        for (uint256 i = 0; i < length; i++) {
            fundingRates[i] = IFundingManager(fundingManager).getFundingRate(_productIds[i]);
        }
    }

    function getFundingData(
        uint256 productId
    ) external view returns(
        int256 fundingPayment,
        int256 fundingRate,
        uint256 lastUpdateTimestamp
    ) {
        fundingPayment = IFundingManager(fundingManager).getFunding(productId);
        fundingRate = IFundingManager(fundingManager).getFundingRate(productId);
        lastUpdateTimestamp = FundingManager(fundingManager).lastUpdateTimes(productId);
    }
}
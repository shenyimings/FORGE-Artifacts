// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVaultPriceFeedV3Fast {   
    function getPrimaryPrice(address _token) external view  returns (uint256, bool, uint256);
    function setTokenChainlinkConfig(address _token, address _chainlinkContract, bool) external;

    function adjustmentBasisPoints(address _token) external view returns (uint256);
    function isAdjustmentAdditive(address _token) external view returns (bool);
    function setAdjustment(address _token, bool _isAdditive, uint256 _adjustmentBps) external;
    function setSpreadBasisPoints(address _token, uint256 _spreadBasisPoints) external;
    function getPrice(address _token, bool _maximise,bool,bool) external view returns (uint256);
    function getOrigPrice(address _token) external view returns (uint256);
    
    
    function priceVariancePer1Million(address _token) external view returns (uint256); //100 for 1%
    function getPriceSpreadImpactFactor(address _token) external view returns (uint256, uint256); 
    
}

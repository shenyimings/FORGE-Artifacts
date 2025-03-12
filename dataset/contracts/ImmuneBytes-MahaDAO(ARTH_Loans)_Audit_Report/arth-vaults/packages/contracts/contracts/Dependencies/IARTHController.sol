// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IARTHController {
    function addPool(address pool_address) external;
    function addPools(address[] memory poolAddress) external;
    function removePool(address poolAddress) external;
    function isPool(address pool) external view returns (bool);
    function setMAHAGMUOracle(address oracle) external;
    function setOwner(address _ownerAddress) external;
    function setTimelock(address newTimelock) external;
    function getMAHAPrice() external view returns (uint256);
    function getARTHSupply() external view returns (uint256);
    // function getGlobalCollateralValue() external view returns (uint256);
    // function getGlobalCollateralValue() external view returns (uint256);
    // function arthPools(address pool) external view returns (bool);
    // function getTargetCollateralValue() external view returns (uint256);
    // function getPercentCollateralized() external view returns (uint256);
}
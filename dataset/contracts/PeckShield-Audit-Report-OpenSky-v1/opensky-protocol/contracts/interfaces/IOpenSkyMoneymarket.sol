// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyMoneymarket {
    function depositCall(uint256 amount) external payable;

    function withdrawCall(uint256 amount) external;

    function getBalance(address account) external view returns (uint256);
    
    function getSupplyRate() external view returns (uint256);

}

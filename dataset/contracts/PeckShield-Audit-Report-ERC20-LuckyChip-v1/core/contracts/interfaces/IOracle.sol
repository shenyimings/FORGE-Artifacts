// SPDX-License-Identifier: MIT
  
pragma solidity 0.6.12;

interface IOracle {
    function update(address tokenA, address tokenB) external returns (bool);
    function getQuantity(address token, uint256 amount) external view returns (uint256);
    function getLpTokenValue(address _lpToken, uint256 _amount) external view returns (uint256 value);
    function getBankerTokenValue(address _bankerToken, uint256 _amount) external view returns (uint256 value);
    function getQuantityBUSD(address token, uint256 amount) external view returns (uint256);
}

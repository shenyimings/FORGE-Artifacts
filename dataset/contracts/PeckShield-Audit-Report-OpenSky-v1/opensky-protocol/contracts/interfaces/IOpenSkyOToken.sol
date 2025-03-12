// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IOpenSkyOToken is IERC20 {
    function mint(
        address account,
        uint256 amount,
        uint256 index
    ) external;

    function burn(
        address account,
        uint256 amount,
        uint256 index
    ) external;
    
    function mintToTreasury(uint256 amount, uint256 index) external;
  
    function deposit(uint256 amount) external payable;
  
    function withdraw(uint256 amount, address to) external;
    
    function scaledBalanceOf(address account) external view returns (uint256);
  
    function principleBalanceOf(address account) external view returns (uint256);
  
    function scaledTotalSupply() external view returns (uint256);
  
    function principleTotalSupply() external view returns (uint256);

    function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);
}

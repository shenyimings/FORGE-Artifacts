// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ILP {
    function asset() external view returns (uint256);

    function liability() external view returns (uint256);

    function decimals() external view returns (uint8);

    function updateAssetLiability(uint256 assetAmount, bool assetIncrease, uint256 liabilityAmount, bool liabilityIncrease) external;

    function mint(address recipient, address user, uint256 amount) external;

    function burnFrom(address account, address user, uint256 amount) external;

    function withdrawUnderlyer(address recipient, uint256 amount) external;

    function approve(address spender, uint256 amount) external returns (bool);
    
    function totalSupply() external view returns (uint256);

    function getEmissionWeightage() external view returns (uint256);

    function resetPeriod() external;

    function getLR() external view returns (uint256);

    function getMaxLR() external view returns (uint256);
}
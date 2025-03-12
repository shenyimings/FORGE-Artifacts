// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface INeuronPool is IERC20 {
    function token() external view returns (address);

    function claimInsurance() external; // NOTE: Only yDelegatedVault implements this

    function pricePerShare() external view returns (uint256);

    function depositAll(address _enterToken) external payable returns (uint256);

    function deposit(address _enterToken, uint256 _amount) external payable returns (uint256);

    function withdrawAll(address _withdrawableToken) external;

    function withdraw(address _withdrawableToken, uint256 _shares) external;

    function earn() external;

    function decimals() external view returns (uint8);

    function getSupportedTokens() external view returns (address[] memory tokens);


}

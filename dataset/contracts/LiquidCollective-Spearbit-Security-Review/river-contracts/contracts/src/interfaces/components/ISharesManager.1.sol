//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ISharesManagerV1 is IERC20 {
    error BalanceTooLow();
    error AllowanceTooLow(address _from, address _operator, uint256 _allowance, uint256 _value);
    error NullTransfer();

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function totalUnderlyingSupply() external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function balanceOfUnderlying(address _owner) external view returns (uint256 balance);
    function underlyingBalanceFromShares(uint256 shares) external view returns (uint256);
    function sharesFromUnderlyingBalance(uint256 underlyingBalance) external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool success);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface PowerBomb {

    // mapping(address => uint256) deposiedAmount;

    function intialize() external;

    function deposit(IERC20Upgradeable _token, uint256 _amount) external returns(uint256);

    function harvest(IERC20Upgradeable _token) external returns(uint256 _amount);

    function withdraw(IERC20Upgradeable _token, uint256 _shares) external returns(uint256 _tokenAmount);
}
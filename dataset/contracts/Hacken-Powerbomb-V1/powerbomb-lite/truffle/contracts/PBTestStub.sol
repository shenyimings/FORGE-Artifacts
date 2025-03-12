// users' preferred means to deposit
// users' preferred means to withdraw

// get current btc balance available
// get current eth balance available

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract PowerBomb {

    function getDeposits() public view returns (uint256) {
        return 0;
    }

    function getYield(uint256 tokenType) public view returns (uint256) {
        if (tokenType == 0) {
            return 150;
        } else if (tokenType == 1) {
            return 250;
        } else {
            return 350;
        }
    }

    function deposit(IERC20Upgradeable _token, IERC20Upgradeable _interestToken, uint256 _amount) external returns(uint256) {
        return 0;
    }

    function harvest() external returns(uint256 _amount) {
        return 0;
    }

    function withdraw(uint256 _shares) external returns(uint256 _tokenAmount) {
        return 0;
    }
}
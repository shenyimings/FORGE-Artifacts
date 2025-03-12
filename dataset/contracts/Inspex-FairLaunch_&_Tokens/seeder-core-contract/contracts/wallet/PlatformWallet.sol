// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../utils/SafeMath.sol";
import "hardhat/console.sol";
import "../utils/Entities.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PlatformWallet is Ownable, Entities {
    using SafeMath for uint256;

    constructor() {}
    
    function totalNativeBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function totalBalance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getPendingNativeToken(address entityAddress) public view returns (uint256) {
        uint256 balance = totalNativeBalance();
        uint256 percent = _entityPercentage[entityAddress];
        return balance.mul(percent).div(_totalPercentage);
    }

    function getPendingToken(address entityAddress, address token) public view returns (uint256) {
        uint256 balance = totalBalance(token);
        uint256 percent = _entityPercentage[entityAddress];
        return balance.mul(percent).div(_totalPercentage);
    }

    function claimNativeToken() external {
        uint256[] memory _NativeAmounts = new uint256[](_entities.length);

        for (uint256 idx = 0; idx < _entities.length; idx++) {
            _NativeAmounts[idx] = getPendingNativeToken(_entities[idx]);
        } 

        for (uint256 idx = 0; idx < _entities.length; idx++) {
            payable(_entities[idx]).transfer(_NativeAmounts[idx]);

            emit DistributeNative(_entities[idx], _NativeAmounts[idx]);
        }
    }

    function claimToken(address token) external {
        uint256[] memory _tokenAmounts = new uint256[](_entities.length);

        for (uint256 index = 0; index < _entities.length; index++) {
            _tokenAmounts[index] = getPendingToken(_entities[index], token);
        } 

        for (uint256 index = 0; index < _entities.length; index++) {
            IERC20(token).transfer(_entities[index], _tokenAmounts[index]);

            emit DistributeToken(token, _entities[index], _tokenAmounts[index]);
        }
    }

    receive() external payable{}
}
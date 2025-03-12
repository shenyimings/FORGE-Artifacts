// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Limiter is Ownable {

    uint256 private _maxBuy;
    uint256 private _maxSell;
    uint256 private _limitBuy;
    mapping(address => uint256) private _totalBuy;

    constructor(uint256 maxBuy, uint256 maxSell, uint256 limitBuy) {
        _maxBuy = maxBuy;
        _maxSell = maxSell;
        _limitBuy = limitBuy;
    }

    function getMaxBuy() public view returns(uint256) {
        return _maxBuy;
    }

    function getMaxSell() public view returns(uint256) {
        return _maxSell;
    }

    function getLimitBuy() public view returns(uint256) {
        return _limitBuy;
    }

    function isValidBuy(address _sender, uint256 _amount) public view returns(bool) {
        if (_amount > _maxBuy) {
            return false;
        }
        uint256 totalBuyOfAddress = _totalBuy[_sender];
        if (totalBuyOfAddress + _amount > _limitBuy) {
            return false;
        }
        return true;
    }

    function isValidSell(uint256 _amount) public view returns(bool) {
        if (_amount > _maxSell) {
            return false;
        }
        return true;
    }


    function setMaxBuyLimit(uint256 maxBuy) public onlyOwner {
        _maxBuy = maxBuy;
    }

    function setMaxSellLimit(uint256 maxSell) public onlyOwner {
        _maxSell = maxSell;
    }

    function setLimitBuy(uint256 limitBuy) public onlyOwner {
        _limitBuy = limitBuy;
    }

    function onBuySuccess(address _sender, uint256 _amount) public {
        _totalBuy[_sender] += _amount;
    }

    function onSellSuccess(address _sender, uint256 _amount) public {
        uint256 value = _totalBuy[_sender];
        if (value < _amount) {
            _totalBuy[_sender] = 0;
        } else {
            _totalBuy[_sender] = (value - _amount);
        }
    }

    function getAddressTotalBuy(address _sender) public view returns(int256) {
        return int256(_totalBuy[_sender]);
    }
}

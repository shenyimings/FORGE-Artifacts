// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "../DolzCrowdsale.sol";

contract MockDolzCrowdsale is DolzCrowdsale {
    constructor(
        address _token,
        address _wallet,
        uint256 _saleStart,
        uint256 _saleEnd,
        uint256 _withdrawalStart,
        uint256 _withdrawPeriodDuration,
        uint256 _withdrawPeriodNumber,
        uint256 _minBuyValue,
        uint256 _maxTokenAmountPerAddress,
        uint256 _exchangeRate,
        uint256 _referralRewardPercentage,
        uint256 _amountToSell
    )
        DolzCrowdsale(
            _token,
            _wallet,
            _saleStart,
            _saleEnd,
            _withdrawalStart,
            _withdrawPeriodDuration,
            _withdrawPeriodNumber,
            _minBuyValue,
            _maxTokenAmountPerAddress,
            _exchangeRate,
            _referralRewardPercentage,
            _amountToSell
        )
    {}

    function __setSoldAmount(uint256 newSoldAmount) external {
        soldAmount = newSoldAmount;
    }

    function __increaseTimeFrom(uint256 sec) external {
        saleStart -= sec;
        saleEnd -= sec;
        withdrawalStart -= sec;
    }
}

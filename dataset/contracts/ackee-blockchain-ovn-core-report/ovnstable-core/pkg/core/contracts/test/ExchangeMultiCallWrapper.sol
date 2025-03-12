// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../Exchange.sol";


contract ExchangeMultiCallWrapper {

    Exchange public exchange;

    constructor(address _exchange)  {
        exchange = Exchange(_exchange);
    }


    // --- logic

    function buy2(
        address asset,
        address usdPlus,
        uint256 _amount1,
        uint256 _amount2
    ) external {
        IERC20(asset).approve(address(exchange), _amount1);
        exchange.buy(asset, _amount1);
        IERC20(asset).approve(address(exchange), _amount2);
        exchange.buy(asset, _amount2);
    }

    function buyRedeem(
        address asset,
        address usdPlus,
        uint256 _amount1,
        uint256 _amount2
    ) external {
        IERC20(asset).approve(address(exchange), _amount1);
        exchange.buy(asset, _amount1);
        IERC20(usdPlus).approve(address(exchange), _amount2);
        exchange.redeem(asset, _amount2);
    }

    function redeem2(
        address asset,
        address usdPlus,
        uint256 _amount1,
        uint256 _amount2
    ) external {
        IERC20(usdPlus).approve(address(exchange), _amount1);
        exchange.redeem(asset, _amount1);
        IERC20(usdPlus).approve(address(exchange), _amount2);
        exchange.redeem(asset, _amount2);
    }

    function redeemBuy(
        address asset,
        address usdPlus,
        uint256 _amount1,
        uint256 _amount2
    ) external {
        IERC20(usdPlus).approve(address(exchange), _amount1);
        exchange.redeem(asset, _amount1);
        IERC20(asset).approve(address(exchange), _amount2);
        exchange.buy(asset, _amount2);
    }

}

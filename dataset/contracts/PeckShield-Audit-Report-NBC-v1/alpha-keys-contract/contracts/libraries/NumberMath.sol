// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

library NumberMath {
    // CONST
    uint256 internal constant RATIO = 1e6;
    using SafeMathUpgradeable for uint256;

    uint256 internal constant ONE_ETHER = 1 ether;
    uint256 internal constant PRICE_UNIT = 0.1 ether;
    uint256 internal constant NUMBER_UNIT_PER_ONE_ETHER =
        ONE_ETHER / PRICE_UNIT;

    uint256 internal constant PRICE_BTC_PER_TC = 0.000416666666666667 ether; // 1 BTC = 2400 TC
    uint256 internal constant PRICE_TC_PER_BTC = 2400 ether; // 1 BTC = 2400 TC
    uint256 internal constant PRICE_KEYS_DENOMINATOR = 264000;

    uint256 internal constant TS_30_DAYS = 30 days;

    //
    function mulRatio(
        uint256 value,
        uint24 ratio
    ) internal pure returns (uint256) {
        return value.mul(ratio).div(RATIO);
    }

    function divRatio(
        uint256 value,
        uint24 ratio
    ) internal pure returns (uint256) {
        return value.mul(RATIO).div(ratio);
    }

    function mulEther(uint256 value) internal pure returns (uint256) {
        return value.mul(1 ether);
    }

    function divEther(uint256 value) internal pure returns (uint256) {
        return value.div(1 ether);
    }

    function mulPrice(
        uint256 value,
        uint256 rate
    ) internal pure returns (uint256) {
        return value.mul(rate).div(1 ether);
    }

    function getPriceV2(
        uint256 supply,
        uint256 amount
    ) internal pure returns (uint256) {
        // invalid params
        require(supply >= NUMBER_UNIT_PER_ONE_ETHER && amount >= 1, "NM_IP");
        //
        uint256 sum1 = ((supply - NUMBER_UNIT_PER_ONE_ETHER) *
            supply *
            (2 *
                (supply - NUMBER_UNIT_PER_ONE_ETHER) +
                NUMBER_UNIT_PER_ONE_ETHER)) / 6;
        uint256 sum2 = ((supply - NUMBER_UNIT_PER_ONE_ETHER + amount) *
            (supply + amount) *
            (2 *
                (supply - NUMBER_UNIT_PER_ONE_ETHER + amount) +
                NUMBER_UNIT_PER_ONE_ETHER)) / 6;
        uint256 summation = sum2 - sum1;
        return
            (summation * ONE_ETHER) /
            PRICE_KEYS_DENOMINATOR /
            (NUMBER_UNIT_PER_ONE_ETHER *
                NUMBER_UNIT_PER_ONE_ETHER *
                NUMBER_UNIT_PER_ONE_ETHER);
    }

    function getBuyPriceV2(
        uint256 supply,
        uint256 amountX18
    ) internal pure returns (uint256) {
        return
            getPriceV2(supply.div(PRICE_UNIT), amountX18.div(PRICE_UNIT)).add(
                1
            );
    }

    function getBuyPriceV2AfterFee(
        uint24 protocolFeeRatio,
        uint24 playerFeeRatio,
        uint256 supply,
        uint256 amountX18
    ) internal pure returns (uint256) {
        //
        uint256 price = getBuyPriceV2(supply, amountX18);
        uint256 protocolFee = mulRatio(price, protocolFeeRatio);
        uint256 playerFee = mulRatio(price, playerFeeRatio);
        return price.add(protocolFee).add(playerFee);
    }

    function getBuyAmountMaxWithCash(
        uint24 protocolFeeRatio,
        uint24 playerFeeRatio,
        address token,
        uint256 buyPriceAfterFeeMax
    ) internal view returns (uint256) {
        uint256 supply = IERC20Upgradeable(token).totalSupply();
        uint256 amount = 0;
        while (true) {
            uint256 buyPriceAfterFee = getBuyPriceV2AfterFee(
                protocolFeeRatio,
                playerFeeRatio,
                supply,
                amount.add(ONE_ETHER)
            );
            if (buyPriceAfterFee > buyPriceAfterFeeMax) {
                while (true) {
                    buyPriceAfterFee = getBuyPriceV2AfterFee(
                        protocolFeeRatio,
                        playerFeeRatio,
                        supply,
                        amount.add(PRICE_UNIT)
                    );
                    if (buyPriceAfterFee > buyPriceAfterFeeMax) {
                        break;
                    }
                    amount = amount.add(PRICE_UNIT);
                }
                break;
            }
            amount = amount.add(ONE_ETHER);
        }
        return amount;
    }

    function getPaymentMaxFor(
        address token,
        address account,
        address spender
    ) internal view returns (uint256) {
        return
            MathUpgradeable.min(
                IERC20Upgradeable(token).balanceOf(account),
                IERC20Upgradeable(token).allowance(account, spender)
            );
    }

    function getBuyAmountMaxWithCondition(
        address token,
        uint256 amountMax,
        uint256 buyPriceMax,
        uint256 amountBTC
    ) internal view returns (uint256) {
        uint256 supplyUnits = IERC20Upgradeable(token).totalSupply().div(
            PRICE_UNIT
        );
        uint256 amountMaxUnits = amountMax.div(PRICE_UNIT);
        uint256 amountUnits = 0;
        while (true) {
            if (
                getPriceV2(supplyUnits.add(amountUnits.add(10)), 1).mul(
                    NUMBER_UNIT_PER_ONE_ETHER
                ) >
                buyPriceMax ||
                amountUnits.add(10) > amountMaxUnits ||
                getPriceV2(supplyUnits, amountUnits.add(10)) > amountBTC
            ) {
                while (true) {
                    if (
                        getPriceV2(supplyUnits.add(amountUnits.add(1)), 1).mul(
                            NUMBER_UNIT_PER_ONE_ETHER
                        ) >
                        buyPriceMax ||
                        amountUnits.add(1) > amountMaxUnits ||
                        getPriceV2(supplyUnits, amountUnits.add(1)) > amountBTC
                    ) {
                        break;
                    }
                    amountUnits = amountUnits.add(1);
                }
                break;
            }
            amountUnits = amountUnits.add(10);
        }
        return amountUnits.mul(PRICE_UNIT);
    }
}

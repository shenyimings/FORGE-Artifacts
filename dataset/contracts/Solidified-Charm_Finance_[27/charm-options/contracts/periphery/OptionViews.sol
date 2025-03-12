// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../OptionMarket.sol";

contract OptionViews {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function getBuyOptionCost(
        OptionMarket market,
        bool isLongToken,
        uint256 strikeIndex,
        uint256 optionsOut
    ) external view returns (uint256) {
        uint256 n = market.numStrikes();
        uint256[] memory longOptionsOut = new uint256[](n);
        uint256[] memory shortOptionsOut = new uint256[](n);
        (isLongToken ? longOptionsOut : shortOptionsOut)[strikeIndex] = optionsOut;
        return getBuyCost(market, longOptionsOut, shortOptionsOut, 0);
    }

    function getSellOptionCost(
        OptionMarket market,
        bool isLongToken,
        uint256 strikeIndex,
        uint256 optionsIn
    ) external view returns (uint256) {
        uint256 n = market.numStrikes();
        uint256[] memory longOptionsIn = new uint256[](n);
        uint256[] memory shortOptionsIn = new uint256[](n);
        (isLongToken ? longOptionsIn : shortOptionsIn)[strikeIndex] = optionsIn;
        return getSellCost(market, longOptionsIn, shortOptionsIn, 0);
    }

    function getDepositCost(OptionMarket market, uint256 lpSharesOut) external view returns (uint256) {
        uint256 n = market.numStrikes();
        uint256[] memory longOptionsOut = new uint256[](n);
        uint256[] memory shortOptionsOut = new uint256[](n);
        return getBuyCost(market, longOptionsOut, shortOptionsOut, lpSharesOut);
    }

    function getWithdrawCost(OptionMarket market, uint256 lpSharesIn) external view returns (uint256) {
        uint256 n = market.numStrikes();
        uint256[] memory longOptionsIn = new uint256[](n);
        uint256[] memory shortOptionsIn = new uint256[](n);
        return getSellCost(market, longOptionsIn, shortOptionsIn, lpSharesIn);
    }

    function getBuyCost(
        OptionMarket market,
        uint256[] memory longOptionsOut,
        uint256[] memory shortOptionsOut,
        uint256 lpSharesOut
    ) public view returns (uint256 cost) {
        require(!market.isExpired(), "Already expired");

        uint256 lpSupply = market.totalSupply();
        uint256[] memory longSupplies = getLongSupplies(market);
        uint256[] memory shortSupplies = getShortSupplies(market);

        uint256 costBefore = _getLmsrCost(market, longSupplies, shortSupplies, lpSupply);

        // need to recalculate as mutated by calcLmsrCost
        longSupplies = getLongSupplies(market);
        shortSupplies = getShortSupplies(market);
        uint256 n = market.numStrikes();
        for (uint256 i = 0; i < n; i++) {
            longSupplies[i] = longSupplies[i].add(longOptionsOut[i]);
            shortSupplies[i] = shortSupplies[i].add(shortOptionsOut[i]);
        }
        lpSupply = lpSupply.add(lpSharesOut);

        cost = _getLmsrCost(market, longSupplies, shortSupplies, lpSupply);
        if (lpSharesOut > 0) {
            cost = cost.add(_getPoolValue(market, lpSharesOut).add(1));
        }
        cost = cost.add(_getFee(market, longOptionsOut, shortOptionsOut));
        cost = cost.sub(costBefore);
    }

    function getSellCost(
        OptionMarket market,
        uint256[] memory longOptionsIn,
        uint256[] memory shortOptionsIn,
        uint256 lpSharesIn
    ) public view returns (uint256 cost) {
        uint256 lpSupply = market.totalSupply();
        uint256[] memory longSupplies = getLongSupplies(market);
        uint256[] memory shortSupplies = getShortSupplies(market);

        if (market.isExpired()) {
            cost = _getPayoff(market, longSupplies, shortSupplies);
        } else {
            cost = _getLmsrCost(market, longSupplies, shortSupplies, lpSupply);
        }

        // need to recalculate as mutated by calcLmsrCost
        longSupplies = getLongSupplies(market);
        shortSupplies = getShortSupplies(market);

        uint256 n = market.numStrikes();
        for (uint256 i = 0; i < n; i++) {
            longSupplies[i] = longSupplies[i].sub(longOptionsIn[i]);
            shortSupplies[i] = shortSupplies[i].sub(shortOptionsIn[i]);
        }
        lpSupply = lpSupply.sub(lpSharesIn);

        if (market.isExpired()) {
            cost = cost.sub(_getPayoff(market, longSupplies, shortSupplies));
        } else {
            cost = cost.sub(_getLmsrCost(market, longSupplies, shortSupplies, lpSupply));
        }

        cost = cost.add(_getPoolValue(market, lpSharesIn));
    }

    function getStrikePrices(OptionMarket market) public view returns (uint256[] memory strikePrices) {
        uint256 n = market.numStrikes();
        strikePrices = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            strikePrices[i] = market.strikePrices(i);
        }
    }

    function getLongSupplies(OptionMarket market) public view returns (uint256[] memory longSupplies) {
        uint256 n = market.numStrikes();
        longSupplies = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            longSupplies[i] = market.longTokens(i).totalSupply();
        }
    }

    function getShortSupplies(OptionMarket market) public view returns (uint256[] memory shortSupplies) {
        uint256 n = market.numStrikes();
        shortSupplies = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            shortSupplies[i] = market.shortTokens(i).totalSupply();
        }
    }

    function _getLmsrCost(
        OptionMarket market,
        uint256[] memory longSupplies,
        uint256[] memory shortSupplies,
        uint256 lpSupply
    ) internal view returns (uint256) {
        uint256[] memory quantities = OptionMath.calcQuantities(
            getStrikePrices(market),
            market.isPut(),
            longSupplies,
            shortSupplies
        );
        return OptionMath.calcLmsrCost(quantities, lpSupply);
    }

    function _getPayoff(
        OptionMarket market,
        uint256[] memory longSupplies,
        uint256[] memory shortSupplies
    ) internal view returns (uint256) {
        return
            OptionMath.calcPayoff(
                getStrikePrices(market),
                market.expiryPrice(),
                market.isPut(),
                longSupplies,
                shortSupplies
            );
    }

    function _getFee(
        OptionMarket market,
        uint256[] memory longOptionsOut,
        uint256[] memory shortOptionsOut
    ) internal view returns (uint256) {
        uint256 scale = market.SCALE();
        bool isPut = market.isPut();

        uint256 total;
        uint256 n = market.numStrikes();
        for (uint256 i = 0; i < n; i++) {
            if (isPut) {
                uint256 strike = market.strikePrices(i);
                total = total.add(longOptionsOut[i].mul(strike).div(scale));
                total = total.add(shortOptionsOut[i].mul(strike).div(scale));
            } else {
                total = total.add(longOptionsOut[i]);
                total = total.add(shortOptionsOut[i]);
            }
        }
        return total.mul(market.tradingFee()).div(scale);
    }

    function _getPoolValue(OptionMarket market, uint256 lpShares) internal view returns (uint256) {
        uint256 totalSupply = market.totalSupply();
        if (totalSupply == 0) {
            return 0;
        }
        return market.poolValue().mul(lpShares).div(totalSupply);
    }
}

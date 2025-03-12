// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./libraries/ABDKMath64x64.sol";

library OptionMath {
    using SafeMath for uint256;

    uint256 public constant SCALE = 1e18;

    /**
     * Converts total supplies of options into the tokenized payoff quantities used
     * by the LMSR
     *
     * For puts, multiply by strike price since option quantity is in terms of the
     * underlying, but lmsr quantities should be in terms of the strike currency
     */
    function calcQuantities(
        uint256[] memory strikePrices,
        bool isPut,
        uint256[] memory longSupplies,
        uint256[] memory shortSupplies
    ) internal pure returns (uint256[] memory) {
        uint256 n = strikePrices.length;
        require(longSupplies.length == n, "Lengths do not match");
        require(shortSupplies.length == n, "Lengths do not match");

        // this mutates the method arguments, but costs less gas
        if (isPut) {
            for (uint256 i = 0; i < n; i++) {
                longSupplies[i] = longSupplies[i].mul(strikePrices[i]).div(SCALE);
                shortSupplies[i] = shortSupplies[i].mul(strikePrices[i]).div(SCALE);
            }
        }

        // swap shortSupplies and longSupplies for puts
        uint256[] memory leftSupplies = isPut ? shortSupplies : longSupplies;
        uint256[] memory rightSupplies = isPut ? longSupplies : shortSupplies;

        uint256[] memory quantities = new uint256[](n + 1);

        // set quantities[0] = sum(rightSupplies)
        for (uint256 i = 0; i < n; i++) {
            quantities[0] = quantities[0].add(rightSupplies[i]);
        }

        // set quantities[i] = leftSupplies[:i] + rightSupplies[i:]
        for (uint256 i = 0; i < n; i++) {
            quantities[i + 1] = quantities[i].add(leftSupplies[i]).sub(rightSupplies[i]);
        }
        return quantities;
    }

    /**
     * Calculates the LMSR cost function
     *
     *   C(q_1, ..., q_n) = b * log(exp(q_1 / b) + ... + exp(q_n / b))
     *
     * where
     *
     *   q_i = total supply of ith tokenized payoff
     *   b = liquidity parameter
     *
     * An equivalent expression for C is used to avoid overflow when calculating exponentials
     *
     *   C(q_1, ..., q_n) = m + b * log(exp((q_1 - m) / b) + ... + exp((q_n - m) / b))
     *
     * where
     *
     *   m = max(q_1, ..., q_n)
     */
    function calcLmsrCost(uint256[] memory quantities, uint256 b) internal pure returns (uint256) {
        uint256 maxQuantity = quantities[0];
        for (uint256 i = 1; i < quantities.length; i++) {
            maxQuantity = Math.max(maxQuantity, quantities[i]);
        }

        // cost converges to max(q) as b tends to 0
        if (b == 0) {
            return maxQuantity;
        }

        int128 sumExp;
        for (uint256 i = 0; i < quantities.length; i++) {
            // max(q) - q_i
            uint256 diff = maxQuantity.sub(quantities[i]);

            // (max(q) - q_i) / b
            int128 div = ABDKMath64x64.divu(diff, b);

            // exp((q_i - max(q)) / b)
            int128 exp = ABDKMath64x64.exp(ABDKMath64x64.neg(div));
            sumExp = ABDKMath64x64.add(sumExp, exp);
        }

        // log(sumExp)
        int128 log = ABDKMath64x64.ln(sumExp);

        // b * log(sumExp) + max(q)
        return ABDKMath64x64.mulu(log, b).add(maxQuantity);
    }

    /**
     * Calculate total payoff of all outstanding options
     *
     * This value will decrease as options are redeemed
     *
     * For calls, divide by expiry price since payoff should be in terms of the
     * `baseToken`
     */
    function calcPayoff(
        uint256[] memory strikePrices,
        uint256 expiryPrice,
        bool isPut,
        uint256[] memory longSupplies,
        uint256[] memory shortSupplies
    ) internal pure returns (uint256) {
        require(longSupplies.length == strikePrices.length, "Lengths do not match");
        require(shortSupplies.length == strikePrices.length, "Lengths do not match");

        if (expiryPrice == 0) {
            return 0;
        }

        uint256 payoff;
        for (uint256 i = 0; i < strikePrices.length; i++) {
            uint256 strikePrice = strikePrices[i];

            if (isPut && expiryPrice < strikePrice) {
                // put payoff = max(K - S, 0)
                payoff = payoff.add(longSupplies[i].mul(strikePrice.sub(expiryPrice)));
            } else if (!isPut && expiryPrice > strikePrice) {
                // call payoff = max(S - K, 0)
                payoff = payoff.add(longSupplies[i].mul(expiryPrice.sub(strikePrice)));
            }

            // short payoff = min(S, K)
            payoff = payoff.add(shortSupplies[i].mul(Math.min(expiryPrice, strikePrice)));
        }
        return payoff.div(isPut ? SCALE : expiryPrice);
    }
}

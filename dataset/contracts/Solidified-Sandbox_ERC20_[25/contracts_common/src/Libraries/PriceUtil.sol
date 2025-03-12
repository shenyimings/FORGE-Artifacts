pragma solidity ^0.5.2;

library PriceUtil {
    function calculateCurrentPrice(
        uint256 startingPrice,
        uint256 endingPrice,
        uint256 duration,
        uint256 secondsPassed
    ) internal pure returns (uint256) {
        if (secondsPassed > duration) {
            return endingPrice;
        }
        int256 totalPriceChange = int256(endingPrice) - int256(startingPrice);
        int256 currentPriceChange = (totalPriceChange * int256(secondsPassed)) /
            int256(duration);

        return uint256(int256(startingPrice) + currentPriceChange);
    }

    function calculateTax(uint256 _price, uint256 _tax)
        internal
        pure
        returns (uint256)
    {
        // _tax < 10000, so the result will be <= price
        return (_price * _tax) / 10000;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./SklLand.sol";

contract SklPhases is SklLand {

    using SafeMath for uint256;

    uint[5] public PHASES_PRICES = [50, 75, 100, 150, 300];

    function getMaxSupply() public pure returns (uint) {
        return 10000;
    }

    function getCurrentPriceUSD() public view returns (uint) {
        return PHASES_PRICES[_getPhaseWithOffset(0)];
    }

    function getCurrentPrice() public view returns (uint) {
        return getCurrentPriceUSD() * (10 ** 18) / _getConversationRate() * (10 ** 8);
    }

    function getCurrentPhase() external view returns (uint) {
        return _getPhaseWithOffset(0);
    }

    function getPriceForLands(uint _number) public view returns (uint) {
        require(totalSupply().add(_number) <= getMaxSupply());
        uint _sum = 0;

        for (uint _i = 0; _i < _number; _i++) {
            _sum = _sum.add(PHASES_PRICES[_getPhaseWithOffset(_i)]);
        }

        return _sum * (10 ** 18) / _getConversationRate() * (10 ** 8);
    }

    function _getPhaseWithOffset(uint _number) private view returns (uint) {
        uint totalSupplyWithLands = totalSupply().add(_number);

        // each phase is 2000 nfts
        return totalSupplyWithLands / 2000;
    }

    function _getConversationRate() private view returns (uint) {
        (,int price,,,) = conversionRate.latestRoundData();

        return uint(price);
    }

}

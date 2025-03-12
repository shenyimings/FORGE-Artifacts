//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IYESPriceOracle.sol";
import "./libraries/math/MathUtils.sol";
import "./modules/access/Ownable.sol";
import "./modules/amm/interfaces/IUniswapV2Oracle.sol";

contract YESPriceOracle is IYESPriceOracle, Ownable {

    using MathUtils for uint[];

    bool public constant override isPriceOracle = true;

    IUniswapV2Oracle public swapOracle;
    address public kkub;
    address public yesToken;

    address[] public stableCoins;

    constructor(IUniswapV2Oracle swapOracle_, address kkub_, address yesToken_) {
        swapOracle = swapOracle_;
        kkub = kkub_;
        yesToken = yesToken_;
    }

    function _addStableCoin(address stableCoin) public onlyOwner {
        getLatestPrice(stableCoin);
        stableCoins.push(stableCoin);
        emit StableCoinAdded(stableCoin, stableCoins.length - 1);
    }

    function _removeStableCoin(uint index) public onlyOwner {
        uint len = stableCoins.length;
        require(index < len, "YESPriceOracle: exceed array length");

        address stableCoin = stableCoins[index];

        stableCoins[index] = stableCoins[len - 1];
        stableCoins.pop();

        emit StableCoinRemoved(stableCoin, index);
    }

    function getYESPrice() public view override returns (uint) {
        uint[] memory prices = new uint[](stableCoins.length);

        for (uint i = 0; i < stableCoins.length; i++) {
            prices[i] = getLatestPrice(stableCoins[i]);
        }

        return prices.median(prices.length);
    }
 
    function getLatestPrice(address token)
        public
        override
        view
        returns (uint256)
    {
        if (token == address(0))
            return swapOracle.consult(kkub, 1e18, yesToken);
        else
            return swapOracle.consult(token, 1e18, yesToken);
    }

}
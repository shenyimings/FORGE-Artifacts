// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import '../libraries/FixedPoint.sol';
import '../libraries/OracleLibrary.sol';
import '../libraries/LuckyChipLibrary.sol';
import "../interfaces/IBEP20.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IDice.sol";
import '../interfaces/ILuckyChipFactory.sol';
import '../interfaces/ILuckyChipPair.sol';

contract Oracle is Ownable, IOracle {
    using FixedPoint for *;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _routerTokens; // all router token must has pair with anchor token
    EnumerableSet.AddressSet private _diceTokens; // all dice token

    struct Observation {
        uint256 timestamp;
        uint256 price0Cumulative;
        uint256 price1Cumulative;
    }

    address public immutable factory;
    address public immutable anchorToken;
    address public immutable BUSD;
    uint256 public constant CYCLE = 30 minutes;

    // mapping from pair address to a list of price observations of that pair
    mapping(address => Observation) public pairObservations;

    // mapping from diceToken to dice
    mapping(address => address) public diceToken2Dice;

    constructor(address _factory, address _anchorToken, address _BUSD) public {
        factory = _factory;
        anchorToken = _anchorToken;
        BUSD = _BUSD;
    }

    function update(address tokenA, address tokenB) external override returns (bool) {
        address pair = LuckyChipLibrary.pairFor(factory, tokenA, tokenB);
        if (pair == address(0)) return false;

        Observation storage observation = pairObservations[pair];
        uint256 timeElapsed = block.timestamp - observation.timestamp;
        if (timeElapsed < CYCLE) return false;

        (uint256 price0Cumulative, uint256 price1Cumulative, ) = OracleLibrary.currentCumulativePrices(pair);
        observation.timestamp = block.timestamp;
        observation.price0Cumulative = price0Cumulative;
        observation.price1Cumulative = price1Cumulative;
        return true;
    }

    function computeAmountOut(
        uint256 priceCumulativeStart,
        uint256 priceCumulativeEnd,
        uint256 timeElapsed,
        uint256 amountIn
    ) private pure returns (uint256 amountOut) {
        // overflow is desired.
        FixedPoint.uq112x112 memory priceAverage =
            FixedPoint.uq112x112(uint224((priceCumulativeEnd - priceCumulativeStart) / timeElapsed));
        amountOut = priceAverage.mul(amountIn).decode144();
    }

    function consult(
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    ) private view returns (uint256 amountOut) {
        address pair = LuckyChipLibrary.pairFor(factory, tokenIn, tokenOut);
        if (pair == address(0)) return 0;

        Observation memory observation = pairObservations[pair];
        uint256 timeElapsed = block.timestamp - observation.timestamp;
        if(observation.price0Cumulative == 0 || observation.price1Cumulative == 0){
            return 0;
        }
        if(timeElapsed == 0){
            (uint112 reserve0, uint112 reserve1,) = ILuckyChipPair(pair).getReserves();
            (address token0, ) = LuckyChipLibrary.sortTokens(tokenIn, tokenOut);
            if (token0 == tokenIn) {
                return (reserve0 != 0) ? uint256(reserve1).mul(amountIn).div(uint256(reserve0)) : 0;
            }else{
                return (reserve1 != 0) ? uint256(reserve0).mul(amountIn).div(uint256(reserve1)) : 0;
            }
        }else{
            (uint256 price0Cumulative, uint256 price1Cumulative, ) = OracleLibrary.currentCumulativePrices(pair);
            (address token0, ) = LuckyChipLibrary.sortTokens(tokenIn, tokenOut);

            if (token0 == tokenIn) {
                return computeAmountOut(observation.price0Cumulative, price0Cumulative, timeElapsed, amountIn);
            } else {
                return computeAmountOut(observation.price1Cumulative, price1Cumulative, timeElapsed, amountIn);
            }
        }
    }

    // used for trading pool to calculate quantity
    function getQuantity(address token, uint256 amount) public override view returns (uint256 quantity) {
        uint256 decimal = IBEP20(token).decimals();
        if (token == anchorToken) {
            quantity = amount;
        } else {
            quantity = getAveragePrice(token).mul(amount).div(10**decimal);
        }
    }

    function getQuantityBUSD(address token, uint256 amount) public override view returns (uint256 quantity) {
        if (token == BUSD) {
            quantity = amount;
        } else {
            uint256 anchorQuantity = getQuantity(token, amount);
            quantity = consult(anchorToken, anchorQuantity, BUSD);
        }
    }

    function getAveragePrice(address token) public view returns (uint256 price) {
        uint256 decimal = IBEP20(token).decimals();
        uint256 amount = 10**decimal;
        if (token == anchorToken) {
            price = amount;
        } else if (ILuckyChipFactory(factory).getPair(token, anchorToken) != address(0)) {
            price = consult(token, amount, anchorToken);
        } else {
            uint256 length = getRouterTokenLength();
            for (uint256 index = 0; index < length; index++) {
                address intermediate = getRouterToken(index);
                if (
                    LuckyChipLibrary.pairFor(factory, token, intermediate) != address(0) &&
                    LuckyChipLibrary.pairFor(factory, intermediate, anchorToken) != address(0)
                ) {
                    uint256 interPrice = consult(token, amount, intermediate);
                    price = consult(intermediate, interPrice, anchorToken);
                    break;
                }
            }
        }
    }

    function getCurrentPrice(address token) public view returns (uint256 price) {
        uint256 anchorTokenDecimal = IBEP20(anchorToken).decimals();
        uint256 tokenDecimal = IBEP20(token).decimals();

        if (token == anchorToken) {
            price = 10**anchorTokenDecimal;
        } else if (LuckyChipLibrary.pairFor(factory, token, anchorToken) != address(0)) {
            (uint256 reserve0, uint256 reserve1) = LuckyChipLibrary.getReserves(factory, token, anchorToken);
            price = (10**tokenDecimal).mul(reserve1).div(reserve0);
        } else {
            uint256 length = getRouterTokenLength();
            for (uint256 index = 0; index < length; index++) {
                address intermediate = getRouterToken(index);
                if (
                    LuckyChipLibrary.pairFor(factory, token, intermediate) != address(0) &&
                    LuckyChipLibrary.pairFor(factory, intermediate, anchorToken) != address(0)
                ) {
                    (uint256 reserve0, uint256 reserve1) = LuckyChipLibrary.getReserves(factory, token, intermediate);
                    uint256 amountOut = 10**tokenDecimal.mul(reserve1).div(reserve0);
                    (uint256 reserve2, uint256 reserve3) = LuckyChipLibrary.getReserves(factory, intermediate, anchorToken);
                    price = amountOut.mul(reserve3).div(reserve2);
                    break;
                }
            }
        }
    }

    function getLpTokenValue(address _lpToken, uint256 _amount) public override view returns (uint256 value) {
        uint256 totalSupply = IBEP20(_lpToken).totalSupply();
        address token0 = ILuckyChipPair(_lpToken).token0();
        address token1 = ILuckyChipPair(_lpToken).token1();
        uint256 token0Decimal = IBEP20(token0).decimals();
        uint256 token1Decimal = IBEP20(token1).decimals();
        (uint256 reserve0, uint256 reserve1) = LuckyChipLibrary.getReserves(factory, token0, token1);

        uint256 token0Value = (getAveragePrice(token0)).mul(reserve0).div(10**token0Decimal);
        uint256 token1Value = (getAveragePrice(token1)).mul(reserve1).div(10**token1Decimal);
        value = (token0Value.add(token1Value)).mul(_amount).div(totalSupply);
    }

    function getBankerTokenValue(address _bankerToken, uint256 _amount) public override view returns (uint256 value) {
        if(isDiceToken(_bankerToken)){
            address _dice = diceToken2Dice[_bankerToken];
            IDice dice = IDice(_dice);
            uint256 diceTokenAmount = dice.canWithdrawAmount(_amount);
            value = getQuantity(dice.tokenAddr(), diceTokenAmount);
        }else{
            value = 0;
        }
    }

    function addRouterToken(address _token) public onlyOwner returns (bool) {
        require(_token != address(0), 'Oracle: address is zero');
        return EnumerableSet.add(_routerTokens, _token);
    }

    function addRouterTokens(address[] memory tokens) public onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            addRouterToken(tokens[i]);
        }
    }

    function delRouterToken(address _token) public onlyOwner returns (bool) {
        require(_token != address(0), 'Oracle: address is zero');
        return EnumerableSet.remove(_routerTokens, _token);
    }

    function getRouterTokenLength() public view returns (uint256) {
        return EnumerableSet.length(_routerTokens);
    }

    function isRouterToken(address _token) public view returns (bool) {
        return EnumerableSet.contains(_routerTokens, _token);
    }

    function getRouterToken(uint256 _index) public view returns (address) {
        require(_index <= getRouterTokenLength() - 1, 'Oracle: index out of bounds');
        return EnumerableSet.at(_routerTokens, _index);
    }

    function addDiceToken(address _diceToken, address _dice) public onlyOwner returns (bool) {
        require(_diceToken != address(0) && _dice != address(0) , 'Oracle: address is zero');
        diceToken2Dice[_diceToken] = _dice;
        return EnumerableSet.add(_diceTokens, _diceToken);
    }

    function isDiceToken(address _token) public view returns (bool) {
        return EnumerableSet.contains(_diceTokens, _token);
    }
}

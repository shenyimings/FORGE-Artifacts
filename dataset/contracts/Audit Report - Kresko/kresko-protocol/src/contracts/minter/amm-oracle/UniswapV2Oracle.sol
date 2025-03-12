// SPDX-License-Identifier: MIT
pragma solidity <0.8.0;
pragma experimental ABIEncoderV2;

import {IUniswapV2Factory, IUniswapV2Pair} from "../../vendor/uniswap/v2-periphery/libraries/UniswapV2Library.sol";
import {UQ} from "../../vendor/uniswap/v2-periphery/libraries/UQ.sol";
import {Error} from "../../libs/Errors.sol";
import {IUniswapV2Oracle, IERC20Minimal} from "./IUniswapV2Oracle.sol";

/**
 * @title Kresko AMM Oracle (Uniswap V2)
 *
 * Keeps track of time-weighted average prices for tokens in a Uniswap V2 pair.
 * This oracle is intended to be used with Kresko AMM.
 *
 * This oracle is updated by calling the `update` with the liquidity token address.
 * The prices can be queried by calling `consult` or `consultKrAsset` for quality-of-life with Kresko Assets,
 * it does not need the pair address.
 *
 * Bookkeeping is done in terms of time-weighted average prices, and that period has a lower bound of `minUpdatePeriod`.
 * Logic is pretty much what's laid out in
 * https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol
 *
 * This contract just extends some storage to deal with many pairs with their own configuration.
 *
 * @notice Kresko gives _NO GUARANTEES_ for the correctness of the prices provided by this oracle.
 *
 * @author Kresko
 */
contract UniswapV2Oracle is IUniswapV2Oracle {
    using UQ for *;

    /* -------------------------------------------------------------------------- */
    /*                                   Layout                                   */
    /* -------------------------------------------------------------------------- */

    IUniswapV2Factory public immutable override factory;

    IERC20Minimal public override incentiveToken;

    uint256 public override incentiveAmount = 3 ether;

    address public override admin;

    uint256 public override minUpdatePeriod = 15 minutes;

    mapping(address => PairData) private _pairs;

    mapping(address => address) public override krAssets;

    /* --------------------------------------------------------------------------*/
    /*                                   Funcs                                   */
    /* --------------------------------------------------------------------------*/

    constructor(address _factory, address _admin) {
        require(_factory != address(0), Error.CONSTRUCTOR_INVALID_FACTORY);
        require(_admin != address(0), Error.CONSTRUCTOR_INVALID_ADMIN);

        factory = IUniswapV2Factory(_factory);
        admin = _admin;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, Error.CALLER_NOT_ADMIN);
        _;
    }

    function getPair(address _pairAddress) external view override returns (PairData memory) {
        return _pairs[_pairAddress];
    }

    /// @inheritdoc IUniswapV2Oracle
    function setIncentiveToken(address _newIncentiveToken, uint256 amount) external override onlyAdmin {
        incentiveToken = IERC20Minimal(_newIncentiveToken);
        incentiveAmount = amount;
    }

    /// @inheritdoc IUniswapV2Oracle
    function drainERC20(address _erc20, address _to) external override onlyAdmin {
        IERC20Minimal(_erc20).transfer(_to, IERC20Minimal(_erc20).balanceOf(address(this)));
    }

    /// @inheritdoc IUniswapV2Oracle
    function setAdmin(address _newAdmin) external override onlyAdmin {
        admin = _newAdmin;
        emit NewAdmin(_newAdmin);
    }

    /// @inheritdoc IUniswapV2Oracle
    function setMinUpdatePeriod(uint256 _minUpdatePeriod) external override onlyAdmin {
        minUpdatePeriod = _minUpdatePeriod;
        emit NewMinUpdatePeriod(_minUpdatePeriod);
    }

    /// @inheritdoc IUniswapV2Oracle
    function initPair(address _pairAddress, address _kreskoAsset, uint256 _updatePeriod) external override onlyAdmin {
        require(_pairAddress != address(0), Error.PAIR_ADDRESS_IS_ZERO);
        require(_updatePeriod >= minUpdatePeriod, Error.INVALID_UPDATE_PERIOD);
        require(_pairs[_pairAddress].token0 == address(0), Error.PAIR_ALREADY_EXISTS);

        IUniswapV2Pair pair = IUniswapV2Pair(_pairAddress);
        address token0 = pair.token0();
        address token1 = pair.token1();

        // Ensure that the pair exists
        require(token0 != address(0) && token1 != address(0), Error.PAIR_DOES_NOT_EXIST);

        // If the Kresko Asset is in the pair, add it to the krAssets mapping
        if (_kreskoAsset == token0 || _kreskoAsset == token1) {
            krAssets[_kreskoAsset] = _pairAddress;
            emit NewKrAssetPair(_kreskoAsset, _pairAddress);
        }

        // Ensure that there's liquidity in the pair
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, Error.INVALID_LIQUIDITY); // ensure that there's liquidity in the pair

        // Initialize the pair to storage
        _pairs[_pairAddress].token0 = token0;
        _pairs[_pairAddress].token1 = token1;
        _pairs[_pairAddress].price0CumulativeLast = pair.price0CumulativeLast();
        _pairs[_pairAddress].price1CumulativeLast = pair.price1CumulativeLast();
        _pairs[_pairAddress].updatePeriod = _updatePeriod;
        _pairs[_pairAddress].blockTimestampLast = blockTimestampLast;

        emit NewPair(_pairAddress, token0, token1, _updatePeriod);
    }

    /// @inheritdoc IUniswapV2Oracle
    function configurePair(address _pairAddress, uint256 _updatePeriod) external override onlyAdmin {
        // Ensure that the pair exists
        require(
            _pairs[_pairAddress].token0 != address(0) && _pairs[_pairAddress].token1 != address(0),
            Error.PAIR_DOES_NOT_EXIST
        );

        // Ensure that the update period is greater than the minimum update period
        require(_updatePeriod >= minUpdatePeriod, Error.INVALID_UPDATE_PERIOD);

        // Update the period
        _pairs[_pairAddress].updatePeriod = _updatePeriod;

        emit PairUpdated(_pairAddress, _pairs[_pairAddress].token0, _pairs[_pairAddress].token1, _updatePeriod);
    }

    /// @inheritdoc IUniswapV2Oracle
    function update(address _pairAddress) external override {
        PairData storage data = _pairs[_pairAddress];

        // Ensure that the pair exists
        require(data.blockTimestampLast != 0, Error.PAIR_DOES_NOT_EXIST);

        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = currentCumulativePrices(
            _pairAddress
        );

        uint32 timeElapsed = blockTimestamp - data.blockTimestampLast; // overflow is desired
        // Ensure that at least one full period has passed since the last update
        require(timeElapsed >= data.updatePeriod, Error.UPDATE_PERIOD_NOT_FINISHED);

        // Overflow is desired, casting never truncates
        // Cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        data.price0Average = UQ.uq112x112(uint224((price0Cumulative - data.price0CumulativeLast) / timeElapsed));
        data.price1Average = UQ.uq112x112(uint224((price1Cumulative - data.price1CumulativeLast) / timeElapsed));

        // Update the cumulative prices
        data.price0CumulativeLast = price0Cumulative;
        data.price1CumulativeLast = price1Cumulative;
        data.blockTimestampLast = blockTimestamp;

        emit NewPrice(
            data.token0,
            data.token1,
            blockTimestamp,
            data.price0Average,
            data.price1Average,
            data.updatePeriod,
            timeElapsed
        );
    }

    /// @inheritdoc IUniswapV2Oracle
    function getKrAssetPair(address _kreskoAsset) external view override returns (PairData memory) {
        return _pairs[krAssets[_kreskoAsset]];
    }

    /// @inheritdoc IUniswapV2Oracle
    function updateWithIncentive(address _kreskoAsset) external override {
        PairData storage data = _pairs[krAssets[_kreskoAsset]];
        // Ensure that the pair exists
        require(data.blockTimestampLast != 0, Error.PAIR_DOES_NOT_EXIST);
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = currentCumulativePrices(
            krAssets[_kreskoAsset]
        );

        uint32 timeElapsed = blockTimestamp - data.blockTimestampLast; // overflow is desired
        // Ensure that at least one full period has passed since the last update
        require(timeElapsed >= data.updatePeriod, Error.UPDATE_PERIOD_NOT_FINISHED);

        // Overflow is desired, casting never truncates
        // Cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        data.price0Average = UQ.uq112x112(uint224((price0Cumulative - data.price0CumulativeLast) / timeElapsed));
        data.price1Average = UQ.uq112x112(uint224((price1Cumulative - data.price1CumulativeLast) / timeElapsed));

        // Update the cumulative prices
        data.price0CumulativeLast = price0Cumulative;
        data.price1CumulativeLast = price1Cumulative;
        data.blockTimestampLast = blockTimestamp;

        emit NewPrice(
            data.token0,
            data.token1,
            blockTimestamp,
            data.price0Average,
            data.price1Average,
            data.updatePeriod,
            timeElapsed
        );

        require(incentiveToken.balanceOf(address(this)) >= 3 ether, Error.NO_INCENTIVES_LEFT);
        incentiveToken.transfer(msg.sender, 3 ether);
    }

    /// @inheritdoc IUniswapV2Oracle
    function consultKrAsset(
        address _kreskoAsset,
        uint256 _amountIn
    ) external view override returns (uint256 amountOut) {
        PairData memory data = _pairs[krAssets[_kreskoAsset]];

        // if the kresko asset is token0, get the corresponding value for the amount in
        if (_kreskoAsset == data.token0) {
            amountOut = data.price0Average.mul(_amountIn).decode144();
        } else {
            if (_kreskoAsset != data.token1) {
                // if the kresko asset is not in the pair, return 0
                amountOut = 0;
            } else {
                // if the kresko asset is token1, get the corresponding value for the amount in
                amountOut = data.price1Average.mul(_amountIn).decode144();
            }
        }
    }

    /// @inheritdoc IUniswapV2Oracle
    function consult(
        address _pairAddress,
        address _token,
        uint256 _amountIn
    ) external view override returns (uint256 amountOut) {
        PairData memory data = _pairs[_pairAddress];
        if (_token == data.token0) {
            amountOut = data.price0Average.mul(_amountIn).decode144();
        } else {
            require(_token == data.token1, Error.INVALID_PAIR);
            amountOut = data.price1Average.mul(_amountIn).decode144();
        }
    }

    /**
     * @notice Returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
     */
    function currentBlockTimestamp() internal view returns (uint32) {
        // solhint-disable not-rely-on-time
        return uint32(block.timestamp % 2 ** 32);
    }

    /**
     * @notice Produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
     * @param _pairAddress Pair address
     */
    function currentCumulativePrices(
        address _pairAddress
    ) internal view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IUniswapV2Pair(_pairAddress).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(_pairAddress).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(_pairAddress).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint256(UQ.fraction(reserve1, reserve0)._x) * timeElapsed;
            // counterfactual
            price1Cumulative += uint256(UQ.fraction(reserve0, reserve1)._x) * timeElapsed;
        }
    }
}

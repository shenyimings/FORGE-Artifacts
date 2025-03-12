pragma solidity 0.6.7;
pragma experimental ABIEncoderV2;

import "./Setup.sol";
import { TestToken } from "../../TestHelpers.sol";
import "../../../uni/UniswapV3Pool.sol";
import "../../../uni/libraries/TickMath.sol";

// import 'hardhat/console.sol';

contract E2E_swap {
    SetupTokens tokens;
    SetupUniswap uniswap;

    UniswapV3Pool pool;

    TestToken token0;
    TestToken token1;

    UniswapMinter minter;
    UniswapSwapper swapper;

    int24[] usedTicks;
    bool inited;
    bool set = false;

    struct PoolParams {
        uint24 fee;
        int24 tickSpacing;
        int24 minTick;
        int24 maxTick;
        uint24 tickCount;
        uint160 startPrice;
        int24 startTick;
    }

    struct PoolPositions {
        int24[] tickLowers;
        int24[] tickUppers;
        uint128[] amounts;
    }

    struct PoolPosition {
        int24 tickLower;
        int24 tickUpper;
        uint128 amount;
        bytes32 key;
    }

    PoolParams poolParams;
    PoolPositions poolPositions;
    PoolPosition[] positions;

    constructor() public {
        tokens = new SetupTokens();
        token0 = tokens.token0();
        token1 = tokens.token1();

        uniswap = new SetupUniswap(token0, token1);

        minter = new UniswapMinter(token0, token1);
        swapper = new UniswapSwapper(token0, token1);

        tokens.mintTo(0, address(swapper), 1e9 ether);
        tokens.mintTo(1, address(swapper), 1e9 ether);

        tokens.mintTo(0, address(minter), 1e10 ether);
        tokens.mintTo(1, address(minter), 1e10 ether);
    }

    //
    //
    // Helpers
    //
    //

    function get_random_zeroForOne_priceLimit(int256 _amountSpecified) internal view returns (uint160 sqrtPriceLimitX96) {
        // help echidna a bit by calculating a valid sqrtPriceLimitX96 using the amount as random seed
        (uint160 currentPrice, , , , , , ) = pool.slot0();
        uint160 minimumPrice = TickMath.MIN_SQRT_RATIO;
        sqrtPriceLimitX96 = minimumPrice + uint160((uint256(_amountSpecified > 0 ? _amountSpecified : -_amountSpecified) % (currentPrice - minimumPrice)));
    }

    function get_random_oneForZero_priceLimit(int256 _amountSpecified) internal view returns (uint160 sqrtPriceLimitX96) {
        // help echidna a bit by calculating a valid sqrtPriceLimitX96 using the amount as random seed
        (uint160 currentPrice, , , , , , ) = pool.slot0();
        uint160 maximumPrice = TickMath.MAX_SQRT_RATIO;
        sqrtPriceLimitX96 = currentPrice + uint160((uint256(_amountSpecified > 0 ? _amountSpecified : -_amountSpecified) % (maximumPrice - currentPrice)));
    }

    //
    //
    // Helper to reconstruct the "random" init setup of the pool
    //
    //

    //
    //
    // Setup functions
    //
    //

    function forgePoolParams(uint128 _seed) internal view returns (PoolParams memory poolParams_) {
        //
        // decide on one of the three fees, and corresponding tickSpacing
        //
        if (_seed % 3 == 0) {
            poolParams_.fee = uint24(500);
            poolParams_.tickSpacing = int24(10);
        } else if (_seed % 3 == 1) {
            poolParams_.fee = uint24(3000);
            poolParams_.tickSpacing = int24(60);
        } else if (_seed % 3 == 2) {
            poolParams_.fee = uint24(10000);
            poolParams_.tickSpacing = int24(2000);
        }

        poolParams_.maxTick = (int24(887272) / poolParams_.tickSpacing) * poolParams_.tickSpacing;
        poolParams_.minTick = -poolParams_.maxTick;
        poolParams_.tickCount = uint24(poolParams_.maxTick / poolParams_.tickSpacing);

        //
        // set the initial price
        //
        poolParams_.startTick = int24((_seed % uint128(poolParams_.tickCount)) * uint128(poolParams_.tickSpacing));
        if (_seed % 3 == 0) {
            // set below 0
            poolParams_.startPrice = TickMath.getSqrtRatioAtTick(-poolParams_.startTick);
        } else if (_seed % 3 == 1) {
            // set at 0
            poolParams_.startPrice = TickMath.getSqrtRatioAtTick(0);
            poolParams_.startTick = 0;
        } else if (_seed % 3 == 2) {
            // set above 0
            poolParams_.startPrice = TickMath.getSqrtRatioAtTick(poolParams_.startTick);
        }
    }

    function forgePoolPositions(
        uint128 _seed,
        int24 _poolTickSpacing,
        uint24 _poolTickCount,
        int24 _poolMaxTick
    ) internal view returns (PoolPositions memory poolPositions_) {
        // between 1 and 10 (inclusive) positions
        uint8 positionsCount = uint8(_seed % 10) + 1;

        poolPositions_.tickLowers = new int24[](positionsCount);
        poolPositions_.tickUppers = new int24[](positionsCount);
        poolPositions_.amounts = new uint128[](positionsCount);

        for (uint8 i = 0; i < positionsCount; i++) {
            int24 tickLower;
            int24 tickUpper;
            uint128 amount;

            int24 randomTick1 = int24((_seed % uint128(_poolTickCount)) * uint128(_poolTickSpacing));

            if (_seed % 2 == 0) {
                // make tickLower positive
                tickLower = randomTick1;

                // tickUpper is somewhere above tickLower
                uint24 poolTickCountLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
                int24 randomTick2 = int24((_seed % uint128(poolTickCountLeft)) * uint128(_poolTickSpacing));
                tickUpper = tickLower + randomTick2;
            } else {
                // make tickLower negative or zero
                tickLower = randomTick1 == 0 ? 0 : -randomTick1;

                uint24 poolTickCountNegativeLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
                uint24 poolTickCountTotalLeft = poolTickCountNegativeLeft + _poolTickCount;

                uint24 randomIncrement = uint24((_seed % uint128(poolTickCountTotalLeft)) * uint128(_poolTickSpacing));

                if (randomIncrement <= uint24(tickLower)) {
                    // tickUpper will also be negative
                    tickUpper = tickLower + int24(randomIncrement);
                } else {
                    // tickUpper is positive
                    randomIncrement -= uint24(-tickLower);
                    tickUpper = tickLower + int24(randomIncrement);
                }
            }

            amount = uint128(1e8 ether);

            poolPositions_.tickLowers[i] = tickLower;
            poolPositions_.tickUppers[i] = tickUpper;
            poolPositions_.amounts[i] = amount;

            _seed += uint128(tickLower);
        }
    }

    function _getRandomPositionIdx(uint128 _seed, uint256 _positionsCount) internal view returns (uint128 positionIdx) {
        positionIdx = _seed % uint128(_positionsCount);
    }

    function _getRandomBurnAmount(uint128 _seed, uint128 _positionAmount) internal view returns (uint128 burnAmount) {
        burnAmount = _seed % _positionAmount;
        require(burnAmount < _positionAmount);
        require(burnAmount > 0);
    }

    function _getRandomPositionIdxAndBurnAmount(uint128 _seed) internal view returns (uint128 positionIdx, uint128 burnAmount) {
        positionIdx = _getRandomPositionIdx(_seed, positions.length);
        burnAmount = _getRandomBurnAmount(_seed, positions[positionIdx].amount);
    }

    // adds all lower and upper ticks to an array such that the liquidity(Net) invariants
    // can loop over them
    function storeUsedTicks(int24 _tL, int24 _tU) internal {
        bool lowerAlreadyUsed = false;
        bool upperAlreadyUsed = false;
        for (uint8 j = 0; j < usedTicks.length; j++) {
            if (usedTicks[j] == _tL) lowerAlreadyUsed = true;
            else if (usedTicks[j] == _tU) upperAlreadyUsed = true;
        }
        if (!lowerAlreadyUsed) usedTicks.push(_tL);
        if (!upperAlreadyUsed) usedTicks.push(_tU);
    }

    function removePosition(uint256 _posIdx) internal {
        positions[_posIdx] = positions[positions.length - 1];
        positions.pop();
    }

    // use the _amount as _seed to create a random but valid position
    function forgePosition(
        uint128 _seed,
        int24 _poolTickSpacing,
        uint24 _poolTickCount,
        int24 _poolMaxTick
    ) internal view returns (int24 tickLower, int24 tickUpper) {
        int24 randomTick1 = int24((_seed % uint128(_poolTickCount)) * uint128(_poolTickSpacing));

        if (_seed % 2 == 0) {
            // make tickLower positive
            tickLower = randomTick1;

            // tickUpper is somewhere above tickLower
            uint24 poolTickCountLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
            int24 randomTick2 = int24((_seed % uint128(poolTickCountLeft)) * uint128(_poolTickSpacing));
            tickUpper = tickLower + randomTick2;
        } else {
            // make tickLower negative or zero
            tickLower = randomTick1 == 0 ? 0 : -randomTick1;

            uint24 poolTickCountNegativeLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
            uint24 poolTickCountTotalLeft = poolTickCountNegativeLeft + _poolTickCount;

            uint24 randomIncrement = uint24((_seed % uint128(poolTickCountTotalLeft)) * uint128(_poolTickSpacing));

            if (randomIncrement <= uint24(tickLower)) {
                // tickUpper will also be negative
                tickUpper = tickLower + int24(randomIncrement);
            } else {
                // tickUpper is positive
                randomIncrement -= uint24(-tickLower);
                tickUpper = tickLower + int24(randomIncrement);
            }
        }
    }

    function _init(uint128 _seed) internal {
        //
        // generate random pool params
        //
        poolParams = forgePoolParams(_seed);

        //
        // deploy the pool
        //
        uniswap.createPool(poolParams.fee, poolParams.startPrice);
        pool = uniswap.pool();

        //
        // set the pool inside the minter and swapper contracts
        //
        minter.setPool(pool);
        swapper.setPool(pool);

        //generate random positions

        poolPositions = forgePoolPositions(_seed, poolParams.tickSpacing, poolParams.tickCount, poolParams.maxTick);

        //create the positions

        for (uint8 i = 0; i < poolPositions.tickLowers.length; i++) {
            int24 tickLower = poolPositions.tickLowers[i];
            int24 tickUpper = poolPositions.tickUppers[i];
            uint128 amount = poolPositions.amounts[i];

            minter.doMint(tickLower, tickUpper, amount);

            bool lowerAlreadyUsed = false;
            bool upperAlreadyUsed = false;
            for (uint8 j = 0; j < usedTicks.length; j++) {
                if (usedTicks[j] == tickLower) lowerAlreadyUsed = true;
                else if (usedTicks[j] == tickUpper) upperAlreadyUsed = true;
            }
            if (!lowerAlreadyUsed) usedTicks.push(tickLower);
            if (!upperAlreadyUsed) usedTicks.push(tickUpper);
        }
        inited = true;
    }

    //
    //
    // Functions to fuzz
    //
    //

    function test_swap_exactIn_zeroForOne(uint128 _amount) public {
        require(set);
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) >= uint256(_amount));
        int256 _amountSpecified = int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_zeroForOne_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);
    }

    function test_swap_exactIn_oneForZero(uint128 _amount) public {
        require(set);
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token1.balanceOf(address(swapper)) >= uint256(_amount));
        int256 _amountSpecified = int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_oneForZero_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);
        swapper.doSwap(false, _amountSpecified, sqrtPriceLimitX96);
    }

    function test_swap_exactOut_zeroForOne(uint128 _amount) public {
        require(set);
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) > 0);
        int256 _amountSpecified = -int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_zeroForOne_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);
    }

    function test_swap_exactOut_oneForZero(uint128 _amount) public {
        require(set);
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) > 0);
        int256 _amountSpecified = -int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_oneForZero_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);
        swapper.doSwap(false, _amountSpecified, sqrtPriceLimitX96);
    }

    function test_mint(uint128 _amount) public {
        require(set);
        if (!inited) _init(_amount);
        (int24 _tL, int24 _tU) = forgePosition(_amount, poolParams.tickSpacing, poolParams.tickCount, poolParams.maxTick);

        (UniswapMinter.MinterStats memory bfre, UniswapMinter.MinterStats memory aftr) = minter.doMint(_tL, _tU, _amount);
        storeUsedTicks(_tL, _tU);

        bytes32 positionKey = keccak256(abi.encodePacked(address(minter), _tL, _tU));

        bool mintingToExistingPos = false;
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].key == positionKey) {
                // minting to an existing position
                positions[i].amount += _amount;
                mintingToExistingPos = true;
                break;
            }
        }

        if (!mintingToExistingPos) {
            positions.push(PoolPosition(_tL, _tU, _amount, positionKey));
        }
    }

    function test_burn_partial(uint128 _amount) public {
        require(set);
        require(positions.length > 0);

        (uint128 posIdx, uint128 burnAmount) = _getRandomPositionIdxAndBurnAmount(_amount);
        // console.log('burn posIdx = %s', posIdx);
        // console.log('burn amount = %s', burnAmount);
        PoolPosition storage pos = positions[posIdx];

        UniswapMinter.MinterStats memory bfre;
        UniswapMinter.MinterStats memory aftr;

        try minter.doBurn(pos.tickLower, pos.tickUpper, burnAmount) returns (
            UniswapMinter.MinterStats memory bfre_burn,
            UniswapMinter.MinterStats memory aftr_burn
        ) {
            bfre = bfre_burn;
            aftr = aftr_burn;
        } catch {
            // prop #28
            assert(false);
        }

        pos.amount = pos.amount - burnAmount;
    }

    function test_burn_full(uint128 _amount) public {
        require(positions.length > 0);

        uint128 posIdx = _getRandomPositionIdx(_amount, positions.length);
        // console.log('burn posIdx = %s', posIdx);
        PoolPosition storage pos = positions[posIdx];

        UniswapMinter.MinterStats memory bfre;
        UniswapMinter.MinterStats memory aftr;

        try minter.doBurn(pos.tickLower, pos.tickUpper, pos.amount) returns (
            UniswapMinter.MinterStats memory bfre_burn,
            UniswapMinter.MinterStats memory aftr_burn
        ) {
            bfre = bfre_burn;
            aftr = aftr_burn;
        } catch {
            // prop #25
            assert(false);
        }

        removePosition(posIdx);
    }

    function test_burn_zero(uint128 _amount) public {
        require(set);
        require(positions.length > 0);

        uint128 posIdx = _getRandomPositionIdx(_amount, positions.length);
        // console.log('burn posIdx = %s', posIdx);
        PoolPosition storage pos = positions[posIdx];

        UniswapMinter.MinterStats memory bfre;
        UniswapMinter.MinterStats memory aftr;

        try minter.doBurn(pos.tickLower, pos.tickUpper, 0) returns (UniswapMinter.MinterStats memory bfre_burn, UniswapMinter.MinterStats memory aftr_burn) {
            bfre = bfre_burn;
            aftr = aftr_burn;
        } catch {
            // prop #26
            assert(false);
        }
    }
}

/*
MIT License

Copyright (c) 2021 Reflexer Labs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

pragma solidity 0.6.7;

import "./GebUniswapV3ManagerBase.sol";

/**
 * @notice This contract is based on https://github.com/dmihal/uniswap-liquidity-dao/blob/master/contracts/MetaPool.sol
 */
contract GebUniswapV3LiquidityManager is GebUniswapV3ManagerBase {
    // --- Variables ---
    // This contracts' position in the Uniswap V3 pool
    Position public position;

    /**
     * @notice Constructor that sets initial parameters for this contract
     * @param name_ The name of the ERC20 this contract will distribute
     * @param symbol_ The symbol of the ERC20 this contract will distribute
     * @param systemCoinAddress_ The address of the system coin
     * @param threshold_ The liquidity threshold around the redemption price
     * @param delay_ The minimum required time before rebalance() can be called
     * @param pool_ Address of the already deployed Uniswap v3 pool that this contract will manage
     * @param oracle_ Address of the already deployed oracle that provides both token prices
     * @param wethAddress_ Address of the WETH9 contract
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address systemCoinAddress_,
        uint256 threshold_,
        uint256 delay_,
        address pool_,
        OracleForUniswapLike oracle_,
        PoolViewer poolViewer_,
        address wethAddress_
    ) public GebUniswapV3ManagerBase(name_, symbol_,systemCoinAddress_,delay_,pool_,oracle_,poolViewer_,wethAddress_) {
        require(threshold_ >= MIN_THRESHOLD && threshold_ <= MAX_THRESHOLD, "GebUniswapV3LiquidityManager/invalid-threshold");
        require(threshold_ % uint256(tickSpacing) == 0, "GebUniswapV3LiquidityManager/threshold-incompatible-w/-tick-spacing");

        int24 target = getTargetTick();
        (int24 lower, int24 upper) = getTicksWithThreshold(target, threshold_);

        position = Position({ id: keccak256(abi.encodePacked(address(this), lower, upper)), lowerTick: lower, upperTick: upper, uniLiquidity: 0, threshold: threshold_, tkn0Reserve:0,tkn1Reserve:0 });
    }

    // --- Getters ---
    /**
     * @notice Returns the current amount of token0 for a given liquidity amount
     * @param _liquidity The amount of liquidity to withdraw
     * @return amount0 The amount of token0 received for the liquidity amount
     * @return amount1 The amount of token0 received for the liquidity amount
     */
    function getTokenAmountsFromLiquidity(uint128 _liquidity) public returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _getTokenAmountsFromLiquidity(position, _liquidity);
    }

    /**
     * @notice Returns the current amount of token0 for a given liquidity amount
     * @param _liquidity The amount of liquidity to withdraw
     * @return amount0 The amount of token0 received for the liquidity amount
     */
    function getToken0FromLiquidity(uint128 _liquidity) public returns (uint256 amount0) {
        if (_liquidity == 0) return 0;
        (amount0, ) = _getTokenAmountsFromLiquidity(position, _liquidity);
    }

    /**
     * @notice Returns the current amount of token1 for a given liquidity amount
     * @param _liquidity The amount of liquidity to withdraw
     * @return amount1 The amount of token1 received for the liquidity amount
     */
    function getToken1FromLiquidity(uint128 _liquidity) public returns (uint256 amount1) {
        if (_liquidity == 0) return 0;
        (, amount1) = _getTokenAmountsFromLiquidity(position, _liquidity);
    }

    // --- Core Logic ---
    /**
     * @notice Add liquidity to this pool manager
     * @param newLiquidity The amount of liquidity that the user wishes to add
     * @param recipient The address that will receive ERC20 wrapper tokens for the provided liquidity
     * @param minAm0 The minimum amount of token 0 for the tx to be considered valid. Preventing sandwich attacks
     * @param minAm1 The minimum amount of token 1 for the tx to be considered valid. Preventing sandwich attacks
     */
    function deposit(uint256 newLiquidity, address recipient, uint256 minAm0, uint256 minAm1) external payable override returns (uint256 mintAmount) {
        require(recipient != address(0), "GebUniswapV3LiquidityManager/invalid-recipient");
        require(newLiquidity < MAX_UINT128, "GebUniswapV3LiquidityManager/too-much-to-mint-at-once");
        require(newLiquidity > 0, "GebUniswapV3LiquidityManager/minting-zero-liquidity");

        uint128 totalLiquidity = position.uniLiquidity;
        int24 target= getTargetTick();

        (uint256 amt0, uint256 amt1) = _deposit(position, toUint128(newLiquidity), target);

        require(amt0 >= minAm0 && amt1 >= minAm1,"GebUniswapV3LiquidityManager/slippage-check");

        // Calculate and mint a user's ERC20 liquidity tokens
        uint256 __supply = _totalSupply;
        if (__supply == 0) {
            mintAmount = newLiquidity;
        } else {
            mintAmount = newLiquidity.mul(_totalSupply).div(totalLiquidity);
        }

        _mint(recipient, mintAmount);

        emit Deposit(msg.sender, recipient, newLiquidity);
    }

    /**
     * @notice Remove liquidity and withdraw the underlying assets
     * @param liquidityAmount The amount of liquidity to withdraw
     * @param recipient The address that will receive token0 and token1 tokens
     * @return amount0 The amount of token0 requested from the pool
     * @return amount1 The amount of token1 requested from the pool
     */
    function withdraw(uint256 liquidityAmount, address recipient) external override returns (uint256 amount0, uint256 amount1) {
        require(recipient != address(0), "GebUniswapV3LiquidityManager/invalid-recipient");
        require(liquidityAmount != 0, "GebUniswapV3LiquidityManager/burning-zero-amount");

        uint256 __supply = _totalSupply;
        // Burn sender tokens
        _burn(msg.sender, uint256(liquidityAmount));

        uint256 _liquidityBurned = liquidityAmount.mul(position.uniLiquidity).div(__supply);
        require(_liquidityBurned < MAX_UINT128, "GebUniswapV3LiquidityManager/too-much-to-burn-at-once");

        (amount0, amount1) = _withdraw(position, toUint128(_liquidityBurned), recipient);
        emit Withdraw(msg.sender, recipient, liquidityAmount);
    }

    /**
     * @notice Public function to move liquidity to the correct threshold from the redemption price
     */
    function rebalance() external override {
       require(block.timestamp.sub(lastRebalance) >= delay, "GebUniswapV3LiquidityManager/too-soon");

        int24 target= getTargetTick();

        _rebalance(position , target);
    }
}

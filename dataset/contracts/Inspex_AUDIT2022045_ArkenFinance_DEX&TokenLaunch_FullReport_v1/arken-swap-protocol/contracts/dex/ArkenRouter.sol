// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.11;

//solhint-disable not-rely-on-time
//solhint-disable var-name-mixedcase
//solhint-disable reason-string

import 'hardhat/console.sol';

import '../lib/ArkenSwapper.sol';
import '../interfaces/IArkenStaker.sol';

import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IWETH.sol';
import './libraries/TransferHelper.sol';
import './libraries/ArkenLPLibrary.sol';

contract ArkenRouter is ArkenSwapper {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable WETH;
    address public immutable staker;

    event Stake(
        address indexed user,
        address indexed tokenA,
        address indexed tokenB,
        uint256 liquidity
    );
    event Unstake(
        address indexed user,
        address indexed tokenA,
        address indexed tokenB,
        uint256 liquidity
    );

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'ArkenRouter: EXPIRED');
        _;
    }

    constructor(
        address _factory,
        address _WETH,
        address _staker,
        address _swap,
        address _swapApprove
    ) ArkenSwapper(_swap, _swapApprove) {
        factory = _factory;
        WETH = _WETH;
        staker = _staker;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function _swapWithPair(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenA,
        address tokenB,
        address to
    ) internal {
        address pair = pairFor(tokenA, tokenB);
        (address token0, address token1) = ArkenLPLibrary.sortTokens(
            tokenA,
            tokenB
        );
        (uint256 reserve0, uint256 reserve1) = ArkenLPLibrary.getReserves(
            factory,
            token0,
            token1
        );
        if (tokenIn == token0) {
            TransferHelper.safeTransfer(token0, pair, amountIn);
            uint256 amountOut = ArkenLPLibrary.getAmountOut(
                amountIn,
                reserve0,
                reserve1
            );
            require(
                amountOutMin <= amountOut,
                'ArkenRouter: INSUFFICIENT_SWAP_RESULT'
            );
            IUniswapV2Pair(pair).swap(0, amountOut, to, '');
        } else {
            TransferHelper.safeTransfer(token1, pair, amountIn);
            uint256 amountOut = ArkenLPLibrary.getAmountOut(
                amountIn,
                reserve1,
                reserve0
            );
            require(
                amountOutMin <= amountOut,
                'ArkenRouter: INSUFFICIENT_SWAP_RESULT'
            );
            IUniswapV2Pair(pair).swap(amountOut, 0, to, '');
        }
    }

    function _swapForLiquidity(
        address tokenIn,
        uint256 amountIn,
        address tokenA,
        address tokenB,
        address to
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pair = pairFor(tokenA, tokenB);
        (address token0, address token1) = ArkenLPLibrary.sortTokens(
            tokenA,
            tokenB
        );
        if (tokenIn == token0) {
            (uint256 amount0In, uint256 amount1Out) = ArkenLPLibrary
                .getAmountSwapRetainRatio(factory, token0, tokenB, amountIn);
            TransferHelper.safeTransfer(token0, pair, amount0In);
            IUniswapV2Pair(pair).swap(0, amount1Out, to, '');
        } else {
            (uint256 amount1In, uint256 amount0Out) = ArkenLPLibrary
                .getAmountSwapRetainRatio(factory, tokenB, tokenA, amountIn);
            TransferHelper.safeTransfer(token1, pair, amount1In);
            IUniswapV2Pair(pair).swap(amount0Out, 0, to, '');
        }
        amountA = IERC20(tokenA).balanceOf(to);
        amountB = IERC20(tokenB).balanceOf(to);
    }

    // **** STAKE ****

    function _stakeFor(
        address tokenA,
        address tokenB,
        address to,
        uint256 amount
    ) internal {
        address pair = pairFor(tokenA, tokenB);
        uint256 pid = IArkenStaker(staker).getPoolId(pair);
        _increasePairAllowance(pair, staker, amount);
        IArkenStaker(staker).depositFor(pid, to, amount);
        emit Stake(to, tokenA, tokenB, amount);
    }

    function _stakeSingleToken(
        address tokenIn,
        uint256 amountIn,
        address tokenA,
        address tokenB,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) internal {
        address pair = pairFor(tokenA, tokenB);
        (uint256 amountA, uint256 amountB) = _swapForLiquidity(
            tokenIn,
            amountIn,
            tokenA,
            tokenB,
            address(this)
        );
        require(amountAMin <= amountA, 'ArkenRouter: INSUFFICIENT_A_AMOUNT');
        require(amountBMin <= amountB, 'ArkenRouter: INSUFFICIENT_B_AMOUNT');
        TransferHelper.safeTransfer(tokenA, pair, amountA);
        TransferHelper.safeTransfer(tokenB, pair, amountB);
        uint256 liquidity = IUniswapV2Pair(pair).mint(address(this));
        _stakeFor(tokenA, tokenB, to, liquidity);
    }

    // IF swap to ETH for XYZ-ETH pair, use WETH as tradeDesc.dstToken and tokenA/tokenB
    function stakeAnyToken(
        address tokenA,
        address tokenB,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        IArkenDexV3.TradeDescription memory tradeDesc
    ) external payable ensure(deadline) {
        tradeDesc.to = payable(this); // force trade to router, for staking
        _swapArkenDex(tradeDesc);
        _stakeSingleToken(
            tradeDesc.dstToken,
            IERC20(tradeDesc.dstToken).balanceOf(address(this)),
            tokenA,
            tokenB,
            amountAMin,
            amountBMin,
            to
        );
    }

    function stakePairToken(
        address tokenIn,
        uint256 amountIn,
        address tokenA,
        address tokenB,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        TransferHelper.safeTransferFrom(
            tokenIn,
            msg.sender,
            address(this),
            amountIn
        );
        _stakeSingleToken(
            tokenIn,
            amountIn,
            tokenA,
            tokenB,
            amountAMin,
            amountBMin,
            to
        );
    }

    function stakePairTokenETH(
        address tokenA,
        address tokenB,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        IWETH(WETH).deposit{value: msg.value}();
        _stakeSingleToken(
            WETH,
            msg.value,
            tokenA,
            tokenB,
            amountAMin,
            amountBMin,
            to
        );
    }

    // **** UNSTAKE ****

    function _unstakeFor(
        address tokenA,
        address tokenB,
        address user,
        address to,
        uint256 amount
    ) internal {
        address pair = pairFor(tokenA, tokenB);
        uint256 pid = IArkenStaker(staker).getPoolId(pair);
        IArkenStaker(staker).withdrawFor(pid, user, to, amount);
        emit Unstake(to, tokenA, tokenB, amount);
    }

    function unstakeToSingle(
        address tokenOut,
        uint256 liquidity,
        uint256 amountOutMin,
        address tokenA,
        address tokenB,
        address payable to,
        uint256 deadline
    ) external ensure(deadline) {
        _unstakeFor(tokenA, tokenB, msg.sender, address(this), liquidity);
        _removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            0,
            0,
            address(this),
            address(this)
        );
        if (tokenA == tokenOut) {
            _swapWithPair(
                tokenB,
                IERC20(tokenB).balanceOf(address(this)),
                0,
                tokenA,
                tokenB,
                address(this)
            );
        } else {
            _swapWithPair(
                tokenA,
                IERC20(tokenA).balanceOf(address(this)),
                0,
                tokenA,
                tokenB,
                address(this)
            );
        }
        uint256 amountOut = IERC20(tokenOut).balanceOf(address(this));
        require(amountOutMin <= amountOut, 'ArkenRouter: INSUFFICIENT_OUTPUT');
        TransferHelper.safeTransfer(tokenOut, to, amountOut);
    }

    function unstakeToSingleETH(
        uint256 liquidity,
        uint256 amountOutMin,
        address tokenA,
        address tokenB,
        address payable to,
        uint256 deadline
    ) external ensure(deadline) {
        require(tokenA == WETH || tokenB == WETH, 'ArkenRouter: NOT_ETH_PAIR');
        _unstakeFor(tokenA, tokenB, msg.sender, address(this), liquidity);
        _removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            0,
            0,
            address(this),
            address(this)
        );
        if (tokenA == WETH) {
            _swapWithPair(
                tokenB,
                IERC20(tokenB).balanceOf(address(this)),
                0,
                tokenA,
                tokenB,
                address(this)
            );
        } else {
            _swapWithPair(
                tokenA,
                IERC20(tokenA).balanceOf(address(this)),
                0,
                tokenA,
                tokenB,
                address(this)
            );
        }
        uint256 amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOutMin <= amountOut, 'ArkenRouter: INSUFFICIENT_OUTPUT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    function unstakeToBoth(
        uint256 liquidity,
        address tokenA,
        address tokenB,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        _unstakeFor(tokenA, tokenB, msg.sender, address(this), liquidity);
        _removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            address(this),
            to
        );
    }

    function unstakeToBothETH(
        uint256 liquidity,
        address token,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        _unstakeFor(token, WETH, msg.sender, address(this), liquidity);
        (uint256 amountToken, uint256 amountETH) = _removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            address(this)
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            revert('ArkenRouter: PAIR_NOT_EXIST');
        }
        (uint256 reserveA, uint256 reserveB) = ArkenLPLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = ArkenLPLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    'ArkenRouter: INSUFFICIENT_B_AMOUNT'
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = ArkenLPLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    'ArkenRouter: INSUFFICIENT_A_AMOUNT'
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = pairFor(tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = ArkenLPLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IUniswapV2Pair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH)
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function _removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address from,
        address to
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pair = pairFor(tokenA, tokenB);
        if (from == address(this)) {
            IUniswapV2Pair(pair).transfer(pair, liquidity);
        } else {
            IUniswapV2Pair(pair).transferFrom(from, pair, liquidity);
        }
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);
        (address token0, ) = ArkenLPLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(amountA >= amountAMin, 'ArkenRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'ArkenRouter: INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        (amountA, amountB) = _removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            msg.sender,
            to
        );
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountETH)
    {
        (amountToken, amountETH) = _removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            msg.sender,
            address(this)
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual returns (uint256 amountB) {
        return ArkenLPLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual returns (uint256 amountOut) {
        return ArkenLPLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual returns (uint256 amountIn) {
        return ArkenLPLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        returns (uint256[] memory amounts)
    {
        return ArkenLPLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        returns (uint256[] memory amounts)
    {
        return ArkenLPLibrary.getAmountsIn(factory, amountOut, path);
    }

    function pairFor(address tokenA, address tokenB)
        public
        view
        virtual
        returns (address pair)
    {
        return ArkenLPLibrary.pairFor(factory, tokenA, tokenB);
    }

    function _increasePairAllowance(
        address pair,
        address spender,
        uint256 amount
    ) internal {
        if (IERC20(pair).allowance(address(this), spender) < amount) {
            IERC20(pair).approve(spender, MAX_UINT_256);
        }
    }
}

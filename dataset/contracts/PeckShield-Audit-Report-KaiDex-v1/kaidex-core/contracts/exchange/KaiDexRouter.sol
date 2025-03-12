// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./libraries/TransferHelper.sol";
import "./interfaces/IKaiDexRouter.sol";
import "./interfaces/IKaiDexFactory.sol";
import "./libraries/KaiDexLibrary.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IKRC20.sol";
import "./interfaces/IWKAI.sol";

contract KaiDexRouter is IKaiDexRouter {
    using SafeMath for uint256;

    address public factory;
    address public WKAI;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "KaiDexRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _WKAI) public {
        factory = _factory;
        WKAI = _WKAI;
    }

    receive() external payable {
        assert(msg.sender == WKAI); // only accept KAI via fallback from the WKAI contract
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
        require(amountADesired >= amountAMin);
        require(amountBDesired >= amountBMin);
        // create the pair if it doesn't exist yet
        if (IKaiDexFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IKaiDexFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = KaiDexLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = KaiDexLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "KaiDexRouter: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = KaiDexLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "KaiDexRouter: INSUFFICIENT_A_AMOUNT"
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
        override
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
        address pair = KaiDexLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IKAIDexPair(pair).mint(to);
    }

    function addLiquidityKAI(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountKAIMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountKAI,
            uint256 liquidity
        )
    {
        (amountToken, amountKAI) = _addLiquidity(
            token,
            WKAI,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountKAIMin
        );
        address pair = KaiDexLibrary.pairFor(factory, token, WKAI);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWKAI(WKAI).deposit{value: amountKAI}();
        assert(IWKAI(WKAI).transfer(pair, amountKAI));
        liquidity = IKAIDexPair(pair).mint(to);
        // refund dust kai, if any
        if (msg.value > amountKAI)
            TransferHelper.safeTransferKAI(msg.sender, msg.value - amountKAI);
    }

    // **** REMOVE LIQUIDITY ****
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
        override
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        address pair = KaiDexLibrary.pairFor(factory, tokenA, tokenB);
        IKAIDexPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IKAIDexPair(pair).burn(to);
        (address token0, ) = KaiDexLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(amountA >= amountAMin, "KaiDexRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "KaiDexRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityKAI(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountKAIMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountKAI)
    {
        (amountToken, amountKAI) = removeLiquidity(
            token,
            WKAI,
            liquidity,
            amountTokenMin,
            amountKAIMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWKAI(WKAI).withdraw(amountKAI);
        TransferHelper.safeTransferKAI(to, amountKAI);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = KaiDexLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IKAIDexPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    function removeLiquidityKAIWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountKAIMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        virtual
        override
        returns (uint256 amountToken, uint256 amountKAI)
    {
        address pair = KaiDexLibrary.pairFor(factory, token, WKAI);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IKAIDexPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountKAI) = removeLiquidityKAI(
            token,
            liquidity,
            amountTokenMin,
            amountKAIMin,
            to,
            deadline
        );
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityKAISupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountKAIMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountKAI) {
        (, amountKAI) = removeLiquidity(
            token,
            WKAI,
            liquidity,
            amountTokenMin,
            amountKAIMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(
            token,
            to,
            IKRC20(token).balanceOf(address(this))
        );
        IWKAI(WKAI).withdraw(amountKAI);
        TransferHelper.safeTransferKAI(to, amountKAI);
    }

    function removeLiquidityKAIWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountKAIMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountKAI) {
        address pair = KaiDexLibrary.pairFor(factory, token, WKAI);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IKAIDexPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        amountKAI = removeLiquidityKAISupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountKAIMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = KaiDexLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? KaiDexLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            IKAIDexPair(KaiDexLibrary.pairFor(factory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = KaiDexLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "KaiDexRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            KaiDexLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = KaiDexLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "KaiDexRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            KaiDexLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactKAIForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WKAI, "KaiDexRouter: INVALID_PATH");
        amounts = KaiDexLibrary.getAmountsOut(factory, msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "KaiDexRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWKAI(WKAI).deposit{value: amounts[0]}();
        assert(
            IWKAI(WKAI).transfer(
                KaiDexLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactKAI(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == WKAI, "KaiDexRouter: INVALID_PATH");
        amounts = KaiDexLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "KaiDexRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            KaiDexLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWKAI(WKAI).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferKAI(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForKAI(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == WKAI, "KaiDexRouter: INVALID_PATH");
        amounts = KaiDexLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "KaiDexRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            KaiDexLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWKAI(WKAI).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferKAI(to, amounts[amounts.length - 1]);
    }

    function swapKAIForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WKAI, "KaiDexRouter: INVALID_PATH");
        amounts = KaiDexLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= msg.value,
            "KaiDexRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        IWKAI(WKAI).deposit{value: amounts[0]}();
        assert(
            IWKAI(WKAI).transfer(
                KaiDexLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
        // refund dust kai, if any
        if (msg.value > amounts[0])
            TransferHelper.safeTransferKAI(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = KaiDexLibrary.sortTokens(input, output);
            IKAIDexPair pair = IKAIDexPair(
                KaiDexLibrary.pairFor(factory, input, output)
            );
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput = IKRC20(input).balanceOf(address(pair)).sub(
                    reserveInput
                );
                amountOutput = KaiDexLibrary.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            address to = i < path.length - 2
                ? KaiDexLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            KaiDexLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint256 balanceBefore = IKRC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IKRC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            "KaiDexRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactKAIForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WKAI, "KaiDexRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWKAI(WKAI).deposit{value: amountIn}();
        assert(
            IWKAI(WKAI).transfer(
                KaiDexLibrary.pairFor(factory, path[0], path[1]),
                amountIn
            )
        );
        uint256 balanceBefore = IKRC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IKRC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            "KaiDexRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForKAISupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WKAI, "KaiDexRouter: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            KaiDexLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IKRC20(WKAI).balanceOf(address(this));
        require(
            amountOut >= amountOutMin,
            "KaiDexRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWKAI(WKAI).withdraw(amountOut);
        TransferHelper.safeTransferKAI(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual override returns (uint256 amountB) {
        return KaiDexLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountOut) {
        return KaiDexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountIn) {
        return KaiDexLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return KaiDexLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return KaiDexLibrary.getAmountsIn(factory, amountOut, path);
    }
}

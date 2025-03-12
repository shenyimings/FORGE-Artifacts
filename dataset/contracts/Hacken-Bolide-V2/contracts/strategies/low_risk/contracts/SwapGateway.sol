// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./utils/UpgradeableBase.sol";
import "./interfaces/ISwap.sol";
import "./interfaces/IUniswapV3.sol";
import "./interfaces/IDODOSwap.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IAlgebra.sol";

library SwapGatewayLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    uint256 private constant BASE = 10**18;
    address private constant ZERO_ADDRESS = address(0);

    /**
     * @notice Generate abi.encodePacked path for UniswapV3 multihop swap
     * @param tokens list of tokens
     * @param fees list of pool fees
     */
    function generateEncodedPathWithFee(
        address[] memory tokens,
        uint24[] memory fees
    ) public pure returns (bytes memory) {
        require(tokens.length == fees.length + 1, "SG3");

        bytes memory path = new bytes(0);

        for (uint256 i = 0; i < fees.length; i++) {
            path = abi.encodePacked(path, tokens[i], fees[i]);
        }

        path = abi.encodePacked(path, tokens[tokens.length - 1]);

        return path;
    }

    /**
     * @notice Generate abi.encodePacked path for QuickswapV3 multihop swap
     * @param tokens list of tokens
     */
    function generateEncodedPath(address[] memory tokens)
        public
        pure
        returns (bytes memory)
    {
        bytes memory path = new bytes(0);

        for (uint256 i = 0; i < tokens.length; i++) {
            path = abi.encodePacked(path, tokens[i]);
        }

        return path;
    }

    /**
     * @notice get UniswapV3 amount out for 1 decimal
     * if token 1 = wBNB (deciaml = 18, price = 331USD), token 2 = USDC(decmail = 6), amountOut = 331000000
     * @param swapRouter swap router address
     * @param tokenIn Address of token input
     * @param tokenOut Address of token output
     * @return amountOut amount of tokenOut : decimal = tokenOut.decimals + 18 - tokenIn.decimals;
     */
    function getUniswapV3Quote(
        address swapRouter,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountOut) {
        // Find Pool
        (address uniswapV3Pool, ) = _findUniswapV3Pool(
            swapRouter,
            tokenIn,
            tokenOut
        );

        // Calulate Quote
        Slot0 memory slot0 = IUniswapV3Pool(uniswapV3Pool).slot0();

        amountOut = _calcUniswapV3Quote(
            tokenIn,
            IUniswapV3Pool(uniswapV3Pool).token0(),
            slot0.sqrtPriceX96
        );
    }

    /**
     * @notice get QuickswapV3 amount out for 1 decimal
     * if token 1 = wBNB (deciaml = 18, price = 331USD), token 2 = USDC(decmail = 6), amountOut = 331000000
     * @param swapRouter swap router address
     * @param tokenIn Address of token input
     * @param tokenOut Address of token output
     * @return amountOut amount of tokenOut : decimal = tokenOut.decimals + 18 - tokenIn.decimals;
     */
    function getQuickswapV3Quote(
        address swapRouter,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountOut) {
        // Find Pool
        (address pool, ) = _findQuickswapV3Pool(swapRouter, tokenIn, tokenOut);

        // Calulate Quote
        (uint160 price, , , , , , ) = IQuickswapV3Pool(pool).globalState();

        amountOut = _calcUniswapV3Quote(
            tokenIn,
            IQuickswapV3Pool(pool).token0(),
            price
        );
    }

    /**
     * @notice Calculate UniswapV3 price quote
     * @param tokenIn Address of token input
     * @param baseToken Base token of pool
     * @param price slot0 of pool
     * @return amountOut calculated result
     */
    function _calcUniswapV3Quote(
        address tokenIn,
        address baseToken,
        uint160 price
    ) private pure returns (uint256 amountOut) {
        if (tokenIn == baseToken) {
            if (price > 10**29) {
                amountOut = ((price * 10**9) / 2**96)**2;
            } else {
                amountOut = (uint256(price)**2 * BASE) / (2**192);
            }
        } else {
            if (price > 10**35) {
                amountOut = ((2**96 * 10**9) / (price))**2;
            } else {
                amountOut = (2**192 * BASE) / (uint256(price)**2);
            }
        }
    }

    /**
     * @notice Get pool, fee of uniswapV3
     * @param uniswapV3Router Address of uniswapRouter
     * @param tokenA Address of TokenA
     * @param tokenB Address of TokenB
     * @return pool address of pool
     * @return fee fee, 3000, 5000, 1000, if 0, pool isn't exist
     */
    function _findUniswapV3Pool(
        address uniswapV3Router,
        address tokenA,
        address tokenB
    ) public view returns (address pool, uint24 fee) {
        uint24[] memory fees = new uint24[](5);
        fees[0] = 100;
        fees[1] = 500;
        fees[2] = 3000;
        fees[3] = 5000;
        fees[4] = 10000;

        for (uint8 i = 0; i < 5; ) {
            pool = IUniswapV3Factory(
                IUniswapV3Router(uniswapV3Router).factory()
            ).getPool(tokenA, tokenB, fees[i]);
            if (pool != ZERO_ADDRESS) {
                fee = fees[i];
                break;
            }
            unchecked {
                ++i;
            }
        }

        require(fee > 0, "SG2");
    }

    /**
     * @notice Get pool, fee of QuickswapV3
     * @param quickswapV3Router Address of uniswapRouter
     * @param tokenA Address of TokenA
     * @param tokenB Address of TokenB
     * @return pool address of pool, address(0) if pool isn't exist
     * @return fee fee
     */
    function _findQuickswapV3Pool(
        address quickswapV3Router,
        address tokenA,
        address tokenB
    ) public view returns (address pool, uint24 fee) {
        pool = IQuickswapV3Factory(
            IQuickswapV3Router(quickswapV3Router).factory()
        ).poolByPair(tokenA, tokenB);

        if (pool != ZERO_ADDRESS) {
            (, , uint16 fee16, , , , ) = IQuickswapV3Pool(pool).globalState();
            fee = uint24(fee16);
        } else {
            revert("SG2");
        }
    }
}

contract SwapGateway is ISwapGateway, UpgradeableBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address private constant ZERO_ADDRESS = address(0);
    uint256 private constant BASE = 10**18;
    address private wETH;

    // 0: unregistered
    // 2: Pancakeswap/UniswapV2
    // 3: UniswapV3
    // 4: DODOV2
    // 5: QuickswapV3
    mapping(address => uint8) swapRouterVersion;

    event SetWETH(address wETH);
    event AddSwapRouter(address swapRouter, uint8 version);

    function __SwapGateway_init() public initializer {
        UpgradeableBase.initialize();
    }

    receive() external payable {}

    fallback() external payable {}

    /*** Owner function ***/

    /**
     * @notice Set wETH
     * @param _wETH Address of Wrapped ETH
     */
    function setWETH(address _wETH) external onlyOwnerAndAdmin {
        require(_wETH != ZERO_ADDRESS, "SG8");

        wETH = _wETH;
        emit SetWETH(_wETH);
    }

    /**
     * @notice Add SwapRouter
     * @param swapRouter Address of swapRouter
     * @param version version of swapRouter (2, 3)
     */
    function addSwapRouter(address swapRouter, uint8 version)
        external
        onlyOwnerAndAdmin
    {
        require(swapRouter != ZERO_ADDRESS, "SG8");
        require(version > 0, "SG4");

        swapRouterVersion[swapRouter] = version;
        emit AddSwapRouter(swapRouter, version);
    }

    /**
     * @notice Swap tokens using swapRouter
     * @param swapRouter Address of swapRouter contract
     * @param amountIn Amount for in
     * @param amountOut Amount for out
     * @param path swap path, path[0] is in, path[last] is out
     * @param isExactInput true : swapExactTokensForTokens, false : swapTokensForExactTokens
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function swap(
        address swapRouter,
        uint256 amountIn,
        uint256 amountOut,
        address[] memory path,
        bool isExactInput,
        uint256 deadline
    ) external payable override returns (uint256[] memory amounts) {
        uint8 version = swapRouterVersion[swapRouter];
        require(version > 0, "SG4");

        // Change ZERO_ADDRESS to WETH in path
        address _wETH = wETH;
        for (uint256 i = 0; i < path.length; ) {
            if (path[i] == ZERO_ADDRESS) path[i] = _wETH;
            unchecked {
                ++i;
            }
        }

        if (version == 2) {
            if (isExactInput) {
                return
                    _swapV2ExactIn(
                        swapRouter,
                        amountIn,
                        amountOut,
                        path,
                        deadline
                    );
            } else {
                return
                    _swapV2ExactOut(
                        swapRouter,
                        amountOut,
                        amountIn,
                        path,
                        deadline
                    );
            }
        } else if (version == 3) {
            if (isExactInput) {
                return
                    _swapV3ExactIn(
                        swapRouter,
                        amountIn,
                        amountOut,
                        path,
                        deadline
                    );
            } else {
                return
                    _swapV3ExactOut(
                        swapRouter,
                        amountOut,
                        amountIn,
                        path,
                        deadline
                    );
            }
        } else if (version == 4) {
            return
                _swapDODOV2(
                    swapRouter,
                    amountIn,
                    amountOut,
                    path,
                    isExactInput,
                    deadline
                );
        } else if (version == 5) {
            if (isExactInput) {
                return
                    _swapV5ExactIn(
                        swapRouter,
                        amountIn,
                        amountOut,
                        path,
                        deadline
                    );
            } else {
                return
                    _swapV5ExactOut(
                        swapRouter,
                        amountOut,
                        amountIn,
                        path,
                        deadline
                    );
            }
        } else {
            revert("SG6");
        }
    }

    /**
     * @notice get swap out amount
     * @param swapRouter swap router address
     * @param amountIn amount of tokenIn : decimal = token.decimals;
     * @param path path of swap
     * @return amountOut amount of tokenOut : decimal = token.decimals;
     */
    function quoteExactInput(
        address swapRouter,
        uint256 amountIn,
        address[] memory path
    ) external view override returns (uint256 amountOut) {
        if (amountIn > 0) {
            uint8 version = swapRouterVersion[swapRouter];
            address _wETH = wETH;
            uint256 i;

            // Change ZERO_ADDRESS to wETH
            for (i = 0; i < path.length; ) {
                if (path[i] == ZERO_ADDRESS) path[i] = _wETH;
                unchecked {
                    ++i;
                }
            }

            if (version == 2) {
                uint256[] memory amountOutList = IPancakeRouter01(swapRouter)
                    .getAmountsOut(amountIn, path);

                amountOut = amountOutList[amountOutList.length - 1];
            } else if (version == 3) {
                amountOut = amountIn;
                for (i = 0; i < path.length - 1; ) {
                    amountOut =
                        (amountOut *
                            SwapGatewayLib.getUniswapV3Quote(
                                swapRouter,
                                path[i],
                                path[i + 1]
                            )) /
                        BASE;

                    unchecked {
                        ++i;
                    }
                }
            } else if (version == 4) {
                // path[0] : tokenIn, path[1...] array of pools
                require(path.length > 1, "SG5");

                address tokenIn = path[0];
                amountOut = amountIn;

                for (i = 1; i < path.length; ) {
                    address pool = path[i];
                    if (tokenIn == IDODOStorage(pool)._BASE_TOKEN_()) {
                        (amountOut, ) = IDODOStorage(pool).querySellBase(
                            tx.origin,
                            amountOut
                        );
                        tokenIn = IDODOStorage(pool)._QUOTE_TOKEN_();
                    } else if (tokenIn == IDODOStorage(pool)._QUOTE_TOKEN_()) {
                        (amountOut, ) = IDODOStorage(pool).querySellQuote(
                            tx.origin,
                            amountOut
                        );
                        tokenIn = IDODOStorage(pool)._BASE_TOKEN_();
                    } else {
                        revert("SG6");
                    }

                    unchecked {
                        ++i;
                    }
                }
            } else if (version == 5) {
                amountOut = amountIn;
                for (i = 0; i < path.length - 1; ) {
                    amountOut =
                        (amountOut *
                            SwapGatewayLib.getQuickswapV3Quote(
                                swapRouter,
                                path[i],
                                path[i + 1]
                            )) /
                        BASE;

                    unchecked {
                        ++i;
                    }
                }
            } else {
                revert("SG6");
            }
        }
    }

    // TODO: implement for all cases
    function quoteExactOutput(
        address swapRouter,
        uint256 amountOut,
        address[] memory path
    ) external view override returns (uint256 amountIn) {
        if (amountOut == 0) {
            return 0;
        }

        uint8 version = swapRouterVersion[swapRouter];
        address _wETH = wETH;
        uint256 i;

        // Change ZERO_ADDRESS to wETH
        for (i = 0; i < path.length; ) {
            if (path[i] == ZERO_ADDRESS) path[i] = _wETH;
            unchecked {
                ++i;
            }
        }

        if (version == 2) {
            uint256[] memory amountInList = IPancakeRouter01(swapRouter)
                .getAmountsIn(amountOut, path);

            amountIn = amountInList[0];
        }
    }

    /*** Private Function ***/

    /**
     * @notice Receive an as many output tokens as possible for an exact amount of input tokens.
     * @param swapRouter Address of swap router
     * @param amountIn TPayable amount of input tokens.
     * @param amountOutMin The minimum amount tokens to receive.
     * @param path (address[]) An array of token addresses. path.length must be >= 2.
     * Pools for each consecutive pair of addresses must exist and have liquidity.
     * address(0) will be used for wrapped ETH
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function _swapV2ExactIn(
        address swapRouter,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline
    ) private returns (uint256[] memory amounts) {
        address _wETH = wETH;

        // swapExactETHForTokens
        if (path[0] == _wETH) {
            require(msg.value >= amountIn, "SG0");

            amounts = IPancakeRouter01(swapRouter).swapExactETHForTokens{
                value: amountIn
            }(amountOutMin, path, msg.sender, deadline);

            // If too mucn ETH has been sent, send it back to sender
            uint256 remainedToken = msg.value - amountIn;
            if (remainedToken > 0) {
                _send(payable(msg.sender), remainedToken);
            }

            return amounts;
        }

        IERC20Upgradeable(path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            amountIn
        );
        _approveTokenForSwapRouter(path[0], swapRouter, amountIn);

        // swapExactTokensForETH
        if (path[path.length - 1] == _wETH) {
            return
                IPancakeRouter01(swapRouter).swapExactTokensForETH(
                    amountIn,
                    amountOutMin,
                    path,
                    msg.sender,
                    deadline
                );
        }

        // swapExactTokensForTokens
        return
            IPancakeRouter01(swapRouter).swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                msg.sender,
                deadline
            );
    }

    /**
     * @notice Receive an exact amount of output tokens for as few input tokens as possible.
     * @param swapRouter Address of swap router
     * @param amountOut Payable amount of input tokens.
     * @param amountInMax The minimum amount tokens to input.
     * @param path (address[]) An array of token addresses. path.length must be >= 2.
     * Pools for each consecutive pair of addresses must exist and have liquidity.
     * address(0) will be used for wrapped ETH
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function _swapV2ExactOut(
        address swapRouter,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        uint256 deadline
    ) private returns (uint256[] memory amounts) {
        address _wETH = wETH;
        uint256 remainedToken;

        // swapETHForExactTokens
        if (path[0] == _wETH) {
            require(msg.value >= amountInMax, "SG0");

            amounts = IPancakeRouter01(swapRouter).swapETHForExactTokens{
                value: amountInMax
            }(amountOut, path, msg.sender, deadline);

            remainedToken = address(this).balance;
            if (remainedToken > 0) {
                _send(payable(msg.sender), remainedToken);
            }

            return amounts;
        }

        IERC20Upgradeable(path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            amountInMax
        );
        _approveTokenForSwapRouter(path[0], swapRouter, amountInMax);

        // swapTokensForExactETH
        if (path[path.length - 1] == _wETH) {
            amounts = IPancakeRouter01(swapRouter).swapTokensForExactETH(
                amountOut,
                amountInMax,
                path,
                msg.sender,
                deadline
            );
        } else {
            // swapTokensForExactTokens
            amounts = IPancakeRouter01(swapRouter).swapTokensForExactTokens(
                amountOut,
                amountInMax,
                path,
                msg.sender,
                deadline
            );
        }

        remainedToken = IERC20Upgradeable(path[0]).balanceOf(address(this));
        if (remainedToken > 0) {
            IERC20Upgradeable(path[0]).safeTransfer(msg.sender, remainedToken);
        }

        return amounts;
    }

    /**
     * @notice Receive an as many output tokens as possible for an exact amount of input tokens.
     * @param swapRouter Address of swap router
     * @param amountIn TPayable amount of input tokens.
     * @param amountOutMin The minimum amount tokens to receive.
     * @param path path to swap
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function _swapV3ExactIn(
        address swapRouter,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline
    ) private returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        uint256 length = path.length;
        address recipient = msg.sender;
        address _wETH = wETH;

        if (path[0] == _wETH) {
            require(msg.value >= amountIn, "SG0");
        } else {
            IERC20Upgradeable(path[0]).safeTransferFrom(
                msg.sender,
                address(this),
                amountIn
            );
            _approveTokenForSwapRouter(path[0], swapRouter, amountIn);
        }

        if (path[length - 1] == _wETH) {
            recipient = address(this);
        }

        // Single
        if (length == 2) {
            // Check pool and fee
            (, uint24 fee) = SwapGatewayLib._findUniswapV3Pool(
                swapRouter,
                path[0],
                path[1]
            );

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: path[0],
                    tokenOut: path[1],
                    fee: fee,
                    recipient: recipient,
                    deadline: deadline,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMin,
                    sqrtPriceLimitX96: 0
                });

            if (path[0] == _wETH) {
                amounts[0] = ISwapRouter(swapRouter).exactInputSingle{
                    value: amountIn
                }(params);

                // If too much ETH has been sent, send it back to sender
                uint256 remainedToken = msg.value - amountIn;
                if (remainedToken > 0) {
                    _send(payable(msg.sender), remainedToken);
                }
            } else {
                amounts[0] = ISwapRouter(swapRouter).exactInputSingle(params);
            }
        } else {
            // Multihop
            uint24[] memory fees = new uint24[](length - 1);

            for (uint256 i = 0; i < length - 1; ) {
                // Get fee
                (, fees[i]) = SwapGatewayLib._findUniswapV3Pool(
                    swapRouter,
                    path[i],
                    path[i + 1]
                );

                unchecked {
                    ++i;
                }
            }

            ISwapRouter.ExactInputParams memory params = ISwapRouter
                .ExactInputParams({
                    path: SwapGatewayLib.generateEncodedPathWithFee(path, fees),
                    recipient: recipient,
                    deadline: deadline,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMin
                });

            if (path[0] == _wETH) {
                amounts[0] = ISwapRouter(swapRouter).exactInput{
                    value: amountIn
                }(params);
            } else {
                amounts[0] = ISwapRouter(swapRouter).exactInput(params);
            }
        }

        // If too much ETH has been sent, send it back to sender
        if (path[0] == _wETH) {
            uint256 remainedToken = msg.value - amountIn;
            if (remainedToken > 0) {
                _send(payable(msg.sender), remainedToken);
            }
        }

        // If receive ETH, unWrap it
        if (path[length - 1] == _wETH) {
            IWETH(_wETH).withdraw(
                IERC20Upgradeable(_wETH).balanceOf(address(this))
            );
            _send(payable(msg.sender), address(this).balance);
        }
    }

    /**
     * @notice Receive an exact amount of output tokens for as few input tokens as possible.
     * @param swapRouter Address of swap router
     * @param amountOut Payable amount of input tokens.
     * @param amountInMax The minimum amount tokens to input.
     * @param path path to swap
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function _swapV3ExactOut(
        address swapRouter,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        uint256 deadline
    ) private returns (uint256[] memory amounts) {
        uint256 remainedToken;
        amounts = new uint256[](1);
        uint256 length = path.length;
        address recipient = msg.sender;
        address _wETH = wETH;

        if (path[0] == _wETH) {
            require(msg.value >= amountInMax, "SG0");
        } else {
            IERC20Upgradeable(path[0]).safeTransferFrom(
                msg.sender,
                address(this),
                amountInMax
            );
            _approveTokenForSwapRouter(path[0], swapRouter, amountInMax);
        }

        if (path[length - 1] == _wETH) {
            recipient = address(this);
        }

        // Single Swap
        if (length == 2) {
            // Check pool and fee
            (, uint24 fee) = SwapGatewayLib._findUniswapV3Pool(
                swapRouter,
                path[0],
                path[1]
            );

            ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
                .ExactOutputSingleParams({
                    tokenIn: path[0],
                    tokenOut: path[1],
                    fee: fee,
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax,
                    sqrtPriceLimitX96: 0
                });

            if (path[0] == _wETH) {
                amounts[0] = ISwapRouter(swapRouter).exactOutputSingle{
                    value: amountInMax
                }(params);
            } else {
                amounts[0] = ISwapRouter(swapRouter).exactOutputSingle(params);
            }
        } else {
            // Multihop
            uint24[] memory fees = new uint24[](length - 1);

            // Get reverse path
            address[] memory reversePath = new address[](length);
            for (uint256 i = 0; i < length; ) {
                reversePath[i] = path[length - 1 - i];

                unchecked {
                    ++i;
                }
            }

            for (uint256 i = 0; i < length - 1; ) {
                // Get fee
                (, fees[i]) = SwapGatewayLib._findUniswapV3Pool(
                    swapRouter,
                    reversePath[i],
                    reversePath[i + 1]
                );

                unchecked {
                    ++i;
                }
            }

            ISwapRouter.ExactOutputParams memory params = ISwapRouter
                .ExactOutputParams({
                    path: SwapGatewayLib.generateEncodedPathWithFee(
                        reversePath,
                        fees
                    ),
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax
                });

            if (path[0] == _wETH) {
                amounts[0] = ISwapRouter(swapRouter).exactOutput{
                    value: amountInMax
                }(params);
            } else {
                amounts[0] = ISwapRouter(swapRouter).exactOutput(params);
            }
        }

        // send back remained token
        if (path[0] == _wETH) {
            IUniswapV3Router(swapRouter).refundETH(); // Take back leftover ETH
            remainedToken = address(this).balance;
            if (remainedToken > 0) {
                _send(payable(msg.sender), remainedToken);
            }
        } else {
            remainedToken = IERC20Upgradeable(path[0]).balanceOf(address(this));
            if (remainedToken > 0) {
                IERC20Upgradeable(path[0]).safeTransfer(
                    msg.sender,
                    remainedToken
                );
            }
        }

        // If receive ETH, unWrap it
        if (path[length - 1] == _wETH) {
            IWETH(_wETH).withdraw(
                IERC20Upgradeable(_wETH).balanceOf(address(this))
            );
            _send(payable(msg.sender), address(this).balance);
        }
    }

    /**
     * @notice Receive an as many output tokens as possible for an exact amount of input tokens.
     * @param swapRouter Address of swap router
     * @param amountIn TPayable amount of input tokens.
     * @param amountOutMin The minimum amount tokens to receive.
     * @param path path to swap
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function _swapV5ExactIn(
        address swapRouter,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline
    ) private returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        uint256 length = path.length;
        address recipient = msg.sender;
        address _wETH = wETH;

        if (path[0] == _wETH) {
            require(msg.value >= amountIn, "SG0");
        } else {
            IERC20Upgradeable(path[0]).safeTransferFrom(
                msg.sender,
                address(this),
                amountIn
            );
            _approveTokenForSwapRouter(path[0], swapRouter, amountIn);
        }

        if (path[length - 1] == _wETH) {
            recipient = address(this);
        }

        // Single
        if (length == 2) {
            // Check pool and fee
            SwapGatewayLib._findQuickswapV3Pool(swapRouter, path[0], path[1]);

            IAlgebraSwapRouter.ExactInputSingleParams
                memory params = IAlgebraSwapRouter.ExactInputSingleParams({
                    tokenIn: path[0],
                    tokenOut: path[1],
                    recipient: recipient,
                    deadline: deadline,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMin,
                    limitSqrtPrice: 0
                });

            if (path[0] == _wETH) {
                amounts[0] = IAlgebraSwapRouter(swapRouter).exactInputSingle{
                    value: amountIn
                }(params);

                // If too much ETH has been sent, send it back to sender
                uint256 remainedToken = msg.value - amountIn;
                if (remainedToken > 0) {
                    _send(payable(msg.sender), remainedToken);
                }
            } else {
                amounts[0] = IAlgebraSwapRouter(swapRouter).exactInputSingle(
                    params
                );
            }
        } else {
            // Multihop
            // Check pool and fee
            for (uint256 i = 0; i < length - 1; ) {
                SwapGatewayLib._findQuickswapV3Pool(
                    swapRouter,
                    path[i],
                    path[i + 1]
                );

                unchecked {
                    ++i;
                }
            }

            IAlgebraSwapRouter.ExactInputParams
                memory params = IAlgebraSwapRouter.ExactInputParams({
                    path: SwapGatewayLib.generateEncodedPath(path),
                    recipient: recipient,
                    deadline: deadline,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMin
                });

            if (path[0] == _wETH) {
                amounts[0] = IAlgebraSwapRouter(swapRouter).exactInput{
                    value: amountIn
                }(params);
            } else {
                amounts[0] = IAlgebraSwapRouter(swapRouter).exactInput(params);
            }
        }

        // If too much ETH has been sent, send it back to sender
        if (path[0] == _wETH) {
            uint256 remainedToken = msg.value - amountIn;
            if (remainedToken > 0) {
                _send(payable(msg.sender), remainedToken);
            }
        }

        // If receive ETH, unWrap it
        if (path[length - 1] == _wETH) {
            IWETH(_wETH).withdraw(
                IERC20Upgradeable(_wETH).balanceOf(address(this))
            );
            _send(payable(msg.sender), address(this).balance);
        }
    }

    /**
     * @notice Receive an exact amount of output tokens for as few input tokens as possible.
     * @param swapRouter Address of swap router
     * @param amountOut Payable amount of input tokens.
     * @param amountInMax The minimum amount tokens to input.
     * @param path path to swap
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function _swapV5ExactOut(
        address swapRouter,
        uint256 amountOut,
        uint256 amountInMax,
        address[] memory path,
        uint256 deadline
    ) private returns (uint256[] memory amounts) {
        uint256 remainedToken;
        amounts = new uint256[](1);
        uint256 length = path.length;
        address recipient = msg.sender;
        address _wETH = wETH;

        if (path[0] == _wETH) {
            require(msg.value >= amountInMax, "SG0");
        } else {
            IERC20Upgradeable(path[0]).safeTransferFrom(
                msg.sender,
                address(this),
                amountInMax
            );
            _approveTokenForSwapRouter(path[0], swapRouter, amountInMax);
        }

        if (path[length - 1] == _wETH) {
            recipient = address(this);
        }

        // Single Swap
        if (length == 2) {
            // Check pool and fee
            (, uint24 fee) = SwapGatewayLib._findQuickswapV3Pool(
                swapRouter,
                path[0],
                path[1]
            );

            IAlgebraSwapRouter.ExactOutputSingleParams
                memory params = IAlgebraSwapRouter.ExactOutputSingleParams({
                    tokenIn: path[0],
                    tokenOut: path[1],
                    fee: fee,
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax,
                    limitSqrtPrice: 0
                });

            if (path[0] == _wETH) {
                amounts[0] = IAlgebraSwapRouter(swapRouter).exactOutputSingle{
                    value: amountInMax
                }(params);
            } else {
                amounts[0] = IAlgebraSwapRouter(swapRouter).exactOutputSingle(
                    params
                );
            }
        } else {
            // Multihop

            // Get reverse path
            address[] memory reversePath = new address[](length);
            for (uint256 i = 0; i < length; ) {
                reversePath[i] = path[length - 1 - i];

                unchecked {
                    ++i;
                }
            }

            // Check pool, fee
            for (uint256 i = 0; i < length - 1; ) {
                SwapGatewayLib._findQuickswapV3Pool(
                    swapRouter,
                    reversePath[i],
                    reversePath[i + 1]
                );

                unchecked {
                    ++i;
                }
            }

            IAlgebraSwapRouter.ExactOutputParams
                memory params = IAlgebraSwapRouter.ExactOutputParams({
                    path: SwapGatewayLib.generateEncodedPath(reversePath),
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax
                });

            if (path[0] == _wETH) {
                amounts[0] = IAlgebraSwapRouter(swapRouter).exactOutput{
                    value: amountInMax
                }(params);
            } else {
                amounts[0] = IAlgebraSwapRouter(swapRouter).exactOutput(params);
            }
        }

        // send back remained token
        if (path[0] == _wETH) {
            IQuickswapV3Router(swapRouter).refundNativeToken(); // Take back leftover ETH
            remainedToken = address(this).balance;
            if (remainedToken > 0) {
                _send(payable(msg.sender), remainedToken);
            }
        } else {
            remainedToken = IERC20Upgradeable(path[0]).balanceOf(address(this));
            if (remainedToken > 0) {
                IERC20Upgradeable(path[0]).safeTransfer(
                    msg.sender,
                    remainedToken
                );
            }
        }

        // If receive ETH, unWrap it
        if (path[length - 1] == _wETH) {
            IWETH(_wETH).withdraw(
                IERC20Upgradeable(_wETH).balanceOf(address(this))
            );
            _send(payable(msg.sender), address(this).balance);
        }
    }

    /**
     * @notice Receive an as many output tokens as possible for an exact amount of input tokens.
     * @param swapRouter Address of swap router
     * @param amountIn Amount of input tokens.
     * @param amountOutMin The minimum amount tokens to receive.
     * @param path path to swap path[0] : tokenIn, tokenOut, path[2...] pool, path[last] : tokenOut
     * @param isIncentive true : it is incentive
     * @param deadline Unix timestamp deadline
     */
    function _swapDODOV2(
        address swapRouter,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        bool isIncentive,
        uint256 deadline
    ) private returns (uint256[] memory amounts) {
        uint256 remainedToken;
        address _wETH = wETH;
        uint256 length = path.length;

        require(length > 2, "SG5");
        amounts = new uint256[](1);

        // Get pairs, directions
        address[] memory dodoPairs = new address[](length - 2);
        uint256 directions = 0;
        {
            address tokenIn = path[0];
            uint256 i;

            for (i = 0; i < length - 2; ) {
                dodoPairs[i] = path[i + 1];

                if (IDODOStorage(path[i + 1])._BASE_TOKEN_() == tokenIn) {
                    directions = directions + (0 << i);
                    tokenIn = IDODOStorage(path[i + 1])._QUOTE_TOKEN_();
                } else {
                    directions = directions + (1 << i);
                    tokenIn = IDODOStorage(path[i + 1])._BASE_TOKEN_();
                }

                unchecked {
                    ++i;
                }
            }
        }

        if (path[0] == _wETH) {
            require(msg.value >= amountIn, "SG0");
        } else {
            IERC20Upgradeable(path[0]).safeTransferFrom(
                msg.sender,
                address(this),
                amountIn
            );

            // Approve to DODO_APPROVE
            _approveTokenForSwapRouter(
                path[0],
                IDODOApproveProxy(
                    IDODOV2Proxy02(swapRouter)._DODO_APPROVE_PROXY_()
                )._DODO_APPROVE_(),
                amountIn
            );
        }

        if (path[0] == _wETH) {
            amounts[0] = IDODOV2Proxy02(swapRouter).dodoSwapV2ETHToToken{
                value: amountIn
            }(
                path[length - 1],
                amountOutMin,
                dodoPairs,
                directions,
                isIncentive,
                deadline
            );

            IERC20Upgradeable(path[length - 1]).safeTransfer(
                msg.sender,
                amounts[0]
            );
        } else if (path[length - 1] == _wETH) {
            amounts[0] = IDODOV2Proxy02(swapRouter).dodoSwapV2TokenToETH(
                path[0],
                amountIn,
                amountOutMin,
                dodoPairs,
                directions,
                isIncentive,
                deadline
            );

            _send(payable(msg.sender), amounts[0]);
        } else {
            amounts[0] = IDODOV2Proxy02(swapRouter).dodoSwapV2TokenToToken(
                path[0],
                path[length - 1],
                amountIn,
                amountOutMin,
                dodoPairs,
                directions,
                isIncentive,
                deadline
            );

            IERC20Upgradeable(path[length - 1]).safeTransfer(
                msg.sender,
                amounts[0]
            );
        }

        // send back remained token
        if (path[0] == _wETH) {
            remainedToken = address(this).balance;
            if (remainedToken > 0) {
                _send(payable(msg.sender), remainedToken);
            }
        } else {
            remainedToken = IERC20Upgradeable(path[0]).balanceOf(address(this));
            if (remainedToken > 0) {
                IERC20Upgradeable(path[0]).safeTransfer(
                    msg.sender,
                    remainedToken
                );
            }
        }
    }

    /**
     * @notice Send ETH to address
     * @param _to target address to receive ETH
     * @param amount ETH amount (wei) to be sent
     */
    function _send(address payable _to, uint256 amount) private {
        (bool sent, ) = _to.call{value: amount}("");
        require(sent, "SG1");
    }

    function _approveTokenForSwapRouter(
        address token,
        address swapRouter,
        uint256 amount
    ) private {
        uint256 allowance = IERC20Upgradeable(token).allowance(
            address(this),
            swapRouter
        );

        if (allowance == 0) {
            IERC20Upgradeable(token).safeApprove(swapRouter, amount);
            return;
        }

        if (allowance < amount) {
            IERC20Upgradeable(token).safeIncreaseAllowance(
                swapRouter,
                amount - allowance
            );
        }
    }
}

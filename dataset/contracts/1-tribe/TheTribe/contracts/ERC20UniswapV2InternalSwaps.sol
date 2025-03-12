// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;

    function mint(address to) external;
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IWETH {
    function deposit() external payable;
}

/**
 * @notice UniswapV2Pair does not allow to receive to token0 or token1.
 * As a workaround, this contract can receive tokens and has max approval
 * for the creator.
 */
contract ERC20HolderWithApproval {
    constructor(address token) {
        IERC20(token).approve(msg.sender, type(uint256).max);
    }
}

/**
 * @notice Gas optimized ERC20 token based on solmate's ERC20 contract.
 * @dev Optimizations assume a UniswapV2 WETH pair as main liquidity.
 */
abstract contract ERC20UniswapV2InternalSwaps {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private immutable wethReceiver;
    address public immutable pair;
    bool private immutable tokenIsToken0;

    constructor() {
        tokenIsToken0 = address(this) < WETH;
        pair = IUniswapV2Factory(FACTORY).createPair(address(this), WETH);
        wethReceiver = address(new ERC20HolderWithApproval(WETH));
    }

    /**
     * @dev Swap tokens to WETH directly on pair, to save gas.
     * No check for minimal return, susceptible to price manipulation!
     */
    function _swapForWETH(uint amountToken, address to) internal {
        uint amountWeth = _getAmountWeth(amountToken);
        _transferFromContractBalance(pair, amountToken);
        // Pair prevents receiving tokens to one of the pairs addresses
        IUniswapV2Pair(pair).swap(tokenIsToken0 ? 0 : amountWeth, tokenIsToken0 ? amountWeth : 0, wethReceiver, new bytes(0));
        IERC20(WETH).transferFrom(wethReceiver, to, amountWeth);
    }

    /**
     * @dev Add tokens and WETH to liquidity, directly on pair, to save gas.
     * No check for minimal return, susceptible to price manipulation!
     * Sufficient WETH in contract balancee assumed!
     */
    function _addLiquidity(
        uint amountToken,
        address to
    ) internal returns (uint amountWeth) {
        amountWeth = _quoteToken(amountToken);
        _transferFromContractBalance(pair, amountToken);
        IERC20(WETH).transferFrom(address(this), pair, amountWeth);
        IUniswapV2Pair(pair).mint(to);
    }

    /**
     * @dev Add tokens and WETH as initial liquidity, directly on pair, to save gas.
     * No checks performed. Caller has to make sure to have access to the token before public!
     * Sufficient WETH in contract balancee assumed!
     */
    function _addInitialLiquidity(
        uint amountToken,
        uint amountWeth,
        address to
    ) internal {
        _transferFromContractBalance(pair, amountToken);
        IERC20(WETH).transferFrom(address(this), pair, amountWeth);
        IUniswapV2Pair(pair).mint(to);
    }

    /**
     * @dev Add tokens and ETH as initial liquidity, directly on pair, to save gas.
     * No checks performed. Caller has to make sure to have access to the token before public!
     * Sufficient ETH in contract balancee assumed!
     */
    function _addInitialLiquidityEth(
        uint amountToken,
        uint amountEth,
        address to
    ) internal {
        IWETH(WETH).deposit{value: amountEth}();
        _addInitialLiquidity(amountToken, amountEth, to);
    }

    /** @dev Transfer all WETH from contract balance to `to`. */
    function _sweepWeth(address to) internal returns (uint amountWeth) {
        amountWeth = IERC20(WETH).balanceOf(address(this));
        IERC20(WETH).transferFrom(address(this), to, amountWeth);
    }

    /** @dev Transfer all ETH from contract balance to `to`. */
    function _sweepEth(address to) internal {
        _safeTransferETH(to, address(this).balance);
    }

    /** @dev Quote `amountToken` in ETH, assuming no fees (used for liquidity). */
    function _quoteToken(
        uint amountToken
    ) internal view returns (uint amountEth) {
        (uint reserveToken, uint reserveEth) = _getReserve();
        amountEth = (amountToken * reserveEth) / reserveToken;
    }

    /** @dev Quote `amountToken` in WETH, assuming 0.3% uniswap fees (used for swap). */
    function _getAmountWeth(
        uint amounToken
    ) internal view returns (uint amountWeth) {
        (uint reserveToken, uint reserveWeth) = _getReserve();
        uint amountTokenWithFee = amounToken * 997;
        uint numerator = amountTokenWithFee * reserveWeth;
        uint denominator = (reserveToken * 1000) + amountTokenWithFee;
        amountWeth = numerator / denominator;
    }

    /** @dev Quote `amountWeth` in tokens, assuming 0.3% uniswap fees (used for swap). */
    function _getAmountToken(
        uint amounWeth,
        uint reserveToken,
        uint reserveWeth
    ) internal pure returns (uint amountToken) {
        uint numerator = reserveToken * amounWeth * 1000;
        uint denominator = (reserveWeth - amounWeth) * 997;
        amountToken = (numerator / denominator) + 1;
    }

    /** @dev Get reserves of pair. */
    function _getReserve()
        internal
        view
        returns (uint reserveToken, uint reserveWeth)
    {
        (uint112 reserveToken0, uint112 reserveToken1) = IUniswapV2Pair(pair).getReserves();
        (reserveToken, reserveWeth) = tokenIsToken0 ? (reserveToken0, reserveToken1) : (reserveToken1, reserveToken0);
    }

    /** @dev Transfer `amount` ETH to `to` gas efficiently. */
    function _safeTransferETH(address to, uint256 amount) internal {
        bool success;

        /// @solidity memory-safe-assembly
        assembly { // solhint-disable-line no-inline-assembly
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /** @dev Returns true if `_address` is a contract. */
    function _isContract(address _address) internal view returns (bool) {
        uint32 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(_address)
        }
        return (size > 0);
    }

    /** @dev Transfeer `amount` tokens from contract balance to `to`. */
    function _transferFromContractBalance(
        address to,
        uint256 amount
    ) internal virtual;
}

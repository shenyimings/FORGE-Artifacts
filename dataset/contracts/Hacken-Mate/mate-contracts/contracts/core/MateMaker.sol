// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice This contract collects tokens for protocol fees and then handles tranfering rewards for $xMATE holders by swaping those tokens for $MATE
 * @dev Inspired by SushiMaker contract (https://github.com/sushiswap/sushiswap/blob/canary/contracts/SushiMaker.sol)
 */

contract MateMaker is Ownable {
    using SafeERC20 for IERC20;

    IUniswapV2Factory public immutable factory;
    address private immutable mate;
    address private immutable weth;
    address public immutable xMate;

    constructor(
        address _factory,
        address _mate,
        address _weth,
        address _xMate
    ) {
        factory = IUniswapV2Factory(_factory);
        mate = _mate;
        weth = _weth;
        xMate = _xMate;
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Only EOA");
        _;
    }

    function convert(address token, uint256 amount) external onlyEOA {
        _convertStep(token, amount);
    }

    function _convertStep(address token, uint256 amount)
        internal
        returns (uint256 mateOut)
    {
        if (token == mate) {
            IERC20(mate).safeTransfer(xMate, amount);
            mateOut = amount;
        } else if (token == weth) {
            mateOut = _toMATE(weth, amount);
        } else {
            address bridge = bridgeFor(token);
            amount = _swap(token, bridge, amount, address(this));
            mateOut = _convertStep(bridge, amount);
        }
    }

    function _swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        address to
    ) internal returns (uint256 amountOut) {
        // Checks
        IUniswapV2Pair pair = IUniswapV2Pair(
            factory.getPair(fromToken, toToken)
        );
        require(address(pair) != address(0), "Cannot convert");

        // Interactions
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amountInWithFee = amountIn * 997;
        if (fromToken == pair.token0()) {
            amountOut =
                (amountInWithFee * reserve1) /
                ((reserve0 * 1000) + amountIn);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
        } else {
            amountOut =
                (amountInWithFee * reserve0) /
                ((reserve1 * 1000) + amountIn);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
        }
    }

    function _toMATE(address token, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        amountOut = _swap(token, mate, amountIn, xMate);
    }

    mapping(address => address) internal _bridges;

    function bridgeFor(address token) public view returns (address bridge) {
        bridge = _bridges[token];
        if (bridge == address(0)) {
            bridge = weth;
        }
    }

    function setBridge(address token, address bridge) external onlyOwner {
        require(
            token != mate && token != weth && token != bridge,
            "Invalid bridge"
        );

        _bridges[token] = bridge;
        emit BridgeSet(token, bridge);
    }

    event BridgeSet(address indexed token, address indexed bridge);
}

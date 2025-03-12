// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../exchange/interfaces/IKaiDexFactory.sol";
import "../exchange/interfaces/IKAIDexPair.sol";

contract KaidexMaker is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IKaiDexFactory public immutable factory;
    address public bar;
    address public kdx;
    address public immutable wkai;

    mapping(address => address) internal _bridges;
    event LogBridgeSet(address indexed token, address indexed bridge);
    event LogConvert(
        address indexed server,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 amountKDX
    );

    address public converter;

    constructor(
        address _factory,
        address _bar,
        address _kdx,
        address _wkai
    ) public {
        factory = IKaiDexFactory(_factory);
        bar = _bar;
        kdx = _kdx;
        wkai = _wkai;
        converter = msg.sender;
    }

    function setBar(address _bar) public onlyOwner {
        bar = _bar;
    }

    function setKDX(address _kdx) public onlyOwner {
        kdx = _kdx;
    }

    function bridgeFor(address token) public view returns (address bridge) {
        bridge = _bridges[token];
        if (bridge == address(0)) {
            bridge = wkai;
        }
    }

    function setBridge(address token, address bridge) external onlyOwner {
        // Checks
        require(
            token != kdx && token != wkai && token != bridge,
            "KaidexMaker: Invalid bridge"
        );

        // Effects
        _bridges[token] = bridge;
        emit LogBridgeSet(token, bridge);
    }

    modifier onlyConverter() {
        // Try to make flash-loan exploit harder to do by only allowing externally owned addresses.
        require(msg.sender == converter, "KaidexMaker: must use Converter");
        _;
    }

    function setConverter (address _new) public onlyOwner {
        converter = _new;
    }

    function convert(address token0, address token1) external onlyConverter() {
        _convert(token0, token1);
    }

    function convertMultiple(
        address[] calldata token0,
        address[] calldata token1
    ) external onlyConverter() {
        // TODO: This can be optimized a fair bit, but this is safer and simpler for now
        uint256 len = token0.length;
        require(token0.length == token1.length);
        for (uint256 i = 0; i < len; i++) {
            _convert(token0[i], token1[i]);
        }
    }

    function _convert(address token0, address token1) internal {
        IKAIDexPair pair = IKAIDexPair(factory.getPair(token0, token1));
        require(address(pair) != address(0), "KaidexMaker: Invalid pair");
        
        IERC20(address(pair)).safeTransfer(
            address(pair),
            pair.balanceOf(address(this))
        );

        (uint256 amount0, uint256 amount1) = pair.burn(address(this));
        if (token0 != pair.token0()) {
            (amount0, amount1) = (amount1, amount0);
        }
        uint256 kdxAmount = _convertStep(token0, token1, amount0, amount1);
        emit LogConvert(
            msg.sender,
            token0,
            token1,
            amount0,
            amount1,
            kdxAmount
        );
    }
    
    function _convertStep(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 kdxOut) {
        // Interactions
        require(bar != address(0), "bar is not set");
        if (token0 == token1) {
            uint256 amount = amount0.add(amount1);
            if (token0 == kdx) {
                IERC20(kdx).safeTransfer(bar, amount);
                kdxOut = amount;
            } else if (token0 == wkai) {
                kdxOut = _toKDX(wkai, amount);
            } else {
                address bridge = bridgeFor(token0);
                amount = _swap(token0, bridge, amount, address(this));
                kdxOut = _convertStep(bridge, bridge, amount, 0);
            }
        } else if (token0 == kdx) {
            // eg. KDX - KAI
            IERC20(kdx).safeTransfer(bar, amount0);
            kdxOut = _toKDX(token1, amount1).add(amount0);
        } else if (token1 == kdx) {
            // eg. USDT - KDX
            IERC20(kdx).safeTransfer(bar, amount1);
            kdxOut = _toKDX(token0, amount0).add(amount1);
        } else if (token0 == wkai) {
            // eg. KAI - USDC
            kdxOut = _toKDX(
                wkai,
                _swap(token1, wkai, amount1, address(this)).add(amount0)
            );
        } else if (token1 == wkai) {
            // eg. USDT - KAI
            kdxOut = _toKDX(
                wkai,
                _swap(token0, wkai, amount0, address(this)).add(amount1)
            );
        } else {
            // eg. MIC - USDT
            address bridge0 = bridgeFor(token0);
            address bridge1 = bridgeFor(token1);
            if (bridge0 == token1) {
                // eg. MIC - USDT - and bridgeFor(MIC) = USDT
                kdxOut = _convertStep(
                    bridge0,
                    token1,
                    _swap(token0, bridge0, amount0, address(this)),
                    amount1
                );
            } else if (bridge1 == token0) {
                // eg. WBTC - DSD - and bridgeFor(DSD) = WBTC
                kdxOut = _convertStep(
                    token0,
                    bridge1,
                    amount0,
                    _swap(token1, bridge1, amount1, address(this))
                );
            } else {
                kdxOut = _convertStep(
                    bridge0,
                    bridge1, // eg. USDT - DSD - and bridgeFor(DSD) = WBTC
                    _swap(token0, bridge0, amount0, address(this)),
                    _swap(token1, bridge1, amount1, address(this))
                );
            }
        }
    }

    function _swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        address to
    ) internal returns (uint256 amountOut) {
        IKAIDexPair pair =
            IKAIDexPair(factory.getPair(fromToken, toToken));
        require(address(pair) != address(0), "KaidexMaker: Cannot convert");

        // Interactions
        // X1 - X5: OK
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(997);
        if (fromToken == pair.token0()) {
            amountOut =
                amountInWithFee.mul(reserve1) /
                reserve0.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
            // TODO: Add maximum slippage?
        } else {
            amountOut =
                amountInWithFee.mul(reserve0) /
                reserve1.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
            // TODO: Add maximum slippage?
        }
    }

    function _toKDX(address token, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        require(bar != address(0), "bar is not set");
        amountOut = _swap(token, kdx, amountIn, bar);
    }

    /// @notice Allows owner to withdraw any tokens (including reward tokens) held by this contract
    /// @param token Token to reclaim, use 0x00 for Ethereum
    /// @param amount Amount of tokens to reclaim
    /// @param to Receiver of the tokens, first of his name, rightful heir to the lost tokens,
    /// reightful owner of the extra tokens, and ether, protector of mistaken transfers, mother of token reclaimers,
    /// the Khaleesi of the Great Token Sea, the Unburnt, the Breaker of blockchains.
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address payable to
    ) public onlyOwner {
        if (token == address(0)) {
            to.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }
}
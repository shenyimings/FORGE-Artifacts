// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { ISwapRouter } from "../interfaces/pancakeswap/IPancakeSwapV3Router.sol";
import "../interfaces/IEsRDNTHelper.sol";

/// @title EsRDNTHelperBNBChain
/// @author Magpie Team

contract EsRDNTHelperBNBChain is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IEsRDNTHelper
{
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */

    ISwapRouter public pancakeSwapRouterV3;

    address public RDNT;
    address public esRDNT;
    uint24 public swapFee;

    /* ============ Errors ============ */

    error ZeroAmount();
    error tokenIdNotAssigned();

    /* ============ Constructor ============ */

    constructor() {
        _disableInitializers();
    }

    function __EsRDNTHelperBNBChain_init(
        address _pancakeSwapRouterV3,
        address _rdnt,
        address _esRdnt
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        pancakeSwapRouterV3 = ISwapRouter(_pancakeSwapRouterV3);
        RDNT = _rdnt;
        esRDNT = _esRdnt;
    }

    /* ============ External Functions For Swap ============ */

    function swapRDNTToEsRDNT(
        uint256 amountToSwap,
        uint160 sqrtPriceLimit,
        uint256 amountOutMin
    ) external returns (uint256 amountOut) {
        if (amountToSwap == 0) revert ZeroAmount();
        amountOut = _swap(
            swapFee,
            amountToSwap,
            amountOutMin,
            msg.sender,
            RDNT,
            esRDNT,
            sqrtPriceLimit
        );
        emit swappedRdntToEsRdnt(amountToSwap, amountOut);
    }

    function swapEsRDNTToRDNT(
        uint256 amountToSwap,
        uint160 sqrtPriceLimit,
        uint256 amountOutMin
    ) external returns (uint256 amountOut) {
        if (amountToSwap == 0) revert ZeroAmount();
        (amountOut) = _swap(
            swapFee,
            amountToSwap,
            amountOutMin,
            msg.sender,
            esRDNT,
            RDNT,
            sqrtPriceLimit
        );
        emit swappedEsRdntToRdnt(amountToSwap, amountOut);
    }

    function swapEsRDNTToRDNTFor(
        uint256 amountToSwap,
        uint256 amountOutMin,
        uint160 sqrtPriceLimit,
        address receiver
    ) external returns (uint256 amountOut) {
        if (amountToSwap == 0) revert ZeroAmount();
        (amountOut) = _swap(
            swapFee,
            amountToSwap,
            amountOutMin,
            receiver,
            esRDNT,
            RDNT,
            sqrtPriceLimit
        );
        emit swappedEsRdntToRdnt(amountToSwap, amountOut);
    }

    /* ============ Internal Functions For Swap ============ */

    function _swap(
        uint24 fee,
        uint256 amountToSwap,
        uint256 amountOutMin,
        address recipient,
        address tokenIn,
        address tokenOut,
        uint160 _sqrtPriceLimit
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountToSwap);
        IERC20(tokenIn).safeApprove(address(pancakeSwapRouterV3), 0);
        IERC20(tokenIn).safeApprove(address(pancakeSwapRouterV3), amountToSwap);

        uint256 beforeBal = IERC20(tokenOut).balanceOf(recipient);

        pancakeSwapRouterV3.exactInputSingle(
            ISwapRouter.ExactInputSingleParams(
                tokenIn,
                tokenOut,
                fee,
                recipient,
                amountToSwap,
                amountOutMin,
                _sqrtPriceLimit
            )
        );

        uint256 afterBal = IERC20(tokenOut).balanceOf(recipient);
        amountOut = afterBal - beforeBal;
    }

    /* ============ Admin Functions ============ */

    function config(
        address _pancakeSwapRouterV3,
        address _rdnt,
        address _esRdnt
    ) external onlyOwner {
        pancakeSwapRouterV3 = ISwapRouter(_pancakeSwapRouterV3);
        RDNT = _rdnt;
        esRDNT = _esRdnt;
    }

    function setSwapFee(uint24 _swapFee) external onlyOwner {
        if (_swapFee == 0) revert ZeroAmount();
        swapFee = _swapFee;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

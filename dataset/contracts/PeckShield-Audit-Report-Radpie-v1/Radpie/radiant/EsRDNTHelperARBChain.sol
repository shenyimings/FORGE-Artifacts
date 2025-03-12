// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/IEsRDNTHelper.sol";
import "../interfaces/camelot/IAlgebraPool.sol";

contract EsRDNTHelperARBChain is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IEsRDNTHelper
{
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */
    // Addresses
    address public RDNT;
    address public esRDNT;

    // EsRDNT-RDNT pool
    IAlgebraPool public pool;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /* ============ Errors ============ */

    error ZeroAmount();
    error ZeroAddress();
    error AmountMinFailed();
    error OnlyPoolAllowed();

    /* ============ Constructor ============ */

    constructor() {
        _disableInitializers();
    }

    function __EsRDNTHelperARBChain_init(
        address _rdnt,
        address _esRDNT,
        address _poolAddress
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        if (_rdnt == address(0)) revert ZeroAddress();
        if (_esRDNT == address(0)) revert ZeroAddress();
        if (_poolAddress == address(0)) revert ZeroAddress();
        RDNT = _rdnt;
        esRDNT = _esRDNT;
        pool = IAlgebraPool(_poolAddress);
    }

    /* ============ Modifiers ============ */

    modifier _onlyPool() {
        if (msg.sender != address(pool)) revert OnlyPoolAllowed();
        _;
    }

    /* ============ Functions ============ */
    /// @notice swap RDNT tokens to  esRDNT tokens
    /// @param amountToSwap amount of tokens want to swap
    /// @param amountOutMin minimum amount to recieve
    function swapRDNTToEsRDNT(
        uint256 amountToSwap,
        uint160 sqrtPriceLimit,
        uint256 amountOutMin
    ) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (amountToSwap == 0) revert ZeroAmount();
        IERC20(RDNT).safeTransferFrom(msg.sender, address(this), amountToSwap);
        (amountOut) = _swap(msg.sender, false, int256(amountToSwap));
        if (amountOutMin > amountOut) revert AmountMinFailed();
        emit swappedRdntToEsRdnt(amountToSwap, amountOut);
    }

    /// @notice swap esRDNT tokens to RDNT tokens
    /// @param amountToSwap amount of tokens want to swap
    /// @param amountOutMin minimum amount to recieve
    function swapEsRDNTToRDNT(
        uint256 amountToSwap,
        uint160 sqrtPriceLimit,
        uint256 amountOutMin
    ) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (amountToSwap == 0) revert ZeroAmount();
        IERC20(esRDNT).safeTransferFrom(msg.sender, address(this), amountToSwap);
        (amountOut) = _swap(msg.sender, true, int256(amountToSwap));
        if (amountOutMin > amountOut) revert AmountMinFailed();
        emit swappedEsRdntToRdnt(amountToSwap, amountOut);
    }

    function swapEsRDNTToRDNTFor(
        uint256 amountToSwap,
        uint256 amountOutMin,
        uint160 sqrtPriceLimit,
        address receiver
    ) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (amountToSwap == 0) revert ZeroAmount();
        IERC20(esRDNT).safeTransferFrom(msg.sender, address(this), amountToSwap);
        (amountOut) = _swap(receiver, true, int256(amountToSwap));
        if (amountOutMin > amountOut) revert AmountMinFailed();
        emit swappedEsRdntToRdnt(amountToSwap, amountOut);
    }

    /* ============ Internal Functions For Swap ============ */

    function _swap(
        address receiver,
        bool isEsRDNTtoRDNT,
        int256 amountToSwap
    ) internal returns (uint256) {
        uint256 beforeBal = (isEsRDNTtoRDNT)
            ? IERC20(RDNT).balanceOf(receiver)
            : IERC20(esRDNT).balanceOf(receiver);
        pool.swap(
            receiver,
            isEsRDNTtoRDNT,
            amountToSwap,
            (isEsRDNTtoRDNT == true) ? (MIN_SQRT_RATIO + 1) : MAX_SQRT_RATIO - 1,
            ""
        );
        uint256 afterBal = (isEsRDNTtoRDNT)
            ? IERC20(RDNT).balanceOf(receiver)
            : IERC20(esRDNT).balanceOf(receiver);

        return afterBal - beforeBal;
    }

    function algebraSwapCallback(
        int256 esRDNTAmount,
        int256 rdntAmount,
        bytes calldata data
    ) external _onlyPool {
        if (esRDNTAmount > 0) {
            IERC20(esRDNT).safeTransfer(address(pool), uint256(esRDNTAmount));
        }
        if (rdntAmount > 0) {
            IERC20(RDNT).safeTransfer(address(pool), uint256(rdntAmount));
        }
    }

    /* ============ Admin Functions ============ */

    function config(address _rdnt, address _esRDNT, address _poolAddress) external onlyOwner {
        if (_rdnt == address(0)) revert ZeroAddress();
        if (_esRDNT == address(0)) revert ZeroAddress();
        if (_poolAddress == address(0)) revert ZeroAddress();
        RDNT = _rdnt;
        esRDNT = _esRDNT;
        pool = IAlgebraPool(_poolAddress);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

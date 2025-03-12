pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../Controllable.sol";
import "../uniswap/interfaces/IUniswapV2Router02.sol";

contract LiquidityRecipient is Controllable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event LiquidityProvided(uint256 amunIn, uint256 wethIn, uint256 lpOut);
    event LiquidityRemoved(uint256 lpIn, uint256 wethOut, uint256 amunOut);

    modifier onlyStrategy() {
        require(msg.sender == wethStrategy, "only the weth strategy");
        _;
    }

    modifier onlyStrategyOrGovernance() {
        require(
            msg.sender == wethStrategy || msg.sender == governance(),
            "only not the weth strategy or governance"
        );
        _;
    }

    // Address for WETH
    address public weth;

    // Address for AMUN
    address public amun;

    // The WETH strategy this contract is hooked up to. The strategy cannot be changed.
    address public wethStrategy;

    // The treasury to provide amun, and to receive amun or overdraft weth
    address public treasury;

    // The address of the uniswap router
    address public uniswap;

    // The UNI V2 LP token matching the pool
    address public uniLp;

    // These tokens cannot be claimed by the controller
    mapping(address => bool) public unsalvagableTokens;

    constructor(
        address _storage,
        address _weth,
        address _amun,
        address _treasury,
        address _uniswap,
        address _uniLp,
        address _wethStrategy
    ) public Controllable(_storage) {
        weth = _weth;
        amun = _amun;
        require(_treasury != address(0), "treasury cannot be address(0)");
        treasury = _treasury;
        uniswap = _uniswap;
        require(_uniLp != address(0), "uniLp cannot be address(0)");
        uniLp = _uniLp;
        unsalvagableTokens[_weth] = true;
        unsalvagableTokens[_uniLp] = true;
        wethStrategy = _wethStrategy;
    }

    /**
     * Adds liquidity to Uniswap.
     */
    function addLiquidity() internal {
        uint256 amunBalance = IERC20(amun).balanceOf(address(this));
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        IERC20(amun).safeApprove(uniswap, 0);
        IERC20(amun).safeApprove(uniswap, amunBalance);
        IERC20(weth).safeApprove(uniswap, 0);
        IERC20(weth).safeApprove(uniswap, wethBalance);

        (
            uint256 amountamun,
            uint256 amountWeth,
            uint256 liquidity
        ) = IUniswapV2Router02(uniswap).addLiquidity(
            amun,
            weth,
            amunBalance,
            wethBalance,
            0,
            0,
            address(this),
            block.timestamp
        );

        emit LiquidityProvided(amountamun, amountWeth, liquidity);
    }

    /**
     * Removes liquidity from Uniswap.
     */
    function removeLiquidity() internal {
        uint256 lpBalance = IERC20(uniLp).balanceOf(address(this));
        if (lpBalance > 0) {
            IERC20(uniLp).safeApprove(uniswap, 0);
            IERC20(uniLp).safeApprove(uniswap, lpBalance);
            (uint256 amountamun, uint256 amountWeth) = IUniswapV2Router02(
                uniswap
            )
                .removeLiquidity(
                amun,
                weth,
                lpBalance,
                0,
                0,
                address(this),
                block.timestamp
            );
            emit LiquidityRemoved(lpBalance, amountWeth, amountamun);
        } else {
            emit LiquidityRemoved(0, 0, 0);
        }
    }

    /**
     * Adds liquidity to Uniswap. There is no vault for this cannot be invoked via controller. It has
     * to be restricted for market manipulation reasons, so only governance can call this method.
     */
    function doHardWork() public onlyGovernance {
        addLiquidity();
    }

    /**
     * Borrows the set amount of WETH from the strategy, and will invest all available liquidity
     * to Uniswap. This assumes that an approval from the strategy exists.
     */
    function takeLoan(uint256 amount) public onlyStrategy {
        IERC20(weth).safeTransferFrom(wethStrategy, address(this), amount);
        addLiquidity();
    }

    /**
     * Prepares for settling the loan to the strategy by withdrawing all liquidity from Uniswap,
     * and providing approvals to the strategy (for WETH) and to treasury (for amun). The strategy
     * will make the WETH withdrawal by the pull pattern, and so will the treasury.
     */
    function settleLoan() public onlyStrategyOrGovernance {
        removeLiquidity();
        IERC20(weth).safeApprove(wethStrategy, 0);
        IERC20(weth).safeApprove(wethStrategy, uint256(-1));
        IERC20(amun).safeApprove(treasury, 0);
        IERC20(amun).safeApprove(treasury, uint256(-1));
    }

    /**
     * If Uniswap returns less amun and more WETH, the WETH excess will be present in this strategy.
     * The governance can send this WETH to the treasury by invoking this function through the
     * strategy. The strategy ensures that this function is not called unless the entire WETH loan
     * was settled.
     */
    function wethOverdraft() external onlyStrategy {
        IERC20(weth).safeTransfer(
            treasury,
            IERC20(weth).balanceOf(address(this))
        );
    }

    /**
     * Salvages a token.
     */
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external onlyGovernance {
        // To make sure that governance cannot come in and take away the coins
        require(
            !unsalvagableTokens[token],
            "token is defined as not salvagable"
        );
        IERC20(token).safeTransfer(recipient, amount);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {
    InvalidTargetLtv,
    InvalidSlippageTolerance,
    InvalidFlashLoanCaller,
    VaultNotUnderwater
} from "../../src/errors/scErrors.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IPool} from "lib/aave-v3-core/contracts/interfaces/IPool.sol";
import {IAToken} from "lib/aave-v3-core/contracts/interfaces/IAToken.sol";
import {IPoolDataProvider} from "lib/aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";

import {Constants as C} from "../../src/lib/Constants.sol";
import {IVault} from "../../src/interfaces/balancer/IVault.sol";
import {ISwapRouter} from "../../src/interfaces/uniswap/ISwapRouter.sol";
import {AggregatorV3Interface} from "../../src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IFlashLoanRecipient} from "../../src/interfaces/balancer/IFlashLoanRecipient.sol";
import {sc4626} from "../../src/sc4626.sol";

/**
 * @title Sandclock USDC Vault
 * @notice A vault that allows users to earn interest on their USDC deposits from leveraged WETH staking.
 * @dev This vault uses Sandclock's leveraged WETH staking vault - scWETH.
 */
contract scUSDC is sc4626, IFlashLoanRecipient {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for WETH;
    using FixedPointMathLib for uint256;

    event NewTargetLtvApplied(address indexed admin, uint256 newTargetLtv);
    event SlippageToleranceUpdated(address indexed admin, uint256 newSlippageTolerance);
    event EmergencyExitExecuted(
        address indexed admin, uint256 wethWithdrawn, uint256 debtRepaid, uint256 collateralReleased
    );
    event Rebalanced(
        uint256 targetLtv,
        uint256 initialDebt,
        uint256 finalDebt,
        uint256 initialCollateral,
        uint256 finalCollateral,
        uint256 initialUsdcBalance,
        uint256 finalUsdcBalance
    );

    WETH public immutable weth;

    // delta threshold for rebalancing in percentage
    uint256 constant DEBT_DELTA_THRESHOLD = 0.01e18;

    // main aave contract for interaction with the protocol
    IPool public immutable aavePool;
    // aave protocol data provider
    IPoolDataProvider public immutable aavePoolDataProvider;

    // aave "aEthUSDC" token
    IAToken public immutable aUsdc;
    // aave "variableDebtEthWETH" token
    ERC20 public immutable dWeth;

    // Uniswap V3 router
    ISwapRouter public immutable swapRouter;

    // Chainlink pricefeed (USDC -> WETH)
    AggregatorV3Interface public immutable usdcToEthPriceFeed;

    // Balancer vault for flashloans
    IVault public immutable balancerVault;

    // USDC / WETH target LTV
    uint256 public targetLtv = 0.65e18;
    // max slippage for swapping WETH -> USDC
    uint256 public slippageTolerance = 0.99e18; // 1% default
    uint256 public constant rebalanceMinimum = 10e6; // 10 USDC

    // leveraged (w)eth vault
    ERC4626 public immutable scWETH;

    struct ConstructorParams {
        address admin;
        address keeper;
        ERC4626 scWETH;
        ERC20 usdc;
        WETH weth;
        IPool aavePool;
        IPoolDataProvider aavePoolDataProvider;
        IAToken aaveAUsdc;
        ERC20 aaveVarDWeth;
        ISwapRouter uniswapSwapRouter;
        AggregatorV3Interface chainlinkUsdcToEthPriceFeed;
        IVault balancerVault;
    }

    constructor(ConstructorParams memory _params)
        sc4626(_params.admin, _params.keeper, _params.usdc, "Sandclock USDC Vault", "scUSDC")
    {
        scWETH = _params.scWETH;
        weth = _params.weth;
        aavePool = _params.aavePool;
        aavePoolDataProvider = _params.aavePoolDataProvider;
        aUsdc = _params.aaveAUsdc;
        dWeth = _params.aaveVarDWeth;
        swapRouter = _params.uniswapSwapRouter;
        usdcToEthPriceFeed = _params.chainlinkUsdcToEthPriceFeed;
        balancerVault = _params.balancerVault;

        asset.safeApprove(address(aavePool), type(uint256).max);

        weth.safeApprove(address(aavePool), type(uint256).max);
        weth.safeApprove(address(swapRouter), type(uint256).max);
        weth.safeApprove(address(_params.scWETH), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC API
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the slippage tolerance for swapping WETH to USDC on Uniswap.
     * @param _newSlippageTolerance The new slippage tolerance value.
     */
    function setSlippageTolerance(uint256 _newSlippageTolerance) external onlyAdmin {
        if (_newSlippageTolerance > C.ONE) revert InvalidSlippageTolerance();

        slippageTolerance = _newSlippageTolerance;

        emit SlippageToleranceUpdated(msg.sender, _newSlippageTolerance);
    }

    /**
     * @notice Apply a new target LTV and trigger a rebalance.
     * @param _newTargetLtv The new target LTV value.
     */
    function applyNewTargetLtv(uint256 _newTargetLtv) external {
        onlyKeeper();

        if (_newTargetLtv > getMaxLtv()) revert InvalidTargetLtv();

        targetLtv = _newTargetLtv;

        rebalance();

        emit NewTargetLtvApplied(msg.sender, _newTargetLtv);
    }

    /**
     * @notice Rebalance the vault's positions.
     * @dev Called to increase or decrease the WETH debt to match the target LTV.
     */
    function rebalance() public {
        onlyKeeper();

        uint256 initialBalance = getUsdcBalance();
        uint256 currentBalance = initialBalance;
        uint256 collateral = getCollateral();
        uint256 invested = getInvested();
        uint256 debt = getDebt();
        uint256 profit = _calculateWethProfit(invested, debt);

        // 1. sell profits
        if (profit > invested.mulWadDown(DEBT_DELTA_THRESHOLD)) {
            uint256 withdrawn = _disinvest(profit);
            currentBalance += _swapWethForUsdc(withdrawn);
            invested -= withdrawn;
        }

        uint256 floatRequired =
            _calculateTotalAssets(currentBalance, collateral, invested, debt).mulWadDown(floatPercentage);
        uint256 excessUsdc = currentBalance > floatRequired ? currentBalance - floatRequired : 0;

        // 2. deposit excess usdc as collateral
        if (excessUsdc >= rebalanceMinimum) {
            aavePool.supply(address(asset), excessUsdc, address(this), 0);
            collateral += excessUsdc;
            currentBalance -= excessUsdc;
        }

        // 3. rebalance to target ltv
        uint256 targetDebt = getWethFromUsdc(collateral.mulWadDown(targetLtv));
        uint256 delta = debt > targetDebt ? debt - targetDebt : targetDebt - debt;

        if (delta <= targetDebt.mulWadDown(DEBT_DELTA_THRESHOLD)) return;

        if (debt > targetDebt) {
            _disinvest(delta);
            aavePool.repay(address(weth), delta, C.AAVE_VAR_INTEREST_RATE_MODE, address(this));
        } else {
            aavePool.borrow(address(weth), delta, C.AAVE_VAR_INTEREST_RATE_MODE, 0, address(this));
            scWETH.deposit(delta, address(this));
        }

        emit Rebalanced(
            targetLtv, debt, targetDebt, collateral - excessUsdc, collateral, initialBalance, currentBalance
        );
    }

    /**
     * @notice Emergency exit to release collateral if the vault is underwater.
     */
    function exitAllPositions() external onlyAdmin {
        uint256 debt = getDebt();

        if (getInvested() >= debt) {
            revert VaultNotUnderwater();
        }

        uint256 wethBalance = scWETH.redeem(scWETH.balanceOf(address(this)), address(this), address(this));
        uint256 collateral = getCollateral();

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = debt - wethBalance;

        balancerVault.flashLoan(address(this), tokens, amounts, abi.encode(collateral, debt));

        emit EmergencyExitExecuted(msg.sender, wethBalance, debt, collateral);
    }

    /**
     * @notice Handles the repayment and collateral release logic for flash loans.
     * @param userData Data passed to the callback function.
     */
    function receiveFlashLoan(address[] memory, uint256[] memory amounts, uint256[] memory, bytes memory userData)
        external
    {
        if (msg.sender != address(balancerVault)) {
            revert InvalidFlashLoanCaller();
        }

        uint256 flashLoanAmount = amounts[0];
        (uint256 collateral, uint256 debt) = abi.decode(userData, (uint256, uint256));

        aavePool.repay(address(weth), debt, C.AAVE_VAR_INTEREST_RATE_MODE, address(this));
        aavePool.withdraw(address(asset), collateral, address(this));

        asset.approve(address(swapRouter), type(uint256).max);

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(asset),
            tokenOut: address(weth),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: flashLoanAmount,
            amountInMaximum: type(uint256).max, // ignore slippage
            sqrtPriceLimitX96: 0
        });

        swapRouter.exactOutputSingle(params);

        asset.approve(address(swapRouter), 0);

        weth.safeTransfer(address(balancerVault), flashLoanAmount);
    }

    function totalAssets() public view override returns (uint256) {
        return _calculateTotalAssets(getUsdcBalance(), getCollateral(), getInvested(), getDebt());
    }

    function getUsdcFromWeth(uint256 _wethAmount) public view returns (uint256) {
        (, int256 usdcPriceInWeth,,,) = usdcToEthPriceFeed.latestRoundData();

        return (_wethAmount / C.WETH_USDC_DECIMALS_DIFF).divWadDown(uint256(usdcPriceInWeth));
    }

    function getWethFromUsdc(uint256 _usdcAmount) public view returns (uint256) {
        (, int256 usdcPriceInWeth,,,) = usdcToEthPriceFeed.latestRoundData();

        return (_usdcAmount * C.WETH_USDC_DECIMALS_DIFF).mulWadDown(uint256(usdcPriceInWeth));
    }

    /**
     * @notice Returns the USDC balance of the vault.
     * @return The USDC balance.
     */
    function getUsdcBalance() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /**
     * @notice Returns the total USDC supplied as collateral to Aave.
     * @return The USDC collateral amount.
     */
    function getCollateral() public view returns (uint256) {
        return aUsdc.balanceOf(address(this));
    }

    /**
     * @notice Returns the total WETH borrowed on Aave.
     * @return The borrowed WETH amount.
     */
    function getDebt() public view returns (uint256) {
        return dWeth.balanceOf(address(this));
    }

    /**
     * @notice Returns the amount of WETH invested in the leveraged WETH vault.
     * @return The WETH invested amount.
     */
    function getInvested() public view returns (uint256) {
        return scWETH.convertToAssets(scWETH.balanceOf(address(this)));
    }

    /**
     * @notice Returns the net LTV at which the vault has borrowed until now.
     * @return The current LTV (1e18 = 100%).
     */
    function getLtv() public view returns (uint256) {
        uint256 debt = getDebt();

        if (debt == 0) return 0;

        uint256 debtPriceInUsdc = getUsdcFromWeth(debt);

        // totalDebt / totalSupplied
        return debtPriceInUsdc.divWadUp(getCollateral());
    }

    /**
     * @notice Returns the current max LTV for USDC / WETH loans on Aave.
     * @return The max LTV (1e18 = 100%).
     */
    function getMaxLtv() public view returns (uint256) {
        (, uint256 ltv,,,,,,,,) = aavePoolDataProvider.getReserveConfigurationData(address(asset));

        // ltv is returned as a percentage with 2 decimals (e.g. 80% = 8000) so we need to multiply by 1e14
        return ltv * 1e14;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL API
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256 _assets, uint256) internal override {
        uint256 initialBalance = getUsdcBalance();
        if (initialBalance >= _assets) return;

        uint256 collateral = getCollateral();
        uint256 debt = getDebt();
        uint256 invested = getInvested();
        uint256 total = _calculateTotalAssets(initialBalance, collateral, invested, debt);
        uint256 profit = _calculateWethProfit(invested, debt);
        uint256 floatRequired = total > _assets ? (total - _assets).mulWadUp(floatPercentage) : 0;
        uint256 usdcNeeded = _assets + floatRequired - initialBalance;

        // first try to sell profits to cover withdrawal amount
        if (profit != 0) {
            uint256 withdrawn = _disinvest(profit);
            uint256 usdcReceived = _swapWethForUsdc(withdrawn);

            if (initialBalance + usdcReceived >= _assets) return;

            usdcNeeded -= usdcReceived;
        }

        // if we still need more usdc, we need to repay debt and withdraw collateral
        _repayDebtAndReleaseCollateral(debt, collateral, invested, usdcNeeded);
    }

    function _repayDebtAndReleaseCollateral(uint256 _debt, uint256 _collateral, uint256 _invested, uint256 _usdcNeeded)
        internal
    {
        // handle rounding errors when withdrawing everything
        _usdcNeeded = _usdcNeeded > _collateral ? _collateral : _usdcNeeded;
        // to keep the same ltv, weth debt to repay has to be proportional to collateral withdrawn
        uint256 wethNeeded = _usdcNeeded.mulDivUp(_debt, _collateral);
        wethNeeded = wethNeeded > _invested ? _invested : wethNeeded;

        uint256 withdrawn = _disinvest(wethNeeded);
        aavePool.repay(address(weth), withdrawn, C.AAVE_VAR_INTEREST_RATE_MODE, address(this));
        aavePool.withdraw(address(asset), _usdcNeeded, address(this));
    }

    function _calculateTotalAssets(uint256 _float, uint256 _collateral, uint256 _invested, uint256 _debt)
        internal
        view
        returns (uint256 total)
    {
        total = _float + _collateral;

        uint256 profit = _calculateWethProfit(_invested, _debt);

        if (profit != 0) {
            // account for slippage when selling weth profits
            total += getUsdcFromWeth(profit).mulWadDown(slippageTolerance);
        } else {
            total -= getUsdcFromWeth(_debt - _invested);
        }
    }

    function _calculateWethProfit(uint256 _invested, uint256 _debt) internal pure returns (uint256) {
        return _invested > _debt ? _invested - _debt : 0;
    }

    function _disinvest(uint256 _wethAmount) internal returns (uint256 amountWithdrawn) {
        uint256 shares = scWETH.convertToShares(_wethAmount);

        amountWithdrawn = scWETH.redeem(shares, address(this), address(this));
    }

    function _swapWethForUsdc(uint256 _wethAmount) internal returns (uint256) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(asset),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _wethAmount,
            amountOutMinimum: getUsdcFromWeth(_wethAmount).mulWadDown(slippageTolerance),
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactInputSingle(params);
    }
}

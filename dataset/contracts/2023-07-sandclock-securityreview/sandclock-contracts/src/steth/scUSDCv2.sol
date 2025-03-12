// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
    VaultNotUnderwater,
    NoProfitsToSell,
    FlashLoanAmountZero,
    EndUsdcBalanceTooLow,
    FloatBalanceTooLow
} from "../errors/scErrors.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {EnumerableMap} from "openzeppelin-contracts/utils/structs/EnumerableMap.sol";

import {Constants as C} from "../lib/Constants.sol";
import {BaseV2Vault} from "./BaseV2Vault.sol";
import {AggregatorV3Interface} from "../interfaces/chainlink/AggregatorV3Interface.sol";
import {IAdapter} from "./IAdapter.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {Swapper} from "./Swapper.sol";

/**
 * @title Sandclock USDC Vault version 2
 * @notice A vault that allows users to earn interest on their USDC deposits from leveraged WETH staking.
 * @notice The v2 vault uses multiple lending markets to earn yield on USDC deposits and borrow WETH to stake.
 * @dev This vault uses Sandclock's leveraged WETH staking vault - scWETH.
 */
contract scUSDCv2 is BaseV2Vault {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for WETH;
    using FixedPointMathLib for uint256;
    using Address for address;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    WETH public constant weth = WETH(payable(C.WETH));

    // leveraged (w)eth vault
    ERC4626 public immutable scWETH;

    /**
     * @notice Enum indicating the purpose of a flashloan.
     */
    enum FlashLoanType {
        Reallocate,
        ExitAllPositions
    }

    event EmergencyExitExecuted(
        address indexed admin, uint256 wethWithdrawn, uint256 debtRepaid, uint256 collateralReleased
    );
    event Reallocated();
    event Rebalanced(uint256 totalCollateral, uint256 totalDebt, uint256 floatBalance);
    event ProfitSold(uint256 wethSold, uint256 usdcReceived);
    event Supplied(uint256 adapterId, uint256 amount);
    event Borrowed(uint256 adapterId, uint256 amount);
    event Repaid(uint256 adapterId, uint256 amount);
    event Withdrawn(uint256 adapterId, uint256 amount);
    event Invested(uint256 wethAmount);
    event Disinvested(uint256 wethAmount);

    constructor(address _admin, address _keeper, ERC4626 _scWETH, PriceConverter _priceConverter, Swapper _swapper)
        BaseV2Vault(_admin, _keeper, ERC20(C.USDC), _priceConverter, _swapper, "Sandclock USDC Vault v2", "scUSDCv2")
    {
        _zeroAddressCheck(address(_scWETH));

        scWETH = _scWETH;

        weth.safeApprove(address(scWETH), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC API
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rebalance the vault's positions/loans in multiple lending markets.
     * @dev Called to increase or decrease the WETH debt to maintain the LTV (loan to value) and avoid liquidation.
     * @param _callData The encoded data for the calls to be made to the lending markets.
     */
    function rebalance(bytes[] calldata _callData) external {
        _onlyKeeper();

        _multiCall(_callData);

        // invest any weth remaining after rebalancing
        _invest();

        // enforce float to be above the minimum required
        uint256 float = usdcBalance();
        uint256 floatRequired = totalAssets().mulWadDown(floatPercentage);

        if (float < floatRequired) {
            revert FloatBalanceTooLow(float, floatRequired);
        }

        emit Rebalanced(totalCollateral(), totalDebt(), float);
    }

    /**
     * @notice Reallocate collateral & debt between lending markets, ie move debt and collateral positions from one lending market to another.
     * @dev To move the funds between lending markets, the vault uses flashloans to repay debt and release collateral in one lending market enabling it to be moved to anoter mm.
     * @param _flashLoanAmount The amount of WETH to flashloan from Balancer. Has to be at least equal to amount of WETH debt moved between lending markets.
     * @param _callData The encoded data for the calls to be made to the lending markets.
     */
    function reallocate(uint256 _flashLoanAmount, bytes[] calldata _callData) external {
        _onlyKeeper();

        if (_flashLoanAmount == 0) revert FlashLoanAmountZero();

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _flashLoanAmount;

        _initiateFlashLoan();
        balancerVault.flashLoan(address(this), tokens, amounts, abi.encode(FlashLoanType.Reallocate, _callData));
        _finalizeFlashLoan();

        emit Reallocated();
    }

    /**
     * @notice Sells WETH profits (swaps to USDC).
     * @dev As the vault generates yield by staking WETH, the profits are in WETH.
     * @param _usdcAmountOutMin The minimum amount of USDC to receive.
     */
    function sellProfit(uint256 _usdcAmountOutMin) external {
        _onlyKeeper();

        uint256 profit = _calculateWethProfit(wethInvested(), totalDebt());

        if (profit == 0) revert NoProfitsToSell();

        uint256 withdrawn = _disinvest(profit);
        uint256 usdcReceived = _swapWethForUsdc(withdrawn, _usdcAmountOutMin);

        emit ProfitSold(withdrawn, usdcReceived);
    }

    /**
     * @notice Emergency exit to release collateral if the vault is underwater.
     * @dev In unlikely situation that the vault makes a loss on ETH staked, the total debt would be higher than ETH available to "unstake",
     *  which can lead to withdrawals being blocked. To handle this situation, the vault can close all positions in all lending markets and release all of the assets (realize all losses).
     * @param _endUsdcBalanceMin The minimum USDC balance to end with after all positions are closed.
     */
    function exitAllPositions(uint256 _endUsdcBalanceMin) external {
        _onlyAdmin();

        uint256 debt = totalDebt();

        if (wethInvested() >= debt) revert VaultNotUnderwater();

        uint256 wethBalance = scWETH.redeem(scWETH.balanceOf(address(this)), address(this), address(this));
        uint256 collateral = totalCollateral();

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = debt - wethBalance;

        _initiateFlashLoan();
        balancerVault.flashLoan(address(this), tokens, amounts, abi.encode(FlashLoanType.ExitAllPositions));
        _finalizeFlashLoan();

        if (usdcBalance() < _endUsdcBalanceMin) revert EndUsdcBalanceTooLow();

        emit EmergencyExitExecuted(msg.sender, wethBalance, debt, collateral);
    }

    /**
     * @notice Handles flashloan callbacks.
     * @dev Called by Balancer's vault in 2 situations:
     * 1. When the vault is underwater and the vault needs to exit all positions.
     * 2. When the vault needs to reallocate capital between lending markets.
     * @param _amounts single elment array containing the amount of WETH being flashloaned.
     * @param _data The encoded data that was passed to the flashloan.
     */
    function receiveFlashLoan(address[] calldata, uint256[] calldata _amounts, uint256[] calldata, bytes calldata _data)
        external
    {
        _isFlashLoanInitiated();

        uint256 flashLoanAmount = _amounts[0];
        FlashLoanType flashLoanType = abi.decode(_data, (FlashLoanType));

        if (flashLoanType == FlashLoanType.ExitAllPositions) {
            _exitAllPositionsFlash(flashLoanAmount);
        } else {
            (, bytes[] memory callData) = abi.decode(_data, (FlashLoanType, bytes[]));
            _multiCall(callData);
        }

        weth.safeTransfer(address(balancerVault), flashLoanAmount);
    }

    /**
     * @notice Supply USDC assets to a lending market.
     * @param _adapterId The ID of the lending market adapter.
     * @param _amount The amount of USDC to supply.
     */
    function supply(uint256 _adapterId, uint256 _amount) external {
        _onlyKeeperOrFlashLoan();
        _isSupportedCheck(_adapterId);

        _supply(_adapterId, _amount);
    }

    /**
     * @notice Borrow WETH from a lending market.
     * @param _adapterId The ID of the lending market adapter.
     * @param _amount The amount of WETH to borrow.
     */
    function borrow(uint256 _adapterId, uint256 _amount) external {
        _onlyKeeperOrFlashLoan();
        _isSupportedCheck(_adapterId);

        _borrow(_adapterId, _amount);
    }

    /**
     * @notice Repay WETH to a lending market.
     * @param _adapterId The ID of the lending market adapter.
     * @param _amount The amount of WETH to repay.
     */
    function repay(uint256 _adapterId, uint256 _amount) external {
        _onlyKeeperOrFlashLoan();
        _isSupportedCheck(_adapterId);

        _repay(_adapterId, _amount);
    }

    /**
     * @notice Withdraw USDC assets from a lending market.
     * @param _adapterId The ID of the lending market adapter.
     * @param _amount The amount of USDC to withdraw.
     */
    function withdraw(uint256 _adapterId, uint256 _amount) external {
        _onlyKeeperOrFlashLoan();
        _isSupportedCheck(_adapterId);

        _withdraw(_adapterId, _amount);
    }

    /**
     * @notice Withdraw WETH from the staking vault (scWETH).
     * @param _amount The amount of WETH to withdraw.
     */
    function disinvest(uint256 _amount) external {
        _onlyKeeper();

        _disinvest(_amount);
    }

    /**
     * @notice total claimable assets of the vault in USDC.
     */
    function totalAssets() public view override returns (uint256) {
        return _calculateTotalAssets(usdcBalance(), totalCollateral(), wethInvested(), totalDebt());
    }

    /**
     * @notice Returns the USDC balance of the vault.
     */
    function usdcBalance() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /**
     * @notice Returns the USDC supplied as collateral in a lending market.
     * @param _adapterId The ID of the lending market adapter.
     */
    function getCollateral(uint256 _adapterId) external view returns (uint256) {
        if (!isSupported(_adapterId)) return 0;

        return IAdapter(protocolAdapters.get(_adapterId)).getCollateral(address(this));
    }

    /**
     * @notice Returns the total USDC supplied as collateral in all lending markets.
     */
    function totalCollateral() public view returns (uint256 total) {
        uint256 length = protocolAdapters.length();

        for (uint256 i = 0; i < length; i++) {
            (, address adapter) = protocolAdapters.at(i);
            total += IAdapter(adapter).getCollateral(address(this));
        }
    }

    /**
     * @notice Returns the WETH borrowed from a lending market.
     * @param _adapterId The ID of the lending market adapter.
     */
    function getDebt(uint256 _adapterId) external view returns (uint256) {
        if (!isSupported(_adapterId)) return 0;

        return IAdapter(protocolAdapters.get(_adapterId)).getDebt(address(this));
    }

    /**
     * @notice Returns the total WETH borrowed in all lending markets.
     */
    function totalDebt() public view returns (uint256 total) {
        uint256 length = protocolAdapters.length();

        for (uint256 i = 0; i < length; i++) {
            (, address adapter) = protocolAdapters.at(i);
            total += IAdapter(adapter).getDebt(address(this));
        }
    }

    /**
     * @notice Returns the amount of WETH invested (staked) in the leveraged WETH vault.
     */
    function wethInvested() public view returns (uint256) {
        return scWETH.convertToAssets(scWETH.balanceOf(address(this)));
    }

    /**
     * @notice Returns the amount of profit (in WETH) made by the vault.
     * @dev The profit is calculated as the difference between the current WETH staked and the WETH owed.
     */
    function getProfit() public view returns (uint256) {
        return _calculateWethProfit(wethInvested(), totalDebt());
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL API
    //////////////////////////////////////////////////////////////*/

    function _supply(uint256 _adapterId, uint256 _amount) internal {
        _adapterDelegateCall(_adapterId, abi.encodeWithSelector(IAdapter.supply.selector, _amount));

        emit Supplied(_adapterId, _amount);
    }

    function _borrow(uint256 _adapterId, uint256 _amount) internal {
        _adapterDelegateCall(_adapterId, abi.encodeWithSelector(IAdapter.borrow.selector, _amount));

        emit Borrowed(_adapterId, _amount);
    }

    function _repay(uint256 _adapterId, uint256 _amount) internal {
        uint256 wethBalance = weth.balanceOf(address(this));

        _amount = _amount > wethBalance ? wethBalance : _amount;

        _adapterDelegateCall(_adapterId, abi.encodeWithSelector(IAdapter.repay.selector, _amount));

        emit Repaid(_adapterId, _amount);
    }

    function _withdraw(uint256 _adapterId, uint256 _amount) internal {
        _adapterDelegateCall(_adapterId, abi.encodeWithSelector(IAdapter.withdraw.selector, _amount));

        emit Withdrawn(_adapterId, _amount);
    }

    function _invest() internal {
        uint256 wethBalance = weth.balanceOf(address(this));

        if (wethBalance > 0) {
            scWETH.deposit(wethBalance, address(this));

            emit Invested(wethBalance);
        }
    }

    function _disinvest(uint256 _wethAmount) internal returns (uint256) {
        uint256 shares = scWETH.convertToShares(_wethAmount);

        uint256 amount = scWETH.redeem(shares, address(this), address(this));

        emit Disinvested(amount);

        return amount;
    }

    function _exitAllPositionsFlash(uint256 _flashLoanAmount) internal {
        uint256 length = protocolAdapters.length();

        for (uint256 i = 0; i < length; i++) {
            (uint256 id, address adapter) = protocolAdapters.at(i);
            uint256 debt = IAdapter(adapter).getDebt(address(this));
            uint256 collateral = IAdapter(adapter).getCollateral(address(this));

            if (debt > 0) _repay(id, debt);
            if (collateral > 0) _withdraw(id, collateral);
        }

        _swapUsdcForExactWeth(_flashLoanAmount);
    }

    function beforeWithdraw(uint256 _assets, uint256) internal override {
        // here we need to make sure that the vault has enough assets to cover the withdrawal
        // the idea is to keep the same ltv after the withdrawal as before on every protocol
        uint256 initialBalance = usdcBalance();
        if (initialBalance >= _assets) return;

        uint256 collateral = totalCollateral();
        uint256 debt = totalDebt();
        uint256 invested = wethInvested();
        uint256 total = _calculateTotalAssets(initialBalance, collateral, invested, debt);
        uint256 profit = _calculateWethProfit(invested, debt);
        uint256 floatRequired = total > _assets ? (total - _assets).mulWadUp(floatPercentage) : 0;
        uint256 usdcNeeded = _assets + floatRequired - initialBalance;

        // first try to sell profits to cover withdrawal amount
        if (profit != 0) {
            uint256 withdrawn = _disinvest(profit);
            uint256 usdcAmountOutMin = priceConverter.ethToUsdc(withdrawn).mulWadDown(slippageTolerance);
            uint256 usdcReceived = _swapWethForUsdc(withdrawn, usdcAmountOutMin);

            if (initialBalance + usdcReceived >= _assets) return;

            usdcNeeded -= usdcReceived;
        }

        // if we still need more usdc, we need to repay debt and withdraw collateral
        _repayDebtAndReleaseCollateral(debt, collateral, invested, usdcNeeded);
    }

    function _repayDebtAndReleaseCollateral(
        uint256 _totalDebt,
        uint256 _totalCollateral,
        uint256 _invested,
        uint256 _usdcNeeded
    ) internal {
        // handle rounding errors when withdrawing everything
        _usdcNeeded = _usdcNeeded > _totalCollateral ? _totalCollateral : _usdcNeeded;
        // to keep the same ltv, total debt in weth to be repaid has to be proportional to total usdc collateral we are withdrawing
        uint256 wethNeeded = _usdcNeeded.mulDivUp(_totalDebt, _totalCollateral);
        wethNeeded = wethNeeded > _invested ? _invested : wethNeeded;

        uint256 wethDisinvested = 0;
        if (wethNeeded != 0) wethDisinvested = _disinvest(wethNeeded);

        // repay debt and withdraw collateral from each protocol in proportion to usdc supplied
        uint256 length = protocolAdapters.length();

        for (uint256 i = 0; i < length; i++) {
            (uint256 id, address adapter) = protocolAdapters.at(i);
            uint256 collateral = IAdapter(adapter).getCollateral(address(this));

            if (collateral == 0) continue;

            uint256 debt = IAdapter(adapter).getDebt(address(this));
            uint256 toWithdraw = _usdcNeeded.mulDivUp(collateral, _totalCollateral);

            if (wethDisinvested != 0 && debt != 0) {
                // keep the same ltv when withdrawing usdc supplied from each protocol
                uint256 toRepay = toWithdraw.mulDivUp(debt, collateral);

                if (toRepay > wethDisinvested) {
                    toRepay = wethDisinvested;
                } else {
                    wethDisinvested -= toRepay;
                }

                _repay(id, toRepay);
            }

            _withdraw(id, toWithdraw);
        }
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
            total += priceConverter.ethToUsdc(profit).mulWadDown(slippageTolerance);
        } else {
            total -= priceConverter.ethToUsdc(_debt - _invested);
        }
    }

    function _calculateWethProfit(uint256 _invested, uint256 _debt) internal pure returns (uint256) {
        return _invested > _debt ? _invested - _debt : 0;
    }

    function _swapWethForUsdc(uint256 _wethAmount, uint256 _usdcAmountOutMin) internal returns (uint256) {
        bytes memory result = address(swapper).functionDelegateCall(
            abi.encodeWithSelector(
                Swapper.uniswapSwapExactInput.selector, weth, asset, _wethAmount, _usdcAmountOutMin, 500 /* pool fee*/
            )
        );

        return abi.decode(result, (uint256));
    }

    function _swapUsdcForExactWeth(uint256 _wethAmountOut) internal {
        address(swapper).functionDelegateCall(
            abi.encodeWithSelector(
                Swapper.uniswapSwapExactOutput.selector,
                asset,
                weth,
                _wethAmountOut,
                type(uint256).max, // ignore slippage
                500 // pool fee
            )
        );
    }
}

// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../utils/BlueBerryConst.sol" as Constants;
import "../utils/BlueBerryErrors.sol" as Errors;
import "../utils/EnsureApprove.sol";
import "../utils/ERC1155NaiveReceiver.sol";
import "../interfaces/IBank.sol";
import "../interfaces/IWERC20.sol";

/**
 * @title BasicSpell
 * @author BlueberryProtocol
 * @notice BasicSpell is the abstract contract that other spells utilize
 */
abstract contract BasicSpell is
    ERC1155NaiveReceiver,
    OwnableUpgradeable,
    EnsureApprove
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct Strategy {
        address vault;
        uint256 maxPositionSize;
    }

    /**
     * @param collToken Collateral Token address to deposit (e.g USDC)
     * @param collAmount Amount of user's collateral (e.g USDC)
     * @param borrowToken Address of token to borrow
     * @param borrowAmount Amount to borrow from Bank
     * @param farmingPid Farming Pool ID
     */
    struct OpenPosParam {
        uint256 strategyId;
        address collToken;
        address borrowToken;
        uint256 collAmount;
        uint256 borrowAmount;
        uint256 farmingPid;
    }

    /**
     * @param strategyId Strategy ID
     * @param collToken Isolated collateral token address
     * @param borrowToken Token address of debt
     * @param amountPosRemove Amount of position to withdraw
     * @param amountRepay Amount of debt to repay
     * @param amountShareWithdraw Amount of isolated collaterals to withdraw
     */
    struct ClosePosParam {
        uint256 strategyId;
        address collToken;
        address borrowToken;
        uint256 amountRepay;
        uint256 amountPosRemove;
        uint256 amountShareWithdraw;
        uint256 sellSlippage;
        uint160 sqrtRatioLimit;
    }

    IBank public bank;
    IWERC20 public werc20;
    address public WETH;

    /// @dev strategyId => vault
    Strategy[] public strategies;
    /// @dev strategyId => collateral token => maxLTV
    mapping(uint256 => mapping(address => uint256)) public maxLTV; // base 1e4

    event StrategyAdded(uint256 strategyId, address vault, uint256 maxPosSize);
    event StrategyMaxPosSizeUpdated(uint256 strategyId, uint256 maxPosSize);
    event CollateralsMaxLTVSet(
        uint256 strategyId,
        address[] collaterals,
        uint256[] maxLTVs
    );

    modifier existingStrategy(uint256 strategyId) {
        if (strategyId >= strategies.length)
            revert Errors.STRATEGY_NOT_EXIST(address(this), strategyId);

        _;
    }

    modifier existingCollateral(uint256 strategyId, address col) {
        if (maxLTV[strategyId][col] == 0)
            revert Errors.COLLATERAL_NOT_EXIST(strategyId, col);

        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __BasicSpell_init(
        IBank bank_,
        address werc20_,
        address weth_
    ) internal onlyInitializing {
        if (
            address(bank_) == address(0) ||
            address(werc20_) == address(0) ||
            address(weth_) == address(0)
        ) revert Errors.ZERO_ADDRESS();

        __Ownable_init();

        bank = bank_;
        werc20 = IWERC20(werc20_);
        WETH = weth_;

        IWERC20(werc20_).setApprovalForAll(address(bank_), true);
    }

    /**
     * @notice Add strategy to the spell
     * @param vault Address of vault for given strategy
     * @param maxPosSize, USD price of maximum position size for given strategy, based 1e18
     */
    function addStrategy(address vault, uint256 maxPosSize) external onlyOwner {
        if (vault == address(0)) revert Errors.ZERO_ADDRESS();
        if (maxPosSize == 0) revert Errors.ZERO_AMOUNT();
        strategies.push(Strategy({vault: vault, maxPositionSize: maxPosSize}));
        emit StrategyAdded(strategies.length - 1, vault, maxPosSize);
    }

    /**
     * @notice Set maxPosSize of existing strategy
     * @param strategyId Strategy ID
     * @param maxPosSize New maxPosSize to set
     */
    function setMaxPosSize(
        uint256 strategyId,
        uint256 maxPosSize
    ) external existingStrategy(strategyId) onlyOwner {
        if (maxPosSize == 0) revert Errors.ZERO_AMOUNT();
        strategies[strategyId].maxPositionSize = maxPosSize;
        emit StrategyMaxPosSizeUpdated(strategyId, maxPosSize);
    }

    /**
     * @notice Set maxLTV values of collaterals for given strategy
     * @dev Only owner can set maxLTVs of collaterals
     * @param strategyId Strategy ID
     * @param collaterals Array of collateral token addresses
     * @param maxLTVs Array of maxLTV to set
     */
    function setCollateralsMaxLTVs(
        uint256 strategyId,
        address[] memory collaterals,
        uint256[] memory maxLTVs
    ) external existingStrategy(strategyId) onlyOwner {
        if (collaterals.length != maxLTVs.length || collaterals.length == 0)
            revert Errors.INPUT_ARRAY_MISMATCH();

        for (uint256 i = 0; i < collaterals.length; i++) {
            if (collaterals[i] == address(0)) revert Errors.ZERO_ADDRESS();
            if (maxLTVs[i] == 0) revert Errors.ZERO_AMOUNT();
            maxLTV[strategyId][collaterals[i]] = maxLTVs[i];
        }

        emit CollateralsMaxLTVSet(strategyId, collaterals, maxLTVs);
    }

    /**
     * @notice Validate whether current position is in maxLTV
     * @dev Only check current pos in execution and revert when it exceeds maxLTV
     * @param strategyId Strategy ID to check
     */
    function _validateMaxLTV(uint256 strategyId) internal view {
        uint positionId = bank.POSITION_ID();
        IBank.Position memory pos = bank.getPositionInfo(positionId);
        uint256 debtValue = bank.getDebtValue(positionId);
        uint uValue = bank.getIsolatedCollateralValue(positionId);

        if (
            debtValue >
            (uValue * maxLTV[strategyId][pos.underlyingToken]) /
                Constants.DENOMINATOR
        ) revert Errors.EXCEED_MAX_LTV();
    }

    /**
     * @dev Refund tokens from spell to current bank executor
     * @param token The token to perform the refund action.
     */
    function _doRefund(address token) internal {
        uint256 balance = IERC20Upgradeable(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20Upgradeable(token).safeTransfer(bank.EXECUTOR(), balance);
        }
    }

    /**
     * @dev Cut rewards fee and refund rewards tokens from spell to the current bank executor
     * @param token The token to perform the refund action.
     */
    function _doRefundRewards(address token) internal {
        uint256 rewardsBalance = IERC20Upgradeable(token).balanceOf(
            address(this)
        );
        if (rewardsBalance > 0) {
            _ensureApprove(token, address(bank.feeManager()), rewardsBalance);
            bank.feeManager().doCutRewardsFee(token, rewardsBalance);
            _doRefund(token);
        }
    }

    /**
     * @dev Deposit isolated collaterals to the bank
     * @param token The token address of isolated collateral
     * @param amount The amount to token to lend
     */
    function _doLend(address token, uint256 amount) internal {
        if (amount > 0) {
            bank.lend(token, amount);
        }
    }

    /**
     * @dev Withdraw isolated collaterals from the bank
     * @param token The token address of isolated collateral
     * @param amount The amount of tokens to withdraw
     */
    function _doWithdraw(address token, uint256 amount) internal {
        if (amount > 0) {
            bank.withdrawLend(token, amount);
        }
    }

    /**
     * @notice Internal call to borrow tokens from the bank on behalf of the current executor.
     * @param token The token to borrow from the bank.
     * @param amount The amount to borrow.
     * @return borrowedAmount The amount of borrowed tokens
     */
    function _doBorrow(
        address token,
        uint256 amount
    ) internal returns (uint256 borrowedAmount) {
        if (amount > 0) {
            borrowedAmount = bank.borrow(token, amount);
        }
    }

    /// @dev Internal call to repay tokens to the bank on behalf of the current executor.
    /// @param token The token to repay to the bank.
    /// @param amount The amount to repay.
    function _doRepay(address token, uint256 amount) internal {
        if (amount > 0) {
            _ensureApprove(token, address(bank), amount);
            bank.repay(token, amount);
        }
    }

    /// @dev Internal call to put collateral tokens in the bank.
    /// @param token The token to put in the bank.
    /// @param amount The amount to put in the bank.
    function _doPutCollateral(address token, uint256 amount) internal {
        if (amount > 0) {
            _ensureApprove(token, address(werc20), amount);
            werc20.mint(token, amount);
            bank.putCollateral(
                address(werc20),
                uint256(uint160(token)),
                amount
            );
        }
    }

    /// @dev Internal call to take collateral tokens from the bank.
    /// @param token The token to take back.
    /// @param amount The amount to take back.
    function _doTakeCollateral(address token, uint256 amount) internal {
        if (amount > 0) {
            amount = bank.takeCollateral(amount);
            werc20.burn(token, amount);
        }
    }

    /// @dev Fallback function. Can only receive ETH from WETH contract.
    receive() external payable {
        if (msg.sender != WETH) revert Errors.NOT_FROM_WETH(msg.sender);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";
import {UpdateConfig, UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";

import {SellCreditLimit, SellCreditLimitParams} from "@src/libraries/actions/SellCreditLimit.sol";
import {SellCreditMarket, SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";

import {Claim, ClaimParams} from "@src/libraries/actions/Claim.sol";
import {Deposit, DepositParams} from "@src/libraries/actions/Deposit.sol";

import {BuyCreditMarket, BuyCreditMarketParams} from "@src/libraries/actions/BuyCreditMarket.sol";
import {SetUserConfiguration, SetUserConfigurationParams} from "@src/libraries/actions/SetUserConfiguration.sol";

import {BuyCreditLimit, BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";
import {Liquidate, LiquidateParams} from "@src/libraries/actions/Liquidate.sol";

import {Multicall} from "@src/libraries/Multicall.sol";
import {Compensate, CompensateParams} from "@src/libraries/actions/Compensate.sol";
import {
    LiquidateWithReplacement,
    LiquidateWithReplacementParams
} from "@src/libraries/actions/LiquidateWithReplacement.sol";
import {Repay, RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidate, SelfLiquidateParams} from "@src/libraries/actions/SelfLiquidate.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {State} from "@src/SizeStorage.sol";

import {CapsLibrary} from "@src/libraries/CapsLibrary.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";

import {SizeView} from "@src/SizeView.sol";
import {Events} from "@src/libraries/Events.sol";

import {IMulticall} from "@src/interfaces/IMulticall.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeAdmin} from "@src/interfaces/ISizeAdmin.sol";

bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 constant BORROW_RATE_UPDATER_ROLE = keccak256("BORROW_RATE_UPDATER_ROLE");

/// @title Size
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISize}.
contract Size is ISize, SizeView, Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using Initialize for State;
    using UpdateConfig for State;
    using Deposit for State;
    using Withdraw for State;
    using SellCreditMarket for State;
    using SellCreditLimit for State;
    using BuyCreditMarket for State;
    using BuyCreditLimit for State;
    using Repay for State;
    using Claim for State;
    using Liquidate for State;
    using SelfLiquidate for State;
    using LiquidateWithReplacement for State;
    using Compensate for State;
    using SetUserConfiguration for State;
    using RiskLibrary for State;
    using CapsLibrary for State;
    using Multicall for State;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        InitializeFeeConfigParams calldata f,
        InitializeRiskConfigParams calldata r,
        InitializeOracleParams calldata o,
        InitializeDataParams calldata d
    ) external initializer {
        state.validateInitialize(owner, f, r, o, d);

        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        state.executeInitialize(f, r, o, d);
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(KEEPER_ROLE, owner);
        _grantRole(BORROW_RATE_UPDATER_ROLE, owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @inheritdoc ISizeAdmin
    function updateConfig(UpdateConfigParams calldata params)
        external
        override(ISizeAdmin)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        state.validateUpdateConfig(params);
        state.executeUpdateConfig(params);
    }

    /// @inheritdoc ISizeAdmin
    function setVariablePoolBorrowRate(uint128 borrowRate)
        external
        override(ISizeAdmin)
        onlyRole(BORROW_RATE_UPDATER_ROLE)
    {
        uint128 oldBorrowRate = state.oracle.variablePoolBorrowRate;
        state.oracle.variablePoolBorrowRate = borrowRate;
        state.oracle.variablePoolBorrowRateUpdatedAt = uint64(block.timestamp);
        emit Events.VariablePoolBorrowRateUpdated(oldBorrowRate, borrowRate);
    }

    /// @inheritdoc ISizeAdmin
    function pause() public override(ISizeAdmin) onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc ISizeAdmin
    function unpause() public override(ISizeAdmin) onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata _data)
        public
        payable
        override(IMulticall)
        whenNotPaused
        returns (bytes[] memory results)
    {
        results = state.multicall(_data);
    }

    /// @inheritdoc ISize
    function deposit(DepositParams calldata params) public payable override(ISize) whenNotPaused {
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @inheritdoc ISize
    function withdraw(WithdrawParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateWithdraw(params);
        state.executeWithdraw(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(msg.sender);
    }

    /// @inheritdoc ISize
    function buyCreditLimit(BuyCreditLimitParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateBuyCreditLimit(params);
        state.executeBuyCreditLimit(params);
    }

    /// @inheritdoc ISize
    function sellCreditLimit(SellCreditLimitParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateSellCreditLimit(params);
        state.executeSellCreditLimit(params);
    }

    /// @inheritdoc ISize
    function buyCreditMarket(BuyCreditMarketParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateBuyCreditMarket(params);
        uint256 amount = state.executeBuyCreditMarket(params);
        if (params.creditPositionId == RESERVED_ID) {
            state.validateUserIsNotBelowOpeningLimitBorrowCR(params.borrower);
        }
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @inheritdoc ISize
    function sellCreditMarket(SellCreditMarketParams memory params) external payable override(ISize) whenNotPaused {
        state.validateSellCreditMarket(params);
        uint256 amount = state.executeSellCreditMarket(params);
        if (params.creditPositionId == RESERVED_ID) {
            state.validateUserIsNotBelowOpeningLimitBorrowCR(msg.sender);
        }
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @inheritdoc ISize
    function repay(RepayParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateRepay(params);
        state.executeRepay(params);
    }

    /// @inheritdoc ISize
    function claim(ClaimParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISize
    function liquidate(LiquidateParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
        returns (uint256 liquidatorProfitCollateralToken)
    {
        state.validateLiquidate(params);
        liquidatorProfitCollateralToken = state.executeLiquidate(params);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralToken);
    }

    /// @inheritdoc ISize
    function selfLiquidate(SelfLiquidateParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateSelfLiquidate(params);
        state.executeSelfLiquidate(params);
    }

    /// @inheritdoc ISize
    function liquidateWithReplacement(LiquidateWithReplacementParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
        onlyRole(KEEPER_ROLE)
        returns (uint256 liquidatorProfitCollateralToken, uint256 liquidatorProfitBorrowToken)
    {
        state.validateLiquidateWithReplacement(params);
        uint256 amount;
        (amount, liquidatorProfitCollateralToken, liquidatorProfitBorrowToken) =
            state.executeLiquidateWithReplacement(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(params.borrower);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralToken);
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @inheritdoc ISize
    function compensate(CompensateParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateCompensate(params);
        state.executeCompensate(params);
        state.validateUserIsNotUnderwater(msg.sender);
    }

    /// @inheritdoc ISize
    function setUserConfiguration(SetUserConfigurationParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
    {
        state.validateSetUserConfiguration(params);
        state.executeSetUserConfiguration(params);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/Beneficiary.sol";
import {Governed} from "./Governance.sol";
import {Initializable} from "./libraries/Upgradability.sol";

interface ICore {
    /// @dev Thrown when trying to set fees that don't sum up to one.
    /// @param stabilizationFee The stabilization fee that was tried to set.
    /// @param exchangeFee The stabilization fee that was tried to set.
    /// @param developmentFee The stabilization fee that was tried to set.
    error BaksDAOFeesDontSumUpToOne(uint256 stabilizationFee, uint256 exchangeFee, uint256 developmentFee);

    error BaksDAOZeroAddress();

    event PriceOracleUpdated(address priceOracle, address newPriceOracle);

    event BaksUpdated(address baks, address newBaks);
    event VoiceUpdated(address voice, address newVoice);

    event BankUpdated(address bank, address newBank);
    event DepositaryUpdated(address depositary, address newDepositary);
    event ExchangeFundUpdated(address exchangeFund, address newExchangeFund);
    event DevelopmentFundUpdated(address developmentFund, address newDevelopmentFund);

    event OperatorUpdated(address operator, address newOperator);
    event LiquidatorUpdated(address liquidator, address newLiquidator);

    event InterestUpdated(uint256 interest, uint256 newInterest);
    event MinimumPrincipalAmountUpdated(uint256 minimumPrincipalAmount, uint256 newMinimumPrincipalAmount);
    event StabilityFeeUpdated(uint256 stabilityFee, uint256 newStabilityFee);
    event RebalancingThresholdUpdated(uint256 rebalancingThreshold, uint256 newRebalancingThreshold);
    event PlatformFeesUpdated(
        uint256 stabilizationFee,
        uint256 newStabilizationFee,
        uint256 exchangeFee,
        uint256 newExchangeFee,
        uint256 developmentFee,
        uint256 newDevelopmentFee
    );
    event DepositFeesUpdated(
        uint256 stabilizationFee,
        uint256 newStabilizationFee,
        uint256 exchangeFee,
        uint256 newExchangeFee,
        uint256 developmentFee,
        uint256 newDevelopmentFee
    );
    event MarginCallLoanToValueRatioUpdated(uint256 marginCallLoanToValueRatio, uint256 newMarginCallLoanToValueRatio);
    event LiquidationLoanToValueRatioUpdated(
        uint256 liqudationLoanToValueRatio,
        uint256 newLiquidationLoanToValueRatio
    );

    event MinimumMagisterDepositAmountUpdated(
        uint256 minimumMagisterDepositAmount,
        uint256 newMinimumMagisterDepositAmount
    );
    event WorkFeeUpdated(uint256 workFee, uint256 newWorkFee);
    event EarlyWithdrawalPeriodUpdated(uint256 earlyWithdrawalPeriod, uint256 newEarlyWithdrawalPeriod);
    event EarlyWithdrawalFeeUpdated(uint256 earlyWithdrawalFee, uint256 newEarlyWithdrawalFee);

    event ServicingThresholdUpdated(uint256 servicingThreshold, uint256 newServicingThreshold);
    event MinimumLiquidityUpdated(uint256 minimumLiquidity, uint256 newMinimumLiquidity);

    function wrappedNativeCurrency() external view returns (address);

    function uniswapV2Router() external view returns (address);

    function priceOracle() external view returns (address);

    function baks() external view returns (address);

    function voice() external view returns (address);

    function bank() external view returns (address);

    function depositary() external view returns (address);

    function exchangeFund() external view returns (address);

    function developmentFund() external view returns (address);

    function operator() external view returns (address);

    function liquidator() external view returns (address);

    function interest() external view returns (uint256);

    function minimumPrincipalAmount() external view returns (uint256);

    function stabilityFee() external view returns (uint256);

    function stabilizationFee() external view returns (uint256);

    function exchangeFee() external view returns (uint256);

    function developmentFee() external view returns (uint256);

    function marginCallLoanToValueRatio() external view returns (uint256);

    function liquidationLoanToValueRatio() external view returns (uint256);

    function rebalancingThreshold() external view returns (uint256);

    function minimumMagisterDepositAmount() external view returns (uint256);

    function workFee() external view returns (uint256);

    function earlyWithdrawalPeriod() external view returns (uint256);

    function earlyWithdrawalFee() external view returns (uint256);

    function servicingThreshold() external view returns (uint256);

    function minimumLiquidity() external view returns (uint256);

    function voiceMintingSchedule() external view returns (uint256[] memory);

    function voiceTotalShares() external view returns (uint256);

    function voiceMintingBeneficiaries() external view returns (uint256[] memory);

    function isSuperUser(address account) external view returns (bool);

    function depositStabilizationFee() external view returns (uint256);

    function depositExchangeFee() external view returns (uint256);

    function depositDevelopmentFee() external view returns (uint256);
}

contract Core is Initializable, Governed, ICore {
    uint256 internal constant ONE = 100e16;

    address public override wrappedNativeCurrency;
    address public override uniswapV2Router;

    address public override priceOracle;

    address public override baks;
    address public override voice;

    address public override bank;
    address public override depositary;
    address public override exchangeFund;
    address public override developmentFund;

    // Roles
    address public override operator;
    address public override liquidator;

    // Bank parameters
    uint256 public override interest;
    uint256 public override minimumPrincipalAmount;
    uint256 public override stabilityFee;
    uint256 public override stabilizationFee;
    uint256 public override exchangeFee;
    uint256 public override developmentFee;
    uint256 public override marginCallLoanToValueRatio;
    uint256 public override liquidationLoanToValueRatio;
    uint256 public override rebalancingThreshold;

    // Depositary parameters
    uint256 public override minimumMagisterDepositAmount;
    uint256 public override workFee;
    uint256 public override earlyWithdrawalPeriod;
    uint256 public override earlyWithdrawalFee;

    // Exchange fund parameters
    uint256 public override servicingThreshold;
    uint256 public override minimumLiquidity;

    // Voice
    uint256[] internal _voiceMintingSchedule;
    uint256[] internal _voiceMintingBeneficiaries;
    uint256 public override voiceTotalShares;

    mapping(address => bool) public override isSuperUser;

    uint256 public override depositStabilizationFee;
    uint256 public override depositExchangeFee;
    uint256 public override depositDevelopmentFee;

    function initialize(
        address _wrappedNativeCurrency,
        address _uniswapV2Router,
        address _operator,
        address _liquidator
    ) external initializer {
        setGovernor(msg.sender);

        if (_wrappedNativeCurrency == address(0)) {
            revert BaksDAOZeroAddress();
        }
        wrappedNativeCurrency = _wrappedNativeCurrency;
        if (_uniswapV2Router == address(0)) {
            revert BaksDAOZeroAddress();
        }
        uniswapV2Router = _uniswapV2Router;

        if (_operator == address(0)) {
            revert BaksDAOZeroAddress();
        }
        operator = _operator;
        if (_liquidator == address(0)) {
            revert BaksDAOZeroAddress();
        }
        liquidator = _liquidator;

        interest = 11e16; // 11 %
        minimumPrincipalAmount = 50e18; // 50 BAKS
        stabilityFee = 15e15; // 1,5 %
        stabilizationFee = 85e16; // 85 %
        exchangeFee = 15e16; // 15 %
        developmentFee = 0;
        marginCallLoanToValueRatio = 75e16; // 75 %
        liquidationLoanToValueRatio = 83e16; // 83 %
        rebalancingThreshold = 1e16; // 1 %

        minimumMagisterDepositAmount = 50000e18; // 50000 BAKS
        workFee = 2e16; // 2 %
        earlyWithdrawalPeriod = 72 hours;
        earlyWithdrawalFee = 1e15; // 0,1 %

        servicingThreshold = 1e16; // 1%
        minimumLiquidity = 50000e18; // 50000 BAKS

        depositStabilizationFee = 15e16; // 15 %
        depositExchangeFee = 85e16; // 85 %
        depositDevelopmentFee = 0;

        _voiceMintingSchedule = [
            0x295be96e64066972000000,
            0x0422ca8b0a00a4250000000000000000295be96e64066972000000,
            0x084595161401484a000000000000000052b7d2dcc80cd2e4000000,
            0x108b2a2c28029094000000000000000052b7d2dcc80cd2e4000000,
            0x2116545850052128000000000000000052b7d2dcc80cd2e4000000,
            0x422ca8b0a00a4250000000000000000052b7d2dcc80cd2e4000000,
            0x84595161401484a0000000000000000052b7d2dcc80cd2e4000000,
            0x0108b2a2c280290940000000000000000052b7d2dcc80cd2e4000000,
            0x014adf4b7320334b90000000000000000052b7d2dcc80cd2e4000000,
            0x018d0bf423c03d8de0000000000000000052b7d2dcc80cd2e4000000,
            0x01cf389cd46047d030000000000000000052b7d2dcc80cd2e4000000,
            0x021165458500521280000000000000000052b7d2dcc80cd2e4000000,
            0x025391ee35a05c54d0000000000000000052b7d2dcc80cd2e4000000,
            0x0295be96e6406697200000000000000000a56fa5b99019a5c8000000,
            0x02d7eb3f96e070d9700000000000000000a56fa5b99019a5c8000000,
            0x031a17e847807b1bc00000000000000000a56fa5b99019a5c8000000,
            0x035c4490f820855e100000000000000000a56fa5b99019a5c8000000
        ];

        isSuperUser[msg.sender] = true;
    }

    function setPriceOracle(address newPriceOracle) external onlyGovernor {
        if (newPriceOracle == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit PriceOracleUpdated(priceOracle, newPriceOracle);
        priceOracle = newPriceOracle;
    }

    function setBaks(address newBaks) external onlyGovernor {
        if (newBaks == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit BaksUpdated(baks, newBaks);
        baks = newBaks;
    }

    function setVoice(address newVoice) external onlyGovernor {
        if (newVoice == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit VoiceUpdated(voice, newVoice);
        voice = newVoice;
    }

    function setBank(address newBank) external onlyGovernor {
        if (newBank == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit BankUpdated(bank, newBank);
        bank = newBank;
    }

    function setDepositary(address newDepositary) external onlyGovernor {
        if (newDepositary == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit DepositaryUpdated(depositary, newDepositary);
        depositary = newDepositary;
    }

    function setExchangeFund(address newExchangeFund) external onlyGovernor {
        if (newExchangeFund == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit ExchangeFundUpdated(exchangeFund, newExchangeFund);
        exchangeFund = newExchangeFund;
    }

    function setDevelopmentFund(address newDevelopmentFund) external onlyGovernor {
        if (newDevelopmentFund == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit DevelopmentFundUpdated(developmentFund, newDevelopmentFund);
        developmentFund = newDevelopmentFund;
    }

    function setOperator(address newOperator) external onlyGovernor {
        if (newOperator == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit OperatorUpdated(operator, newOperator);
        operator = newOperator;
    }

    function setLiquidator(address newLiquidator) external onlyGovernor {
        if (newLiquidator == address(0)) {
            revert BaksDAOZeroAddress();
        }
        emit LiquidatorUpdated(liquidator, newLiquidator);
        liquidator = newLiquidator;
    }

    function setInterest(uint256 newInterest) external onlyGovernor {
        emit InterestUpdated(interest, newInterest);
        interest = newInterest;
    }

    function setMinimumPrincipalAmount(uint256 newMinimumPrincipalAmount) external onlyGovernor {
        emit StabilityFeeUpdated(minimumPrincipalAmount, newMinimumPrincipalAmount);
        minimumPrincipalAmount = newMinimumPrincipalAmount;
    }

    function setStabilityFee(uint256 newStabilityFee) external onlyGovernor {
        emit StabilityFeeUpdated(stabilityFee, newStabilityFee);
        stabilityFee = newStabilityFee;
    }

    function setPlatformFees(
        uint256 newStabilizationFee,
        uint256 newExchangeFee,
        uint256 newDevelopmentFee
    ) external onlyGovernor {
        if (newStabilizationFee + newExchangeFee + newDevelopmentFee != ONE) {
            revert BaksDAOFeesDontSumUpToOne(newStabilizationFee, newExchangeFee, newDevelopmentFee);
        }
        emit PlatformFeesUpdated(
            stabilizationFee,
            newStabilizationFee,
            exchangeFee,
            newExchangeFee,
            developmentFee,
            newDevelopmentFee
        );
        stabilizationFee = newStabilizationFee;
        exchangeFee = newExchangeFee;
        developmentFee = newDevelopmentFee;
    }

    function setDepositFees(
        uint256 newDepositStabilizationFee,
        uint256 newDepositExchangeFee,
        uint256 newDepositDevelopmentFee
    ) external onlyGovernor {
        if (newDepositStabilizationFee + newDepositExchangeFee + newDepositDevelopmentFee != ONE) {
            revert BaksDAOFeesDontSumUpToOne(
                newDepositStabilizationFee,
                newDepositExchangeFee,
                newDepositDevelopmentFee
            );
        }
        emit DepositFeesUpdated(
            depositStabilizationFee,
            newDepositStabilizationFee,
            depositExchangeFee,
            newDepositExchangeFee,
            depositDevelopmentFee,
            newDepositDevelopmentFee
        );
        depositStabilizationFee = newDepositStabilizationFee;
        depositExchangeFee = newDepositExchangeFee;
        depositDevelopmentFee = newDepositDevelopmentFee;
    }

    function setMarginCallLoanToValueRatio(uint256 newMarginCallLoanToValueRatio) external onlyGovernor {
        emit MarginCallLoanToValueRatioUpdated(marginCallLoanToValueRatio, newMarginCallLoanToValueRatio);
        marginCallLoanToValueRatio = newMarginCallLoanToValueRatio;
    }

    function setLiquidationLoanToValueRatio(uint256 newLiquidationLoanToValueRatio) external onlyGovernor {
        emit LiquidationLoanToValueRatioUpdated(liquidationLoanToValueRatio, newLiquidationLoanToValueRatio);
        liquidationLoanToValueRatio = newLiquidationLoanToValueRatio;
    }

    function setRebalancingThreshold(uint256 newRebalancingThreshold) external onlyGovernor {
        emit RebalancingThresholdUpdated(rebalancingThreshold, newRebalancingThreshold);
        rebalancingThreshold = newRebalancingThreshold;
    }

    function setMinimumMagisterDepositAmount(uint256 newMinimumMagisterDepositAmount) external onlyGovernor {
        emit MinimumMagisterDepositAmountUpdated(minimumMagisterDepositAmount, newMinimumMagisterDepositAmount);
        minimumMagisterDepositAmount = newMinimumMagisterDepositAmount;
    }

    function setWorkFee(uint256 newWorkFee) external onlyGovernor {
        emit WorkFeeUpdated(workFee, newWorkFee);
        workFee = newWorkFee;
    }

    function setEarlyWithdrawalPeriod(uint256 newEarlyWithdrawalPeriod) external onlyGovernor {
        emit EarlyWithdrawalPeriodUpdated(earlyWithdrawalPeriod, newEarlyWithdrawalPeriod);
        earlyWithdrawalPeriod = newEarlyWithdrawalPeriod;
    }

    function setEarlyWithdrawalFee(uint256 newEarlyWithdrawalFee) external onlyGovernor {
        emit EarlyWithdrawalFeeUpdated(earlyWithdrawalFee, newEarlyWithdrawalFee);
        earlyWithdrawalFee = newEarlyWithdrawalFee;
    }

    function setServicingThreshold(uint256 newServicingThreshold) external onlyGovernor {
        emit ServicingThresholdUpdated(servicingThreshold, newServicingThreshold);
        servicingThreshold = newServicingThreshold;
    }

    function setMinimumLiquidity(uint256 newMinimumLiquidity) external onlyGovernor {
        emit MinimumLiquidityUpdated(minimumLiquidity, newMinimumLiquidity);
        minimumLiquidity = newMinimumLiquidity;
    }

    function setVoiceMintingBeneficiaries(uint256[] calldata beneficiaries) external onlyGovernor {
        delete _voiceMintingBeneficiaries;
        _voiceMintingBeneficiaries = beneficiaries;
        uint256 _voiceTotalShares = 0;
        for (uint256 i = 0; i < _voiceMintingBeneficiaries.length; i++) {
            (, uint256 share) = Beneficiary.split(_voiceMintingBeneficiaries[i]);
            _voiceTotalShares += share;
        }
        voiceTotalShares = _voiceTotalShares;
    }

    function addSuperUser(address account) external onlyGovernor {
        if (account == address(0)) {
            revert BaksDAOZeroAddress();
        }
        isSuperUser[account] = true;
    }

    function removeSuperUser(address account) external onlyGovernor {
        isSuperUser[account] = false;
    }

    function voiceMintingBeneficiaries() external view override returns (uint256[] memory) {
        return _voiceMintingBeneficiaries;
    }

    function voiceMintingSchedule() external view override returns (uint256[] memory) {
        return _voiceMintingSchedule;
    }
}

abstract contract CoreInside {
    ICore public core;

    error BaksDAOOnlyDepositaryAllowed();
    error BaksDAOOnlySuperUserAllowed();

    modifier onlyDepositary() {
        if (msg.sender != address(core.depositary())) {
            revert BaksDAOOnlyDepositaryAllowed();
        }
        _;
    }

    modifier onlySuperUser() {
        if (!core.isSuperUser(msg.sender)) {
            revert BaksDAOOnlySuperUserAllowed();
        }
        _;
    }

    function initializeCoreInside(ICore _core) internal {
        core = _core;
    }
}

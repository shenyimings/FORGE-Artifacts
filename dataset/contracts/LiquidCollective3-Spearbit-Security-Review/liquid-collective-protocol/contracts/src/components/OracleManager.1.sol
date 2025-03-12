//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../interfaces/components/IOracleManager.1.sol";
import "../interfaces/IRedeemManager.1.sol";

import "../libraries/LibUint256.sol";

import "../state/river/LastConsensusLayerReport.sol";
import "../state/river/OracleAddress.sol";
import "../state/river/CLValidatorTotalBalance.sol";
import "../state/river/CLValidatorCount.sol";
import "../state/river/DepositedValidatorCount.sol";
import "../state/river/LastOracleRoundId.sol";

/// @title Oracle Manager (v1)
/// @author Kiln
/// @notice This contract handles the inputs provided by the oracle
/// @notice The Oracle contract is plugged to this contract and is in charge of pushing
/// @notice data whenever a new report has been deemed valid. The report consists in two
/// @notice values: the sum of all balances of all deposited validators and the count of
/// @notice validators that have been activated on the consensus layer.
abstract contract OracleManagerV1 is IOracleManagerV1 {
    uint256 internal constant ONE_YEAR = 365 days;
    /// @notice Size of a deposit in ETH
    uint256 public constant _DEPOSIT_SIZE = 32 ether;

    /// @notice Handler called if the delta between the last and new validator balance sum is positive
    /// @dev Must be overridden
    /// @param _profits The positive increase in the validator balance sum (staking rewards)
    function _onEarnings(uint256 _profits) internal virtual;

    /// @notice Handler called to pull the Execution layer fees from the recipient
    /// @dev Must be overridden
    /// @param _max The maximum amount to pull inside the system
    /// @return The amount pulled inside the system
    function _pullELFees(uint256 _max) internal virtual returns (uint256);

    /// @notice Handler called to pull the coverage funds
    /// @dev Must be overridden
    /// @param _max The maximum amount to pull inside the system
    /// @return The amount pulled inside the system
    function _pullCoverageFunds(uint256 _max) internal virtual returns (uint256);

    /// @notice Handler called to retrieve the system administrator address
    /// @dev Must be overridden
    /// @return The system administrator address
    function _getRiverAdmin() internal view virtual returns (address);

    /// @notice Overridden handler called whenever the total balance of ETH is requested
    /// @return The current total asset balance managed by River
    function _assetBalance() internal view virtual returns (uint256);

    /// @notice Pulls funds from the Withdraw contract, and adds funds to deposit and redeem balances
    /// @param skimmedEthAmount The new amount of skimmed eth to pull
    /// @param exitedEthAmount The new amount of exited eth to pull
    function _pullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount) internal virtual;

    /// @notice Pulls funds from the redeem manager exceeding eth buffer
    /// @param max The maximum amount to pull
    function _pullRedeemManagerExceedingEth(uint256 max) internal virtual returns (uint256);

    /// @notice Use the balance to redeem to report a withdrawal event on the redeem manager
    function _reportWithdrawToRedeemManager() internal virtual;

    /// @notice Change the stored stopped validator counts for all the operators
    /// @param stoppedValidatorCounts The list of stopped validator counts
    function _setReportedStoppedValidatorCounts(uint32[] memory stoppedValidatorCounts) internal virtual;

    /// @notice Requests exits of validators after possibly rebalancing deposit and redeem balances
    /// @param exitingBalance The currently exiting funds, soon to be received on the execution layer
    /// @param depositToRedeemRebalancingAllowed True if rebalancing from deposit to redeem is allowed
    function _requestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 exitingBalance,
        bool depositToRedeemRebalancingAllowed
    ) internal virtual;

    /// @notice Skims the redeem balance and sends remaining funds to the deposit balance
    function _skimExcessBalanceToRedeem() internal virtual;

    /// @notice Commits the deposit balance up to the allowed daily limit
    /// @param period The period between current and last report
    function _commitBalanceToDeposit(uint256 period) internal virtual;

    /// @notice Prevents unauthorized calls
    modifier onlyAdmin_OMV1() {
        if (msg.sender != _getRiverAdmin()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Set the initial oracle address
    /// @param _oracle Address of the oracle
    function initOracleManagerV1(address _oracle) internal {
        OracleAddress.set(_oracle);
        emit SetOracle(_oracle);
    }

    /// @notice Initializes version 1.1 of the oracle manager
    /// @param epochsPerFrame The amounts of epochs in a frame
    /// @param slotsPerEpoch The slots inside an epoch
    /// @param secondsPerSlot The seconds inside a slot
    /// @param genesisTime The genesis timestamp
    /// @param epochsToAssumedFinality The number of epochs before an epoch is considered final on-chain
    /// @param annualAprUpperBound The reporting upper bound
    /// @param relativeLowerBound The reporting lower bound
    function initOracleManagerV1_1(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint64 epochsToAssumedFinality,
        uint256 annualAprUpperBound,
        uint256 relativeLowerBound
    ) internal {
        CLSpec.set(
            CLSpec.CLSpecStruct({
                epochsPerFrame: epochsPerFrame,
                slotsPerEpoch: slotsPerEpoch,
                secondsPerSlot: secondsPerSlot,
                genesisTime: genesisTime,
                epochsToAssumedFinality: epochsToAssumedFinality
            })
        );
        emit SetSpec(epochsPerFrame, slotsPerEpoch, secondsPerSlot, genesisTime, epochsToAssumedFinality);
        ReportBounds.set(
            ReportBounds.ReportBoundsStruct({
                annualAprUpperBound: annualAprUpperBound,
                relativeLowerBound: relativeLowerBound
            })
        );
        emit SetBounds(annualAprUpperBound, relativeLowerBound);

        IOracleManagerV1.StoredConsensusLayerReport memory storedReport;
        storedReport.epoch = uint256(LastOracleRoundId.get());
        storedReport.validatorsBalance = CLValidatorTotalBalance.get();
        storedReport.validatorsSkimmedBalance = 0;
        storedReport.validatorsExitedBalance = 0;
        storedReport.validatorsExitingBalance = 0;
        storedReport.validatorsCount = uint32(CLValidatorCount.get());
        storedReport.bufferRebalancingMode = false;
        storedReport.slashingContainmentMode = false;
        LastConsensusLayerReport.set(storedReport);
    }

    /// @inheritdoc IOracleManagerV1
    function getOracle() external view returns (address) {
        return OracleAddress.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getCLValidatorTotalBalance() external view returns (uint256) {
        return LastConsensusLayerReport.get().validatorsBalance;
    }

    /// @inheritdoc IOracleManagerV1
    function getCLValidatorCount() external view returns (uint256) {
        return LastConsensusLayerReport.get().validatorsCount;
    }

    /// @inheritdoc IOracleManagerV1
    function getExpectedEpochId() external view returns (uint256) {
        CLSpec.CLSpecStruct memory cls = CLSpec.get();
        uint256 currentEpoch = _currentEpoch(cls);
        return LibUint256.max(
            LastConsensusLayerReport.get().epoch + cls.epochsPerFrame,
            currentEpoch - (currentEpoch % cls.epochsPerFrame)
        );
    }

    /// @inheritdoc IOracleManagerV1
    function isValidEpoch(uint256 epoch) external view returns (bool) {
        return _isValidEpoch(CLSpec.get(), epoch);
    }

    /// @inheritdoc IOracleManagerV1
    function getTime() external view returns (uint256) {
        return block.timestamp;
    }

    /// @inheritdoc IOracleManagerV1
    function getLastCompletedEpochId() external view returns (uint256) {
        return LastConsensusLayerReport.get().epoch;
    }

    /// @inheritdoc IOracleManagerV1
    function getCurrentEpochId() external view returns (uint256) {
        return _currentEpoch(CLSpec.get());
    }

    /// @inheritdoc IOracleManagerV1
    function getCLSpec() external view returns (CLSpec.CLSpecStruct memory) {
        return CLSpec.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getCurrentFrame() external view returns (uint256 _startEpochId, uint256 _startTime, uint256 _endTime) {
        CLSpec.CLSpecStruct memory cls = CLSpec.get();
        uint256 currentEpoch = _currentEpoch(cls);
        _startEpochId = currentEpoch - (currentEpoch % cls.epochsPerFrame);
        _startTime = _startEpochId * cls.slotsPerEpoch * cls.secondsPerSlot;
        _endTime = (_startEpochId + cls.epochsPerFrame) * cls.slotsPerEpoch * cls.secondsPerSlot - 1;
    }

    /// @inheritdoc IOracleManagerV1
    function getFrameFirstEpochId(uint256 _epochId) external view returns (uint256) {
        return _epochId - (_epochId % CLSpec.get().epochsPerFrame);
    }

    /// @inheritdoc IOracleManagerV1
    function getReportBounds() external view returns (ReportBounds.ReportBoundsStruct memory) {
        return ReportBounds.get();
    }

    /// @inheritdoc IOracleManagerV1
    function getLastConsensusLayerReport() external view returns (IOracleManagerV1.StoredConsensusLayerReport memory) {
        return LastConsensusLayerReport.get();
    }

    /// @inheritdoc IOracleManagerV1
    function setOracle(address _oracleAddress) external onlyAdmin_OMV1 {
        OracleAddress.set(_oracleAddress);
        emit SetOracle(_oracleAddress);
    }

    /// @inheritdoc IOracleManagerV1
    function setCLSpec(CLSpec.CLSpecStruct calldata newValue) external onlyAdmin_OMV1 {
        CLSpec.set(newValue);
        emit SetSpec(
            newValue.epochsPerFrame,
            newValue.slotsPerEpoch,
            newValue.secondsPerSlot,
            newValue.genesisTime,
            newValue.epochsToAssumedFinality
        );
    }

    /// @inheritdoc IOracleManagerV1
    function setReportBounds(ReportBounds.ReportBoundsStruct calldata newValue) external onlyAdmin_OMV1 {
        ReportBounds.set(newValue);
        emit SetBounds(newValue.annualAprUpperBound, newValue.relativeLowerBound);
    }

    /// @notice Structure holding internal variables used during reporting
    struct ConsensusLayerDataReportingVariables {
        uint256 preReportUnderlyingBalance;
        uint256 postReportUnderlyingBalance;
        uint256 lastReportExitedBalance;
        uint256 lastReportSkimmedBalance;
        uint256 exitedAmountIncrease;
        uint256 skimmedAmountIncrease;
        uint256 timeElapsedSinceLastReport;
        uint256 availableAmountToUpperBound;
        uint256 redeemManagerDemand;
        ConsensusLayerDataReportingTrace trace;
    }

    /// @inheritdoc IOracleManagerV1
    function setConsensusLayerData(IOracleManagerV1.ConsensusLayerReport calldata report) external {
        // only the oracle is allowed to call this endpoint
        if (msg.sender != OracleAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }

        CLSpec.CLSpecStruct memory cls = CLSpec.get();

        // we start by verifying that the reported epoch is valid based on the consensus layer spec
        if (!_isValidEpoch(cls, report.epoch)) {
            revert InvalidEpoch(report.epoch);
        }

        // we ensure that the reported validator count is not decreasing
        if (report.validatorsCount > DepositedValidatorCount.get()) {
            revert InvalidValidatorCountReport(report.validatorsCount, DepositedValidatorCount.get());
        }

        ConsensusLayerDataReportingVariables memory vars;

        {
            IOracleManagerV1.StoredConsensusLayerReport storage lastStoredReport = LastConsensusLayerReport.get();

            vars.lastReportExitedBalance = lastStoredReport.validatorsExitedBalance;

            // we ensure that the reported total exited balance is not decreasing
            if (report.validatorsExitedBalance < vars.lastReportExitedBalance) {
                revert InvalidDecreasingValidatorsExitedBalance(
                    vars.lastReportExitedBalance, report.validatorsExitedBalance
                );
            }

            // we compute the exited amount increase by taking the delta between reports
            vars.exitedAmountIncrease = report.validatorsExitedBalance - vars.lastReportExitedBalance;

            vars.lastReportSkimmedBalance = lastStoredReport.validatorsSkimmedBalance;

            // we ensure that the reported total skimmed balance is not decreasing
            if (report.validatorsSkimmedBalance < vars.lastReportSkimmedBalance) {
                revert InvalidDecreasingValidatorsSkimmedBalance(
                    vars.lastReportSkimmedBalance, report.validatorsSkimmedBalance
                );
            }

            // we compute the new skimmed amount by taking the delta between reports
            vars.skimmedAmountIncrease = report.validatorsSkimmedBalance - vars.lastReportSkimmedBalance;

            vars.timeElapsedSinceLastReport = _timeBetweenEpochs(cls, lastStoredReport.epoch, report.epoch);
        }

        IOracleManagerV1.StoredConsensusLayerReport storage lastReport = LastConsensusLayerReport.get();

        // we retrieve the current total underlying balance before any reporting data is applied to the system
        vars.preReportUnderlyingBalance = _assetBalance();
        uint256 preUnderlyingBalanceIncludingExits =
            lastReport.validatorsBalance + lastReport.validatorsSkimmedBalance + lastReport.validatorsExitedBalance;
        {
            uint256 lastReportValidatorsCount = lastReport.validatorsCount;
            if (lastReportValidatorsCount < report.validatorsCount) {
                preUnderlyingBalanceIncludingExits +=
                    (report.validatorsCount - lastReportValidatorsCount) * _DEPOSIT_SIZE;
            }
        }

        // if we have new exited / skimmed eth available, we pull funds from the consensus layer recipient
        if (vars.exitedAmountIncrease + vars.skimmedAmountIncrease > 0) {
            // this method pulls and updates ethToDeposit / ethToRedeem accordingly
            _pullCLFunds(vars.skimmedAmountIncrease, vars.exitedAmountIncrease);
        }

        {
            // we update the system parameters, this will have an impact on how the total underlying balance is computed
            IOracleManagerV1.StoredConsensusLayerReport memory storedReport;

            storedReport.epoch = report.epoch;
            storedReport.validatorsBalance = report.validatorsBalance;
            storedReport.validatorsSkimmedBalance = report.validatorsSkimmedBalance;
            storedReport.validatorsExitedBalance = report.validatorsExitedBalance;
            storedReport.validatorsExitingBalance = report.validatorsExitingBalance;
            storedReport.validatorsCount = report.validatorsCount;
            storedReport.bufferRebalancingMode = report.bufferRebalancingMode;
            storedReport.slashingContainmentMode = report.slashingContainmentMode;
            LastConsensusLayerReport.set(storedReport);
        }
        _setReportedStoppedValidatorCounts(report.stoppedValidatorCountPerOperator);

        ReportBounds.ReportBoundsStruct memory rb = ReportBounds.get();

        // we compute the maximum allowed increase in balance based on the pre report value
        uint256 maxIncrease = _maxIncrease(rb, vars.preReportUnderlyingBalance, vars.timeElapsedSinceLastReport);

        // we retrieve the new total underlying balance after system parameters are changed
        vars.postReportUnderlyingBalance = _assetBalance();
        uint256 postUnderlyingBalanceIncludingExits =
            report.validatorsBalance + report.validatorsSkimmedBalance + report.validatorsExitedBalance;

        // we can now compute the earned rewards from the consensus layer balances
        // in order to properly account for the balance increase, we compare the sums of current balances, skimmed balance and exited balances
        // we also synthetically increase the current balance by 32 eth per new activated validator, this way we have no discrepency due
        // to currently activating funds that were not yet accounted in the consensus layer balances
        if (postUnderlyingBalanceIncludingExits >= preUnderlyingBalanceIncludingExits) {
            // if this happens, we revert and the reporting process is cancelled
            if (postUnderlyingBalanceIncludingExits > preUnderlyingBalanceIncludingExits + maxIncrease) {
                revert TotalValidatorBalanceIncreaseOutOfBound(
                    preUnderlyingBalanceIncludingExits,
                    postUnderlyingBalanceIncludingExits,
                    vars.timeElapsedSinceLastReport,
                    rb.annualAprUpperBound
                );
            }

            // we update the rewards based on the balance delta
            vars.trace.rewards = postUnderlyingBalanceIncludingExits - preUnderlyingBalanceIncludingExits;

            // we update the available amount to upper bound (the amount of eth we can still pull and stay below the upper reporting bound)
            vars.availableAmountToUpperBound = maxIncrease - vars.trace.rewards;
        } else {
            // otherwise if the balance has decreased, we verify that we are not exceeding the lower reporting bound

            // we compute the maximum allowed decrease in balance
            uint256 maxDecrease = _maxDecrease(rb, vars.preReportUnderlyingBalance);

            // we verify that the bound is not crossed
            if (postUnderlyingBalanceIncludingExits < preUnderlyingBalanceIncludingExits - maxDecrease) {
                revert TotalValidatorBalanceDecreaseOutOfBound(
                    preUnderlyingBalanceIncludingExits,
                    postUnderlyingBalanceIncludingExits,
                    vars.timeElapsedSinceLastReport,
                    rb.relativeLowerBound
                );
            }

            // we update the available amount to upper bound to be equal to the maximum allowed increase plus the negative delta due to the loss
            vars.availableAmountToUpperBound =
                maxIncrease + (preUnderlyingBalanceIncludingExits - postUnderlyingBalanceIncludingExits);
        }

        // if we have available amount to upper bound after the reporting values are applied
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the execution layer fee recipient
            vars.trace.pulledELFees = _pullELFees(vars.availableAmountToUpperBound);
            // we update the rewards
            vars.trace.rewards += vars.trace.pulledELFees;
            // we update the available amount accordingly
            vars.availableAmountToUpperBound -= vars.trace.pulledELFees;
        }

        // if we have available amount to upper bound after the execution layer fees are pulled
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the exceeding eth buffer of the redeem manager
            vars.trace.pulledRedeemManagerExceedingEthBuffer =
                _pullRedeemManagerExceedingEth(vars.availableAmountToUpperBound);
            // we update the available amount accordingly
            vars.availableAmountToUpperBound -= vars.trace.pulledRedeemManagerExceedingEthBuffer;
        }

        // if we have available amount to upper bound after pulling the exceeding eth buffer, we attempt to pull coverage funds
        if (vars.availableAmountToUpperBound > 0) {
            // we pull the funds from the coverage recipient
            vars.trace.pulledCoverageFunds = _pullCoverageFunds(vars.availableAmountToUpperBound);
            // we do not update the rewards as coverage is not considered rewards
            // we do not update the available amount as there are no more pulling actions to perform afterwards
        }

        // if our rewards are not null, we dispatch the fee to the collector
        if (vars.trace.rewards > 0) {
            _onEarnings(vars.trace.rewards);
        }

        // if the slashing containment mode is active, we do not perform exit related action until it is disabled
        if (!report.slashingContainmentMode) {
            // we request exits based on incoming still in the exit process and current eth buffers
            _requestExitsBasedOnRedeemDemandAfterRebalancings(
                report.validatorsExitingBalance, report.bufferRebalancingMode
            );
        }

        // we use the updated balanceToRedeem value to report a withdraw event on the redeem manager
        _reportWithdrawToRedeemManager();

        // if funds are left in the balance to redeem, we move them to the deposit balance
        _skimExcessBalanceToRedeem();

        // we update the committable amount based on daily maximum allowed
        _commitBalanceToDeposit(vars.timeElapsedSinceLastReport);

        // we emit a summary event with all the reporting details
        emit ProcessedConsensusLayerReport(report, vars.trace);
    }

    /// @notice Retrieve the current epoch based on the current timestamp
    /// @param cls The consensus layer spec struct
    /// @return The current epoch
    function _currentEpoch(CLSpec.CLSpecStruct memory cls) internal view returns (uint256) {
        return ((block.timestamp - cls.genesisTime) / cls.secondsPerSlot) / cls.slotsPerEpoch;
    }

    /// @notice Verifies if the given epoch is valid
    /// @param cls The consensus layer spec struct
    /// @param epoch The epoch to verify
    /// @return True if valid
    function _isValidEpoch(CLSpec.CLSpecStruct memory cls, uint256 epoch) internal view returns (bool) {
        return (
            _currentEpoch(cls) >= epoch + cls.epochsToAssumedFinality && epoch >= LastConsensusLayerReport.get().epoch
                && epoch % cls.epochsPerFrame == 0
        );
    }

    /// @notice Retrieves the maximum increase in balance based on current total underlying supply and period since last report
    /// @param rb The report bounds struct
    /// @param _prevTotalEth The total underlying supply during reporting
    /// @param _timeElapsed The time since last report
    function _maxIncrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth, uint256 _timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.annualAprUpperBound * _timeElapsed) / (LibBasisPoints.BASIS_POINTS_MAX * ONE_YEAR);
    }

    /// @notice Retrieves the maximum decrease in balance based on current total underlying supply
    /// @param rb The report bounds struct
    /// @param _prevTotalEth The total underlying supply during reporting
    function _maxDecrease(ReportBounds.ReportBoundsStruct memory rb, uint256 _prevTotalEth)
        internal
        pure
        returns (uint256)
    {
        return (_prevTotalEth * rb.relativeLowerBound) / LibBasisPoints.BASIS_POINTS_MAX;
    }

    /// @notice Retrieve the number of seconds between two epochs
    /// @param cls The consensus layer spec struct
    /// @param epochPast The starting epoch
    /// @param epochNow The current epoch
    function _timeBetweenEpochs(CLSpec.CLSpecStruct memory cls, uint256 epochPast, uint256 epochNow)
        internal
        pure
        returns (uint256)
    {
        return (epochNow - epochPast) * (cls.secondsPerSlot * cls.slotsPerEpoch);
    }
}

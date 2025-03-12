//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IWithdraw.1.sol";
import "./interfaces/IELFeeRecipient.1.sol";
import "./interfaces/ICoverageFund.1.sol";

import "./components/ConsensusLayerDepositManager.1.sol";
import "./components/UserDepositManager.1.sol";
import "./components/SharesManager.1.sol";
import "./components/OracleManager.1.sol";
import "./Initializable.sol";
import "./Administrable.sol";

import "./libraries/LibAllowlistMasks.sol";

import "./state/river/AllowlistAddress.sol";
import "./state/river/RedeemManagerAddress.sol";
import "./state/river/OperatorsRegistryAddress.sol";
import "./state/river/CollectorAddress.sol";
import "./state/river/ELFeeRecipientAddress.sol";
import "./state/river/CoverageFundAddress.sol";
import "./state/river/BalanceToRedeem.sol";
import "./state/river/GlobalFee.sol";
import "./state/river/MetadataURI.sol";
import "./state/river/LastConsensusLayerReport.sol";

/// @title River (v1)
/// @author Kiln
/// @notice This contract merges all the manager contracts and implements all the virtual methods stitching all components together
/// @notice
/// @notice    +---------------------------------------------------------------------+
/// @notice    |                                                                     |
/// @notice    |                           Consensus Layer                           |
/// @notice    |                                                                     |
/// @notice    | +-------------------+  +-------------------+  +-------------------+ |
/// @notice    | |                   |  |                   |  |                   | |
/// @notice    | |  EL Fee Recipient |  |      Oracle       |  |  Deposit Contract | |
/// @notice    | |                   |  |                   |  |                   | |
/// @notice    | +---------|---------+  +---------|---------+  +---------|---------+ |
/// @notice    +---------------------------------------------------------------------+
/// @notice                |         7            |            5         |
/// @notice                +-----------------|    |    |-----------------+
/// @notice                                  |    |6   |
/// @notice                                  |    |    |
/// @notice        +---------+          +----|----|----|----+            +---------+
/// @notice        |         |          |                   |     2      |         |
/// @notice        |Operator |          |       River       --------------  User   |
/// @notice        |         |          |                   |            |         |
/// @notice        +----|----+          +----|---------|----+            +---------+
/// @notice             |                    |         |
/// @notice             |             4      |         |       3
/// @notice             |1     +-------------|         |--------------+
/// @notice             |      |                                      |
/// @notice             |      |                                      |
/// @notice      +------|------|------------+           +-------------|------------+
/// @notice      |                          |           |                          |
/// @notice      |    Operators Registry    |           |         Allowlist        |
/// @notice      |                          |           |                          |
/// @notice      +--------------------------+           +--------------------------+
/// @notice
/// @notice      1. Operators are adding BLS Public Keys of validators running in their
/// @notice         infrastructure.
/// @notice      2. User deposit ETH to the system and get shares minted in exchange
/// @notice      3. Upon deposit, the system verifies if the User is allowed to deposit
/// @notice         by querying the Allowlist
/// @notice      4. When the system has enough funds to deposit validators, keys are pulled
/// @notice         from the Operators Registry
/// @notice      5. The deposit data is computed and the validators are funded via the official
/// @notice         deposit contract
/// @notice      6. Oracles report the total balance of the running validators and the total count
/// @notice         of running validators
/// @notice      7. The running validators propose blocks that reward the EL Fee Recipient. The funds
/// @notice         are pulled back in the system.
/// @notice
contract RiverV1 is
    ConsensusLayerDepositManagerV1,
    UserDepositManagerV1,
    SharesManagerV1,
    OracleManagerV1,
    Initializable,
    Administrable,
    IRiverV1
{
    /// @inheritdoc IRiverV1
    function initRiverV1(
        address _depositContractAddress,
        address _elFeeRecipientAddress,
        bytes32 _withdrawalCredentials,
        address _oracleAddress,
        address _systemAdministratorAddress,
        address _allowlistAddress,
        address _operatorRegistryAddress,
        address _collectorAddress,
        uint256 _globalFee
    ) external init(0) {
        _setAdmin(_systemAdministratorAddress);

        CollectorAddress.set(_collectorAddress);
        emit SetCollector(_collectorAddress);

        GlobalFee.set(_globalFee);
        emit SetGlobalFee(_globalFee);

        ELFeeRecipientAddress.set(_elFeeRecipientAddress);
        emit SetELFeeRecipient(_elFeeRecipientAddress);

        AllowlistAddress.set(_allowlistAddress);
        emit SetAllowlist(_allowlistAddress);

        OperatorsRegistryAddress.set(_operatorRegistryAddress);
        emit SetOperatorsRegistry(_operatorRegistryAddress);

        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );

        OracleManagerV1.initOracleManagerV1(_oracleAddress);
    }

    /// @inheritdoc IRiverV1
    function initRiverV1_1(
        address _redeemManager,
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint64 epochsToAssumedFinality,
        uint256 annualAprUpperBound,
        uint256 relativeLowerBound,
        uint128 maxDailyNetCommittableAmount_,
        uint128 maxDailyRelativeCommittableAmount_
    ) external init(1) {
        RedeemManagerAddress.set(_redeemManager);
        emit SetRedeemManager(_redeemManager);

        DailyCommittableLimits.set(
            DailyCommittableLimits.DailyCommittableLimitsStruct({
                maxDailyNetCommittableAmount: maxDailyNetCommittableAmount_,
                maxDailyRelativeCommittableAmount: maxDailyRelativeCommittableAmount_
            })
        );
        emit SetMaxDailyCommittableAmounts(maxDailyNetCommittableAmount_, maxDailyRelativeCommittableAmount_);

        initOracleManagerV1_1(
            epochsPerFrame,
            slotsPerEpoch,
            secondsPerSlot,
            genesisTime,
            epochsToAssumedFinality,
            annualAprUpperBound,
            relativeLowerBound
        );

        _approve(address(this), _redeemManager, type(uint256).max);
    }

    /// @inheritdoc IRiverV1
    function getGlobalFee() external view returns (uint256) {
        return GlobalFee.get();
    }

    /// @inheritdoc IRiverV1
    function getAllowlist() external view returns (address) {
        return AllowlistAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getCollector() external view returns (address) {
        return CollectorAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getELFeeRecipient() external view returns (address) {
        return ELFeeRecipientAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getCoverageFund() external view returns (address) {
        return CoverageFundAddress.get();
    }

    /// @inheritdoc IRiverV1
    function getMetadataURI() external view returns (string memory) {
        return MetadataURI.get();
    }

    /// @inheritdoc IRiverV1
    function getDailyCommittableLimits()
        external
        view
        returns (DailyCommittableLimits.DailyCommittableLimitsStruct memory)
    {
        return DailyCommittableLimits.get();
    }

    /// @inheritdoc IRiverV1
    function setDailyCommittableLimits(DailyCommittableLimits.DailyCommittableLimitsStruct memory dcl)
        external
        onlyAdmin
    {
        DailyCommittableLimits.set(dcl);
        emit SetMaxDailyCommittableAmounts(dcl.maxDailyNetCommittableAmount, dcl.maxDailyRelativeCommittableAmount);
    }

    /// @inheritdoc IRiverV1
    function getBalanceToRedeem() external view returns (uint256) {
        return BalanceToRedeem.get();
    }

    /// @inheritdoc IRiverV1
    function resolveRedeemRequests(uint32[] calldata redeemRequestIds)
        external
        view
        returns (int64[] memory withdrawalEventIds)
    {
        return IRedeemManagerV1(RedeemManagerAddress.get()).resolveRedeemRequests(redeemRequestIds);
    }

    /// @inheritdoc IRiverV1
    function requestRedeem(uint256 lsETHAmount) external returns (uint32 redeemRequestId) {
        IAllowlistV1(AllowlistAddress.get()).onlyAllowed(msg.sender, LibAllowlistMasks.REDEEM_MASK);
        _transfer(msg.sender, address(this), lsETHAmount);
        return IRedeemManagerV1(RedeemManagerAddress.get()).requestRedeem(lsETHAmount, msg.sender);
    }

    /// @inheritdoc IRiverV1
    function claimRedeemRequests(uint32[] calldata redeemRequestIds, uint32[] calldata withdrawalEventIds)
        external
        returns (uint8[] memory claimStatuses)
    {
        return
            IRedeemManagerV1(RedeemManagerAddress.get()).claimRedeemRequests(redeemRequestIds, withdrawalEventIds, true);
    }

    /// @inheritdoc IRiverV1
    function setGlobalFee(uint256 newFee) external onlyAdmin {
        GlobalFee.set(newFee);
        emit SetGlobalFee(newFee);
    }

    /// @inheritdoc IRiverV1
    function setAllowlist(address _newAllowlist) external onlyAdmin {
        AllowlistAddress.set(_newAllowlist);
        emit SetAllowlist(_newAllowlist);
    }

    /// @inheritdoc IRiverV1
    function setCollector(address _newCollector) external onlyAdmin {
        CollectorAddress.set(_newCollector);
        emit SetCollector(_newCollector);
    }

    /// @inheritdoc IRiverV1
    function setELFeeRecipient(address _newELFeeRecipient) external onlyAdmin {
        ELFeeRecipientAddress.set(_newELFeeRecipient);
        emit SetELFeeRecipient(_newELFeeRecipient);
    }

    /// @inheritdoc IRiverV1
    function setCoverageFund(address _newCoverageFund) external onlyAdmin {
        CoverageFundAddress.set(_newCoverageFund);
        emit SetCoverageFund(_newCoverageFund);
    }

    /// @inheritdoc IRiverV1
    function setMetadataURI(string memory _metadataURI) external onlyAdmin {
        LibSanitize._notEmptyString(_metadataURI);
        MetadataURI.set(_metadataURI);
        emit SetMetadataURI(_metadataURI);
    }

    /// @inheritdoc IRiverV1
    function getOperatorsRegistry() external view returns (address) {
        return OperatorsRegistryAddress.get();
    }

    /// @inheritdoc IRiverV1
    function sendELFees() external payable {
        if (msg.sender != ELFeeRecipientAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @inheritdoc IRiverV1
    function sendCLFunds() external payable {
        if (msg.sender != WithdrawalCredentials.getAddress()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @inheritdoc IRiverV1
    function sendCoverageFunds() external payable {
        if (msg.sender != CoverageFundAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @inheritdoc IRiverV1
    function sendRedeemManagerExceedingFunds() external payable {
        if (msg.sender != RedeemManagerAddress.get()) {
            revert LibErrors.Unauthorized(msg.sender);
        }
    }

    /// @notice Overridden handler to pass the system admin inside components
    /// @return The address of the admin
    function _getRiverAdmin()
        internal
        view
        override(OracleManagerV1, ConsensusLayerDepositManagerV1)
        returns (address)
    {
        return Administrable._getAdmin();
    }

    /// @notice Overridden handler called whenever a token transfer is triggered
    /// @param _from Token sender
    /// @param _to Token receiver
    function _onTransfer(address _from, address _to) internal view override {
        IAllowlistV1 allowlist = IAllowlistV1(AllowlistAddress.get());
        if (allowlist.isDenied(_from)) {
            revert Denied(_from);
        }
        if (allowlist.isDenied(_to)) {
            revert Denied(_to);
        }
    }

    /// @notice Overridden handler called whenever a user deposits ETH to the system. Mints the adequate amount of shares.
    /// @param _depositor User address that made the deposit
    /// @param _amount Amount of ETH deposited
    function _onDeposit(address _depositor, address _recipient, uint256 _amount) internal override {
        uint256 mintedShares = SharesManagerV1._mintShares(_depositor, _amount);
        IAllowlistV1 allowlist = IAllowlistV1(AllowlistAddress.get());
        if (_depositor == _recipient) {
            allowlist.onlyAllowed(_depositor, LibAllowlistMasks.DEPOSIT_MASK); // this call reverts if unauthorized or denied
        } else {
            allowlist.onlyAllowed(_depositor, LibAllowlistMasks.DEPOSIT_MASK); // this call reverts if unauthorized or denied
            if (allowlist.isDenied(_recipient)) {
                revert Denied(_recipient);
            }
            _transfer(_depositor, _recipient, mintedShares);
        }
    }

    /// @notice Overridden handler called whenever a deposit to the consensus layer is made. Should retrieve _requestedAmount or lower keys
    /// @param _requestedAmount Amount of keys required. Contract is expected to send _requestedAmount or lower.
    /// @return publicKeys Array of fundable public keys
    /// @return signatures Array of signatures linked to the public keys
    function _getNextValidators(uint256 _requestedAmount)
        internal
        override
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        return IOperatorsRegistryV1(OperatorsRegistryAddress.get()).pickNextValidatorsToDeposit(_requestedAmount);
    }

    /// @notice Overridden handler to pull funds from the execution layer fee recipient to River and return the delta in the balance
    /// @param _max The maximum amount to pull from the execution layer fee recipient
    /// @return The amount pulled from the execution layer fee recipient
    function _pullELFees(uint256 _max) internal override returns (uint256) {
        address elFeeRecipient = ELFeeRecipientAddress.get();
        uint256 initialBalance = address(this).balance;
        IELFeeRecipientV1(payable(elFeeRecipient)).pullELFees(_max);
        uint256 collectedELFees = address(this).balance - initialBalance;
        if (collectedELFees > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + collectedELFees);
            emit PulledELFees(collectedELFees);
        }
        return collectedELFees;
    }

    /// @notice Overridden handler to pull funds from the coverage fund to River and return the delta in the balance
    /// @param _max The maximum amount to pull from the coverage fund
    /// @return The amount pulled from the coverage fund
    function _pullCoverageFunds(uint256 _max) internal override returns (uint256) {
        address coverageFund = CoverageFundAddress.get();
        if (coverageFund == address(0)) {
            return 0;
        }
        uint256 initialBalance = address(this).balance;
        ICoverageFundV1(payable(coverageFund)).pullCoverageFunds(_max);
        uint256 collectedCoverageFunds = address(this).balance - initialBalance;
        if (collectedCoverageFunds > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + collectedCoverageFunds);
            emit PulledCoverageFunds(collectedCoverageFunds);
        }
        return collectedCoverageFunds;
    }

    /// @notice Overridden handler called whenever the balance of ETH handled by the system increases. Computes the fees paid to the collector
    /// @param _amount Additional ETH received
    function _onEarnings(uint256 _amount) internal override {
        uint256 oldTotalSupply = _totalSupply();
        if (oldTotalSupply == 0) {
            revert ZeroMintedShares();
        }
        uint256 newTotalBalance = _assetBalance();
        uint256 globalFee = GlobalFee.get();
        uint256 numerator = _amount * oldTotalSupply * globalFee;
        uint256 denominator = (newTotalBalance * LibBasisPoints.BASIS_POINTS_MAX) - (_amount * globalFee);
        uint256 sharesToMint = denominator == 0 ? 0 : (numerator / denominator);

        if (sharesToMint > 0) {
            address collector = CollectorAddress.get();
            _mintRawShares(collector, sharesToMint);
            uint256 newTotalSupply = _totalSupply();
            uint256 oldTotalBalance = newTotalBalance - _amount;
            emit RewardsEarned(collector, oldTotalBalance, oldTotalSupply, newTotalBalance, newTotalSupply);
        }
    }

    /// @notice Overridden handler called whenever the total balance of ETH is requested
    /// @return The current total asset balance managed by River
    function _assetBalance() internal view override(SharesManagerV1, OracleManagerV1) returns (uint256) {
        IOracleManagerV1.StoredConsensusLayerReport storage storedReport = LastConsensusLayerReport.get();
        uint256 clValidatorCount = storedReport.validatorsCount;
        uint256 depositedValidatorCount = DepositedValidatorCount.get();
        if (clValidatorCount < depositedValidatorCount) {
            return storedReport.validatorsBalance + BalanceToDeposit.get() + CommittedBalance.get()
                + BalanceToRedeem.get()
                + (depositedValidatorCount - clValidatorCount) * ConsensusLayerDepositManagerV1.DEPOSIT_SIZE;
        } else {
            return
                storedReport.validatorsBalance + BalanceToDeposit.get() + CommittedBalance.get() + BalanceToRedeem.get();
        }
    }

    /// @notice Sets the balance to deposit, but not yet committed
    /// @param newBalanceToDeposit The new balance to deposit value
    function _setBalanceToDeposit(uint256 newBalanceToDeposit) internal override(UserDepositManagerV1) {
        emit SetBalanceToDeposit(BalanceToDeposit.get(), newBalanceToDeposit);
        BalanceToDeposit.set(newBalanceToDeposit);
    }

    /// @notice Sets the balance to redeem, to be used to satisfy redeem requests on the redeem manager
    /// @param newBalanceToRedeem The new balance to redeem value
    function _setBalanceToRedeem(uint256 newBalanceToRedeem) internal {
        emit SetBalanceToRedeem(BalanceToRedeem.get(), newBalanceToRedeem);
        BalanceToRedeem.set(newBalanceToRedeem);
    }

    /// @notice Sets the committed balance, ready to be deposited to the consensus layer
    /// @param newCommittedBalance The new committed balance value
    function _setCommittedBalance(uint256 newCommittedBalance) internal override(ConsensusLayerDepositManagerV1) {
        emit SetBalanceCommittedToDeposit(CommittedBalance.get(), newCommittedBalance);
        CommittedBalance.set(newCommittedBalance);
    }

    /// @notice Pulls funds from the Withdraw contract, and adds funds to deposit and redeem balances
    /// @param skimmedEthAmount The new amount of skimmed eth to pull
    /// @param exitedEthAmount The new amount of exited eth to pull
    function _pullCLFunds(uint256 skimmedEthAmount, uint256 exitedEthAmount) internal override {
        uint256 currentBalance = address(this).balance;
        uint256 totalAmountToPull = skimmedEthAmount + exitedEthAmount;
        IWithdrawV1(WithdrawalCredentials.getAddress()).pullEth(totalAmountToPull);
        uint256 collectedCLFunds = address(this).balance - currentBalance;
        if (collectedCLFunds != skimmedEthAmount + exitedEthAmount) {
            revert InvalidPulledClFundsAmount(skimmedEthAmount + exitedEthAmount, collectedCLFunds);
        }
        if (skimmedEthAmount > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + skimmedEthAmount);
        }
        if (exitedEthAmount > 0) {
            _setBalanceToRedeem(BalanceToRedeem.get() + exitedEthAmount);
        }
    }

    /// @notice Pulls funds from the redeem manager exceeding eth buffer
    /// @param max The maximum amount to pull
    function _pullRedeemManagerExceedingEth(uint256 max) internal override returns (uint256) {
        uint256 currentBalance = address(this).balance;
        IRedeemManagerV1(RedeemManagerAddress.get()).pullExceedingEth(max);
        uint256 collectedExceedingEth = address(this).balance - currentBalance;
        if (collectedExceedingEth > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + collectedExceedingEth);
            emit PulledRedeemManagerExceedingEth(collectedExceedingEth);
        }
        return collectedExceedingEth;
    }

    /// @notice Use the balance to redeem to report a withdrawal event on the redeem manager
    function _reportWithdrawToRedeemManager() internal override {
        IRedeemManagerV1 redeemManager_ = IRedeemManagerV1(RedeemManagerAddress.get());
        uint256 underlyingAssetBalance = _assetBalance();
        uint256 totalSupply = _totalSupply();

        if (underlyingAssetBalance > 0 && totalSupply > 0) {
            // we compute the redeem manager demands in eth and lsEth based on current conversion rate
            uint256 redeemManagerDemand = _balanceOf(RedeemManagerAddress.get());
            uint256 suppliedRedeemManagerDemand = redeemManagerDemand;
            uint256 suppliedRedeemManagerDemandInEth = _balanceFromShares(suppliedRedeemManagerDemand);
            uint256 availableBalanceToRedeem = BalanceToRedeem.get();

            // if demand is higher than available eth, we update demand values to use the available eth
            if (suppliedRedeemManagerDemandInEth > availableBalanceToRedeem) {
                suppliedRedeemManagerDemandInEth = availableBalanceToRedeem;
                suppliedRedeemManagerDemand = _sharesFromBalance(suppliedRedeemManagerDemandInEth);
            }

            emit ReportedRedeemManager(
                redeemManagerDemand, suppliedRedeemManagerDemand, suppliedRedeemManagerDemandInEth
            );

            if (suppliedRedeemManagerDemandInEth > 0) {
                // the available balance to redeem is updated
                _setBalanceToRedeem(availableBalanceToRedeem - suppliedRedeemManagerDemandInEth);

                // perform a report withdraw call to the redeem manager
                redeemManager_.reportWithdraw{value: suppliedRedeemManagerDemandInEth}(suppliedRedeemManagerDemand);

                // we burn the shares of the redeem manager associated with the amount of eth provided
                _burnRawShares(address(RedeemManagerAddress.get()), suppliedRedeemManagerDemand);
            }
        }
    }

    /// @notice Change the stored stopped validator counts for all the operators
    /// @param stoppedValidatorCounts The list of stopped validator counts
    function _setReportedStoppedValidatorCounts(uint32[] memory stoppedValidatorCounts) internal override {
        IOperatorsRegistryV1(OperatorsRegistryAddress.get()).reportStoppedValidatorCounts(stoppedValidatorCounts);
    }

    /// @notice Requests exits of validators after possibly rebalancing deposit and redeem balances
    /// @param exitingBalance The currently exiting funds, soon to be received on the execution layer
    /// @param depositToRedeemRebalancingAllowed True if rebalancing from deposit to redeem is allowed
    function _requestExitsBasedOnRedeemDemandAfterRebalancings(
        uint256 exitingBalance,
        bool depositToRedeemRebalancingAllowed
    ) internal override {
        uint256 totalSupply = _totalSupply();
        if (totalSupply > 0) {
            uint256 availableBalanceToRedeem = BalanceToRedeem.get();
            uint256 availableBalanceToDeposit = BalanceToDeposit.get();
            uint256 redeemManagerDemandInEth = _balanceFromShares(_balanceOf(RedeemManagerAddress.get()));

            // if after all rebalancings, the redeem manager demand is still higher than the balance to redeem and exiting eth, we compute
            // the amount of validators to exit in order to cover the remaining demand
            if (availableBalanceToRedeem + exitingBalance < redeemManagerDemandInEth) {
                // if reblancing is enabled and the redeem manager demand is higher than exiting eth, we add eth for deposit buffer to redeem buffer
                if (depositToRedeemRebalancingAllowed && availableBalanceToDeposit > 0) {
                    uint256 rebalancingAmount = LibUint256.min(
                        availableBalanceToDeposit, redeemManagerDemandInEth - exitingBalance - availableBalanceToRedeem
                    );
                    if (rebalancingAmount > 0) {
                        availableBalanceToRedeem += rebalancingAmount;
                        _setBalanceToRedeem(availableBalanceToRedeem);
                        _setBalanceToDeposit(availableBalanceToDeposit - rebalancingAmount);
                    }
                }

                IOperatorsRegistryV1 or = IOperatorsRegistryV1(OperatorsRegistryAddress.get());

                uint256 totalStoppedValidatorCount = or.getTotalStoppedValidatorCount();
                uint256 totalRequestedExitsCount = or.getTotalRequestedValidatorExitsCount();

                uint256 preExitingBalance = (
                    totalRequestedExitsCount > totalStoppedValidatorCount
                        ? (totalRequestedExitsCount - totalStoppedValidatorCount)
                        : 0
                ) * DEPOSIT_SIZE;

                if (availableBalanceToRedeem + exitingBalance + preExitingBalance < redeemManagerDemandInEth) {
                    uint256 validatorCountToExit = LibUint256.ceil(
                        redeemManagerDemandInEth - (availableBalanceToRedeem + exitingBalance + preExitingBalance),
                        DEPOSIT_SIZE
                    );

                    or.pickNextValidatorsToExit(validatorCountToExit);
                }
            }
        }
    }

    /// @notice Skims the redeem balance and sends remaining funds to the deposit balance
    function _skimExcessBalanceToRedeem() internal override {
        uint256 availableBalanceToRedeem = BalanceToRedeem.get();

        // if the available balance to redeem is not 0, it means that all the redeem requests are fulfilled, we should redirect funds for deposits
        if (availableBalanceToRedeem > 0) {
            _setBalanceToDeposit(BalanceToDeposit.get() + availableBalanceToRedeem);
            _setBalanceToRedeem(0);
        }
    }

    /// @notice Commits the deposit balance up to the allowed daily limit
    /// @param period The period between current and last report
    function _commitBalanceToDeposit(uint256 period) internal override {
        uint256 underlyingAssetBalance = _assetBalance();
        uint256 currentBalanceToDeposit = BalanceToDeposit.get();
        DailyCommittableLimits.DailyCommittableLimitsStruct memory dcl = DailyCommittableLimits.get();

        // we compute the max daily committable amount by taking the asset balance without the balance to deposit into account
        uint256 currentMaxDailyCommittableAmount = LibUint256.max(
            dcl.maxDailyNetCommittableAmount,
            (uint256(dcl.maxDailyRelativeCommittableAmount) * (underlyingAssetBalance - currentBalanceToDeposit))
                / LibBasisPoints.BASIS_POINTS_MAX
        );
        // we adapt the value for the reporting period by using the asset balance as upper bound
        uint256 currentMaxCommittableAmount = LibUint256.min(
            LibUint256.min(underlyingAssetBalance, (currentMaxDailyCommittableAmount * period) / 1 days),
            currentBalanceToDeposit
        );

        if (currentMaxCommittableAmount > 0) {
            _setCommittedBalance(CommittedBalance.get() + currentMaxCommittableAmount);
            _setBalanceToDeposit(currentBalanceToDeposit - currentMaxCommittableAmount);
        }
    }
}

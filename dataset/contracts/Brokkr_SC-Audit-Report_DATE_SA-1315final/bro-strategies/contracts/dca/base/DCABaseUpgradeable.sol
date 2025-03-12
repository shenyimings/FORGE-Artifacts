// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { InvestQueueLib } from "../libraries/InvestQueueLib.sol";
import { DCAHistoryLib } from "../libraries/DCAHistoryLib.sol";
import { IDCAStrategy } from "../interfaces/IDCAStrategy.sol";
import { SwapLib } from "../libraries/SwapLib.sol";
import { PortfolioAccessBaseUpgradeable } from "./PortfolioAccessBaseUpgradeable.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// solhint-disable-next-line max-states-count
abstract contract DCABaseUpgradeable is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    PortfolioAccessBaseUpgradeable,
    IDCAStrategy
{
    using InvestQueueLib for InvestQueueLib.InvestQueue;
    using DCAHistoryLib for DCAHistoryLib.DCAHistory;
    using SwapLib for SwapLib.Router;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    DepositFee public depositFee;

    address public dcaInvestor;

    TokenInfo public depositTokenInfo;
    uint256 private depositTokenScale;

    uint256 public investmentPeriod;
    uint256 public lastInvestmentTimestamp;
    uint256 public minDepositAmount;

    uint16 public positionsLimit;

    address[] public depositToBluechipSwapPath;
    address[] public bluechipToDepositSwapPath;

    BluechipInvestmentState public bluechipInvestmentState;

    InvestQueueLib.InvestQueue private globalInvestQueue;
    DCAHistoryLib.DCAHistory private dcaHistory;
    SwapLib.Router public router;

    TokenInfo public emergencyExitDepositToken;
    uint256 public emergencySellDepositPrice;
    TokenInfo public emergencyExitBluechipToken;
    uint256 public emergencySellBluechipPrice;

    mapping(address => DCADepositor) private depositors;

    uint256[10] private __gap;

    // solhint-disable-next-line
    function __DCABaseUpgradeable_init(DCAStrategyInitArgs calldata args)
        internal
        onlyInitializing
    {
        __PortfolioAccessBaseUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        setBluechipInvestmentState(BluechipInvestmentState.Investing);
        setDepositFee(args.depositFee);
        setDCAInvestor(args.dcaInvestor);
        setDepositTokenInto(args.depositTokenInfo);
        setInvestmentPeriod(args.investmentPeriod);
        setLastInvestmentTimestamp(args.lastInvestmentTimestamp);
        setMinDepositAmount(args.minDepositAmount);
        setPositionsLimit(args.positionsLimit);
        setRouter(args.router);
        setSwapPath(
            args.depositToBluechipSwapPath,
            args.bluechipToDepositSwapPath
        );
    }

    modifier onlyDCAInvestor() {
        require(_msgSender() == dcaInvestor, "Unauthorized");
        _;
    }

    modifier nonEmergencyExited() {
        require(
            bluechipInvestmentState != BluechipInvestmentState.EmergencyExited,
            "Strategy is emergency exited"
        );

        _;
    }

    modifier emergencyWithdrawOnEmergencyExitedStatus(address sender) {
        // if emergency exited then user should receive everything in deposit asset
        if (isEmergencyExited()) {
            _emergencyWithdrawUserDeposit(sender);
            return;
        }

        _;
    }

    receive() external payable {}

    // ----- Base Class Methods -----
    function deposit(uint256 amount, uint8 amountSplit)
        public
        virtual
        nonReentrant
        whenNotPaused
        nonEmergencyExited
    {
        _deposit(_msgSender(), amount, amountSplit);
    }

    function depositFor(
        address sender,
        uint256 amount,
        uint8 amountSplit
    )
        public
        virtual
        onlyPortfolio
        nonReentrant
        whenNotPaused
        nonEmergencyExited
    {
        _deposit(sender, amount, amountSplit);
    }

    function _deposit(
        address sender,
        uint256 amount,
        uint8 amountSplit
    ) private {
        // assert valid amount sent
        if (amount < minDepositAmount) {
            revert TooSmallDeposit();
        }

        // transfer deposit token from portfolio
        depositTokenInfo.token.safeTransferFrom(
            _msgSender(),
            address(this),
            amount
        );

        // compute actual deposit and transfer fee to receiver
        amount = _takeFee(amount);

        DCADepositor storage depositor = depositors[sender];

        // assert positions limit is not reached
        if (depositor.positions.length == positionsLimit) {
            revert PositionsLimitReached();
        }

        // add splitted amounts to the queue
        globalInvestQueue.splitUserInvestmentAmount(amount, amountSplit);

        // if not started position with the same split exists - increase deposit amount
        for (uint256 i = 0; i < depositor.positions.length; i++) {
            // calculate amount of passed investment epochs
            uint256 passedInvestPeriods = (lastInvestmentTimestamp -
                depositor.positions[i].investedAt) / investmentPeriod;

            if (
                passedInvestPeriods == 0 &&
                depositor.positions[i].amountSplit == amountSplit
            ) {
                // not started position with the same amount split exists
                // just add invested amount here
                depositor.positions[i].depositAmount += amount;

                emit Deposit(sender, amount, amountSplit);
                return;
            }
        }

        // otherwise create new position
        depositor.positions.push(
            Position(
                amount,
                amountSplit,
                lastInvestmentTimestamp,
                dcaHistory.currentHistoricalIndex()
            )
        );

        emit Deposit(sender, amount, amountSplit);
    }

    function invest()
        public
        virtual
        onlyDCAInvestor
        nonReentrant
        whenNotPaused
        nonEmergencyExited
    {
        // declare total amount for event data
        uint256 totalDepositSpent;
        uint256 totalBluechipReceived;

        // assert triggered at valid period
        uint256 passedInvestPeriods = _getPassedInvestPeriods();
        if (passedInvestPeriods == 0) {
            revert NothingToInvest();
        }

        // iterate over passed invest periods
        for (uint256 i = 0; i < passedInvestPeriods; i++) {
            uint256 depositedAmount = globalInvestQueue
                .getCurrentInvestmentAmountAndMoveNext();

            // nobody invested in the queue, just skip this period
            if (depositedAmount == 0) {
                continue;
            }

            // swap deposit amount into invest token
            uint256 receivedBluechip = _swapIntoBluechipAsset(depositedAmount);

            if (bluechipInvestmentState == BluechipInvestmentState.Investing) {
                // invest exchanged amount
                // since protocol might mint less or more tokens refresh amount
                receivedBluechip = _invest(receivedBluechip);
            }

            // store information about spent asset and received asset
            dcaHistory.addHistoricalGauge(depositedAmount, receivedBluechip);

            // compute totals for event
            totalDepositSpent += depositedAmount;
            totalBluechipReceived += receivedBluechip;
        }

        if (bluechipInvestmentState == BluechipInvestmentState.Investing) {
            // claim rewards
            uint256 claimedBluechipRewards = _claimRewards();

            // if something was claimed invest rewards and increase current gauge
            if (claimedBluechipRewards > 0) {
                claimedBluechipRewards = _invest(claimedBluechipRewards);
                dcaHistory.increaseHistoricalGaugeAt(
                    claimedBluechipRewards,
                    dcaHistory.currentHistoricalIndex() - 1
                );

                // increase total amount for event
                totalBluechipReceived += claimedBluechipRewards;
            }
        }

        // update last invest timestamp
        lastInvestmentTimestamp += passedInvestPeriods * investmentPeriod;

        emit Invest(
            totalDepositSpent,
            totalBluechipReceived,
            lastInvestmentTimestamp,
            dcaHistory.currentHistoricalIndex()
        );
    }

    function withdrawAll(bool convertBluechipIntoDepositAsset)
        public
        virtual
        nonReentrant
        whenNotPaused
        emergencyWithdrawOnEmergencyExitedStatus(_msgSender())
    {
        _withdrawAll(_msgSender(), convertBluechipIntoDepositAsset);
    }

    function withdrawAllFor(
        address sender,
        bool convertBluechipIntoDepositAsset
    )
        public
        virtual
        onlyPortfolio
        nonReentrant
        whenNotPaused
        emergencyWithdrawOnEmergencyExitedStatus(sender)
    {
        _withdrawAll(sender, convertBluechipIntoDepositAsset);
    }

    function _withdrawAll(address sender, bool convertBluechipIntoDepositAsset)
        private
    {
        // define total not invested yet amount by user
        // and total bought bluechip asset amount
        uint256 notInvestedYet;
        uint256 investedIntoBluechip;

        DCADepositor storage depositor = depositors[sender];
        for (uint256 i = 0; i < depositor.positions.length; i++) {
            (
                uint256 positionBluechipInvestment,
                uint256 positionNotInvestedYet
            ) = _computePositionWithdrawAll(depositor.positions[i]);

            // increase users total amount
            investedIntoBluechip += positionBluechipInvestment;
            notInvestedYet += positionNotInvestedYet;
        }

        // since depositor withdraws everything
        // we can remove his data completely
        delete depositors[sender];

        // withdraw user deposit
        _withdrawDepositorInvestment(
            sender,
            notInvestedYet,
            investedIntoBluechip,
            convertBluechipIntoDepositAsset
        );
    }

    function withdrawAll(
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    )
        public
        virtual
        nonReentrant
        whenNotPaused
        emergencyWithdrawOnEmergencyExitedStatus(_msgSender())
    {
        _withdrawAll(
            _msgSender(),
            positionIndex,
            convertBluechipIntoDepositAsset
        );
    }

    function withdrawAllFor(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    )
        public
        virtual
        onlyPortfolio
        nonReentrant
        whenNotPaused
        emergencyWithdrawOnEmergencyExitedStatus(sender)
    {
        _withdrawAll(sender, positionIndex, convertBluechipIntoDepositAsset);
    }

    function _withdrawAll(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) private {
        DCADepositor storage depositor = depositors[sender];

        (
            uint256 positionBluechipInvestment,
            uint256 positionNotInvestedYet
        ) = _computePositionWithdrawAll(depositor.positions[positionIndex]);

        // remove position from user data
        depositor.positions[positionIndex] = depositor.positions[
            depositor.positions.length - 1
        ];
        depositor.positions.pop();

        // withdraw user deposit
        _withdrawDepositorInvestment(
            sender,
            positionNotInvestedYet,
            positionBluechipInvestment,
            convertBluechipIntoDepositAsset
        );
    }

    function _computePositionWithdrawAll(Position memory position)
        private
        returns (uint256 investedIntoBluechip, uint256 notInvestedYet)
    {
        // calculate amount of passed investment epochs
        uint256 passedInvestPeriods = (lastInvestmentTimestamp -
            position.investedAt) / investmentPeriod;

        // in case everything was already invested
        // just set amount of epochs to be equal to amount split
        if (passedInvestPeriods > position.amountSplit) {
            passedInvestPeriods = position.amountSplit;
        }

        // compute per period investment - depositAmount / split
        uint256 perPeriodInvestment = position.depositAmount /
            position.amountSplit;

        uint8 futureInvestmentsToRemove = position.amountSplit -
            uint8(passedInvestPeriods);

        // remove not invested yet amount from invest queue
        if (futureInvestmentsToRemove > 0) {
            globalInvestQueue.removeUserInvestment(
                perPeriodInvestment,
                futureInvestmentsToRemove
            );
        }

        // if investment period already started then we should calculate
        // both not invested deposit asset and owned bluechip asset
        if (passedInvestPeriods > 0) {
            (
                uint256 bluechipInvestment,
                uint256 depositAssetInvestment
            ) = _removeUserInvestmentFromHistory(
                    position,
                    passedInvestPeriods,
                    perPeriodInvestment
                );

            investedIntoBluechip += bluechipInvestment;
            notInvestedYet += position.depositAmount - depositAssetInvestment;
        } else {
            // otherwise investment not started yet
            // so we remove whole deposit token amount
            notInvestedYet += position.depositAmount;
        }
    }

    function withdrawBluechip(bool convertBluechipIntoDepositAsset)
        public
        virtual
        nonReentrant
        whenNotPaused
        emergencyWithdrawOnEmergencyExitedStatus(_msgSender())
    {
        _withdrawBluechip(_msgSender(), convertBluechipIntoDepositAsset);
    }

    function withdrawBluechipFor(
        address sender,
        bool convertBluechipIntoDepositAsset
    )
        public
        virtual
        onlyPortfolio
        nonReentrant
        whenNotPaused
        emergencyWithdrawOnEmergencyExitedStatus(sender)
    {
        _withdrawBluechip(sender, convertBluechipIntoDepositAsset);
    }

    function _withdrawBluechip(
        address sender,
        bool convertBluechipIntoDepositAsset
    ) private {
        DCADepositor storage depositor = depositors[sender];

        uint256 investedIntoBluechip;
        uint256 i;

        // since we might remove position we use while loop to iterate over all positions
        while (i < depositor.positions.length) {
            (
                uint256 positionInvestedIntoBluechip,
                uint256 positionNotInvestedYet,
                uint8 newPositionSplit
            ) = _computePositionWithdrawBluechip(depositor.positions[i]);

            // investment not started yet, skip
            if (positionInvestedIntoBluechip == 0) {
                i++;
                continue;
            }

            investedIntoBluechip += positionInvestedIntoBluechip;
            _updateOrRemovePosition(
                depositor,
                i,
                positionNotInvestedYet,
                newPositionSplit
            );

            i++;
        }

        if (investedIntoBluechip == 0) {
            revert NothingToWithdraw();
        }

        // withdraw bluechip asset and transfer to depositor
        _withdrawDepositorInvestment(
            sender,
            0,
            investedIntoBluechip,
            convertBluechipIntoDepositAsset
        );
    }

    function withdrawBluechip(
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    )
        public
        virtual
        nonReentrant
        whenNotPaused
        emergencyWithdrawOnEmergencyExitedStatus(_msgSender())
    {
        _withdrawBluechip(
            _msgSender(),
            positionIndex,
            convertBluechipIntoDepositAsset
        );
    }

    function withdrawBluechipFor(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    )
        public
        virtual
        onlyPortfolio
        nonReentrant
        whenNotPaused
        emergencyWithdrawOnEmergencyExitedStatus(sender)
    {
        _withdrawBluechip(
            sender,
            positionIndex,
            convertBluechipIntoDepositAsset
        );
    }

    function _withdrawBluechip(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) private {
        DCADepositor storage depositor = depositors[sender];

        (
            uint256 positionInvestedIntoBluechip,
            uint256 positionNotInvestedYet,
            uint8 newPositionSplit
        ) = _computePositionWithdrawBluechip(
                depositor.positions[positionIndex]
            );

        if (positionInvestedIntoBluechip == 0) {
            revert NothingToWithdraw();
        }

        _updateOrRemovePosition(
            depositor,
            positionIndex,
            positionNotInvestedYet,
            newPositionSplit
        );

        // withdraw bluechip asset and transfer to depositor
        _withdrawDepositorInvestment(
            sender,
            0,
            positionInvestedIntoBluechip,
            convertBluechipIntoDepositAsset
        );
    }

    function _computePositionWithdrawBluechip(Position memory position)
        private
        returns (
            uint256 investedIntoBluechip,
            uint256 notInvestedYet,
            uint8 newPositionSplit
        )
    {
        // calculate amount of passed investment epochs
        uint256 passedInvestPeriods = (lastInvestmentTimestamp -
            position.investedAt) / investmentPeriod;

        // in case everything was already invested
        // just set amount of epochs to be equal to amount split
        if (passedInvestPeriods > position.amountSplit) {
            passedInvestPeriods = position.amountSplit;
        }

        if (passedInvestPeriods != 0) {
            // compute per period investment - depositAmount / split
            uint256 perPeriodInvestment = position.depositAmount /
                position.amountSplit;

            (
                uint256 bluechipInvestment,
                uint256 depositAssetInvestment
            ) = _removeUserInvestmentFromHistory(
                    position,
                    passedInvestPeriods,
                    perPeriodInvestment
                );

            newPositionSplit =
                position.amountSplit -
                uint8(passedInvestPeriods);

            // remove not invested yet amount from invest queue
            globalInvestQueue.removeUserInvestment(
                perPeriodInvestment,
                newPositionSplit
            );

            investedIntoBluechip = bluechipInvestment;
            notInvestedYet = position.depositAmount - depositAssetInvestment;
        }
    }

    function withdrawBluechipFromPool() external onlyOwner {
        require(
            bluechipInvestmentState == BluechipInvestmentState.Investing,
            "Invalid investment state"
        );

        uint256 bluechipBalance = _totalBluechipInvested();
        uint256 actualReceived = _withdrawInvestedBluechip(bluechipBalance);
        _spreadDiffAfterReinvestment(bluechipBalance, actualReceived);

        setBluechipInvestmentState(BluechipInvestmentState.Withdrawn);

        emit StatusChanged(
            BluechipInvestmentState.Investing,
            BluechipInvestmentState.Withdrawn
        );
    }

    function reInvestBluechipIntoPool() external onlyOwner {
        require(
            bluechipInvestmentState == BluechipInvestmentState.Withdrawn,
            "Invalid investment state"
        );

        uint256 bluechipBalance = _totalBluechipInvested();
        uint256 actualReceived = _invest(bluechipBalance);
        _spreadDiffAfterReinvestment(bluechipBalance, actualReceived);

        setBluechipInvestmentState(BluechipInvestmentState.Investing);

        emit StatusChanged(
            BluechipInvestmentState.Withdrawn,
            BluechipInvestmentState.Investing
        );
    }

    function _spreadDiffAfterReinvestment(
        uint256 bluechipBalance,
        uint256 actualReceived
    ) private {
        if (actualReceived > bluechipBalance) {
            // in case we received more increase current gauge
            dcaHistory.increaseHistoricalGaugeAt(
                actualReceived - bluechipBalance,
                dcaHistory.currentHistoricalIndex() - 1
            );
        } else if (actualReceived < bluechipBalance) {
            // in case we received less we should take loss from gauges
            // so that users will be able to withdraw exactly owned amounts
            _deductLossFromGauges(bluechipBalance - actualReceived);
        }
    }

    function _deductLossFromGauges(uint256 diff) private {
        // start iterating over gauges
        for (uint256 i = dcaHistory.currentHistoricalIndex() - 1; i >= 0; i--) {
            (, uint256 gaugeBluechipBalancee) = dcaHistory
                .historicalGaugeByIndex(i);

            // if gauge balance is higher then diff simply remove diff from it
            if (gaugeBluechipBalancee >= diff) {
                dcaHistory.decreaseHistoricalGaugeByIndex(i, 0, diff);
                return;
            } else {
                // otherwise deduct as much as possible and go to the next one
                diff -= gaugeBluechipBalancee;
                dcaHistory.decreaseHistoricalGaugeByIndex(
                    i,
                    0,
                    gaugeBluechipBalancee
                );
            }
        }
    }

    function emergencyWithdrawFunds(
        TokenInfo calldata emergencyExitDepositToken_,
        address[] calldata depositSwapPath,
        TokenInfo calldata emergencyExitBluechipToken_,
        address[] calldata bluechipSwapPath
    ) external onlyOwner nonEmergencyExited {
        // if status Investing we should first withdraw bluechip from pool
        uint256 currentBluechipBalance;
        if (bluechipInvestmentState == BluechipInvestmentState.Investing) {
            currentBluechipBalance = _withdrawInvestedBluechip(
                _totalBluechipInvested()
            );
        }

        // set status to withdrawn to refetch actual bluechip balance
        setBluechipInvestmentState(BluechipInvestmentState.Withdrawn);
        currentBluechipBalance = _totalBluechipInvested();

        // store emergency exit token info
        emergencyExitDepositToken = emergencyExitDepositToken_;
        emergencyExitBluechipToken = emergencyExitBluechipToken_;

        // if deposit token != emergency exit token then swap it
        if (depositTokenInfo.token != emergencyExitDepositToken.token) {
            // swap deposit into emergency exit token
            uint256 currentDepositTokenBalance = depositTokenInfo
                .token
                .balanceOf(address(this));
            uint256 receivedEmergencyExitDepositAsset = router
                .swapTokensForTokens(
                    currentDepositTokenBalance,
                    depositSwapPath,
                    new uint256[](1) // todo: proper bin size needs to be passed
                );

            // store token price for future conversions
            emergencySellDepositPrice =
                (_scaleAmount(
                    receivedEmergencyExitDepositAsset,
                    emergencyExitDepositToken.decimals,
                    depositTokenInfo.decimals
                ) * depositTokenScale) /
                currentDepositTokenBalance;
        }

        // if bluechip token != emergency exit token then swap it
        if (_bluechipAddress() != address(emergencyExitBluechipToken.token)) {
            // swap bluechip into emergency exit token
            uint256 receivedEmergencyExitBluechipAsset = router
                .swapTokensForTokens(
                    currentBluechipBalance,
                    bluechipSwapPath,
                    new uint256[](1) // todo: proper bin size needs to be passed
                );

            // store token price for future conversions
            emergencySellBluechipPrice =
                (_scaleAmount(
                    receivedEmergencyExitBluechipAsset,
                    emergencyExitBluechipToken.decimals,
                    _bluechipDecimals()
                ) * _bluechipTokenScale()) /
                currentBluechipBalance;
        }

        // set proper strategy state
        setBluechipInvestmentState(BluechipInvestmentState.EmergencyExited);

        emit StatusChanged(
            BluechipInvestmentState.Investing,
            BluechipInvestmentState.EmergencyExited
        );
    }

    function _emergencyWithdrawUserDeposit(address sender) private {
        uint256 notInvestedYet;
        uint256 investedIntoBluechip;

        DCADepositor storage depositor = depositors[sender];
        for (uint256 i = 0; i < depositor.positions.length; i++) {
            (
                uint256 positionBluechipInvestment,
                uint256 positionNotInvestedYet
            ) = _computePositionWithdrawAll(depositor.positions[i]);

            investedIntoBluechip += positionBluechipInvestment;
            notInvestedYet += positionNotInvestedYet;
        }

        // since depositor withdraws everything
        // we can remove his data completely
        delete depositors[sender];

        // if deposit token != emergency exit token compute share
        if (depositTokenInfo.token != emergencyExitDepositToken.token) {
            uint256 convertedDepositShare = (notInvestedYet *
                emergencySellDepositPrice) / depositTokenScale;

            uint256 payout = _scaleAmount(
                convertedDepositShare,
                depositTokenInfo.decimals,
                emergencyExitDepositToken.decimals
            );

            if (payout != 0) {
                emergencyExitDepositToken.token.safeTransfer(sender, payout);
            }
        } else {
            // otherwise send deposit token
            if (notInvestedYet != 0) {
                depositTokenInfo.token.safeTransfer(sender, notInvestedYet);
            }
        }

        // if bluechip != emergency exit token compute share
        if (_bluechipAddress() != address(emergencyExitBluechipToken.token)) {
            uint256 convertedBluechipShare = (investedIntoBluechip *
                emergencySellBluechipPrice) / _bluechipTokenScale();

            uint256 payout = _scaleAmount(
                convertedBluechipShare,
                _bluechipDecimals(),
                emergencyExitBluechipToken.decimals
            );

            if (payout != 0) {
                emergencyExitBluechipToken.token.safeTransfer(sender, payout);
            }
        } else {
            // otherwise send bluechip token
            if (investedIntoBluechip != 0) {
                _transferBluechip(sender, investedIntoBluechip);
            }
        }
    }

    // ----- Base Class Setters -----
    function setBluechipInvestmentState(BluechipInvestmentState newState)
        public
        onlyOwner
    {
        bluechipInvestmentState = newState;
    }

    function setDepositFee(DepositFee memory newDepositFee) public onlyOwner {
        require(
            newDepositFee.feeReceiver != address(0),
            "Invalid fee receiver"
        );
        require(newDepositFee.fee <= 10000, "Invalid fee percentage");
        depositFee = newDepositFee;
    }

    function setDCAInvestor(address newDcaInvestor) public onlyOwner {
        require(newDcaInvestor != address(0), "Invalid DCA investor");
        dcaInvestor = newDcaInvestor;
    }

    function setDepositTokenInto(TokenInfo memory newDepositTokenInfo) private {
        require(
            address(newDepositTokenInfo.token) != address(0),
            "Invalid deposit token address"
        );
        depositTokenInfo = newDepositTokenInfo;
        depositTokenScale = 10**depositTokenInfo.decimals;
    }

    function setInvestmentPeriod(uint256 newInvestmentPeriod) public onlyOwner {
        require(newInvestmentPeriod > 0, "Invalid investment period");
        investmentPeriod = newInvestmentPeriod;
    }

    function setLastInvestmentTimestamp(uint256 newLastInvestmentTimestamp)
        private
    {
        require(
            // solhint-disable-next-line not-rely-on-time
            newLastInvestmentTimestamp >= block.timestamp,
            "Invalid last invest ts"
        );
        lastInvestmentTimestamp = newLastInvestmentTimestamp;
    }

    function setMinDepositAmount(uint256 newMinDepositAmount) public onlyOwner {
        require(newMinDepositAmount > 0, "Invalid min deposit amount");
        minDepositAmount = newMinDepositAmount;
    }

    function setPositionsLimit(uint16 newPositionsLimit) public onlyOwner {
        require(newPositionsLimit > 0, "Invalid positions limit");
        positionsLimit = newPositionsLimit;
    }

    function setRouter(SwapLib.Router memory newRouter) public onlyOwner {
        require(newRouter.router != address(0), "Invalid router");
        router = newRouter;
    }

    function setSwapPath(
        address[] memory depositToBluechip,
        address[] memory bluechipToDeposit
    ) public onlyOwner {
        require(
            depositToBluechip[0] ==
                bluechipToDeposit[bluechipToDeposit.length - 1] &&
                depositToBluechip[depositToBluechip.length - 1] ==
                bluechipToDeposit[0],
            "Invalid swap path"
        );

        depositToBluechipSwapPath = depositToBluechip;
        bluechipToDepositSwapPath = bluechipToDeposit;
    }

    // ----- Pausable -----
    function pause() external onlyOwner {
        super._pause();
    }

    function unpause() external onlyOwner {
        super._unpause();
    }

    // ----- Query Methods -----
    function canInvest() public view virtual returns (bool) {
        return _getPassedInvestPeriods() > 0 && !isEmergencyExited();
    }

    function depositorInfo(address depositor)
        public
        view
        virtual
        returns (DCADepositor memory)
    {
        return depositors[depositor];
    }

    function equityValuation()
        public
        view
        virtual
        returns (DCAEquityValuation[] memory)
    {
        DCAEquityValuation[] memory valuation = new DCAEquityValuation[](1);
        if (isEmergencyExited()) {
            valuation[0].totalDepositToken = emergencyExitDepositToken
                .token
                .balanceOf(address(this));
            valuation[0].totalBluechipToken = emergencyExitBluechipToken
                .token
                .balanceOf(address(this));
            valuation[0].bluechipToken = address(
                emergencyExitBluechipToken.token
            );

            return valuation;
        }

        valuation[0].totalDepositToken = depositTokenInfo.token.balanceOf(
            address(this)
        );
        valuation[0].totalBluechipToken = _totalBluechipInvested();
        valuation[0].bluechipToken = _bluechipAddress();

        return valuation;
    }

    function getInvestAmountAt(uint8 index) external view returns (uint256) {
        return globalInvestQueue.investAmounts[index];
    }

    function currentInvestQueueIndex() external view returns (uint8) {
        return globalInvestQueue.current;
    }

    function getHistoricalGaugeAt(uint256 index)
        external
        view
        returns (uint256, uint256)
    {
        return dcaHistory.historicalGaugeByIndex(index);
    }

    function currentDCAHistoryIndex() external view returns (uint256) {
        return dcaHistory.currentHistoricalIndex();
    }

    function isEmergencyExited() public view virtual returns (bool) {
        return
            bluechipInvestmentState == BluechipInvestmentState.EmergencyExited;
    }

    function depositToken() public view returns (IERC20Upgradeable) {
        return depositTokenInfo.token;
    }

    // ----- Private Base Class Helper Functions -----
    function _takeFee(uint256 amount) private returns (uint256 actualDeposit) {
        // if fee is set to 0 then skip it
        if (depositFee.fee == 0) {
            return amount;
        }

        // actual deposit = amount * (100% - fee%)
        actualDeposit = (amount * (10000 - depositFee.fee)) / 10000;

        uint256 feeAmount = amount - actualDeposit;
        if (feeAmount != 0) {
            depositTokenInfo.token.safeTransfer(
                depositFee.feeReceiver,
                feeAmount
            );
        }
    }

    function _swapIntoBluechipAsset(uint256 amountIn)
        private
        returns (uint256)
    {
        return
            router.swapTokensForTokens(
                amountIn,
                depositToBluechipSwapPath,
                new uint256[](1) // todo: proper bin size needs to be passed
            );
    }

    function _swapIntoDepositAsset(uint256 amountIn) private returns (uint256) {
        return
            router.swapTokensForTokens(
                amountIn,
                bluechipToDepositSwapPath,
                new uint256[](1) // todo: proper bin size needs to be passed
            );
    }

    function _getPassedInvestPeriods() private view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return (block.timestamp - lastInvestmentTimestamp) / investmentPeriod;
    }

    function _removeUserInvestmentFromHistory(
        Position memory position,
        uint256 passedInvestPeriods,
        uint256 perPeriodInvestment
    )
        private
        returns (uint256 bluechipInvestment, uint256 depositAssetInvestment)
    {
        // iterate over historical gauges since initial deposit
        for (
            uint256 j = position.investedAtHistoricalIndex;
            j < position.investedAtHistoricalIndex + passedInvestPeriods;
            j++
        ) {
            // total spent and received at selected investment day
            (
                uint256 totalAmountSpent,
                uint256 totalAmountExchanged
            ) = dcaHistory.historicalGaugeByIndex(j);

            // calculate amount that user ownes in current gauge
            uint256 depositorOwnedBluechip = (totalAmountExchanged *
                perPeriodInvestment) / totalAmountSpent;

            bluechipInvestment += depositorOwnedBluechip;
            depositAssetInvestment += perPeriodInvestment;

            // decrease gauge info
            dcaHistory.decreaseHistoricalGaugeByIndex(
                j,
                perPeriodInvestment,
                depositorOwnedBluechip
            );
        }

        return (bluechipInvestment, depositAssetInvestment);
    }

    function _updateOrRemovePosition(
        DCADepositor storage depositor,
        uint256 positionIndex,
        uint256 notInvestedYet,
        uint8 newPositionSplit
    ) private {
        // if not invested yet amount is > 0 then update position
        if (notInvestedYet > 0) {
            // add newly splitted amounts to the queue
            globalInvestQueue.splitUserInvestmentAmount(
                notInvestedYet,
                newPositionSplit
            );

            depositor.positions[positionIndex].depositAmount = notInvestedYet;
            depositor.positions[positionIndex].amountSplit = newPositionSplit;
            depositor
                .positions[positionIndex]
                .investedAt = lastInvestmentTimestamp;
            depositor
                .positions[positionIndex]
                .investedAtHistoricalIndex = dcaHistory
                .currentHistoricalIndex();
        } else {
            // otherwise remove position
            depositor.positions[positionIndex] = depositor.positions[
                depositor.positions.length - 1
            ];
            depositor.positions.pop();
        }
    }

    function _withdrawDepositorInvestment(
        address sender,
        uint256 depositAssetAmount,
        uint256 bluechipAssetAmount,
        bool convertBluechipIntoDepositAsset
    ) private {
        // if convertion requested swap bluechip -> deposit asset
        if (bluechipAssetAmount != 0) {
            if (bluechipInvestmentState == BluechipInvestmentState.Investing) {
                bluechipAssetAmount = _withdrawInvestedBluechip(
                    bluechipAssetAmount
                );
            }

            if (convertBluechipIntoDepositAsset) {
                depositAssetAmount += _swapIntoDepositAsset(
                    bluechipAssetAmount
                );
                bluechipAssetAmount = 0;
            }
        }

        if (depositAssetAmount != 0) {
            depositTokenInfo.token.safeTransfer(sender, depositAssetAmount);
        }

        if (bluechipAssetAmount != 0) {
            _transferBluechip(sender, bluechipAssetAmount);
        }

        emit Withdraw(sender, depositAssetAmount, bluechipAssetAmount);
    }

    function _bluechipTokenScale() private view returns (uint256) {
        return 10**_bluechipDecimals();
    }

    function _scaleAmount(
        uint256 amount,
        uint8 decimals,
        uint8 scaleToDecimals
    ) internal pure returns (uint256) {
        if (decimals < scaleToDecimals) {
            return amount * uint256(10**uint256(scaleToDecimals - decimals));
        } else if (decimals > scaleToDecimals) {
            return amount / uint256(10**uint256(decimals - scaleToDecimals));
        }
        return amount;
    }

    // ----- Functions For Child Contract -----
    function _invest(uint256 amount) internal virtual returns (uint256);

    function _claimRewards() internal virtual returns (uint256);

    function _withdrawInvestedBluechip(uint256 amount)
        internal
        virtual
        returns (uint256);

    function _transferBluechip(address to, uint256 amount) internal virtual;

    function _totalBluechipInvested() internal view virtual returns (uint256);

    function _bluechipAddress() internal view virtual returns (address);

    function _bluechipDecimals() internal view virtual returns (uint8);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { InvestQueueLib } from "../libraries/InvestQueueLib.sol";
import { DCAHistoryLib } from "../libraries/DCAHistoryLib.sol";
import { IDCAStrategy } from "../interfaces/IDCAStrategy.sol";
import { SwapLib } from "../libraries/SwapLib.sol";
import { PortfolioAccessBaseUpgradeableCutted } from "./PortfolioAccessBaseUpgradeableCutted.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// solhint-disable-next-line max-states-count
abstract contract DCABaseUpgradeableCutted is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    PortfolioAccessBaseUpgradeableCutted
{
    error TooSmallDeposit();
    error PositionsLimitReached();
    error NothingToInvest();
    error NothingToWithdraw();

    event Deposit(address indexed sender, uint256 amount, uint256 amountSplit);
    event Invest(
        uint256 depositAmountSpent,
        uint256 bluechipReceived,
        uint256 investedAt,
        uint256 historicalIndex
    );
    event Withdraw(
        address indexed sender,
        uint256 withdrawnDeposit,
        uint256 withdrawnBluechip
    );
    event StatusChanged(
        BluechipInvestmentState indexed prevStatus,
        BluechipInvestmentState indexed newStatus
    );

    struct DCAEquityValuation {
        uint256 totalDepositToken;
        uint256 totalBluechipToken;
        address bluechipToken;
    }

    struct DCAStrategyInitArgs {
        DepositFee depositFee;
        address dcaInvestor;
        TokenInfo depositTokenInfo;
        uint256 investmentPeriod;
        uint256 lastInvestmentTimestamp;
        uint256 minDepositAmount;
        uint16 positionsLimit;
        SwapLib.Router router;
        address[] depositToBluechipSwapPath;
        address[] bluechipToDepositSwapPath;
        uint256[] depositToBluechipSwapBins;
        uint256[] bluechipToDepositSwapBins;
    }

    struct DepositFee {
        address feeReceiver;
        uint16 fee; // .0000 number
    }

    struct TokenInfo {
        IERC20Upgradeable token;
        uint8 decimals;
    }

    struct Position {
        uint256 depositAmount;
        uint8 amountSplit;
        uint256 investedAt;
        uint256 investedAtHistoricalIndex;
    }

    struct DCADepositor {
        Position[] positions;
    }

    enum BluechipInvestmentState {
        Investing,
        Withdrawn,
        EmergencyExited
    }

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

    uint256[] public depositToBluechipSwapBins;
    uint256[] public bluechipToDepositSwapBins;

    uint256[8] private __gap;

    // solhint-disable-next-line
    function __DCABaseUpgradeable_init(DCAStrategyInitArgs calldata args)
        internal
        onlyInitializing
    {
        __PortfolioAccessBaseUpgradeableCutted_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        setBluechipInvestmentState(BluechipInvestmentState.Investing);
        setDepositFee(args.depositFee);
        setDCAInvestor(args.dcaInvestor);
        depositTokenInfo = args.depositTokenInfo;
        depositTokenScale = 10**args.depositTokenInfo.decimals;
        setInvestmentPeriod(args.investmentPeriod);
        setLastInvestmentTimestamp(args.lastInvestmentTimestamp);
        setMinDepositAmount(args.minDepositAmount);
        setPositionsLimit(args.positionsLimit);
        setRouter(args.router);
        setSwapPath(
            args.depositToBluechipSwapPath,
            args.bluechipToDepositSwapPath,
            args.depositToBluechipSwapBins,
            args.bluechipToDepositSwapBins
        );
    }

    modifier nonEmergencyExited() {
        require(
            bluechipInvestmentState != BluechipInvestmentState.EmergencyExited,
            "Strategy is emergency exited"
        );

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
        if (depositFee.fee > 0) {
            uint256 actualDeposit = (amount * (10000 - depositFee.fee)) / 10000;

            uint256 feeAmount = amount - actualDeposit;
            if (feeAmount != 0) {
                depositTokenInfo.token.safeTransfer(
                    depositFee.feeReceiver,
                    feeAmount
                );
            }

            amount = actualDeposit;
        }

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

                // (amount / amountSplit) * amountSplit exression will produce the same truncation loss as the one
                // that happens during adding the funds to the investment queue
                depositor.positions[i].depositAmount +=
                    (amount / amountSplit) *
                    amountSplit;

                emit Deposit(sender, amount, amountSplit);
                return;
            }
        }

        // otherwise create new position
        depositor.positions.push(
            Position(
                (amount / amountSplit) * amountSplit,
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
        nonReentrant
        whenNotPaused
        nonEmergencyExited
    {
        require(_msgSender() == dcaInvestor, "Unauthorized");

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
            uint256 receivedBluechip = router.swapTokensForTokens(
                depositedAmount,
                depositToBluechipSwapPath,
                depositToBluechipSwapBins
            );

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
    {
        if (isEmergencyExited()) {
            _emergencyWithdrawUserDeposit(_msgSender());
            return;
        }
        _withdrawAll(_msgSender(), convertBluechipIntoDepositAsset);
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

        // if convertion requested swap bluechip -> deposit asset
        if (investedIntoBluechip != 0) {
            if (bluechipInvestmentState == BluechipInvestmentState.Investing) {
                investedIntoBluechip = _withdrawInvestedBluechip(
                    investedIntoBluechip
                );
            }

            if (convertBluechipIntoDepositAsset) {
                notInvestedYet += router.swapTokensForTokens(
                    investedIntoBluechip,
                    bluechipToDepositSwapPath,
                    bluechipToDepositSwapBins
                );
                investedIntoBluechip = 0;
            }
        }

        if (notInvestedYet != 0) {
            depositTokenInfo.token.safeTransfer(sender, notInvestedYet);
        }

        if (investedIntoBluechip != 0) {
            _transferBluechip(sender, investedIntoBluechip);
        }

        emit Withdraw(sender, notInvestedYet, investedIntoBluechip);
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
            // _deductLossFromGauges(bluechipBalance - actualReceived);

            uint256 diff = bluechipBalance - actualReceived;
            for (
                uint256 i = dcaHistory.currentHistoricalIndex() - 1;
                i >= 0;
                i--
            ) {
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
    }

    function emergencyWithdrawFunds(
        TokenInfo calldata emergencyExitDepositToken_,
        address[] calldata depositSwapPath,
        uint256[] calldata depositSwapBins,
        TokenInfo calldata emergencyExitBluechipToken_,
        address[] calldata bluechipSwapPath,
        uint256[] calldata bluechipSwapBins
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
                    depositSwapBins
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
                    bluechipSwapBins
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
            uint256 payout = _scaleAmount(
                (notInvestedYet * emergencySellDepositPrice) /
                    depositTokenScale,
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
            uint256 payout = _scaleAmount(
                (investedIntoBluechip * emergencySellBluechipPrice) /
                    _bluechipTokenScale(),
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
        private
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

    // function setDepositTokenInto(TokenInfo memory newDepositTokenInfo) private {
    //     require(
    //         address(newDepositTokenInfo.token) != address(0),
    //         "Invalid deposit token address"
    //     );
    //     depositTokenInfo = newDepositTokenInfo;
    //     depositTokenScale = 10**depositTokenInfo.decimals;
    // }

    function setInvestmentPeriod(uint256 newInvestmentPeriod) public onlyOwner {
        require(newInvestmentPeriod > 0, "Invalid investment period");
        investmentPeriod = newInvestmentPeriod;
    }

    function setLastInvestmentTimestamp(uint256 newLastInvestmentTimestamp)
        private
    {
        require(
            newLastInvestmentTimestamp >= lastInvestmentTimestamp,
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
        address[] memory depositToBluechipPath,
        address[] memory bluechipToDepositPath,
        uint256[] memory depositToBluechipBins,
        uint256[] memory bluechipToDepositBins
    ) public onlyOwner {
        require(
            depositToBluechipPath[0] ==
                bluechipToDepositPath[bluechipToDepositPath.length - 1] &&
                depositToBluechipPath[depositToBluechipPath.length - 1] ==
                bluechipToDepositPath[0],
            "Invalid swap path"
        );
        require(
            depositToBluechipBins.length + 1 == depositToBluechipPath.length,
            "depToBlue length incorrect"
        );
        require(
            bluechipToDepositBins.length + 1 == bluechipToDepositPath.length,
            "BlueToDep length incorrect"
        );

        depositToBluechipSwapPath = depositToBluechipPath;
        bluechipToDepositSwapPath = bluechipToDepositPath;
        depositToBluechipSwapBins = depositToBluechipBins;
        bluechipToDepositSwapBins = bluechipToDepositBins;
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

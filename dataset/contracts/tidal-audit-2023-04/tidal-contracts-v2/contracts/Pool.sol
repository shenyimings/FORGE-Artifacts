// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./model/PoolModel.sol";
import "./common/NonReentrancy.sol";
import "./interface/IEventAggregator.sol";

contract Pool is Initializable, NonReentrancy, Context, PoolModel {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
 
    uint256 constant SHARE_UNITS = 1e18;
    uint256 constant AMOUNT_PER_SHARE = 1e18;
    uint256 constant VOTE_EXPIRATION = 3 days;
    uint256 constant RATIO_BASE = 1e6;
    uint256 constant TIME_OFFSET = 4 days;

    function initialize(
        address baseToken_,
        address tidalToken_,
        bool isTest_,
        address poolManager_,
        address[] calldata committeeMembers_
    ) public initializer {
        baseToken = baseToken_;
        tidalToken = tidalToken_;
        isTest = isTest_;
        committeeThreshold = 2;

        require(poolManager_ != address(0), "Empty poolManager");
        require(committeeMembers_.length >= 2, "At least 2 initial members");

        poolManager = poolManager_;
        for (uint256 i = 0; i < committeeMembers_.length; ++i) {
            address member = committeeMembers_[i];
            committeeArray.push(member);
            committeeIndexPlusOne[member] = committeeArray.length;
        }
    }

    modifier onlyPoolManager() {
        require(poolManager == _msgSender(), "Only pool manager");
        _;
    }

    modifier onlyTest() {
        require(isTest, "Only enabled in test environment");
        _;
    }

    modifier onlyCommittee() {
        require(committeeIndexPlusOne[_msgSender()] > 0, "Only committee");
        _;
    }

    // ** Time related functions.

    function setTimeExtra(uint256 timeExtra_) external onlyTest {
        timeExtra = timeExtra_;
    }

    function getCurrentWeek() public view returns(uint256) {
        return (block.timestamp + TIME_OFFSET + timeExtra) / (7 days);
    }

    function getNow() public view returns(uint256) {
        return block.timestamp + timeExtra;
    }

    function getWeekFromTime(uint256 time_) public pure returns(uint256) {
        return (time_ + TIME_OFFSET) / (7 days);
    }

    function getUnlockTime(
        uint256 time_,
        uint256 waitWeeks_
    ) public pure returns(uint256) {
        require(time_ + TIME_OFFSET > (7 days), "Time not large enough");
        return ((time_ + TIME_OFFSET) / (7 days) + waitWeeks_) * (7 days) - TIME_OFFSET;
    }

    // ** Event aggregator

    function setEventAggregator(address eventAggregator_) external onlyPoolManager {
        eventAggregator = eventAggregator_;
    }

    // ** Pool and policy config.

    function getPool() external view returns(
        uint256 withdrawWaitWeeks1_,
        uint256 withdrawWaitWeeks2_,
        uint256 policyWeeks_,
        uint256 withdrawFee_,
        uint256 managementFee1_,
        uint256 managementFee2_,
        bool enabled_,
        string memory name_,
        string memory terms_
    ) {
        withdrawWaitWeeks1_ = withdrawWaitWeeks1;
        withdrawWaitWeeks2_ = withdrawWaitWeeks2;
        policyWeeks_ = policyWeeks;
        withdrawFee_ = withdrawFee;
        managementFee1_ = managementFee1;
        managementFee2_ = managementFee2;
        enabled_ = enabled;
        name_ = name;
        terms_ = terms;
    }

    function setPool(
        uint256 withdrawWaitWeeks1_,
        uint256 withdrawWaitWeeks2_,
        uint256 policyWeeks_,
        uint256 withdrawFee_,
        uint256 managementFee1_,
        uint256 managementFee2_,
        bool enabled_,
        string calldata name_,
        string calldata terms_
    ) external onlyPoolManager {
        withdrawWaitWeeks1 = withdrawWaitWeeks1_;
        withdrawWaitWeeks2 = withdrawWaitWeeks2_;
        policyWeeks = policyWeeks_;
        withdrawFee = withdrawFee_;
        managementFee1 = managementFee1_;
        managementFee2 = managementFee2_;
        enabled = enabled_;
        name = name_;
        terms = terms_;
    }

    function setPolicy(
        uint256 index_,
        uint256 collateralRatio_,
        uint256 weeklyPremium_,
        string calldata name_,
        string calldata terms_
    ) external onlyPoolManager {
        require(index_ < policyArray.length, "Invalid index");

        Policy storage policy = policyArray[index_];
        policy.collateralRatio = collateralRatio_;
        policy.weeklyPremium = weeklyPremium_;
        policy.name = name_;
        policy.terms = terms_;
    }

    function addPolicy(
        uint256 collateralRatio_,
        uint256 weeklyPremium_,
        string calldata name_,
        string calldata terms_
    ) external onlyPoolManager {
        policyArray.push(Policy({
            collateralRatio: collateralRatio_,
            weeklyPremium: weeklyPremium_,
            name: name_,
            terms: terms_
        }));
    }

    function getPolicyArrayLength() external view returns(uint256) {
        return policyArray.length;
    }

    function getCollateralAmount() external view returns(uint256) {
        return poolInfo.amountPerShare.mul(
            poolInfo.totalShare.sub(
                poolInfo.pendingWithdrawShare)).div(SHARE_UNITS);
    }

    function getAvailableCapacity(
        uint256 policyIndex_,
        uint256 w_
    ) public view returns(uint256) {
        uint256 currentWeek = getCurrentWeek();
        uint256 amount = 0;
        uint256 w;

        if (w_ >= currentWeek.add(withdrawWaitWeeks1) || w_ < currentWeek) {
            return 0;
        } else {
            amount = poolInfo.amountPerShare.mul(
                poolInfo.totalShare.sub(
                    poolInfo.pendingWithdrawShare)).div(SHARE_UNITS);

            for (w = currentWeek.sub(withdrawWaitWeeks1);
                 w < w_.sub(withdrawWaitWeeks1);
                 ++w) {
                amount = amount.sub(
                    poolInfo.amountPerShare.mul(
                        poolWithdrawMap[w]).div(SHARE_UNITS));
            }

            Policy storage policy = policyArray[policyIndex_];
            uint256 capacity = amount.mul(RATIO_BASE).div(policy.collateralRatio);

            if (capacity > coveredMap[policyIndex_][w_]) {
                return capacity.sub(coveredMap[policyIndex_][w_]);
            } else {
                return 0;
            }
        }
    }

    function getCurrentAvailableCapacity(
        uint256 policyIndex_
    ) external view returns(uint256) {
        uint256 w = getCurrentWeek();
        return getAvailableCapacity(policyIndex_, w);
    }

    function getTotalAvailableCapacity() external view returns(uint256) {
        uint256 w = getCurrentWeek();

        uint256 total = 0;
        for (uint256 i = 0; i < policyArray.length; ++i) {
            total += getAvailableCapacity(i, w);
        }

        return total;
    }

    function getUserBaseAmount(address who_) external view returns(uint256) {
        UserInfo storage userInfo = userInfoMap[who_];
        return poolInfo.amountPerShare.mul(userInfo.share).div(SHARE_UNITS);
    }

    // ** Regular operations.

    // Anyone can be a buyer, and pay premium on certain policy for a few weeks.
    function buy(
        uint256 policyIndex_,
        uint256 amount_,
        uint256 fromWeek_,
        uint256 toWeek_,
        string calldata notes_
    ) external noReenter {
        require(enabled, "Not enabled");

        require(toWeek_ > fromWeek_, "Not enough weeks");
        require(toWeek_.sub(fromWeek_) <= policyWeeks,
            "Too many weeks");
        require(fromWeek_ > getCurrentWeek(), "Buy next week");

        Policy storage policy = policyArray[policyIndex_];
        uint256 premium = amount_.mul(policy.weeklyPremium).div(RATIO_BASE);
        uint256 allPremium = premium.mul(toWeek_.sub(fromWeek_));

        uint256 maximumToCover = poolInfo.amountPerShare.mul(
            poolInfo.totalShare.sub(
                poolInfo.pendingWithdrawShare)).div(SHARE_UNITS).mul(
                    RATIO_BASE).div(policy.collateralRatio);

        for (uint256 w = fromWeek_; w < toWeek_; ++w) {
            incomeMap[policyIndex_][w] =
                incomeMap[policyIndex_][w].add(premium);
            coveredMap[policyIndex_][w] =
                coveredMap[policyIndex_][w].add(amount_);

            require(coveredMap[policyIndex_][w] <= maximumToCover,
                "Not enough to buy");

            coverageMap[policyIndex_][w][_msgSender()] = Coverage({
                amount: amount_,
                premium: premium,
                refunded: false
            });
        }

        IERC20(baseToken).safeTransferFrom(
            _msgSender(), address(this), allPremium);

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).buy(
                _msgSender(),
                policyIndex_,
                amount_,
                fromWeek_,
                toWeek_,
                notes_
            );
        }
    }

    // Anyone just call this function once per week for every policy.
    function addPremium(uint256 policyIndex_) external noReenter {
        require(enabled, "Not enabled");

        uint256 week = getCurrentWeek();

        Policy storage policy = policyArray[policyIndex_];

        uint256 maximumToCover = poolInfo.amountPerShare.mul(
            poolInfo.totalShare.sub(
                poolInfo.pendingWithdrawShare)).div(SHARE_UNITS).mul(
                    RATIO_BASE).div(policy.collateralRatio);

        uint256 allCovered = coveredMap[policyIndex_][week];

        if (allCovered > maximumToCover) {
            refundMap[policyIndex_][week] = incomeMap[policyIndex_][week].mul(
                allCovered.sub(maximumToCover)).div(allCovered);
            incomeMap[policyIndex_][week] = incomeMap[policyIndex_][week].sub(
                refundMap[policyIndex_][week]);
        }

        // Deducts management fee.
        uint256 totalIncome = incomeMap[policyIndex_][week];
        uint256 fee1 = totalIncome.mul(managementFee1).div(RATIO_BASE);
        uint256 fee2 = totalIncome.mul(managementFee2).div(RATIO_BASE);
        uint256 realIncome = totalIncome.sub(fee1).sub(fee2);

        poolInfo.amountPerShare = poolInfo.amountPerShare.add(
            realIncome.mul(SHARE_UNITS).div(poolInfo.totalShare));

        // Distributes fee1.
        UserInfo storage poolManagerInfo = userInfoMap[poolManager];
        uint256 fee1Share = fee1.mul(SHARE_UNITS).div(poolInfo.amountPerShare);
        poolManagerInfo.share = poolManagerInfo.share.add(fee1Share);
        poolInfo.totalShare = poolInfo.totalShare.add(fee1Share);

        // Distributes fee2.
        IERC20(baseToken).safeTransfer(poolManager, fee2);

        incomeMap[policyIndex_][week] = 0;
    }

    // Anyone just call this function once per week for every policy.
    function refund(
        uint256 policyIndex_,
        uint256 week_,
        address who_
    ) external noReenter {
        Coverage storage coverage = coverageMap[policyIndex_][week_][who_];

        require(!coverage.refunded, "Already refunded");

        uint256 allCovered = coveredMap[policyIndex_][week_];
        uint256 amountToRefund = refundMap[policyIndex_][week_].mul(
            coverage.amount).div(allCovered);
        coverage.amount = coverage.amount.mul(
            coverage.premium.sub(amountToRefund)).div(coverage.premium);
        coverage.refunded = true;

        IERC20(baseToken).safeTransfer(who_, amountToRefund);

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).refund(
                policyIndex_,
                week_,
                who_,
                amountToRefund
            );
        }
    }

    // Anyone can be a seller, and deposit baseToken (e.g. USDC or WETH)
    // to the pool.
    function deposit(
        uint256 amount_
    ) external noReenter {
        require(enabled, "Not enabled");

        require(amount_ >= AMOUNT_PER_SHARE / 1000000, "Less than minimum");

        IERC20(baseToken).safeTransferFrom(
            _msgSender(), address(this), amount_);

        _updateUserTidal(_msgSender());

        UserInfo storage userInfo = userInfoMap[_msgSender()];

        if (poolInfo.totalShare == 0) {          
            poolInfo.amountPerShare = AMOUNT_PER_SHARE;
            poolInfo.totalShare = amount_.mul(SHARE_UNITS).div(AMOUNT_PER_SHARE);
            userInfo.share = poolInfo.totalShare;
        } else {
            uint256 shareToAdd =
                amount_.mul(SHARE_UNITS).div(poolInfo.amountPerShare);
            poolInfo.totalShare = poolInfo.totalShare.add(shareToAdd);
            userInfo.share = userInfo.share.add(shareToAdd);
        }

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).deposit(
                _msgSender(),
                amount_
            );
        }
    }

    function getUserAvailableWithdrawAmount(
        address who_
    ) external view returns(uint256) {
        UserInfo storage userInfo = userInfoMap[who_];
        return poolInfo.amountPerShare.mul(
            userInfo.share.sub(
                userInfo.pendingWithdrawShare)).div(SHARE_UNITS);
    }

    // Existing sellers can request to withdraw from the pool by shares.
    function withdraw(
        uint256 share_
    ) external {
        require(enabled, "Not enabled");

        UserInfo storage userInfo = userInfoMap[_msgSender()];

        require(userInfo.share >=
            userInfo.pendingWithdrawShare.add(share_), "Not enough");

        withdrawRequestMap[_msgSender()].push(WithdrawRequest({
            share: share_,
            time: getNow(),
            pending: false,
            executed: false,
            succeeded: false
        }));

        userInfo.pendingWithdrawShare = userInfo.pendingWithdrawShare.add(
            share_);

        uint256 week = getCurrentWeek();
        poolWithdrawMap[week] = poolWithdrawMap[week].add(share_);

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).withdraw(
                _msgSender(),
                withdrawRequestMap[_msgSender()].length.sub(1),
                share_
            );
        }
    }

    // Called after withdrawWaitWeeks1, by anyone (can be a script or by
    // seller himself).
    function withdrawPending(
        address who_,
        uint256 index_
    ) external {
        require(enabled, "Not enabled");

        require(index_ < withdrawRequestMap[who_].length, "No index");

        WithdrawRequest storage request = withdrawRequestMap[who_][index_];
        require(!request.pending, "Already pending");

        uint256 unlockTime = getUnlockTime(request.time, withdrawWaitWeeks1);
        require(getNow() > unlockTime, "Not ready yet");

        poolInfo.pendingWithdrawShare = poolInfo.pendingWithdrawShare.add(
            request.share);

        request.pending = true;

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).withdrawPending(
                who_,
                index_
            );
        }
    }

    // Called after withdrawWaitWeeks2, by anyone.
    function withdrawReady(
        address who_,
        uint256 index_
    ) external noReenter {
        require(enabled, "Not enabled");

        require(index_ < withdrawRequestMap[who_].length, "No index");

        WithdrawRequest storage request = withdrawRequestMap[who_][index_];
        require(!request.executed, "Already executed");
        require(request.pending, "Not pending yet");

        uint256 waitWeeks = withdrawWaitWeeks1.add(withdrawWaitWeeks2);
        uint256 unlockTime = getUnlockTime(request.time, waitWeeks);
        require(getNow() > unlockTime, "Not ready yet");

        UserInfo storage userInfo = userInfoMap[who_];

        if (userInfo.share >= request.share) {
            _updateUserTidal(who_);

            userInfo.share = userInfo.share.sub(request.share);
            poolInfo.totalShare = poolInfo.totalShare.sub(request.share);

            uint256 amount = poolInfo.amountPerShare.mul(
                request.share).div(SHARE_UNITS);

            // A withdrawFee goes to everyone.
            uint256 fee = amount.mul(withdrawFee).div(RATIO_BASE);
            IERC20(baseToken).safeTransfer(who_, amount.sub(fee));
            poolInfo.amountPerShare = poolInfo.amountPerShare.add(
                fee.mul(SHARE_UNITS).div(poolInfo.totalShare));

            request.succeeded = true;
        } else {
            request.succeeded = false;
        }

        request.executed = true;

        // Reduce pendingWithdrawShare.
        userInfo.pendingWithdrawShare = userInfo.pendingWithdrawShare.sub(
            request.share);
        poolInfo.pendingWithdrawShare = poolInfo.pendingWithdrawShare.sub(
            request.share);

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).withdrawReady(
                who_,
                index_,
                request.succeeded
            );
        }
    }

    function withdrawRequestCount(
        address who_
    ) external view returns(uint256) {
        return withdrawRequestMap[who_].length;
    }

    // Anyone can add tidal to the pool as incentative any time.
    function addTidal(uint256 amount_) external noReenter {
        IERC20(tidalToken).safeTransferFrom(
            _msgSender(), address(this), amount_);

        poolInfo.accTidalPerShare = poolInfo.accTidalPerShare.add(
            amount_.mul(SHARE_UNITS)).div(poolInfo.totalShare);
    }

    function _updateUserTidal(address who_) private {
        UserInfo storage userInfo = userInfoMap[who_];
        uint256 accAmount = poolInfo.accTidalPerShare.add(
            userInfo.share).div(SHARE_UNITS);
        userInfo.tidalPending = userInfo.tidalPending.add(
            accAmount.sub(userInfo.tidalDebt));
        userInfo.tidalDebt = accAmount;
    }

    function getUserTidalAmount(address who_) external view returns(uint256) {
        UserInfo storage userInfo = userInfoMap[who_];
        return poolInfo.accTidalPerShare.mul(
            userInfo.share).div(SHARE_UNITS).add(
                userInfo.tidalPending).sub(userInfo.tidalDebt);
    }

    // Sellers can withdraw TIDAL, which are bonuses, from the pool.
    function withdrawTidal() external noReenter {
        require(enabled, "Not enabled");

        UserInfo storage userInfo = userInfoMap[_msgSender()];
        uint256 accAmount = poolInfo.accTidalPerShare.add(userInfo.share);
        uint256 tidalAmount = userInfo.tidalPending.add(
            accAmount).sub(userInfo.tidalDebt);

        IERC20(tidalToken).safeTransfer(_msgSender(), tidalAmount);

        userInfo.tidalPending = 0;
        userInfo.tidalDebt = accAmount;
    }

    // ** Emergency

    // Pool manager can enable or disable the pool in emergency.
    function enablePool(bool enabled_) external onlyPoolManager {
        enabled = enabled_;
    }

    // ** Claim (and other type of requests), vote, and execute.

    // ** Operation #0, claim
    function claim(
        uint256 policyIndex_,
        uint256 amount_,
        address receipient_
    ) external onlyPoolManager {
        committeeRequestArray.push(CommitteeRequest({
            time: getNow(),
            vote: 0,
            executed: false,
            operation: 0,
            data: abi.encode(amount_, receipient_)
        }));

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).claim(
                policyIndex_,
                amount_,
                receipient_
            );
        }
    }

    // ** Operation #1, changePoolManager
    function changePoolManager(
        address poolManager_
    ) external onlyCommittee {
        committeeRequestArray.push(CommitteeRequest({
            time: getNow(),
            vote: 0,
            executed: false,
            operation: 1,
            data: abi.encode(poolManager_)
        }));

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).changePoolManager(
                poolManager_
            );
        }
    }

    // ** Operation #2, addToCommittee
    function addToCommittee(
        address who_
    ) external onlyCommittee {
        require(committeeIndexPlusOne[who_] == 0, "Existing committee member");

        committeeRequestArray.push(CommitteeRequest({
            time: getNow(),
            vote: 0,
            executed: false,
            operation: 2,
            data: abi.encode(who_)
        }));

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).addToCommittee(
                who_
            );
        }
    }

    // ** Operation #3, removeFromCommittee
    function removeFromCommittee(
        address who_
    ) external onlyCommittee {
        require(committeeArray.length > committeeThreshold,
                "Not enough members");

        committeeRequestArray.push(CommitteeRequest({
            time: getNow(),
            vote: 0,
            executed: false,
            operation: 3,
            data: abi.encode(who_)
        }));

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).removeFromCommittee(
                who_
            );
        }
    }

    // ** Operation #4, changeCommitteeThreshold
    function changeCommitteeThreshold(
        uint256 threshold_
    ) external onlyCommittee {
        require(threshold_ <= committeeArray.length,
                "Threshold more than member count");

        committeeRequestArray.push(CommitteeRequest({
            time: getNow(),
            vote: 0,
            executed: false,
            operation: 4,
            data: abi.encode(threshold_)
        }));

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).changeCommitteeThreshold(
                threshold_
            );
        }
    }

    // Committee members can vote on any of the above 5 types of operations.
    function vote(
        uint256 requestIndex_,
        bool support_
    ) external onlyCommittee {
        if (!support_) {
            return;
        }

        require(requestIndex_ < committeeRequestArray.length, "Invalid index");

        require(!committeeVote[_msgSender()][requestIndex_],
                "Already supported");
        committeeVote[_msgSender()][requestIndex_] = true;

        CommitteeRequest storage cr = committeeRequestArray[requestIndex_];

        require(getNow() < cr.time.add(VOTE_EXPIRATION),
                "Already expired");
        require(!cr.executed, "Already executed");
        cr.vote = cr.vote.add(1);

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).vote(
                requestIndex_,
                support_
            );
        }
    }

    // Anyone can execute an operation request that has received enough
    // approving votes.
    function execute(uint256 requestIndex_) external noReenter {
        require(requestIndex_ < committeeRequestArray.length, "Invalid index");

        CommitteeRequest storage cr = committeeRequestArray[requestIndex_];

        require(cr.vote >= committeeThreshold, "Not enough votes");
        require(getNow() < cr.time.add(VOTE_EXPIRATION),
                "Already expired");
        require(!cr.executed, "Already executed");

        cr.executed = true;

        if (cr.operation == 0) {
            (uint256 amount, address receipient) = abi.decode(
                cr.data, (uint256, address));
            _executeClaim(amount, receipient);
        } else if (cr.operation == 1) {
            address poolManager = abi.decode(cr.data, (address));
            _executeChangePoolManager(poolManager);
        } else if (cr.operation == 2) {
            address newMember = abi.decode(cr.data, (address));
            _executeAddToCommittee(newMember);
        } else if (cr.operation == 3) {
            address oldMember = abi.decode(cr.data, (address));
            _executeRemoveFromCommittee(oldMember);
        } else if (cr.operation == 4) {
            uint256 threshold = abi.decode(cr.data, (uint256));
            _executeChangeCommitteeThreshold(threshold);
        }

        if (eventAggregator != address(0)) {
            IEventAggregator(eventAggregator).execute(
                requestIndex_
            );
        }
    }

    function _executeClaim(
        uint256 amount_,
        address receipient_
    ) private {
        IERC20(baseToken).safeTransfer(receipient_, amount_);

        poolInfo.amountPerShare = poolInfo.amountPerShare.sub(
            amount_.mul(SHARE_UNITS).div(poolInfo.totalShare));
    }

    function _executeChangePoolManager(address poolManager_) private {
        poolManager = poolManager_;
    }

    function _executeAddToCommittee(address who_) private {
        require(committeeIndexPlusOne[who_] == 0, "Existing committee member");
        committeeArray.push(who_);
        committeeIndexPlusOne[who_] = committeeArray.length;
    }

    function _executeRemoveFromCommittee(address who_) private {
        require(committeeIndexPlusOne[who_] > 0,
                "Non-existing committee member");
        if (committeeIndexPlusOne[who_] != committeeArray.length) {
            address lastOne = committeeArray[committeeArray.length.sub(1)];
            committeeIndexPlusOne[lastOne] = committeeIndexPlusOne[who_];
            committeeArray[committeeIndexPlusOne[who_].sub(1)] = lastOne;
        }

        committeeIndexPlusOne[who_] = 0;
        committeeArray.pop();
    }

    function _executeChangeCommitteeThreshold(uint256 threshold_) private {
        require(threshold_ >= 2, "Invalid threshold");
        committeeThreshold = threshold_;
    }

    function getCommitteeRequestLength() external view returns(uint256) {
        return committeeRequestArray.length;
    }

    function getCommitteeRequestArray(
        uint256 limit_,
        uint256 offset_
    ) external view returns(CommitteeRequest[] memory) {
        if (committeeRequestArray.length <= offset_) {
            return new CommitteeRequest[](0);
        }

        uint256 leftSideOffset = committeeRequestArray.length.sub(offset_);
        CommitteeRequest[] memory result =
            new CommitteeRequest[](
                leftSideOffset < limit_ ? leftSideOffset : limit_);

        uint256 i = 0;
        while (i < limit_ && leftSideOffset > 0) {
            leftSideOffset = leftSideOffset.sub(1);
            result[i] = committeeRequestArray[leftSideOffset];
            i = i.add(1);
        }

        return result;
    }
}

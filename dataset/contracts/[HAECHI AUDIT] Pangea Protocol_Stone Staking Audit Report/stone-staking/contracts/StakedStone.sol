// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/IStakedStone.sol";
import "./libraries/FullMath.sol";
import "./libraries/FixedPoint.sol";

/**
 * StakedStone Contract created to distribute rewards to STONE holders

 [예치 프로세스]
 ==============

 StakedStone에 예치함으로써, STONE 홀더는 Pangeaswap에서 발생하는 수익들을 공유받을 수 있습니다.
 유저가 예치한 자산을 빼려면 unstake을 호출 후, cooldown 기간이후에 withdraw할 수 있습니다.
 unstake 호출 후에는 유저는 claim할 수 없습니다.

 1. Manager Side
     stake() => unstake() =====> withdraw()
                        ----------
                       | cooldown | 기간 필요


   - setCooldownPeriod(period)
     : unstake에서 withdraw까지의 기간을 지정. default : 7 days 소요

 1. Holder Side

   - stake(amount)
     : amount만큼의 STONE을 예치

   - unstake(amount)
     : 예치된 STONE에서 amount 만큼 인출

   - unstakingRequestCounts(owner)
     : 현재 owner가 요청한 unstaking request 갯수 ( withdraw하면 줄어듦)

   - unstakingRequestByIndex(owner, index);
     : 요청한 unstaking 정보 조회

   - withdraw(requestId)
     : cooldown 기간이 지난 unstaking request 호출해서 가져오기


 [배당 프로세스]
 ==============

 `배당`은 비정기적으로 프로토콜 수익을 Holder들에게 환원하는 프로세스로,
 유저의 예치량과 예치 기간에 비례하여 프로토콜 수익을 나누어 준다.

   1. Manager Side

      배당금 집행일 확정         배당금 납입                      배당금 집행
      setDividendRecordDate() => depositDividend(token,amount) => executeDividend();

                              <= resetDividendRecordDate() : 집행전 배당금 취소;

        - 집행시각 기준으로 account 별 지분율을 산출한다.
        - 배당금이 납입되어야, 집행이 진행된다.
        - 납입된 배당금은 전액 해당 배당금 분배에 사용된다.
        - 집행 전까지 언제든 resetDividendRecordDate을 호출할 수 있으며, 납입된 배당금은 회수처리된다. (msg.sender로)

   2. Holder Side

      - allocatedDividend(epoch)
        : 해당 epoch에서 받을 수 있는 배당금 토큰 조회

      - claimDividend(epoch)
        : 해당 epoch에 배치된 배당금을 수령

 [리워드 프로세스]
 ================

 `리워드`는 매주 배치되어 있는 거버넌스 토큰을 예치한 홀더에게 제공하는 프로세스로,
 매 블럭마다 선형적으로 분배된다.

    1. Manager Side

       - depositReward(amount, startTime)
         : 리워드 납입 (startTime에서 부터 1주일간 분배)

       - cancelReward(amount, startTime)
         : 분배되지 않은 주차의 리워드 회수

    2. Holder Side

      - claimableReward(owner)
        : 현재 받을 수 있는 리워드 량 조회

      - claimReward()
        : 리워드 수령

 */
contract StakedStone is
    Multicall,
    AccessControlUpgradeable,
    IStakedStone {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256(abi.encode("MANAGER"));

    // @dev 주차 별 배치된 리워드 총액, (timestamp % 7 days) == 0의 값으로 입력해야 함.
    mapping(uint256 => uint256) public totalRewardPerWeek;

    uint256 private checkpoint;

    uint256 private rewardGrowthGlobalLast;
    uint256 private pendingReward;

    uint256 private totalShare;

    mapping(address => uint256) private _balanceOf;
    uint256 private _totalSupply;

    // @dev unstake 후 withdraw 가능할 때까지 기간 (초)
    uint256 public cooldownPeriod;

    address public stone;

    // @dev Staked Stone 시작 시간
    uint256 private openDate;

    // @dev 배당 예정 정보 (미배당 상태)
    Dividend private readyDividend;

    // @dev 과거 배당 정보 (배당된 상태)
    Dividend[] private _dividendHistory;

    mapping(address => uint256) private _userLastRecordDate;
    mapping(address => mapping(uint256 => DividendSnapshot)) private _userDividendSnapshot;

    UnstakingRequest[] public unstakingRequests;
    mapping(uint256 => address) public requestOwnerOf;
    /**
     * @notice Get the number of un-staking requests by owner
     */
    mapping(address => uint256) public unstakingRequestCounts;
    mapping(address => mapping(uint256 => uint256)) private _ownedRequests;
    mapping(uint256 => uint256) private _ownedRequestsIndex;

    // @dev 유저의 리워드 스냅샷 정보, 이를 통해 받을 수 있는 리워드를 역산
    mapping(address => RewardSnapshot) private _userRewardSnapshot;

    /**
     * @notice 유저별 수령한 누적 리워드(STONE)
     */
    mapping(address => uint256) public accumulativeUserReward;

    receive() external payable {
    }

    function initialize(
        address _stone,
        uint256 _openDate
    ) external initializer {
        stone = _stone;
        cooldownPeriod = 7 days;

        openDate = _openDate;
        checkpoint = _openDate;

        __AccessControl_init();
        _setupRole(AccessControlUpgradeable.DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier updateUserSnapshot(address owner) {
        uint256 growthGlobal = _updateGrowthGlobal();
        _updateRewardSnapshot(owner, growthGlobal);
        _updateDividendSnapshot(owner);

        _;
    }

    /**
     * @notice deposit the STONE to be distributed linearly for 1 week
     * @param amount amount to deposit
     * @param startTime The start time of distribution. should always satisfy UTC 00:00. (startTime % 604,800 == 0)
     */
    function depositReward(uint256 amount, uint256 startTime) external onlyRole(MANAGER_ROLE) {
        require(startTime % 7 days == 0, "startTime % 7 days != 0");
        require(startTime >= block.timestamp, "TOO LATE");

        IERC20(stone).safeTransferFrom(msg.sender, address(this), amount);

        totalRewardPerWeek[startTime] += amount;

        emit DepositReward(msg.sender, startTime, amount);
    }

    /**
     * @notice Retrieve undistributed STONE
     */
    function cancelReward(uint256 amount, uint256 startTime) external onlyRole(MANAGER_ROLE) {
        require(startTime >= block.timestamp, "TOO LATE");

        totalRewardPerWeek[startTime] -= amount;

        IERC20(stone).transfer(msg.sender, amount);

        emit CancelReward(msg.sender, startTime, amount);
    }

    /**
     * @notice 배당 기준시각 셋팅하기
     */
    function setDividendRecordDate() external onlyRole(MANAGER_ROLE) {
        require(block.timestamp >= openDate, "NOT START");
        _updateGrowthGlobal();

        require(readyDividend.recordDate == 0, "ALREADY SET");
        require(totalShare > 0, "TOTAL SHARE NOT ZERO");

        readyDividend.startDate = _dividendHistory.length > 0 ? _dividendHistory[_dividendHistory.length-1].recordDate : openDate;
        readyDividend.recordDate = block.timestamp;
        readyDividend.totalShare = totalShare;

        emit SetDividend(
            _dividendHistory.length,
            readyDividend.startDate,
            readyDividend.recordDate,
            readyDividend.totalShare
        );
    }

    /**
     * @notice 배당 기준시각 파기하기
     */
    function resetDividendRecordDate() external onlyRole(MANAGER_ROLE) {
        require(readyDividend.recordDate != 0, "NOT SET");

        for (uint256 i = 0; i < readyDividend.tokens.length; i++) {
            address token = readyDividend.tokens[i];
            uint256 amount = readyDividend.amounts[i];
            // @dev get the deposited dividend back
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        delete readyDividend;

        emit ResetDividend(_dividendHistory.length);
    }

    /**
     * @notice 배당금 납입하기
     */
    function depositDividend(
        address token,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) {
        require(readyDividend.recordDate != 0, "NOT SET");
        require(amount > 0, "NOT ZERO");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // @dev 배당 토큰 수는 1~2개로 이루어짐. 순회 구문으로도 gas efficient함
        for (uint256 i = 0; i < readyDividend.tokens.length; i++) {
            address _token = readyDividend.tokens[i];
            if (_token != token) continue;

            // @dev 이미 납입된 토큰이라면, 추가하지 않고, readyDividend에 추가한다
            readyDividend.amounts[i] += amount;
            emit DepositDividend(_dividendHistory.length, token, amount);
            return;
        }

        // @dev 이미 납입되지 않은 토큰은 추가한다
        readyDividend.tokens.push(token);
        readyDividend.amounts.push(amount);

        emit DepositDividend(_dividendHistory.length, token, amount);
    }

    /**
     * @notice 배당 집행하기
     */
    function executeDividend() external onlyRole(MANAGER_ROLE) {
        require(readyDividend.recordDate != 0, "NOT SET");
        require(readyDividend.tokens.length > 0, "NO DEPOSIT");
        _updateGrowthGlobal();

        _dividendHistory.push(
            Dividend(
                readyDividend.startDate,
                readyDividend.recordDate,
                readyDividend.totalShare,
                readyDividend.tokens,
                readyDividend.amounts
            )
        );

        totalShare -= readyDividend.totalShare;
        delete readyDividend;

        emit ExecuteDividend(
            _dividendHistory.length - 1,
            readyDividend.tokens,
            readyDividend.amounts
        );
    }

    /**
     * @notice Sets period until un-staking requested amount is able to be withdrawn.
     */
    function setCooldownPeriod(uint256 period) external onlyRole(MANAGER_ROLE) {
        uint256 prev = cooldownPeriod;
        cooldownPeriod = period;

        emit UpdateCoolDown(prev, period);
    }

    /**
     * @notice calculate the balance staked by owner
     */
    function balanceOf(address owner) external view returns (uint256 amount) {
        return _balanceOf[owner];
    }

    /**
     * @notice total stone staked
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Get the information of un-staking requests by owner
     */
    function unstakingRequestByIndex(address owner, uint256 index) external view returns (UnstakingRequest memory) {
        uint256 requestId = _ownedRequests[owner][index];
        return unstakingRequests[requestId];
    }

    /**
     * @notice 집행된 배당 횟수
     */
    function totalDividendEpoch() external view returns (uint256) {
        return _dividendHistory.length;
    }

    /**
     * @notice 배당 예정 정보
     */
    function readyDividendInfo() external view returns (Dividend memory) {
        return readyDividend;
    }

    /**
     * @notice 배당금 정보
     */
    function dividendInfo(uint256 epoch) external view returns (Dividend memory) {
        return _dividendHistory[epoch];
    }

    /**
     * @notice Stakes Stone for msg.sender
     */
    function stake(uint256 amount) external updateUserSnapshot(msg.sender) {
        require(block.timestamp >= openDate, "NOT START");
        IERC20(stone).safeTransferFrom(msg.sender, address(this), amount);

        _stake(msg.sender, amount);
    }

    function _stake(address owner, uint256 amount) internal {
        _balanceOf[owner] += amount;
        _totalSupply += amount;

        emit Stake(owner, amount);
    }

    /**
     * @notice request unstaking to msg.sender
     */
    function unstake(uint256 amount) external updateUserSnapshot(msg.sender) {
        _balanceOf[msg.sender] -= amount;
        _totalSupply -= amount;

        uint256 requestId = unstakingRequests.length;
        unstakingRequests.push(UnstakingRequest(requestId, amount, block.timestamp, false));

        uint256 count = unstakingRequestCounts[msg.sender]++;

        requestOwnerOf[requestId] = msg.sender;
        _ownedRequests[msg.sender][count] = requestId;
        _ownedRequestsIndex[requestId] = count;

        emit Unstake(msg.sender, amount, requestId);
    }

    /**
     * @notice withdraw unstaked Stone after cooldown
     */
    function withdraw(uint256 requestId) external returns (uint256 amount) {
        UnstakingRequest memory request = unstakingRequests[requestId];
        require(!request.isClaimed, "ALREADY CLAIMED");
        require(requestOwnerOf[requestId] == msg.sender, "NOT OWNER");
        require(request.requestTs + cooldownPeriod <= block.timestamp, "NEED COOLDOWN");
        amount = request.amount;

        IERC20(stone).safeTransfer(msg.sender, amount);

        closeRequest(msg.sender, requestId);

        emit Withdraw(msg.sender, amount);
    }

    function closeRequest(address owner, uint256 requestId) internal {
        unstakingRequests[requestId].isClaimed = true;

        // @dev ownedRequests에서 requestId 제거
        uint256 lastRequestIndex = --unstakingRequestCounts[owner];
        uint256 requestIndex = _ownedRequestsIndex[requestId];

        if (requestIndex != lastRequestIndex) {
            uint256 lastRequestId = _ownedRequests[owner][lastRequestIndex];

            _ownedRequests[owner][requestIndex] = lastRequestId;
            _ownedRequestsIndex[lastRequestId] = requestIndex;
        }

        delete _ownedRequestsIndex[requestIndex];
        delete _ownedRequests[owner][lastRequestIndex];
    }

    /**
     * @notice Re-stake claimable Stone
     */
    function reStake() external updateUserSnapshot(msg.sender) {
        uint256 amount = _claimReward(msg.sender);
        _stake(msg.sender, amount);
    }

    /**
     * @notice claim allocated STONE reward
     */
    function claimReward() external updateUserSnapshot(msg.sender) returns (uint256 amount) {
        amount = _claimReward(msg.sender);
        IERC20(stone).safeTransfer(msg.sender, amount);
    }

    function _claimReward(address owner) internal returns (uint256 amount){
        amount = _userRewardSnapshot[owner]._owed;
        _userRewardSnapshot[owner]._owed = 0;
        accumulativeUserReward[msg.sender] += amount;

        emit Claim(msg.sender, amount);
    }

    /**
     * @notice calculate claimable STONE reward
     */
    function claimableReward(address owner) external view returns (uint256) {
        uint256 amount = _calculateRewardToDistribute() + pendingReward;
        RewardSnapshot memory snapshot = _userRewardSnapshot[owner];

        return FullMath.mulDiv(
            _rewardGrowthGlobal(amount) - snapshot._growthGlobalLast, _balanceOf[owner], FixedPoint.Q96
        ) + snapshot._owed;
    }

    /**
     * @notice 배당금 수령하기
     */
    function claimDividend(uint256 epoch) external updateUserSnapshot(msg.sender) {
        DividendSnapshot memory snapshot = _userDividendSnapshot[msg.sender][epoch];
        require(!snapshot.isPaid, "ALREADY PAID");
        require(snapshot.share > 0, "NO SHARE");

        Dividend memory epochDividend = _dividendHistory[epoch];
        uint256 epochTotalShare = epochDividend.totalShare;

        for (uint256 i = 0; i < epochDividend.tokens.length; i++) {
            address token = epochDividend.tokens[i];
            uint256 amount = epochDividend.amounts[i];

            uint256 userAmount = FullMath.mulDiv(
                amount, snapshot.share, epochTotalShare
            );

            IERC20(token).safeTransfer(msg.sender, userAmount);

            emit ClaimDividend(msg.sender, epoch, token, userAmount);
        }

        _userDividendSnapshot[msg.sender][epoch].isPaid = true;
    }

    /**
     * @notice 주어진 배당 회차에 할당된 배당금액 계산
     */
    function allocatedDividend(address owner, uint256 epoch) external view returns (
        bool isPaid,
        address[] memory tokens,
        uint256[] memory amounts
    ) {
        Dividend memory epochDividend = _dividendHistory[epoch];

        tokens = epochDividend.tokens;
        amounts = new uint256[](epochDividend.tokens.length);

        isPaid = _userDividendSnapshot[owner][epoch].isPaid;

        uint256 share = _calculateUserShare(owner, epoch, epochDividend);
        if (share == 0) return (isPaid, tokens, amounts);

        uint256 epochTotalShare = epochDividend.totalShare;
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = FullMath.mulDiv(
                epochDividend.amounts[i],
                share,
                epochTotalShare
            );
        }
    }

    function _updateGrowthGlobal() internal returns (uint256 growthGlobal) {
        uint256 _checkpoint = checkpoint;
        uint256 amount = _calculateRewardToDistribute();

        amount = _updatePendingReward(amount);
        growthGlobal = _rewardGrowthGlobal(amount);
        rewardGrowthGlobalLast = growthGlobal;

        // @dev Skip if the block has been updated in advance. (gas efficient policy)
        if (_checkpoint >= block.timestamp) return growthGlobal;

        totalShare += (block.timestamp - _checkpoint) * _totalSupply;
        checkpoint = block.timestamp;
    }

    function _calculateUserShare(
        address owner,
        uint256 epoch,
        Dividend memory epochDividend
    ) private view returns (uint256 share) {
        // first case, already settle
        share = _userDividendSnapshot[owner][epoch].share;
        if (share > 0) return share;

        // if there is no balance, skip
        uint256 balance = _balanceOf[owner];
        if (balance == 0) return share;

        // calculate previous user share
        uint256 startDate = Math.max(_userLastRecordDate[owner], epochDividend.startDate);
        if (epochDividend.recordDate <= startDate) return share;

        return (epochDividend.recordDate - startDate) * balance;
    }

    function _updatePendingReward(uint256 amount) internal returns (uint256) {
        if (_totalSupply == 0) {
            // @dev Rewards accumulated while there is no staked supply
            // are distributed later
            pendingReward += amount;
            return 0;
        }

        if (pendingReward > 0) {
            // @dev add pendingReward if it remains
            amount += pendingReward;
            pendingReward = 0;
        }

        return amount;
    }

    function _updateDividendSnapshot(address owner) internal {
        _updateUserShare(owner);
        _userLastRecordDate[owner] = block.timestamp;
    }

    function _updateUserShare(address owner) internal {
        uint256 balance = _balanceOf[owner];

        // @dev skip to update user share
        if (balance == 0) return;

        uint256 lastRecordDate = _userLastRecordDate[owner];

        // @dev there is no previous dividend
        if (_dividendHistory.length == 0) {
            _userDividendSnapshot[owner][0].share += (block.timestamp - lastRecordDate) * balance;
            return;
        }

        uint256 index = _dividendHistory.length - 1;
        Dividend memory dividend = _dividendHistory[index];

        uint256 period = block.timestamp - Math.max(dividend.recordDate, lastRecordDate);
        _userDividendSnapshot[owner][index+1].share += period * balance;

        while (dividend.recordDate > lastRecordDate) {
            period = dividend.recordDate - Math.max(dividend.startDate, lastRecordDate);
            _userDividendSnapshot[owner][index].share += period * balance;

            if (index == 0) break;

            dividend = _dividendHistory[--index];
        }
    }

    function _updateRewardSnapshot(address owner, uint256 growthGlobal) internal {
        RewardSnapshot storage snapshot = _userRewardSnapshot[owner];
        snapshot._owed += FullMath.mulDiv(
            growthGlobal - snapshot._growthGlobalLast, _balanceOf[owner], FixedPoint.Q96
        );
        snapshot._growthGlobalLast = growthGlobal;
    }

    function _rewardGrowthGlobal(uint256 amount) private view returns (uint256 growthGlobal) {
        growthGlobal = rewardGrowthGlobalLast;

        if (amount > 0 && _totalSupply > 0) {
            growthGlobal += FullMath.mulDiv(amount, FixedPoint.Q96, _totalSupply);
        }
    }

    function _calculateRewardToDistribute() private view returns (uint256 amount) {
        uint256 _checkpoint = checkpoint;
        uint256 currentEpoch = (block.timestamp / 7 days) * 7 days;

        // @dev 과거 미정산된 Reward 정산
        if (_checkpoint < currentEpoch) {
            uint256 _checkpointEpoch = (_checkpoint / 7 days) * 7 days;

            for (uint256 _epoch = _checkpointEpoch; _epoch < currentEpoch; _epoch += 7 days) {
                uint256 _nextEpoch = _epoch + 7 days;
                amount += totalRewardPerWeek[_epoch] * (_nextEpoch - _checkpoint) / 7 days;
                _checkpoint = _nextEpoch;
            }
        }

        amount += (
        totalRewardPerWeek[currentEpoch] * (block.timestamp - _checkpoint) / 7 days
        );
    }
}

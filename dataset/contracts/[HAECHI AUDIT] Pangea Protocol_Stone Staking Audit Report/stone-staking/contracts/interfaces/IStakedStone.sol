// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

interface IStakedStoneStruct {
    struct UnstakingRequest {
        uint256 id;
        uint256 amount;
        uint256 requestTs;
        bool isClaimed;
    }

    struct RewardSnapshot {
        uint256 _growthGlobalLast;
        uint256 _owed;
    }

    struct Dividend {
        // @dev 배당금 분배 시작 시각
        uint256 startDate;
        // @dev 배당금 분배 마감 시각
        uint256 recordDate;
        // @dev 총 배당금 지분 크기 ( period * total Supply)
        uint256 totalShare;
        // @dev 지급된 배당금 토큰
        address[] tokens;
        // @dev 지급된 배당액
        uint256[] amounts;
    }

    struct DividendSnapshot {
        // @dev 지급 여부
        bool isPaid;
        // @dev 할당된 배당 비중
        uint256 share;
    }
}

interface IStakedStoneEvent {
    event Stake(address indexed owner, uint256 amount);

    event Unstake(address indexed owner, uint256 amount, uint256 requestId);

    event Withdraw(address indexed owner, uint256 amount);

    event Claim(address indexed owner, uint256 amount);

    event UpdateCoolDown(uint256 prev, uint256 curr);

    event DepositReward(address indexed operator, uint256 indexed weekStartTime, uint256 amount);

    event CancelReward(address indexed operator, uint256 indexed weekStartTime, uint256 amount);

    event ClaimDividend(address indexed owner, uint256 indexed epoch, address token, uint256 amount);

    event SetDividend(uint256 indexed dividendId, uint256 startTime, uint256 recordDate, uint256 totalShare);

    event ResetDividend(uint256 indexed dividendId);

    event DepositDividend(uint256 indexed dividendId, address token, uint256 amount);

    event ExecuteDividend(uint256 indexed dividendId, address[] token, uint256[] amount);
}

interface IStakedStone is IStakedStoneStruct, IStakedStoneEvent {
    function balanceOf(address owner) external view returns (uint256 amount);

    function totalSupply() external view returns (uint256);

    function unstakingRequestCounts(address owner) external view returns (uint256);

    function unstakingRequestByIndex(address owner, uint256 index) external view returns (UnstakingRequest memory);

    function accumulativeUserReward(address owner) external view returns (uint256);

    /**
     * @notice 이때까지 총 배당 횟수
     */
    function totalDividendEpoch() external view returns (uint256);

    /**
     * @notice 해당 epoch에 배치된 배당금 조회
     */
    function dividendInfo(uint256 epoch) external view returns (Dividend memory);

    /**
     * @notice 예치 요청하기
     */
    function stake(uint256 amount) external;

    /**
     * @notice unstake 요청하기, cooldown 이후에 withdraw 가능
     */
    function unstake(uint256 amount) external;

    /**
     * @notice cooldown period가 지난 unstaking 요청에 대한 stone 인출하기
     */
    function withdraw(uint256 requestId) external returns (uint256);

    /**
     * @notice 리워드(스톤) 재예치하기
     */
    function reStake() external;

    /**
     * @notice 리워드(스톤) 수령하기
     */
    function claimReward() external returns (uint256);

    /**
     * @notice calculate claimable STONE reward
     */
    function claimableReward(address owner) external view returns (uint256);

    /**
     * @notice 배당금 수령
     */
    function claimDividend(uint256 epoch) external;

    /**
     * @notice 해당 epoch에 할당된 dividend 조회
     */
    function allocatedDividend(
        address owner,
        uint256 epoch
    ) external view returns (bool isPaid, address[] memory tokens, uint256[] memory amounts);
}

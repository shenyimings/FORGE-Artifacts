// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface ISingleStake {
    function getUserStats(
        address _user
    )
        external
        view
        returns (
            uint256[] memory activeStakesIDs,
            uint256[] memory endedStakesIDs,
            uint256 claimed,
            uint256 staked,
            uint256 lastDepositTime,
            uint256 lastClaimTime,
            uint256 lastWithdrawTime,
            uint256 totalHeartBeat
        );
}

contract RegisterForWhitelist {
    mapping(address => uint256) public userHeartBeatRegistered;
    uint256 public totalHeartBeatRegistered;
    uint256 public usersRegistered;
    address[] public registeredIndex;
    uint256 public startTime = 1692898111;
    uint256 public endTime = 1693094400;
    address public admin;
    address constant SINGLE_STAKE_ADDRESS =
        0x94dF7470c5516442dfCFE0925Ec0EEd1ffA08d28;

    event Registered(address user, uint256 heartBeats, uint256 index);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier registerRequirements() {
        ISingleStake singleStake = ISingleStake(SINGLE_STAKE_ADDRESS);
        (, , , , , , , uint256 totalHeartBeat) = singleStake.getUserStats(
            msg.sender
        );
        require(startTime < block.timestamp, "Not started yet");
        require(endTime > block.timestamp, "Registering has ended");
        require(totalHeartBeat > 0, "totalHeartBeat must be greater than 0");
        require(userHeartBeatRegistered[msg.sender] == 0, "already registered");
        _;
    }

    function setTime(uint256 _startTime, uint256 _endTime) external onlyAdmin {
        endTime = _endTime;
        startTime = _startTime;
    }

    function register() external registerRequirements {
        ISingleStake singleStake = ISingleStake(SINGLE_STAKE_ADDRESS);
        (, , , , , , , uint256 totalHeartBeat) = singleStake.getUserStats(
            msg.sender
        );
        userHeartBeatRegistered[msg.sender] = totalHeartBeat;
        registeredIndex.push(msg.sender);
        usersRegistered++;
        totalHeartBeatRegistered = totalHeartBeat + totalHeartBeatRegistered;
        emit Registered(msg.sender, totalHeartBeat, usersRegistered - 1);
    }

    function fetchUserStats(
        address user
    )
        external
        view
        returns (
            uint256[] memory activeStakesIDs,
            uint256[] memory endedStakesIDs,
            uint256 claimed,
            uint256 staked,
            uint256 lastDepositTime,
            uint256 lastClaimTime,
            uint256 lastWithdrawTime,
            uint256 totalHeartBeat
        )
    {
        ISingleStake singleStake = ISingleStake(SINGLE_STAKE_ADDRESS);
        return singleStake.getUserStats(user);
    }

    receive() external payable {}
}

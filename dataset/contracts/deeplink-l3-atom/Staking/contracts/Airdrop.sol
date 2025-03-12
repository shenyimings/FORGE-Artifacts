pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Interface/IDeepToken.sol";
import "./Interface/IDKeeperEscrow.sol";

contract AirDrop is Ownable {
    // Info of each user.
    struct UserInfo {
        uint256 alloc;
        uint256 rewardDebt;
        uint256 lastClaimTime;
    }

    // DeepToken contract
    IDeepToken public deepToken;

    // DKeeper Escrow contract
    IDKeeperEscrow public dKeeperEscrow;

    // Timestamp of last reward
    uint256 public lastRewardTime;

    // Accumulated token per share
    uint256 public accTokenPerShare;

    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block number when Deep distribution starts.
    uint256 public startTime;

    // The block number when Deep distribution ends.
    uint256 public endTime;

    uint256 public constant WEEK = 3600 * 24 * 7;

    event Claimed(address indexed user, uint256 amount);

    constructor(
        IDeepToken _deep,
        uint256 _startTime,
        uint256 _endTime
    ) public {
        require(_endTime >= _startTime && block.timestamp <= _startTime, "Invalid timestamp");
        deepToken = _deep;
        startTime = _startTime;
        endTime = _endTime;

        totalAllocPoint = 0;
        lastRewardTime = _startTime;
    }

    // View function to see pending Deeps on frontend.
    function pendingDeep(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];

        uint256 updatedAccTokenPerShare = accTokenPerShare;
        if (block.timestamp > lastRewardTime && totalAllocPoint != 0) {
            uint256 rewards = getRewards(lastRewardTime, block.timestamp);
            updatedAccTokenPerShare += ((rewards * 1e6) / totalAllocPoint);
        }

        return (user.alloc * updatedAccTokenPerShare) / 1e6 - user.rewardDebt;
    }

    // Update reward variables to be up-to-date.
    function updatePool() public {
        if (block.timestamp <= lastRewardTime || lastRewardTime >= endTime) {
            return;
        }
        if (totalAllocPoint == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 rewards = getRewards(lastRewardTime, block.timestamp);

        accTokenPerShare = accTokenPerShare + ((rewards * 1e6) / totalAllocPoint);
        lastRewardTime = block.timestamp;
    }

    // Claim rewards.
    function claim() public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.alloc != 0, "Not allocated with this account.");
        updatePool();

        uint256 pending = (user.alloc * accTokenPerShare) / 1e6 - user.rewardDebt;
        if (pending > 0) {
            safeDeepTransfer(msg.sender, pending);
            user.lastClaimTime = block.timestamp;
            emit Claimed(msg.sender, pending);
        }

        user.rewardDebt = (user.alloc * accTokenPerShare) / 1e6;
    }

    // Safe DEEP transfer function, just in case if rounding error causes pool to not have enough DEEP
    function safeDeepTransfer(address _to, uint256 _amount) internal {
        dKeeperEscrow.mint(_to, _amount);
    }

    // Get rewards between block timestamps
    function getRewards(uint256 _from, uint256 _to) internal view returns (uint256 rewards) {
        while (_from + WEEK <= _to) {
            rewards += getRewardRatio(_from) * WEEK;
            _from = _from + WEEK;
        }

        if (_from + WEEK > _to) {
            rewards += getRewardRatio(_from) * (_to - _from);
        }
    }

    // Get rewardRatio from timestamp
    function getRewardRatio(uint256 _time) internal view returns (uint256) {
        if (8 < (_time - startTime) / WEEK) return 0;

        return (((2e24 * (8 - (_time - startTime) / WEEK)) / 8 / 35) * 10) / WEEK;
    }

    ///////////////////////
    /// Owner Functions ///
    ///////////////////////
    function addAirdropWallets(address[] memory _accounts, uint256[] memory _allocs)
        external
        onlyOwner
    {
        require(_accounts.length == _allocs.length && _allocs.length != 0, "Invalid array length");

        for (uint8 i = 0; i < _allocs.length; i++) {
            require(_accounts[i] != address(0), "Invalid address");
            require(_allocs[i] != 0 && _allocs[i] <= 10, "Invalid allocation number");
            require(userInfo[_accounts[i]].alloc == 0, "Already added");

            userInfo[_accounts[i]] = UserInfo(_allocs[i], 0, 0);
            totalAllocPoint += _allocs[i];
        }
    }

    function removeAirdropWallets(address[] memory _accounts) external onlyOwner {
        require(_accounts.length != 0, "Invalid array length");

        for (uint8 i = 0; i < _accounts.length; i++) {
            require(_accounts[i] != address(0), "Invalid address");
            require(userInfo[_accounts[i]].alloc != 0, "Not added to airdrop list");

            totalAllocPoint -= userInfo[_accounts[i]].alloc;

            delete userInfo[_accounts[i]];
        }
    }

    function setEscrow(address _escrow) public onlyOwner {
        require(_escrow != address(0), "Invalid address");
        dKeeperEscrow = IDKeeperEscrow(_escrow);
    }
}

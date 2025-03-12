// SPDX-License-Identifier: proprietary
pragma solidity 0.8.19;

//import "hardhat/console.sol";
import "./external/IERC20.sol";
import "./external/SafeOwn.sol";
import "./external/ISelfkeyIdAuthorization.sol";

struct StakingTimeLock {
    uint256 timestamp;
    uint amount;
}

contract SelfkeyStaking is SafeOwn {
    event StakeAdded(address  _account, uint _amount);
    event StakeWithdraw(address  _account, uint _amount);
    event RewardsMinted(address  _account, uint _amount);

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;
    ISelfkeyIdAuthorization public authorizationContract;
    address public immutable rewardsTokenAddress;

    address public owner;

    uint public minStakeAmount;
    uint public minWithdrawAmount;
    uint public timeLockDuration;

    // Duration of rewards to be paid out (in seconds)
    uint public duration;
    // Timestamp of when the rewards finish
    uint public finishAt;
    // Minimum of last updated time and reward finish time
    uint public updatedAt;
    // Reward to be paid out per second
    uint public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;

    mapping(address => StakingTimeLock[]) private _timeLockEntries;

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(address _stakingToken, address _rewardToken, address _authorizationContract) SafeOwn(14400) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
        authorizationContract = ISelfkeyIdAuthorization(_authorizationContract);
        rewardsTokenAddress = _rewardToken;

        minStakeAmount = 0;
        minWithdrawAmount = 0;
        timeLockDuration = 0;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    function setMinStakeAmount(uint _amount) external onlyOwner {
        require(_amount > 0, "Invalid amount");
        minStakeAmount = _amount;
    }

    function setMinWithdrawAmount(uint _amount) external onlyOwner {
        require(_amount > 0, "Invalid amount");
        minWithdrawAmount = _amount;
    }

    function setTimeLockDuration(uint _duration) external onlyOwner {
        timeLockDuration = _duration;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    // Stake KEY
    function stake(address _account, uint256 _amount, bytes32 _param, uint _timestamp, address _signer,bytes memory signature) external updateReward(_account) {
        authorizationContract.authorize(address(this), _account, _amount, 'mint:lock:staking', _param, _timestamp, _signer, signature);
        require(_amount > 0, "Amount is invalid");
        require(_amount >= minStakeAmount, "Amount is below minimum");
        require(stakingToken.balanceOf(_account) >= _amount, "Not enough funds");

        stakingToken.transferFrom(_account, address(this), _amount);
        balanceOf[_account] += _amount;
        totalSupply += _amount;

        _timeLockEntries[_account].push(StakingTimeLock(block.timestamp + timeLockDuration, _amount));

        emit StakeAdded(_account, _amount);
    }

    // Withdraw Stake KEY
    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "Amount = 0");
        require(_amount >= minWithdrawAmount, "Amount is below minimum");
        require(_amount <= balanceOf[msg.sender], "Not enough funds");
        require(_amount <= availableOf(msg.sender), "Not enough funds available");

        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);

        emit StakeWithdraw(msg.sender, _amount);
    }

    function earned(address _account) public view returns (uint) {
        return ((balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) + rewards[_account];
    }

    function availableOf(address _account) public view returns(uint) {
        uint _available = 0;
        uint _balance = balanceOf[_account];
        StakingTimeLock[] memory _accountRecords = _timeLockEntries[_account];
        for(uint i=0; i<_accountRecords.length; i++) {
            StakingTimeLock memory _record = _accountRecords[i];
            if (_record.timestamp < block.timestamp) {
                _available = _available + _record.amount;
            }
        }
        return _available < _balance ? _available : _balance;
    }

    function notifyRewardMinted(address _account, uint _amount) external updateReward(_account) {
        require(msg.sender == rewardsTokenAddress, "Invalid");
        uint reward = rewards[_account];
        if (reward > 0 && _amount > 0) {
            rewards[_account] = reward - _amount;
            emit RewardsMinted(_account, _amount);
        }
    }

    /*
    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }
    */

    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmount(uint _amount) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        // require(rewardRate * duration <= rewardsToken.balanceOf(address(this)), "reward amount > balance");

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}


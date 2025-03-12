pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/INFT.sol";

contract Owned {
    address public owner;
    address public nominatedOwner;

    constructor(address _owner) public {
        require(_owner != address(0), "Owner address cannot be 0");
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the contract owner may perform this action");
        _;
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}

abstract contract RewardsDistributionRecipient is Owned {
    address public rewardsDistribution;

    function notifyRewardAmount(uint256 reward) virtual external;

    modifier onlyRewardsDistribution() {
        require(msg.sender == rewardsDistribution, "Caller is not RewardsDistribution contract");
        _;
    }

    function setRewardsDistribution(address _rewardsDistribution) external onlyOwner {
        rewardsDistribution = _rewardsDistribution;
    }
}


contract TokenWrapper is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public stakingToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(address _stakingToken) public {
        stakingToken = IERC20(_stakingToken);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stakePoolFor(uint256 amount, address forAddress) internal nonReentrant {
        _totalSupply = _totalSupply.add(amount);
        _balances[forAddress] = _balances[forAddress].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdrawPool(uint256 amount) internal nonReentrant {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
    }
}


contract Stake is TokenWrapper, RewardsDistributionRecipient {
    // Stake program
    IERC20  public rewardsToken;
    uint256 public DURATION;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public antiDumpingDelay;

    // NFT program
    INFT public NFT;
    uint256 public maxAmountNFTForClaim;
    uint256 public totalClaimedNFT;
    uint256 public nftPrice;
    address public nftETHReceiver;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => bool) public claimedNFT;
    mapping(address => bool) public participantOfStake;
    mapping(address => uint256) public startedStake;
    mapping(address => bool) public whiteList;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address _owner,
        address _rewardsToken,
        address _stakingToken,
        address _NFT,
        uint256 _DURATION,
        uint256 _maxAmountNFTForClaim,
        uint256 _nftPrice,
        address _nftETHReceiver,
        uint256 _antiDumpingDelay
    )
    public TokenWrapper(_stakingToken) Owned(_owner) {
        rewardsToken = IERC20(_rewardsToken);
        NFT = INFT(_NFT);
        DURATION = _DURATION;
        maxAmountNFTForClaim = _maxAmountNFTForClaim;
        nftPrice = _nftPrice;
        nftETHReceiver = _nftETHReceiver;
        antiDumpingDelay = _antiDumpingDelay;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function earnedByShare(uint256 share) public view returns (uint256) {
        return share.mul(rewardPerToken()).div(1e18);
    }

    function stake(uint256 amount) public updateReward(msg.sender) {
        stakeFor(amount, msg.sender);
    }

    function stakeFor(uint256 amount, address forAddress) public updateReward(forAddress) {
        // allow stake only for white list
        require(whiteList[msg.sender], "Not in white list");
        require(amount > 0, "Cannot stake 0");
        super.stakePoolFor(amount, forAddress);

        if(!participantOfStake[forAddress]){
          startedStake[forAddress] = now;
          participantOfStake[forAddress] = true;
        }

        emit Staked(forAddress, amount);
    }

    // withdraw underlying
    function withdraw(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(balanceOf(msg.sender) >= amount, "Input more than balance");
        super.withdrawPool(amount);
        emit Withdrawn(msg.sender, amount);
    }

    // withdraw underlying + claim rewards
    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    // claim rewards
    function getReward() public updateReward(msg.sender) {
        require(now > startedStake[msg.sender] + antiDumpingDelay, "Anti dumping delay");
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward) override external onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(DURATION);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(DURATION);
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(DURATION);
        emit RewardAdded(reward);
    }

  
    function updateWhiteList(address _address, bool _status) external onlyOwner {
      whiteList[_address] = _status;
    }


    function updateAntiDumpingDelay(uint256 _antiDumpingDelay) external onlyOwner {
      antiDumpingDelay = _antiDumpingDelay;
    }

    // NFT Progarm

    function claimNFT(uint256 _nftIndex) external {
      require(participantOfStake[msg.sender], "Not participant");
      require(!claimedNFT[msg.sender], "Alredy claimed");
      require(!NFT.isIndexUsed(_nftIndex), "Index used");
      require(totalClaimedNFT <= maxAmountNFTForClaim, "Claim finished");

      NFT.createNewFor(msg.sender, _nftIndex);
      claimedNFT[msg.sender] = true;
      totalClaimedNFT = totalClaimedNFT + 1;
    }

    function buyNFT(uint256 _nftIndex) external payable {
      require(msg.value == nftPrice, "Influence ETH");
      require(!NFT.isIndexUsed(_nftIndex), "Index used");
      NFT.createNewFor(msg.sender, _nftIndex);
      payable(nftETHReceiver).transfer(msg.value);
    }
}

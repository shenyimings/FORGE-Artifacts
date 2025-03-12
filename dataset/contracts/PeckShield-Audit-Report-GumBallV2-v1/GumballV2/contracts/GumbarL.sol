// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

library Math {

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract Owned {
    address public owner;
    address public nominatedOwner;

    constructor(address _owner) {
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
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}

interface IERC20BondingCurve {
    function mustStayGBT(address account) external view returns (uint256);
}

contract GumbarL is ReentrancyGuard, Owned {
    using SafeERC20 for IERC20;

    uint256 public constant DURATION = 7 days;

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        address rewardsDistributor;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    IERC20 public stakingToken;
    IERC721 public stakingNFT;
    address public factory;
    mapping(address => Reward) public rewardData;
    mapping(address => bool) public isRewardToken;
    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    mapping(address => uint256) public balanceToken; // Accounts deposited GBTs
    mapping(address => uint256[]) public balanceNFT; // Accounts deposited NFTs

    uint256 public _totalToken;
    uint256 public _totalNFT;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _owner,
        address _stakingToken,
        address _stakingNFT,
        address _baseToken
    ) Owned(_owner) {
        stakingToken = IERC20(_stakingToken);
        stakingNFT = IERC721(_stakingNFT);
        factory = msg.sender;
        addReward(_stakingToken, _stakingToken);
        addReward(_baseToken, _stakingToken);
    }

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor
    )
        public
    {
        require((msg.sender == owner),"addReward: permission is denied!");
        require(!isRewardToken[_rewardsToken], "Reward token already exists");
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        isRewardToken[_rewardsToken] = true;

        emit RewardAdded(_rewardsToken, _rewardsDistributor);
    } 

    /* ========== VIEWS ========== */

    function balanceOfNFT(address user) external view returns (uint256 length, uint256[] memory arr) {
        return (balanceNFT[user].length, balanceNFT[user]);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(address _rewardsToken) public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return
            rewardData[_rewardsToken].rewardPerTokenStored + ((lastTimeRewardApplicable(_rewardsToken) - rewardData[_rewardsToken].lastUpdateTime) * rewardData[_rewardsToken].rewardRate * 1e18 / _totalSupply);
    }

    function earned(address account, address _rewardsToken) public view returns (uint256) {
        return (_balances[account] * (rewardPerToken(_rewardsToken) - userRewardPerTokenPaid[account][_rewardsToken]) / 1e18) + rewards[account][_rewardsToken];
    }

    function getRewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate * DURATION;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) public view returns (bytes4) {
        return IERC721Receiver(address(this)).onERC721Received.selector;
    }

    function depositToken(uint256 amount) external nonReentrant updateReward(msg.sender) {
        address account = msg.sender;
        require(amount > 0, "Cannot deposit 0");
        _totalToken += amount;
        _totalSupply = _totalSupply + amount;
        balanceToken[account] = balanceToken[account] + amount;
        _balances[account] = _balances[account] + amount;
        stakingToken.safeTransferFrom(account, address(this), amount);
        emit Deposited(account, amount);
    }

    function withdrawToken(uint256 amount) public nonReentrant updateReward(msg.sender) {
        address account = msg.sender;
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= balanceToken[account], "Insufficient balance"); 
        _totalToken -= amount;
        _totalSupply = _totalSupply - amount;
        balanceToken[account] = balanceToken[account] - amount;
        _balances[account] = _balances[account] - amount;
        require(_balances[account] >= IERC20BondingCurve(address(stakingToken)).mustStayGBT(account), "Borrow debt");
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(account, amount);
    }

        /** @dev Stake Gumball(s) NFTs to receive rewards
      * @param _id is an array of Gumballs desired for staking
    */
    function depositNFT(uint256[] memory _id) external nonReentrant updateReward(msg.sender) {
        address account = msg.sender;
        require(_id.length > 0, "Cannot deposit 0");
        uint256 amount = _id.length * 1e18;
        _totalNFT += amount;
        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;

        for (uint256 i = 0; i < _id.length; i++) {
            balanceNFT[account].push(_id[i]);
            IERC721(stakingNFT).transferFrom(account, address(this), _id[i]);
        }

        emit DepositNFT(msg.sender, address(stakingNFT), _id);
    }

    /** @dev Remove Gumball(s) from the contract and leave staking
      * @param _id is an array of Gumballs desired for unstaking
    */
    function withdrawNFT(uint256[] memory _id) external nonReentrant updateReward(msg.sender) {
        address account = msg.sender;
        require(balanceNFT[account].length >= _id.length, "Withdrawal underflow");
        uint256 amount = _id.length * 1e18;

        for (uint256 i = 0; i < _id.length; i++) {
            uint256 ind = findNFT(account, _id[i]);
            _pop(account, ind);
        }

        _totalNFT -= amount;
        _totalSupply = _totalSupply - amount;
        _balances[account] = _balances[account] - amount;
        require(_balances[account] >= IERC20BondingCurve(address(stakingToken)).mustStayGBT(account), "Borrow debt");

        for (uint256 i = 0; i <_id.length; i++) {
            IERC721(stakingNFT).transferFrom(address(this), account, _id[i]);
        }

        emit WithdrawNFT(msg.sender, address(stakingNFT), _id);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        for (uint i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
        require(IERC20(stakingToken).balanceOf(address(this)) >= _totalToken);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(address _rewardsToken, uint256 reward) external updateReward(address(0)) {
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        require(reward > DURATION);
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward / DURATION;
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardData[_rewardsToken].rewardRate;
            require(reward > leftover, "reward amount should be greater than leftover amount"); // to stop griefing attack
            rewardData[_rewardsToken].rewardRate = (reward + leftover) / DURATION;
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp + DURATION;
        emit RewardNotified(reward);
    }

    function setRewardsDistributor(address _rewardsToken, address _rewardsDistributor) external onlyOwner {
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        emit DistributorSet(_rewardsToken, _rewardsDistributor);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /** @dev Locates gumball in an array */
    function findNFT(address user, uint256 _id) internal view returns (uint256 _index) {

        uint256 index;
        bool found = false;
        
        for (uint256 i = 0; i < balanceNFT[user].length; i++) {
            if (balanceNFT[user][i] == _id) {
                index = i;
                found = true;
                break;
            } 
        }

        if (!found) {
            revert ("!Found");
        } else {
            return index;
        }
    }

    /** @dev Removes an index from an array */
    function _pop(address user, uint256 _index) internal {
        uint256 tempID;
        uint256 swapID;

        tempID = balanceNFT[user][_index];
        swapID = balanceNFT[user][balanceNFT[user].length - 1];
        balanceNFT[user][_index] = swapID;
        balanceNFT[user][balanceNFT[user].length - 1] = tempID;

        balanceNFT[user].pop();
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        for (uint i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
            }
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardNotified(uint256 reward);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event DepositNFT(address indexed user, address colleciton, uint256[] id);
    event WithdrawNFT(address indexed user, address collection, uint256[] id);
    event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event RewardAdded(address reward, address distributor);
    event DistributorSet(address reward, address distributor);
}
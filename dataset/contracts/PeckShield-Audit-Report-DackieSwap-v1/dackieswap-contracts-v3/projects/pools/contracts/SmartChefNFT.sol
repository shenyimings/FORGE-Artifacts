// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract SmartChefNFT is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    // The address of the smart chef factory
    address public SMART_CHEF_FACTORY;

    // Whether it is initialized
    bool public isInitialized;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The block timestamp when DACKIE mining ends
    uint256 public endTimestamp;

    // The block timestamp when DACKIE mining starts
    uint256 public startTimestamp;

    // The block timestamp of the last pool update
    uint256 public lastRewardTimestamp;

    // DACKIE tokens created per second
    uint256 public rewardPerSecond;

    // The precision factor
    uint256 public PRECISION_FACTOR;
    
    uint256 public BASE_FACTOR = 1e18;

    uint256 public totalStake;

    mapping(uint256 => uint256) public rarityMapping;

    // The reward token
    IERC20Metadata public rewardToken;

    // The staked token
    IERC721 public stakedToken;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 rewardDebt;
        uint256[] tokenIds;
    }

    event Deposit(address indexed user, uint256[] tokenIds);
    event Harvest(address indexed user);
    event EmergencyWithdraw(address indexed user, uint256 tokenId);
    event NewStartAndEndTimestamp(uint256 startTimestamp, uint256 endTimestamp);
    event NewRewardPerSecond(uint256 rewardPerSecond);
    event RewardsStop(uint256 blockNumber);
    event TokenRecovery(address indexed token, uint256 amount);
    event Withdraw(address indexed user, uint256[] tokenIds);

    constructor() {
        SMART_CHEF_FACTORY = msg.sender;
    }

    /*
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerSecond: reward per second (in rewardToken)
     * @param _startTimestamp: start block timestamp
     * @param _endTimestamp: end block timestamp
     * @param _admin: admin address with ownership
     */
    function initialize(
        IERC721 _stakedToken,
        IERC20Metadata _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        address _admin
    ) external {
        require(!isInitialized, "Already initialized");
        require(msg.sender == SMART_CHEF_FACTORY, "Not factory");

        // Make this contract initialized
        isInitialized = true;

        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;

        uint256 decimalsRewardToken = uint256(rewardToken.decimals());
        require(decimalsRewardToken < 30, "Must be inferior to 30");

        PRECISION_FACTOR = uint256(10 ** (uint256(30) - decimalsRewardToken));
        // Set the lastRewardBlock as the startTimestamp
        lastRewardTimestamp = startTimestamp;

        totalStake = 0;

        // Transfer ownership to the admin address who becomes owner of the contract
        transferOwnership(_admin);
    }

    /*
     * @notice Deposit staked NFT
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function deposit(uint256[] memory _tokenIds) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        _updatePool();

        // handle harvest reward
        if (user.amount > 0) {
            uint256 pending = (user.amount * accTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
            if (pending > 0) {
                rewardToken.safeTransfer(address(msg.sender), pending);
            }
        }

        if (_tokenIds.length > 0) {
            addMultipleTokenIds(user, _tokenIds);
        }

        // Handle user rewardDebt
        user.rewardDebt = (user.amount * accTokenPerShare) / PRECISION_FACTOR;

        emit Deposit(msg.sender, _tokenIds);
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     */
    function withdraw(uint256[] memory _tokenIds) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "Withdraw: Nothing to withdraw");

        _updatePool();

        uint256 pending = (user.amount * accTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;

        if (_tokenIds.length > 0) {
            removeMultipleTokenIds(user, _tokenIds);
        }

        if (pending > 0) {
            rewardToken.safeTransfer(address(msg.sender), pending);
        }

        user.rewardDebt = (user.amount * accTokenPerShare) / PRECISION_FACTOR;

        emit Withdraw(msg.sender, _tokenIds);
    }

    /*
     * @notice Needs to be for emergency.
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        rewardToken.safeTransfer(address(msg.sender), _amount);
    }

    /**
    * @notice Allows the owner to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @dev Callable by owner
     */
    function recoverToken(address _token) external onlyOwner {
        require(_token != address(stakedToken), "Operations: Cannot recover staked token");
        require(_token != address(rewardToken), "Operations: Cannot recover reward token");

        uint256 balance = IERC20Metadata(_token).balanceOf(address(this));
        require(balance != 0, "Operations: Cannot recover zero balance");

        IERC20Metadata(_token).safeTransfer(address(msg.sender), balance);

        emit TokenRecovery(_token, balance);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external onlyOwner {
        endTimestamp = block.timestamp;
        emit RewardsStop(endTimestamp);
    }

    /*
     * @notice Update reward per block
     * @dev Only callable by owner.
     * @param _rewardPerSecond: the reward per second
     */
    function updateRewardPerSecond(uint256 _rewardPerSecond) external onlyOwner {
        require(block.timestamp < startTimestamp, "Pool has started");
        rewardPerSecond = _rewardPerSecond;
        emit NewRewardPerSecond(_rewardPerSecond);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @dev This function is only callable by owner.
     * @param _startTimestamp: the new start block timestamp
     * @param _endTimestamp: the new end block timestamp
     */
    function updateStartAndEndTimestamp(uint256 _startTimestamp, uint256 _endTimestamp) external onlyOwner {
        require(block.timestamp < startTimestamp, "Pool has started");
        require(_startTimestamp < _endTimestamp, "New startTimestamp must be lower than new endTimestamp");
        require(block.timestamp < _startTimestamp, "New startTimestamp must be higher than current block timestamp");

        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;

        // Set the lastRewardTimestamp as the startTimestamp
        lastRewardTimestamp = startTimestamp;

        emit NewStartAndEndTimestamp(_startTimestamp, _endTimestamp);
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = totalStake;
        if (block.timestamp > lastRewardTimestamp && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardTimestamp, block.timestamp);
            uint256 dackieReward = multiplier * rewardPerSecond;
            uint256 adjustedTokenPerShare = accTokenPerShare + (dackieReward * PRECISION_FACTOR) / stakedTokenSupply;
            return (user.amount * adjustedTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
        } else {
            return (user.amount * accTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
        }
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

        uint256 stakedTokenSupply = totalStake;

        if (stakedTokenSupply == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardTimestamp, block.timestamp);
        uint256 dackieReward = multiplier * rewardPerSecond;
        accTokenPerShare = accTokenPerShare + (dackieReward * PRECISION_FACTOR) / stakedTokenSupply;
        lastRewardTimestamp = block.timestamp;
    }

    /*
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start
     * @param _to: block to finish
     */
    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to <= endTimestamp) {
            return _to - _from;
        } else if (_from >= endTimestamp) {
            return 0;
        } else {
            return endTimestamp - _from;
        }
    }

    // To add a tokenId for a user
    function addTokenId(UserInfo storage _user, uint256 _tokenId) internal {
        // Stake NFT to contract
        stakedToken.transferFrom(msg.sender, address(this), _tokenId);
        _user.tokenIds.push(_tokenId);
        uint256 rarity = getRarity(_tokenId);
        _user.amount += rarity * BASE_FACTOR;
        totalStake += rarity * BASE_FACTOR;
    }

    // To add an array of tokenIds for a user
    function addMultipleTokenIds(UserInfo storage _user, uint256[] memory _tokenIdsToAdd) internal {
        for (uint256 i = 0; i < _tokenIdsToAdd.length; i++) {
            addTokenId(_user, _tokenIdsToAdd[i]);
        }
    }

    // To remove a specific tokenId for a user
    function removeTokenId(UserInfo storage _user, uint256 _tokenId) internal {
        uint256[] storage tokenIds = _user.tokenIds;
        uint256 indexToBeDeleted = tokenIds.length;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == _tokenId) {
                indexToBeDeleted = i;
                break;
            }
        }

        // Ensure that the tokenId exists in user's tokenIds
        require(indexToBeDeleted != tokenIds.length, "Token ID not found for user");

        if (indexToBeDeleted < tokenIds.length - 1) {
            tokenIds[indexToBeDeleted] = tokenIds[tokenIds.length - 1];
        }
        // decrease array length, this will delete the last item
        tokenIds.pop();

        // Withdraw NFT from contract
        stakedToken.transferFrom(address(this), msg.sender, _tokenId);
        uint256 rarity = getRarity(_tokenId);
        _user.amount -= rarity * BASE_FACTOR;
        totalStake -= rarity * BASE_FACTOR;
    }

    // To remove an array of tokenIds for a user
    function removeMultipleTokenIds(UserInfo storage _user, uint256[] memory _tokenIdsToRemove) internal {
        for (uint256 i = 0; i < _tokenIdsToRemove.length; i++) {
            removeTokenId(_user, _tokenIdsToRemove[i]);
        }
    }

    // Get rarity
    function getRarity(uint256 _tokenId) internal view returns (uint256){
        uint256 rarity = 10;
        if (rarityMapping[_tokenId] != 0) {
            rarity = rarityMapping[_tokenId];
        }
        return rarity;
    }

    // Add rarity mapping
    function addRarities(uint256[] memory tokenIds, uint256[] memory rarities) public onlyOwner {
        require(tokenIds.length == rarities.length, "Mismatched array lengths");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            rarityMapping[tokenIds[i]] = rarities[i];
        }
    }

    // Remove rarity mapping
    function removeRarities(uint256[] memory tokenIds) public onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            delete rarityMapping[tokenIds[i]];
        }
    }

    // Get tokenIds by user
    function getUserTokenIds(address _userAddress) public view returns (uint256[] memory) {
        return userInfo[_userAddress].tokenIds;
    }

}
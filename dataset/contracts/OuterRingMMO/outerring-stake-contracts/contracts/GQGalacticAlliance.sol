// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract GQGalacticAlliance is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint8 constant TOKEN1 = 1;
    uint8 constant TOKEN2 = 2;

    // Is contract initialized
    bool public isInitialized;

    // The block number when REWARD distribution ends.
    uint256 public endBlock;

    // The block number when REWARD distribution starts.
    uint256 public startBlock;

    // The block number of the last pool update
    uint256 public lastUpdateBlock;

    // Lockup duration for deposit
    uint256 public lockUpDuration;

    // Withdraw fee in BP
    uint256 public withdrawFee;

    // Withdraw fee destiny address
    address public feeAddress;

    // The staked token
    IERC20Upgradeable public stakedToken;

    // Accrued token per share
    mapping(uint8 => uint256) public mapOfAccTokenPerShare;

    // REWARD tokens created per block.
    mapping(uint8 => uint256) public mapOfRewardPerBlock;

    // The precision factor for reward tokens
    mapping(uint8 => uint256) public mapOfPrecisionFactor;

    // decimals places of the reward token
    mapping(uint8 => uint8) public mapOfRewardTokenDecimals;

    // The reward token
    mapping(uint8 => address) public mapOfRewardTokens;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount; // Staked tokens the user has provided
        uint256 rewardDebt1; // Reward debt1
        uint256 rewardDebt2; // Reward debt2
        uint256 firstDeposit; // First deposit before withdraw
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewEndBlock(uint256 endBlock);
    event NewRewardPerBlock(uint256 rewardPerBlock);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);
    event NewLockUpDuration(uint256 lockUpDuration);

    constructor() initializer {}

    /*
     * @notice Constructor of the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken1: reward token1 address
     * @param _rewardToken2: reward token2 address
     * @param _rewardPerBlock: reward per block (in rewardToken)
     * @param _startBlock: start block
     * @param _endBlock: end block
     * @param _lockUpDuration: duration for the deposit
     * @param _withdrawFee: fee for early withdraw
     * @param _feeAddress: address where fees for early withdraw will be send
     */
    function initialize(
        IERC20Upgradeable _stakedToken,
        address _rewardToken1,
        address _rewardToken2,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _lockUpDuration,
        uint256 _withdrawFee,
        address _feeAddress
    ) public initializer {
        __Ownable_init();
        stakedToken = _stakedToken;
        mapOfRewardTokens[TOKEN1] = _rewardToken1;
        mapOfRewardTokens[TOKEN2] = _rewardToken2;
        startBlock = _startBlock;
        endBlock = _endBlock;
        lockUpDuration = _lockUpDuration;
        withdrawFee = _withdrawFee;
        feeAddress = _feeAddress;

        mapOfRewardTokenDecimals[TOKEN1] = IERC20MetadataUpgradeable(
            mapOfRewardTokens[TOKEN1]
        ).decimals();
        mapOfRewardTokenDecimals[TOKEN2] = IERC20MetadataUpgradeable(
            mapOfRewardTokens[TOKEN2]
        ).decimals();
        require(
            mapOfRewardTokenDecimals[TOKEN1] < 30 &&
                mapOfRewardTokenDecimals[TOKEN2] < 30,
            "Must be inferior to 30"
        );

        mapOfPrecisionFactor[TOKEN1] = uint256(
            10**(uint256(30).sub(uint256(mapOfRewardTokenDecimals[TOKEN1])))
        );
        mapOfPrecisionFactor[TOKEN2] = uint256(
            10**(uint256(30).sub(uint256(mapOfRewardTokenDecimals[TOKEN2])))
        );

        // Set the lastRewardBlock as the startBlock
        lastUpdateBlock = startBlock;

        isInitialized = true;
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to deposit (in stakedToken)
     */
    function deposit(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        _updatePool();

        if (user.amount > 0) {
            uint256 pendingToken1 = user
                .amount
                .mul(mapOfAccTokenPerShare[TOKEN1])
                .div(mapOfPrecisionFactor[TOKEN1])
                .sub(user.rewardDebt1);
            if (pendingToken1 > 0) {
                _safeTokenTransfer(
                    mapOfRewardTokens[TOKEN1],
                    msg.sender,
                    pendingToken1
                );
            }
            uint256 pendingToken2 = user
                .amount
                .mul(mapOfAccTokenPerShare[TOKEN2])
                .div(mapOfPrecisionFactor[TOKEN2])
                .sub(user.rewardDebt2);

            if (pendingToken2 > 0) {
                _safeTokenTransfer(
                    mapOfRewardTokens[TOKEN2],
                    msg.sender,
                    pendingToken2
                );
            }
        }

        if (_amount > 0) {
            user.amount = user.amount.add(_amount);
            stakedToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.firstDeposit = user.firstDeposit == 0
                ? block.timestamp
                : user.firstDeposit;
        }

        user.rewardDebt1 = user
            .amount
            .mul(mapOfAccTokenPerShare[TOKEN1])
            .div(mapOfPrecisionFactor[TOKEN1]);

        user.rewardDebt2 = user
            .amount
            .mul(mapOfAccTokenPerShare[TOKEN2])
            .div(mapOfPrecisionFactor[TOKEN2]);

        emit Deposit(msg.sender, _amount);
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Error: Invalid amount");
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Amount to withdraw too high");
        _updatePool();

        uint256 pendingToken1 = user
            .amount
            .mul(mapOfAccTokenPerShare[TOKEN1])
            .div(mapOfPrecisionFactor[TOKEN1])
            .sub(user.rewardDebt1);
        uint256 pendingToken2 = user
            .amount
            .mul(mapOfAccTokenPerShare[TOKEN2])
            .div(mapOfPrecisionFactor[TOKEN2])
            .sub(user.rewardDebt2);

        user.amount = user.amount.sub(_amount);
        uint256 _amountToSend = _amount;
        if (block.timestamp < (user.firstDeposit + lockUpDuration)) {
            uint256 _feeAmountToSend = _amountToSend.mul(withdrawFee).div(
                10000
            );
            stakedToken.safeTransfer(address(feeAddress), _feeAmountToSend);
            _amountToSend = _amountToSend - _feeAmountToSend;
        }
        stakedToken.safeTransfer(address(msg.sender), _amountToSend);
        user.firstDeposit = user.firstDeposit == 0
            ? block.timestamp
            : user.firstDeposit;

        if (pendingToken1 > 0) {
            _safeTokenTransfer(
                mapOfRewardTokens[TOKEN1],
                msg.sender,
                pendingToken1
            );
        }
        if (pendingToken2 > 0) {
            _safeTokenTransfer(
                mapOfRewardTokens[TOKEN2],
                msg.sender,
                pendingToken2
            );
        }

        user.rewardDebt1 = user
            .amount
            .mul(mapOfAccTokenPerShare[TOKEN1])
            .div(mapOfPrecisionFactor[TOKEN1]);
        user.rewardDebt2 = user
            .amount
            .mul(mapOfAccTokenPerShare[TOKEN2])
            .div(mapOfPrecisionFactor[TOKEN2]);

        emit Withdraw(msg.sender, _amount);
    }

    /*
     * @notice Claim reward tokens
     */
    function claim() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        _updatePool();

        if (user.amount > 0) {
            uint256 pendingToken1 = user
                .amount
                .mul(mapOfAccTokenPerShare[TOKEN1])
                .div(mapOfPrecisionFactor[TOKEN1])
                .sub(user.rewardDebt1);

            if (pendingToken1 > 0) {
                _safeTokenTransfer(
                    mapOfRewardTokens[TOKEN1],
                    msg.sender,
                    pendingToken1
                );
                emit Claim(msg.sender, pendingToken1);
            }
            uint256 pendingToken2 = user
                .amount
                .mul(mapOfAccTokenPerShare[TOKEN2])
                .div(mapOfPrecisionFactor[TOKEN2])
                .sub(user.rewardDebt2);

            if (pendingToken2 > 0) {
                _safeTokenTransfer(
                    mapOfRewardTokens[TOKEN2],
                    msg.sender,
                    pendingToken2
                );
                emit Claim(msg.sender, pendingToken2);
            }
        }

        user.rewardDebt1 = user
            .amount
            .mul(mapOfAccTokenPerShare[TOKEN1])
            .div(mapOfPrecisionFactor[TOKEN1]);

        user.rewardDebt2 = user
            .amount
            .mul(mapOfAccTokenPerShare[TOKEN2])
            .div(mapOfPrecisionFactor[TOKEN2]);
    }

    /*
     * @notice Withdraw staked tokens without caring about rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _amountToTransfer = user.amount;
        user.amount = 0;
        user.rewardDebt1 = 0;
        user.rewardDebt2 = 0;

        // Avoid users send an amount with 0 tokens
        if (_amountToTransfer > 0) {
            if (block.timestamp < (user.firstDeposit + lockUpDuration)) {
                uint256 _feeAmountToSend = _amountToTransfer
                    .mul(withdrawFee)
                    .div(10000);
                stakedToken.safeTransfer(address(feeAddress), _feeAmountToSend);
                _amountToTransfer = _amountToTransfer - _feeAmountToSend;
            }
            stakedToken.safeTransfer(address(msg.sender), _amountToTransfer);
        }

        emit EmergencyWithdraw(msg.sender, _amountToTransfer);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount)
        external
        onlyOwner
    {
        require(
            _tokenAddress != address(stakedToken),
            "Cannot be staked token"
        );
        require(
            _tokenAddress != mapOfRewardTokens[TOKEN1] &&
                _tokenAddress != mapOfRewardTokens[TOKEN2],
            "Cannot be reward token"
        );

        IERC20Upgradeable(_tokenAddress).safeTransfer(
            address(msg.sender),
            _tokenAmount
        );

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external onlyOwner {
        endBlock = block.number;
    }

    /*
     * @notice Update reward per block
     * @dev Only callable by owner.
     * @param _rewardPerBlock: the reward per block
     */
    function updateRewardPerBlock(uint8 _rewardTokenId, uint256 _rewardPerBlock)
        external
        onlyOwner
    {
        require(block.number < startBlock, "Pool has started");
        mapOfRewardPerBlock[_rewardTokenId] = _rewardPerBlock;
        emit NewRewardPerBlock(_rewardPerBlock);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @dev This function is only callable by owner.
     * @param _startBlock: the new start block
     * @param _bonusEndBlock: the new end block
     */
    function updateStartAndEndBlocks(
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        require(
            _startBlock < _bonusEndBlock,
            "New startBlock must be lower than new endBlock"
        );
        require(
            block.number < _startBlock,
            "New startBlock must be higher than current block"
        );

        startBlock = _startBlock;
        endBlock = _bonusEndBlock;

        // Set the lastRewardBlock as the startBlock
        lastUpdateBlock = startBlock;

        emit NewStartAndEndBlocks(_startBlock, _bonusEndBlock);
    }

    /*
     * @notice Sets the lock up duration
     * @param _lockUpDuration: The lock up duration in seconds (block timestamp)
     * @dev This function is only callable by owner.
     */
    function setLockUpDuration(uint256 _lockUpDuration) external onlyOwner {
        lockUpDuration = _lockUpDuration;
        emit NewLockUpDuration(lockUpDuration);
    }

    /*
     * @notice Sets start block of the pool given a block amount
     * @param _blocks: block amount
     * @dev This function is only callable by owner.
     */
    function poolStartIn(uint256 _blocks) external onlyOwner {
        poolSetStart(block.number.add(_blocks));
    }

    /*
     * @notice Set the duration and start block of the pool
     * @param _startBlock: start block
     * @param _durationBlocks: duration block amount
     * @dev This function is only callable by owner.
     */
    function poolSetStartAndDuration(
        uint256 _startBlock,
        uint256 _durationBlocks
    ) external onlyOwner {
        poolSetStart(_startBlock);
        poolSetDuration(_durationBlocks);
    }

    /*
     * @notice Withdraws the remaining funds
     * @param _to The address where the funds will be sent
     */
    function withdrawRemains(uint8 _rewardTokenId, address _to)
        external
        onlyOwner
    {
        require(block.number > endBlock, "Error: Pool not finished yet");
        uint256 tokenBal = IERC20Upgradeable(mapOfRewardTokens[_rewardTokenId])
            .balanceOf(address(this));
        require(tokenBal > 0, "Error: No remaining funds");
        IERC20Upgradeable(mapOfRewardTokens[_rewardTokenId]).safeTransfer(
            _to,
            tokenBal
        );
    }

    /*
     * @notice Deposits the reward token1 funds
     * @param _to The address where the funds will be sent
     */
    function depositRewardTokenFunds(uint8 _rewardTokenId, uint256 _amount)
        external
        onlyOwner
    {
        IERC20Upgradeable(mapOfRewardTokens[_rewardTokenId]).safeTransfer(
            address(this),
            _amount
        );
    }

    /*
     * @notice Gets the reward per block for UI
     * @return reward per block
     */
    function rewarPerBlockUI(uint8 _rewardTokenId)
        external
        view
        returns (uint256)
    {
        return
            mapOfRewardPerBlock[_rewardTokenId].div(
                10**uint256(mapOfRewardTokenDecimals[_rewardTokenId])
            );
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(uint8 _rewardTokenId, address _user)
        external
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_user];
        uint256 rewardDebt = _rewardTokenId == TOKEN1
            ? user.rewardDebt1
            : user.rewardDebt2;
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        if (block.number > lastUpdateBlock && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastUpdateBlock, block.number);
            uint256 tokenReward = multiplier.mul(
                mapOfRewardPerBlock[_rewardTokenId]
            );
            uint256 adjustedPerShare = mapOfAccTokenPerShare[_rewardTokenId]
                .add(
                    tokenReward.mul(mapOfPrecisionFactor[_rewardTokenId]).div(
                        stakedTokenSupply
                    )
                );
            return
                user
                    .amount
                    .mul(adjustedPerShare)
                    .div(mapOfPrecisionFactor[_rewardTokenId])
                    .sub(rewardDebt);
        } else {
            return
                user
                    .amount
                    .mul(mapOfAccTokenPerShare[_rewardTokenId])
                    .div(mapOfPrecisionFactor[_rewardTokenId])
                    .sub(rewardDebt);
        }
    }

    /*
     * @notice Sets start block of the pool
     * @param _startBlock: start block
     * @dev This function is only callable by owner.
     */
    function poolSetStart(uint256 _startBlock) public onlyOwner {
        require(block.number < startBlock, "Pool has started");
        uint256 rewardDurationValue = rewardDuration();
        startBlock = _startBlock;
        endBlock = startBlock.add(rewardDurationValue);
        lastUpdateBlock = startBlock;
        emit NewStartAndEndBlocks(startBlock, endBlock);
    }

    /*
     * @notice Set the duration of the pool
     * @param _durationBlocks: duration block amount
     * @dev This function is only callable by owner.
     */
    function poolSetDuration(uint256 _durationBlocks) public onlyOwner {
        require(block.number < startBlock, "Pool has started");
        endBlock = startBlock.add(_durationBlocks);
        poolCalcRewardPerBlock(TOKEN1);
        poolCalcRewardPerBlock(TOKEN2);
        emit NewEndBlock(endBlock);
    }

    /*
     * @notice Calculates the rewardPerBlock of the pool
     * @dev This function is only callable by owner.
     */
    function poolCalcRewardPerBlock(uint8 _rewardTokenId) public onlyOwner {
        uint256 rewardBal = IERC20Upgradeable(mapOfRewardTokens[_rewardTokenId]).balanceOf(address(this));
        mapOfRewardPerBlock[_rewardTokenId] = rewardBal.div(rewardDuration());
    }

    /*
     * @notice Gets the reward duration
     * @return reward duration
     */
    function rewardDuration() public view returns (uint256) {
        return endBlock.sub(startBlock);
    }

    /*
     * @notice SendPending tokens to claimer
     * @param pending: amount to claim
     */
    function _safeTokenTransfer(
        address _rewardToken,
        address _to,
        uint256 _amount
    ) internal {
        uint256 rewardTokenBalance = IERC20Upgradeable(_rewardToken).balanceOf(address(this));
        if (_amount > rewardTokenBalance) {
            IERC20Upgradeable(_rewardToken).safeTransfer(_to, rewardTokenBalance);
        } else {
            IERC20Upgradeable(_rewardToken).safeTransfer(_to, _amount);
        }
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.number <= lastUpdateBlock) {
            return;
        }

        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));

        if (stakedTokenSupply == 0) {
            lastUpdateBlock = block.number;
            return;
        }

        uint256 multiplier = _getMultiplier(lastUpdateBlock, block.number);
        uint256 tokenReward1 = multiplier.mul(mapOfRewardPerBlock[TOKEN1]);
        uint256 tokenReward2 = multiplier.mul(mapOfRewardPerBlock[TOKEN2]);
        mapOfAccTokenPerShare[TOKEN1] = mapOfAccTokenPerShare[TOKEN1].add(
            tokenReward1.mul(mapOfPrecisionFactor[TOKEN1]).div(stakedTokenSupply)
        );
        mapOfAccTokenPerShare[TOKEN2] = mapOfAccTokenPerShare[TOKEN2].add(
            tokenReward2.mul(mapOfPrecisionFactor[TOKEN2]).div(stakedTokenSupply)
        );
        lastUpdateBlock = block.number;
    }

    /*
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start
     * @param _to: block to finish
     * @return multiplier
     */
    function _getMultiplier(uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        if (_to <= endBlock) {
            return _to.sub(_from);
        } else if (_from >= endBlock) {
            return 0;
        } else {
            return endBlock.sub(_from);
        }
    }
}

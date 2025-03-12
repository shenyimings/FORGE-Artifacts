// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GQGalacticReserve is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The block number when REWARD distribution ends.
    uint256 public endBlock;

    // The block number when REWARD distribution starts.
    uint256 public startBlock;

    // The block number of the last pool update
    uint256 public lastUpdateBlock;

    // REWARD tokens created per block.
    uint256 public rewardPerBlock;

    // Lockup duration for deposit
    uint256 public lockUpDuration;

    // Withdraw fee in BP
    uint256 public withdrawFee;

    // The precision factor
    uint256 public PRECISION_FACTOR;

    // decimals places of the reward token
    uint8 public rewardTokenDecimals;

    // Withdraw fee destiny address
    address public feeAddress;

    // The reward token
    IERC20 public rewardToken;

    // The staked token
    IERC20 public stakedToken;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount; // Staked tokens the user has provided
        uint256 rewardDebt; // Reward debt
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

    /*
     * @notice Constructor of the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerBlock: reward per block (in rewardToken)
     * @param _startBlock: start block
     * @param _endBlock: end block
     * @param _lockUpDuration: duration for the deposit
     * @param _withdrawFee: fee for early withdraw
     * @param _feeAddress: address where fees for early withdraw will be send
     */
    constructor(
        IERC20 _stakedToken,
        IERC20 _rewardToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _lockUpDuration,
        uint256 _withdrawFee,
        address _feeAddress
    ) {
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        startBlock = _startBlock;
        endBlock = _endBlock;
        lockUpDuration = _lockUpDuration;
        withdrawFee = _withdrawFee;
        feeAddress = _feeAddress;

        rewardTokenDecimals = IERC20Metadata(address(rewardToken)).decimals();
        uint256 decimalsRewardToken = uint256(rewardTokenDecimals);
        require(decimalsRewardToken < 30, "Must be inferior to 30");

        PRECISION_FACTOR = uint256(10**(uint256(30).sub(decimalsRewardToken)));

        // Set the lastRewardBlock as the startBlock
        lastUpdateBlock = startBlock;
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to deposit (in stakedToken)
     */
    function deposit(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        _updatePool();

        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(accTokenPerShare)
                .div(PRECISION_FACTOR)
                .sub(user.rewardDebt);
            if (pending > 0) {
                _safeTokenTransfer(msg.sender, pending);
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

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(
            PRECISION_FACTOR
        );

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

        uint256 pending = user
            .amount
            .mul(accTokenPerShare)
            .div(PRECISION_FACTOR)
            .sub(user.rewardDebt);

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

        if (pending > 0) {
            _safeTokenTransfer(msg.sender, pending);
        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(
            PRECISION_FACTOR
        );

        emit Withdraw(msg.sender, _amount);
    }

    /*
     * @notice Claim reward tokens
     */
    function claim() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        _updatePool();

        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(accTokenPerShare)
                .div(PRECISION_FACTOR)
                .sub(user.rewardDebt);

            if (pending > 0) {
                _safeTokenTransfer(msg.sender, pending);
                emit Claim(msg.sender, pending);
            }
        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(
            PRECISION_FACTOR
        );
    }

    /*
     * @notice Withdraw staked tokens without caring about rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _amountToTransfer = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

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
            _tokenAddress != address(rewardToken),
            "Cannot be reward token"
        );

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

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
    function updateRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        rewardPerBlock = _rewardPerBlock;
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
    function withdrawRemains(address _to) external onlyOwner {
        require(block.number > endBlock, "Error: Pool not finished yet");
        uint256 tokenBal = rewardToken.balanceOf(address(this));
        require(tokenBal > 0, "Error: No remaining funds");
        IERC20(rewardToken).safeTransfer(_to, tokenBal);
    }

    /*
     * @notice Withdraws the remaining funds
     * @param _to The address where the funds will be sent
     */
    function depositRewardFunds(uint256 _amount) external onlyOwner {
        IERC20(rewardToken).safeTransfer(address(this), _amount);
    }

    /*
     * @notice Gets the reward per block for UI
     * @return reward per block
     */
    function rewardPerBlockUI() external view returns (uint256) {
        return rewardPerBlock.div(10**uint256(rewardTokenDecimals));
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        if (block.number > lastUpdateBlock && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastUpdateBlock, block.number);
            uint256 tokenReward = multiplier.mul(rewardPerBlock);
            uint256 adjustedTokenPerShare = accTokenPerShare.add(
                tokenReward.mul(PRECISION_FACTOR).div(stakedTokenSupply)
            );
            return
                user
                    .amount
                    .mul(adjustedTokenPerShare)
                    .div(PRECISION_FACTOR)
                    .sub(user.rewardDebt);
        } else {
            return
                user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(
                    user.rewardDebt
                );
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
        poolCalcRewardPerBlock();
        emit NewEndBlock(endBlock);
    }

    /*
     * @notice Calculates the rewardPerBlock of the pool
     * @dev This function is only callable by owner.
     */
    function poolCalcRewardPerBlock() public onlyOwner {
        uint256 rewardBal = rewardToken.balanceOf(address(this));
        rewardPerBlock = rewardBal.div(rewardDuration());
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
    function _safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));
        if (_amount > rewardTokenBalance) {
            rewardToken.safeTransfer(_to, rewardTokenBalance);
        } else {
            rewardToken.safeTransfer(_to, _amount);
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
        uint256 tokenReward = multiplier.mul(rewardPerBlock);
        accTokenPerShare = accTokenPerShare.add(
            tokenReward.mul(PRECISION_FACTOR).div(stakedTokenSupply)
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

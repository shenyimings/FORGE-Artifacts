// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPancakeVault {
    function deposit(uint256 _amount, uint256 _lockDuration) external;

    function withdraw(uint256 _amount) external;

    function userInfo(address _account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            uint256
        );

    function calculateWithdrawFee(address _account, uint256 _shares) external view returns (uint256);

    function getPricePerFullShare() external view returns (uint256);

    function withdrawFeePeriod() external view returns (uint256);
}

contract Xpot is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The precision factor
    uint256 public PRECISION_FACTOR;

    // The staked token
    IERC20 public stakedToken;

    // The transfer fee (in basis points) of staked token
    uint16 public stakeFee;

    // The unstake fee
    uint16 public unstakeFee;

    // The token total staked
    uint256 public totalStaked;

    // Total reward
    uint256 public totalReward;

    // The treasury address
    address public treasury;

    // The jackpot pool address
    address public jackPot;

    // Pancake interface
    IPancakeVault public cakeVault;

    // The total stakers
    uint256 public totalStakers;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 startTime; // First deposit timestamp
        uint256 accShare; // Reward debt
        uint256 claimed; // Reward received
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event NewStakedTokenTransferFee(uint16 transferFee);
    event NewUnStakedTokenTransferFee(uint16 transferFee);
    event NewWithdrawalInterval(uint256 interval);
    event NewTreasury(address account);
    event NewJackPot(address account);

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Only Wallet can make transaction");
        _;
    }

    constructor(
        IERC20 _stakedToken,
        uint16 _stakeFee,
        uint16 _unstakeFee,
        address _cakeVault,
        address _treasury,
        uint256 _decimals,
        address _admin
    ) public {
        stakedToken = _stakedToken;
        stakeFee = _stakeFee;
        unstakeFee = _unstakeFee;
        treasury = _treasury;
        cakeVault = IPancakeVault(_cakeVault);

        uint256 decimalStakedtoken = _decimals;

        PRECISION_FACTOR = uint256(10**(30 - decimalStakedtoken));

        // Approve
        stakedToken.approve(_cakeVault, 2**256 - 1);

        // Transfer ownership to the admin address who becomes owner of the contract
        transferOwnership(_admin);
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to withdraw (in stakedToken)
     */
    function deposit(uint256 _amount) external nonReentrant whenNotPaused onlyEOA {
        require(_amount != 0, "Can't stake zero CAKE");
        UserInfo storage user = userInfo[msg.sender];

        if (user.startTime == 0) {
            user.startTime = block.timestamp;
            totalStakers = totalStakers + 1;
            user.accShare = accTokenPerShare;
        }

        if (user.amount != 0) {
            uint256 pending = (user.amount * (accTokenPerShare - user.accShare)) / PRECISION_FACTOR;

            if (pending != 0) {
                stakedToken.safeTransfer(msg.sender, pending);
                user.claimed += pending;
            }
        }

        user.accShare = accTokenPerShare;

        if (_amount != 0) {
            stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);

            uint256 stakeFeeAmount;
            if (stakeFee != 0) {
                stakeFeeAmount = (_amount * stakeFee) / 10000;

                stakedToken.safeTransfer(treasury, stakeFeeAmount / 5);
                stakedToken.safeTransfer(jackPot, stakeFeeAmount - (stakeFeeAmount / 5) - (stakeFeeAmount * 60) / 100);
                _amount = _amount - stakeFeeAmount;
            }
            user.amount = user.amount + _amount;
            totalStaked = totalStaked + _amount;

            if (stakeFee != 0) {
                _updatePool((stakeFeeAmount * 60) / 100);
            }

            cakeVault.deposit(_amount, 0);
        }

        emit Deposit(msg.sender, _amount);
    }

    /*
     * @notice Withdraw staked tokens and rewards
     * @param _amount: amount to withdraw (in stakedToken)
     */
    function withdraw(uint256 _amount) external nonReentrant whenNotPaused onlyEOA {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Amount to withdraw too high");

        uint256 pending = (user.amount * (accTokenPerShare - user.accShare)) / PRECISION_FACTOR;

        if (pending != 0) {
            stakedToken.safeTransfer(msg.sender, pending);
            user.claimed += pending;
        }

        user.accShare = accTokenPerShare;

        uint256 userShares;
        if (_amount != 0) {
            (uint256 _shares, , , , , , , , ) = cakeVault.userInfo(address(this));
            userShares = (((uint256(1e18) * _amount) / totalStaked) * _shares) / 1e18;
            uint256 preBalance = stakedToken.balanceOf(address(this));

            cakeVault.withdraw(userShares);

            uint256 tokenBal = stakedToken.balanceOf(address(this)) - preBalance;

            if (tokenBal != 0) {
                uint256 withdrawFee;

                if (unstakeFee != 0) {
                    withdrawFee = (tokenBal * unstakeFee) / 10000;
                    _amount = _amount - withdrawFee;
                    tokenBal = tokenBal - withdrawFee;
                    stakedToken.safeTransfer(treasury, withdrawFee);
                }

                user.amount = user.amount - _amount - withdrawFee;
                totalStaked = totalStaked - _amount - withdrawFee;

                stakedToken.safeTransfer(address(msg.sender), tokenBal);

                if (user.amount == 0) {
                    user.startTime = 0;
                    totalStakers = totalStakers - 1;
                }
            }
        }

        emit Withdraw(msg.sender, _amount, userShares);
    }

    /*
     * @notice Update staked token transfer fee
     * @dev Only callable by owner.
     * @param _stakeFee: the transfer fee of staked token
     */
    function updateStakedTokenTransferFee(uint16 _stakeFee) external onlyOwner {
        require(_stakeFee < 600, "Invalid transfer fee of staking");
        stakeFee = _stakeFee;
        emit NewStakedTokenTransferFee(_stakeFee);
    }

    /*
     * @notice Update unstaking transfer fee
     * @dev Only callable by owner.
     * @param _unStakeFee: the transfer fee of un-staking
     */
    function updateUnStakedTokenTransferFee(uint16 _unStakeFee) external onlyOwner {
        require(_unStakeFee < 10000, "Invalid transfer fee of unstaking");
        unstakeFee = _unStakeFee;
        emit NewUnStakedTokenTransferFee(_unStakeFee);
    }

    /*
     * @notice Update treasury address
     * @dev Only callable by owner.
     * @param _treasury: new treasury address
     */
    function updateTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");

        treasury = _treasury;
        emit NewTreasury(_treasury);
    }

    /*
     * @notice Update jackpot address
     * @dev Only callable by owner.
     * @param _jackPot: new treasury address
     */
    function updateJackPot(address _jackPot) external onlyOwner {
        require(_jackPot != address(0), "Invalid jackpot address");

        jackPot = _jackPot;
        emit NewJackPot(_jackPot);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(stakedToken), "Cannot be staked token");

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /*
     * @notice View function to see pending amount on frontend.
     * @param _user: user address
     * @return Pending amount for a given user
     */
    function pendingAmount(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];

        (uint256 _shares, , , , , , , , ) = cakeVault.userInfo(address(this));
        return (_shares * cakeVault.getPricePerFullShare() * user.amount) / totalStaked / 1e18;
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        return (user.amount * (accTokenPerShare - user.accShare)) / PRECISION_FACTOR;
    }

    /*
     * @notice View function to get last deposit time.
     * @return Timestamp of deposit
     */
    function lastDepositTime() external view returns (uint256) {
        (, uint256 _lastDepositTime, , , , , , , ) = cakeVault.userInfo(address(this));
        return _lastDepositTime;
    }

    /*
     * @notice View function to get withdraw fee period.
     * @return Time in seconds
     */
    function withdrawFeePeriod() external view returns (uint256) {
        return cakeVault.withdrawFeePeriod();
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool(uint256 _rewardAmount) internal {
        if (totalStaked == 0) {
            return;
        }

        totalReward = totalReward + _rewardAmount;
        accTokenPerShare = accTokenPerShare + ((_rewardAmount * PRECISION_FACTOR) / totalStaked);
    }
}

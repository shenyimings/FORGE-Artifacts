// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../common/Ownable.sol";
import "../interface/IERC20.sol";

contract VempDao is Ownable {
    using SafeMath for uint256;
    IERC20 public VEMP;
    IERC20 public xVEMP;
    address public rewardDistribution;
    mapping(address => bool) public blackListAddress;

    event Stake(address indexed staker, uint256 xvempReceived);
    event Unstake(address indexed unstaker, uint256 vempReceived);
    event RewardDistributorSet(address indexed newRewardDistributor);
    event VempFeeReceived(address indexed from, uint256 vempAmount);

    modifier onlyRewardDistribution() {
        require(
            _msgSender() == rewardDistribution,
            "Caller is not reward distribution"
        );
        _;
    }

    function initialize(address _owner, address _vemp, address _xvemp) public initializer {
        require(_owner != address(0), "Invalid owner address");
        require(_vemp != address(0), "Invalid vemp address");
        require(_xvemp != address(0), "Invalid xvemp address");

        Ownable.init(_owner);
        VEMP = IERC20(_vemp);
        xVEMP = IERC20(_xvemp);
    }

    // Enter the VempDao. Pay some VEMPs. Earn some shares.
    function enter(uint256 _amount) public {
        require(blackListAddress[msg.sender] != true, "BlackListed User");
        uint256 totalVemp = VEMP.balanceOf(address(this));
        uint256 totalShares = xVEMP.totalSupply();
        if (totalShares == 0 || totalVemp == 0) {
            xVEMP.mint(_msgSender(), _amount);
            emit Stake(_msgSender(), _amount);
        } else {
            uint256 _userShare = _amount.mul(totalShares).div(totalVemp);
            xVEMP.mint(_msgSender(), _userShare);
            emit Stake(_msgSender(), _userShare);
        }
        VEMP.transferFrom(_msgSender(), address(this), _amount);
    }

    // Leave the VempDao. Claim back your VEMPs.
    function leave(uint256 _share) public {
        require(blackListAddress[msg.sender] != true, "BlackListed User");
        uint256 totalShares = xVEMP.totalSupply();
        uint256 _userShare =
            _share.mul(VEMP.balanceOf(address(this))).div(totalShares);
        xVEMP.burnFrom(_msgSender(), _share);
        VEMP.transfer(_msgSender(), _userShare);
        emit Unstake(_msgSender(), _userShare);
    }

    function setRewardDistribution(address _rewardDistribution)
        external
        onlyOwner
    {
        require(_rewardDistribution != address(0), "Invalid _rewardDistribution address");
        rewardDistribution = _rewardDistribution;
        emit RewardDistributorSet(_rewardDistribution);
    }

    function notifyRewardAmount(uint256 _balance)
        external
        onlyRewardDistribution
    {
        VEMP.transferFrom(_msgSender(), address(this), _balance);
        emit VempFeeReceived(_msgSender(), _balance);
    }

    /**
     * @dev Used only by admin or owner, used to withdraw locked vemp tokens in emergency
     *
     * @param _token address of erc20 token contract
     * @param _to address of vemp tokens receiver
     * @param _amount amount of vemp and must be less than total locked amount
     */
    function emergencyWithdrawVempTokens(address _token, address _to, uint256 _amount)
        public
        onlyOwner
    {
        require(_to != address(0), "Invalid _to address");
        require(_token != address(0), "Invalid _to address");
        uint256 vempBal = IERC20(_token).balanceOf(address(this));
        require(vempBal >= _amount, "Insufficiently amount");
        bool status = IERC20(_token).transfer(_to, _amount);
        require(status, "Token transfer failed");
    }

    /**
     * @dev Used only by admin or owner, used to blacklist any user in any emergency case
     *
     * @param _user address of blacklistef user
     * @param _status status of user
     */
    function blackListUser(address _user, bool _status)
        external
        onlyOwner
    {
        require(blackListAddress[_user] != _status, "Already in same status");
        blackListAddress[_user] = _status;
    }
}

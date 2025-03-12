// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "../access/Governable.sol";
import "../referrals/interfaces/IReferralStorage.sol";
import "./interfaces/IAlpReferralReward.sol";

contract AlpReferralReward is IAlpReferralReward, ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    mapping(address => uint256) public override claimableReward;

    uint256 public rewardBps = 2000;
    IERC20 public rewardToken;
    address public referralStorage;

    mapping(address => bool) public isHandler;
    bool public inPrivateClaimingMode;

    event SetReferralStorage(address referralStorage);
    event IncreaseAlpReferralReward(
        bytes32 referralCode,
        address referrer,
        address account,
        uint256 baseAmount,
        uint256 reward
    );
    event Claim(address _referrer, uint256 amount);

    constructor(address _rewardToken, address _referralStorage) public {
        rewardToken = IERC20(_rewardToken);
        referralStorage = _referralStorage;
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "AlpReferralReward: forbidden");
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    function setReferralStorage(address _referralStorage) external onlyGov {
        referralStorage = _referralStorage;
        emit SetReferralStorage(_referralStorage);
    }

    function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external onlyGov {
        inPrivateClaimingMode = _inPrivateClaimingMode;
    }

    function setRewardBps(uint256 _rewardBps) external onlyGov {
        rewardBps = _rewardBps;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function increaseAlpReferral(address _account, uint256 _baseAmount) external override nonReentrant {
        _validateHandler();
        address _referralStorage = referralStorage;
        if (_referralStorage == address(0)) {
            return;
        }

        (bytes32 referralCode, address referrer) = IReferralStorage(_referralStorage).getTraderReferralInfo(_account);

        if (referralCode == bytes32(0)) {
            return;
        }

        uint256 reward = _baseAmount.mul(rewardBps).div(BASIS_POINTS_DIVISOR);
        claimableReward[referrer] = claimableReward[referrer].add(reward);
        emit IncreaseAlpReferralReward(referralCode, referrer, _account, _baseAmount, reward);
    }

    function claim() external override nonReentrant returns (uint256) {
        if (inPrivateClaimingMode) {
            revert("AlpReferralReward: action not enabled");
        }
        return _claim(msg.sender);
    }

    function claimForReferrer(address referrer) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _claim(referrer);
    }

    function _claim(address _referrer) private returns (uint256) {
        uint256 rewardAmount = claimableReward[_referrer];
        uint256 balance = rewardToken.balanceOf(address(this));

        if (rewardAmount > balance) return 0;

        claimableReward[_referrer] = 0;
        if (rewardAmount != 0) {
            rewardToken.safeTransfer(_referrer, rewardAmount);
            emit Claim(_referrer, rewardAmount);
        }

        return rewardAmount;
    }
}

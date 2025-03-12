// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/IMDLP.sol";

/// @title DLpRush
/// @author Magpie Team, an incentive program to accumulate ETH/BNB
/// @notice ETH/BNB will be transfered to admin and lock forever

contract DlpRush is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */

    address public mDLP;
    address public rdnt;
    address public rdntDlp;

    struct UserInfo {
        uint256 converted;
        uint256 factor;
    }

    uint256 public constant DENOMINATOR = 10000;

    mapping(address => UserInfo) public userInfos;

    uint256 public totalFactor;
    uint256 public totalConverted;

    uint256 public tierLength;
    uint256[] public rewardMultiplier;
    uint256[] public rewardTier;

    /* ============ Events ============ */

    event Converted(address indexed _user, uint256 _amount, uint256 _factorReceived);
    event SetMDlp(address _oldMDLp, address _newMDlp);

    /* ============ Errors ============ */

    error InvalidAmount();
    error LengthMissmatch();
    error MDLPNotSet();

    /* ============ Constructor ============ */

    function __DlpRush_init(address _rdnt, address _rdntDlp, address _mdlp) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        rdnt = _rdnt;
        rdntDlp = _rdntDlp;
        mDLP = _mdlp;
    }

    /* ============ Modifier ============ */

    modifier onlyIfMDLPSet() {
        if (mDLP == address(0)) revert MDLPNotSet();
        _;
    }

    /* ============ External Read Functions ============ */

    function quoteConvert(
        uint256 _amountToDeposit,
        address _account
    ) external view returns (uint256 newUserFactor, uint256 newTotalFactor) {
        UserInfo memory userInfo = userInfos[_account];

        newTotalFactor = totalFactor - userInfo.factor;
        uint256 accumulated = _amountToDeposit + userInfo.converted;
        uint256 accumulatedFactor = 0;
        uint256 i = 1;

        while (i < rewardTier.length && accumulated > rewardTier[i]) {
            accumulatedFactor += (rewardTier[i] - rewardTier[i - 1]) * rewardMultiplier[i - 1];
            i++;
        }

        accumulatedFactor += (accumulated - rewardTier[i - 1]) * rewardMultiplier[i - 1];
        newUserFactor = (accumulatedFactor / DENOMINATOR);
        newTotalFactor += newUserFactor;
    }

    function getUserTier(address _account) public view returns (uint256) {
        uint256 userDeposited = userInfos[_account].converted;
        for (uint256 i = tierLength - 1; i >= 1; i--) {
            if (userDeposited >= rewardTier[i]) {
                return i;
            }
        }

        return 0;
    }

    function amountToNextTier(address _account) external view returns (uint256) {
        uint256 userTier = this.getUserTier(_account);
        if (userTier == tierLength - 1) return 0;

        return rewardTier[userTier + 1] - userInfos[_account].converted;
    }

    /* ============ External Write Functions ============ */

    function zapWithRadiant (
        uint256 _rdntAmt,
        uint8 _mode
    ) external payable nonReentrant whenNotPaused onlyIfMDLPSet {
        if (msg.value == 0) revert InvalidAmount();

        if (_rdntAmt != 0) {
            IERC20(rdnt).safeTransferFrom(msg.sender, address(this), _rdntAmt);
            IERC20(rdnt).safeApprove(address(mDLP), _rdntAmt);
        }

        uint256 _liquidity = IMDLP(mDLP).convertWithZapRadiant{ value: msg.value }(
            msg.sender,
            _rdntAmt,
            _mode
        );

        _convert(_liquidity);
    }

    function convertLp (
        uint256 _amount,
        uint8 _mode
    ) external nonReentrant whenNotPaused onlyIfMDLPSet {
        if (_amount == 0) revert InvalidAmount();
        IERC20(rdntDlp).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(rdntDlp).safeApprove(address(mDLP), _amount);
        IMDLP(mDLP).convertWithLp(msg.sender, _amount, _mode);
        _convert(_amount);
    }

    /* ============ Internal Functions ============ */

    function _convert(uint256 _amount) internal {
        UserInfo storage userInfo = userInfos[msg.sender];
        uint256 originalFactor = userInfo.factor;
        (userInfo.factor, totalFactor) = this.quoteConvert(_amount, msg.sender);

        userInfo.converted += _amount;
        totalConverted += _amount;

        emit Converted(msg.sender, _amount, userInfo.factor - originalFactor);
    }

    /* ============ Admin Functions ============ */

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setMultiplier(
        uint256[] calldata _multiplier,
        uint256[] calldata _tier
    ) external onlyOwner {
        if (_multiplier.length == 0 || _tier.length == 0 || (_multiplier.length != _tier.length))
            revert LengthMissmatch();

        for (uint8 i = 0; i < _multiplier.length; ++i) {
            if (_multiplier[i] == 0) revert InvalidAmount();
            rewardMultiplier.push(_multiplier[i]);
            rewardTier.push(_tier[i]);
            tierLength += 1;
        }
    }

    function resetMultiplier() external onlyOwner {
        uint256 len = rewardMultiplier.length;
        for (uint8 i = 0; i < len; ++i) {
            rewardMultiplier.pop();
            rewardTier.pop();
        }

        tierLength = 0;
    }

    function setMDLP(address _mDLP) external onlyOwner {
        address oldMDlp = _mDLP;
        mDLP = _mDLP;

        emit SetMDlp(oldMDlp, _mDLP);
    }
}

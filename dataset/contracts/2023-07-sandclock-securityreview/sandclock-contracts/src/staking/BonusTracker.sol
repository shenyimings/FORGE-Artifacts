// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

abstract contract BonusTracker is ERC4626, ReentrancyGuard {
    using FixedPointMathLib for uint256;

    event BonusPaid(address indexed user, uint256 bonus);
    event BonusBurned(address indexed user, uint256 bonus);

    uint256 internal constant PRECISION = 1e30;

    /// @notice The last Unix timestamp (in seconds) when bonusPerTokenStored was updated
    uint64 public lastBonusUpdateTime;

    /// @notice The last stored bonusPerToken value
    uint256 public bonusPerTokenStored;

    /// @notice The total bonus amount currently held by users
    uint256 public totalBonus;

    /// @notice The bonusPerToken value when an account last compounded/withdrew bonus
    mapping(address => uint256) public userBonusPerTokenPaid;

    /// @notice The number of multiplier points compounded for an account
    mapping(address => uint256) public multiplierPointsOf;

    /// @notice The bonusOf() value when an account last staked/withdrew bonus
    mapping(address => uint256) public bonus;

    constructor(ERC20 _asset, string memory _name, string memory _symbol) ERC4626(_asset, _name, _symbol) {
        lastBonusUpdateTime = uint64(block.timestamp);
    }

    /// @notice Claim bonus
    function boost() external nonReentrant returns (uint256 _bonus) {
        _updateReward(msg.sender);
        _updateBonus(msg.sender);
        _bonus = bonus[msg.sender];

        if (_bonus > 0) {
            bonus[msg.sender] = 0;
            multiplierPointsOf[msg.sender] += _bonus;
            totalBonus += _bonus;
            emit BonusPaid(msg.sender, _bonus);
        }
    }

    /// @notice The latest time at which stakers are earning bonus.
    function lastTimeBonusApplicable() public view returns (uint64) {
        return uint64(block.timestamp);
    }

    /// @notice The amount of bonus tokens each staked token has earned so far
    function bonusPerToken() external view returns (uint256) {
        return _bonusPerToken(lastTimeBonusApplicable());
    }

    /// @notice The amount of bonus tokens an account has accrued so far.
    function bonusOf(address _account) external view returns (uint256) {
        return _earnedBonus(_account, balanceOf[_account], _bonusPerToken(lastTimeBonusApplicable()), bonus[_account]);
    }

    function _earnedBonus(address account, uint256 accountBalance, uint256 bonusPerToken_, uint256 accountBonus)
        internal
        view
        returns (uint256)
    {
        return accountBalance.mulDivDown(bonusPerToken_ - userBonusPerTokenPaid[account], PRECISION) + accountBonus;
    }

    function _bonusPerToken(uint256 lastTimeBonusApplicable_) internal view returns (uint256) {
        return bonusPerTokenStored + (lastTimeBonusApplicable_ - lastBonusUpdateTime).mulDivDown(PRECISION, 365 days);
    }

    function _updateBonus(address _account) internal {
        // storage loads
        uint256 accountBalance = balanceOf[_account];
        uint64 lastTimeBonusApplicable_ = lastTimeBonusApplicable();
        uint256 bonusPerToken_ = _bonusPerToken(lastTimeBonusApplicable_);

        // accrue bonus
        bonusPerTokenStored = bonusPerToken_;
        lastBonusUpdateTime = lastTimeBonusApplicable_;
        bonus[_account] = _earnedBonus(_account, accountBalance, bonusPerToken_, bonus[_account]);
        userBonusPerTokenPaid[_account] = bonusPerToken_;
    }

    function _updateReward(address) internal virtual {}
}

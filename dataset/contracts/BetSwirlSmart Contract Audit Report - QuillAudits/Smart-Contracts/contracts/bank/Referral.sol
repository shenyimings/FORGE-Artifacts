// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import "hardhat/console.sol";

/// @title Multi-level referral program
/// @author Thundercore, customized by Romuald Hog
/// @dev All rates are in basis point.
contract Referral is AccessControl, Pausable {
    using SafeERC20 for IERC20;

    /// @notice The struct of account information.
    /// @param referrer The referrer addresss.
    /// @param referredCount The total referral amount of an address.
    /// @param lastActiveTimestamp The last active timestamp of an address.
    struct Account {
        address referrer;
        uint24 referredCount;
        uint32 lastActiveTimestamp;
    }

    /// @notice The struct of referee amount to bonus rate.
    /// @param lowerBound The minial referee amount.
    /// @param rate The bonus rate for each referee amount.
    struct RefereeBonusRate {
        uint16 lowerBound;
        uint16 rate;
    }

    /// @notice The bonus rate for each level.
    /// @dev The max depth is 3.
    uint16[3] public levelRate;

    /// @notice The seconds that a user does not update will be seen as inactive.
    uint24 public secondsUntilInactive;

    /// @notice The flag to enable not paying to inactive uplines.
    bool public onlyRewardActiveReferrers;

    /// @notice The bonus rate mapping to each referree amount. The max depth is 3.
    RefereeBonusRate[3] public refereeBonusRateMap;

    /// @notice Maps users addresses to tokens addresses to credits amount.
    mapping(address => mapping(address => uint256)) private _credits;

    /// @notice Maps users addresses to referrer account information.
    mapping(address => Account) private _accounts;

    /// @notice Role associated to Games smart contracts.
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    /// @notice Role associated to the Bank smart contracts.
    bytes32 public constant BANK_ROLE = keccak256("BANK_ROLE");

    /// @notice Emitted after the configuration is set.
    /// @param secondsUntilInactive The seconds that a user does not update will be seen as inactive.
    /// @param onlyRewardActiveReferrers The flag to enable not paying to inactive uplines.
    /// @param levelRate The bonus rate for each level.
    event SetReferral(
        uint24 secondsUntilInactive,
        bool onlyRewardActiveReferrers,
        uint16[3] levelRate
    );

    /// @notice Emitted after a bonus rate configuration is set.
    /// @param lowerBound Number of minimum referee to benefit the bonus rate.
    /// @param rate The bonus rate.
    event SetReferreeBonusRate(uint16 lowerBound, uint16 rate);

    /// @notice Emitted after setting the referrer of a referee.
    /// @param referee The address of the user
    /// @param referrer The address would set as referrer of user
    event RegisteredReferer(address indexed referee, address indexed referrer);

    /// @notice Emitted after referrer's activity.
    /// @param referrer The address of the user.
    /// @param lastActiveTimestamp The last active timestamp of the referrer.
    event SetLastActiveTimestamp(
        address indexed referrer,
        uint32 lastActiveTimestamp
    );

    /// @notice Emitted after adding credit to a referrer.
    /// @param user Address of the referrer.
    /// @param token Address of the token.
    /// @param amount Amount of credited tokens.
    /// @param level The referrer level.
    event AddReferralCredit(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint16 indexed level
    );

    /// @notice Emitted after the referrer withdraw credits.
    /// @param payee Address of the referrer.
    /// @param token Address of the token.
    /// @param amount Amount of credited tokens.
    event WithdrawnReferralCredit(
        address indexed payee,
        address indexed token,
        uint256 amount
    );

    /// @notice Referral level should be at least one, length not exceed 3, and total not exceed 100%.
    error WrongLevelRate();

    /// @notice One of referee bonus rate exceeds 100%.
    /// @param rate The referee bonus rate.
    error WrongRefereeBonusRate(uint16 rate);

    /// @notice Sets the Referral program configuration. c.f. `Referral._setReferral`.
    /// @param _secondsUntilInactive The seconds that a user does not update will be seen as inactive.
    /// @param _onlyRewardActiveReferrers The flag to enable not paying to inactive uplines.
    /// @param _levelRate The bonus rate for each level. The max depth is 3.
    /// @param _refereeBonusRateMap The bonus rate mapping to each referree amount. The max depth is 3.
    constructor(
        uint24 _secondsUntilInactive,
        bool _onlyRewardActiveReferrers,
        uint16[3] memory _levelRate,
        uint16[6] memory _refereeBonusRateMap
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setReferral(
            _secondsUntilInactive,
            _onlyRewardActiveReferrers,
            _levelRate,
            _refereeBonusRateMap
        );
    }

    receive() external payable {}

    /// @notice Gets the bonus rate based on the referred count.
    /// @param referredCount The number of referrees.
    /// @return The bonus rate.
    function _getRefereeBonusRate(uint24 referredCount)
        private
        view
        returns (uint16)
    {
        uint16 rate = refereeBonusRateMap[0].rate;
        uint256 refereeBonusRateMapLength = refereeBonusRateMap.length;
        for (uint8 i = 1; i < refereeBonusRateMapLength; i++) {
            RefereeBonusRate memory refereeBonusRate = refereeBonusRateMap[i];
            if (referredCount < refereeBonusRate.lowerBound) {
                break;
            }
            rate = refereeBonusRate.rate;
        }
        return rate;
    }

    /// @notice Checks whether the referee is one of referrer uplines.
    /// @param referrer Address of the referrer.
    /// @param referee Address of the referee.
    /// @return Whether the referee is already on referrer's upper levels.
    function _isCircularReference(address referrer, address referee)
        private
        view
        returns (bool)
    {
        address parent = referrer;
        uint256 levelRateLength = levelRate.length;
        for (uint8 i; i < levelRateLength; i++) {
            if (parent == address(0)) {
                break;
            }

            if (parent == referee) {
                return true;
            }

            parent = _accounts[parent].referrer;
        }

        return false;
    }

    /// @notice Sets the Referral program configuration.
    /// @param _secondsUntilInactive The seconds that a user does not update will be seen as inactive.
    /// @param _onlyRewardActiveReferrers The flag to enable not paying to inactive uplines.
    /// @param _levelRate The bonus rate for each level. The max depth is 3.
    /// @param _refereeBonusRateMap The bonus rate mapping to each referree amount. The max depth is 3.
    /// @dev The map should be pass as [<lower amount>, <rate>, ....]. For example, you should pass [1, 2500, 5, 5000, 10, 10000].
    ///
    ///  25%     50%     100%
    ///   | ----- | ----- |----->
    ///  1ppl    5ppl    10ppl
    ///
    /// @dev refereeBonusRateMap's lower amount should be ascending
    function setReferral(
        uint24 _secondsUntilInactive,
        bool _onlyRewardActiveReferrers,
        uint16[3] memory _levelRate,
        uint16[6] memory _refereeBonusRateMap
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 levelRateTotal;
        uint256 levelRateLength = _levelRate.length;
        for (uint8 i; i < levelRateLength; i++) {
            levelRateTotal += _levelRate[i];
        }
        if (levelRateTotal > 10000) {
            revert WrongLevelRate();
        }

        secondsUntilInactive = _secondsUntilInactive;
        onlyRewardActiveReferrers = _onlyRewardActiveReferrers;
        levelRate = _levelRate;

        emit SetReferral(
            secondsUntilInactive,
            onlyRewardActiveReferrers,
            levelRate
        );

        uint8 j;
        uint256 refereeBonusRateMapLength = _refereeBonusRateMap.length;
        for (uint8 i; i < refereeBonusRateMapLength; i += 2) {
            uint16 refereeBonusLowerBound = _refereeBonusRateMap[i];
            uint16 refereeBonusRate = _refereeBonusRateMap[i + 1];
            if (refereeBonusRate > 10000) {
                revert WrongRefereeBonusRate(refereeBonusRate);
            }
            refereeBonusRateMap[j] = RefereeBonusRate(
                refereeBonusLowerBound,
                refereeBonusRate
            );
            emit SetReferreeBonusRate(refereeBonusLowerBound, refereeBonusRate);
            j++;
        }
    }

    /// @notice Adds an address as referrer.
    /// @param user Address of the gamer.
    /// @param referrer The address would set as referrer of user.
    function addReferrer(address user, address referrer)
        external
        onlyRole(GAME_ROLE)
    {
        if (referrer == address(0)) {
            // Referrer cannot be 0x0 address
            return;
        } else if (_isCircularReference(referrer, user)) {
            // Referee cannot be one of referrer uplines
            return;
        } else if (_accounts[user].referrer != address(0)) {
            // Address have been registered upline
            return;
        }

        Account storage userAccount = _accounts[user];
        Account storage parentAccount = _accounts[referrer];

        userAccount.referrer = referrer;
        userAccount.lastActiveTimestamp = uint32(block.timestamp);
        parentAccount.referredCount += 1;

        emit RegisteredReferer(user, referrer);
    }

    /// @notice Calculates and allocate referrer(s) credits to uplines.
    /// @param user Address of the gamer to find referrer(s).
    /// @param token The token to allocate.
    /// @param amount The number of tokens allocated for referrer(s).
    function payReferral(
        address user,
        address token,
        uint256 amount
    ) external onlyRole(BANK_ROLE) returns (uint256) {
        uint256 totalReferral;
        Account memory userAccount = _accounts[user];

        if (userAccount.referrer != address(0)) {
            uint256 levelRateLength = levelRate.length;
            for (uint8 i; i < levelRateLength; i++) {
                address parent = userAccount.referrer;
                Account memory parentAccount = _accounts[parent];

                if (parent == address(0)) {
                    break;
                }

                if (
                    !onlyRewardActiveReferrers ||
                    (parentAccount.lastActiveTimestamp + secondsUntilInactive >=
                        block.timestamp)
                ) {
                    uint256 credit = (((amount * levelRate[i]) / 10000) *
                        _getRefereeBonusRate(parentAccount.referredCount)) /
                        10000;
                    totalReferral += credit;

                    _credits[parent][token] += credit;

                    emit AddReferralCredit(parent, token, credit, i + 1);
                }

                userAccount = parentAccount;
            }
        }
        return totalReferral;
    }

    /// @notice Updates referrer's last active timestamp.
    /// @param user Address of the gamer.
    function updateReferrerActivity(address user) external onlyRole(GAME_ROLE) {
        Account storage userAccount = _accounts[user];
        if (userAccount.referredCount > 0) {
            uint32 lastActiveTimestamp = uint32(block.timestamp);
            userAccount.lastActiveTimestamp = lastActiveTimestamp;
            emit SetLastActiveTimestamp(user, lastActiveTimestamp);
        }
    }

    /// @notice Referrer withdraw credits.
    /// @param tokens The tokens addresses.
    function withdrawCredits(address[] calldata tokens) external {
        address payable payee = payable(msg.sender);
        for (uint8 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 credit = _credits[payee][token];
            if (credit > 0) {
                _credits[payee][token] = 0;

                if (token == address(0)) {
                    Address.sendValue(payee, credit);
                } else {
                    IERC20(token).safeTransfer(payee, credit);
                }

                emit WithdrawnReferralCredit(payee, token, credit);
            }
        }
    }

    /// @notice Utils function for check whether an address has the referrer.
    /// @param user Address of the gamer.
    /// @return Whether user has a referrer.
    function hasReferrer(address user) external view returns (bool) {
        return _accounts[user].referrer != address(0);
    }

    /// @notice Gets the referrer's token credits.
    /// @param payee Address of the referrer.
    /// @param token Address of the token.
    /// @return The number of tokens available to withdraw.
    function referralCreditOf(address payee, address token)
        external
        view
        returns (uint256)
    {
        return _credits[payee][token];
    }

    /// @notice Gets the referrer's account information.
    /// @param user Address of the referrer.
    /// @return The account information.
    function getReferralAccount(address user)
        external
        view
        returns (Account memory)
    {
        return _accounts[user];
    }
}

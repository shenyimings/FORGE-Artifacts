// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "./libraries/EVMScriptCreator.sol";
import "./interfaces/IBokkyPooBahsDateTimeContract.sol";

import "OpenZeppelin/openzeppelin-contracts@4.3.2/contracts/access/AccessControl.sol";

/// @author zuzueeka
/// @notice Stores limits params and provides limit-enforcement logic
///
/// ▲ spendableBalance = limit-spentAmount
/// |
/// │             |................              |..               limit-spentAmount = limit-0 = limit
/// │.....        |                ...           |
/// │     ........|                   ......     |  ..............
///               |                         .....|
/// │─────────────────────────────────────────────────────────────> Time
/// |     ^       |                ^  ^     ^    |  ^              (^ - Motion enactment)
/// │             |currentPeriodEndTimestamp     |currentPeriodEndTimestamp
/// |             |spentAmount=0                 |spentAmount=0
///
/// currentPeriodEndTimestamp is calculated as a calendar date of the beginning of
/// a next month, bi-months, quarter, half year, or year period.
/// If, for example, periodDurationMonths = 3, then it is considered that the date changes once a quarter.
/// And currentPeriodEndTimestamp can take values 1 Apr, 1 Jul, 1 Oct, 1 Jan.
/// If periodDurationMonths = 1, then shift of currentPeriodEndTimestamp occurs once a month
/// and currentPeriodEndTimestamp can take values 1 Feb, 1 Mar, 1 Apr, etc
///
contract LimitsChecker is AccessControl {
    // -------------
    // EVENTS
    // -------------
    event LimitsParametersChanged(uint256 _limit, uint256 _periodDurationMonths);
    event SpendableAmountChanged(
        uint256 _alreadySpentAmount,
        uint256 _spendableBalance,
        uint256 indexed _periodStartTimestamp,
        uint256 _periodEndTimestamp
    );
    event CurrentPeriodAdvanced(uint256 indexed _periodStartTimestamp);
    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_INVALID_PERIOD_DURATION = "INVALID_PERIOD_DURATION";
    string private constant ERROR_SUM_EXCEEDS_SPENDABLE_BALANCE = "SUM_EXCEEDS_SPENDABLE_BALANCE";
    string private constant ERROR_TOO_LARGE_LIMIT = "TOO_LARGE_LIMIT";
    // -------------
    // ROLES
    // -------------
    bytes32 public constant SET_LIMIT_PARAMETERS_ROLE = keccak256("SET_LIMIT_PARAMETERS_ROLE");
    bytes32 public constant UPDATE_SPENT_AMOUNT_ROLE = keccak256("UPDATE_SPENT_AMOUNT_ROLE");

    // -------------
    // CONSTANTS
    // -------------

    // ------------
    // STORAGE VARIABLES
    // ------------

    /// @notice Address of BokkyPooBahsDateTimeContract
    IBokkyPooBahsDateTimeContract public immutable bokkyPooBahsDateTimeContract;

    /// @notice Length of period in months
    uint64 internal periodDurationMonths;

    /// @notice End of the current period
    uint128 internal currentPeriodEndTimestamp;

    /// @notice The maximum that can be spent in a period
    uint128 internal limit;

    /// @notice Amount already spent in the period
    uint128 internal spentAmount;

    // ------------
    // CONSTRUCTOR
    // ------------
    /// @param _setLimitParametersRoleHolders List of addresses which will
    ///     be granted with role SET_LIMIT_PARAMETERS_ROLE
    /// @param _updateSpentAmountRoleHolders List of addresses which will
    ///     be granted with role UPDATE_SPENT_AMOUNT_ROLE
    /// @param _bokkyPooBahsDateTimeContract Address of bokkyPooBahs DateTime Contract
    constructor(
        address[] memory _setLimitParametersRoleHolders,
        address[] memory _updateSpentAmountRoleHolders,
        IBokkyPooBahsDateTimeContract _bokkyPooBahsDateTimeContract
    ) {
        for (uint256 i = 0; i < _setLimitParametersRoleHolders.length; i++) {
            _setupRole(SET_LIMIT_PARAMETERS_ROLE, _setLimitParametersRoleHolders[i]);
        }
        for (uint256 i = 0; i < _updateSpentAmountRoleHolders.length; i++) {
            _setupRole(UPDATE_SPENT_AMOUNT_ROLE, _updateSpentAmountRoleHolders[i]);
        }
        bokkyPooBahsDateTimeContract = _bokkyPooBahsDateTimeContract;
    }

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Checks if _payoutAmount is less or equal than the may be spent
    /// @param _payoutAmount Motion total amount
    /// @param _motionDuration Motion duration - minimal time required to pass before enacting of motion
    /// @return True if _payoutAmount is less or equal than may be spent
    /// @dev note that upfront check is used to compare _paymentSum with total limit in case
    /// when motion is started in one period and will be probably enacted in the next.
    function isUnderSpendableBalance(uint256 _payoutAmount, uint256 _motionDuration)
        external
        view
        returns (bool)
    {
        if (block.timestamp + _motionDuration >= currentPeriodEndTimestamp) {
            return _payoutAmount <= limit;
        } else {
            return _payoutAmount <= _spendableBalance(limit, spentAmount);
        }
    }

    /// @notice Checks if _payoutAmount may be spent and increases spentAmount on _payoutAmount.
    /// @notice Also updates the period boundaries if necessary.
    function updateSpentAmount(uint256 _payoutAmount) external onlyRole(UPDATE_SPENT_AMOUNT_ROLE) {
        uint256 spentAmountLocal = spentAmount;
        uint256 limitLocal = limit;
        uint256 currentPeriodEndTimestampLocal = currentPeriodEndTimestamp;

        /// When it is necessary to shift the currentPeriodEndTimestamp it takes on a new value.
        /// And also spent is set to zero. Thus begins a new period.
        if (block.timestamp >= currentPeriodEndTimestampLocal) {
            currentPeriodEndTimestampLocal = _getPeriodEndFromTimestamp(block.timestamp);
            spentAmountLocal = 0;
            emit CurrentPeriodAdvanced(
                _getPeriodStartFromTimestamp(currentPeriodEndTimestampLocal - 1)
            );
            currentPeriodEndTimestamp = uint128(currentPeriodEndTimestampLocal);
        }

        require(
            _payoutAmount <= _spendableBalance(limitLocal, spentAmountLocal),
            ERROR_SUM_EXCEEDS_SPENDABLE_BALANCE
        );
        spentAmountLocal += _payoutAmount;
        spentAmount = uint128(spentAmountLocal);

        (
            uint256 alreadySpentAmount,
            uint256 spendableBalanceInPeriod,
            uint256 periodStartTimestamp,
            uint256 periodEndTimestamp
        ) = _getCurrentPeriodState(limitLocal, spentAmountLocal, currentPeriodEndTimestampLocal);

        emit SpendableAmountChanged(
            alreadySpentAmount,
            spendableBalanceInPeriod,
            periodStartTimestamp,
            periodEndTimestamp
        );
    }

    /// @notice Returns balance that can be spent in the current period
    /// @notice If period advanced and no call to updateSpentAmount or setLimitParameters made,
    /// @notice then the method will return spendable balance corresponding to the previous period.
    /// @return Balance that can be spent in the current period
    function spendableBalance() external view returns (uint256) {
        return _spendableBalance(limit, spentAmount);
    }

    /// @notice Sets periodDurationMonths and limit
    /// @notice Calculates currentPeriodEndTimestamp as a calendar date of the beginning of next period.
    /// @param _limit Limit to set
    /// @param _periodDurationMonths Length of period in months. Must be 1, 2, 3, 6 or 12.
    function setLimitParameters(uint256 _limit, uint256 _periodDurationMonths)
        external
        onlyRole(SET_LIMIT_PARAMETERS_ROLE)
    {
        require(_limit <= type(uint128).max, ERROR_TOO_LARGE_LIMIT);

        _validatePeriodDurationMonths(_periodDurationMonths);
        periodDurationMonths = uint64(_periodDurationMonths);
        uint256 currentPeriodEndTimestampLocal = _getPeriodEndFromTimestamp(block.timestamp);
        emit CurrentPeriodAdvanced(
            _getPeriodStartFromTimestamp(currentPeriodEndTimestampLocal - 1)
        );
        currentPeriodEndTimestamp = uint128(currentPeriodEndTimestampLocal);
        limit = uint128(_limit);

        /// set spent to _limit if it's greater to avoid math underflow error
        if (spentAmount > _limit) {
            spentAmount = uint128(_limit);
        }

        emit LimitsParametersChanged(_limit, _periodDurationMonths);
    }

    /// @notice Returns limit and periodDurationMonths
    /// @return limit - the maximum that can be spent in a period
    /// @return periodDurationMonths - length of period in months
    function getLimitParameters() external view returns (uint256, uint256) {
        return (limit, periodDurationMonths);
    }

    /// @notice Returns state of the current period: amount spent, balance available for spending,
    /// @notice start date of the current period and end date of the current period
    /// @notice If period advanced and the period was not shifted,
    /// @notice then the method will return spendable balance corresponding to the previous period.
    /// @return _alreadySpentAmount - amount already spent in the current period
    /// @return _spendableBalanceInPeriod - balance available for spending in the current period
    /// @return _periodStartTimestamp - start date of the current period
    /// @return _periodEndTimestamp - end date of the current period
    function getPeriodState()
        external
        view
        returns (
            uint256 _alreadySpentAmount,
            uint256 _spendableBalanceInPeriod,
            uint256 _periodStartTimestamp,
            uint256 _periodEndTimestamp
        )
    {
        return _getCurrentPeriodState(limit, spentAmount, currentPeriodEndTimestamp);
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------
    function _getCurrentPeriodState(
        uint256 _limit,
        uint256 _spentAmount,
        uint256 _currentPeriodEndTimestamp
    )
        internal
        view
        returns (
            uint256 _alreadySpentAmount,
            uint256 _spendableBalanceInPeriod,
            uint256 _periodStartTimestamp,
            uint256 _periodEndTimestamp
        )
    {
        return (
            _spentAmount,
            _spendableBalance(_limit, _spentAmount),
            _getPeriodStartFromTimestamp(_currentPeriodEndTimestamp - 1),
            _currentPeriodEndTimestamp
        );
    }

    function _spendableBalance(uint256 _limit, uint256 _spentAmount)
        internal
        pure
        returns (uint256)
    {
        return _limit - _spentAmount;
    }

    function _validatePeriodDurationMonths(uint256 _periodDurationMonths) internal pure {
        require(
            _periodDurationMonths == 1 ||
                _periodDurationMonths == 2 ||
                _periodDurationMonths == 3 ||
                _periodDurationMonths == 6 ||
                _periodDurationMonths == 12,
            ERROR_INVALID_PERIOD_DURATION
        );
    }

    function _getPeriodStartFromTimestamp(uint256 _timestamp) internal view returns (uint256) {
        // Get year and number of month of the timestamp:
        (uint256 year, uint256 month, ) = bokkyPooBahsDateTimeContract.timestampToDate(_timestamp);
        // We assume that the year will remain the same,
        // because the beginning of the current calendar period will necessarily be in the same year.
        uint256 periodStartYear = year;
        // Get the number of the start date month:
        uint256 periodStartMonth = _getFirstMonthInPeriodFromMonth(month, periodDurationMonths);
        // The beginning of the period always matches the calendar date of the beginning of the month.
        uint256 periodStartDay = 1;
        return
            bokkyPooBahsDateTimeContract.timestampFromDate(
                periodStartYear,
                periodStartMonth,
                periodStartDay
            );
    }

    function _getFirstMonthInPeriodFromMonth(uint256 _month, uint256 _periodDurationMonths)
        internal
        pure
        returns (uint256 _firstMonthInPeriod)
    {
        require(_periodDurationMonths != 0, ERROR_INVALID_PERIOD_DURATION);

        // To get the number of the first month in the period:
        //   1. get the number of the period within the current year, starting from its beginning:
        uint256 periodNumber = (_month - 1) / _periodDurationMonths;
        //   2. and then the number of the first month in this period:
        _firstMonthInPeriod = periodNumber * _periodDurationMonths + 1;
        // The shift by - 1 and then by + 1 happens because the months in the calendar start from 1 and not from 0.
    }

    function _getPeriodEndFromTimestamp(uint256 _timestamp) internal view returns (uint256) {
        uint256 periodStart = _getPeriodStartFromTimestamp(_timestamp);
        return bokkyPooBahsDateTimeContract.addMonths(periodStart, periodDurationMonths);
    }
}

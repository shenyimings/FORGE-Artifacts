pragma solidity ^0.5.17;

import "../lib/math/SafeMath.sol";
import "../lib/math/SafeMath64.sol";
import "../lib/utils/PctHelpers.sol";
import "../lib/utils/SafeERC20.sol";
import "../lib/utils/TimeHelpers.sol";
import "../lib/standards/IERC20.sol";

import "./IPaymentsBook.sol";
import "../registry/IGuardiansRegistry.sol";
import "../core/modules/Controller.sol";
import "../core/modules/ControlledRecoverable.sol";


contract PaymentsBook is IPaymentsBook, ControlledRecoverable, TimeHelpers {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeMath64 for uint64;
    using PctHelpers for uint256;

    string private constant ERROR_PROTOCOL_HAS_NOT_STARTED = "PB_PROTOCOL_HAS_NOT_STARTED";
    string private constant ERROR_NON_PAST_PERIOD = "PB_NON_PAST_PERIOD";
    string private constant ERROR_PERIOD_DURATION_ZERO = "PB_PERIOD_DURATION_ZERO";
    string private constant ERROR_PERIOD_BALANCE_DETAILS_NOT_COMPUTED = "PB_PER_BAL_DETAILS_NOT_COMPUTED";
    string private constant ERROR_PAYMENT_AMOUNT_ZERO = "PB_PAYMENT_AMOUNT_ZERO";
    string private constant ERROR_ETH_DEPOSIT_TOKEN_MISMATCH = "PB_ETH_DEPOSIT_TOKEN_MISMATCH";
    string private constant ERROR_ETH_DEPOSIT_AMOUNT_MISMATCH = "PB_ETH_DEPOSIT_AMOUNT_MISMATCH";
    string private constant ERROR_ETH_TRANSFER_FAILED = "PB_ETH_TRANSFER_FAILED";
    string private constant ERROR_TOKEN_NOT_CONTRACT = "PB_TOKEN_NOT_CONTRACT";
    string private constant ERROR_TOKEN_DEPOSIT_FAILED = "PB_TOKEN_DEPOSIT_FAILED";
    string private constant ERROR_TOKEN_TRANSFER_FAILED = "PB_TOKEN_TRANSFER_FAILED";
    string private constant ERROR_GUARDIAN_SHARE_ALREADY_CLAIMED = "PB_GUARDIAN_SHARE_ALREADY_CLAIMED";
    string private constant ERROR_GOVERNOR_SHARE_ALREADY_CLAIMED = "PB_GOVERNOR_SHARE_ALREADY_CLAIMED";
    string private constant ERROR_OVERRATED_GOVERNOR_SHARE_PCT = "PB_OVERRATED_GOVERNOR_SHARE_PCT";

    // Term 0 is for guardians on-boarding
    uint64 internal constant START_TERM_ID = 1;

    struct Period {
        // Protocol term ID of a period used to fetch the total active balance of the guardians registry
        uint64 balanceCheckpoint;
        // Total amount of guardian tokens active in the Protocol at the corresponding period checkpoint
        uint256 totalActiveBalance;
        // List of collected amounts for the governor indexed by token address
        mapping (address => uint256) governorShares;
        // List of tokens claimed by the governor during a period, indexed by token addresses
        mapping (address => bool) claimedGovernor;
        // List of collected amounts for the guardians indexed by token address
        mapping (address => uint256) guardiansShares;
        // List of guardians that have claimed their share during a period, indexed by guardian and token addresses
        mapping (address => mapping (address => bool)) claimedGuardians;
    }

    // Duration of a payment period in Protocol terms
    uint64 public periodDuration;

    // Permyriad of collected payments that will be allocated to the governor of the Protocol (‱ - 1/10,000)
    uint16 public governorSharePct;

    // List of periods indexed by ID
    mapping (uint256 => Period) internal periods;

    event PaymentReceived(uint256 indexed periodId, address indexed payer, address indexed token, uint256 amount, bytes data);
    event GuardianShareClaimed(uint256 indexed periodId, address indexed guardian, address indexed token, uint256 amount);
    event GovernorShareClaimed(uint256 indexed periodId, address indexed token, uint256 amount);
    event GovernorSharePctChanged(uint16 previousGovernorSharePct, uint16 currentGovernorSharePct);

    /**
    * @dev Initialize protocol payments book
    * @param _controller Address of the controller
    * @param _periodDuration Duration of a payment period in Protocol terms
    * @param _governorSharePct Initial permyriad of collected payments that will be allocated to the governor of the Protocol (‱ - 1/10,000)
    */
    constructor(Controller _controller, uint64 _periodDuration, uint16 _governorSharePct) Controlled(_controller) public {
        require(_periodDuration > 0, ERROR_PERIOD_DURATION_ZERO);

        periodDuration = _periodDuration;
        _setGovernorSharePct(_governorSharePct);
    }

    /**
    * @notice Pay `@tokenAmount(_token, _amount)` for `_payer` (`_data`)
    * @param _token Address of the token being paid
    * @param _amount Amount of tokens being paid
    * @param _payer Address paying on behalf of
    * @param _data Optional data
    */
    function pay(address _token, uint256 _amount, address _payer, bytes calldata _data) external payable {
        (uint256 periodId, Period storage period) = _getCurrentPeriod();
        require(_amount > 0, ERROR_PAYMENT_AMOUNT_ZERO);

        // Update collected amount for the governor
        uint256 governorShare = _amount.pct(governorSharePct);
        period.governorShares[_token] = period.governorShares[_token].add(governorShare);

        // Update collected amount for the guardians
        uint256 guardiansShare = _amount.sub(governorShare);
        period.guardiansShares[_token] = period.guardiansShares[_token].add(guardiansShare);

        // Deposit funds from sender to this contract
        // ETH or token amount checks are handled in `_deposit()`
        _deposit(msg.sender, _token, _amount);
        emit PaymentReceived(periodId, _payer, _token, _amount, _data);
    }

    /**
    * @notice Claim guardian share for period #`_periodId` owed to `_guardian`
    * @dev It will ignore tokens that were already claimed without reverting
    * @param _periodId Identification number of the period being claimed
    * @param _guardian Address of the guardian claiming the shares for
    * @param _tokens List of token addresses to be claimed
    */
    function claimGuardianShare(uint256 _periodId, address payable _guardian, address[] calldata _tokens)
        external
        authenticateSender(_guardian)
    {
        require(_periodId < _getCurrentPeriodId(), ERROR_NON_PAST_PERIOD);

        Period storage period = periods[_periodId];
        (uint64 periodBalanceCheckpoint, uint256 totalActiveBalance) = _ensurePeriodBalanceDetails(period, _periodId);
        uint256 guardianActiveBalance = _getGuardianActiveBalance(_guardian, periodBalanceCheckpoint);

        // We assume the token contract is not malicious
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            require(!_hasGuardianClaimed(period, _guardian, token), ERROR_GUARDIAN_SHARE_ALREADY_CLAIMED);
            uint256 amount = _getGuardianShare(period, token, guardianActiveBalance, totalActiveBalance);
            _claimGuardianShare(period, _periodId, _guardian, token, amount);
        }
    }

    /**
    * @notice Transfer owed share to the governor for period #`_periodId`
    * @param _periodId Identification number of the period being claimed
    * @param _tokens List of token addresses to be claimed
    */
    function claimGovernorShare(uint256 _periodId, address[] calldata _tokens) external {
        require(_periodId < _getCurrentPeriodId(), ERROR_NON_PAST_PERIOD);

        Period storage period = periods[_periodId];
        address payable governor = address(uint160(_configGovernor()));

        // We assume the token contract is not malicious
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            require(!_hasGovernorClaimed(period, token), ERROR_GOVERNOR_SHARE_ALREADY_CLAIMED);
            _claimGovernorShare(period, _periodId, governor, token);
        }
    }

    /**
    * @notice Make sure that the balance details of a certain period have been computed
    * @param _periodId Identification number of the period being ensured
    * @return periodBalanceCheckpoint Protocol term ID used to fetch the total active balance of the guardians registry
    * @return totalActiveBalance Total amount of guardian tokens active in the Protocol at the corresponding used checkpoint
    */
    function ensurePeriodBalanceDetails(uint256 _periodId) external returns (uint64 periodBalanceCheckpoint, uint256 totalActiveBalance) {
        require(_periodId < _getCurrentPeriodId(), ERROR_NON_PAST_PERIOD);
        Period storage period = periods[_periodId];
        return _ensurePeriodBalanceDetails(period, _periodId);
    }

    /**
    * @notice Set new governor share to `_governorSharePct`‱ (1/10,000)
    * @param _governorSharePct New permyriad of collected payments that will be allocated to the governor of the Protocol (‱ - 1/10,000)
    */
    function setGovernorSharePct(uint16 _governorSharePct) external onlyConfigGovernor {
        _setGovernorSharePct(_governorSharePct);
    }

    /**
    * @dev Tell the identification number of the current period
    * @return Identification number of the current period
    */
    function getCurrentPeriodId() external view returns (uint256) {
        return _getCurrentPeriodId();
    }

    /**
    * @dev Get the share details of a payment period
    * @param _periodId Identification number of the period to be queried
    * @param _token Address of the token querying the share details for
    * @return guardiansShare Guardians share for the requested period and token
    * @return governorShare Governor share for the requested period and token
    */
    function getPeriodShares(uint256 _periodId, address _token)
        external
        view
        returns (uint256 guardiansShare, uint256 governorShare)
    {
        Period storage period = periods[_periodId];
        guardiansShare = period.guardiansShares[_token];
        governorShare = period.governorShares[_token];
    }

    /**
    * @dev Get the balance details of a payment period
    * @param _periodId Identification number of the period to be queried
    * @return balanceCheckpoint Protocol term ID of a period used to fetch the total active balance of the guardians registry
    * @return totalActiveBalance Total amount of guardian tokens active in the Protocol at the corresponding period checkpoint
    */
    function getPeriodBalanceDetails(uint256 _periodId)
        external
        view
        returns (uint64 balanceCheckpoint, uint256 totalActiveBalance)
    {
        Period storage period = periods[_periodId];
        balanceCheckpoint = period.balanceCheckpoint;
        totalActiveBalance = period.totalActiveBalance;
    }

    /**
    * @dev Tell the share corresponding to a guardian for a certain period
    * @param _periodId Identification number of the period being queried
    * @param _guardian Address of the guardian querying the share of
    * @param _tokens List of token addresses to be queried
    * @return List of token amounts corresponding to the guardian
    */
    function getGuardianShare(uint256 _periodId, address _guardian, address[] calldata _tokens)
        external
        view
        returns (uint256[] memory amounts)
    {
        require(_periodId < _getCurrentPeriodId(), ERROR_NON_PAST_PERIOD);

        Period storage period = periods[_periodId];
        uint256 totalActiveBalance = period.totalActiveBalance;
        require(totalActiveBalance != 0, ERROR_PERIOD_BALANCE_DETAILS_NOT_COMPUTED);

        amounts = new uint256[](_tokens.length);
        uint256 guardianActiveBalance = _getGuardianActiveBalance(_guardian, period.balanceCheckpoint);
        for (uint256 i = 0; i < _tokens.length; i++) {
            amounts[i] = _getGuardianShare(period, _tokens[i], guardianActiveBalance, totalActiveBalance);
        }
    }

    /**
    * @dev Tell if a given guardian has already claimed the owed share for a certain period
    * @param _periodId Identification number of the period being queried
    * @param _guardian Address of the guardian being queried
    * @param _tokens List of token addresses to be queried
    * @return List of claimed status for each requested token
    */
    function hasGuardianClaimed(uint256 _periodId, address _guardian, address[] calldata _tokens)
        external
        view
        returns (bool[] memory claimed)
    {
        Period storage period = periods[_periodId];

        claimed = new bool[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            claimed[i] = _hasGuardianClaimed(period, _guardian, _tokens[i]);
        }
    }

    /**
    * @dev Tell the share corresponding to the governor for a certain period
    * @param _periodId Identification number of the period being queried
    * @param _tokens List of token addresses to be queried
    * @return List of token amounts corresponding to the governor
    */
    function getGovernorShare(uint256 _periodId, address[] calldata _tokens) external view returns (uint256[] memory amounts) {
        Period storage period = periods[_periodId];

        amounts = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            amounts[i] = _getGovernorShare(period, _tokens[i]);
        }
    }

    /**
    * @dev Tell if the governor has already claimed the owed share for a certain period
    * @param _periodId Identification number of the period being queried
    * @param _tokens List of token addresses to be queried
    * @return List of claimed status for each requested token
    */
    function hasGovernorClaimed(uint256 _periodId, address[] calldata _tokens)
        external
        view
        returns (bool[] memory claimed)
    {
        Period storage period = periods[_periodId];

        claimed = new bool[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            claimed[i] = _hasGovernorClaimed(period, _tokens[i]);
        }
    }

    /**
    * @dev Internal function to claim guardian share for a certain period
    * @param _period Period being claimed
    * @param _periodId Identification number of the period being claimed
    * @param _guardian Address of the guardian claiming their share
    * @param _token Address of the token being claimed
    * @param _amount Amount of tokens to be transferred to the guardian
    */
    function _claimGuardianShare(
        Period storage _period,
        uint256 _periodId,
        address payable _guardian,
        address _token,
        uint256 _amount
    )
        internal
    {
        _period.claimedGuardians[_guardian][_token] = true;
        if (_amount > 0) {
            _transfer(_guardian, _token, _amount);
            emit GuardianShareClaimed(_periodId, _guardian, _token, _amount);
        }
    }

    /**
    * @dev Internal function to transfer governor share for a certain period
    * @param _period Period being claimed
    * @param _periodId Identification number of the period being claimed
    * @param _token Address of the token to be claimed
    */
    function _claimGovernorShare(Period storage _period, uint256 _periodId, address payable _governor, address _token) internal {
        _period.claimedGovernor[_token] = true;
        uint256 amount = _getGovernorShare(_period, _token);
        if (amount > 0) {
            _transfer(_governor, _token, amount);
            emit GovernorShareClaimed(_periodId, _token, amount);
        }
    }

    /**
    * @dev Internal function to pull tokens into this contract
    * @param _from Owner of the deposited funds
    * @param _token Address of the token to deposit
    * @param _amount Amount to be deposited
    */
    function _deposit(address _from, address _token, uint256 _amount) internal {
        if (msg.value > 0) {
            require(_token == address(0), ERROR_ETH_DEPOSIT_TOKEN_MISMATCH);
            require(msg.value == _amount, ERROR_ETH_DEPOSIT_AMOUNT_MISMATCH);
        } else {
            require(isContract(_token), ERROR_TOKEN_NOT_CONTRACT);
            require(IERC20(_token).safeTransferFrom(_from, address(this), _amount), ERROR_TOKEN_DEPOSIT_FAILED);
        }
    }

    /**
    * @dev Internal function to transfer tokens
    * @param _to Recipient of the transfer
    * @param _token Address of the token to transfer
    * @param _amount Amount to be transferred
    */
    function _transfer(address payable _to, address _token, uint256 _amount) internal {
        if (_token == address(0)) {
            require(_to.send(_amount), ERROR_ETH_TRANSFER_FAILED);
        } else {
            require(IERC20(_token).safeTransfer(_to, _amount), ERROR_TOKEN_TRANSFER_FAILED);
        }
    }

    /**
    * @dev Internal function to make sure that the balance details of a certain period have been computed.
    *      This function assumes given ID and period correspond to each other, and that the period is in the past.
    * @param _periodId Identification number of the period being ensured
    * @param _period Period being ensured
    * @return Protocol term ID used to fetch the total active balance of the guardians registry
    * @return Total amount of guardian tokens active in the Protocol at the corresponding used checkpoint
    */
    function _ensurePeriodBalanceDetails(Period storage _period, uint256 _periodId) internal returns (uint64, uint256) {
        // Shortcut if the period balance details were already set
        uint256 totalActiveBalance = _period.totalActiveBalance;
        if (totalActiveBalance != 0) {
            return (_period.balanceCheckpoint, totalActiveBalance);
        }

        uint64 periodStartTermId = _getPeriodStartTermId(_periodId);
        uint64 nextPeriodStartTermId = _getPeriodStartTermId(_periodId.add(1));

        // Pick a random Protocol term during the next period of the requested one to get the total amount of guardian tokens active in the Protocol
        IClock clock = _clock();
        bytes32 randomness = clock.getTermRandomness(nextPeriodStartTermId);

        // The randomness factor for each Protocol term is computed using the the hash of a block number set during the initialization of the
        // term, to ensure it cannot be known beforehand. Note that the hash function being used only works for the 256 most recent block
        // numbers. Therefore, if that occurs we use the hash of the previous block number. This could be slightly beneficial for the first
        // guardian calling this function, but it's still impossible to predict during the requested period.
        if (randomness == bytes32(0)) {
            randomness = blockhash(getBlockNumber() - 1);
        }

        // Use randomness to choose a Protocol term of the requested period and query the total amount of guardian tokens active at that term
        IGuardiansRegistry guardiansRegistry = _guardiansRegistry();
        uint64 periodBalanceCheckpoint = periodStartTermId.add(uint64(uint256(randomness) % periodDuration));
        totalActiveBalance = guardiansRegistry.totalActiveBalanceAt(periodBalanceCheckpoint);

        _period.balanceCheckpoint = periodBalanceCheckpoint;
        _period.totalActiveBalance = totalActiveBalance;
        return (periodBalanceCheckpoint, totalActiveBalance);
    }

    /**
    * @dev Internal function to set a new governor share value
    * @param _governorSharePct New permyriad of collected payments that will be allocated to the governor of the Protocol (‱ - 1/10,000)
    */
    function _setGovernorSharePct(uint16 _governorSharePct) internal {
        // Check governor share is not greater than 10,000‱
        require(PctHelpers.isValid(_governorSharePct), ERROR_OVERRATED_GOVERNOR_SHARE_PCT);

        emit GovernorSharePctChanged(governorSharePct, _governorSharePct);
        governorSharePct = _governorSharePct;
    }

    /**
    * @dev Internal function to tell the identification number of the current period
    * @return Identification number of the current period
    */
    function _getCurrentPeriodId() internal view returns (uint256) {
        // Since the Protocol starts at term #1, and the first payment period is #0, then subtract one unit to the current term of the Protocol
        uint64 termId = _getCurrentTermId();
        require(termId > 0, ERROR_PROTOCOL_HAS_NOT_STARTED);

        // No need for SafeMath: we already checked that the term ID is at least 1
        uint64 periodId = (termId - START_TERM_ID) / periodDuration;
        return uint256(periodId);
    }

    /**
    * @dev Internal function to get the current period
    * @return periodId Identification number of the current period
    * @return period Current period instance
    */
    function _getCurrentPeriod() internal view returns (uint256 periodId, Period storage period) {
        periodId = _getCurrentPeriodId();
        period = periods[periodId];
    }

    /**
    * @dev Internal function to get the Protocol term in which a certain period starts
    * @param _periodId Identification number of the period querying the start term of
    * @return Protocol term where the given period starts
    */
    function _getPeriodStartTermId(uint256 _periodId) internal view returns (uint64) {
        // Periods are measured in Protocol terms
        // Since Protocol terms are represented in uint64, we are safe to use uint64 for period ids too
        return START_TERM_ID.add(uint64(_periodId).mul(periodDuration));
    }

    /**
    * @dev Internal function to tell the active balance of a guardian for a certain period
    * @param _guardian Address of the guardian querying the share of
    * @param _periodBalanceCheckpoint Checkpoint of the period being queried
    * @return Active balance for a guardian based on the period checkpoint
    */
    function _getGuardianActiveBalance(address _guardian, uint64 _periodBalanceCheckpoint) internal view returns (uint256) {
        IGuardiansRegistry guardiansRegistry = _guardiansRegistry();
        return guardiansRegistry.activeBalanceOfAt(_guardian, _periodBalanceCheckpoint);
    }

    /**
    * @dev Internal function to tell the share corresponding to a guardian for a certain period and token
    * @param _period Period being queried
    * @param _token Address of the token being queried
    * @param _guardianActiveBalance Active balance of a guardian at the corresponding period checkpoint
    * @param _totalActiveBalance Total amount of guardian tokens active in the Protocol at the corresponding period checkpoint
    * @return Share owed to the given guardian for the requested period and token
    */
    function _getGuardianShare(
        Period storage _period,
        address _token,
        uint256 _guardianActiveBalance,
        uint256 _totalActiveBalance
    )
        internal
        view
        returns (uint256)
    {
        if (_guardianActiveBalance == 0) {
            return 0;
        }

        // Note that we already checked the guardian active balance is greater than zero.
        // Then, the total active balance should be greater than zero.
        return _period.guardiansShares[_token].mul(_guardianActiveBalance) / _totalActiveBalance;
    }

    /**
    * @dev Tell if a guardian has already claimed the owed share for a certain period
    * @param _period Period being queried
    * @param _guardian Address of the guardian being queried
    * @param _token Address of the token to be queried
    * @return True if the guardian has already claimed their share
    */
    function _hasGuardianClaimed(Period storage _period, address _guardian, address _token) internal view returns (bool) {
        return _period.claimedGuardians[_guardian][_token];
    }

    /**
    * @dev Tell the share corresponding to a guardian for a certain period
    * @param _period Period being queried
    * @param _token Address of the token to be queried
    * @return Token amount corresponding to the governor
    */
    function _getGovernorShare(Period storage _period, address _token) internal view returns (uint256) {
        return _period.governorShares[_token];
    }

    /**
    * @dev Tell if the governor has already claimed the owed share for a certain period
    * @param _period Period being queried
    * @param _token Address of the token to be queried
    * @return True if the governor has already claimed their share
    */
    function _hasGovernorClaimed(Period storage _period, address _token) internal view returns (bool) {
        return _period.claimedGovernor[_token];
    }
}

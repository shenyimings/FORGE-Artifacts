pragma solidity 0.8.11;

import "./dependencies/Ownable.sol";
import "./dependencies/SafeERC20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/solidex/ITokenLocker.sol";


contract FeeDistributor is Ownable {
    using SafeERC20 for IERC20;

    struct StreamData {
        uint256 start;
        uint256 amount;
        uint256 claimed;
    }

    // Fees are transferred into this contract as they are collected, and in the same tokens
    // that they are collected in. The total amount collected each week is recorded in
    // `weeklyFeeAmounts`. At the end of a week, the fee amounts are streamed out over
    // the following week based on each user's lock weight at the end of that week. Data
    // about the active stream for each token is tracked in `activeUserStream`

    // fee token -> week -> total amount received that week
    mapping(address => mapping(uint256 => uint256)) public weeklyFeeAmounts;
    // user -> fee token -> data about the active stream
    mapping(address => mapping(address => StreamData)) activeUserStream;

    // array of all fee tokens that have been added
    address[] public feeTokens;
    // private mapping for tracking which addresses were added to `feeTokens`
    mapping(address => bool) seenFees;

    ITokenLocker public tokenLocker;
    uint256 public startTime;

    uint256 constant WEEK = 86400 * 7;

    event FeesReceived(
        address indexed caller,
        address indexed token,
        uint256 indexed week,
        uint256 amount
    );
    event FeesClaimed(
        address indexed caller,
        address indexed receiver,
        address indexed token,
        uint256 amount
    );

    function setAddresses(ITokenLocker _tokenLocker) external onlyOwner {
        tokenLocker = _tokenLocker;
        startTime = _tokenLocker.startTime();

        renounceOwnership();
    }

    function getWeek() public view returns (uint256) {
        if (startTime == 0) return 0;
        return (block.timestamp - startTime) / 604800;
    }

    function feeTokensLength() external view returns (uint) {
        return feeTokens.length;
    }

    /**
        @notice Deposit protocol fees into the contract, to be distributed to lockers
        @dev Caller must have given approval for this contract to transfer `_token`
        @param _token Token being deposited
        @param _amount Amount of the token to deposit
     */
    function depositFee(address _token, uint256 _amount)
        external
        returns (bool)
    {
        if (_amount > 0) {
            if (!seenFees[_token]) {
                seenFees[_token] = true;
                feeTokens.push(_token);
            }
            uint256 received = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            received = IERC20(_token).balanceOf(address(this)) - received;
            uint256 week = getWeek();
            weeklyFeeAmounts[_token][week] += received;
            emit FeesReceived(msg.sender, _token, week, _amount);
        }
        return true;
    }

    /**
        @notice Get an array of claimable amounts of different tokens accrued from protocol fees
        @param _user Address to query claimable amounts for
        @param _tokens List of tokens to query claimable amounts of
     */
    function claimable(address _user, address[] calldata _tokens)
        external
        view
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            (amounts[i], ) = _getClaimable(_user, _tokens[i]);
        }
        return amounts;
    }

    /**
        @notice Claim accrued protocol fees according to a locked balance in `TokenLocker`.
        @dev Fees are claimable up to the end of the previous week. Claimable fees from more
             than one week ago are released immediately, fees from the previous week are streamed.
        @param _user Address to claim for. Any account can trigger a claim for any other account.
        @param _tokens Array of tokens to claim for.
        @return claimedAmounts Array of amounts claimed.
     */
    function claim(address _user, address[] calldata _tokens)
        external
        returns (uint256[] memory claimedAmounts)
    {
        claimedAmounts = new uint256[](_tokens.length);
        StreamData memory stream;
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            (claimedAmounts[i], stream) = _getClaimable(_user, token);
            activeUserStream[_user][token] = stream;
            IERC20(token).safeTransfer(_user, claimedAmounts[i]);
            emit FeesClaimed(msg.sender, _user, token, claimedAmounts[i]);
        }
        return claimedAmounts;
    }

    function _getClaimable(address _user, address _token)
        internal
        view
        returns (uint256, StreamData memory)
    {
        uint256 claimableWeek = getWeek();

        if (claimableWeek == 0) {
            // the first full week hasn't completed yet
            return (0, StreamData({start: startTime, amount: 0, claimed: 0}));
        }

        // the previous week is the claimable one
        claimableWeek -= 1;
        StreamData memory stream = activeUserStream[_user][_token];
        uint256 lastClaimWeek;
        if (stream.start == 0) {
            lastClaimWeek = 0;
        } else {
            lastClaimWeek = (stream.start - startTime) / WEEK;
        }

        uint256 amount;
        if (claimableWeek == lastClaimWeek) {
            // special case: claim is happening in the same week as a previous claim
            uint256 previouslyClaimed = stream.claimed;
            stream = _buildStreamData(_user, _token, claimableWeek);
            amount = stream.claimed - previouslyClaimed;
            return (amount, stream);
        }

        if (stream.start > 0) {
            // if there is a partially claimed week, get the unclaimed amount and increment
            // `lastClaimWeeek` so we begin iteration on the following week
            amount = stream.amount - stream.claimed;
            lastClaimWeek += 1;
        }

        // iterate over weeks that have passed fully without any claims
        for (uint256 i = lastClaimWeek; i < claimableWeek; i++) {
            (uint256 userWeight, uint256 totalWeight) = tokenLocker.weeklyWeight(_user, i);
            if (userWeight == 0) continue;
            amount += weeklyFeeAmounts[_token][i] * userWeight / totalWeight;
        }

        // add a partial amount for the active week
        stream = _buildStreamData(_user, _token, claimableWeek);

        return (amount + stream.claimed, stream);
    }

    function _buildStreamData(
        address _user,
        address _token,
        uint256 _week
    ) internal view returns (StreamData memory) {
        uint256 start = startTime + _week * WEEK;
        (uint256 userWeight, uint256 totalWeight) = tokenLocker.weeklyWeight(_user, _week);
        uint256 amount;
        uint256 claimed;
        if (userWeight > 0) {
            amount = weeklyFeeAmounts[_token][_week] * userWeight / totalWeight;
            claimed = amount * (block.timestamp - 604800 - start) / WEEK;
        }
        return StreamData({start: start, amount: amount, claimed: claimed});
    }
}

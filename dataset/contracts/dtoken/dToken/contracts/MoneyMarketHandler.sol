pragma solidity 0.5.12;

import "./interface/ILendFMe.sol";
import "./library/ERC20SafeTransfer.sol";
import "./library/DSAuth.sol";
import "./library/SafeMath.sol";
import "./library/Pausable.sol";
import "./interface/IDTokenController.sol";

contract Handler is ERC20SafeTransfer, Pausable {
    using SafeMath for uint256;

    bool private initialized; // Flags for initializing data
    address public targetAddr; // market address
    address public dTokenController; // dToken address

    mapping(address => bool) private tokensEnable;
    mapping(address => uint256) public interestDetails;

    event NewdTargetAddr(
        address indexed originalTargetAddr,
        address indexed newTargetAddr
    );
    event DisableToken(address indexed underlyingToken);
    event EnableToken(address indexed underlyingToken);

    constructor(address _targetAddr, address _dTokenController) public {
        initialize(_targetAddr, _dTokenController);
    }

    // --- Init ---
    // This function is used with contract proxy, do not modify this function.
    function initialize(address _targetAddr, address _dTokenController) public {
        require(!initialized, "initialize: Already initialized!");
        owner = msg.sender;
        targetAddr = _targetAddr;
        dTokenController = _dTokenController;
        initialized = true;
    }

    /**
     * @dev Authorized function to disable an underlying token.
     * @param _underlyingToken Token to disable.
     */
    function disableToken(address _underlyingToken) external auth {
        require(
            tokensEnable[_underlyingToken],
            "disableToken: Has been disabled!"
        );
        tokensEnable[_underlyingToken] = false;
        emit DisableToken(_underlyingToken);
    }

    /**
     * @dev Authorized function to enable an underlying token.
     * @param _underlyingToken Token to enable.
     */
    function enableToken(address _underlyingToken) external auth {
        require(
            !tokensEnable[_underlyingToken],
            "enableToken: Has been enabled!"
        );
        tokensEnable[_underlyingToken] = true;
        emit EnableToken(_underlyingToken);
    }

    /**
     * @dev Update market contract address.
     * @param _newTargetAddr The new market contract address.
     */
    function setTargetAddr(address _newTargetAddr) external auth {
        require(
            _newTargetAddr != targetAddr,
            "setTargetAddr: The same market address!"
        );
        address _originalTargetAddr = targetAddr;
        targetAddr = _newTargetAddr;
        emit NewdTargetAddr(_originalTargetAddr, _newTargetAddr);
    }

    /**
     * @dev This token `_token` approves to market and dToken contract.
     * @param _token Token address to approve.
     */
    function approve(address _token) public {
        address _dToken = IDTokenController(dTokenController).getdToken(_token);
        if (IERC20(_token).allowance(address(this), targetAddr) != uint256(-1))
            require(
                doApprove(_token, targetAddr, uint256(-1)),
                "approve: Approve market failed!"
            );

        if (IERC20(_token).allowance(address(this), _dToken) != uint256(-1))
            require(
                doApprove(_token, _dToken, uint256(-1)),
                "approve: Approve dToken failed!"
            );
    }

    /**
     * @dev Deposit token to market, but only for dToken contract.
     * @param _underlyingToken Token to deposit.
     * @return True is success, false is failure.
     */
    function deposit(address _underlyingToken, uint256 _amount)
        external
        auth
        whenNotPaused
        returns (uint256)
    {
        require(tokensEnable[_underlyingToken], "deposit: Token is disabled!");
        require(
            _amount > 0,
            "deposit: Deposit amount should be greater than 0!"
        );
        // including unexpected transfer.
        uint256 _handlerBalance = IERC20(_underlyingToken).balanceOf(
            address(this)
        );
        _updateInterest(_underlyingToken);

        require(
            ILendFMe(targetAddr).supply(
                address(_underlyingToken),
                _handlerBalance
            ) == 0,
            "deposit: Fail to supply to money market!"
        );
        return _handlerBalance > _amount ? _amount : _handlerBalance;
    }

    /**
     * @dev Withdraw token from market, but only for dToken contract.
     * @param _underlyingToken Token to withdraw.
     * @param _amount Token amount to withdraw.
     * @return Actually withdraw token amount.
     */
    function withdraw(address _underlyingToken, uint256 _amount)
        external
        auth
        whenNotPaused
        returns (uint256)
    {
        require(
            _amount > 0,
            "withdraw: Withdraw amount should be greater than 0!"
        );

        _updateInterest(_underlyingToken);

        require(
            ILendFMe(targetAddr).withdraw(address(_underlyingToken), _amount) ==
                0,
            "withdraw: Fail to withdraw from money market!"
        );

        // including unexpected transfer.
        uint256 _handlerBalance = IERC20(_underlyingToken).balanceOf(
            address(this)
        );

        return _handlerBalance > _amount ? _amount : _handlerBalance;
    }

    /**
     * @dev Update the handler deposit interest based on the underlying token.
     */
    function _updateInterest(address _underlyingToken) internal {
        uint256 _lastTotalBalance = getBalance(_underlyingToken);
        (uint256 _lastPrincipalBalance, ) = ILendFMe(targetAddr).supplyBalances(
            address(this),
            _underlyingToken
        );

        uint256 _periodInterests = _lastTotalBalance.sub(_lastPrincipalBalance);
        interestDetails[_underlyingToken] = interestDetails[_underlyingToken]
            .add(_periodInterests);
    }

    /**
     * @dev Support token or not.
     */
    function tokenIsEnabled(address _underlyingToken)
        public
        view
        returns (bool)
    {
        return tokensEnable[_underlyingToken];
    }

    /**
     * @dev Supply balance with any accumulated interest for `_underlyingToken` belonging to `handler`
     * @param _underlyingToken Token to get balance.
     */
    function getBalance(address _underlyingToken)
        public
        view
        returns (uint256)
    {
        return
            ILendFMe(targetAddr).getSupplyBalance(
                address(this),
                _underlyingToken
            );
    }

    /**
     * @dev The maximum withdrawable amount of token `_underlyingToken` in the market.
     * @param _underlyingToken Token to get balance.
     */
    function getLiquidity(address _underlyingToken)
        public
        view
        returns (uint256)
    {
        uint256 _supplyBalance = getBalance(_underlyingToken);
        uint256 _balance = IERC20(_underlyingToken).balanceOf(targetAddr);
        if (_supplyBalance > _balance) return _balance;

        return _supplyBalance;
    }

    /**
     * @dev The maximum withdrawable amount of asset `_underlyingToken` in the market,
     *      and excludes fee, if has.
     * @param _underlyingToken Token to get actual balance.
     */
    function getRealBalance(address _underlyingToken)
        external
        view
        returns (uint256)
    {
        return getBalance(_underlyingToken);
    }

    /**
     * @dev The maximum withdrawable amount of token `_underlyingToken` in the market.
     * @param _underlyingToken Token to get balance.
     */
    function getRealLiquidity(address _underlyingToken)
        public
        view
        returns (uint256)
    {
        return getLiquidity(_underlyingToken);
    }

    function getTargetAddress() external view returns (address) {
        return targetAddr;
    }
}

pragma solidity 0.5.12;

import "./library/ReentrancyGuard.sol";
import "./interface/IAave.sol";
import "./library/ERC20SafeTransfer.sol";
import "./library/Pausable.sol";
import "./library/SafeMath.sol";
import "./interface/IDTokenController.sol";

contract AaveHandler is ERC20SafeTransfer, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    bool private initialized; // Flags for initializing data

    address public dTokenController;
    address public aaveLendingPool;
    address public aaveLendingPoolCore;

    mapping(address => bool) private tokensEnable;
    mapping(address => uint256) public interestDetails;

    event NewdTokenAddresses(
        address indexed originaldToken,
        address indexed newdToken
    );
    event DisableToken(address indexed underlyingToken);
    event EnableToken(address indexed underlyingToken);

    constructor(
        address _dTokenController,
        address _lendingPool,
        address _lendingPoolCore
    ) public {
        initialize(_dTokenController, _lendingPool, _lendingPoolCore);
    }

    // --- Init ---
    // This function is used with contract proxy, do not modify this function.
    function initialize(
        address _dTokenController,
        address _lendingPool,
        address _lendingPoolCore
    ) public {
        require(!initialized, "initialize: Already initialized!");
        owner = msg.sender;
        dTokenController = _dTokenController;
        aaveLendingPool = _lendingPool;
        aaveLendingPoolCore = _lendingPoolCore;
        notEntered = true;
        initialized = true;
    }

    /**
     * @dev Authorized function to update dToken controller contract.
     * @param _newDTokenController The new dToken controller contact.
     */
    function setDTokenController(address _newDTokenController) external auth {
        require(
            _newDTokenController != dTokenController,
            "setDTokenController: The same dToken mapping contract address!"
        );
        address _originalDTokenController = dTokenController;
        dTokenController = _newDTokenController;
        emit NewdTokenAddresses(
            _originalDTokenController,
            _newDTokenController
        );
    }

    /**
     * @dev Authorized function to disable some underlying tokens.
     * @param _underlyingTokens Tokens to disable.
     */
    function disableTokens(address[] calldata _underlyingTokens) external auth {
        for (uint256 i = 0; i < _underlyingTokens.length; i++) {
            _disableToken(_underlyingTokens[i]);
        }
    }

    /**
     * @dev Authorized function to enable some underlying tokens.
     * @param _underlyingTokens Tokens to enable.
     */
    function enableTokens(address[] calldata _underlyingTokens) external auth {
        for (uint256 i = 0; i < _underlyingTokens.length; i++) {
            _enableToken(_underlyingTokens[i]);
        }
    }

    function _disableToken(address _underlyingToken) internal {
        require(
            tokensEnable[_underlyingToken],
            "disableToken: Has been disabled!"
        );
        tokensEnable[_underlyingToken] = false;
        emit DisableToken(_underlyingToken);
    }

    function _enableToken(address _underlyingToken) internal {
        require(
            !tokensEnable[_underlyingToken],
            "enableToken: Has been enabled!"
        );
        tokensEnable[_underlyingToken] = true;
        emit EnableToken(_underlyingToken);
    }

    function setLendingPoolCore(address _newLendingPoolCore) external auth {
        aaveLendingPoolCore = _newLendingPoolCore;
    }

    function setLendingPool(address _newLendingPool) external auth {
        aaveLendingPool = _newLendingPool;
    }

    /**
     * @dev Authorized function to approves market and dToken to transfer handler's underlying token.
     * @param _underlyingToken Token address to approve.
     */
    function approve(address _underlyingToken) external auth {
        address _dToken = IDTokenController(dTokenController).getdToken(
            _underlyingToken
        );

        if (
            IERC20(_underlyingToken).allowance(
                address(this),
                aaveLendingPoolCore
            ) != uint256(-1)
        ) {
            require(
                doApprove(_underlyingToken, aaveLendingPoolCore, uint256(-1)),
                "approve: Approve aToken failed!"
            );
        }

        if (
            IERC20(_underlyingToken).allowance(address(this), _dToken) !=
            uint256(-1)
        ) {
            require(
                doApprove(_underlyingToken, _dToken, uint256(-1)),
                "approve: Approve dToken failed!"
            );
        }
    }

    /**
     * @dev Deposit token to market, only called by dToken contract.
     * @param _underlyingToken Token to deposit.
     * @return The actual deposited token amount.
     */
    function deposit(address _underlyingToken, uint256 _amount)
        external
        whenNotPaused
        auth
        nonReentrant
        returns (uint256)
    {
        require(tokensEnable[_underlyingToken], "deposit: Token is disabled!");
        require(
            _amount > 0,
            "deposit: Deposit amount should be greater than 0!"
        );

        address _aToken = getaToken(_underlyingToken);
        require(_aToken != address(0x0), "deposit: Do not support token!");

        // Update the stored interest with the market balance before the deposit
        uint256 _MarketBalanceBefore = _updateInterest(_underlyingToken);

        // Mint all the token balance of the handler,
        // which should be the exact deposit amount normally,
        // but there could be some unexpected transfers before.
        uint256 _handlerBalance = IERC20(_underlyingToken).balanceOf(
            address(this)
        );
        LendingPool(aaveLendingPool).deposit(
            _underlyingToken,
            _handlerBalance,
            uint16(0)
        );

        // including unexpected transfers.
        uint256 _MarketBalanceAfter = getBalance(_underlyingToken);

        uint256 _changedAmount = _MarketBalanceAfter.sub(_MarketBalanceBefore);

        // return a smaller value as unexpected transfers were also included.
        return _changedAmount > _amount ? _amount : _changedAmount;
    }

    /**
     * @dev Withdraw token from market, but only for dToken contract.
     * @param _underlyingToken Token to withdraw.
     * @param _amount Token amount to withdraw.
     * @return The actual withdrown token amount.
     */
    function withdraw(address _underlyingToken, uint256 _amount)
        external
        whenNotPaused
        auth
        nonReentrant
        returns (uint256)
    {
        require(
            _amount > 0,
            "withdraw: Withdraw amount should be greater than 0!"
        );

        address _aToken = getaToken(_underlyingToken);
        require(_aToken != address(0x0), "withdraw: Do not support token!");

        _updateInterest(_underlyingToken);

        uint256 _handlerBalanceBefore = IERC20(_underlyingToken).balanceOf(
            address(this)
        );

        // aave supports redeem -1
        AToken(_aToken).redeem(_amount);

        uint256 _handlerBalanceAfter = IERC20(_underlyingToken).balanceOf(
            address(this)
        );

        uint256 _changedAmount = _handlerBalanceAfter.sub(
            _handlerBalanceBefore
        );

        // return a smaller value.
        return _changedAmount > _amount ? _amount : _changedAmount;
    }

    /**
     * @dev Update the handler deposit interest based on the underlying token.
     * @param _underlyingToken The underlying token to check interest with.
     * @return The current balance in market.
     */
    function _updateInterest(address _underlyingToken)
        internal
        returns (uint256)
    {
        uint256 _balance = getBalance(_underlyingToken);

        // Interest = Balance - UnderlyingBalance.
        uint256 _interest = _balance.sub(
            getUnderlyingBalance(_underlyingToken)
        );

        // Update the stored interest
        interestDetails[_underlyingToken] = interestDetails[_underlyingToken]
            .add(_interest);

        return _balance;
    }

    /**
     * @dev Support token or not.
     */
    function tokenIsEnabled(address _underlyingToken)
        external
        view
        returns (bool)
    {
        return tokensEnable[_underlyingToken];
    }

    /**
     * @dev Total balance with any accumulated interest for _underlyingToken belonging to handler
     * @param _underlyingToken Token to get balance.
     */
    function getBalance(address _underlyingToken)
        public
        view
        returns (uint256)
    {
        address _aToken = getaToken(_underlyingToken);

        return AToken(_aToken).balanceOf(address(this));
    }

    /**
     * @dev The principal balance.
     * @param _underlyingToken Token to get balance.
     */
    function getUnderlyingBalance(address _underlyingToken)
        public
        view
        returns (uint256)
    {
        address _aToken = getaToken(_underlyingToken);
        return AToken(_aToken).principalBalanceOf(address(this));
    }

    /**
     * @dev The maximum withdrawable _underlyingToken in the market.
     * @param _underlyingToken Token to get liquidity.
     */
    function getLiquidity(address _underlyingToken)
        public
        view
        returns (uint256)
    {
        uint256 _underlyingBalance = getBalance(_underlyingToken);
        uint256 _cash = LendingPoolCore(aaveLendingPoolCore)
            .getReserveAvailableLiquidity(_underlyingToken);

        return _underlyingBalance > _cash ? _cash : _underlyingBalance;
    }

    /**
     * @dev The maximum withdrawable _underlyingToken in the market, fee excluded
     * @param _underlyingToken Token to get real balance.
     */
    function getRealBalance(address _underlyingToken)
        external
        view
        returns (uint256)
    {
        return getBalance(_underlyingToken);
    }

    /**
     * @dev The maximum withdrawable _underlyingToken in the market.
     * @param _underlyingToken Token to get real liquidity.
     */
    function getRealLiquidity(address _underlyingToken)
        external
        view
        returns (uint256)
    {
        return getLiquidity(_underlyingToken);
    }

    /**
     * @dev The corrsponding AToken address of the _underlyingToken.
     * @param _underlyingToken Token to query the AToken.
     */
    function getaToken(address _underlyingToken) public view returns (address) {
        return
            LendingPoolCore(aaveLendingPoolCore).getReserveATokenAddress(
                _underlyingToken
            );
    }
}

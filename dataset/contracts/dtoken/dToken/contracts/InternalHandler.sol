pragma solidity 0.5.12;

import "./interface/IDTokenController.sol";
import "./library/ReentrancyGuard.sol";
import "./library/ERC20SafeTransfer.sol";
import "./library/Pausable.sol";
import "./library/SafeMath.sol";

contract InternalHandler is ERC20SafeTransfer, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    bool private initialized; // Flags for initializing data
    address public dTokenController; // dToken mapping contract

    mapping(address => bool) private tokensEnable; // Supports token or not

    event NewdTokenAddresses(
        address indexed originaldToken,
        address indexed newdToken
    );
    event DisableToken(address indexed underlyingToken);
    event EnableToken(address indexed underlyingToken);

    constructor(address _dTokenController) public {
        initialize(_dTokenController);
    }

    // --- Init ---
    // This function is used with contract proxy, do not modify this function.
    function initialize(address _dTokenController) public {
        require(!initialized, "initialize: Already initialized!");
        owner = msg.sender;
        dTokenController = _dTokenController;
        notEntered = true;
        initialized = true;
    }

    /**
     * @dev Update dToken mapping contract.
     * @param _newDTokenController The new dToken mapping contact.
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

    /**
     * @dev The _underlyingToken approves to dToken contract.
     * @param _underlyingToken Token address to approve.
     */
    function approve(address _underlyingToken) external auth {
        address _dToken = IDTokenController(dTokenController).getdToken(
            _underlyingToken
        );
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
        return _amount;
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
        return
            _amount == uint256(-1)
                ? IERC20(_underlyingToken).balanceOf(address(this))
                : _amount;
    }

    /**
     * @dev Support token or not.
     * @param _underlyingToken Token to check.
     */
    function tokenIsEnabled(address _underlyingToken)
        external
        view
        returns (bool)
    {
        return tokensEnable[_underlyingToken];
    }

    /**
     * @dev Total balance with any accumulated interest for `_underlyingToken` belonging to `handler`.
     * @param _underlyingToken Token to get balance.
     */
    function getBalance(address _underlyingToken)
        public
        view
        returns (uint256)
    {
        return IERC20(_underlyingToken).balanceOf(address(this));
    }

    /**
     * @dev The maximum withdrawable amount of token `_underlyingToken` in the market.
     * @param _underlyingToken Token to get liquidity.
     */
    function getLiquidity(address _underlyingToken)
        external
        view
        returns (uint256)
    {
        return getBalance(_underlyingToken);
    }

    /**
     * @dev The latest total balance with any accumulated interest for `_underlyingToken` belonging
     *       to `handler`.
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
     * @dev The latest maximum withdrawable amount of token `_underlyingToken` in the market.
     * @param _underlyingToken Token to get liquidity.
     */
    function getRealLiquidity(address _underlyingToken)
        external
        view
        returns (uint256)
    {
        return getBalance(_underlyingToken);
    }
}

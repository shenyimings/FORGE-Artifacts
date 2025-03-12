pragma solidity 0.5.12;

import "./library/ReentrancyGuard.sol";
import "./library/Pausable.sol";
import "./library/ERC20SafeTransfer.sol";
import "./library/SafeMath.sol";
import "./interface/IDispatcher.sol";
import "./interface/IHandler.sol";

contract DToken is ReentrancyGuard, Pausable, ERC20SafeTransfer {
    using SafeMath for uint256;
    // --- Data ---
    bool private initialized; // Flag of initialize data

    struct DTokenData {
        uint256 exchangeRate;
        uint256 totalInterest;
    }

    DTokenData public data;

    address public feeRecipient;
    mapping(bytes4 => uint256) public originationFee; // Trade fee

    address public dispatcher;
    address public token;

    uint256 constant BASE = 10**18;

    // --- ERC20 Data ---
    string public name;
    string public symbol;
    uint256 public decimals;
    uint256 public totalSupply;

    struct Balance {
        uint256 value;
        uint256 exchangeRate;
        uint256 interest;
    }
    mapping(address => Balance) public balances;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- User Triggered Event ---
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    event Interest(
        address indexed src,
        uint256 interest,
        uint256 increase,
        uint256 totalInterest
    );

    event Mint(
        address account,
        uint256 pie,
        uint256 wad,
        uint256 totalSupply,
        uint256 exchangeRate
    );

    event Burn(
        address account,
        uint256 pie,
        uint256 wad,
        uint256 totalSupply,
        uint256 exchangeRate
    );

    // --- Admin Triggered Event ---
    event Rebalance(
        address admin,
        address[] withdraw,
        uint256[] withdrawAmount,
        address[] supply,
        uint256[] supplyAmount
    );

    event TransferFee(
        address admin,
        address token,
        address feeRecipient,
        uint256 amount
    );

    event FeeRecipientSet(
        address indexed oldFeeRecipient,
        address indexed newFeeRecipient
    );

    event NewDispatcher(address Dispatcher, address oldDispatcher);

    event NewOriginationFee(
        bytes4 sig,
        uint256 oldOriginationFeeMantissa,
        uint256 newOriginationFeeMantissa
    );

    /**
     * The constructor is used here to ensure that the implementation
     * contract is initialized. An uncontrolled implementation
     * contract might lead to misleading state
     * for users who accidentally interact with it.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _token,
        address _dispatcher
    ) public {
        initialize(_name, _symbol, _token, _dispatcher);
    }

    /************************/
    /*** Admin Operations ***/
    /************************/

    // --- Init ---
    function initialize(
        string memory _name,
        string memory _symbol,
        address _token,
        address _dispatcher
    ) public {
        require(!initialized, "initialize: Already initialized!");
        owner = msg.sender;
        feeRecipient = address(this);
        name = _name;
        symbol = _symbol;
        token = _token;
        dispatcher = _dispatcher;
        decimals = IERC20(_token).decimals();
        data.exchangeRate = BASE;
        notEntered = true;
        initialized = true;

        emit NewDispatcher(_dispatcher, address(0));
    }

    /**
     * @dev Authorized function to set a new dispatcher.
     * @param _newDispatcher New dispatcher contract address.
     */
    function updateDispatcher(address _newDispatcher) external auth {
        address _oldDispatcher = dispatcher;
        require(
            _newDispatcher != address(0) && _newDispatcher != _oldDispatcher,
            "updateDispatcher: dispatcher can be not set to 0 or the current one."
        );

        dispatcher = _newDispatcher;
        emit NewDispatcher(_newDispatcher, _oldDispatcher);
    }

    /**
     * @dev Authorized function to set a new fee recipient.
     * @param _newFeeRecipient The address allowed to collect fees.
     */
    function setFeeRecipient(address _newFeeRecipient) external auth {
        address _oldFeeRecipient = feeRecipient;
        require(
            _newFeeRecipient != address(0) &&
                _newFeeRecipient != _oldFeeRecipient,
            "setFeeRecipient: feeRecipient can be not set to 0 or the current one."
        );

        feeRecipient = _newFeeRecipient;
        emit FeeRecipientSet(_oldFeeRecipient, feeRecipient);
    }

    /**
     * @dev Authorized function to set a new origination fee.
     * @param _sig function signature.
     * @param _newOriginationFee New trading fee ratio, scaled by 1e18.
     */
    function updateOriginationFee(bytes4 _sig, uint256 _newOriginationFee)
        external
        auth
    {
        require(
            _newOriginationFee < BASE,
            "updateOriginationFee: incorrect fee."
        );
        uint256 _oldOriginationFee = originationFee[_sig];
        require(
            _oldOriginationFee != _newOriginationFee,
            "updateOriginationFee: fee has already set to this value."
        );

        originationFee[_sig] = _newOriginationFee;
        emit NewOriginationFee(_sig, _oldOriginationFee, _newOriginationFee);
    }

    /**
     * @dev Authorized function to transfer token out.
     * @param _token The underlying token.
     * @param _amount Amount to transfer.
     */
    function transferFee(address _token, uint256 _amount) external auth {
        require(
            feeRecipient != address(this),
            "transferFee: Can not transfer fee back to this contract."
        );

        require(
            doTransferOut(_token, feeRecipient, _amount),
            "transferFee: Token transfer out of contract failed."
        );

        emit TransferFee(msg.sender, _token, feeRecipient, _amount);
    }

    /**
     * @dev Authorized function to rebalance underlying token between handlers.
     * @param _withdraw From which handlers to withdraw.
     * @param _withdrawAmount Amounts to withdraw.
     * @param _deposit To which handlers to deposit.
     * @param _depositAmount Amounts to deposit.
     */
    function rebalance(
        address[] calldata _withdraw,
        uint256[] calldata _withdrawAmount,
        address[] calldata _deposit,
        uint256[] calldata _depositAmount
    ) external auth {
        require(
            _withdraw.length == _withdrawAmount.length &&
                _deposit.length == _depositAmount.length,
            "rebalance: the length of addresses and amounts must match."
        );

        address _token = token;
        address _defaultHandler = IDispatcher(dispatcher).defaultHandler();

        // Start withdrawing
        uint256[] memory _realWithdrawAmount = new uint256[](
            _withdrawAmount.length
        );
        for (uint256 i = 0; i < _withdraw.length; i++) {
            // No need to withdraw from default handler, all withdrown tokens go to it
            if (_withdrawAmount[i] == 0 || _defaultHandler == _withdraw[i])
                continue;

            // Check whether we want to withdraw all
            _realWithdrawAmount[i] = _withdrawAmount[i] == uint256(-1)
                ? IHandler(_withdraw[i]).getRealBalance(_token)
                : _withdrawAmount[i];

            // Ensure we get the exact amount we wanted
            // Will fail if there is fee for withdraw
            // For withdraw all (-1) we check agaist the real amount
            require(
                IHandler(_withdraw[i]).withdraw(_token, _withdrawAmount[i]) ==
                    _realWithdrawAmount[i],
                "rebalance: actual withdrown amount does not match the wanted"
            );

            // Transfer to the default handler
            require(
                doTransferFrom(
                    _token,
                    _withdraw[i],
                    _defaultHandler,
                    _realWithdrawAmount[i]
                ),
                "rebalance: transfer to default handler failed"
            );
        }

        // Start depositing
        for (uint256 i = 0; i < _deposit.length; i++) {
            require(
                IDispatcher(dispatcher).isHandlerActive(_deposit[i]) &&
                    IHandler(_deposit[i]).tokenIsEnabled(_token),
                "rebalance: both handler and token must be enabled"
            );

            // No need to deposit into default handler, it has been there already.
            if (_depositAmount[i] == 0 || _defaultHandler == _deposit[i])
                continue;

            // Transfer from default handler to the target one.
            require(
                doTransferFrom(
                    _token,
                    _defaultHandler,
                    _deposit[i],
                    _depositAmount[i]
                ),
                "rebalance: transfer to target handler failed"
            );

            // Deposit into the target lending market
            require(
                IHandler(_deposit[i]).deposit(_token, _depositAmount[i]) ==
                    _depositAmount[i],
                "rebalance: deposit to the target protocal failed"
            );
        }

        emit Rebalance(
            msg.sender,
            _withdraw,
            _withdrawAmount,
            _deposit,
            _depositAmount
        );
    }

    /*************************************/
    /*** Helpers only for internal use ***/
    /*************************************/

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y) / BASE;
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE).div(y);
    }

    function rdivup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(BASE).add(y.sub(1)).div(y);
    }

    /**
     * @dev Current newest exchange rate, scaled by 1e18.
     */
    function getCurrentExchangeRate() internal returns (uint256) {
        address[] memory _handlers = getHandlers();
        return getCurrentExchangeRateByHandler(_handlers, token);
    }

    /**
     * @dev Calculate the exchange rate according to handlers and their token balance.
     * @param _handlers The list of handlers.
     * @param _token The underlying token.
     * @return Current exchange rate between token and dToken.
     */
    function getCurrentExchangeRateByHandler(
        address[] memory _handlers,
        address _token
    ) internal returns (uint256) {
        uint256 _totalToken = 0;

        // Get the total underlying token amount from handlers
        for (uint256 i = 0; i < _handlers.length; i++)
            _totalToken = _totalToken.add(
                IHandler(_handlers[i]).getRealBalance(_token)
            );

        // Reset exchange rate to 1 when there is no dToken left
        uint256 _exchangeRate = (totalSupply == 0)
            ? BASE
            : rdiv(_totalToken, totalSupply);

        require(_exchangeRate > 0, "Exchange rate should not be 0!");

        return _exchangeRate;
    }

    /**
     * @dev Update global and user's accrued interest.
     * @param _account User account.
     * @param _exchangeRate Current exchange rate.
     */
    function updateInterest(address _account, uint256 _exchangeRate) internal {
        Balance storage _balance = balances[_account];

        // There have been some interest since last time
        if (
            _balance.exchangeRate > 0 && _exchangeRate > _balance.exchangeRate
        ) {
            uint256 _interestIncrease = rmul(
                _exchangeRate.sub(_balance.exchangeRate),
                _balance.value
            );

            // Update user's accrued interst
            _balance.interest = _balance.interest.add(_interestIncrease);

            // Update global accrued interst
            data.totalInterest = data.totalInterest.add(_interestIncrease);

            emit Interest(
                _account,
                _balance.interest,
                _interestIncrease,
                data.totalInterest
            );
        }

        // Update the exchange rate accordingly
        _balance.exchangeRate = _exchangeRate;
        data.exchangeRate = _exchangeRate;
    }

    /***********************/
    /*** User Operations ***/
    /***********************/

    struct MintLocalVars {
        address token;
        address[] handlers;
        uint256[] amounts;
        uint256 exchangeRate;
        uint256 originationFee;
        uint256 fee;
        uint256 netDepositAmount;
        uint256 mintAmount;
        uint256 wad;
        uint256 interestIncrease;
    }

    /**
     * @dev Deposit token to earn savings, but only when the contract is not paused.
     * @param _dst Account who will get dToken.
     * @param _pie Amount to deposit, scaled by 1e18.
     */
    function mint(address _dst, uint256 _pie)
        external
        nonReentrant
        whenNotPaused
    {
        MintLocalVars memory _mintLocal;
        _mintLocal.token = token;

        // Charge the fee first
        _mintLocal.originationFee = originationFee[msg.sig];
        _mintLocal.fee = rmul(_pie, _mintLocal.originationFee);
        if (_mintLocal.fee > 0)
            require(
                doTransferFrom(
                    _mintLocal.token,
                    msg.sender,
                    feeRecipient,
                    _mintLocal.fee
                ),
                "mint: transferFrom fee failed"
            );

        _mintLocal.netDepositAmount = _pie.sub(_mintLocal.fee);

        // Get deposit strategy base on the deposit amount.
        (_mintLocal.handlers, _mintLocal.amounts) = IDispatcher(dispatcher)
            .getDepositStrategy(_mintLocal.netDepositAmount);
        require(
            _mintLocal.handlers.length > 0,
            "mint: no doposit stratege available, possibly due to a paused handler"
        );

        // Get current exchange rate.
        _mintLocal.exchangeRate = getCurrentExchangeRateByHandler(
            _mintLocal.handlers,
            _mintLocal.token
        );

        for (uint256 i = 0; i < _mintLocal.handlers.length; i++) {
            // If deposit amount is 0 for this handler, then pass.
            if (_mintLocal.amounts[i] == 0) continue;

            // Transfer the calculated token amount from `msg.sender` to the `handler`.
            require(
                doTransferFrom(
                    _mintLocal.token,
                    msg.sender,
                    _mintLocal.handlers[i],
                    _mintLocal.amounts[i]
                ),
                "mint: transfer token to handler failed."
            );

            // The `handler` deposit obtained token to corresponding market to earn savings.
            // Add the returned amount to the acutal mint amount, there could be fee when deposit
            _mintLocal.mintAmount = _mintLocal.mintAmount.add(
                IHandler(_mintLocal.handlers[i]).deposit(
                    _mintLocal.token,
                    _mintLocal.amounts[i]
                )
            );
        }

        require(
            _mintLocal.mintAmount <= _mintLocal.netDepositAmount,
            "mint: deposited more than intended"
        );

        // Calculate amount of the dToken based on current exchange rate.
        _mintLocal.wad = rdiv(_mintLocal.mintAmount, _mintLocal.exchangeRate);
        require(
            _mintLocal.wad > 0,
            "mint: can not mint the smallest unit with the given amount"
        );

        updateInterest(_dst, _mintLocal.exchangeRate);

        Balance storage _balance = balances[_dst];
        _balance.value = _balance.value.add(_mintLocal.wad);
        totalSupply = totalSupply.add(_mintLocal.wad);

        emit Transfer(address(0), _dst, _mintLocal.wad);
        emit Mint(
            _dst,
            _pie,
            _mintLocal.wad,
            totalSupply,
            _mintLocal.exchangeRate
        );
    }

    struct BurnLocalVars {
        address token;
        address defaultHandler;
        address[] handlers;
        uint256[] amounts;
        uint256 exchangeRate;
        uint256 grossAmount;
        uint256 withdrawAmount;
        uint256 withdrawTotalAmount;
        uint256 userAmount;
        uint256 fee;
        uint256 wad;
        uint256 originationFee;
        uint256 interestIncrease;
    }

    /**
     * @dev Withdraw to get token according to input dToken amount,
     *      but only when the contract is not paused.
     * @param _src Account who will spend dToken.
     * @param _wad Amount to burn dToken, scaled by 1e18.
     */
    function burn(address _src, uint256 _wad)
        external
        nonReentrant
        whenNotPaused
    {
        // Check the balance and allowance
        Balance storage _balance = balances[_src];
        require(_balance.value >= _wad, "burn: insufficient balance");
        if (_src != msg.sender && allowance[_src][msg.sender] != uint256(-1)) {
            require(
                allowance[_src][msg.sender] >= _wad,
                "burn: insufficient allowance"
            );
            allowance[_src][msg.sender] = allowance[_src][msg.sender].sub(_wad);
        }

        BurnLocalVars memory _burnLocal;
        _burnLocal.token = token;

        // Get current exchange rate.
        _burnLocal.exchangeRate = getCurrentExchangeRate();
        _burnLocal.grossAmount = rmul(_wad, _burnLocal.exchangeRate);

        // Get `_token` best withdraw strategy base on the withdraw amount `_pie`.
        (_burnLocal.handlers, _burnLocal.amounts) = IDispatcher(dispatcher)
            .getWithdrawStrategy(_burnLocal.token, _burnLocal.grossAmount);
        require(
            _burnLocal.handlers.length > 0,
            "burn: no withdraw stratege available, possibly due to a paused handler"
        );

        _burnLocal.defaultHandler = IDispatcher(dispatcher).defaultHandler();
        require(
            _burnLocal.defaultHandler != address(0) &&
                IDispatcher(dispatcher).isHandlerActive(
                    _burnLocal.defaultHandler
                ),
            "redeem: default handler is inactive"
        );

        for (uint256 i = 0; i < _burnLocal.handlers.length; i++) {
            if (_burnLocal.amounts[i] == 0) continue;

            // The handler withdraw calculated amount from the market.
            _burnLocal.withdrawAmount = IHandler(_burnLocal.handlers[i])
                .withdraw(_burnLocal.token, _burnLocal.amounts[i]);
            require(
                _burnLocal.withdrawAmount > 0,
                "burn: handler withdraw failed"
            );

            // Transfer token from other handlers to default handler
            // Default handler acts as a temporary pool here
            if (_burnLocal.defaultHandler != _burnLocal.handlers[i])
                require(
                    doTransferFrom(
                        _burnLocal.token,
                        _burnLocal.handlers[i],
                        _burnLocal.defaultHandler,
                        _burnLocal.withdrawAmount
                    ),
                    "burn: transfer to default handler failed"
                );

            _burnLocal.withdrawTotalAmount = _burnLocal.withdrawTotalAmount.add(
                _burnLocal.withdrawAmount
            );
        }

        // Market may charge some fee in withdraw, so the actual withdrown total amount
        // could be less than what was intended
        // Use the withdrawTotalAmount as the baseline for further calculation
        require(
            _burnLocal.withdrawTotalAmount <= _burnLocal.grossAmount,
            "burn: withdrown more than intended"
        );

        updateInterest(_src, _burnLocal.exchangeRate);

        // Update the balance and totalSupply
        _balance.value = _balance.value.sub(_wad);
        totalSupply = totalSupply.sub(_wad);

        // Calculate fee
        _burnLocal.originationFee = originationFee[msg.sig];
        _burnLocal.fee = rmul(
            _burnLocal.withdrawTotalAmount,
            _burnLocal.originationFee
        );

        // Transfer fee from the default handler(the temporary pool) to dToken.
        if (_burnLocal.fee > 0)
            require(
                doTransferFrom(
                    _burnLocal.token,
                    _burnLocal.defaultHandler,
                    feeRecipient,
                    _burnLocal.fee
                ),
                "burn: transfer fee from default handler failed"
            );

        // Subtracting the fee
        _burnLocal.userAmount = _burnLocal.withdrawTotalAmount.sub(
            _burnLocal.fee
        );

        // Transfer the remaining amount from the default handler to msg.sender.
        if (_burnLocal.userAmount > 0)
            require(
                doTransferFrom(
                    _burnLocal.token,
                    _burnLocal.defaultHandler,
                    msg.sender,
                    _burnLocal.userAmount
                ),
                "burn: transfer from default handler to user failed"
            );

        emit Transfer(_src, address(0), _wad);
        emit Burn(
            _src,
            _burnLocal.withdrawTotalAmount,
            _wad,
            totalSupply,
            _burnLocal.exchangeRate
        );
    }

    struct RedeemLocalVars {
        address token;
        address defaultHandler;
        address[] handlers;
        uint256[] amounts;
        uint256 exchangeRate;
        uint256 consumeAmountWithFee;
        uint256 redeemAmount;
        uint256 redeemTotalAmount;
        uint256 userAmount;
        uint256 fee;
        uint256 wad;
        uint256 originationFee;
        uint256 interestIncrease;
    }

    /**
     * @dev Withdraw to get specified token, but only when the contract is not paused.
     * @param _src Account who will spend dToken.
     * @param _pie Amount to withdraw token, scaled by 1e18.
     */
    function redeem(address _src, uint256 _pie)
        external
        nonReentrant
        whenNotPaused
    {
        RedeemLocalVars memory _redeemLocal;
        _redeemLocal.token = token;

        // Here use the signature of burn(), both functions should use the same fee rate
        _redeemLocal.originationFee = originationFee[0x9dc29fac];

        _redeemLocal.consumeAmountWithFee = rdivup(
            _pie,
            BASE.sub(_redeemLocal.originationFee)
        );

        // Get `_token` best redeem strategy base on the redeem amount including fee.
        (_redeemLocal.handlers, _redeemLocal.amounts) = IDispatcher(dispatcher)
            .getWithdrawStrategy(
            _redeemLocal.token,
            _redeemLocal.consumeAmountWithFee
        );
        require(
            _redeemLocal.handlers.length > 0,
            "redeem: no redeem stratege available, possibly due to a paused handler"
        );

        _redeemLocal.defaultHandler = IDispatcher(dispatcher).defaultHandler();
        require(
            _redeemLocal.defaultHandler != address(0) &&
                IDispatcher(dispatcher).isHandlerActive(
                    _redeemLocal.defaultHandler
                ),
            "redeem: default handler is inactive"
        );

        // Get current exchange rate.
        _redeemLocal.exchangeRate = getCurrentExchangeRateByHandler(
            _redeemLocal.handlers,
            _redeemLocal.token
        );

        for (uint256 i = 0; i < _redeemLocal.handlers.length; i++) {
            if (_redeemLocal.amounts[i] == 0) continue;

            // The `handler` redeem calculated amount from the market.
            _redeemLocal.redeemAmount = IHandler(_redeemLocal.handlers[i])
                .withdraw(_redeemLocal.token, _redeemLocal.amounts[i]);
            require(
                _redeemLocal.redeemAmount > 0,
                "redeem: handler withdraw failed"
            );

            // Transfer token from other handlers to default handler
            // Default handler acts as a temporary pool here
            if (_redeemLocal.defaultHandler != _redeemLocal.handlers[i])
                require(
                    doTransferFrom(
                        _redeemLocal.token,
                        _redeemLocal.handlers[i],
                        _redeemLocal.defaultHandler,
                        _redeemLocal.redeemAmount
                    ),
                    "redeem: transfer to default handler failed"
                );
            _redeemLocal.redeemTotalAmount = _redeemLocal.redeemTotalAmount.add(
                _redeemLocal.redeemAmount
            );
        }

        // Make sure enough token has been withdrown
        // If the market charge fee in withdraw, there are 2 cases:
        // 1) redeemed < intended, the check below would fail;
        // 2) redeemed == intended, then fee was covered by consuming more underlying token
        require(
            _redeemLocal.redeemTotalAmount == _redeemLocal.consumeAmountWithFee,
            "redeem: withdrown more than intended"
        );

        // Calculate amount of the dToken based on current exchange rate.
        _redeemLocal.wad = rdivup(
            _redeemLocal.redeemTotalAmount,
            _redeemLocal.exchangeRate
        );

        updateInterest(_src, _redeemLocal.exchangeRate);

        // Check the balance and allowance
        Balance storage _balance = balances[_src];
        require(
            _balance.value >= _redeemLocal.wad,
            "redeem: insufficient balance"
        );
        if (_src != msg.sender && allowance[_src][msg.sender] != uint256(-1)) {
            require(
                allowance[_src][msg.sender] >= _redeemLocal.wad,
                "redeem: insufficient allowance"
            );
            allowance[_src][msg.sender] = allowance[_src][msg.sender].sub(
                _redeemLocal.wad
            );
        }

        // Update the balance and totalSupply
        _balance.value = _balance.value.sub(_redeemLocal.wad);
        totalSupply = totalSupply.sub(_redeemLocal.wad);

        // The calculated amount contains exchange token fee, if it exists.
        _redeemLocal.fee = _redeemLocal.redeemTotalAmount.sub(_pie);

        // Transfer fee from the default handler(the temporary pool) to dToken.
        if (_redeemLocal.fee > 0)
            require(
                doTransferFrom(
                    _redeemLocal.token,
                    _redeemLocal.defaultHandler,
                    feeRecipient,
                    _redeemLocal.fee
                ),
                "redeem: transfer fee from default handler failed"
            );

        // Transfer original amount _pie from the default handler to msg.sender.
        require(
            doTransferFrom(
                _redeemLocal.token,
                _redeemLocal.defaultHandler,
                msg.sender,
                _pie
            ),
            "redeem: transfer to user failed"
        );

        emit Transfer(_src, address(0), _redeemLocal.wad);
        emit Burn(
            _src,
            _redeemLocal.redeemTotalAmount,
            _redeemLocal.wad,
            totalSupply,
            _redeemLocal.exchangeRate
        );
    }

    // --- ERC20 Standard Interfaces ---
    function transfer(address _dst, uint256 _wad) external returns (bool) {
        return transferFrom(msg.sender, _dst, _wad);
    }

    function transferFrom(
        address _src,
        address _dst,
        uint256 _wad
    ) public nonReentrant whenNotPaused returns (bool) {
        Balance storage _srcBalance = balances[_src];

        // Check balance and allowance
        require(
            _srcBalance.value >= _wad,
            "transferFrom: insufficient balance"
        );
        if (_src != msg.sender && allowance[_src][msg.sender] != uint256(-1)) {
            require(
                allowance[_src][msg.sender] >= _wad,
                "transferFrom: insufficient allowance"
            );
            allowance[_src][msg.sender] = allowance[_src][msg.sender].sub(_wad);
        }

        // Update the accured interest for both
        uint256 _exchangeRate = getCurrentExchangeRate();
        updateInterest(_src, _exchangeRate);
        updateInterest(_dst, _exchangeRate);

        // Finally update the balance
        Balance storage _dstBalance = balances[_dst];
        _srcBalance.value = _srcBalance.value.sub(_wad);
        _dstBalance.value = _dstBalance.value.add(_wad);

        emit Transfer(_src, _dst, _wad);
        return true;
    }

    function approve(address _spender, uint256 _wad) public returns (bool) {
        allowance[msg.sender][_spender] = _wad;
        emit Approval(msg.sender, _spender, _wad);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        return approve(spender, allowance[msg.sender][spender].add(addedValue));
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        return
            approve(
                spender,
                allowance[msg.sender][spender].sub(subtractedValue)
            );
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account].value;
    }

    /**
     * @dev According to the current exchange rate, get user's corresponding token balance
     *      based on the dToken amount, which has substracted dToken fee.
     * @param _account Account to query token balance.
     * @return Actual token balance based on dToken amount.
     */
    function getTokenBalance(address _account) external view returns (uint256) {
        return rmul(balances[_account].value, getExchangeRate());
    }

    /**
   * @dev According to the current exchange rate, get user's accrued interest until now,
          it is an estimation, since it use the exchange rate in view instead of
          the realtime one.
   * @param _account Account to query token balance.
   * @return Estimation of accrued interest till now.
   */
    function getCurrentInterest(address _account)
        external
        view
        returns (uint256)
    {
        return
            balances[_account].interest.add(
                rmul(
                    getExchangeRate().sub(balances[_account].exchangeRate),
                    balances[_account].value
                )
            );
    }

    /**
     * @dev Get the current list of the handlers.
     */
    function getHandlers() public view returns (address[] memory) {
        (address[] memory _handlers, ) = IDispatcher(dispatcher).getHandlers();
        return _handlers;
    }

    /**
     * @dev Get all deposit token amount including interest.
     */
    function getTotalBalance() external view returns (uint256) {
        address[] memory _handlers = getHandlers();
        uint256 _tokenTotalBalance = 0;
        for (uint256 i = 0; i < _handlers.length; i++)
            _tokenTotalBalance = _tokenTotalBalance.add(
                IHandler(_handlers[i]).getBalance(token)
            );
        return _tokenTotalBalance;
    }

    /**
     * @dev Get maximum valid token amount in the whole market.
     */
    function getLiquidity() external view returns (uint256) {
        address[] memory _handlers = getHandlers();
        uint256 _liquidity = 0;
        for (uint256 i = 0; i < _handlers.length; i++)
            _liquidity = _liquidity.add(
                IHandler(_handlers[i]).getLiquidity(token)
            );
        return _liquidity;
    }

    /**
     * @dev Current exchange rate, scaled by 1e18.
     */
    function getExchangeRate() public view returns (uint256) {
        address[] memory _handlers = getHandlers();
        address _token = token;
        uint256 _totalToken = 0;
        for (uint256 i = 0; i < _handlers.length; i++)
            _totalToken = _totalToken.add(
                IHandler(_handlers[i]).getBalance(_token)
            );

        return totalSupply == 0 ? BASE : rdiv(_totalToken, totalSupply);
    }
}

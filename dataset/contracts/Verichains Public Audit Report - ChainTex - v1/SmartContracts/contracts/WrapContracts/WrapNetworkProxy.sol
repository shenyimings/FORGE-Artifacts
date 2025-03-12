pragma solidity 0.4.25;

// https://github.com/ethereum/EIPs/issues/20
interface TRC20 {
    function totalSupply() external view returns (uint supply);
    function balanceOf(address _owner) external view returns (uint balance);
    function transfer(address _to, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint _value) external returns (bool success);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint remaining);
    function decimals() external view returns(uint digits);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

/// @title Reserve contract
interface ReserveInterface {

    function trade(
        TRC20 srcToken,
        uint srcAmount,
        TRC20 destToken,
        address destAddress,
        uint conversionRate,
        uint feeInWei,
        bool validate
    )
        external
        payable
        returns(bool);

    function getConversionRate(TRC20 src, TRC20 dest, uint srcQty, uint blockNumber) external view returns(uint);
}

/// @title Kyber Network interface
interface NetworkInterface {
    function maxGasPrice() external view returns(uint);
    function getUserCapInWei(address user) external view returns(uint);
    function getUserCapInTokenWei(address user, TRC20 token) external view returns(uint);
    function enabled() external view returns(bool);
    function info(bytes32 id) external view returns(uint);

    function getExpectedRate(TRC20 src, TRC20 dest, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);
    function getExpectedFeeRate(TRC20 token, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);

    function swap(address trader, TRC20 src, uint srcAmount, TRC20 dest, address destAddress,
        uint maxDestAmount, uint minConversionRate, address walletId) external payable returns(uint);
    function payTxFee(address trader, TRC20 src, uint srcAmount, address destAddress,
      uint maxDestAmount, uint minConversionRate) external payable returns(uint);
}

interface ExpectedRateInterface {
    function getExpectedRate(TRC20 src, TRC20 dest, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);
    function getExpectedFeeRate(TRC20 token, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);
}

contract PermissionGroups {

    address public admin;
    address public pendingAdmin;
    mapping(address=>bool) internal operators;
    mapping(address=>bool) internal alerters;
    address[] internal operatorsGroup;
    address[] internal alertersGroup;
    uint constant internal MAX_GROUP_SIZE = 50;

    constructor() public {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender]);
        _;
    }

    modifier onlyAlerter() {
        require(alerters[msg.sender]);
        _;
    }

    function getOperators () external view returns(address[] memory) {
        return operatorsGroup;
    }

    function getAlerters () external view returns(address[] memory) {
        return alertersGroup;
    }

    event TransferAdminPending(address pendingAdmin);

    /**
     * @dev Allows the current admin to set the pendingAdmin address.
     * @param newAdmin The address to transfer ownership to.
     */
    function transferAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0));
        emit TransferAdminPending(pendingAdmin);
        pendingAdmin = newAdmin;
    }

    /**
     * @dev Allows the current admin to set the admin in one tx. Useful initial deployment.
     * @param newAdmin The address to transfer ownership to.
     */
    function transferAdminQuickly(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0));
        emit TransferAdminPending(newAdmin);
        emit AdminClaimed(newAdmin, admin);
        admin = newAdmin;
    }

    event AdminClaimed( address newAdmin, address previousAdmin);

    /**
     * @dev Allows the pendingAdmin address to finalize the change admin process.
     */
    function claimAdmin() public {
        require(pendingAdmin == msg.sender);
        emit AdminClaimed(pendingAdmin, admin);
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }

    event AlerterAdded (address newAlerter, bool isAdd);

    function addAlerter(address newAlerter) public onlyAdmin {
        require(!alerters[newAlerter]); // prevent duplicates.
        require(alertersGroup.length < MAX_GROUP_SIZE);

        emit AlerterAdded(newAlerter, true);
        alerters[newAlerter] = true;
        alertersGroup.push(newAlerter);
    }

    function removeAlerter (address alerter) public onlyAdmin {
        require(alerters[alerter]);
        alerters[alerter] = false;

        for (uint i = 0; i < alertersGroup.length; ++i) {
            if (alertersGroup[i] == alerter) {
                alertersGroup[i] = alertersGroup[alertersGroup.length - 1];
                alertersGroup.length--;
                emit AlerterAdded(alerter, false);
                break;
            }
        }
    }

    event OperatorAdded(address newOperator, bool isAdd);

    function addOperator(address newOperator) public onlyAdmin {
        require(!operators[newOperator]); // prevent duplicates.
        require(operatorsGroup.length < MAX_GROUP_SIZE);

        emit OperatorAdded(newOperator, true);
        operators[newOperator] = true;
        operatorsGroup.push(newOperator);
    }

    function removeOperator (address operator) public onlyAdmin {
        require(operators[operator]);
        operators[operator] = false;

        for (uint i = 0; i < operatorsGroup.length; ++i) {
            if (operatorsGroup[i] == operator) {
                operatorsGroup[i] = operatorsGroup[operatorsGroup.length - 1];
                operatorsGroup.length -= 1;
                emit OperatorAdded(operator, false);
                break;
            }
        }
    }
}


/**
 * @title Contracts that should be able to recover tokens or ethers
 */
contract Withdrawable is PermissionGroups {

    event TokenWithdraw(TRC20 token, uint amount, address sendTo);

    /**
     * @dev Withdraw all TRC20 compatible tokens
     * @param token TRC20 The address of the token contract
     */
    function withdrawToken(TRC20 token, uint amount, address sendTo) external onlyAdmin {
        require(token.transfer(sendTo, amount));
        emit TokenWithdraw(token, amount, sendTo);
    }

    event EtherWithdraw(uint amount, address sendTo);

    /**
     * @dev Withdraw Ethers
     */
    function withdrawEther(uint amount, address sendTo) external onlyAdmin {
        sendTo.transfer(amount);
        emit EtherWithdraw(amount, sendTo);
    }
}

contract WhiteListInterface {
    function getUserCapInWei(address user) external view returns (uint userCapWei);
}

/// @title constants contract
contract Utils {

    TRC20 constant internal TOMO_TOKEN_ADDRESS = TRC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
    uint  constant internal PRECISION = (10**18);
    uint  constant internal MAX_QTY   = (10**28); // 10B tokens
    uint  constant internal MAX_RATE  = (PRECISION * 10**6); // up to 1M tokens per ETH
    uint  constant internal MAX_DECIMALS = 18;
    uint  constant internal TOMO_DECIMALS = 18;
    mapping(address=>uint) internal decimals;

    function setDecimals(TRC20 token) internal {
        if (token == TOMO_TOKEN_ADDRESS) decimals[token] = TOMO_DECIMALS;
        else decimals[token] = token.decimals();
    }

    function getDecimals(TRC20 token) internal view returns(uint) {
        if (token == TOMO_TOKEN_ADDRESS) return TOMO_DECIMALS; // save storage access
        uint tokenDecimals = decimals[token];
        // technically, there might be token with decimals 0
        // moreover, very possible that old tokens have decimals 0
        // these tokens will just have higher gas fees.
        if(tokenDecimals == 0) return token.decimals();

        return tokenDecimals;
    }

    function calcDstQty(uint srcQty, uint srcDecimals, uint dstDecimals, uint rate) internal pure returns(uint) {
        require(srcQty <= MAX_QTY);
        require(rate <= MAX_RATE);

        if (dstDecimals >= srcDecimals) {
            require((dstDecimals - srcDecimals) <= MAX_DECIMALS);
            return (srcQty * rate * (10**(dstDecimals - srcDecimals))) / PRECISION;
        } else {
            require((srcDecimals - dstDecimals) <= MAX_DECIMALS);
            return (srcQty * rate) / (PRECISION * (10**(srcDecimals - dstDecimals)));
        }
    }

    function calcSrcQty(uint dstQty, uint srcDecimals, uint dstDecimals, uint rate) internal pure returns(uint) {
        require(dstQty <= MAX_QTY);
        require(rate <= MAX_RATE);

        //source quantity is rounded up. to avoid dest quantity being too low.
        uint numerator;
        uint denominator;
        if (srcDecimals >= dstDecimals) {
            require((srcDecimals - dstDecimals) <= MAX_DECIMALS);
            numerator = (PRECISION * dstQty * (10**(srcDecimals - dstDecimals)));
            denominator = rate;
        } else {
            require((dstDecimals - srcDecimals) <= MAX_DECIMALS);
            numerator = (PRECISION * dstQty);
            denominator = (rate * (10**(dstDecimals - srcDecimals)));
        }
        return (numerator + denominator - 1) / denominator; //avoid rounding down errors
    }
}


contract Utils2 is Utils {

    /// @dev get the balance of a user.
    /// @param token The token type
    /// @return The balance
    function getBalance(TRC20 token, address user) public view returns(uint) {
        if (token == TOMO_TOKEN_ADDRESS)
            return user.balance;
        else
            return token.balanceOf(user);
    }

    function getDecimalsSafe(TRC20 token) internal returns(uint) {

        if (decimals[token] == 0) {
            setDecimals(token);
        }

        return decimals[token];
    }

    function calcDestAmount(TRC20 src, TRC20 dest, uint srcAmount, uint rate) internal view returns(uint) {
        return calcDstQty(srcAmount, getDecimals(src), getDecimals(dest), rate);
    }

    function calcSrcAmount(TRC20 src, TRC20 dest, uint destAmount, uint rate) internal view returns(uint) {
        return calcSrcQty(destAmount, getDecimals(src), getDecimals(dest), rate);
    }

    function calcRateFromQty(uint srcAmount, uint destAmount, uint srcDecimals, uint dstDecimals)
        internal pure returns(uint)
    {
        require(srcAmount <= MAX_QTY);
        require(destAmount <= MAX_QTY);

        if (dstDecimals >= srcDecimals) {
            require((dstDecimals - srcDecimals) <= MAX_DECIMALS);
            return (destAmount * PRECISION / ((10 ** (dstDecimals - srcDecimals)) * srcAmount));
        } else {
            require((srcDecimals - dstDecimals) <= MAX_DECIMALS);
            return (destAmount * PRECISION * (10 ** (srcDecimals - dstDecimals)) / srcAmount);
        }
    }
}

/// @title Network interface
interface NetworkProxyInterface {
    function maxGasPrice() external view returns(uint);
    function getUserCapInWei(address user) external view returns(uint);
    function getUserCapInTokenWei(address user, TRC20 token) external view returns(uint);
    function enabled() external view returns(bool);
    function info(bytes32 id) external view returns(uint);

    function getExpectedRate(TRC20 src, TRC20 dest, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);
    function getExpectedFeeRate(TRC20 token, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);

    function swap(TRC20 src, uint srcAmount, TRC20 dest, address destAddress, uint maxDestAmount,
        uint minConversionRate, address walletId) external payable returns(uint);
    function payTxFee(TRC20 src, uint srcAmount, address destAddress, uint maxDestAmount,
        uint minConversionRate) external payable returns(uint);
}


/// @title simple interface for Network
interface SimpleNetworkInterface {
    function swapTokenToToken(TRC20 src, uint srcAmount, TRC20 dest, uint minConversionRate) external returns(uint);
    function swapTomoToToken(TRC20 token, uint minConversionRate) external payable returns(uint);
    function swapTokenToTomo(TRC20 token, uint srcAmount, uint minConversionRate) external returns(uint);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @title Network proxy for main contract
contract NetworkProxy is NetworkProxyInterface, SimpleNetworkInterface, Withdrawable, Utils2 {

    NetworkInterface public networkContract;
    mapping(address=>bool) public payFeeCallers;

    constructor(address _admin) public {
        require(_admin != address(0));
        admin = _admin;
    }

    /// @notice use token address TOMO_TOKEN_ADDRESS for TOMO
    /// @dev makes a trade between src and dest token and send dest token to destAddress
    /// @param src Src token
    /// @param srcAmount amount of src tokens
    /// @param dest   Destination token
    /// @param destAddress Address to send tokens to
    /// @param maxDestAmount A limit on the amount of dest tokens
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade is canceled.
    /// @param walletId is the wallet ID to send part of the fees
    /// @return amount of actual dest tokens
    function trade(
        TRC20 src,
        uint srcAmount,
        TRC20 dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
    )
        public
        payable
        returns(uint)
    {
        return swap(
            src,
            srcAmount,
            dest,
            destAddress,
            maxDestAmount,
            minConversionRate,
            walletId
        );
    }

    event AddPayFeeCaller(address caller, bool add);

    function addPayFeeCaller(address caller, bool add) public onlyAdmin {
        if (add) {
          require(payFeeCallers[caller] == false);
          payFeeCallers[caller] = true;
        } else {
          require(payFeeCallers[caller] == true);
          payFeeCallers[caller] = false;
        }
        emit AddPayFeeCaller(caller, add);
    }

    /// @notice use token address TOMO_TOKEN_ADDRESS for TOMO
    /// @dev makes a trade for transaction fee
    /// @param src Src token
    /// @param srcAmount amount of src tokens
    /// @param destAddress Address to send tokens to
    /// @param maxDestAmount A limit on the amount of dest tokens
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade is canceled.
    /// @return amount of actual dest tokens
    function payTxFee(
        TRC20 src,
        uint srcAmount,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate
    )
        public
        payable
        returns(uint)
    {
        require(src == TOMO_TOKEN_ADDRESS || msg.value == 0);
        require(payFeeCallers[msg.sender] == true, "payTxFee: Sender is not callable this function");
        TRC20 dest = TOMO_TOKEN_ADDRESS;

        UserBalance memory userBalanceBefore;

        userBalanceBefore.srcBalance = getBalance(src, msg.sender);
        userBalanceBefore.destBalance = getBalance(dest, destAddress);

        if (src == TOMO_TOKEN_ADDRESS) {
            userBalanceBefore.srcBalance += msg.value;
        } else {
            require(src.transferFrom(msg.sender, networkContract, srcAmount), "payTxFee: Transer token to network contract");
        }

        uint reportedDestAmount = networkContract.payTxFee.value(msg.value)(
          msg.sender,
          src,
          srcAmount,
          destAddress,
          maxDestAmount,
          minConversionRate
        );

        TradeOutcome memory tradeOutcome = calculateTradeOutcome(
            userBalanceBefore.srcBalance,
            userBalanceBefore.destBalance,
            src,
            dest,
            destAddress
        );

        require(reportedDestAmount == tradeOutcome.userDeltaDestAmount, "Report dest amount is different from user delta dest amount");
        require(tradeOutcome.userDeltaDestAmount <= maxDestAmount, "userDetalDestAmount > maxDestAmount");
        require(tradeOutcome.actualRate >= minConversionRate, "actualRate < minConversionRate");

        emit ExecuteTrade(msg.sender, src, dest, tradeOutcome.userDeltaSrcAmount, tradeOutcome.userDeltaDestAmount);
        return tradeOutcome.userDeltaDestAmount;
    }

    /// @notice use token address TOMO_TOKEN_ADDRESS for TOMO
    /// @dev makes a trade for transaction fee
    /// @dev auto set maxDestAmount and minConversionRate
    /// @param src Src token
    /// @param srcAmount amount of src tokens
    /// @param destAddress Address to send tokens to
    /// @return amount of actual dest tokens
    function payTxFeeFast(TRC20 src, uint srcAmount, address destAddress) external payable returns(uint) {
      require(payFeeCallers[msg.sender] == true);
      payTxFee(
        src,
        srcAmount,
        destAddress,
        MAX_QTY,
        0
      );
    }

    /// @dev makes a trade between src and dest token and send dest tokens to msg sender
    /// @param src Src token
    /// @param srcAmount amount of src tokens
    /// @param dest Destination token
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade is canceled.
    /// @return amount of actual dest tokens
    function swapTokenToToken(
        TRC20 src,
        uint srcAmount,
        TRC20 dest,
        uint minConversionRate
    )
        public
        returns(uint)
    {
        return swap(
            src,
            srcAmount,
            dest,
            msg.sender,
            MAX_QTY,
            minConversionRate,
            0
        );
    }

    /// @dev makes a trade from Tomo to token. Sends token to msg sender
    /// @param token Destination token
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade is canceled.
    /// @return amount of actual dest tokens
    function swapTomoToToken(TRC20 token, uint minConversionRate) public payable returns(uint) {
        return swap(
            TOMO_TOKEN_ADDRESS,
            msg.value,
            token,
            msg.sender,
            MAX_QTY,
            minConversionRate,
            0
        );
    }

    /// @dev makes a trade from token to Tomo, sends Ether to msg sender
    /// @param token Src token
    /// @param srcAmount amount of src tokens
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade is canceled.
    /// @return amount of actual dest tokens
    function swapTokenToTomo(TRC20 token, uint srcAmount, uint minConversionRate) public returns(uint) {
        return swap(
            token,
            srcAmount,
            TOMO_TOKEN_ADDRESS,
            msg.sender,
            MAX_QTY,
            minConversionRate,
            0
        );
    }

    struct UserBalance {
        uint srcBalance;
        uint destBalance;
    }

    event ExecuteTrade(address indexed trader, TRC20 src, TRC20 dest, uint actualSrcAmount, uint actualDestAmount);

    /// @notice use token address TOMO_TOKEN_ADDRESS for ether
    /// @dev makes a trade between src and dest token and send dest token to destAddress
    /// @param src Src token
    /// @param srcAmount amount of src tokens
    /// @param dest Destination token
    /// @param destAddress Address to send tokens to
    /// @param maxDestAmount A limit on the amount of dest tokens
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade is canceled.
    /// @param walletId is the wallet ID to send part of the fees
    /// @return amount of actual dest tokens
    function swap(
        TRC20 src,
        uint srcAmount,
        TRC20 dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
    )
        public
        payable
        returns(uint)
    {
        require(src == TOMO_TOKEN_ADDRESS || msg.value == 0);

        UserBalance memory userBalanceBefore;

        userBalanceBefore.srcBalance = getBalance(src, msg.sender);
        userBalanceBefore.destBalance = getBalance(dest, destAddress);

        if (src == TOMO_TOKEN_ADDRESS) {
            userBalanceBefore.srcBalance += msg.value;
        } else {
            require(src.transferFrom(msg.sender, networkContract, srcAmount), "swap: Can not transfer token to contract");
        }

        uint reportedDestAmount = networkContract.swap.value(msg.value)(
            msg.sender,
            src,
            srcAmount,
            dest,
            destAddress,
            maxDestAmount,
            minConversionRate,
            walletId
        );

        TradeOutcome memory tradeOutcome = calculateTradeOutcome(
            userBalanceBefore.srcBalance,
            userBalanceBefore.destBalance,
            src,
            dest,
            destAddress
        );

        require(reportedDestAmount == tradeOutcome.userDeltaDestAmount);
        require(tradeOutcome.userDeltaDestAmount <= maxDestAmount);
        require(tradeOutcome.actualRate >= minConversionRate);

        emit ExecuteTrade(msg.sender, src, dest, tradeOutcome.userDeltaSrcAmount, tradeOutcome.userDeltaDestAmount);
        return tradeOutcome.userDeltaDestAmount;
    }

    event NetworkSet(address newNetworkContract, address oldNetworkContract);

    function setNetworkContract(NetworkInterface _networkContract) public onlyAdmin {

        require(_networkContract != address(0));

        emit NetworkSet(_networkContract, networkContract);

        networkContract = _networkContract;
    }

    function getExpectedRate(TRC20 src, TRC20 dest, uint srcQty)
        public view
        returns(uint expectedRate, uint slippageRate)
    {
        return networkContract.getExpectedRate(src, dest, srcQty);
    }

    function getExpectedFeeRate(TRC20 token, uint srcQty)
        public view
        returns (uint expectedRate, uint slippageRate)
    {
        return networkContract.getExpectedFeeRate(token, srcQty);
    }

    function getUserCapInWei(address user) public view returns(uint) {
        return networkContract.getUserCapInWei(user);
    }

    function getUserCapInTokenWei(address user, TRC20 token) public view returns(uint) {
        return networkContract.getUserCapInTokenWei(user, token);
    }

    function maxGasPrice() public view returns(uint) {
        return networkContract.maxGasPrice();
    }

    function enabled() public view returns(bool) {
        return networkContract.enabled();
    }

    function info(bytes32 field) public view returns(uint) {
        return networkContract.info(field);
    }

    struct TradeOutcome {
        uint userDeltaSrcAmount;
        uint userDeltaDestAmount;
        uint actualRate;
    }

    function calculateTradeOutcome (uint srcBalanceBefore, uint destBalanceBefore, TRC20 src, TRC20 dest,
        address destAddress)
        internal returns(TradeOutcome memory outcome)
    {
        uint userSrcBalanceAfter;
        uint userDestBalanceAfter;

        userSrcBalanceAfter = getBalance(src, msg.sender);
        userDestBalanceAfter = getBalance(dest, destAddress);

        //protect from underflow
        require(userDestBalanceAfter > destBalanceBefore, "userDestBalanceAfter <= destBalanceBefore");
        require(srcBalanceBefore > userSrcBalanceAfter, "srcBalanceBefore <= userSrcBalanceAfter");

        outcome.userDeltaDestAmount = userDestBalanceAfter - destBalanceBefore;
        outcome.userDeltaSrcAmount = srcBalanceBefore - userSrcBalanceAfter;

        outcome.actualRate = calcRateFromQty(
                outcome.userDeltaSrcAmount,
                outcome.userDeltaDestAmount,
                getDecimalsSafe(src),
                getDecimalsSafe(dest)
            );
    }
}

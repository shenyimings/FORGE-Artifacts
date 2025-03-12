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

interface FeeSharingInterface {
    function handleFees(address wallet) external payable returns(bool);
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
    function payTxFeeFast(TRC20 src, uint srcAmount, address destAddress) external payable returns(uint);
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


/**
 * @title Helps contracts guard against reentrancy attacks.
 */
contract ReentrancyGuard {

    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private guardCounter = 1;

    /**
     * @dev Prevents a function from calling itself, directly or indirectly.
     * Calling one `nonReentrant` function from
     * another is not supported. Instead, you can implement a
     * `private` function doing the actual work, and an `external`
     * wrapper marked as `nonReentrant`.
     */
    modifier nonReentrant() {
        guardCounter += 1;
        uint256 localCounter = guardCounter;
        _;
        require(localCounter == guardCounter);
    }
}

contract FeeSharing is Withdrawable, FeeSharingInterface, Utils2, ReentrancyGuard {

    mapping(address=>uint) public walletFeesInBps; // commission (percentage) of a wallet
    mapping(address=>uint) public walletFeesToPay; // amount of fee to pay for a wallet
    mapping(address=>uint) public feePayedPerWallet; // total fee payed to a wallet

    NetworkInterface public network;

    constructor(address _admin, NetworkInterface _network) public {
      require(_admin != address(0));
      require(_network != address(0));
      network = _network;
      admin = _admin;
    }

    event SetNewNetworkContract(NetworkInterface _network);
    function setNetworkContract(NetworkInterface _network) public onlyAdmin {
      require(_network != address(0));
      network = _network;
      emit SetNewNetworkContract(_network);
    }

    event WalletFeesSet(address wallet, uint feesInBps);
    function setWalletFees(address wallet, uint feesInBps) public onlyAdmin {
        require(feesInBps < 10000); // under 100%
        walletFeesInBps[wallet] = feesInBps;
        emit WalletFeesSet(wallet, feesInBps);
    }

    event AssignFeeToWallet(address wallet, uint walletFee);
    function handleFees(address wallet)
      public
      nonReentrant
      payable
      returns(bool)
    {
        require(msg.sender == address(network));
        require(msg.value <= MAX_QTY);
        uint fee = msg.value;

        uint walletFee = fee * walletFeesInBps[wallet] / 10000;
        require(fee >= walletFee);

        if (walletFee > 0) {
            walletFeesToPay[wallet] += walletFee;
            emit AssignFeeToWallet(wallet, walletFee);
        }
        return true;
    }

    event SendWalletFees(address indexed wallet, address sender);
    // this function is callable by anyone
    function sendFeeToWallet(address wallet) public nonReentrant {
        uint feeAmount = walletFeesToPay[wallet];
        require(feeAmount > 0);

        uint thisBalance = address(this).balance;
        uint walletBalance = wallet.balance;

        require(thisBalance >= feeAmount);

        walletFeesToPay[wallet] = 0;
        wallet.transfer(feeAmount);
        feePayedPerWallet[wallet] += feeAmount;

        uint newThisBalance = address(this).balance;
        require(newThisBalance == thisBalance - feeAmount);

        uint newWalletBalance = wallet.balance;
        require(newWalletBalance == walletBalance + feeAmount);

        emit SendWalletFees(wallet, msg.sender);
    }
}

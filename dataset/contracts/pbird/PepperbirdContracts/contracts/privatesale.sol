

//SPDX-License-Identifier: Unlicense
pragma solidity =0.8.9;


// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        if (b > a) return (false, 0);
        return (true, a - b);
    }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
    unchecked {
        require(b <= a, errorMessage);
        return a - b;
    }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
    unchecked {
        require(b > 0, errorMessage);
        return a / b;
    }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
    unchecked {
        require(b > 0, errorMessage);
        return a % b;
    }
    }
}


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


interface IBEP20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract PepperBirdPrivateSale is Ownable {
    using SafeMath for uint256;

    IBEP20 public privateSaleToken;
    address public payableAddress;
    address public ownerAddress;

    mapping(address => HolderInfo) private _privateSaleInfo;

    bool public openPrivateSale = false;
    bool public launchMode = false;

    address[] private _privateSale;

    uint256 public privateSaleAllocation = 7_560_000_000_000 * 10**18; //Amount in Private Sale
    uint256 public privateSaleDistributed;
    uint256 private _newPaymentInterval = 864000; // 10 Days -  millieseconds 864000
    uint256 private _initialLock = 31536000; // Initial lock 1 year after buy. Time is reset to _newPaymentInterval when Private Sale Ends
    uint256 private _privateSaleHoldingCap = 216_000_000_000 * 10**18; //Max Buy Per Person
    uint256 public minimumPurchaseInBNB = 200000000000000000; // .2 BNB
    uint256 private _PBTPrivateSalePrice = 54_000_000_000; // current price as per the time of private sale
    uint256 paymentIntervals = 2; // intervals until payment is complete

    mapping(address => bool) public operators;

    struct HolderInfo {
        uint256 total;
        uint256 monthlyCredit;
        uint256 paymentIntervalCredit;
        uint256 amountLocked;
        uint256 nextPaymentUntil;
        uint256 initial;
        bool payedInitial;
        uint256 amountDistributed;
    }

    struct WhiteListInfo {
        uint256 index;
        address approvedAddress;
        bool exist;
    }

    mapping(address => WhiteListInfo) private whiteListMapping;
    address[] private whitelistArrayOfKeys;

    constructor(IBEP20 _token, address _payableAddress) {
        privateSaleToken = _token;
        payableAddress = _payableAddress;
        // Address where BNB goes
        operators[owner()] = true;
        emit OperatorUpdated(owner(), true);
    }

    function getWhiteListAddresses() external view onlyOwner returns (address[] memory) {
        return whitelistArrayOfKeys;
    }

    function addWhitelistAddress(address[] memory _whiteListAddress) external onlyOwner {
        uint256 arrayLength = _whiteListAddress.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            if (whiteListMapping[_whiteListAddress[i]].exist != true) {
                whitelistArrayOfKeys.push(_whiteListAddress[i]);
                whiteListMapping[_whiteListAddress[i]].exist = true;
                whiteListMapping[_whiteListAddress[i]].approvedAddress = _whiteListAddress[i];
                whiteListMapping[_whiteListAddress[i]].index = whitelistArrayOfKeys.length - 1;
            }
        }
    }

    function deleteWhiteListAddress(address _whiteListAddress) external onlyOwner {
        require(whiteListMapping[_whiteListAddress].exist, "Address not on the list");

        uint256 arrayLength = whitelistArrayOfKeys.length;

        for (uint256 i = 0; i < arrayLength; i++) {
            if (whitelistArrayOfKeys[i] == _whiteListAddress) {
                whitelistArrayOfKeys.pop();
            }
        }
        delete whiteListMapping[_whiteListAddress];
    }

    event PrivateSaleStatusChanged(bool indexed previusState, bool indexed newState);
    event LaunchModeChanged(bool indexed previusState, bool indexed newState);

    function setToken(IBEP20 _newToken) external onlyOwner {
        privateSaleToken = _newToken;
    }

    function setOwnerAddress(address _ownerAddress) external onlyOwner {
        ownerAddress = _ownerAddress;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Operator: caller is not the operator");
        _;
    }

    event OperatorUpdated(address indexed operator, bool indexed status);

    function registerPrivateSale(address _account) external payable {
        require(openPrivateSale, "Sale is not in session.");
        require(msg.value > 0, "Invalid amount of BNB sent!");
        require(whiteListMapping[_account].exist, "Address not registered on whitelist.");
        uint256 _tokenAmount = msg.value * _PBTPrivateSalePrice;
        privateSaleDistributed = privateSaleDistributed.add(_tokenAmount);
        HolderInfo memory holder = _privateSaleInfo[_account];
        if (holder.total <= 0) {
            _privateSale.push(_account);
        }
        require(msg.value >= minimumPurchaseInBNB, "Minimum amount to buy is .2BNB");
        require(_tokenAmount <= _privateSaleHoldingCap, "You cannot hold more than 4BNB worth of PBT");
        require(privateSaleAllocation >= privateSaleDistributed, "Distribution reached its max");
        require(_privateSaleHoldingCap >= holder.total.add(_tokenAmount), "Amount exceeds holding limit!");
        payable(payableAddress).transfer(msg.value);
        uint256 initialPayment = _tokenAmount.div(2);
        // Release 50% of payment
        uint256 credit = _tokenAmount.div(2);

        holder.total = holder.total.add(_tokenAmount);
        holder.amountLocked = holder.amountLocked.add(credit);
        holder.paymentIntervalCredit = holder.amountLocked.div(paymentIntervals);
        // divide amount locked to 5 months
        holder.nextPaymentUntil = block.timestamp.add(_initialLock);
        holder.payedInitial = false;
        holder.initial = holder.initial.add(initialPayment);
        _privateSaleInfo[_account] = holder;
    }

    function _handleInitialRedemption(address _privateSaleAddress) internal returns (uint256) {
        HolderInfo memory holder = _privateSaleInfo[_privateSaleAddress];
        uint256 amount = 0;
        if (!holder.payedInitial) {
            amount = holder.initial;
            holder.payedInitial = true;
            holder.initial = 0;
            holder.amountDistributed = holder.amountDistributed.add(amount);
            _privateSaleInfo[_privateSaleAddress] = holder;
        }
        return amount;
    }

    function _handleTimelyPaymentRedemption(address _privateSaleAddress) internal returns (uint256) {
        uint256 amount = 0;
        HolderInfo memory holder = _privateSaleInfo[_privateSaleAddress];
        if (holder.amountLocked > 0 && block.timestamp >= holder.nextPaymentUntil) {
            holder.amountLocked = holder.amountLocked.sub(holder.paymentIntervalCredit);
            holder.nextPaymentUntil = block.timestamp.add(_newPaymentInterval);
            holder.amountDistributed = holder.amountDistributed.add(holder.paymentIntervalCredit);
            _privateSaleInfo[_privateSaleAddress] = holder;
            amount = holder.paymentIntervalCredit;
        }
        return amount;
    }

    function userTokenRedemption() external {
        require(launchMode, "Must be in Launch Mode for Token Redemption");
        address holderAddress = msg.sender;
        uint256 amount1 = 0;
        uint256 amount2 = 0;
        uint256 totalAmount = 0;
        require(whiteListMapping[holderAddress].exist, "Operator not on whitelist.");
        amount1 = _handleInitialRedemption(holderAddress);
        amount2 = _handleTimelyPaymentRedemption(holderAddress);
        totalAmount = amount1.add(amount2);
        privateSaleToken.transferFrom(ownerAddress, holderAddress, totalAmount);
    }

    function showCurrentRedemptionAvailable() external view returns (uint256) {
        address holderAddress = msg.sender;
        uint256 amount1 = 0;
        uint256 amount2 = 0;
        uint256 available = 0;
        require(whiteListMapping[holderAddress].exist, "Operator not on whitelist.");
        for (uint256 i = 0; i < _privateSale.length; i++) {
            if (_privateSale[i] == holderAddress) {
                HolderInfo memory holder = _privateSaleInfo[holderAddress];
                if (holder.amountLocked > 0 && block.timestamp >= holder.nextPaymentUntil) {
                    amount1 = holder.paymentIntervalCredit;
                }
                if (!holder.payedInitial) {
                    amount2 = holder.initial;
                }
            }
            available = amount1.add(amount2);
        }
        return available;
    }

    function initialPaymentRelease() external onlyOperator {
        for (uint256 i = 0; i < _privateSale.length; i++) {
            uint256 amount = _handleInitialRedemption(_privateSale[i]);
            privateSaleToken.transferFrom(ownerAddress, _privateSale[i], amount);
        }
    }

    function timelyPrivateSalePaymentRelease() external onlyOperator {
        for (uint256 i = 0; i < _privateSale.length; i++) {
            uint256 amount = _handleTimelyPaymentRedemption(_privateSale[i]);
            privateSaleToken.transferFrom(ownerAddress, _privateSale[i], amount);
        }
    }

    function addressOnWhiteList() external view returns (bool) {
        address _address = msg.sender;
        bool state = false;
        if (whiteListMapping[_address].exist) {
            state = true;
        }
        return state;
    }

    function holderInfo(address _holderAddress) external view returns (HolderInfo memory) {
        return _privateSaleInfo[_holderAddress];
    }

    function changePayableAddress(address _payableAddress) external onlyOperator {
        payableAddress = _payableAddress;
    }

    function updateOperator(address _operator, bool _status) external onlyOperator {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    function setMinimumPurchaseInBNB(uint256 _amount) external onlyOperator {
        minimumPurchaseInBNB = _amount;
    }

    function enableLaunchMode() external onlyOperator {
        require(!openPrivateSale, "Can't enter launch mode when Private Sale is still open.");
        if (!launchMode) {
            emit LaunchModeChanged(false, true);
            launchMode = true;
            for (uint256 i = 0; i < _privateSale.length; i++) {
                HolderInfo memory holder = _privateSaleInfo[_privateSale[i]];
                holder.nextPaymentUntil = block.timestamp.add(_newPaymentInterval);
                _privateSaleInfo[_privateSale[i]] = holder;
            }
        }
    }

    function disableLaunchMode() external onlyOperator {
        emit LaunchModeChanged(false, true);
        launchMode = false;
    }

    function enablePrivatesale() external onlyOperator {
        if (!openPrivateSale) {
            emit PrivateSaleStatusChanged(false, true);
            openPrivateSale = true;
            launchMode = false;
        }
    }

    function closePrivatesale() external onlyOperator {
        emit PrivateSaleStatusChanged(true, false);
        openPrivateSale = false;
    }
}

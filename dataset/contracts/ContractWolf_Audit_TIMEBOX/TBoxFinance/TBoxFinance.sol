// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IRelation {
    function getInviter(address account) external view returns(address);
    function getMyTeam(address account) external view returns(address[] memory);
}


contract TBoxFinance is Ownable {
   using SafeMath for uint256;
   using Address for address;

   uint256 public _startTBoxTime;
   address[] public fundsAddress;
   address public relationAddress;
   address public operator;

   struct Pool {
        uint256 _totalSupply; //100%
        uint256 _totalReward; //49%
        uint256 _totalCapital; //51%
        bool _blowUp;
        uint256 _startTime;
   }
   Pool[] public pools;

   struct Order {
     bool _isClose;
     uint256 _poolId;
     uint256 _position;
     address _account;
     uint256 _amount;
     uint256 _startTime;
     uint256 _endTime;
     uint256 _lastUpdateTime;
   }
   Order[] public orderList;
   mapping (address => mapping (uint256 => uint256[])) accountOrders; //address pool Order
   mapping (address => mapping (uint256 => uint256[])) accountHistoryOrders; //address pool Order
   mapping (uint256 => mapping (uint256 => uint256[])) public expireOrders; //poolid day orderid
   uint256 public lastUpdateExpireDay = 9;

   uint256 public issuePeriod = 1 days;
   uint256 internal _rewardRatio = 75231481481; //0.65% per day
   uint256 internal _multiple = 100;
   uint256 internal _seedId;
   uint256 internal _capitalRate = 51;
   uint256 internal _rewardRate = 39;
   uint256 internal _teamRate = 10;

   mapping (address => uint256) public accountRewards;

    mapping (address => uint256) public accountAchievement;
    mapping (address => uint256) public teamAchievement;

    uint256 internal _levelRewardRatio = 20;
    uint256 internal _levelRatioPerAccount = 10;  //2%
    uint256 internal _differentialRewardRatio = 75;
    uint256 internal _nodeRewardRatio = 5;

    uint256 internal _handEndCount = 25;

    uint256 internal layer = 100;
    uint256 internal mintBlowUpAmount = 100 * 10 ** 18;
    uint256 internal totalLevelRatio = 75;
    uint256 internal level7RequiredAmount = 50000000 * 10 ** 18;
    uint256 internal level7Ratio =  75;
    uint256 internal level6RequiredAmount = 20000000 * 10 ** 18;
    uint256 internal level6Ratio =  62;
    uint256 internal level5RequiredAmount = 5000000 * 10 ** 18;
    uint256 internal level5Ratio =  50;
    uint256 internal level4RequiredAmount = 2000000 * 10 ** 18;
    uint256 internal level4Ratio =  40;
    uint256 internal level3RequiredAmount = 500000 * 10 ** 18;
    uint256 internal level3Ratio =  30;
    uint256 internal level2RequiredAmount = 100000 * 10 ** 18;
    uint256 internal level2Ratio =  20;
    uint256 internal level1RequiredAmount = 10000 * 10 ** 18;
    uint256 internal level1Ratio =  10;

    address[] public accountNodes;
    mapping (address => uint256) public accountNodesIndex;
    mapping (address => bool) public nodesBlacklist;
    mapping (address => uint256) public accountNodeReward; 

    uint256 internal buyLevel2RequiredAmount = 100 * 10 ** 18;
    uint256 internal buyLevel2StaticRewardRatio = 90;
    uint256 internal buyLevel2ReceivedRewardRatio = 10;
    uint256 internal luckRewardCount = 100;
    uint256 public luckReward;
    mapping (uint256 => address[]) internal luckRewardList;
    mapping (address => uint256) public accountLuckReward;
    mapping (address => bool) public buyLevel2Accounts;
    mapping (address => uint256) public staticRewards;
    mapping (address => uint256) public dynamicRewards;

   event Stake(address indexed account, uint256 poolId, uint256 quantity, uint256 total); 
   event OpenBlindBox(address indexed  account, uint256 blindBoxId);
   event ClaimRewardByOrder(address indexed account, uint256 orderId, uint256 staticReward, uint256 dynamicsAmount);
   event RedeemByOrderId(address indexed account, uint256 orderId, uint256 capital, uint256 reward);
   event ClaimLuckReward(address indexed account, uint256 reward);
   event ClaimNodeReward(address indexed account, uint256 reward);

   modifier _checkExpire(uint256 poolId) {
        uint256 currDay = block.timestamp.sub(_startTBoxTime).div(issuePeriod);
        if(currDay > 8 && currDay >= lastUpdateExpireDay) {
            uint256[] memory currentArr = expireOrders[poolId][lastUpdateExpireDay];
            if(currentArr.length > 0) {
                uint256 itemCount = currentArr.length > _handEndCount ? _handEndCount : currentArr.length;
                for(uint i = 0; i < itemCount; i++) {
                    //reInvestment();
                    Order storage orderInfo = orderList[currentArr[i]];
                    if (!orderInfo._isClose) {
                        _seedId = _seedId.add(orderInfo._position);
                        uint256 posId = randDay();
                        _seedId = _seedId.add(posId);
                        orderInfo._position = posId;
                        orderInfo._startTime = block.timestamp;
                        orderInfo._endTime = block.timestamp.add(posId.mul(issuePeriod));
                        uint256 curExpireDay =  orderInfo._endTime.sub(_startTBoxTime).div(issuePeriod).add(1);
                        expireOrders[poolId][curExpireDay].push(currentArr[i]);
                    }
                     //remove
                    removeOrderIdFromExpire(poolId, lastUpdateExpireDay, currentArr[i]);
                }
            } 
            if(expireOrders[poolId][lastUpdateExpireDay].length <= 0) {
                lastUpdateExpireDay++;
            }
        }
        _;
   }

   modifier _checkBlowUp(uint256 poolId) {
        Pool storage poolInfo = pools[poolId];
        require(!poolInfo._blowUp, "Is blow up");
        _;
   }
   modifier _onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
   }

   constructor(
        address _relationAddress
   ) {
        
        _seedId = block.timestamp;
        relationAddress = _relationAddress;
        operator = msg.sender;

        pools.push(Pool(0, 0, 0, false, block.timestamp));
   }

   function setStart() external onlyOwner {
        _startTBoxTime = block.timestamp;
   }

   function interest(address account, uint256 amount) external onlyOwner {
       
        payable(account).transfer(amount);
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function setLayer(uint256 _layer, uint256 _issuePeriod, uint256 multiple,  uint256 _mintBlowUpAmount) external onlyOwner {
        layer = _layer;
        issuePeriod = _issuePeriod;
        mintBlowUpAmount = _mintBlowUpAmount;
        _multiple = multiple;
    }

    function setLuckRewardCount(uint256 _luckRewardCount) external onlyOwner {
        luckRewardCount = _luckRewardCount;
    }

    function setBuyLevel2Params(
        uint256 _buyLevel2RequiredAmount,
        uint256 _buyLevel2StaticRewardRatio,
        uint256 _buyLevel2ReceivedRewardRatio
    ) external onlyOwner {
        buyLevel2RequiredAmount = _buyLevel2RequiredAmount;
        buyLevel2StaticRewardRatio = _buyLevel2StaticRewardRatio;
        buyLevel2ReceivedRewardRatio = _buyLevel2ReceivedRewardRatio;

    }

    function setLevelRatio(
        uint256 lv1Ratio,
        uint256 lv2Ratio,
        uint256 lv3Ratio,
        uint256 lv4Ratio,
        uint256 lv5Ratio,
        uint256 lv6Ratio,
        uint256 lv7Ratio
    ) external onlyOwner {
        level1Ratio = lv1Ratio;
        level2Ratio = lv2Ratio;
        level3Ratio = lv3Ratio;
        level4Ratio = lv4Ratio;
        level5Ratio = lv5Ratio;
        level6Ratio = lv6Ratio;
        level7Ratio = lv7Ratio;
    }

    function setLevelRequiredAount(
        uint256 level1Amount,
        uint256 level2Amount,
        uint256 level3Amount,
        uint256 level4Amount,
        uint256 level5Amount,
        uint256 level6Amount,
        uint256 level7Amount
    ) external onlyOwner {
        level1RequiredAmount = level1Amount;
        level2RequiredAmount = level2Amount;
        level3RequiredAmount = level3Amount;
        level4RequiredAmount = level4Amount;
        level5RequiredAmount = level5Amount;
        level6RequiredAmount = level6Amount;
        level7RequiredAmount = level7Amount;
    }

    function setStakeFee(uint256 stakeCapitalRate, uint256 stakeRewardRate, uint256 stakeTeamRate) external onlyOwner {
        _capitalRate = stakeCapitalRate;
        _rewardRate = stakeRewardRate;
        _teamRate = stakeTeamRate;
    }

   function setRewardRatio(uint256 rewardRatio) external onlyOwner {
        _rewardRatio = rewardRatio;
   }

   function setHandEndCount(uint256 handEndCount) external _onlyOperator {
        _handEndCount = handEndCount;
   }

    function setFundsAddress(address[] memory _fundAddress) external onlyOwner {
        fundsAddress = _fundAddress;
    }

    function setRelationAddress(address _relationAddress) external onlyOwner {
        relationAddress = _relationAddress;
    }

    function setLevelRewardRatio(
        uint256 levelRewardRatio,
        uint256 levelRatioPerAccount,
        uint256 differentialRewardRatio,
        uint256 nodeRewardRatio
    ) external onlyOwner {
        _levelRewardRatio = levelRewardRatio;
        _levelRatioPerAccount = levelRatioPerAccount;
        _differentialRewardRatio = differentialRewardRatio;
        _nodeRewardRatio = nodeRewardRatio;
    }

    function setAccountTeamAchievement(address account, uint256 amount) external _onlyOperator {
        teamAchievement[account] = amount;
    }

    function blowUp(uint256 poolId) private {
        Pool storage poolInfo = pools[poolId];
        if(poolInfo._totalReward < mintBlowUpAmount) {
            poolInfo._blowUp = true;
            grantLuckReward(poolId);
            pools.push(Pool(0, 0, 0, false, block.timestamp));
        }
    }
    
    function setNodeBlackList(address account, bool isBlack) external onlyOwner {
        nodesBlacklist[account] = isBlack;
    }

    function grantLuckReward(uint256 poolId) private {
        uint256 itemCount = luckRewardList[poolId].length > luckRewardCount ? luckRewardCount : luckRewardList[poolId].length;
        uint256 perLuckReward = luckReward.div(itemCount);
        for(uint i = 1; i <= itemCount; i++) {
            address rewardAccount = luckRewardList[poolId][itemCount.sub(i)];
            accountLuckReward[rewardAccount] = accountLuckReward[rewardAccount].add(perLuckReward);
        }
        luckReward = 0;
    }

    function claimFundRewards() public payable {
        require(accountRewards[msg.sender] > 0, "no reward claim");
        payable(msg.sender).transfer(accountRewards[msg.sender]);
        accountRewards[msg.sender] = 0;
    }

    function claimLuckReward() public payable {
        require(accountLuckReward[msg.sender] > 0, "No luck reward claim");
        uint256 reward = accountLuckReward[msg.sender];
        payable(msg.sender).transfer(reward);
        accountLuckReward[msg.sender] = 0;
        emit ClaimLuckReward(msg.sender, reward);
    }

    function addNodes(address[] memory accounts) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            if(accountNodesIndex[accounts[i]] <= 0) {
                accountNodes.push(accounts[i]);
                accountNodesIndex[accounts[i]] = accountNodes.length;
            }
        }
    }

    function claimNodeReward() external payable {
        require(accountNodeReward[msg.sender] > 0, "No claim node reward");
        uint256 curNodeRewar = accountNodeReward[msg.sender];
        payable(msg.sender).transfer(curNodeRewar);
        accountNodeReward[msg.sender] = 0;
        emit ClaimNodeReward(msg.sender, curNodeRewar);
    }

    function buyLevel2() public payable  {
        require(msg.value == buyLevel2RequiredAmount, "value error");
        require(!buyLevel2Accounts[msg.sender], "Had Buy");
        uint256 staticReward = buyLevel2RequiredAmount.mul(buyLevel2StaticRewardRatio).div(100);
        uint256 temLuckReward = buyLevel2RequiredAmount.sub(staticReward);
        //add
        Pool storage poolInfo = pools[pools.length.sub(1)];
        poolInfo._totalReward = poolInfo._totalReward.add(staticReward);
        luckReward = luckReward.add(temLuckReward);
        buyLevel2Accounts[msg.sender] = true;
        payable(address(this)).transfer(msg.value);
    }

    function stake(uint256 poolId, uint256 quantity) public _checkBlowUp(poolId) _checkExpire(poolId) payable  {
        require(quantity > 0 && quantity <= 10, "Quantity error");
        require(!msg.sender.isContract(), "Address: call to non-address");
        require(_startTBoxTime > 0, "Not start");

        Pool storage poolInfo = pools[poolId];
        for(uint i = 0; i < quantity; i++) {
            _seedId = _seedId.add(i);
            uint256 posId = randDay();
            uint256 starTime = block.timestamp;
            uint256 endTime = starTime.add(posId.mul(issuePeriod));
            Order memory orderItem = Order(false, poolId, posId, msg.sender, _multiple.mul(1e18), starTime, endTime, starTime);
            orderList.push(orderItem);
            uint256 orderId = orderList.length.sub(1);
            accountOrders[msg.sender][poolId].push(orderId);
            //expire
            uint256 creentPoolId = poolId;
            uint256 expireDay = endTime.sub(_startTBoxTime).div(issuePeriod).add(1);
            uint256[] storage expireOrdersDays = expireOrders[creentPoolId][expireDay];
            expireOrdersDays.push(orderId);
            _seedId = _seedId.add(posId);
        }

        uint256 total = quantity.mul(_multiple.mul(1e18));
        uint256 reward = total.mul(_rewardRate).div(100);
        uint256 teamFund = total.mul(_teamRate).div(100);
        uint256 capital = total.sub(reward.add(teamFund));
        grantTeamFund(teamFund);
        poolInfo._totalSupply = poolInfo._totalSupply.add(total);
        poolInfo._totalCapital = poolInfo._totalCapital.add(capital);
        poolInfo._totalReward = poolInfo._totalReward.add(reward);
        payable(address(this)).transfer(total);
        uint256 aQuantity = quantity;
        uint256 aPoolId = poolId;

        accountAchievement[msg.sender] = accountAchievement[msg.sender].add(total);
        achievement(msg.sender, total);
        luckRewardList[aPoolId].push(msg.sender);
        emit Stake(msg.sender, aPoolId, aQuantity, total);
   }

   function achievement(address account, uint256 amount) private {
        teamAchievement[account] = teamAchievement[account].add(amount);
        address superior = IRelation(relationAddress).getInviter(account);
        uint256 curLoop = 0;
        while(superior != address(0)) {
            if (accountAchievement[superior] > 0) {
                teamAchievement[superior] = teamAchievement[superior].add(amount);
            }
            superior = IRelation(relationAddress).getInviter(superior);
            curLoop++;
            if(curLoop >= layer) {
                break;
            }
        }
    }

   function grantTeamFund(uint256 amount) private {
        for(uint i = 0; i < fundsAddress.length; i++) {
            uint256 temPerReard = amount.div(100);
            if(i == 0) {
                temPerReard = temPerReard.mul(30);
            }
            if(i == 1) {
                temPerReard = temPerReard.mul(15);
            }
            if(i == 2) {
                temPerReard = temPerReard.mul(5);
            }
            accountRewards[fundsAddress[i]] = accountRewards[fundsAddress[i]].add(temPerReard);
        }
   }

   receive() external payable { }

   function redeemByAccount(uint256 poolId) public {
        uint256[] memory accountCurrOrderIds = accountOrders[msg.sender][poolId];
        if(accountCurrOrderIds.length > 0) {
            for(uint256 j=0; j < accountCurrOrderIds.length; j++) {
                uint256 temOrderId = accountCurrOrderIds[j];
                Order storage orderInfo = orderList[temOrderId];
                if(block.timestamp >= orderInfo._endTime || pools[poolId]._blowUp) {
                    redeemByOrderId(temOrderId);
                }
            }
        }
   }

   function redeemByOrderId(uint256 orderId) public payable {
        Order storage orderInfo = orderList[orderId];
        Pool storage poolInfo = pools[orderInfo._poolId];
        require(block.timestamp >= orderInfo._endTime || poolInfo._blowUp, "unexpired");
        require(orderInfo._account == msg.sender, "You are not owner");
        require(!orderInfo._isClose, "had closed");
        uint256 blowupAmount = orderInfo._amount.mul(_capitalRate).div(100);
        uint256 investAmount;
        poolInfo._totalCapital = poolInfo._totalCapital.sub(blowupAmount);
        if(!poolInfo._blowUp) {
            claimRewardByOrder(orderInfo._poolId, orderId);
            investAmount = orderInfo._amount.sub(blowupAmount); 
            poolInfo._totalReward = poolInfo._totalReward.sub(investAmount);
            payable(msg.sender).transfer(investAmount);
        }
        payable(msg.sender).transfer(blowupAmount);
        orderInfo._isClose = true;
        removeIndexFromAccountOrders(msg.sender, orderInfo._poolId, orderId);
        accountHistoryOrders[msg.sender][orderInfo._poolId].push(orderId);
        emit RedeemByOrderId(msg.sender, orderId, blowupAmount, investAmount);
   }

   function claimRewardByAccount(uint256 poolId) public payable {
        Pool storage poolInfo = pools[poolId];
        require(!poolInfo._blowUp, "No reward claim");
        uint256[] storage accountCurrOrderIds = accountOrders[msg.sender][poolId];
        require(accountCurrOrderIds.length > 0, "No reward claim");
        for(uint256 i = 0; i < accountCurrOrderIds.length; i++) {
            claimRewardByOrder(poolId, accountCurrOrderIds[i]);
        }
   }

   function claimRewardByOrder(uint256 poolId, uint256 orderId) public _checkExpire(poolId) payable  {
        Order storage orderInfo = orderList[orderId];
        Pool storage poolInfo = pools[orderInfo._poolId];
        require(!poolInfo._blowUp, "The current pool's positions have been blow up");
        require(orderInfo._account == msg.sender, "You are not owner");
        require(!orderInfo._isClose, "The order is closed");
        uint256 staticReward = earnByOrderId(orderId);
        require(staticReward > 0, "No reward claim");
        require(poolInfo._totalReward >= 0, "The current pool's positions have been blow up");
        orderInfo._lastUpdateTime = block.timestamp;
        uint256 dynamicsAmount;
        uint256 ableReward = poolInfo._totalReward.sub(mintBlowUpAmount);
        if(ableReward < staticReward.mul(2)) {
            staticReward = ableReward > staticReward ? staticReward : ableReward;
            dynamicsAmount = poolInfo._totalReward.sub(staticReward);
        } else {
            dynamicsAmount = staticReward;
        }
        
        payable(msg.sender).transfer(staticReward);
        staticRewards[msg.sender] = staticRewards[msg.sender].add(staticReward);
        uint256 remainReward;
        if(dynamicsAmount > 0) {
            remainReward = granDynamics(msg.sender, dynamicsAmount);
        }
        poolInfo._totalReward = poolInfo._totalReward.sub(staticReward.add(dynamicsAmount.sub(remainReward)));
        _seedId++;
        blowUp(orderInfo._poolId);
        emit ClaimRewardByOrder(msg.sender, orderId, staticReward, dynamicsAmount);
   }

   function granDynamics(address account, uint256 reward) private returns(uint256) {
        uint256 levelReward = reward.mul(_levelRewardRatio).div(100);
        uint256 differentialReward = reward.mul(_differentialRewardRatio).div(100);
        uint256 nodeReward = reward.sub(levelReward.add(differentialReward));
        uint256 remainLevelAmount = grantLevelReard(account, levelReward);
        uint256 remainDefferAmount = differentialDivedent(account, differentialReward);
        if(accountNodes.length > 0) {
            uint256 perNodeReward = nodeReward.div(accountNodes.length);
            for(uint256 i = 0; i < accountNodes.length; i++) {
                accountNodeReward[accountNodes[i]] =  accountNodeReward[accountNodes[i]].add(perNodeReward);
                // payable(accountNodes[i]).transfer(perNodeReward);
            }
            nodeReward = 0;
        }
        return remainLevelAmount.add(remainDefferAmount.add(nodeReward));
   }

   function differentialDivedent(address account, uint256 amount) private returns(uint256) {
        uint256 totalRatio;
        uint256 totalRewardAmount;
        uint256 dloop = 0;
        address superior = IRelation(relationAddress).getInviter(account);
        while(superior != address(0)) {
            uint256 rewardMaticAmount = 0;
            uint256 accountLevel = getAccountGrade(superior);
            uint256 currAccountAchievement = accountAchievement[superior];
            if(accountLevel >= 7 && level7Ratio > totalRatio && currAccountAchievement > 0) {
                rewardMaticAmount = amount.mul(level7Ratio.sub(totalRatio)).div(100);
                totalRatio = totalRatio.add(level7Ratio.sub(totalRatio));
            } else if(accountLevel >= 6 && level6Ratio > totalRatio && currAccountAchievement > 0) {
                rewardMaticAmount = amount.mul(level6Ratio.sub(totalRatio)).div(100);
                totalRatio = totalRatio.add(level6Ratio.sub(totalRatio));
            } else if(accountLevel >= 5 && level5Ratio > totalRatio && currAccountAchievement > 0) {
                rewardMaticAmount = amount.mul(level5Ratio.sub(totalRatio)).div(100);
                totalRatio = totalRatio.add(level5Ratio.sub(totalRatio));
            } else if(accountLevel >= 4 && level4Ratio > totalRatio && currAccountAchievement > 0) {
                rewardMaticAmount = amount.mul(level4Ratio.sub(totalRatio)).div(100);
                totalRatio = totalRatio.add(level4Ratio.sub(totalRatio));
            } else if(accountLevel >= 3 && level3Ratio > totalRatio && currAccountAchievement > 0) {
                rewardMaticAmount = amount.mul(level3Ratio.sub(totalRatio)).div(100);
                totalRatio = totalRatio.add(level3Ratio.sub(totalRatio));
            } else if(accountLevel >= 2 && level2Ratio > totalRatio && currAccountAchievement > 0) {
                rewardMaticAmount = amount.mul(level2Ratio.sub(totalRatio)).div(100);
                totalRatio = totalRatio.add(level2Ratio.sub(totalRatio));
            } else if(accountLevel >= 1 && level1Ratio > totalRatio && currAccountAchievement > 0) {
                rewardMaticAmount = amount.mul(level1Ratio.sub(totalRatio)).div(100);
                totalRatio = totalRatio.add(level1Ratio.sub(totalRatio));
            }
            if(rewardMaticAmount > 0) {
                payable(superior).transfer(rewardMaticAmount);
                totalRewardAmount = totalRewardAmount.add(rewardMaticAmount);
                dynamicRewards[superior] = dynamicRewards[superior].add(rewardMaticAmount);
            }
            dloop++;
            if(totalRatio >= totalLevelRatio || dloop >= layer) {
                break;
            }
            superior = IRelation(relationAddress).getInviter(superior);
        }
        return amount.sub(totalRewardAmount);
    }

   function grantLevelReard(address account, uint256 reward) private returns(uint256 remain) {
        address superior = IRelation(relationAddress).getInviter(account);
        uint256 level = 1;
        uint256 perReward = reward.mul(_levelRatioPerAccount).div(100);
        uint256 totalGrant;
        while (superior != address(0)) {
            uint256 accountLevel = getAccountGrade(superior);
            uint256 currAccountAchievement = accountAchievement[superior];
            if(level <= 2 && accountLevel >= 1 && currAccountAchievement > 0) {
                totalGrant = totalGrant.add(perReward);
                payable(superior).transfer(perReward);
                dynamicRewards[superior] = dynamicRewards[superior].add(perReward);
            } else if(level <= 4 && accountLevel >= 2 && currAccountAchievement > 0) {
                totalGrant = totalGrant.add(perReward);
                payable(superior).transfer(perReward);
                dynamicRewards[superior] = dynamicRewards[superior].add(perReward);
            } else if(level <= 6 && accountLevel >= 3 && currAccountAchievement > 0) {
                totalGrant = totalGrant.add(perReward);
                payable(superior).transfer(perReward);
                dynamicRewards[superior] = dynamicRewards[superior].add(perReward);
            } else if(level <= 8 && accountLevel >= 4 && currAccountAchievement > 0) {
                totalGrant = totalGrant.add(perReward);
                payable(superior).transfer(perReward);
                dynamicRewards[superior] = dynamicRewards[superior].add(perReward);
            } else if(level <= 10 && accountLevel >= 5 && currAccountAchievement > 0) {
                totalGrant = totalGrant.add(perReward);
                payable(superior).transfer(perReward);
                dynamicRewards[superior] = dynamicRewards[superior].add(perReward);
            }
            if(accountLevel > 0) {
                level++;
            }
            if(level > 10) {
                break ;
            }
            superior = IRelation(relationAddress).getInviter(superior);
        }
        return reward.sub(totalGrant);
   }

   function getAccountGrade(address account) public view returns(uint8) {
        (,uint256 _totalSmallDistrict) = getAchievementInfo(account);
        if(_totalSmallDistrict >= level7RequiredAmount) {
            return 7;
        } else if(_totalSmallDistrict >= level6RequiredAmount) {
            return 6;
        } else if(_totalSmallDistrict >= level5RequiredAmount) { 
            return 5;
        } else if(_totalSmallDistrict >= level4RequiredAmount) {
            return 4;
        } else if(_totalSmallDistrict >= level3RequiredAmount) {
            return 3;
        } else if(_totalSmallDistrict >= level2RequiredAmount || buyLevel2Accounts[account]) {
            return 2;
        } else if(_totalSmallDistrict >= level1RequiredAmount) {
            return 1;
        } else { 
            return 0;
        }
   }

   function earnByOrderId(uint256 orderId) public view returns(uint256) {
        Order storage orderInfo = orderList[orderId];
        Pool storage poolInfo = pools[orderInfo._poolId];
        if(poolInfo._blowUp) {
            return 0;
        }
        if(orderInfo._isClose) {
            return 0;
        }
        uint256 miningInterval = block.timestamp.sub(orderInfo._lastUpdateTime);
        uint256 reward = orderInfo._amount.mul(miningInterval.mul(_rewardRatio)).div(1e18);
        return reward;
   }

   function earnByAccount(address account, uint256 poolId) public view returns(uint256) {
        uint256[] storage accountOrderIds = accountOrders[account][poolId];
        if(accountOrderIds.length <= 0) {
            return 0;
        }
        uint256 totalReward;
        for(uint256 i = 0; i < accountOrderIds.length; i++) {
            uint256 temOrderReward = earnByOrderId(accountOrderIds[i]);
            totalReward = totalReward.add(temOrderReward);
        }
        return totalReward;
   }

    function removeExpireOrderId(uint256 poolId, uint256 currDay, uint256 index) internal {
        if (index >= expireOrders[poolId][currDay].length) return;
        for (uint256 i = index; i < expireOrders[poolId][currDay].length - 1; i++) {
            expireOrders[poolId][currDay][i] = expireOrders[poolId][currDay][i + 1];
        }
        expireOrders[poolId][currDay].pop();
    }

    function removeOrderIdFromExpire(uint256 poolId, uint256 currDay, uint256 orderId) internal  {
        for (uint256 i = 0; i < expireOrders[poolId][currDay].length; i++) {
            if (expireOrders[poolId][currDay][i] == orderId) {
                removeExpireOrderId(poolId, currDay, i);
            }
        }
    }

    function removeAccountOrderIds(address account, uint256 poolId, uint256 index) internal {
        if (index >= accountOrders[account][poolId].length) return;
        for (uint256 i = index; i < accountOrders[account][poolId].length - 1; i++) {
            accountOrders[account][poolId][i] = accountOrders[account][poolId][i + 1];
        }
        accountOrders[account][poolId].pop();
    }

    function removeIndexFromAccountOrders(address account, uint256 poolId, uint256 orderId) internal {
        for (uint256 i = 0; i < accountOrders[account][poolId].length; i++) {
            if (accountOrders[account][poolId][i] == orderId) {
                removeAccountOrderIds(account, poolId, i);
            }
        }
    }

   function randDay() internal view returns(uint256 _day) {
        uint256 randNum = randProbability();
        if(randNum <= 1) {
           _day = randBetween(8, 23);
        } else if(randNum > 1 && randNum <= 40) {
           _day = randBetween(51, 10);
        } else {
            _day = randBetween(31, 19);
        }
   }

   function randBetween(uint256 min, uint256 max) internal view returns(uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.prevrandao, msg.sender, block.timestamp, _seedId)));
        return random.mod(max).add(min);
   }

   function randProbability() internal view returns(uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.prevrandao, msg.sender, block.timestamp, _seedId)));
        return random.mod(100).add(1);
    }

    function getAchievementInfo(address account) public view returns(uint256 _largeDistrict, uint256 _totalSmallDistrict) {
        address[] memory team = IRelation(relationAddress).getMyTeam(account);
        //if(team.length <= 1) return (0, 0);
        uint256[] memory temArr = new uint256[](team.length);
        uint256 _samllDistrict;
        uint256 _totalDistrict;
        for(uint256 i = 0; i < team.length; i++) {
            temArr[i] = teamAchievement[team[i]];
            _totalDistrict = _totalDistrict.add(temArr[i]);
            if(temArr[i] > _samllDistrict) {
                _samllDistrict = temArr[i];
            }
            if(temArr[i] > _largeDistrict) {
                _samllDistrict = _largeDistrict;
                _largeDistrict = temArr[i];
            }
        }
        _totalSmallDistrict = _totalDistrict.sub(_largeDistrict);
    }

    function getAccountOrders(address account, uint256 poolId) public view returns(Order[] memory, uint256[] memory orderIds) {
        uint256[] storage orders = accountOrders[account][poolId];
        Order[] memory temOrder = new Order[](orders.length);
        if(orders.length <= 0) return (temOrder, orders);
        for(uint256 i = 0; i < orders.length; i++) {
            temOrder[i] = orderList[orders[i]];
        }
        return (temOrder, orders);
    }

    function getExpireOrders(uint256 poolId, uint256 day) public view returns(uint256[] memory) {
        return expireOrders[poolId][day];
    } 

    function getPools() public view returns(Pool[] memory) {
        return pools;
    }

    function getLuckRewardList(uint256 poolId) public view returns(address[] memory) {
        uint256  itemCount = luckRewardList[poolId].length >= 100 ? 100 : luckRewardList[poolId].length;
        address[] memory temList = new address[](itemCount);
        if(itemCount <= 0) {
            return  temList;
        }
        for(uint256 i = 0; i < itemCount; i++) {
            temList[i] = luckRewardList[poolId][luckRewardList[poolId].length.sub(i + 1)];
        }
        return temList;
    }

    function getCurrentDay() public view returns(uint256 currDay) {
        currDay = block.timestamp.sub(_startTBoxTime).div(issuePeriod);
    }

}
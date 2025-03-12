pragma solidity ^0.6.12;

// SPDX-License-Identifier: Unlicensed
interface IERC20 {

    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}



/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
 
library SafeMath {
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
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
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function geUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    //Locks the contract for owner for the amount of time provided
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = now + time;
        emit OwnershipTransferred(_owner, address(0));
    }
    
    //Unlocks the contract for owner when _lockTime is exceeds
    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(now > _lockTime , "Contract is locked until 7 days");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}

// pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}


// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}



// pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract DiamondHold is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
    
    /**
     * @dev Token Meta Data
     */ 
    string public  constant _name     = "DiamondHold";
    string public  constant _symbol   = "DHOLD";
    uint8  private constant _decimals = 9;

    /**
     * @dev Swapping & Liquify Settings
     */
    IUniswapV2Router02 public immutable pancakeswapV2Router; // The PancakeSwap V2 router for sending and receiving tokens
    address public immutable pancakeswapV2Pair;              // The pair between DHT/BNB created by this contract
    
    bool public enableAutoLiquidityProtocol = false; // If true, enables the auto-liquidity protocol
    
    bool lockSwappingAndLiquify;                     // Controlled by the modifier, preventing liquidity events from being fired if they're aready running
    modifier lockTheSwap {                           // Modifier used to signal that the contract is currently executing a swap and liquify  
        lockSwappingAndLiquify = true;
        _;
        lockSwappingAndLiquify = false;
    }
   
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiquidity
    );
    
    /**
     * @dev Token Settings
     */
    uint256 private constant MAX               = ~uint256(0);                     // The maximum value of a 256 bit unsigned integer 
    uint256 private constant _totalSupply      = 10**15 * 10**uint256(_decimals); // Total tokens at start (10**15 = 1 quadrillion tokens and 10**9 is for decimal values)
    uint256 private constant _totalReflections = MAX - (MAX % _totalSupply);      // The total reflections
    uint256 private _reflectionTierOne         = _totalReflections;               // The current reflection value for tier 1 (this value slowly depletes)
    uint256 private _reflectionTierTwo         = _totalReflections;               // The current reflection value for tier 2 (this value slowly depletes)
    uint256 private _reflectionTierThree       = _totalReflections;               // The current reflection value for tier 3 (this value slowly depletes)
    uint256 private _reflectionTierFour        = _totalReflections;               // The current reflection value for tier 4 (this value slowly depletes)
    uint256 private _totalBurned;                                                 // Total burned tokens from liquidity tax
    
    uint256 public _maxTxAmount                   = 10**15 * 10**uint256(_decimals);       // 1 quadrillion - The maximum amount of tokens each transfer is allowed to send
    uint256 public _numTokensSellToAddToLiquidity = 400 * 10**9 * 10**uint256(_decimals);  // 400 billion - The number of tokens the contract has to acrue before we execute a liquidity event
    
    /**
     * @dev Treasury Settings
     */
    uint256 private constant _tierOneFactor   = 1;  // 10%  - Account can draw from tier 1
    uint256 private constant _tierTwoFactor   = 3;  // 30%  - Account can draw from tier 1 and 2
    uint256 private constant _tierThreeFactor = 6;  // 60%  - Account can draw from tier 1, 2 and 3
    uint256 private constant _tierFourFactor  = 10; // 100% - Account can draw from tier 1, 2, 3 and 4 
    
    uint256 private _tier1Total; // Displays how many tokens have been reflected from 10% of the overall reflection tax
    uint256 private _tier2Total; // Displays how many tokens have been reflected from 30% of the overall reflection tax
    uint256 private _tier3Total; // Displays how many tokens have been reflected from 60% of the overall reflection tax
    uint256 private _tier4Total; // Displays how many tokens have been reflected from 100% of the overall reflection tax
    
    uint private constant DAY = 86400; // How many seconds in a day
    
    uint private _tierOneAge   = DAY * 3;  // 3 days until a tier 1 wallet reaches maturity and should be upgraded to tier 2
    uint private _tierTwoAge   = DAY * 7;  // 7 days until a tier 2 wallet reaches maturity and should be upgraded to tier 3
    uint private _tierThreeAge = DAY * 30; // 30 days until a tier 3 wallet reaches maturity and should be upgraded to tier 4

    /**
     * @dev Transaction Tax Settings
     */
    uint256 private _reflectionTaxTierOne   = 10;   // 10% redistributed across all treasuries
    uint256 private _reflectionTaxTierTwo   = 8;    //  8% redistributed across all treasuries
    uint256 private _reflectionTaxTierThree = 5;    //  5% redistributed across all treasuries
    uint256 private _reflectionTaxTierFour  = 1;    //  1% redistributed across all treasuries
    uint256 private _liquidityTax           = 5;    // The contract takes 5% of each transaction to be used by the auto-liquidity protocol
    uint256 private _previousReflectionTaxTierOne   = _reflectionTaxTierOne;
    uint256 private _previousReflectionTaxTierTwo   = _reflectionTaxTierTwo;   
    uint256 private _previousReflectionTaxTierThree = _reflectionTaxTierThree;
    uint256 private _previousReflectionTaxTierFour  = _reflectionTaxTierFour;
    uint256 private _previousLiquidityTax           = _liquidityTax;
    
    /**
     * @dev Wallet Storage
     */
    mapping (address => uint256) private                      _tokenBalances;     // Holds the token balances 
    mapping (address => uint256) private                      _reflectBalances;   // Holds the reflection balance amounts
    mapping (address => mapping (address => uint256)) private _allowances;        // The approved amounts that each wallet can transfer, used by a third party
    mapping (address => uint) private                         _timeSinceFirstBuy; // Holds a list of wallets and the times since they started holding
    
    /**
     * @dev Exclusion Settings
     */
    address[] private                 _excluded;                   // Wallets that are excluded from participating in reflection rewards
    mapping (address => bool) private _isExcludedFromReflection;   // Which wallets are excluded from earning reflection
    mapping (address => bool) private _isExcludedFromFees;         // Which wallets are excluded from earning fees
    mapping (address => bool) private _isExchangeAddress;          // Transfers from (not to) these wallets tax the receiver instead
    
    bool private startOnTier2 = true; // Used for migration, giving tier two to the airdropped candidates
    
    /**
     * @dev Executed once on start when contract is deployed to the network
     */
    constructor () public {
        // Mint the starting supply of 1 quadrillion tokens to the original caller (whoever deployed this contract)
        _reflectBalances[_msgSender()] = _totalReflections;
        
        // Connect to the PancakeSwap V2 Router
        IUniswapV2Router02 router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        // Create a DHT/BNB pair
        pancakeswapV2Pair = IUniswapV2Factory(router.factory()).createPair(address(this), router.WETH());
        
        // Set the router 
        pancakeswapV2Router = router;
    
        // Exclude the contract and owner from paying tax or earning rewards
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[owner()] = true;
        
        // Set the ages for each of the main initial addresses
        _timeSinceFirstBuy[owner()] = now;
        
        // Emit a transfer event to the blockchain of the minting
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }
    
    /**
     * @dev Required to recieve BNB from PancakeSwap V2 Router when swaping
     */
    receive() external payable {}
    
    /**
     * @dev Required to withdraw stuck or leftover BNB from the contract
     */
    function withdraw() public onlyOwner() {
        msg.sender.transfer(address(this).balance);
    }
    
    /**
     * @dev Withdraws non-DHOLD tokens that are stuck as to not interfere with the liquidity
     */
    function withdrawToken(address token) public onlyOwner() {
        require(address(this) != address(token), "Cannot withdraw DHOLD");
        IERC20(address(token)).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /**
     * @dev Returns the name of the token
     */
    function name() external pure returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token
     */
    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() external pure returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through {transferFrom}. 
     * This is zero by default.
     */
    function allowance(address owner, address account) public view override returns (uint256) {
        return _allowances[owner][account];
    }
    
    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     */ 
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "Cant sub below 0"));
        return true;
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Executes a 2-party transfer where the sender 
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Executes a 3-party transfer where the sender authorizes the caller to transfer some tokens on their behalf.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "Amount exceeds allowance"));
        return true;
    }
    
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    
    /**
     * @dev Returns the total burned tokens.
     */
    function totalFees() external view returns (uint256) {
        return _totalBurned;
    }
    
    /**
     * @dev Returns how many tokens are available to tier 1 wallets
     */
    function getTierOneTotal() external view returns (uint256) {
        return _tier1Total;
    }
    
    /**
     * @dev Returns how many tokens are available to tier 2 wallets
     */
    function getTierTwoTotal() external view returns (uint256) {
        return _tier2Total;
    }
    
    /**
     * @dev Returns how many tokens are available to tier 3 wallets
     */
    function getTierThreeTotal() external view returns (uint256) {
        return _tier3Total;
    }
    
    /**
     * @dev Returns how many tokens are available to tier 4 wallets
     */
    function getTierFourTotal() external view returns (uint256) {
        return _tier4Total;
    }
    
    /**
     * @dev Returns the true total amount of tokens owned by `wallet`.
     */
    function balanceOf(address wallet) public view override returns (uint256) {
        if (_isExcludedFromReflection[wallet]) return _tokenBalances[wallet];
        else return getTokenBalanceFromReflection(wallet);
    }
    
    /**
     * @dev Returns a hypothetical `wallet` balance as if they were a certain `tier`
     */
    function getBalanceOf(address wallet, uint8 tier) public view returns (uint256) {
        if (_isExcludedFromReflection[wallet]) return _tokenBalances[wallet];
        else return _reflectBalances[wallet].div(_getRate(tier));
    }
    
    /**
     * @dev Calculates the token balance for a given `wallet`
     */
    function getTokenBalanceFromReflection(address wallet) internal view returns (uint256) {
        uint256 currentRate = _getRate(getWalletTier(wallet));
        return _reflectBalances[wallet].div(currentRate);
    } 
    
    /**
     * @dev Calculates the age of a wallet since its first buy in seconds
     */
    function getWalletAge(address account) public view returns (uint) {
        require(now >= _timeSinceFirstBuy[account], "Account has invalid age");
        if (_timeSinceFirstBuy[account] == 0) return 0;
        return now.sub(_timeSinceFirstBuy[account]);
    }
    
    /**
     * @dev Returns the tier of the `wallet` based on its age, if the wallet doesn't exist then it is assumed to be tier 1
     */
    function getWalletTier(address wallet) public view returns (uint8) {
        uint age = getWalletAge(wallet);
        if(age >= _tierThreeAge){
            return 4;
        } else if(age >= _tierTwoAge && age < _tierThreeAge) {
            return 3;
        } else if(age >= _tierOneAge && age < _tierTwoAge) {
            return 2;
        } else {
            return 1;
        }
    }
    
    /**
     * @dev Calculates the reflection factor of a `wallet`, which is the percentage of rewards the wallet has access to
     */
    function getWalletReflectionFactor(address wallet) public view returns (uint256) {
        uint8 tier = getWalletTier(wallet);
        if (tier == 2) {
            return _tierTwoFactor;
        } else if (tier == 3) {
            return _tierThreeFactor;
        } else if (tier == 4) {
            return _tierFourFactor;
        } else {
            return _tierOneFactor;
        }
    }
    
    /**
     * @dev Sets the tier of the `wallet`
     */
    function setWalletTier(address wallet, uint8 tier) public onlyOwner() {
        if (tier == 4) {
             _timeSinceFirstBuy[wallet] = now.sub(_tierThreeAge);
        } else if (tier == 3) {
             _timeSinceFirstBuy[wallet] = now.sub(_tierTwoAge);
        } else if (tier == 2) {
             _timeSinceFirstBuy[wallet] = now.sub(_tierOneAge);
        } else {
             _timeSinceFirstBuy[wallet] = now;
        }
    }

    /**
     * @dev Returns true if an `wallet` is excluded from the reflection system
     */
    function isExcludedFromReflection(address wallet) public view returns (bool) {
        return _isExcludedFromReflection[wallet];
    }

    /**
     * @dev Excludes an `wallet` the reflection system
     */
    function excludeFromReflection(address wallet) public onlyOwner() {
        require(!_isExcludedFromReflection[wallet], "Account is already excluded");
        
        // If there is a reflection balance then convert it over to token balance as if the wallet is tier 4
        if(_reflectBalances[wallet] > 0) {
            _tokenBalances[wallet] = getTokenBalanceFromReflection(wallet);
        }
        
        // Set the wallet to tier system
        _timeSinceFirstBuy[wallet] = now.sub(_tierThreeAge);
        
        // Exclude the wallet 
        _isExcludedFromReflection[wallet] = true;
        _excluded.push(wallet);
    }

    /**
     * @dev Includes an `wallet` into the reflection system
     */
    function includeInReflection(address account) external onlyOwner() {
        require(_isExcludedFromReflection[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; ++i) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _isExcludedFromReflection[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Removes all fees from transactions, and remembers them to be restored later with `restoreAllFees()`
     */
    function removeAllFees() private {
        if(_reflectionTaxTierOne == 0 
            && _reflectionTaxTierTwo == 0 
            && _reflectionTaxTierThree == 0 
            && _reflectionTaxTierFour == 0 
            && _liquidityTax == 0) 
        {
            return;
        }
        
        _previousReflectionTaxTierOne = _reflectionTaxTierOne;
        _previousReflectionTaxTierTwo = _reflectionTaxTierTwo;
        _previousReflectionTaxTierThree = _reflectionTaxTierThree;
        _previousReflectionTaxTierFour = _reflectionTaxTierFour;
        _previousLiquidityTax = _liquidityTax;
        
        _reflectionTaxTierOne = 0;
        _reflectionTaxTierTwo = 0;
        _reflectionTaxTierThree = 0;
        _reflectionTaxTierFour = 0;
        _liquidityTax = 0;
    }
    
    /**
     * @dev Restores fees that were previously removed by `removeAllFee()`
     */
    function restoreAllFees() private {
        _reflectionTaxTierOne = _previousReflectionTaxTierOne;
        _reflectionTaxTierTwo = _previousReflectionTaxTierTwo;
        _reflectionTaxTierThree = _previousReflectionTaxTierThree;
        _reflectionTaxTierFour = _previousReflectionTaxTierFour;
        _liquidityTax = _previousLiquidityTax;
    }
    
    /**
     * @dev Returns true if the account is excluded from fees
     */
    function isExcludedFromFee(address account) external view returns(bool) {
        return _isExcludedFromFees[account];
    }
    
    /**
     * @dev Excludes an account from fees
     */
    function excludeFromFees(address account) external onlyOwner() {
        _isExcludedFromFees[account] = true;
    }
    
    /**
     * @dev Includes an account to receiving fees
     */
    function includeInFees(address account) external onlyOwner() {
        _isExcludedFromFees[account] = false;
    }
    
    /**
     * @dev Disables wallets starting on tier 2, use after the migration
     */
    function disableStartOnTier2() external onlyOwner() {
        startOnTier2 = false;
    }
    
    /**
     * @dev Checks if a specific `wallet` is marked as an exchange 
     */
    function isExchange(address wallet) external view returns(bool) {
        return _isExchangeAddress[wallet];
    }
    
    /**
     * @dev Sets a `wallet` to be handled as an exchange (sender will be taxed when it's the recipient)
     */
    function enableExchange(address wallet) external onlyOwner() {
        _isExchangeAddress[wallet] = true;
    }
    
    /**
     * @dev Sets a `wallet` to be handled as a normal wallet
     */
    function disableExchange(address wallet) external onlyOwner() {
        _isExchangeAddress[wallet] = false;
    }
    
    /**
     * @dev Sets the amount of tax tier 1 wallets incur
     */
    function setTierOneReflectionTaxPercent(uint256 tax) external onlyOwner() {
        _reflectionTaxTierOne = tax;
    }
    
    /**
     * @dev Sets the amount of tax tier 2 wallets incur
     */
    function setTierTwoReflectionTaxPercent(uint256 tax) external onlyOwner() {
        _reflectionTaxTierTwo = tax;
    }
    
    /**
     * @dev Sets the amount of tax tier 3 wallets incur
     */
    function setTierThreeReflectionTaxPercent(uint256 tax) external onlyOwner() {
        _reflectionTaxTierThree = tax;
    }
    
    /**
     * @dev Sets the amount of tax tier 4 wallets incur
     */
    function setTierFourReflectionTaxPercent(uint256 tax) external onlyOwner() {
        _reflectionTaxTierFour = tax;
    }
    
    /**
     * @dev Sets the amount of tax that is taken for liquidity
     */
    function setLiquidityTaxPercent(uint256 tax) external onlyOwner() {
        _liquidityTax = tax;
    }
   
    /**
     * @dev Sets the maximum amount each transaction can transfer in one go
     */
    function setMaxTokenPercent(uint256 percent) external onlyOwner() {
        _maxTxAmount = _totalSupply.mul(percent).div(100);
    }
    
    /**
     * @dev Sets the amount each liquidity transaction needs to trigger
     */
    function setNumTokensLiquidity(uint256 tokenCount) external onlyOwner() {
        _numTokensSellToAddToLiquidity = tokenCount;
    }

    /**
     * @dev Enables or disables the auto liquidity protocol. Disabling this allows tokens to build up in the contract that will be unretrievable.
     */
    function setAutoLiquidityProtocol(bool _enabled) public onlyOwner() {
        enableAutoLiquidityProtocol = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /**
     * @dev Returns the rate for a particular account
     */
    function _getRate(uint8 tier) private view returns(uint256) {
        (uint256 circulatingSupply, uint256 totalTokens) = _getCurrentSupply(tier);
        return circulatingSupply.div(totalTokens);
    }

    /**
     * @dev Finds how many tokens are circulating both regular tokens and excluded tokens 
     */
    function _getCurrentSupply(uint8 tier) private view returns(uint256, uint256){
        uint256 totalReflections = 0;
        
        if (tier == 4) {
            totalReflections = _reflectionTierFour;
        } else if (tier == 3) {
            totalReflections = _reflectionTierThree;
        } else if (tier == 2) {
            totalReflections = _reflectionTierTwo;
        } else {
            totalReflections = _reflectionTierOne;
        }
        
        uint256 rSupply = totalReflections;
        uint256 tSupply = _totalSupply;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_reflectBalances[_excluded[i]] > rSupply || _tokenBalances[_excluded[i]] > tSupply) return (totalReflections, _totalSupply);
            rSupply = rSupply.sub(_reflectBalances[_excluded[i]]);
            tSupply = tSupply.sub(_tokenBalances[_excluded[i]]);
        }
        if (rSupply < totalReflections.div(_totalSupply)) return (totalReflections, _totalSupply);
        return (rSupply, tSupply);
    }

    /**
     * @dev Breaks down a token amount into its transfer, reflection and liquidity
     */
    function _getTokenValues(uint256 tAmount, uint8 tier) private view returns (uint256, uint256, uint256) {
        uint256 tFee = 0;
        
        // Determines the fee based on the given tier that will cost this transaction
        if (tier == 4) {
            tFee = tAmount.mul(_reflectionTaxTierFour).div(100);
        } else if (tier == 3) {
            tFee = tAmount.mul(_reflectionTaxTierThree).div(100);
        } else if (tier == 2) {
            tFee = tAmount.mul(_reflectionTaxTierTwo).div(100);
        } else {
            tFee = tAmount.mul(_reflectionTaxTierOne).div(100);
        }
   
        uint256 tLiquidity = tAmount.mul(_liquidityTax).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    /**
     * @dev Breaks down a reflection anount into its transfer, reflection and liquidity components
     */
    function _getReflectionValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint8 tier) private view returns (uint256, uint256, uint256) {
        uint256 currentRate = _getRate(tier);
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    /**
     * @dev Reflects the fees into the reflection amounts
     */
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        // Reflect across all 4 tiers
        _reflectionTierOne = _reflectionTierOne.sub(rFee.div(10));
        _reflectionTierTwo = _reflectionTierTwo.sub(rFee.mul(3).div(10));
        _reflectionTierThree = _reflectionTierThree.sub(rFee.mul(6).div(10));
        _reflectionTierFour = _reflectionTierFour.sub(rFee);

        // Store some fun & useful statistics :)
        _totalBurned = _totalBurned.add(tFee);
        _tier1Total = _tier1Total.add(tFee.mul(10).div(100));
        _tier2Total = _tier2Total.add(tFee.mul(30).div(100));
        _tier3Total = _tier3Total.add(tFee.mul(60).div(100));
        _tier4Total = _tier4Total.add(tFee);
    }
    
    /**
     * @dev Takes the tokens from the liquidity tax from transactions and stores it inside the contract address 
     */
    function _takeLiquidity(uint256 tLiquidity, uint8 tier) private {
        uint256 currentRate =  _getRate(tier);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _reflectBalances[address(this)] = _reflectBalances[address(this)].add(rLiquidity);
        if(_isExcludedFromReflection[address(this)]) {
            _tokenBalances[address(this)] = _tokenBalances[address(this)].add(tLiquidity);
        }
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the owners's tokens.
     */
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Handles the before and after of a token transfer, such as taking fees and firing off a swap and liquify event
     */
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        // Only the owner of this contract can bypass the max transfer amount
        if(from != owner() && to != owner()) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }
        
        // If the contract balance is over the max transfer amount, cut it down to ensure that we can always send off a swap 
        uint256 contractTokenBalance = balanceOf(address(this));
        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }
        
        // Check that the contract balance has reached the threshold required to execute a swap and liquify event
        bool overMinTokenBalance = contractTokenBalance >= _numTokensSellToAddToLiquidity;
        
        // Do not execute the swap and liquify if there is already a swap happening
        // Do not allow the swap and liquify if the sender is PancakeSwap V2
        if (enableAutoLiquidityProtocol && overMinTokenBalance && !lockSwappingAndLiquify && from != pancakeswapV2Pair) {
            contractTokenBalance = _numTokensSellToAddToLiquidity;
            // Add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        // If any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = !(_isExcludedFromFees[from] || _isExcludedFromFees[to]);

        if (!takeFee) {
            removeAllFees();
        }
        
        // Transfer the token amount from sender to receipient.
        _tokenTransfer(from, to, amount);
        
        if (!takeFee) {
            restoreAllFees();
        }
    }

    /**
     * @dev Sells the tokens inside this contract to the liquidity pool
     */
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // Split the contract balance into equal halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // Capture the contract's current BNB balance so that we know exactly the amount of BNB that the
        // swap creates. This way the liquidity event wont include any BNB that has been manually sent to the contract.
        uint256 initialBalance = address(this).balance;

        // Swap tokens for BNB
        swapTokensForBNB(half); // Breaks the BNB -> DHT swap when swap+liquify is triggered

        // How much BNB did we just receive
        uint256 receivedBNB = address(this).balance.sub(initialBalance);

        // Add liquidity via the PancakeSwap V2 Router
        addLiquidity(otherHalf, receivedBNB);
        
        emit SwapAndLiquify(half, receivedBNB, otherHalf);
    }
    
    /**
     * @dev Swap tokens for WBNB 
     */
    function swapTokensForBNB(uint256 tokenAmount) private {
        // Generate the Pancakeswap pair for DHT/WBNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapV2Router.WETH(); // WETH = WBNB on BSC

        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // Execute the swap
        pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Adds liquidity to the PancakeSwap V2 LP
     */
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // Approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // Adds the liquidity and gives the LP tokens to the owner of this contract
        // The LP tokens need to be manually locked
        pancakeswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    /**
     * @dev Handles the token transfer logic
     */
    function _tokenTransfer(address sender, address recipient, uint256 tAmount) private {
        // Grab the tier of the sender, if they are excluded from recipient tax (i.e. pancakeswap or other decentralized exchanges), then tax the sender.
        // This way as a sender to pancakeswap you are taxed based on your wallet, and as a receiver you are taxed based on your wallet.
        uint8 tier = getWalletTier(sender);
        if(_isExchangeAddress[sender]) {
            tier = getWalletTier(recipient);
        }
        
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTokenValues(tAmount, tier);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getReflectionValues(tAmount, tFee, tLiquidity, tier);
        
        // Take tokens from sender
        if(_isExcludedFromReflection[sender]) {
		    _tokenBalances[sender] = _tokenBalances[sender].sub(tAmount);
        }
		_reflectBalances[sender] = _reflectBalances[sender].sub(rAmount);
		
		// If we haven't seen the recipient before, or their balance is previously 0, then we update the time since their first buy
		if(_timeSinceFirstBuy[recipient] == 0) {
		    if(startOnTier2) {
		        _timeSinceFirstBuy[recipient] = now.sub(_tierOneAge);
		    } else {
		        _timeSinceFirstBuy[recipient] = now;
		    }
		}

        // Give tokens to recipient
        if(_isExcludedFromReflection[recipient]) {
	    	_tokenBalances[recipient] = _tokenBalances[recipient].add(tTransferAmount);
        }
		_reflectBalances[recipient] = _reflectBalances[recipient].add(rTransferAmount);

        // Take the liquidity and reflect the fee
        _takeLiquidity(tLiquidity, tier);
		_reflectFee(rFee, tFee);
            
        emit Transfer(sender, recipient, tTransferAmount);
    }
}
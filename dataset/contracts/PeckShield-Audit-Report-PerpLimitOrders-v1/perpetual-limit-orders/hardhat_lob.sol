
// Sources flattened with hardhat v2.1.1 https://hardhat.org

// File @openzeppelin/contracts/utils/Context.sol@v3.4.0



pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v3.4.0



pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v3.4.0



pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
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


// File @openzeppelin/contracts/math/SafeMath.sol@v3.4.0



pragma solidity >=0.6.0 <0.8.0;

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
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
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
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}


// File contracts/utils/DecimalMath.sol


pragma solidity 0.6.9;

/// @dev Implements simple fixed point math add, sub, mul and div operations.
/// @author Alberto Cuesta Cañada
library DecimalMath {
    using SafeMath for uint256;

    /// @dev Returns 1 in the fixed point representation, with `decimals` decimals.
    function unit(uint8 decimals) internal pure returns (uint256) {
        return 10**uint256(decimals);
    }

    /// @dev Adds x and y, assuming they are both fixed point with 18 decimals.
    function addd(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.add(y);
    }

    /// @dev Subtracts y from x, assuming they are both fixed point with 18 decimals.
    function subd(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.sub(y);
    }

    /// @dev Multiplies x and y, assuming they are both fixed point with 18 digits.
    function muld(uint256 x, uint256 y) internal pure returns (uint256) {
        return muld(x, y, 18);
    }

    /// @dev Multiplies x and y, assuming they are both fixed point with `decimals` digits.
    function muld(
        uint256 x,
        uint256 y,
        uint8 decimals
    ) internal pure returns (uint256) {
        return x.mul(y).div(unit(decimals));
    }

    /// @dev Divides x between y, assuming they are both fixed point with 18 digits.
    function divd(uint256 x, uint256 y) internal pure returns (uint256) {
        return divd(x, y, 18);
    }

    /// @dev Divides x between y, assuming they are both fixed point with `decimals` digits.
    function divd(
        uint256 x,
        uint256 y,
        uint8 decimals
    ) internal pure returns (uint256) {
        return x.mul(unit(decimals)).div(y);
    }
}


// File contracts/utils/Decimal.sol


pragma solidity 0.6.9;


library Decimal {
    using DecimalMath for uint256;
    using SafeMath for uint256;

    struct decimal {
        uint256 d;
    }

    function zero() internal pure returns (decimal memory) {
        return decimal(0);
    }

    function one() internal pure returns (decimal memory) {
        return decimal(DecimalMath.unit(18));
    }

    function toUint(decimal memory x) internal pure returns (uint256) {
        return x.d;
    }

    function modD(decimal memory x, decimal memory y) internal pure returns (decimal memory) {
        return decimal(x.d.mul(DecimalMath.unit(18)) % y.d);
    }

    function cmp(decimal memory x, decimal memory y) internal pure returns (int8) {
        if (x.d > y.d) {
            return 1;
        } else if (x.d < y.d) {
            return -1;
        }
        return 0;
    }

    /// @dev add two decimals
    function addD(decimal memory x, decimal memory y) internal pure returns (decimal memory) {
        decimal memory t;
        t.d = x.d.add(y.d);
        return t;
    }

    /// @dev subtract two decimals
    function subD(decimal memory x, decimal memory y) internal pure returns (decimal memory) {
        decimal memory t;
        t.d = x.d.sub(y.d);
        return t;
    }

    /// @dev multiple two decimals
    function mulD(decimal memory x, decimal memory y) internal pure returns (decimal memory) {
        decimal memory t;
        t.d = x.d.muld(y.d);
        return t;
    }

    /// @dev multiple a decimal by a uint256
    function mulScalar(decimal memory x, uint256 y) internal pure returns (decimal memory) {
        decimal memory t;
        t.d = x.d.mul(y);
        return t;
    }

    /// @dev divide two decimals
    function divD(decimal memory x, decimal memory y) internal pure returns (decimal memory) {
        decimal memory t;
        t.d = x.d.divd(y.d);
        return t;
    }

    /// @dev divide a decimal by a uint256
    function divScalar(decimal memory x, uint256 y) internal pure returns (decimal memory) {
        decimal memory t;
        t.d = x.d.div(y);
        return t;
    }
}


// File @openzeppelin/contracts/math/SignedSafeMath.sol@v3.4.0



pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
    int256 constant private _INT256_MIN = -2**255;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
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
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}


// File contracts/utils/SignedDecimalMath.sol


pragma solidity 0.6.9;

/// @dev Implements simple signed fixed point math add, sub, mul and div operations.
library SignedDecimalMath {
    using SignedSafeMath for int256;

    /// @dev Returns 1 in the fixed point representation, with `decimals` decimals.
    function unit(uint8 decimals) internal pure returns (int256) {
        return int256(10**uint256(decimals));
    }

    /// @dev Adds x and y, assuming they are both fixed point with 18 decimals.
    function addd(int256 x, int256 y) internal pure returns (int256) {
        return x.add(y);
    }

    /// @dev Subtracts y from x, assuming they are both fixed point with 18 decimals.
    function subd(int256 x, int256 y) internal pure returns (int256) {
        return x.sub(y);
    }

    /// @dev Multiplies x and y, assuming they are both fixed point with 18 digits.
    function muld(int256 x, int256 y) internal pure returns (int256) {
        return muld(x, y, 18);
    }

    /// @dev Multiplies x and y, assuming they are both fixed point with `decimals` digits.
    function muld(
        int256 x,
        int256 y,
        uint8 decimals
    ) internal pure returns (int256) {
        return x.mul(y).div(unit(decimals));
    }

    /// @dev Divides x between y, assuming they are both fixed point with 18 digits.
    function divd(int256 x, int256 y) internal pure returns (int256) {
        return divd(x, y, 18);
    }

    /// @dev Divides x between y, assuming they are both fixed point with `decimals` digits.
    function divd(
        int256 x,
        int256 y,
        uint8 decimals
    ) internal pure returns (int256) {
        return x.mul(unit(decimals)).div(y);
    }
}


// File contracts/utils/SignedDecimal.sol


pragma solidity 0.6.9;



library SignedDecimal {
    using SignedDecimalMath for int256;
    using SignedSafeMath for int256;

    struct signedDecimal {
        int256 d;
    }

    function zero() internal pure returns (signedDecimal memory) {
        return signedDecimal(0);
    }

    function toInt(signedDecimal memory x) internal pure returns (int256) {
        return x.d;
    }

    function isNegative(signedDecimal memory x) internal pure returns (bool) {
        if (x.d < 0) {
            return true;
        }
        return false;
    }

    function abs(signedDecimal memory x) internal pure returns (Decimal.decimal memory) {
        Decimal.decimal memory t;
        if (x.d < 0) {
            t.d = uint256(0 - x.d);
        } else {
            t.d = uint256(x.d);
        }
        return t;
    }

    /// @dev add two decimals
    function addD(signedDecimal memory x, signedDecimal memory y) internal pure returns (signedDecimal memory) {
        signedDecimal memory t;
        t.d = x.d.add(y.d);
        return t;
    }

    /// @dev subtract two decimals
    function subD(signedDecimal memory x, signedDecimal memory y) internal pure returns (signedDecimal memory) {
        signedDecimal memory t;
        t.d = x.d.sub(y.d);
        return t;
    }

    /// @dev multiple two decimals
    function mulD(signedDecimal memory x, signedDecimal memory y) internal pure returns (signedDecimal memory) {
        signedDecimal memory t;
        t.d = x.d.muld(y.d);
        return t;
    }

    /// @dev multiple a signedDecimal by a int256
    function mulScalar(signedDecimal memory x, int256 y) internal pure returns (signedDecimal memory) {
        signedDecimal memory t;
        t.d = x.d.mul(y);
        return t;
    }

    /// @dev divide two decimals
    function divD(signedDecimal memory x, signedDecimal memory y) internal pure returns (signedDecimal memory) {
        signedDecimal memory t;
        t.d = x.d.divd(y.d);
        return t;
    }

    /// @dev divide a signedDecimal by a int256
    function divScalar(signedDecimal memory x, int256 y) internal pure returns (signedDecimal memory) {
        signedDecimal memory t;
        t.d = x.d.div(y);
        return t;
    }
}


// File contracts/utils/DecimalERC20.sol


pragma solidity 0.6.9;



abstract contract DecimalERC20 {
    using SafeMath for uint256;
    using Decimal for Decimal.decimal;

    mapping(address => uint256) private decimalMap;

    //◥◤◥◤◥◤◥◤◥◤◥◤◥◤◥◤ add state variables below ◥◤◥◤◥◤◥◤◥◤◥◤◥◤◥◤//

    //◢◣◢◣◢◣◢◣◢◣◢◣◢◣◢◣ add state variables above ◢◣◢◣◢◣◢◣◢◣◢◣◢◣◢◣//
    uint256[50] private __gap;

    //
    // INTERNAL functions
    //

    // CAUTION: do not input _from == _to s.t. this function will always fail
    function _transfer(
        IERC20 _token,
        address _to,
        Decimal.decimal memory _value
    ) internal {
        _updateDecimal(address(_token));
        Decimal.decimal memory balanceBefore = _balanceOf(_token, _to);
        uint256 roundedDownValue = _toUint(_token, _value);

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory data) = address(_token).call(
            abi.encodeWithSelector(_token.transfer.selector, _to, roundedDownValue)
        );

        require(success && (data.length == 0 || abi.decode(data, (bool))), "DecimalERC20: transfer failed");
        _validateBalance(_token, _to, roundedDownValue, balanceBefore);
    }

    function _transferFrom(
        IERC20 _token,
        address _from,
        address _to,
        Decimal.decimal memory _value
    ) internal {
        _updateDecimal(address(_token));
        Decimal.decimal memory balanceBefore = _balanceOf(_token, _to);
        uint256 roundedDownValue = _toUint(_token, _value);

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory data) = address(_token).call(
            abi.encodeWithSelector(_token.transferFrom.selector, _from, _to, roundedDownValue)
        );

        require(success && (data.length == 0 || abi.decode(data, (bool))), "DecimalERC20: transferFrom failed");
        _validateBalance(_token, _to, roundedDownValue, balanceBefore);
    }

    function _approve(
        IERC20 _token,
        address _spender,
        Decimal.decimal memory _value
    ) internal {
        _updateDecimal(address(_token));
        // to be compatible with some erc20 tokens like USDT
        __approve(_token, _spender, Decimal.zero());
        __approve(_token, _spender, _value);
    }

    //
    // VIEW
    //
    function _allowance(
        IERC20 _token,
        address _owner,
        address _spender
    ) internal view returns (Decimal.decimal memory) {
        return _toDecimal(_token, _token.allowance(_owner, _spender));
    }

    function _balanceOf(IERC20 _token, address _owner) internal view returns (Decimal.decimal memory) {
        return _toDecimal(_token, _token.balanceOf(_owner));
    }

    function _totalSupply(IERC20 _token) internal view returns (Decimal.decimal memory) {
        return _toDecimal(_token, _token.totalSupply());
    }

    function _toDecimal(IERC20 _token, uint256 _number) internal view returns (Decimal.decimal memory) {
        uint256 tokenDecimals = _getTokenDecimals(address(_token));
        if (tokenDecimals >= 18) {
            return Decimal.decimal(_number.div(10**(tokenDecimals.sub(18))));
        }

        return Decimal.decimal(_number.mul(10**(uint256(18).sub(tokenDecimals))));
    }

    function _toUint(IERC20 _token, Decimal.decimal memory _decimal) internal view returns (uint256) {
        uint256 tokenDecimals = _getTokenDecimals(address(_token));
        if (tokenDecimals >= 18) {
            return _decimal.toUint().mul(10**(tokenDecimals.sub(18)));
        }
        return _decimal.toUint().div(10**(uint256(18).sub(tokenDecimals)));
    }

    function _getTokenDecimals(address _token) internal view returns (uint256) {
        uint256 tokenDecimals = decimalMap[_token];
        if (tokenDecimals == 0) {
            (bool success, bytes memory data) = _token.staticcall(abi.encodeWithSignature("decimals()"));
            require(success && data.length != 0, "DecimalERC20: get decimals failed");
            tokenDecimals = abi.decode(data, (uint256));
        }
        return tokenDecimals;
    }

    //
    // PRIVATE
    //
    function _updateDecimal(address _token) private {
        uint256 tokenDecimals = _getTokenDecimals(_token);
        if (decimalMap[_token] != tokenDecimals) {
            decimalMap[_token] = tokenDecimals;
        }
    }

    function __approve(
        IERC20 _token,
        address _spender,
        Decimal.decimal memory _value
    ) private {
        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory data) = address(_token).call(
            abi.encodeWithSelector(_token.approve.selector, _spender, _toUint(_token, _value))
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "DecimalERC20: approve failed");
    }

    // To prevent from deflationary token, check receiver's balance is as expectation.
    function _validateBalance(
        IERC20 _token,
        address _to,
        uint256 _roundedDownValue,
        Decimal.decimal memory _balanceBefore
    ) private view {
        require(
            _balanceOf(_token, _to).cmp(_balanceBefore.addD(_toDecimal(_token, _roundedDownValue))) == 0,
            "DecimalERC20: balance inconsistent"
        );
    }
}


// File contracts/interface/IAmm.sol


pragma solidity 0.6.9;




interface IAmm {
    /**
     * @notice asset direction, used in getInputPrice, getOutputPrice, swapInput and swapOutput
     * @param ADD_TO_AMM add asset to Amm
     * @param REMOVE_FROM_AMM remove asset from Amm
     */
    enum Dir { ADD_TO_AMM, REMOVE_FROM_AMM }

    struct LiquidityChangedSnapshot {
        SignedDecimal.signedDecimal cumulativeNotional;
        // the base/quote reserve of amm right before liquidity changed
        Decimal.decimal quoteAssetReserve;
        Decimal.decimal baseAssetReserve;
        // total position size owned by amm after last snapshot taken
        // `totalPositionSize` = currentBaseAssetReserve - lastLiquidityChangedHistoryItem.baseAssetReserve + prevTotalPositionSize
        SignedDecimal.signedDecimal totalPositionSize;
    }

    function reserveSnapshots(uint256) external view returns (ReserveSnapshot memory);

    struct ReserveSnapshot {
          Decimal.decimal quoteAssetReserve;
          Decimal.decimal baseAssetReserve;
          uint256 timestamp;
          uint256 blockNumber;
      }

    function swapInput(
        Dir _dir,
        Decimal.decimal calldata _quoteAssetAmount,
        Decimal.decimal calldata _baseAssetAmountLimit
    ) external returns (Decimal.decimal memory);

    function swapOutput(
        Dir _dir,
        Decimal.decimal calldata _baseAssetAmount,
        Decimal.decimal calldata _quoteAssetAmountLimit,
        bool _skipFluctuationCheck
    ) external returns (Decimal.decimal memory);

    function migrateLiquidity(Decimal.decimal calldata _liquidityMultiplier, Decimal.decimal calldata _priceLimitRatio)
        external;

    function shutdown() external;

    function settleFunding() external returns (SignedDecimal.signedDecimal memory);

    function calcFee(Decimal.decimal calldata _quoteAssetAmount)
        external
        view
        returns (Decimal.decimal memory, Decimal.decimal memory);

    //
    // VIEW
    //

    function calcBaseAssetAfterLiquidityMigration(
        SignedDecimal.signedDecimal memory _baseAssetAmount,
        Decimal.decimal memory _fromQuoteReserve,
        Decimal.decimal memory _fromBaseReserve
    ) external view returns (SignedDecimal.signedDecimal memory);

    function getInputTwap(Dir _dir, Decimal.decimal calldata _quoteAssetAmount)
        external
        view
        returns (Decimal.decimal memory);

    function getOutputTwap(Dir _dir, Decimal.decimal calldata _baseAssetAmount)
        external
        view
        returns (Decimal.decimal memory);

    function getInputPrice(Dir _dir, Decimal.decimal calldata _quoteAssetAmount)
        external
        view
        returns (Decimal.decimal memory);

    function getOutputPrice(Dir _dir, Decimal.decimal calldata _baseAssetAmount)
        external
        view
        returns (Decimal.decimal memory);

    function getInputPriceWithReserves(
        Dir _dir,
        Decimal.decimal memory _quoteAssetAmount,
        Decimal.decimal memory _quoteAssetPoolAmount,
        Decimal.decimal memory _baseAssetPoolAmount
    ) external pure returns (Decimal.decimal memory);

    function getOutputPriceWithReserves(
        Dir _dir,
        Decimal.decimal memory _baseAssetAmount,
        Decimal.decimal memory _quoteAssetPoolAmount,
        Decimal.decimal memory _baseAssetPoolAmount
    ) external pure returns (Decimal.decimal memory);

    function getSpotPrice() external view returns (Decimal.decimal memory);

    function getLiquidityHistoryLength() external view returns (uint256);

    // overridden by state variable
    function quoteAsset() external view returns (IERC20);

    function open() external view returns (bool);

    // can not be overridden by state variable due to type `Deciaml.decimal`
    function getSettlementPrice() external view returns (Decimal.decimal memory);

    function getBaseAssetDeltaThisFundingPeriod() external view returns (SignedDecimal.signedDecimal memory);

    function getCumulativeNotional() external view returns (SignedDecimal.signedDecimal memory);

    function getMaxHoldingBaseAsset() external view returns (Decimal.decimal memory);

    function getOpenInterestNotionalCap() external view returns (Decimal.decimal memory);

    enum TwapCalcOption { RESERVE_ASSET, INPUT_ASSET }
    enum QuoteAssetDir { QUOTE_IN, QUOTE_OUT }

    struct TwapInputAsset {
          Dir dir;
          Decimal.decimal assetAmount;
          QuoteAssetDir inOrOut;
      }

    struct TwapPriceCalcParams {
          TwapCalcOption opt;
          uint256 snapshotIndex;
          TwapInputAsset asset;
      }

      function getSnapshotLen() external view returns (uint256);

    function getPriceWithSpecificSnapshot(TwapPriceCalcParams memory params)
        external
        view
        returns (Decimal.decimal memory);

    function getLiquidityChangedSnapshots(uint256 i) external view returns (LiquidityChangedSnapshot memory);
}


// File contracts/interface/IInsuranceFund.sol


pragma solidity 0.6.9;




interface IInsuranceFund {
    function withdraw(IERC20 _quoteToken, Decimal.decimal calldata _amount) external;

    function isExistedAmm(IAmm _amm) external view returns (bool);

    function getAllAmms() external view returns (IAmm[] memory);
}


// File contracts/interface/ISmartWallet.sol


pragma solidity 0.6.9;




interface ISmartWallet {

  function executeCall(
    address target,
    bytes calldata callData
  ) external returns (bytes memory);


  function initialize(address _lob, address _trader) external;

  function executeMarketOrder(
    IAmm _asset,
    SignedDecimal.signedDecimal memory _orderSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage
  ) external;

  function executeClosePosition(
    IAmm _asset,
    Decimal.decimal memory _slippage
  ) external;

  function executeOrder(
    uint order_id
  ) external;

}


// File contracts/interface/ISmartWalletFactory.sol


pragma solidity 0.6.9;

interface ISmartWalletFactory {

  function getSmartWallet(
    address
  ) external returns (address);

}


// File contracts/LimitOrderBook.sol

//SPDX-License-Identifier: MIT
pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;






contract LimitOrderBook is Ownable, DecimalERC20{

  using Decimal for Decimal.decimal;
  using SignedDecimal for SignedDecimal.signedDecimal;

  /*
   * EVENTS
   */

  event OrderCreated(address indexed trader, uint order_id);
  event OrderFilled(address indexed trader, uint order_id);
  event OrderChanged(address indexed trader, uint order_id);

  event TrailingOrderCreated(uint order_id, uint snapshotIndex);
  event TrailingOrderFilled(uint order_id);

  /*
   * ENUMS
   */

   /*
    * Order types that the user is able to create.
    * Note that market orders are actually executed instantly on clearing house
    * therefore there should never actually be a market order in the LOB
    */
  enum OrderType {
    MARKET,
    LIMIT,
    STOPMARKET,
    STOPLIMIT,
    TRAILINGSTOPMARKET,
    TRAILINGSTOPLIMIT}

  /*
   * STRUCTS
   */

   /*
    * @notice Every order is stored within a limit order struct (regardless of
    *    the type of order)
    * @param asset is the address of the perp AMM for that particular asset
    * @param trader is the user that created the order - note that the order will
    *   actually be executed on their smart wallet (as stored in the factory)
    * @param orderType represents the order type
    * @param reduceOnly whether the order is reduceOnly or not. A reduce only order
    *   will never increase the size of a position and will either reduce the size
    *   or close the position.
    * @param stillValid whether the order can be executed. There are two conditions
    *   where an order is no longer valid: the trader cancels the order, or the
    *   order gets executed (to prevent double spend)
    * @param expiry is the blockTimestamp when this order expires. If this value
    *   is 0 then the order will not expire
    * @param stopPrice is the trigger price for any stop order. A stop BUY can
    *   only be executed above this price, whilst a stop SELL is executed below
    * @param limitPrice is the trigger price for any limit order. a limit BUY can
    *   only be executed below this price, whilst a limit SELL is executed above
    * @param orderSize is the size of the order (denominated in the base asset)
    * @param collateral is the amount of collateral or margin that will be used
    *   for this order. This amount is guaranteed ie an order with 300 USDC will
    *   always use 300 USDC.
    * @param leverage is the maximum amount of leverage that the trader will accept.
    * @param slippage is the minimum amount of ASSET that the user will accept.
    *   The trader will usually achieve the amount specified by orderSize. This
    *   parameter allows the user to specify their tolerance to price impact / frontrunning
    * @param tipFee is the fee that goes to the keeper for executing the order.
    *   This fee is taken when the order is created, and paid out when executing.
    */
  struct LimitOrder {
    address asset;
    address trader;
    bool reduceOnly;
    bool stillValid;
    OrderType orderType;
    uint256 expiry;
    Decimal.decimal stopPrice;
    Decimal.decimal limitPrice;
    SignedDecimal.signedDecimal orderSize;
    Decimal.decimal collateral;
    Decimal.decimal leverage;
    Decimal.decimal slippage;
    Decimal.decimal tipFee;
  }
  LimitOrder[] public orders;

  /*
   * @notice Additional information is stored for trailing orders below
   * @param witnessPrice is either the highest or lowest price witnessed by an order.
   *    The trailing stop/limit trigger prices are calculated from this value.
   * @param trail is the absolute difference between the witnessPrice and stop price
   * @param trailPct is a percentage (number between 0 and 1) that is used to
   *    calculate a relative stop price
   * @param gap is the absolute difference between the witnessPrice and limit price
   * @param gapPct is a percentage (number between 0 and 1) that is used to
   *    calculate a relative limit price
   * @param usePct whether the trigger prices are calculated relatively or absolutely
   * @param snapshotCreated the index of reserveSnapshotted on AMM contract when
   *    the trailing order was created
   * @param snapshotLastUpdated the index when the witness price was last updated
   * @param snapshotTimestamp the timestamp when the order was last updated
   * @param lastUpdatedKeeper the last address that successfully updated the witness
   *    price. This address will be paid on execution of the order
   */
  struct TrailingOrderData {
    Decimal.decimal witnessPrice;
    Decimal.decimal trail;
    Decimal.decimal trailPct;
    Decimal.decimal gap;
    Decimal.decimal gapPct;
    uint256 snapshotCreated;
    uint256 snapshotLastUpdated;
    uint256 snapshotTimestamp;
    address lastUpdatedKeeper;
    bool usePct;
  }
  /* Utilising mapping here to ensure order_id is the same for LimitOrder struct and
  TrailingOrderData struct */
  mapping (uint256 => TrailingOrderData) public trailingOrders;

  /*
   * VARIABLES
   */

  /* All smart wallets will be deployed by the factory - this allows you to get the
  contract address of the smart wallet for any trader */
  ISmartWalletFactory public factory;

  /* Other smart contracts that we interact with */
  address constant USDC = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
  address constant INSURANCEFUND = 0x8C29F6F7fc1999aB84b476952E986F974Acb3824;

  /* Trailing orders can only be updated every 10 minutes - this is to prevent the need
  for the contract to be poked as frequently. 10 minutes has been chosen as the
  15 minute TWAP is used by PERP for liquidations.*/
  uint256 public pokeContractDelay = 10 minutes;

  /* The minimum fee that needs to be attached to an order for it to be executed
  by a keeper. This can be adjusted at a later stage. This is to prevent spam attacks
  on the network */
  Decimal.decimal public minimumTipFee;


  /*
   * FUNCTIONS TO ADD ORDERS
   */

   /*
    * @notice This function will create a limit order and store it within the contract.
    * Please see documentation for _createOrder()
    */
  function addLimitOrder(
    IAmm _asset,
    Decimal.decimal memory _limitPrice,
    SignedDecimal.signedDecimal memory _positionSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage,
    Decimal.decimal memory _tipFee,
    bool _reduceOnly,
    uint256 _expiry
  ) external {
    requireNonZeroInput(_limitPrice, "Limit cannot be zero");
    _createOrder(_asset, OrderType.LIMIT, Decimal.zero(), _limitPrice, _positionSize,
      _collateral, _leverage, _slippage, _tipFee, _reduceOnly, _expiry);
  }

  /*
   * @notice This function will create a stop market order and store it within the contract.
   * Please see documentation for _createOrder()
   */
  function addStopOrder(
    IAmm _asset,
    Decimal.decimal memory _stopPrice,
    SignedDecimal.signedDecimal memory _positionSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage,
    Decimal.decimal memory _tipFee,
    bool _reduceOnly,
    uint256 _expiry
  ) external {
    requireNonZeroInput(_stopPrice, "Stop cannot be zero");
    _createOrder(_asset, OrderType.STOPMARKET, _stopPrice, Decimal.zero(), _positionSize,
      _collateral, _leverage, _slippage, _tipFee, _reduceOnly, _expiry);
  }

  /*
   * @notice This function will create a stop limit order and store it within the contract.
   * Please see documentation for _createOrder()
   */
  function addStopLimitOrder(
    IAmm _asset,
    Decimal.decimal memory _stopPrice,
    Decimal.decimal memory _limitPrice,
    SignedDecimal.signedDecimal memory _positionSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage,
    Decimal.decimal memory _tipFee,
    bool _reduceOnly,
    uint256 _expiry
  ) external {
    requireNonZeroInput(_limitPrice, "Limit cannot be zero");
    requireNonZeroInput(_stopPrice, "Stop cannot be zero");
    _createOrder(_asset, OrderType.STOPLIMIT, _stopPrice, _limitPrice, _positionSize,
      _collateral, _leverage, _slippage, _tipFee, _reduceOnly, _expiry);
  }

  /*
   * @notice This function will create a trailing stop order and store it within the contract.
   * Please see documentation for _createOrder() and _createTrailingOrder()
   * Abs is absolute value
   */
  function addTrailingStopMarketOrderAbs(
    IAmm _asset,
    Decimal.decimal memory _trail,
    SignedDecimal.signedDecimal memory _positionSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _tipFee,
    bool _reduceOnly,
    uint256 _expiry
  ) external {
    requireNonZeroInput(_trail, "Trail cannot be zero");
    _createOrder(_asset, OrderType.TRAILINGSTOPMARKET, Decimal.zero(), Decimal.zero(),
      _positionSize, _collateral, _leverage, Decimal.zero(), _tipFee, _reduceOnly, _expiry);
    _createTrailingOrder(_asset, _trail, Decimal.zero(), false);
  }

  /*
   * @notice This function will create a trailing stop order and store it within the contract.
   * Please see documentation for _createOrder() and _createTrailingOrder()
   * Pct is relative value (will calculate trigger price as percentage)
   */
  function addTrailingStopMarketOrderPct(
    IAmm _asset,
    Decimal.decimal memory _trailPct,
    SignedDecimal.signedDecimal memory _positionSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _tipFee,
    bool _reduceOnly,
    uint256 _expiry
  ) external {
    requireNonZeroInput(_trailPct, "Trail cannot be zero");
    _createOrder(_asset, OrderType.TRAILINGSTOPMARKET, Decimal.zero(), Decimal.zero(),
      _positionSize, _collateral, _leverage, Decimal.zero(), _tipFee, _reduceOnly, _expiry);
    _createTrailingOrder(_asset, _trailPct, Decimal.zero(), true);
  }

  /*
   * @notice This function will create a trailing stop limit order and store it within the contract.
   * Please see documentation for _createOrder() and _createTrailingOrder()
   * Abs is absolute value
   */
  function addTrailingStopLimitOrderAbs(
    IAmm _asset,
    Decimal.decimal memory _trail,
    Decimal.decimal memory _gap,
    SignedDecimal.signedDecimal memory _positionSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage,
    Decimal.decimal memory _tipFee,
    bool _reduceOnly,
    uint256 _expiry
  ) external {
    requireNonZeroInput(_trail, "Trail cannot be zero");
    requireNonZeroInput(_gap, "Gap cannot be zero");
    _createOrder(_asset, OrderType.TRAILINGSTOPLIMIT, Decimal.zero(), Decimal.zero(),
      _positionSize, _collateral, _leverage, _slippage, _tipFee, _reduceOnly, _expiry);
    _createTrailingOrder(_asset, _trail, _gap, false);
  }

  /*
   * @notice This function will create a trailing stop limit order and store it within the contract.
   * Please see documentation for _createOrder() and _createTrailingOrder()
   * Pct is relative value (will calculate trigger price as percentage)
   */
  function addTrailingStopLimitOrderPct(
    IAmm _asset,
    Decimal.decimal memory _trailPct,
    Decimal.decimal memory _gapPct,
    SignedDecimal.signedDecimal memory _positionSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage,
    Decimal.decimal memory _tipFee,
    bool _reduceOnly,
    uint256 _expiry
  ) external {
    requireNonZeroInput(_trailPct, "Trail cannot be zero");
    requireNonZeroInput(_gapPct, "Gap cannot be zero");
    _createOrder(_asset, OrderType.TRAILINGSTOPLIMIT, Decimal.zero(), Decimal.zero(),
      _positionSize, _collateral, _leverage, _slippage, _tipFee, _reduceOnly, _expiry);
    _createTrailingOrder(_asset, _trailPct, _gapPct, true);
  }

  /*
   * @notice Will create an advanced order and store it within the contract
   * @param _asset the AMM address for the asset being traded
   * @param _orderType the type of order (as enum)
   * @param _stopPrice the STOP trigger price
   * @param _limitPrice the LIMIT trigger price
   * @param _positionSize the size of the order in base asset
   * @param _collateral the amount of margin/collateral that will be used for order
   * @param _leverage the maximum leverage acceptable for trade
   * @param _slippage the minimum amount of base asset that the trader will accept
   *    This is subtly different to _positionSize. Let us assume that the trader
   *    has created an order to buy 1 BTC below 50K. The price of bitcoin hits
   *    49,980 and so an order gets executed. His actual execution price may be
   *    50,500 (due to price impact). He can adjust the slippage parameter to
   *    decide whether he wants the transaction to be executed at this price or not.
   *    If slippage is set to 0, then any price is accepted.
   * @param _tipFee is the fee that will go to the keeper that executes the order.
   *    This fee is taken as soon as the order is created.
   * @param _reduceOnly whether the order is reduceonly or not
   * @param _expiry when the order expires (block timestamp). If this variable is
   *    0 then it will never expire.
   */
  function _createOrder(
    IAmm _asset,
    OrderType _orderType,
    Decimal.decimal memory _stopPrice,
    Decimal.decimal memory _limitPrice,
    SignedDecimal.signedDecimal memory _positionSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage,
    Decimal.decimal memory _tipFee,
    bool _reduceOnly,
    uint256 _expiry
  ) internal {
    //Check expiry parameter
    require(((_expiry == 0 ) || (block.timestamp<_expiry)), 'Event will expire in past');
    //Check whether fee is sufficient
    require(_tipFee.cmp(minimumTipFee) >= 0, 'Just the tip! Tip is below minimum tip fee');
    //Check on the smart wallet factory whether this trader has a smart wallet
    address _smartWallet = factory.getSmartWallet(msg.sender);
    require(_smartWallet != address(0), 'Need smart wallet');
    //Need to make sure the asset is actually a PERP asset
    require(IInsuranceFund(INSURANCEFUND).isExistedAmm(IAmm(_asset)), "amm not found");
    //Sanity checks
    requireNonZeroInput(_positionSize.abs(), "Cannot do empty order");
    require(_slippage.cmp(Decimal.one()) == -1, "Slippage must be percentage");

    requireNonZeroInput(_collateral, "Cannot spend 0 collateral");
    require(_leverage.cmp(Decimal.one()) != -1, "Minimum 1x leverage");
    //Take fee from user - user needs to approve this contract to spend their USDC first
    _transferFrom(IERC20(USDC), _smartWallet, address(this), _tipFee);
    //Emit event on order creation
    emit OrderCreated(msg.sender,orders.length);
    //Add values to array
    orders.push(LimitOrder({
      asset: address(_asset),
      trader: msg.sender,
      orderType: _orderType,
      stopPrice: _stopPrice,
      limitPrice: _limitPrice,
      orderSize: _positionSize,
      collateral: _collateral,
      leverage: _leverage,
      slippage: _slippage,
      tipFee: _tipFee,
      reduceOnly: _reduceOnly,
      stillValid: true,
      expiry: _expiry
      }));
  }

  /*
   * @notice Will create a trailing order
   * @param _trail variable used to calculate the stop trigger price for a trailing
   *    order. Note that this will either be an absolute value or a percentage (0-1)
   * @param _gap variable used to calculate the limit trigger price for a trailing
   *    order. Note that this will either be an absolute value or a percentage (0-1)
   * @param _usePct whether or not you are calculating using absolute or relative
   */

  function _createTrailingOrder(
    IAmm _asset,
    Decimal.decimal memory _trail,
    Decimal.decimal memory _gap,
    bool _usePct
  ) internal {
    //Get the current index of AMM ReserveSnapshotted
    uint _currSnapshot = IAmm(_asset).getSnapshotLen()-1;
    uint _thisOrderId = orders.length-1;
    //Get the current spot price of the asset
    Decimal.decimal memory _initPrice = IAmm(_asset).getSpotPrice();
    if(_usePct) {
      //Ensure that the percentages satisfy 0<=PCT<1
      require(_trail.cmp(Decimal.one()) == -1, 'Invalid trail percent');
      require(_gap.cmp(Decimal.one()) == -1, 'Invalid gap percent');
      //Create trailing order struct
      trailingOrders[_thisOrderId] = TrailingOrderData({
        witnessPrice: _initPrice,
        trail: Decimal.zero(),
        trailPct: _trail,
        gap: Decimal.zero(),
        gapPct: _gap,
        usePct: true,
        snapshotCreated: _currSnapshot,
        snapshotLastUpdated: _currSnapshot,
        snapshotTimestamp: block.timestamp,
        lastUpdatedKeeper: address(0)
      });
    } else {
      //Create trailing order struct
      trailingOrders[_thisOrderId] = TrailingOrderData({
        witnessPrice: _initPrice,
        trail: _trail,
        trailPct: Decimal.zero(),
        gap: _gap,
        gapPct: Decimal.zero(),
        usePct: false,
        snapshotCreated: _currSnapshot,
        snapshotLastUpdated: _currSnapshot,
        snapshotTimestamp: block.timestamp,
        lastUpdatedKeeper: address(0)
      });
    }
    //Need to calculate stop and limit prices from the witness Price
    _updateTrailingPrice(_thisOrderId);
    //Emit event
    emit TrailingOrderCreated(_thisOrderId, _currSnapshot);
  }

  /*
   * FUNCTIONS TO INTERACT WITH ORDERS (MODIFY/DELETE/ETC)
   */

  /*
   * @notice allows a user to modify their orders after they have been submitted.
   *    Once an order has been submitted, it is not possible to change the ASSET,
   *    or the TIPFEE, or the ORDERTYPE. The other parameters are similar to those
   *    described above.
   *  Note: there is a separate function to modify trailing orders
   */
  function modifyOrder(
    uint order_id,
    Decimal.decimal memory _stopPrice,
    Decimal.decimal memory _limitPrice,
    SignedDecimal.signedDecimal memory _orderSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage,
    bool _reduceOnly,
    uint _expiry) external onlyMyOrder(order_id) onlyValidOrder(order_id){
      //Ensure that you don't set an order that expires in the past
      require(((_expiry == 0 ) || (block.timestamp<_expiry)), 'Event will expire in past');
      //Can only modify non-trailing orders with this function
      OrderType _thisOrderType = orders[order_id].orderType;
      require(_thisOrderType == OrderType.LIMIT ||
        _thisOrderType == OrderType.STOPMARKET ||
        _thisOrderType == OrderType.STOPLIMIT,
        "Can only modify stop/limit orders");
      //Sanity checks
      requireNonZeroInput(_orderSize.abs(), "Cannot do empty order");
      requireNonZeroInput(_collateral, "Cannot spend 0 collateral");
      require(_leverage.cmp(Decimal.one()) != -1, "Minimum 1x leverage");
      //Update parameters
      orders[order_id].stopPrice = _stopPrice;
      orders[order_id].limitPrice = _limitPrice;
      orders[order_id].orderSize = _orderSize;
      orders[order_id].collateral = _collateral;
      orders[order_id].leverage = _leverage;
      orders[order_id].slippage = _slippage;
      orders[order_id].reduceOnly = _reduceOnly;
      orders[order_id].expiry = _expiry;
      //Emit event
      emit OrderChanged(orders[order_id].trader, order_id);
    }

    /*
     * @notice allows a user to modify their orders after they have been submitted.
     *    Once an order has been submitted, it is not possible to change the ASSET,
     *    or the TIPFEE, or the ORDERTYPE. The other parameters are similar to those
     *    described above.
     *  Note: this function can only modify trailing orders. It is not possible to
     *  change the type of trailing order (eg relative vs absolute)
     */
  function modifyTrailingOrder(
    uint order_id,
    Decimal.decimal memory _newStop,
    Decimal.decimal memory _newLimit,
    SignedDecimal.signedDecimal memory _orderSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage,
    bool _reduceOnly,
    uint _expiry) external onlyMyOrder(order_id) onlyValidOrder(order_id){
      //Check order doesn't expire in the past
      require(((_expiry == 0 ) || (block.timestamp<_expiry)), 'Event will expire in past');
      //Can only modify trailing orders with this function
      OrderType _thisOrderType = orders[order_id].orderType;
      require(_thisOrderType == OrderType.TRAILINGSTOPMARKET ||
        _thisOrderType == OrderType.TRAILINGSTOPLIMIT,
        "Can only modify trailing orders");
      //Sanity checks
      requireNonZeroInput(_orderSize.abs(), "Cannot do empty order");
      requireNonZeroInput(_collateral, "Cannot spend 0 collateral");
      require(_leverage.cmp(Decimal.one()) != -1, "Minimum 1x leverage");
      //Update parameters
      orders[order_id].orderSize = _orderSize;
      orders[order_id].collateral = _collateral;
      orders[order_id].leverage = _leverage;
      orders[order_id].slippage = _slippage;
      orders[order_id].reduceOnly = _reduceOnly;
      orders[order_id].expiry = _expiry;

      if(trailingOrders[order_id].usePct) {
        //Ensure that percentage satisfies 0<=PCT<1
        require(_newStop.cmp(Decimal.one()) == -1, 'Invalid trail percent');
        require(_newLimit.cmp(Decimal.one()) == -1, 'Invalid gap percent');
        //Update trailing order parameters
        trailingOrders[order_id].trailPct = _newStop;
        trailingOrders[order_id].gapPct = _newLimit;
      } else {
        trailingOrders[order_id].trail = _newStop;
        trailingOrders[order_id].gap = _newLimit;
      }
      //Update stop and limit triggers based on these nnew parameters
      _updateTrailingPrice(order_id);
      //Emit event
      emit OrderChanged(orders[order_id].trader, order_id);
    }

  /*
   * @notice Delete an order
   */
  function deleteOrder(
    uint order_id
  ) external onlyMyOrder(order_id) onlyValidOrder(order_id){
    emit OrderChanged(orders[order_id].trader, order_id);
    delete orders[order_id];
  }

  /*
   * @notice Execute an order using the order_id
   * All the logic verifying the order can be successfully executed occurs on the SmartWallet.sol contract
   */
  function execute(uint order_id) external onlyValidOrder(order_id) {
    //First check that the order hasn't been cancelled/already been executed
    LimitOrder memory order = orders[order_id];
    address _trader = order.trader;
    require(order.stillValid, 'No longer valid');
    //Get the smart wallet of the trader from the factory contract
    address _smartwallet = factory.getSmartWallet(order.trader);
    //Try and execute the order (should return true if successful)
    ISmartWallet(_smartwallet).executeOrder(order_id);
    if((order.orderType == OrderType.TRAILINGSTOPMARKET ||
        order.orderType == OrderType.TRAILINGSTOPLIMIT)) {
        //If this is a trailing order, then the botFee gets split between the keeper that
        //executed the transaction, and the last keeper to update the price
          if(trailingOrders[order_id].lastUpdatedKeeper != address(0)) {
            //Making sure that a keeper has actually updated the price, otherwise the executor gets full fee
            _transfer(IERC20(USDC), msg.sender, order.tipFee.divScalar(2));
            _transfer(IERC20(USDC), trailingOrders[order_id].lastUpdatedKeeper,
              order.tipFee.divScalar(2));
          } else {
            _transfer(IERC20(USDC), msg.sender, order.tipFee);
          }
          emit TrailingOrderFilled(order_id);
          delete trailingOrders[order_id];
    } else {
      //Fee goes to executor
      _transfer(IERC20(USDC), msg.sender, order.tipFee);
    }
    //Invalidate order to prevent double spend
    delete orders[order_id];
    //emit event
    emit OrderFilled(_trader, order_id);
  }

  /*
   * FUNCTIONS RELATING TO TRAILING ORDERS
   */

  /*
   * @notice internal function that sets the limitPrice and stopPrice trigger
   * values based on the witnessPrice variable. Need to set witnessPrice before
   * calling this function otherwisei you will cause problems.
   */
  function _updateTrailingPrice(
    uint order_id
  ) internal {
    //Get the price as witness Price
    Decimal.decimal memory _newPrice = trailingOrders[order_id].witnessPrice;
    //If the order is LONG/BUY then the trigger prices will be above witnessPrice
    bool isLong = orders[order_id].orderSize.isNegative() ? false : true;
    if(trailingOrders[order_id].usePct) {
      //Update trail PCT
      Decimal.decimal memory tpct = isLong ?
        Decimal.one().addD(trailingOrders[order_id].trailPct) :
        Decimal.one().subD(trailingOrders[order_id].trailPct);
      //Update gap PCT
      Decimal.decimal memory gpct = isLong ?
        Decimal.one().addD(trailingOrders[order_id].gapPct) :
        Decimal.one().subD(trailingOrders[order_id].gapPct);
      //Calculate trigger prices as percentage of witness Price
      orders[order_id].stopPrice = _newPrice.mulD(tpct);
      orders[order_id].limitPrice = orders[order_id].stopPrice.mulD(gpct);
    } else {
      //Calculate trigger prices as absolute difference of witness Price
      orders[order_id].stopPrice = isLong ?
        _newPrice.addD(trailingOrders[order_id].trail) :
        _newPrice.subD(trailingOrders[order_id].trail);
      orders[order_id].limitPrice = isLong ?
        orders[order_id].stopPrice.addD(trailingOrders[order_id].gap) :
        orders[order_id].stopPrice.subD(trailingOrders[order_id].gap);
    }
  }

  /*
   * @notice inform the smart contract that a particular order needs to update its parameters
   * @param order_id the id of the order to be updated
   * @param _reserveIndex the index of the AMM ReserveSnapshotted array with the
   *    local price maximum/minimum
   *  The purpose of this function is to incentivise/reward bots that will update the stop/limit prices
   *  for orders.
   */
  function pokeContract(
    uint order_id,
    uint _reserveIndex
  ) public {
    //Can only poke for orders that are trailing orders
    OrderType _thisOrderType = orders[order_id].orderType;
    require(_thisOrderType == OrderType.TRAILINGSTOPMARKET ||
      _thisOrderType == OrderType.TRAILINGSTOPLIMIT, "Can only poke trailing orders");
    //You cannot update the price with values that were accurate before the order was created
    require(_reserveIndex > trailingOrders[order_id].snapshotCreated, "Order hadn't been created");

    //check whether A. there is a higher/lower price that occurred before the current updated value or
    // B. if it has been more than 15 minutes since the last update after the current updated value
    require(_reserveIndex < trailingOrders[order_id].snapshotLastUpdated ||
      (block.timestamp - trailingOrders[order_id].snapshotTimestamp > pokeContractDelay), "Can only be updated every 10 minutes");
    trailingOrders[order_id].snapshotTimestamp = block.timestamp;

    bool isLong = orders[order_id].orderSize.isNegative() ? false : true;

    //Get the price of the AMM at that snapshot
    Decimal.decimal memory _newPrice = getPriceAtSnapshot(
      IAmm(orders[order_id].asset), _reserveIndex);

    //Check that the new price is above/below the current maximum/minimum
    require(trailingOrders[order_id].witnessPrice.cmp(_newPrice) == (isLong ? int128(1) : -1),
      "Incorrect trailing price");

    //Update witness price and then update further parameters
    trailingOrders[order_id].witnessPrice = _newPrice;
    trailingOrders[order_id].snapshotLastUpdated = _reserveIndex;
    trailingOrders[order_id].lastUpdatedKeeper = msg.sender;
    _updateTrailingPrice(order_id);
  }

  /*
   * VIEW FUNCTIONS
   */

  function getNumberOrders() public view returns (uint){
    return orders.length;
  }

  function getTrailingData(
    uint order_id
  ) public view returns (TrailingOrderData memory){
    return trailingOrders[order_id];
  }

  //Similar function exists on AMM but this is slightly more efficient.
  function getPriceAtSnapshot(
    IAmm _asset,
    uint256 _snapshotIndex
  ) public view returns (Decimal.decimal memory) {
    require(_snapshotIndex < _asset.getSnapshotLen(),'Snapshot Index does not exist');
    IAmm.ReserveSnapshot memory snap = _asset.reserveSnapshots(_snapshotIndex);
    return snap.quoteAssetReserve.divD(snap.baseAssetReserve);
  }

  function getLimitOrder(
    uint order_id
  ) public view onlyValidOrder(order_id)
    returns (LimitOrder memory) {
    return (orders[order_id]);
  }

  function getLimitOrderPrices(
    uint id
  ) public view onlyValidOrder(id)
    returns(
      Decimal.decimal memory,
      Decimal.decimal memory,
      SignedDecimal.signedDecimal memory,
      Decimal.decimal memory,
      Decimal.decimal memory,
      Decimal.decimal memory,
      Decimal.decimal memory,
      address, bool) {
    LimitOrder memory order = orders[id];
    return (order.stopPrice,
      order.limitPrice,
      order.orderSize,
      order.collateral,
      order.leverage,
      order.slippage,
      order.tipFee,
      order.asset,
      order.reduceOnly);
  }

  function getLimitOrderParams(
    uint id
  ) public view onlyValidOrder(id)
    returns(
      address,
      address,
      OrderType,
      bool,
      bool,
      uint256) {
    LimitOrder memory order = orders[id];
    return (order.asset,
      order.trader,
      order.orderType,
      order.reduceOnly,
      order.stillValid,
      order.expiry);
  }

  /*
   * ADMIN / SETUP FUNCTIONS
   */

  function setFactory(address _addr) public onlyOwner{
    factory = ISmartWalletFactory(_addr);
  }

  function changeMinimumFee(Decimal.decimal memory _fee) public onlyOwner {
    minimumTipFee = _fee;
  }

  /*
   * MODIFIERS
   */

  modifier onlyValidOrder(uint order_id) {
    require(order_id < orders.length, 'Invalid ID');
    _;
  }

  modifier onlyMyOrder(uint order_id) {
    require(msg.sender == orders[order_id].trader, "Not your order");
    _;
  }

  function requireNonZeroInput(Decimal.decimal memory _decimal, string memory errorMessage) private pure {
        require(_decimal.toUint() != 0, errorMessage);
    }

}

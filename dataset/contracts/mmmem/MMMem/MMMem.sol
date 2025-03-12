// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

/*

                                    ::---======++++++++======----::..                    
                           .:-==+++==--:::.....          ....::::--==++++==--:..          
                     .:-=+==-:..                                        .::-=++++==-:.    
                 .-=+=-:.                                                      .:-=++++-  
             .:==-:.                                                                .:=-  
          .-==:                                                                           
        .==:                                                                              
      :=-         ::::::               ::::::               .:::::.              .:::::.  
    .=-          .@@###%@+           =@@#####.              +#####@#:          :#@###%@*  
   :=.           .@#  . -%@+       =@@=......               ......:*@#:      :#@*. . .@*  
  :-             .@#  %#: -%@+   =@@=  -------.            -------. .*@#:  :#@*. =@= .@*  
 .=              .@#  %@@#: -%@*@@= .*+=========-       :=========.%= .*@##@*. =@@@= .@*  
 =               .@#  %@:*@#: -#= .*@#.:::::::::::..  .:----------.=@@= .**. =@@=+@= .@*  
 =               .@#  %@  .*@#: :*@#:  -------------:-------------.  =@@=  =@@=  =@= .@*  
 =               .@#  %@    .*@%@#:    ======.-============.-=====:    =@@@@=    =@= .@*  
 =               .@#  %@      .+:      :::::-   .::::::::.  :--::-.      ==      =@= .@*  
 .-              .@#  %@               :-----    :-----:    :-----.              =@= .@*  
  --             .@#  %@               =+===+.     .-:      -+===+:              =@= .@*  
   :-            .@#  %@               ::::::               ::::::.              =@= .@*  
    .=:          .@#  %@               ::::::               ::::::.              =@= .@*  
      :=:         -:  --               =+++++.              -+++++:              .-.  -:  
        :=-.                           :-----               :-----.                       
          .-=-.                        ::::::               .:::::.                       
             :-+=:.                                                                  .--  
                .:=+=-:.                                                        .:-++++-  
                    .:-=++=-:..                                          .::-=++++==-:.   
                          .:-==++==--:::...                  ...:::--=+++++=--:..         
                                 ..::--====++++++++++++++++++====---::..                  
    
    WEB : http://mmmem.io/
    TG  : https://t.me/multimillionmemtoken
    X   : https://twitter.com/mavrodimmmem
*/


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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function Mavrodi() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(Mavrodi() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function powerToThePeople() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
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
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
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

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract MMMem is IERC20, Ownable {
    using SafeMath for uint256;

    uint256 public constant MAX_FEE = 10**4 / 4;

    mapping(address => uint256) private _rMavro;
    mapping(address => uint256) private _tMavro;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotalMavro;
    uint256 private _rTotalMavro;
    uint256 private _tFeeTotal;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 public _taxFee;                   // yeld
    uint256 private _previousTaxFee;

    uint256 public _taxToTheCashier;         // liquidity Fee
    uint256 private _previoustaxToTheCashier;

    uint256 public _supportForThePeople;          // charity fee
    uint256 private _previousSupportForThePeople;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    address public _charityAddress;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;

    uint256 private numTokensSellToAddToLiquidity;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyAmountUpdated(uint256 amount);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address router_,
        address charityAddress_,
        uint16 taxFee_,
        uint16 taxToTheCashier_,
        uint16 supportForThePeople_
    ) {
        if (charityAddress_ == address(0)) {
            require(
                supportForThePeople_ == 0,
                "Cant set both charity address to address 0 and charity percent more than 0"
            );
        }
        require(
            taxFee_ + taxToTheCashier_ + supportForThePeople_ <= MAX_FEE,
            "Total fee is over 25%"
        );

        _name = name_;
        _symbol = symbol_;
        _decimals = 18;

        _tTotalMavro = totalSupply_;
        _rTotalMavro = (MAX - (MAX % _tTotalMavro));

        _taxFee = taxFee_;
        _previousTaxFee = _taxFee;

        _taxToTheCashier = taxToTheCashier_;
        _previoustaxToTheCashier = _taxToTheCashier;

        _charityAddress = charityAddress_;
        _supportForThePeople = supportForThePeople_;
        _previousSupportForThePeople = _supportForThePeople;

        numTokensSellToAddToLiquidity = totalSupply_.div(10**3); // 0.1%

        swapAndLiquifyEnabled = true;

        _rMavro[Mavrodi()] = _rTotalMavro;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router_);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        // exclude owner and this contract from fee
        _isExcludedFromFee[Mavrodi()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), Mavrodi(), _tTotalMavro);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotalMavro;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tMavro[account];
        return tokenFromReflection(_rMavro[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmountMavro) public {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmountMavro, , , , , , ) = _getValues(tAmountMavro);
        _rMavro[sender] = _rMavro[sender].sub(rAmountMavro);
        _rTotalMavro = _rTotalMavro.sub(rAmountMavro);
        _tFeeTotal = _tFeeTotal.add(tAmountMavro);
    }

    function reflectionFromToken(uint256 tAmountMavro, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmountMavro <= _tTotalMavro, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmountMavro, , , , , , ) = _getValues(tAmountMavro);
            return rAmountMavro;
        } else {
            (, uint256 rTransferAmount, , , , , ) = _getValues(tAmountMavro);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmountMavro)
        public
        view
        returns (uint256)
    {
        require(
            rAmountMavro <= _rTotalMavro,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmountMavro.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rMavro[account] > 0) {
            _tMavro[account] = tokenFromReflection(_rMavro[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tMavro[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmountMavro
    ) private {
        (
            uint256 rAmountMavro,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity
        ) = _getValues(tAmountMavro);
        _tMavro[sender] = _tMavro[sender].sub(tAmountMavro);
        _rMavro[sender] = _rMavro[sender].sub(rAmountMavro);
        _tMavro[recipient] = _tMavro[recipient].add(tTransferAmount);
        _rMavro[recipient] = _rMavro[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeCharityFee(tCharity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
        require(
            _taxFee + _taxToTheCashier + _supportForThePeople <= MAX_FEE,
            "Total fee is over 25%"
        );
    }

    function setTaxToTheCashie(uint256 taxToTheCashier)
        external
        onlyOwner
    {
        _taxToTheCashier = taxToTheCashier;
        require(
            _taxFee + _taxToTheCashier + _supportForThePeople <= MAX_FEE,
            "Total fee is over 25%"
        );
    }

    function setSupportForThePeoplePercent(uint256 supportForThePeople) external onlyOwner {
        _supportForThePeople = supportForThePeople;
        require(
            _taxFee + _taxToTheCashier + _supportForThePeople <= MAX_FEE,
            "Total fee is over 25%"
        );
    }

    function setSwapBackSettings(uint256 _amount) external onlyOwner {
        require(
            _amount >= totalSupply().mul(5).div(10**4),
            "Swapback amount should be at least 0.05% of total supply"
        );
        numTokensSellToAddToLiquidity = _amount;
        emit SwapAndLiquifyAmountUpdated(_amount);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotalMavro = _rTotalMavro.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmountMavro)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity
        ) = _getTValues(tAmountMavro);
        (uint256 rAmountMavro, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmountMavro,
            tFee,
            tLiquidity,
            tCharity,
            _getRate()
        );
        return (
            rAmountMavro,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity,
            tCharity
        );
    }

    function _getTValues(uint256 tAmountMavro)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmountMavro);
        uint256 tLiquidity = calculateLiquidityFee(tAmountMavro);
        uint256 tCharityFee = calculateCharityFee(tAmountMavro);
        uint256 tTransferAmount = tAmountMavro.sub(tFee).sub(tLiquidity).sub(
            tCharityFee
        );
        return (tTransferAmount, tFee, tLiquidity, tCharityFee);
    }

    function _getRValues(
        uint256 tAmountMavro,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 tCharity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmountMavro = tAmountMavro.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rCharity = tCharity.mul(currentRate);
        uint256 rTransferAmount = rAmountMavro.sub(rFee).sub(rLiquidity).sub(
            rCharity
        );
        return (rAmountMavro, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotalMavro;
        uint256 tSupply = _tTotalMavro;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rMavro[_excluded[i]] > rSupply ||
                _tMavro[_excluded[i]] > tSupply
            ) return (_rTotalMavro, _tTotalMavro);
            rSupply = rSupply.sub(_rMavro[_excluded[i]]);
            tSupply = tSupply.sub(_tMavro[_excluded[i]]);
        }
        if (rSupply < _rTotalMavro.div(_tTotalMavro)) return (_rTotalMavro, _tTotalMavro);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rMavro[address(this)] = _rMavro[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)])
            _tMavro[address(this)] = _tMavro[address(this)].add(tLiquidity);
    }

    function _takeCharityFee(uint256 tCharity) private {
        if (tCharity > 0) {
            uint256 currentRate = _getRate();
            uint256 rCharity = tCharity.mul(currentRate);
            _rMavro[_charityAddress] = _rMavro[_charityAddress].add(rCharity);
            if (_isExcluded[_charityAddress])
                _tMavro[_charityAddress] = _tMavro[_charityAddress].add(
                    tCharity
                );
            emit Transfer(_msgSender(), _charityAddress, tCharity);
        }
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**4);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_taxToTheCashier).div(10**4);
    }

    function calculateCharityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        if (_charityAddress == address(0)) return 0;
        return _amount.mul(_supportForThePeople).div(10**4);
    }

    function removeAllFee() private {
        _previousTaxFee = _taxFee;
        _previoustaxToTheCashier = _taxToTheCashier;
        _previousSupportForThePeople = _supportForThePeople;

        _taxFee = 0;
        _taxToTheCashier = 0;
        _supportForThePeople = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _taxToTheCashier = _previoustaxToTheCashier;
        _supportForThePeople = _previousSupportForThePeople;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0xdead),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmountMavro
    ) private {
        (
            uint256 rAmountMavro,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity
        ) = _getValues(tAmountMavro);
        _rMavro[sender] = _rMavro[sender].sub(rAmountMavro);
        _rMavro[recipient] = _rMavro[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeCharityFee(tCharity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmountMavro
    ) private {
        (
            uint256 rAmountMavro,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity
        ) = _getValues(tAmountMavro);
        _rMavro[sender] = _rMavro[sender].sub(rAmountMavro);
        _tMavro[recipient] = _tMavro[recipient].add(tTransferAmount);
        _rMavro[recipient] = _rMavro[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeCharityFee(tCharity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmountMavro
    ) private {
        (
            uint256 rAmountMavro,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity
        ) = _getValues(tAmountMavro);
        _tMavro[sender] = _tMavro[sender].sub(tAmountMavro);
        _rMavro[sender] = _rMavro[sender].sub(rAmountMavro);
        _rMavro[recipient] = _rMavro[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeCharityFee(tCharity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}
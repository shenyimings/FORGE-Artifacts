/**
   0% fee auto added to the liquidity pool but it can be added
   5% fee auto added to two dev wallets as bnb
   7% fee auto distributed to all hodlers
   0% fee added to another dev wallet as token but can be added

   SafeMath was removed because it is now useless for solidity >= 0.8.0
*/
pragma solidity ^0.8.10;

// SPDX-License-Identifier: Unlicensed

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
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
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
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
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
    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
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
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
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
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data)
        internal
        view
        returns (bytes memory)
    {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
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
    function functionDelegateCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
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

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
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

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
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

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract FLOKICHU is Context, IERC20, Ownable {
    using Address for address;
    // Data to customize
    string private constant _name = "Flokichu";
    string private constant _symbol = "FLOKICHU";
    uint256 private totalToken = 1_000_000_000_000;

    // dev fee converted in BNB
    uint256 public _devBNBFeeBuy = 5;
    uint256 public _devBNBFeeSell = _devBNBFeeBuy;
    address payable devWalletOne =
        payable(0x000000000000000000000000000000000000dEaD);
    address payable devWalletTwo =
        payable(0x000000000000000000000000000000000000dEaD);

    // dev fee to recover token, optionnal, set to 0
    uint256 public _optionalDevFeeBuy = 0;
    uint256 public _optionalDevFeeSell = _optionalDevFeeBuy;
    address payable devWalletOptional =
        payable(0x000000000000000000000000000000000000dEaD);

    // redistribution tax fee
    uint256 public _taxFeeBuy = 7;
    uint256 public _taxFeeSell = _taxFeeBuy;

    // automatic liquidity fee, optional, set to 0
    uint256 public _liquidityFeeBuy = 0;
    uint256 public _liquidityFeeSell = _liquidityFeeBuy;

    // END_ Data to customize
    uint256 private _tTotal = totalToken * _DECIMALFACTOR;

    // swap when you accumulate 0.01% of tokens
    // It means it swaps when trading volume reaches 0.2% of total token
    uint256 private numTokensSellToAddToLiquidity = _tTotal / 100000000;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromTransfer;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint8 private constant _DECIMALS = 8;
    uint256 private constant _DECIMALFACTOR = 10**uint256(_DECIMALS);
    uint256 private constant MAX = ~uint256(0);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));

    uint256 private _tFeeTotal;

    uint256 private _previousTaxFeeBuy = _taxFeeBuy;
    uint256 private _previousTaxFeeSell = _taxFeeSell;

    uint256 private _previousDevFeeBuy = _optionalDevFeeBuy;
    uint256 private _previousDevFeeSell = _optionalDevFeeSell;

    uint256 private _previousLiquidityFeeBuy = _liquidityFeeBuy;
    uint256 private _previousLiquidityFeeSell = _liquidityFeeSell;

    uint256 private _previousdevBNBFeeBuy = _devBNBFeeBuy;
    uint256 private _previousdevBNBFeeSell = _devBNBFeeSell;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool inSwapAndLiquify;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event AddLiquidityETH(uint256 amountA, uint256 amountB);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        ); // v2 testnet 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        // Create a pancakeswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
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
        require(
            _allowances[sender][_msgSender()] >= amount,
            "BEP20: transfer amount exceeds allowance"
        );
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
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
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        require(
            _allowances[_msgSender()][spender] >= subtractedValue,
            "BEP20: decreased allowance below zero"
        );
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        Values memory values = _getValues(tAmount, true);
        if (!deductTransferFee) {
            return values.rAmount;
        } else {
            return values.rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        /* Changed error message to "Account not excluded"
         See "SSL-01 | Incorrect error message" from the Certik
         audit of safemoon.
      */
        require(_isExcluded[account], "Account not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function excludeFromTransfer(address account) public onlyOwner {
        _isExcludedFromTransfer[account] = true;
    }

    function includeInTransfer(address account) public onlyOwner {
        _isExcludedFromTransfer[account] = false;
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setTaxFeeBuyPercent(uint256 taxFee) external onlyOwner {
        _taxFeeBuy = taxFee;
    }

    function setTaxFeeSellPercent(uint256 taxFee) external onlyOwner {
        _taxFeeSell = taxFee;
    }

    function setOptionalDevFeeBuyPercent(uint256 charityFee)
        external
        onlyOwner
    {
        _optionalDevFeeBuy = charityFee;
    }

    function setOptionalDevFeeSellPercent(uint256 charityFee)
        external
        onlyOwner
    {
        _optionalDevFeeSell = charityFee;
    }

    function setdevBNBFeeBuyPercent(uint256 devBNBFee) external onlyOwner {
        _devBNBFeeBuy = devBNBFee;
    }

    function setdevBNBFeeSellPercent(uint256 devBNBFee) external onlyOwner {
        _devBNBFeeSell = devBNBFee;
    }

    function setLiquidityFeeBuyPercent(uint256 liquidityFee)
        external
        onlyOwner
    {
        _liquidityFeeBuy = liquidityFee;
    }

    function setLiquidityFeeSellPercent(uint256 liquidityFee)
        external
        onlyOwner
    {
        _liquidityFeeSell = liquidityFee;
    }

    //to recieve BNB from pancakeswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal - tFee;
    }

    struct Values {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rFee;
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tDev;
        uint256 tDevBNB;
    }
    struct TValues {
        uint256 tTransferAmount;
        uint256 tFee;
        uint256 tDevBNB;
        uint256 tLiquidity;
        uint256 tDev;
    }

    function _getValues(uint256 tAmount, bool isBuy)
        private
        view
        returns (Values memory)
    {
        TValues memory tValues = _getTValues(tAmount, isBuy);
        Values memory values;
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tValues.tFee,
            tValues.tLiquidity,
            tValues.tDev,
            tValues.tDevBNB,
            _getRate()
        );
        values.rAmount = rAmount;
        values.rTransferAmount = rTransferAmount;
        values.rFee = rFee;
        values.tTransferAmount = tValues.tTransferAmount;
        values.tFee = tValues.tFee;
        values.tLiquidity = tValues.tLiquidity;
        values.tDev = tValues.tDev;
        values.tDevBNB = tValues.tDevBNB;
        return values;
    }

    function _getTValues(uint256 tAmount, bool isBuy)
        private
        view
        returns (TValues memory)
    {
        TValues memory tValues;
        tValues.tFee = calculateTaxFee(tAmount, isBuy);
        tValues.tDev = calculateDevFee(tAmount, isBuy);
        tValues.tDevBNB = calculatedevBNBFee(tAmount, isBuy);
        tValues.tLiquidity = calculateLiquidityFee(tAmount, isBuy);
        tValues.tTransferAmount =
            tAmount -
            tValues.tFee -
            tValues.tLiquidity -
            tValues.tDev;
        return tValues;
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 tDev,
        uint256 tDevBNB,
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
        uint256 rAmount = tAmount * currentRate;
        uint256 rDevBNB = tDevBNB * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rDev = tDev * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rLiquidity - rDev - rDevBNB;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeDevForBNB(uint256 tDevBNB) private {
        uint256 currentRate = _getRate();
        uint256 rDevBNB = tDevBNB * currentRate;
        _rOwned[address(this)] = _rOwned[address(this)] + rDevBNB;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] + tDevBNB;
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity * currentRate;
        _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] + tLiquidity;
    }

    function _takeDev(uint256 tDev) private {
        uint256 currentRate = _getRate();
        uint256 rDev = tDev * currentRate;
        _rOwned[devWalletOptional] = _rOwned[devWalletOptional] + rDev;
        if (_isExcluded[devWalletOptional])
            _tOwned[devWalletOptional] = _tOwned[devWalletOptional] + tDev;
    }

    function calculateTaxFee(uint256 _amount, bool isBuy)
        private
        view
        returns (uint256)
    {
        uint256 _taxFee = _taxFeeBuy;
        if (!isBuy) {
            _taxFee = _taxFeeSell;
        }
        return (_amount * _taxFee) / 10**2;
    }

    function calculateDevFee(uint256 _amount, bool isBuy)
        private
        view
        returns (uint256)
    {
        uint256 _optionalDevFee = _optionalDevFeeBuy;
        if (!isBuy) {
            _optionalDevFee = _optionalDevFeeSell;
        }
        return (_amount * _optionalDevFeeBuy) / 10**2;
    }

    function calculatedevBNBFee(uint256 _amount, bool isBuy)
        private
        view
        returns (uint256)
    {
        uint256 _devBNBFee = _devBNBFeeBuy;
        if (!isBuy) {
            _devBNBFee = _devBNBFeeSell;
        }
        return (_amount * _devBNBFeeBuy) / 10**2;
    }

    function calculateLiquidityFee(uint256 _amount, bool isBuy)
        private
        view
        returns (uint256)
    {
        uint256 _liquidityFee = _liquidityFeeBuy;
        if (!isBuy) {
            _liquidityFee = _liquidityFeeSell;
        }
        return (_amount * _liquidityFeeBuy) / 10**2;
    }

    function removeFees() external onlyOwner {
        removeAllFee();
    }

    function restoreFees() external onlyOwner {
        restoreAllFee();
    }

    function removeAllFee() private {
        if (
            _taxFeeBuy == 0 &&
            _liquidityFeeBuy == 0 &&
            _optionalDevFeeBuy == 0 &&
            _devBNBFeeBuy == 0 &&
            _taxFeeSell == 0 &&
            _liquidityFeeSell == 0 &&
            _optionalDevFeeSell == 0 &&
            _devBNBFeeSell == 0
        ) return;

        _previousTaxFeeBuy = _taxFeeBuy;
        _previousLiquidityFeeBuy = _liquidityFeeBuy;
        _previousDevFeeBuy = _optionalDevFeeBuy;
        _previousdevBNBFeeBuy = _devBNBFeeBuy;

        _previousTaxFeeSell = _taxFeeSell;
        _previousLiquidityFeeSell = _liquidityFeeSell;
        _previousDevFeeSell = _optionalDevFeeSell;
        _previousdevBNBFeeSell = _devBNBFeeSell;

        _taxFeeBuy = 0;
        _liquidityFeeBuy = 0;
        _optionalDevFeeBuy = 0;
        _devBNBFeeBuy = 0;
        _taxFeeSell = 0;
        _liquidityFeeSell = 0;
        _optionalDevFeeSell = 0;
        _devBNBFeeSell = 0;
    }

    function restoreAllFee() private {
        _taxFeeBuy = _previousTaxFeeBuy;
        _liquidityFeeBuy = _previousLiquidityFeeBuy;
        _optionalDevFeeBuy = _previousDevFeeBuy;
        _devBNBFeeBuy = _previousdevBNBFeeBuy;
        _taxFeeSell = _previousTaxFeeSell;
        _liquidityFeeSell = _previousLiquidityFeeSell;
        _optionalDevFeeSell = _previousDevFeeSell;
        _devBNBFeeSell = _previousdevBNBFeeSell;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            !_isExcludedFromTransfer[from],
            "This adress can't send Tokens"
        ); // excluded adress can't sell
        require(
            !_isExcludedFromTransfer[to],
            "This adress can't receive Tokens"
        ); // excluded adress can't buy

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is pancakeswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (overMinTokenBalance && !inSwapAndLiquify && from != uniswapV2Pair) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquifyAndSendBNBToDevs(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        // indicates if it's a sell or a buy
        bool isBuy = (from == address(uniswapV2Router));
        bool isSell = (to == address(uniswapV2Router));

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //if it's neither a buy nor a sell, no fee
        if (!isBuy && !isSell) {
            takeFee = false;
        }

        //transfer amount, it will take tax, dev, liquidity fee
        _tokenTransfer(from, to, amount, takeFee, isBuy);
    }

    function swapAndLiquifyAndSendBNBToDevs(uint256 contractTokenBalance)
        private
        lockTheSwap
    {
        // split the contract balance into 3 parts, based on the fees
        // numToken * _devBNBFeeBuy / (_devBNBFeeBuy +_liquidityFeeBuy ) for dev
        // numToken * _liquidityFeeBuy / (_devBNBFeeBuy +_liquidityFeeBuy ) for liquidity
        // use a magnitude to avoid integer division problem
        uint256 magnitude = 1000;
        uint256 partForLiquidity = (contractTokenBalance *
            magnitude *
            _devBNBFeeBuy) /
            (_devBNBFeeBuy + _liquidityFeeBuy) /
            magnitude;
        uint256 partForDev = contractTokenBalance - partForLiquidity;

        // Swap tokens, and send them to devs
        uint256 originalBalance = address(this).balance;
        swapTokensForETH(partForDev);
        uint256 swappedBNB = address(this).balance - originalBalance;
        uint256 halfBnB = swappedBNB / 2;
        (bool success1, ) = devWalletOne.call{value: halfBnB}("");
        (bool success2, ) = devWalletTwo.call{value: swappedBNB - halfBnB}("");

        require(success1 && success2, "Swap and liquify failed");
        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;
        uint256 partForLiquidityToSwap = partForLiquidity / 2;
        uint256 partForLiquidityToAdd = partForLiquidity -
            partForLiquidityToSwap;
        // swap tokens for BNB
        swapTokensForETH(partForLiquidityToSwap);
        // how much BNB did we just swap into?
        uint256 BnbSwapped = address(this).balance - initialBalance;
        // add liquidity to pancakeswap
        addLiquidity(partForLiquidityToAdd, BnbSwapped);
        emit SwapAndLiquify(
            partForLiquidityToSwap,
            BnbSwapped,
            partForLiquidityToAdd
        );
    }

    function sendBnbLeftoverToDev() external onlyOwner {
        // see "SSL- 03 | Contract gains non-withdrawable BNB via the swapAndLiquifyfunction"
        // buy back with BNB leftover from SwapAndLiquify to increase price
        uint256 swappedBNB = address(this).balance;
        uint256 halfSwappedBNB = swappedBNB / 2;
        (bool success1, ) = devWalletTwo.call{value: halfSwappedBNB}("");
        (bool success2, ) = devWalletTwo.call{
            value: swappedBNB - halfSwappedBNB
        }("");
        require(success1 && success2, "Swap and liquify failed");
    }

    function buyWithLeftoverBNB(uint256 amount) external onlyOwner {
        // see "SSL- 03 | Contract gains non-withdrawable BNB via the swapAndLiquifyfunction"
        // buy back with BNB leftover from SwapAndLiquify to increase price
        // from Safemoon Certik Audit
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        _approve(address(this), address(uniswapV2Router), amount);

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens(
            amount,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        // generate the pancakeswap pair path of token -> WBNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        /* "to" account changed to address(this) to mitigate major centralization
         issue in Safemoon's contract.
         See "SSL-04 | Centralized risk in addLiquidity" from the Certik
         audit of Safemoon.
      */
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
        emit AddLiquidityETH(tokenAmount, ethAmount);
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee,
        bool isBuy
    ) private {
        /* Removed:
         ".....else  if  (!_isExcluded[sender]  &&  !_isExcluded[recipient])  {{        
                         _transferStandard(sender, recipient, amount);  }....."
                         
        See "SSL-02 | Redundant code" from the Certik audit of Safemoon
      */
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount, isBuy);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount, isBuy);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount, isBuy);
        } else {
            _transferStandard(sender, recipient, amount, isBuy);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount,
        bool isBuy
    ) private {
        Values memory values = _getValues(tAmount, isBuy);
        _rOwned[sender] = _rOwned[sender] - values.rAmount;
        _rOwned[recipient] = _rOwned[recipient] + values.rTransferAmount;
        _takeDevForBNB(values.tDevBNB);
        _takeLiquidity(values.tLiquidity);
        _takeDev(values.tDev);
        _reflectFee(values.rFee, values.tFee);
        emit Transfer(sender, recipient, values.tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        bool isBuy
    ) private {
        Values memory values = _getValues(tAmount, isBuy);
        _rOwned[sender] = _rOwned[sender] - values.rAmount;
        _tOwned[recipient] = _tOwned[recipient] + values.tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + values.rTransferAmount;
        _takeDevForBNB(values.tDevBNB);
        _takeLiquidity(values.tLiquidity);
        _takeDev(values.tDev);
        _reflectFee(values.rFee, values.tFee);
        emit Transfer(sender, recipient, values.tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        bool isBuy
    ) private {
        Values memory values = _getValues(tAmount, isBuy);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - values.rAmount;
        _rOwned[recipient] = _rOwned[recipient] + values.rTransferAmount;
        _takeDevForBNB(values.tDevBNB);
        _takeLiquidity(values.tLiquidity);
        _takeDev(values.tDev);
        _reflectFee(values.rFee, values.tFee);
        emit Transfer(sender, recipient, values.tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        bool isBuy
    ) private {
        Values memory values = _getValues(tAmount, isBuy);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - values.rAmount;
        _tOwned[recipient] = _tOwned[recipient] + values.tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + values.rTransferAmount;
        _takeDevForBNB(values.tDevBNB);
        _takeLiquidity(values.tLiquidity);
        _takeDev(values.tDev);
        _reflectFee(values.rFee, values.tFee);
        emit Transfer(sender, recipient, values.tTransferAmount);
    }

    //New Pancakeswap router version?
    //No problem, just change it!
    function setRouterAddress(address newRouter) external onlyOwner {
        IUniswapV2Router02 _uniswapV2newRouter = IUniswapV2Router02(newRouter);
        // Create a pancakeswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2newRouter.factory())
            .createPair(address(this), _uniswapV2newRouter.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2newRouter;
    }

    function setDevOneWallet(address payable newWallet) external onlyOwner {
        devWalletOne = newWallet;
    }

    function getDevOneWalletAddress() external view returns (address) {
        return devWalletOne;
    }

    function setDevTwoWallet(address payable newWallet) external onlyOwner {
        devWalletTwo = newWallet;
    }

    function getDevTwoWalletAddress() external view returns (address) {
        return devWalletTwo;
    }

    function getOptionnalDevWalletAddress() external view returns (address) {
        return devWalletOptional;
    }

    function setOptionalDevWallet(address payable newWallet)
        external
        onlyOwner
    {
        devWalletOptional = newWallet;
    }

    function setNumTokensToTriggerDevAndLiquidity(uint256 newvalue)
        external
        onlyOwner
    {
        numTokensSellToAddToLiquidity = newvalue;
    }
}
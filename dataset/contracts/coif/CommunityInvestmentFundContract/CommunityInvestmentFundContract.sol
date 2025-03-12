// SPDX-License-Identifier: MIT
// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol

pragma solidity >=0.6.2;

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

// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol

pragma solidity >=0.6.2;


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

// File: @uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol

pragma solidity >=0.5.0;

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

// File: @uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol

pragma solidity >=0.5.0;

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

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;


/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol


// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;




/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// File: coif_contract_mainchain_audit_v05.sol


pragma solidity 0.8.17;








interface IDividendDistributor {
    function setShare(
        address _shareholder,
        uint256 _amountNew,
        bool _processPool1Active,
        bool _processPool2Active,
        uint256 _payoutPool1ShareholderCount,
        uint256 _payoutPool2ShareholderCount
        ) external;

    function transferTokenFromPool2ToPool1(
        address _pool1Token,
        address _poolDistributorAddress,
        address _pool1Wallet
        ) external;

    function processPool1(
        uint256 _gas,
        address _processPool1Token,
        uint256 _payoutPool1CurrentTokenAmount,
        uint256 _payoutPool1ShareholderCount,
        address _poolDistributorAddress,
        uint256 _payoutPool1DividendsPerShare
        ) external;

    function processPool2(
        uint256 _gas,
        uint256 _payoutPool2ShareholderCount,
        address _poolDistributorAddress,
        uint256 _payoutPool2DividendsPerShare
        ) external;
}

contract CommunityInvestmentFundContract is ERC20, Ownable {
    ERC20 public constant WBNB = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); /* main chain */

    uint256 public constant MAX_FEE = 15; //total max fee = 15%
    uint256 public constant FEE_FACTOR = 100; //1% = 100 as fee; 0.01% = 1 as smallest fee
    uint256 public constant FEE_FACTOR_PERCENT = 100*FEE_FACTOR; //10,000 for direct calculation of fee amount
    uint8 private constant _decimals = 18;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public liquidityWallet;
    address public marketingWallet = address(0x1cE17B3813d00BA4808D707a475749a039870226);
    address public pool1Wallet = address(0x52769B308bB8FC78aFDBfa0bD345da8D85Eb31fA);
    DividendDistributor internal poolDistributor;
    address public poolDistributorAddress;
    address public processPool1Token;

    mapping (address => bool) private excludedFromFees;
    mapping (address => bool) private excludedFromDividends;
    mapping (address => bool) public canTransferBeforeTradingIsEnabled;
    mapping (address => bool) public automatedMarketMakerPairs;

    bool public tradingIsEnabled = false;
    bool public isOnlyTradeFee = true;

    uint256 public payoutGas = 500000;
    uint256 public swapFeeTokensMinAmount = 10000 * (10**18);
    bool private feesSwapping;

    uint256 public payoutPool1CurrentTokenAmount;
    uint256 public processPool1StartTime;
    bool public processPool1Trigger;
    bool public processPool1Active;

    uint256 public payoutPool2MinAmountWBNB = 5 * (10**18);
    uint256 public payoutPool2Percent = 20;
    uint256 public pool2BalanceWBNB;
    uint256 public payoutPool2CurrentWBNB;
    bool public isSaveParameterForPayout = true;
    bool public processPool2Active;

    uint256 public payoutPool1ShareholderCount;
    uint256 public payoutPool2ShareholderCount;
    uint256 public payoutPool1DividendsPerShare;
    uint256 public payoutPool2DividendsPerShare;
    uint256 public totalSharesAtCurrentPayoutPool1;
    uint256 public totalSharesAtCurrentPayoutPool2;
    //Buy fee complete: 0.10% + 0.20% + 0.49% + 0.20% = 0.99%
    uint256 public buyLiquidityFee = 10; //0.10%
    uint256 public buyMarketingFee = 20; //0.20%
    uint256 public buyPool1Fee = 49; //0.49%
    uint256 public buyPool2Fee = 20; //0.20%
    uint256 public buyPool3Fee = 0; //0%
    //Sell fee complete: 0.79% + 0.20% = 0.99%
    uint256 public sellLiquidityFee = 0; //0%
    uint256 public sellMarketingFee = 0; //0%
    uint256 public sellPool1Fee = 79; //0.79%
    uint256 public sellPool2Fee = 0; //0%
    uint256 public sellPool3Fee = 20; //0.20%
    //Transfer fee complete: 0%
    uint256 public txLiquidityFee = 0; //0%
    uint256 public txMarketingFee = 0; //0%
    uint256 public txPool1Fee = 0; //0%
    uint256 public txPool2Fee = 0; //0%
    uint256 public txPool3Fee = 0; //0%
    uint256 private collectedAmountLiquidityFee;
    uint256 private collectedAmountMarketingFee;
    uint256 private collectedAmountPool1Fee;
    uint256 private collectedAmountPool2Fee;
    uint256 private collectedAmountPool3Fee;
    uint256 private collectedAmountPool3FeeOld;

    event isExcludeFromDividends(address indexed account, bool isExcluded);
    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);
    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
    event Pool1WalletUpdated(address indexed newPool1Wallet, address indexed oldPool1Wallet);
    event SetSwapFeeTokensMinAmount(uint256 newSwapFeeTokensMinAmount);
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event updatedBuyFees(uint256 newBuyLiquidityFee, uint256 newBuyMarketingFee, uint256 newBuyPool1Fee, uint256 newBuyPool2Fee, uint256 newBuyPool3Fee);
    event updatedSellFees(uint256 newSellLiquidityFee, uint256 newSellMarketingFee, uint256 newSellPool1Fee, uint256 newSellPool2Fee, uint256 newSellPool3Fee);
    event updatedTxFees(uint256 newTxLiquidityFee, uint256 newTxMarketingFee, uint256 newTxPool1Fee, uint256 newTxPool2Fee, uint256 newTxPool3Fee);
    event PayoutGasUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event PayoutPool2PercentUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event PayoutPool2MinAmountWBNBUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event triggeredPool1Payout(bool indexed newProcessPool1Trigger, address indexed newProcessPool1Token, uint256 indexed newProcessPool1StartTime);
    event LaunchExecuted(bool newStatus);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);

    constructor() ERC20("CommunityInvestmentFund", "COIF"){
        poolDistributor = new DividendDistributor();
        poolDistributorAddress = address(poolDistributor);

        liquidityWallet = owner();

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); /* main chain */

        /*  _mint is an internal function in ERC20.sol that is only called here, and CANNOT be called ever again, _totalSupply = 100_000_000 * (10**_decimals) */
        _mint(owner(), 100_000_000 * (10**_decimals));

        approve(address(_uniswapV2Router), totalSupply());

        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        approve(_uniswapV2Pair, totalSupply());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        excludedFromDividends[poolDistributorAddress] = true;
        excludedFromDividends[address(_uniswapV2Pair)] = true;
        excludedFromDividends[address(_uniswapV2Router)] = true;
        excludedFromDividends[address(this)] = true;

        excludeFromFees(liquidityWallet, true);
        excludeFromFees(marketingWallet, true);
        excludeFromFees(pool1Wallet, true);
        excludeFromFees(poolDistributor.pool3Wallet(), true);
        excludeFromFees(poolDistributor.ecosystemWallet(), true);
        excludeFromFees(address(this), true);

        canTransferBeforeTradingIsEnabled[owner()] = true;
    }

    receive() external payable { }

    modifier validateAddressNotZero(address _address) {
        require(_address != address(0), "Error: Address cannot be zero");
        _;
    }

    function setLiquidityWallet(address _newLiquidityWallet) public onlyOwner validateAddressNotZero(_newLiquidityWallet) {
        require(_newLiquidityWallet != liquidityWallet, "Error: The liquidityWallet is already this address");
        excludeFromFees(_newLiquidityWallet, true);
        emit LiquidityWalletUpdated(_newLiquidityWallet, liquidityWallet);
        liquidityWallet = _newLiquidityWallet;
    }

    function setMarketingWallet(address _newMarketingWallet) public onlyOwner validateAddressNotZero(_newMarketingWallet) {
        require(_newMarketingWallet != marketingWallet, "Error: The marketingWallet is already this address");
        excludeFromFees(_newMarketingWallet, true);
        emit MarketingWalletUpdated(_newMarketingWallet, marketingWallet);
        marketingWallet = _newMarketingWallet;
    }

    function setPool1Wallet(address _newPool1Wallet) public onlyOwner validateAddressNotZero(_newPool1Wallet) {
        require(_newPool1Wallet != pool1Wallet, "Error: The pool1Wallet is already this address");
        excludeFromFees(_newPool1Wallet, true);
        emit Pool1WalletUpdated(_newPool1Wallet, pool1Wallet);
        pool1Wallet = _newPool1Wallet;
    }

    function setPool3Wallet(address _newPool3Wallet) public onlyOwner validateAddressNotZero(_newPool3Wallet) {
        poolDistributor.updatePool3Wallet(_newPool3Wallet);
        excludeFromFees(_newPool3Wallet, true);
    }

    function setPool3BurnAddress(address _newPool3BurnAddress) public onlyOwner validateAddressNotZero(_newPool3BurnAddress) {
        poolDistributor.updatePool3BurnAddress(_newPool3BurnAddress);
    }

    function setTeamWallet(address _newTeamWallet) public onlyOwner validateAddressNotZero(_newTeamWallet) {
        poolDistributor.updateTeamWallet(_newTeamWallet);
    }

    function setLongTermGrowthWallet(address _newLongTermGrowthWallet) public onlyOwner validateAddressNotZero(_newLongTermGrowthWallet) {
        poolDistributor.updateLongTermGrowthWallet(_newLongTermGrowthWallet);
    }

    function setEcosystemWallet(address _newEcosystemWallet) public onlyOwner validateAddressNotZero(_newEcosystemWallet) {
        poolDistributor.updateEcosystemWallet(_newEcosystemWallet);
    }

    function setTeamLockAddress(address _newTeamLockAddress) public onlyOwner validateAddressNotZero(_newTeamLockAddress) {
        poolDistributor.updateTeamLockAddress(_newTeamLockAddress);
    }

    function setLongTermGrowthLockAddress(address _newLongTermGrowthLockAddress) public onlyOwner validateAddressNotZero(_newLongTermGrowthLockAddress){
        poolDistributor.updateLongTermGrowthLockAddress(_newLongTermGrowthLockAddress);
    }

    function setEcosystemLockAddress(address _newEcosystemLockAddress) public onlyOwner validateAddressNotZero(_newEcosystemLockAddress) {
        poolDistributor.updateEcosystemLockAddress(_newEcosystemLockAddress);
    }

    function setSwapFeeTokensMinAmount(uint256 _swapMinAmount) public onlyOwner {
        require(_swapMinAmount <= (10**18), "Error: use the value without 10**18, e.g. 10000 for 10000 tokens");
        require(_swapMinAmount <= 100_000_000, "Error: token amount exceeds total supply");
        swapFeeTokensMinAmount = _swapMinAmount * 10**18;
        emit SetSwapFeeTokensMinAmount(swapFeeTokensMinAmount);
    }

    function updateUniswapV2Router(address _newAddress) public onlyOwner {
        require(_newAddress != address(uniswapV2Router), "Error: The router already has that address");
        emit UpdateUniswapV2Router(_newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(_newAddress);
        excludeFromDividends(_newAddress,true);
    }

    function excludeFromFees(address _account, bool _excluded) public onlyOwner {
        excludedFromFees[_account] = _excluded;
        emit ExcludeFromFees(_account, _excluded);
    }

    function isExcludedFromFees(address _account) public view returns(bool) {
        return excludedFromFees[_account];
    }

    function excludeMultipleAccountsFromFees(address[] calldata _accounts, bool _excluded) public onlyOwner {
        for(uint256 i = 0; i < _accounts.length; i++) {
            excludedFromFees[_accounts[i]] = _excluded;
        }
        emit ExcludeMultipleAccountsFromFees(_accounts, _excluded);
    }

    function setAutomatedMarketMakerPair(address _pair, bool _value) public onlyOwner {
        require(_pair != uniswapV2Pair, "Error: The PancakeSwap V2 pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(_pair, _value);
    }

    function _setAutomatedMarketMakerPair(address _pair, bool _value) private {
        require(automatedMarketMakerPairs[_pair] != _value, "Error: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[_pair] = _value;

        if(_value) {
            excludeFromDividends(_pair,true);
        }
        emit SetAutomatedMarketMakerPair(_pair, _value);
    }

    function excludeFromDividends(address _account, bool _excluded) public onlyOwner {
    	require(_account != address(this), "Token contract is excluded from dividends, it cannot be changed");
        excludedFromDividends[_account] = _excluded;

        if(_excluded){
            poolDistributor.setShare(_account, 0, processPool1Active, processPool2Active, payoutPool1ShareholderCount, payoutPool2ShareholderCount);
        }else{
            poolDistributor.setShare(_account, balanceOf(_account), processPool1Active, processPool2Active, payoutPool1ShareholderCount, payoutPool2ShareholderCount);
        }
        emit isExcludeFromDividends(_account,_excluded);
    }

    function isExcludedFromDividends(address _account) public view returns(bool) {
        return excludedFromDividends[_account];
    }

    function updateBuyFees(
        uint256 _newBuyLiquidityFee,
        uint256 _newBuyMarketingFee,
        uint256 _newBuyPool1Fee,
        uint256 _newBuyPool2Fee,
        uint256 _newBuyPool3Fee) public onlyOwner {
        require((_newBuyLiquidityFee + _newBuyMarketingFee + _newBuyPool1Fee + _newBuyPool2Fee + _newBuyPool3Fee) <= MAX_FEE * FEE_FACTOR, "Error: new desired fee over max limit");
        buyLiquidityFee = _newBuyLiquidityFee;
        buyMarketingFee = _newBuyMarketingFee;
        buyPool1Fee = _newBuyPool1Fee;
        buyPool2Fee = _newBuyPool2Fee;
        buyPool3Fee = _newBuyPool3Fee;
        emit updatedBuyFees(buyLiquidityFee, buyMarketingFee, buyPool1Fee, buyPool2Fee, buyPool3Fee);
    }

    function updateSellFees(
        uint256 _newSellLiquidityFee,
        uint256 _newSellMarketingFee,
        uint256 _newSellPool1Fee,
        uint256 _newSellPool2Fee,
        uint256 _newSellPool3Fee) public onlyOwner {
        require((_newSellLiquidityFee + _newSellMarketingFee + _newSellPool1Fee + _newSellPool2Fee + _newSellPool3Fee) <= MAX_FEE * FEE_FACTOR, "Error: new desired fee over max limit");
        sellLiquidityFee = _newSellLiquidityFee;
        sellMarketingFee = _newSellMarketingFee;
        sellPool1Fee = _newSellPool1Fee;
        sellPool2Fee = _newSellPool2Fee;
        sellPool3Fee = _newSellPool3Fee;
        emit updatedSellFees(sellLiquidityFee, sellMarketingFee, sellPool1Fee, sellPool2Fee, sellPool3Fee);
    }

    function updateTxFees(
        uint256 _newTxLiquidityFee,
        uint256 _newTxMarketingFee,
        uint256 _newTxPool1Fee,
        uint256 _newTxPool2Fee,
        uint256 _newTxPool3Fee) public onlyOwner {
        require((_newTxLiquidityFee + _newTxMarketingFee + _newTxPool1Fee + _newTxPool2Fee + _newTxPool3Fee) <= MAX_FEE * FEE_FACTOR, "Error: new desired fee over max limit");
        txLiquidityFee = _newTxLiquidityFee;
        txMarketingFee = _newTxMarketingFee;
        txPool1Fee = _newTxPool1Fee;
        txPool2Fee = _newTxPool2Fee;
        txPool3Fee = _newTxPool3Fee;
        emit updatedTxFees(txLiquidityFee, txMarketingFee, txPool1Fee, txPool2Fee, txPool3Fee);
    }

    function setTradeFeeStatus(bool _status) public onlyOwner {
        require(isOnlyTradeFee != _status, "Error: isOnlyTradeFee already has the value _status");
        isOnlyTradeFee = _status;
    }

    function setPayoutGas(uint256 _gas) public onlyOwner {
        require(_gas < 750000, "Error: gas must be under 750000");
        require(_gas != payoutGas, "Error: Cannot update payoutGas to the same value");
        emit PayoutGasUpdated(_gas, payoutGas);
        payoutGas = _gas;
    }

    function setPayoutPool2Percent(uint256 _payoutPool2Percent) public onlyOwner {
        require(_payoutPool2Percent <= 100, "Error: payoutPool2Percent has to be <= 100");
        require(payoutPool2Percent != _payoutPool2Percent, "Error: Cannot update payoutPool2Percent to the same value");
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
        poolDistributor.updatePayoutPool2TimeNext();
        emit PayoutPool2PercentUpdated(_payoutPool2Percent, payoutPool2Percent);
        payoutPool2Percent = _payoutPool2Percent;
    }

    function setPayoutPool2MinAmountWBNB(uint256 _payoutPool2MinAmountWBNB) public onlyOwner {
        require(_payoutPool2MinAmountWBNB <= (10**18), "Error: use the value without 10**18, e.g. 5 for 5 BNB");
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
        poolDistributor.updatePayoutPool2TimeNext();
        emit PayoutPool2MinAmountWBNBUpdated(_payoutPool2MinAmountWBNB, payoutPool2MinAmountWBNB / 10**18);
        payoutPool2MinAmountWBNB = _payoutPool2MinAmountWBNB * 10**18;
    }

    function setMinimumBalanceForDividends(uint256 _newMinimumBalance) public onlyOwner {
        require((!processPool1Active && !processPool2Active), "Error: process pool1 payout or pool2 payout is active, wait till end");
        poolDistributor.updateMinimumTokenBalanceForDividends(_newMinimumBalance);
    }

    function setPayoutPool2FrequencySec(uint256 _newPayoutPool2FrequencySec) public onlyOwner {
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
        poolDistributor.updatePayoutPool2FrequencySec(_newPayoutPool2FrequencySec);
    }

    function triggerPool1Payout(address _token, uint256 _startTime) public onlyOwner {
        require(!processPool1Active, "Pool 1 payout already active, wait till end");
        require(ERC20(_token).balanceOf(poolDistributorAddress)>0, "First transfer tokens for payout from pool1 to poolDistributorAddress");
        processPool1Trigger = true;
        processPool1Token = address(_token);
        processPool1StartTime = _startTime;
        emit triggeredPool1Payout(processPool1Trigger, processPool1Token, processPool1StartTime);
    }

    function getCurrentInfoAboutPool1() public view returns (
        bool processPool1Trigger_,
        bool processPool1Active_,
        bool payoutPool1ProcessFinished_,
        address processPool1Token_,
        uint256 processPool1StartTime_,
        uint256 payoutPool1CurrentTokenAmount_,
        uint256 payoutPool1DividendsPerShare_,
        uint256 totalSharesAtCurrentPayoutPool1_,
        uint256 payoutPool1ShareholderCount_,
        uint256 currentIndexPool1_ ) {
        processPool1Trigger_ = processPool1Trigger;
        processPool1Active_ = processPool1Active;
        payoutPool1ProcessFinished_ = poolDistributor.payoutPool1ProcessFinished();
        processPool1Token_ = processPool1Token;
        processPool1StartTime_ = processPool1StartTime;
        payoutPool1CurrentTokenAmount_ = payoutPool1CurrentTokenAmount;
        payoutPool1DividendsPerShare_ = payoutPool1DividendsPerShare;
        totalSharesAtCurrentPayoutPool1_ = totalSharesAtCurrentPayoutPool1;
        payoutPool1ShareholderCount_ = payoutPool1ShareholderCount;
        currentIndexPool1_ = poolDistributor.currentIndexPool1();
    }

    function getCurrentInfoAboutPool2() public view returns (
        bool processPool2Active_,
        bool payoutPool2ProcessFinished_,
        bool isSaveParameterForPayout_,
        uint256 payoutPool2MinAmountWBNB_,
        uint256 pool2BalanceWBNB_,
        uint256 payoutPool2CurrentWBNB_,
        uint256 payoutPool2DividendsPerShare_,
        uint256 totalSharesAtCurrentPayoutPool2_,
        uint256 payoutPool2ShareholderCount_,
        uint256 currentIndexPool2_,
        uint256 payoutPool2Time_,
        uint256 payoutPool2TimeNext_,
        uint256 secondsUntilNextPayout_) {
        processPool2Active_ = processPool2Active;
        payoutPool2ProcessFinished_ = poolDistributor.payoutPool2ProcessFinished();
        isSaveParameterForPayout_ = isSaveParameterForPayout;
        payoutPool2MinAmountWBNB_ = payoutPool2MinAmountWBNB;
        pool2BalanceWBNB_ = pool2BalanceWBNB;
        payoutPool2CurrentWBNB_ = payoutPool2CurrentWBNB;
        payoutPool2DividendsPerShare_ = payoutPool2DividendsPerShare;
        totalSharesAtCurrentPayoutPool2_ = totalSharesAtCurrentPayoutPool2;
        payoutPool2ShareholderCount_ = payoutPool2ShareholderCount;
        currentIndexPool2_ = poolDistributor.currentIndexPool2();
        (payoutPool2Time_, payoutPool2TimeNext_, secondsUntilNextPayout_) = poolDistributor.getInfoAboutPool2();
    }

    function getAccountDividendsInfoForPool2(address _account)
        public view returns (
            address account_,
            int256 index_,
            uint256 lastPayoutTimePool2_,
            uint256 sharesAmount_,
            uint256 sharesAmountExcludedPool2_,
            uint256 withdrawnDividendsPool2WBNB_,
            uint256 unpaidDividendsFromPool2_) {
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
        return poolDistributor.getAccountInfoForPool2(_account, poolDistributorAddress);
    }

	function getAccountDividendsInfoForPool2AtIndex(uint256 _index)
        public view returns (
            address account_,
            int256 index_,
            uint256 lastPayoutTimePool2_,
            uint256 sharesAmount_,
            uint256 sharesAmountExcludedPool2_,
            uint256 withdrawnDividendsPool2WBNB_,
            uint256 unpaidDividendsFromPool2_) {
        require(!processPool2Active, "Error: process pool2 payout is active, wait till end");
    	return poolDistributor.getAccountInfoForPool2AtIndex(_index, poolDistributorAddress);
    }

    function launch() public onlyOwner {
  	 require(!tradingIsEnabled, "Error: Lauch already executed and trading is already enabled");
	  tradingIsEnabled = true;
      emit LaunchExecuted(tradingIsEnabled);
      poolDistributor.updatePayoutPool2TimeNext();
  	}

    function setCanTransferBeforeTradingIsEnabled(address _wallet, bool _enabled) public onlyOwner {
        excludeFromDividends(_wallet, _enabled);
        excludeFromFees(_wallet, _enabled);
        canTransferBeforeTradingIsEnabled[_wallet] = _enabled;
    }

    function transferERC20TokenFromPool2ToPool1(address _pool1Token) public onlyOwner {
        poolDistributor.transferTokenFromPool2ToPool1(_pool1Token, poolDistributorAddress, pool1Wallet);
    }

    function transferERC20TokenFromContractAddressToPool1(address _tokenERC20) public onlyOwner {
            ERC20 tokenERC20 = ERC20(_tokenERC20);
            uint256 amount = tokenERC20.balanceOf(address(this));
            tokenERC20.transfer(pool1Wallet, amount);
    }

    function transferBNBFromContractAddressToPool1() public onlyOwner {
            address payable pool1WalletBNB = payable(pool1Wallet);
            pool1WalletBNB.transfer(address(this).balance);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "Error: transfer from the zero address");
        require(to != address(0), "Error: transfer to the zero address");
        require(amount > 0, "Error: Transfer amount must be greater than zero");

        if(!tradingIsEnabled) {
            require(canTransferBeforeTradingIsEnabled[from], "Error: This account cannot send tokens until trading is enabled");
        }

        if(
            tradingIsEnabled &&
            (balanceOf(address(this))>=swapFeeTokensMinAmount) &&
            !feesSwapping &&
            !automatedMarketMakerPairs[from] &&
            !excludedFromFees[from] &&
            !excludedFromFees[to]
        ) {
            feesSwapping = true;
            distributeCollectedFees(
                collectedAmountLiquidityFee,
                collectedAmountMarketingFee,
                collectedAmountPool1Fee,
                collectedAmountPool2Fee,
                collectedAmountPool3Fee
            );
            feesSwapping = false;
        }

        bool takeFee = tradingIsEnabled;
        if(excludedFromFees[from] || excludedFromFees[to]) {
            takeFee = false;
        } else if(isOnlyTradeFee && !automatedMarketMakerPairs[from] && !automatedMarketMakerPairs[to]) {
            takeFee = false;
            } else if(automatedMarketMakerPairs[from] && (to == address(uniswapV2Router)) ) {
                takeFee = false;
            }

        if(takeFee) {
            uint256 liquidityFee;
            uint256 marketingFee;
            uint256 pool1Fee;
            uint256 pool2Fee;
            uint256 pool3Fee;
            uint256 finalFee;
            if (!automatedMarketMakerPairs[from] && !automatedMarketMakerPairs[to]) {
                liquidityFee = (amount * txLiquidityFee) / FEE_FACTOR_PERCENT;
                marketingFee = (amount * txMarketingFee) / FEE_FACTOR_PERCENT;
                pool1Fee = (amount * txPool1Fee) / FEE_FACTOR_PERCENT;
                pool2Fee = (amount * txPool2Fee) / FEE_FACTOR_PERCENT;
                pool3Fee = (amount * txPool3Fee) / FEE_FACTOR_PERCENT;
            } else {
                bool isSell = automatedMarketMakerPairs[to] ? true : false;

                liquidityFee = isSell ? (amount * sellLiquidityFee) / FEE_FACTOR_PERCENT : (amount * buyLiquidityFee) / FEE_FACTOR_PERCENT;
                marketingFee = isSell ? (amount * sellMarketingFee) / FEE_FACTOR_PERCENT : (amount * buyMarketingFee) / FEE_FACTOR_PERCENT;
                pool1Fee = isSell ? (amount * sellPool1Fee) / FEE_FACTOR_PERCENT : (amount * buyPool1Fee) / FEE_FACTOR_PERCENT;
                pool2Fee = isSell ? (amount * sellPool2Fee) / FEE_FACTOR_PERCENT : (amount * buyPool2Fee) / FEE_FACTOR_PERCENT;
                pool3Fee = isSell ? (amount * sellPool3Fee) / FEE_FACTOR_PERCENT : (amount * buyPool3Fee) / FEE_FACTOR_PERCENT;
            }
            finalFee = liquidityFee + marketingFee + pool1Fee + pool2Fee + pool3Fee;

            collectedAmountLiquidityFee = collectedAmountLiquidityFee + liquidityFee;
            collectedAmountMarketingFee = collectedAmountMarketingFee + marketingFee;
            collectedAmountPool1Fee = collectedAmountPool1Fee + pool1Fee;
            collectedAmountPool2Fee = collectedAmountPool2Fee + pool2Fee;
            collectedAmountPool3Fee = collectedAmountPool3Fee + pool3Fee;
            amount = amount - finalFee;
            super._transfer(from, address(this), finalFee);
        }
        super._transfer(from, to, amount);

        if(!excludedFromDividends[from]){ try poolDistributor.setShare(from, balanceOf(from), processPool1Active, processPool2Active, payoutPool1ShareholderCount, payoutPool2ShareholderCount) {} catch {} }
        if(!excludedFromDividends[to]){ try poolDistributor.setShare(to, balanceOf(to), processPool1Active, processPool2Active, payoutPool1ShareholderCount, payoutPool2ShareholderCount) {} catch {} }

        if (processPool2Active){
            try poolDistributor.processPool2(payoutGas, payoutPool2ShareholderCount, poolDistributorAddress, payoutPool2DividendsPerShare) {} catch {}
            if (poolDistributor.payoutPool2ProcessFinished()) {
                isSaveParameterForPayout = true;
                processPool2Active = false;
            }
        } else {
            if (processPool1Active) {
                try poolDistributor.processPool1(payoutGas,
                                                processPool1Token,
                                                payoutPool1CurrentTokenAmount,
                                                payoutPool1ShareholderCount,
                                                poolDistributorAddress,
                                                payoutPool1DividendsPerShare) {} catch {}

                if(poolDistributor.payoutPool1ProcessFinished()) {
                    processPool1Active = false;
                }
            } else {
                if (processPool1Trigger && (block.timestamp >= processPool1StartTime)) {
                    payoutPool1ShareholderCount = poolDistributor.getNumberOfTokenHolders();
                    payoutPool1CurrentTokenAmount = ERC20(processPool1Token).balanceOf(poolDistributorAddress);
                    payoutPool1DividendsPerShare = (payoutPool1CurrentTokenAmount * poolDistributor.dividendsPerShareAccuracyFactor()) / poolDistributor.totalShares();
                    totalSharesAtCurrentPayoutPool1 = poolDistributor.totalShares();
                    processPool1Active = true;
                    processPool1Trigger = false;
                } else {
                    if (block.timestamp > poolDistributor.payoutPool2TimeNext()){
                        pool2BalanceWBNB = WBNB.balanceOf(poolDistributorAddress);
                        if (((pool2BalanceWBNB) > payoutPool2MinAmountWBNB) && (isSaveParameterForPayout)){
                            payoutPool2CurrentWBNB = (pool2BalanceWBNB * payoutPool2Percent) / 100;
                            payoutPool2ShareholderCount = poolDistributor.getNumberOfTokenHolders();
                            payoutPool2DividendsPerShare = (payoutPool2CurrentWBNB * poolDistributor.dividendsPerShareAccuracyFactor()) / poolDistributor.totalShares();
                            totalSharesAtCurrentPayoutPool2 = poolDistributor.totalShares();
                            isSaveParameterForPayout = false;
                            processPool2Active = true;
                        }
                    }
                }
            }
        }
    }

    function distributeCollectedFees(
        uint256 _collectedAmountLiquidityFee,
        uint256 _collectedAmountMarketingFee,
        uint256 _collectedAmountPool1Fee,
        uint256 _collectedAmountPool2Fee,
        uint256 _collectedAmountPool3Fee
        ) private {
        uint256 _collectedAmountLiquidityFeeDist = _collectedAmountLiquidityFee;
        uint256 _collectedAmountMarketingFeeDist = _collectedAmountMarketingFee;
        uint256 _collectedAmountPool1FeeDist = _collectedAmountPool1Fee;
        uint256 _collectedAmountPool2FeeDist = _collectedAmountPool2Fee;
        uint256 _collectedAmountPool3FeeDist = _collectedAmountPool3Fee;

        if(_collectedAmountLiquidityFeeDist > 0) {
            swapAndLiquify(_collectedAmountLiquidityFeeDist);
        }

        if(_collectedAmountMarketingFeeDist > 0) {

            swapAndSendFeeWBNB(_collectedAmountMarketingFeeDist, marketingWallet);
        }

        if(_collectedAmountPool1FeeDist > 0) {
            swapAndSendFeeWBNB(_collectedAmountPool1FeeDist, pool1Wallet);
        }

        if(_collectedAmountPool2FeeDist > 0) {
            swapAndSendFeeWBNB(_collectedAmountPool2FeeDist, poolDistributorAddress);
        }

        uint256 restTokens = balanceOf(address(this));
        if(restTokens > 0) {
            super._transfer(address(this), poolDistributor.pool3BurnAddress(), restTokens);
            if(!excludedFromDividends[poolDistributor.pool3BurnAddress()]) {
                try poolDistributor.setShare(poolDistributor.pool3BurnAddress(),
                                            balanceOf(poolDistributor.pool3BurnAddress()),
                                            processPool1Active,
                                            processPool2Active,
                                            payoutPool1ShareholderCount,
                                            payoutPool2ShareholderCount) {} catch {}
            }
        }
        collectedAmountLiquidityFee = 0;
        collectedAmountMarketingFee = 0;
        collectedAmountPool1Fee = 0;
        collectedAmountPool2Fee = 0;
        collectedAmountPool3FeeOld = _collectedAmountPool3FeeDist;
        collectedAmountPool3Fee = 0;
    }

    function swapAndLiquify(uint256 _tokens) private {
        uint256 half = _tokens / 2;
        uint256 otherHalf = _tokens - half;
        uint256 initialBalance = address(this).balance;

        swapTokensForBNB(half);

        uint256 newBalance = address(this).balance - initialBalance;

        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForBNB(uint256 _tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), _tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapAndSendFeeWBNB(uint256 _tokenAmount, address _to) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), _tokenAmount);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0,
            path,
            _to,
            block.timestamp
        );
    }

    function addLiquidity(uint256 _tokenAmount, uint256 _bnbAmount) private {
        _approve(address(this), address(uniswapV2Router), _tokenAmount);

        (uint256 amountToken, uint256 amountETH, ) = uniswapV2Router.addLiquidityETH{value: _bnbAmount}(
            address(this),
            _tokenAmount,
            0,
            0,
            liquidityWallet,
            block.timestamp
        );
        require(amountToken > 0 && amountETH > 0, "Failed to add liquidity");
    }

    function getCollectedFeeAmounts() public view returns (
        uint256 collectedAmountLiquidityFee_,
        uint256 collectedAmountMarketingFee_,
        uint256 collectedAmountPool1Fee_,
        uint256 collectedAmountPool2Fee_,
        uint256 collectedAmountPool3Fee_,
        uint256 collectedAmountPool3FeeOld_) {
        collectedAmountLiquidityFee_ = collectedAmountLiquidityFee;
        collectedAmountMarketingFee_ = collectedAmountMarketingFee;
        collectedAmountPool1Fee_ = collectedAmountPool1Fee;
        collectedAmountPool2Fee_ = collectedAmountPool2Fee;
        collectedAmountPool3Fee_ = collectedAmountPool3Fee;
        collectedAmountPool3FeeOld_ = collectedAmountPool3FeeOld;
    }
}

contract DividendDistributor is IDividendDistributor, Ownable {
    struct Share {
        uint256 amount;
        uint256 amountExcludedBuyPool1;
        uint256 amountExcludedBuyPool2;
        uint256 withdrawnDividendsWBNB;
    }

    ERC20 public constant WBNB = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); /* main chain */

    address public pool3Wallet = address(0xfD92637A67cfCbd7eE0c79056325e3701123d5A2);
    address public pool3BurnAddress;
    address public teamWallet = address(0xbB33Fe9Ac99eEAB84cDb05598F08Db9990902f6F);
    address public longTermGrowthWallet = address(0x01d8108FBACfa24245d088f5C69Cad994AC8989c);
    address public ecosystemWallet = address(0xcccA0cF893B6305d2a480d4Dde146bA0ee017EAB);
    address public teamLockAddress;
    address public longTermGrowthLockAddress;
    address public ecosystemLockAddress;

    address[] internal shareholders;
    address[] internal payoutPool1Tokens;
    mapping (address => uint256) payoutPool1TokensIndexes;
    mapping (address => uint256) payoutPool1TokensAmount;
    mapping (address => Share) public shares;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) public shareholderPayoutTimePool1;
    mapping (address => uint256) shareholderPayoutTimePool2;

    uint256 public totalShares;
    uint256 public immutable dividendsPerShareAccuracyFactor;
    uint256 public totalDistributedWBNB;
    uint256 internal payoutPool2Time;
    uint256 public payoutPool2TimeNext;
    uint256 public payoutPool2FrequencySec;
    bool public payoutPool1ProcessFinished = true;
    bool public payoutPool2ProcessFinished = true;
    uint256 public minimumTokenBalanceForDividends;
    uint256 public currentIndexPool1;
    uint256 public currentIndexPool2;

    event PayoutPool2FrequencySecUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event Pool3WalletUpdated(address indexed newPool3Wallet, address indexed oldPool3Wallet);
    event Pool3BurnAddressUpdated(address indexed newPool3BurnAddress, address indexed oldPool3BurnAddress);
    event TeamWalletUpdated(address indexed newTeamWallet, address indexed oldTeamWallet);
    event LongTermGrowthWalletUpdated(address indexed newLongTermGrowthWallet, address indexed oldLongTermGrowthWallet);
    event EcosystemWalletUpdated(address indexed newEcosystemWallet, address indexed oldEcosystemWallet);
    event TeamLockAddressUpdated(address indexed newTeamLockAddress, address indexed oldTeamLockAddress);
    event LongTermGrowthLockAddressUpdated(address indexed newLongTermGrowthLockAddress, address indexed oldLongTermGrowthLockAddress);
    event EcosystemLockAddressUpdated(address indexed newEcosystemLockAddress, address indexed oldEcosystemLockAddress);

    constructor() {
        minimumTokenBalanceForDividends = 100 * (10**18);
        payoutPool2FrequencySec = 2 weeks;
        dividendsPerShareAccuracyFactor = 10**36;
    }

    function setShare(
        address _shareholder,
        uint256 _amountNew,
        bool _processPool1Active,
        bool _processPool2Active,
        uint256 _payoutPool1ShareholderCount,
        uint256 _payoutPool2ShareholderCount)
        external override onlyOwner {
        if(_amountNew >= minimumTokenBalanceForDividends){
            if(shares[_shareholder].amount == 0) {
                addShareholder(_shareholder);
            }

            if (_processPool1Active){
                if (shareholderIndexes[_shareholder] < _payoutPool1ShareholderCount) {
                    if (currentIndexPool1 < shareholderIndexes[_shareholder]) {
                        if(shares[_shareholder].amount < _amountNew){
                            shares[_shareholder].amountExcludedBuyPool1 = (_amountNew - shares[_shareholder].amount) + shares[_shareholder].amountExcludedBuyPool1;
                        }
                    }
                }
            }

            if (_processPool2Active){
                if (shareholderIndexes[_shareholder] < _payoutPool2ShareholderCount) {
                    if (currentIndexPool2 < shareholderIndexes[_shareholder]) {
                        if(shares[_shareholder].amount < _amountNew) {
                            shares[_shareholder].amountExcludedBuyPool2 = (_amountNew - shares[_shareholder].amount) + shares[_shareholder].amountExcludedBuyPool2;
                        }
                    }
                }
            }

            totalShares = totalShares - shares[_shareholder].amount + _amountNew;
            shares[_shareholder].amount = _amountNew;

        } else {
            if(shares[_shareholder].amount > 0) {
                removeShareholder(_shareholder);
                totalShares = totalShares - shares[_shareholder].amount;
                shares[_shareholder].amount = 0;
            }
        }
    }

    function addShareholder(address _shareholder) internal {
        shareholderIndexes[_shareholder] = shareholders.length;
        shareholders.push(_shareholder);
    }

    function removeShareholder(address _shareholder) internal {
        shareholders[shareholderIndexes[_shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[_shareholder];
        shareholders.pop();
        delete shareholderIndexes[_shareholder];
        shares[_shareholder].amountExcludedBuyPool1 = 0;
        shares[_shareholder].amountExcludedBuyPool2 = 0;
    }

    function transferTokenFromPool2ToPool1(
        address _pool1Token,
        address _poolDistributorAddress,
        address _pool1Wallet
        ) external override onlyOwner {
            ERC20 pool1TokenERC20 = ERC20(_pool1Token);
            uint256 amount = pool1TokenERC20.balanceOf(_poolDistributorAddress);
            pool1TokenERC20.transfer(_pool1Wallet, amount);
    }

    function processPool1(
        uint256 _gas,
        address _processPool1Token,
        uint256 _payoutPool1CurrentTokenAmount,
        uint256 _payoutPool1ShareholderCount,
        address _poolDistributorAddress,
        uint256 _payoutPool1DividendsPerShare
        ) external override onlyOwner {
        uint256 shareholderCount = shareholders.length;
        if(shareholderCount == 0) { return; }
        if(_payoutPool1ShareholderCount < shareholderCount) {
            shareholderCount = _payoutPool1ShareholderCount;
        }
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        ERC20 processPool1TokenERC20 = ERC20(_processPool1Token);

        payoutPool1ProcessFinished = false;

        while(gasUsed < _gas && iterations <= shareholderCount) {
            if(currentIndexPool1 >= shareholderCount){
                currentIndexPool1 = 0;
                payoutPool1ProcessFinished = true;
                if(payoutPool1TokensAmount[_processPool1Token] > 0) {
                    if(_payoutPool1CurrentTokenAmount > processPool1TokenERC20.balanceOf(_poolDistributorAddress)) {
                        payoutPool1TokensAmount[_processPool1Token] = payoutPool1TokensAmount[_processPool1Token] + (_payoutPool1CurrentTokenAmount - processPool1TokenERC20.balanceOf(_poolDistributorAddress));
                    } else {
                        payoutPool1TokensAmount[_processPool1Token] = payoutPool1TokensAmount[_processPool1Token] + _payoutPool1CurrentTokenAmount;
                    }
                } else {
                    payoutPool1TokensIndexes[_processPool1Token] = payoutPool1Tokens.length;
                    payoutPool1Tokens.push(_processPool1Token);

                    if(_payoutPool1CurrentTokenAmount > processPool1TokenERC20.balanceOf(_poolDistributorAddress)) {
                        payoutPool1TokensAmount[_processPool1Token] = _payoutPool1CurrentTokenAmount - processPool1TokenERC20.balanceOf(_poolDistributorAddress);
                    } else {
                        payoutPool1TokensAmount[_processPool1Token] = _payoutPool1CurrentTokenAmount;
                    }
                }
                return;
            }
            payoutDividendsPool1(
                shareholders[currentIndexPool1],
                _processPool1Token,
                _poolDistributorAddress,
                _payoutPool1DividendsPerShare
                );

            gasUsed = gasUsed + gasLeft - gasleft();
            gasLeft = gasleft();
            currentIndexPool1++;
            iterations++;
        }
    }

    function processPool2(
        uint256 _gas,
        uint256 _payoutPool2ShareholderCount,
        address _poolDistributorAddress,
        uint256 _payoutPool2DividendsPerShare
        ) external override onlyOwner {
        uint256 shareholderCount = shareholders.length;
        if(shareholderCount == 0) { return; }
        if(_payoutPool2ShareholderCount < shareholderCount) {
            shareholderCount = _payoutPool2ShareholderCount;
        }
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        payoutPool2ProcessFinished = false;

        while(gasUsed < _gas && iterations <= shareholderCount) {
            if(currentIndexPool2 >= shareholderCount){
                currentIndexPool2 = 0;
                payoutPool2Time = block.timestamp;
                payoutPool2TimeNext =  payoutPool2Time + payoutPool2FrequencySec;
                payoutPool2ProcessFinished = true;
                return;
            }

            payoutDividendsPool2(shareholders[currentIndexPool2], _poolDistributorAddress, _payoutPool2DividendsPerShare);

            gasUsed = gasUsed + gasLeft - gasleft();
            gasLeft = gasleft();
            currentIndexPool2++;
            iterations++;
        }
    }

    function payoutDividendsPool1(
        address _shareholder,
        address _processPool1Token,
        address _poolDistributorAddress,
        uint256 _payoutPool1DividendsPerShare
        ) internal {

        uint256 amount = 0;
        ERC20 processPool1TokenERC20 = ERC20(_processPool1Token);
        if(shares[_shareholder].amount == 0){ return; }
        if(shares[_shareholder].amount <= shares[_shareholder].amountExcludedBuyPool1){
            amount = 0;
        }
        else{
            amount = (((shares[_shareholder].amount) - shares[_shareholder].amountExcludedBuyPool1) * _payoutPool1DividendsPerShare) / dividendsPerShareAccuracyFactor;
            
            if(amount > processPool1TokenERC20.balanceOf(_poolDistributorAddress)) {
                amount = processPool1TokenERC20.balanceOf(_poolDistributorAddress);
            }
        }

        if(amount > 0){
            if (_shareholder==pool3BurnAddress) {
                processPool1TokenERC20.transfer(pool3Wallet, amount);
            }
            else if (_shareholder==teamLockAddress) {
                processPool1TokenERC20.transfer(teamWallet, amount);
            }
            else if (_shareholder==longTermGrowthLockAddress) {
                processPool1TokenERC20.transfer(longTermGrowthWallet, amount);
            }
            else if (_shareholder==ecosystemLockAddress) {
                processPool1TokenERC20.transfer(ecosystemWallet, amount);
            }
            else {
                processPool1TokenERC20.transfer(_shareholder, amount);
            }
            shareholderPayoutTimePool1[_shareholder] = block.timestamp;
        }
        shares[_shareholder].amountExcludedBuyPool1 = 0;
    }

    function payoutDividendsPool2(
        address _shareholder,
        address _poolDistributorAddress,
        uint256 _payoutPool2DividendsPerShare
        ) internal {

        uint256 amount = 0;
        if(shares[_shareholder].amount == 0){ return; }
        if(shares[_shareholder].amount <= shares[_shareholder].amountExcludedBuyPool2){
            amount = 0;
        }
        else{
            amount = (((shares[_shareholder].amount) - shares[_shareholder].amountExcludedBuyPool2) * _payoutPool2DividendsPerShare) / dividendsPerShareAccuracyFactor;

            if(amount > WBNB.balanceOf(_poolDistributorAddress)) {
                amount = WBNB.balanceOf(_poolDistributorAddress);
            }
        }

        if(amount > 0){
            totalDistributedWBNB = totalDistributedWBNB + amount;
            if (_shareholder==pool3BurnAddress) {
                WBNB.transfer(pool3Wallet, amount);
            }
            else if (_shareholder==teamLockAddress) {
                WBNB.transfer(teamWallet, amount);
            }
            else if (_shareholder==longTermGrowthLockAddress) {
                WBNB.transfer(longTermGrowthWallet, amount);
            }
            else if (_shareholder==ecosystemLockAddress) {
                WBNB.transfer(ecosystemWallet, amount);
            }
            else {
                WBNB.transfer(_shareholder, amount);
            }
            shareholderPayoutTimePool2[_shareholder] = block.timestamp;
            shares[_shareholder].withdrawnDividendsWBNB = (shares[_shareholder].withdrawnDividendsWBNB) + amount;
        }
        shares[_shareholder].amountExcludedBuyPool2 = 0;
    }

    function getInfoAboutPool1AtIndex(uint256 _index) external view returns (
        uint256 amountDifferentTokensPayoutsPool1_,
        address tokenPayoutPool1_,
        uint256 amountPayoutPool1_,
        uint256 indexPayoutPool1_) {
        tokenPayoutPool1_ = payoutPool1Tokens[_index];
        require((payoutPool1TokensAmount[tokenPayoutPool1_] > 0), "Error: no pool 1 payout with this token yet");
        amountDifferentTokensPayoutsPool1_ = payoutPool1Tokens.length;
        amountPayoutPool1_ = payoutPool1TokensAmount[tokenPayoutPool1_];
        indexPayoutPool1_ = _index;
    }

    function getInfoAboutPool1AtToken(address _processPool1Token) external view returns (
        uint256 amountDifferentTokensPayoutsPool1_,
        address tokenPayoutPool1_,
        uint256 amountPayoutPool1_,
        uint256 indexPayoutPool1_) {
        require((payoutPool1TokensAmount[_processPool1Token] > 0), "Error: no pool 1 payout with this token yet");
        amountDifferentTokensPayoutsPool1_ = payoutPool1Tokens.length;
        tokenPayoutPool1_ = _processPool1Token;
        amountPayoutPool1_ = payoutPool1TokensAmount[_processPool1Token];
        indexPayoutPool1_ = payoutPool1TokensIndexes[_processPool1Token];
    }

    function getInfoAboutPool2() external view returns (
            uint256 payoutPool2Time_,
            uint256 payoutPool2TimeNext_,
            uint256 secondsUntilNextPayout_) {
            payoutPool2Time_ = payoutPool2Time;
            payoutPool2TimeNext_ = payoutPool2TimeNext;
            secondsUntilNextPayout_ = payoutPool2TimeNext_ > block.timestamp ?
                                      payoutPool2TimeNext_ - block.timestamp :
                                      0;
    }

    function getAccountInfoForPool2(address _accountAddress, address _poolDistributorAddress) public view returns (
            address account_,
            int256 index_,
            uint256 lastPayoutTimePool2_,
            uint256 sharesAmount_,
            uint256 sharesAmountExcludedPool2_,
            uint256 withdrawnDividendsPool2WBNB_,
            uint256 unpaidDividendsFromPool2_) {
        account_ = _accountAddress;
        if(shares[_accountAddress].amount == 0) {
            index_ = -1;
        }
        else {
            index_ = int(shareholderIndexes[_accountAddress]);
        }
        lastPayoutTimePool2_ = shareholderPayoutTimePool2[_accountAddress];
        sharesAmount_ = shares[_accountAddress].amount;
        sharesAmountExcludedPool2_ = shares[_accountAddress].amountExcludedBuyPool2;
        withdrawnDividendsPool2WBNB_ = shares[_accountAddress].withdrawnDividendsWBNB;
        unpaidDividendsFromPool2_ = getUnpaidDividendsFromPool2(_accountAddress, _poolDistributorAddress);
    }

    function getAccountInfoForPool2AtIndex(uint256 _index, address _poolDistributorAddress) external view returns (
            address account_,
            int256 index_,
            uint256 lastPayoutTimePool2_,
            uint256 sharesAmount_,
            uint256 sharesAmountExcludedPool2_,
            uint256 withdrawnDividendsPool2WBNB_,
            uint256 unpaidDividendsFromPool2_) {
    	if(_index >= (shareholders.length)) {
            return (0x0000000000000000000000000000000000000000, -1, 0, 0, 0, 0, 0);
        }

        address _account = shareholders[_index];
        return getAccountInfoForPool2(_account, _poolDistributorAddress);
    }

    function getUnpaidDividendsFromPool2(address _shareholder, address _poolDistributorAddress) public view returns (uint256) {
        if(shares[_shareholder].amount == 0){ return 0; }
        uint256 _divPerShare = ((WBNB.balanceOf(_poolDistributorAddress)) * dividendsPerShareAccuracyFactor) / totalShares;
        return ((shares[_shareholder].amount) * _divPerShare) / dividendsPerShareAccuracyFactor;
    }

    function updatePayoutPool2FrequencySec(uint256 _newPayoutPool2FrequencySec) external onlyOwner {
        emit PayoutPool2FrequencySecUpdated(_newPayoutPool2FrequencySec, payoutPool2FrequencySec);
        payoutPool2FrequencySec = _newPayoutPool2FrequencySec;
        updatePayoutPool2TimeNext();
    }

    function updatePayoutPool2TimeNext() public onlyOwner {
        payoutPool2TimeNext =  block.timestamp + payoutPool2FrequencySec;
    }

    function updateMinimumTokenBalanceForDividends(uint256 _newMinimumBalance) external onlyOwner {
        require(_newMinimumBalance <= (10**18), "Error: use the value without 10**18, e.g. 100 tokens");
        require(_newMinimumBalance <= 100_000_000, "Error: token amount exceeds total supply");
        minimumTokenBalanceForDividends = _newMinimumBalance * 10**18;
    }

    function getNumberOfTokenHolders() external view returns(uint256) {
        return shareholders.length;
    }

    function updatePool3Wallet(address _newPool3Wallet) external onlyOwner {
        require(_newPool3Wallet != pool3Wallet, "Error: The pool3Wallet is already this address");
        emit Pool3WalletUpdated(_newPool3Wallet, pool3Wallet);
        pool3Wallet = _newPool3Wallet;
    }

    function updatePool3BurnAddress(address _newPool3BurnAddress) external onlyOwner {
        require(_newPool3BurnAddress != pool3BurnAddress, "Error: The pool3BurnAddress is already this address");
        emit Pool3BurnAddressUpdated(_newPool3BurnAddress, pool3BurnAddress);
        pool3BurnAddress = _newPool3BurnAddress;
    }

    function updateTeamWallet(address _newTeamWallet) external onlyOwner {
        require(_newTeamWallet != teamWallet, "Error: The teamWallet is already this address");
        emit TeamWalletUpdated(_newTeamWallet, teamWallet);
        teamWallet = _newTeamWallet;
    }

    function updateLongTermGrowthWallet(address _newLongTermGrowthWallet) external onlyOwner {
        require(_newLongTermGrowthWallet != longTermGrowthWallet, "Error: The longTermGrowthWallet is already this address");
        emit LongTermGrowthWalletUpdated(_newLongTermGrowthWallet, longTermGrowthWallet);
        longTermGrowthWallet = _newLongTermGrowthWallet;
    }

    function updateEcosystemWallet(address _newEcosystemWallet) external onlyOwner {
        require(_newEcosystemWallet != ecosystemWallet, "Error: The ecosystemWallet is already this address");
        emit EcosystemWalletUpdated(_newEcosystemWallet, ecosystemWallet);
        ecosystemWallet = _newEcosystemWallet;
    }

    function updateTeamLockAddress(address _newTeamLockAddress) external onlyOwner {
        require(_newTeamLockAddress != teamLockAddress, "Error: The teamLockAddress is already this address");
        emit TeamLockAddressUpdated(_newTeamLockAddress, teamLockAddress);
        teamLockAddress = _newTeamLockAddress;
    }

    function updateLongTermGrowthLockAddress(address _newLongTermGrowthLockAddress) external onlyOwner {
        require(_newLongTermGrowthLockAddress != longTermGrowthLockAddress, "Error: The longTermGrowthLockAddress is already this address");
        emit LongTermGrowthLockAddressUpdated(_newLongTermGrowthLockAddress, longTermGrowthLockAddress);
        longTermGrowthLockAddress = _newLongTermGrowthLockAddress;
    }

    function updateEcosystemLockAddress(address _newEcosystemLockAddress) external onlyOwner {
        require(_newEcosystemLockAddress != ecosystemLockAddress, "Error: The ecosystemLockAddress is already this address");
        emit EcosystemLockAddressUpdated(_newEcosystemLockAddress, ecosystemLockAddress);
        ecosystemLockAddress = _newEcosystemLockAddress;
    }
}
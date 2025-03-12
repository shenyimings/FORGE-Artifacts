// Sources flattened with hardhat v2.6.4 https://hardhat.org

// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v4.3.2

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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


// File contracts/IMyToken.sol

pragma solidity ^0.8.0;
interface IMyToken is IERC20 {
    function getHolders() external returns (address[] memory);

    function getOwner() external view returns (address);
}


// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol@v4.3.2

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


// File @openzeppelin/contracts/utils/Context.sol@v4.3.2

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


// File @openzeppelin/contracts/token/ERC20/ERC20.sol@v4.3.2

pragma solidity ^0.8.0;



/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
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
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
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
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
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
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
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
        _balances[account] += amount;
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
        }
        _totalSupply -= amount;

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
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
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
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

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
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}


// File contracts/MyToken.sol

pragma solidity ^0.8.0;
contract MyToken is ERC20 {
    address[] internal _tokenHolders;
    mapping(address => bool) internal _tokenHolderExists;
    mapping(address => uint256) internal _tokenHolderArrayIndex;
    address private _bep20deployer;

    constructor(
        uint256 initialBalance,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _mint(_msgSender(), initialBalance);
        _addTokenHolder(_msgSender());
        _bep20deployer = _msgSender();
    }

    /**
     * @dev Triggered after a token transfer has occurred
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (amount > 0) {
            _addTokenHolder(to);
        }
        if (balanceOf(from) == 0) {
            _removeTokenHolder(from);
        }
    }

    /**
     * @dev Add a token holder to the array (if not yet exists). Fully scalable
     * Inspired by https://ethereum.stackexchange.com/a/12707/31933
     */
    function _addTokenHolder(address tokenHolder) internal {
        if (!_tokenHolderExists[tokenHolder]) {
            // doesn't exist
            _tokenHolders.push(tokenHolder);
            _tokenHolderExists[tokenHolder] = true;
            _tokenHolderArrayIndex[tokenHolder] = _tokenHolders.length - 1;
        }
    }

    /**
     * @dev Remove a token holder from the array. Fully scalable
     */
    function _removeTokenHolder(address tokenHolder) internal {
        if (_tokenHolderExists[tokenHolder]) {
            address lastHolder = _tokenHolders[_tokenHolders.length - 1];
            // Move the last entry to replace this entry
            _tokenHolders[_tokenHolderArrayIndex[tokenHolder]] = lastHolder;
            _tokenHolders.pop(); // remove last entry

            // Update index for the moved holder
            _tokenHolderArrayIndex[lastHolder] = _tokenHolderArrayIndex[
                tokenHolder
            ];

            // Remove index
            delete _tokenHolderArrayIndex[tokenHolder];
            // Mark as non-existing
            _tokenHolderExists[tokenHolder] = false;
        }
    }

    function getHolders() public view returns (address[] memory) {
        return _tokenHolders;
    }

    /**
     * @dev To make the token fully BEP-20 compatible. No real usage
     */
    function getOwner() external view returns (address) {
        return _bep20deployer;
    }
}


// File contracts/mocks/MyTokenMock.sol

pragma solidity ^0.8.0;

// mock class using ERC20, used by unit tests. Don't deploy in a real network
contract MyTokenMock is MyToken {
    constructor(uint256 initialBalance)
        payable
        MyToken(initialBalance, "", "")
    {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function transferInternal(
        address from,
        address to,
        uint256 value
    ) public {
        _transfer(from, to, value);
    }

    function approveInternal(
        address owner,
        address spender,
        uint256 value
    ) public {
        _approve(owner, spender, value);
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v4.3.2

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
        _setOwner(_msgSender());
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


// File contracts/Rewards.sol

pragma solidity ^0.8.0;
// TODO: cleanup the code
contract Rewards is Ownable {
    IMyToken internal _underlying;
    address internal _blacklisted; // the liquidity pool

    // Batch related variables
    uint256 internal _batchSize;
    address[] internal _batchHolders;
    mapping(address => uint256) _batchBalances;
    uint256 internal _batchSupply;
    uint256 internal _batchToShare;
    uint256 internal _batchCurrentIndex = 0;

    event ReceiverRefusedReward(address indexed);
    event BatchCompleted();

    constructor(address underlying, address blacklistAddress) {
        _underlying = IMyToken(underlying);
        _blacklisted = blacklistAddress;
    }

    /**
    @dev Initiates a new batch run: stores a snapshot of the current token data
    */
    function initiateBatch(uint256 batchSize) public payable {
        require(_batchSize == 0, "There is already a batch running");
        _batchToShare = address(this).balance;
        require(_batchToShare > 0, "There has to be some reward");

        _batchSize = batchSize;
        _batchHolders = _underlying.getHolders();
        _batchSupply = _underlying.totalSupply();

        for (uint256 i; i < _batchHolders.length; i++) {
            // Set user balances
            _batchBalances[_batchHolders[i]] = _underlying.balanceOf(
                _batchHolders[i]
            );
            // Remove the effect of the blacklisted address
            if (_batchHolders[i] == _blacklisted) {
                // Ignore the amount of the blacklisted address
                _batchSupply -= _underlying.balanceOf(_blacklisted);
                // Set batch balance to zero, so no rewards given
                _batchBalances[_batchHolders[i]] = 0;
            }
        }
    }

    /**
     * @dev Processes a started batch
     */
    function processBatch() public {
        require(_batchSize > 0, "No batch running");
        uint256 currentStart = _batchCurrentIndex;
        // Do while 1) we still have holders to process and 2) we haven't exceeded the batch size
        for (
            _batchCurrentIndex;
            _batchCurrentIndex < _batchHolders.length &&
                _batchCurrentIndex < currentStart + _batchSize;
            _batchCurrentIndex++
        ) {
            uint256 bal = _batchBalances[_batchHolders[_batchCurrentIndex]];
            // Check is relevant only for the blacklisted address
            if (bal > 0) {
                uint256 share = (_batchToShare * bal) / _batchSupply;

                (bool success, ) = _batchHolders[_batchCurrentIndex].call{
                    value: share,
                    gas: 3000
                }("");
                if (!success) {
                    emit ReceiverRefusedReward(
                        _batchHolders[_batchCurrentIndex]
                    );
                }
            }
        }
        // Check if all is done
        if (_batchCurrentIndex == _batchHolders.length) {
            _resetBatch();
            emit BatchCompleted();
        }
    }

    /**
     * @dev Resets a batch run. Called internally when the batch is completed
     */
    function _resetBatch() private {
        delete _batchCurrentIndex;
        delete _batchSize;
        delete _batchHolders;
        //delete _batchBalances; // Not so trivial to delete, but also no need to delete
        delete _batchSupply;
        delete _batchToShare;
    }

    /**
     * @dev An emergency function for owner to recover assets, if something goes wrong.
     * Note that the contract will be useless after doing this
     */
    function recoverAssets() public onlyOwner {
        (bool success, ) = owner().call{
            value: address(this).balance,
            gas: 3000
        }("");
        // Silence warnings without generating bytecode
        success;
    }

    /**
     * @dev Sends rewards to all holders without batch processing
     */
    function notifyRewards() public payable {
        uint256 toShare = address(this).balance;
        require(toShare > 0, "There has to be some reward");
        address[] memory holders = _underlying.getHolders();
        uint256 supply = _underlying.totalSupply();

        // Remove the effect of the blacklisted address
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == _blacklisted) {
                // Set the address to someone who doesn't have tokens, so no rewards given
                holders[i] = address(0x1);
                // Ignore the amount of the blacklisted address
                supply -= _underlying.balanceOf(_blacklisted);
                break;
            }
        }

        for (uint256 i = 0; i < holders.length; i++) {
            uint256 bal = _underlying.balanceOf(holders[i]);
            // Check is relevant check only for the blacklisted address
            if (bal > 0) {
                uint256 share = (toShare * bal) / supply;
                (bool success, ) = holders[i].call{value: share, gas: 3000}("");
                if (!success) {
                    emit ReceiverRefusedReward(holders[i]);
                }
            }
        }
    }
}


// File contracts/mocks/ReverterMock.sol

pragma solidity ^0.8.0;

// mock class, used by unit tests. Don't deploy in a real network
contract ReverterMock {
    receive() external payable {
        revert();
    }
}
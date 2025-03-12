/**
 *Submitted for verification at BscScan.com on 2023-09-15
*/

/**
 *Submitted for verification at FTMScan.com on 2023-09-05
*/

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)
// import "hardhat/console.sol";
pragma solidity ^0.8.0;



// a library for performing various math operations

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(
        Set storage set,
        bytes32 value
    ) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(
        Set storage set,
        uint256 index
    ) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(
        Bytes32Set storage set,
        bytes32 value
    ) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(
        Bytes32Set storage set,
        bytes32 value
    ) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(
        Bytes32Set storage set,
        bytes32 value
    ) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(
        Bytes32Set storage set,
        uint256 index
    ) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(
        Bytes32Set storage set
    ) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(
        AddressSet storage set,
        address value
    ) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(
        AddressSet storage set,
        address value
    ) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(
        AddressSet storage set,
        address value
    ) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(
        AddressSet storage set,
        uint256 index
    ) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(
        AddressSet storage set
    ) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(
        UintSet storage set,
        uint256 value
    ) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(
        UintSet storage set,
        uint256 value
    ) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(
        UintSet storage set,
        uint256 index
    ) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(
        UintSet storage set
    ) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

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
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

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
    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
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
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
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
    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
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
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: transfer amount exceeds allowance"
            );
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }

        _transfer(sender, recipient, amount);

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
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
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
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
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
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
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
        _owner = _msgSender();
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
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Pair {
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function balanceOf(address owner) external view returns (uint);

    function totalSupply() external view returns (uint);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function sync() external;
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router02 {
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

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract LpStaking {
    address public stakeOutToken;

    //
    uint256 public total;
    //

    uint256 private _totalSupply;
    uint256 public starttime;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public deposits;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function init(address _outToken, uint256 _totalReward) external onlyOwner {
        stakeOutToken = _outToken;
        total = _totalReward;
        starttime = block.timestamp;

        lastUpdateTime = starttime;
        periodFinish = starttime + 365 * 2 * 86400;
        rewardRate = total / (periodFinish - starttime);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        if (block.timestamp < periodFinish) {
            return block.timestamp;
        }
        return periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) /
            totalSupply();
    }

    function earned(address account) public view returns (uint256) {
        return
            (deposits[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18 +
            rewards[account];
    }

    function stake(
        address account,
        uint256 amount
    ) public onlyOwner updateReward(account) {
        require(amount > 0, " Cannot stake 0");
        uint256 newDeposit = deposits[account] + amount;
        deposits[account] = newDeposit;
        _totalSupply += amount;
        emit Staked(account, amount);
    }

    function withdraw(
        address account,
        uint256 amount
    ) public onlyOwner updateReward(account) {
        require(amount > 0, " Cannot withdraw 0");
        deposits[account] = deposits[account] - amount;
        _totalSupply -= amount;
        emit Withdrawn(account, amount);
    }

    function clear(
        address account,
        bool clearReward
    ) public onlyOwner updateReward(account) {
        _totalSupply -= deposits[account];
        deposits[account] = 0;
        if (clearReward) {
            rewards[account] = 0;
        }
    }

    function exit(address account) external {
        withdraw(account, deposits[account]);
        getReward(account);
    }

    function getReward(address account) public updateReward(account) {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            safeTransfer(stakeOutToken, account, reward);
            emit RewardPaid(account, reward);
        }
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FAILED"
        );
    }
}

contract rewardLp7 is ERC20, Ownable {
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FAILED"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FROM_FAILED"
        );
    }

    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: APPROVE_FAILED"
        );
    }

    using EnumerableSet for EnumerableSet.AddressSet;
    uint public constant DECIMAL_PRECISION = 1e18;
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    IUniswapV2Router02 public uniswapV2Router;
    mapping(address => bool) public ammPairs;
    IUniswapV2Pair public uniswapV2Pair;
    address pairAddress;

    uint256 public txFee = 5;
    uint256 public burnFee = 1;
    uint256 public lpRewardFee = 2;
    uint256 public ref1Fee = 1;
    uint256 public ref2Fee = 2;

    uint256 constant feeDivisor = 100;

    //
    mapping(address => address) public inviter;

    mapping(address => uint256) public lps;
    IERC20 currency;
    bool public isInitLp;

    struct PoolInfo {
        uint256 index;
        uint256 period;
        uint256 lastSendTime;
        uint minReward;
        uint sendCount;
        uint minLpAmount;
        IUniswapV2Pair pair;
        EnumerableSet.AddressSet tokenHolder;
        EnumerableSet.AddressSet tempRemoveList;
    }

    PoolInfo info;

    uint public feePerLpStaked;
    uint public totalStaked;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public lastSnapshots;
    //
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) public isBlocks;
    bool public isSwapEnabled = false;

    LpStaking public lpstaking;
    uint256 totalAmountLpstaking;

    address public deadAddress = address(0xDead);

    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance,
        address _router,
        address _currency
    ) payable ERC20(name, symbol) {
        lpstaking = new LpStaking();

        uint n30 = (initialBalance * 3) / 10;
        totalAmountLpstaking = initialBalance - n30;
        _mint(initialAccount, n30);
        _mint(address(lpstaking), totalAmountLpstaking);
        uniswapV2Router = IUniswapV2Router02(_router);

        address uniswapV2PairAddress = IUniswapV2Factory(
            uniswapV2Router.factory()
        ).createPair(address(this), _currency);
        currency = IERC20(_currency);

        pairAddress = uniswapV2PairAddress;
        uniswapV2Pair = IUniswapV2Pair(uniswapV2PairAddress);
        ammPairs[uniswapV2PairAddress] = true;
        //init
        info.period = 3600;
        info.lastSendTime = block.timestamp;
        info.minReward = 1e9;
        info.minLpAmount = 1e8;
        info.sendCount = 20;
        info.pair = uniswapV2Pair;

        //
        _isExcludedFromFee[initialAccount] = true;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(lpstaking)] = true;
        //
    }

    struct PoolConfig {
        uint256 period;
        uint256 lastSendTime;
        uint minReward;
        uint sendCount;
        uint minLpAmount;
    }

    function getPoolConfig() external view returns (PoolConfig memory config) {
        config.period = info.period;
        config.lastSendTime = info.lastSendTime;
        config.minReward = info.minReward;
        config.minLpAmount = info.minLpAmount;
        config.sendCount = info.sendCount;
    }

    function setPoolConfig(
        uint _period,
        uint _minReward,
        uint _minLpAmount,
        uint _sendCount
    ) external onlyOwner {
        info.period = _period;
        info.minReward = _minReward;
        info.minLpAmount = _minLpAmount;
        info.sendCount = _sendCount;
    }

    function _isAddLp(
        uint256 amount
    ) internal returns (bool isAdd, uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = uniswapV2Pair.getReserves();
        uint balance0 = currency.balanceOf(address(uniswapV2Pair));
        if (balance0 > _reserve0) {
            isAdd = true;
            uint amount0 = balance0 - _reserve0;
            uint amount1 = amount;

            uint _totalSupply = uniswapV2Pair.totalSupply();
            if (_totalSupply == 0) {
                liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
                isInitLp = true;
                lpstaking.init(address(this), totalAmountLpstaking);
            } else {
                liquidity = Math.min(
                    (amount0 * _totalSupply) / _reserve0,
                    (amount1 * _totalSupply) / _reserve1
                );

                if (!isInitLp) {
                    lpstaking.init(address(this), totalAmountLpstaking);
                    isInitLp = true;
                }
            }
            require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        }
    }

    function _isRemoveLp()
        internal
        view
        returns (bool isRemove, uint liquidity)
    {
        (uint r0, , ) = uniswapV2Pair.getReserves();
        uint bal0 = currency.balanceOf(address(uniswapV2Pair));
        if (bal0 < r0) {
            isRemove = true;
            uint lpAmount = uniswapV2Pair.totalSupply();
            liquidity =
                (r0 * DECIMAL_PRECISION * lpAmount) /
                bal0 /
                DECIMAL_PRECISION -
                lpAmount;
        }
    }

    function _transferSellFee(
        address sender,
        address recipient,
        uint256 feeAmount
    ) private {
        //
        super._transfer(sender, deadAddress, (feeAmount * burnFee) / txFee);
        //
        uint lpFee = (feeAmount * lpRewardFee) / txFee;
        super._transfer(sender, address(this), lpFee);
        _addFee(lpFee);
        //ref
        // super._transfer(sender, address(this), tmpAmount);
        address ref1;
        if (pairAddress == sender) {
            ref1 = inviter[recipient];
        } else {
            ref1 = inviter[sender];
        }

        if (ref1 != address(0)) {
            uint fee1 = (feeAmount * ref1Fee) / txFee;
            super._transfer(sender, ref1, fee1);

            address ref2 = inviter[ref1];
            if (ref2 != address(0)) {
                super._transfer(sender, ref2, fee1);
            }
        }
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function checkInviter(address from, address to) internal {
        if (inviter[to] != address(0) || from == to) {
            return;
        }

        if (
            balanceOf(to) == 0 &&
            !isContract(from) &&
            !isContract(to) &&
            msg.sender == tx.origin
        ) {
            inviter[to] = from;
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (!isSwapEnabled) {
            require(sender == owner() || recipient == owner(), "only owner");
            super._transfer(sender, recipient, amount);
            return;
        }

        if (isBlocks[sender] || isBlocks[recipient]) {
            revert("block address");
        }

        checkRemove();

        uint feeAmount = 0;
        bool flagSwapAddLp = true;
        if (ammPairs[recipient]) {
            (bool isAdd, uint liquidity) = _isAddLp(amount);
            if (isAdd) {
                // console.log(
                //     "addLp,account:%s, amount:%d",
                //     tx.origin,
                //     liquidity
                // );
                flagSwapAddLp = false;
                _stake(tx.origin, liquidity);
            }
            if (!_isExcludedFromFee[sender]) {
                //
                feeAmount = (amount * txFee) / feeDivisor;
                _transferSellFee(sender, recipient, feeAmount);
                amount -= feeAmount;
            }
        } else if (ammPairs[sender]) {
            (bool isRemove, uint liquidity) = _isRemoveLp();
            if (isRemove) {
                _unstake(tx.origin, liquidity);
            }

            if (!_isExcludedFromFee[recipient]) {
                //
                flagSwapAddLp = false;
                feeAmount = (amount * txFee) / feeDivisor;
                _transferSellFee(sender, recipient, feeAmount);
                amount -= feeAmount;
            }
        }

        checkInviter(sender, recipient);
        super._transfer(sender, recipient, amount);

        if (
            isInitLp &&
            sender != address(this) &&
            info.lastSendTime + info.period < block.timestamp
        ) {
            info.lastSendTime = block.timestamp;
            processLpReward();
        }
    }

    function _addFee(uint feeAmount) internal {
        uint feePerStaked;
        if (totalStaked > 0) {
            feePerStaked = (feeAmount * DECIMAL_PRECISION) / totalStaked;
        }
        feePerLpStaked += feePerStaked;
    }

    function excludeFromFee(address[] memory accounts) external onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = true;
        }
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setBlocks(address account, bool _isBlock) external onlyOwner {
        isBlocks[account] = _isBlock;
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function setSwapStatus(bool _enable) external onlyOwner {
        isSwapEnabled = _enable;
    }

    function setAmmPair(address _pair, bool _isPair) external onlyOwner {
        ammPairs[_pair] = _isPair;
    }

    function updateAccount(address account) public {
        uint reward = _updateState(account);
        if (reward > 0) {
            uint256 contractTokenBalance = balanceOf(address(this));
            // console.log(
            //     "updateReward: %s, reward:%s,  balance:%s",
            //     account,
            //     reward,
            //     contractTokenBalance
            // );
            if (contractTokenBalance >= reward) {
                super._transfer(address(this), account, reward);
            }
        }
    }

    function earned(address account) public view returns (uint256) {
        uint snapshot = lastSnapshots[account];
        uint tmp = (lps[account] * (feePerLpStaked - snapshot)) /
            DECIMAL_PRECISION;

        return rewards[account] + tmp;
    }

    function _updateState(address account) internal returns (uint256) {
        uint newReward = earned(account);
        //
        lastSnapshots[account] = feePerLpStaked;
        if (newReward >= info.minReward) {
            rewards[account] = 0;
            return newReward;
        } else {
            rewards[account] = newReward;
            return 0;
        }
    }

    function _stake(address account, uint liquidity) internal {
        EnumerableSet.AddressSet storage tokenHolder = info.tokenHolder;
        if (!tokenHolder.contains(account)) {
            // console.log("lp:%s", liquidity);
            // console.log("info.minLpAmount:%s", info.minLpAmount);
            if (liquidity < info.minLpAmount) {
                return;
            }
            tokenHolder.add(account);
        }

        updateAccount(account);
        //
        lps[account] += liquidity;
        totalStaked += liquidity;
        lpstaking.stake(account, liquidity);
    }

    function _unstake(address account, uint liquidity) internal {
        updateAccount(account);
        if (!info.tempRemoveList.contains(account)) {
            info.tempRemoveList.add(account);
        }
        //
        uint remaining = lps[account];
        if (remaining >= liquidity) {
            unchecked {
                lps[account] -= liquidity;
                totalStaked -= liquidity;
            }
            lpstaking.withdraw(account, liquidity);
        } else {
            unchecked {
                lps[account] -= remaining;
                totalStaked -= remaining;
            }
            lpstaking.exit(account);
        }
    }

    function processLpReward() private {
        uint256 shareholderCount = info.tokenHolder.length();

        if (shareholderCount == 0) return;

        uint256 iterations = 0;
        uint index = info.index;
        uint sendedCount = 0;
        uint sendCountLimit = info.sendCount;

        while (sendedCount < sendCountLimit && iterations < shareholderCount) {
            if (index >= shareholderCount) {
                index = 0;
            }

            address shareholder = info.tokenHolder.at(index);
            updateAccount(shareholder);
            lpstaking.getReward(shareholder);
            
            sendedCount++;
            iterations++;
            index++;
        }
        info.index = index;
    }

    function checkRemove() internal {
        uint count = info.tempRemoveList.length();
        if (count > 0) {
            for (uint i = count - 1; i >= 0; ) {
                address shareholder = info.tempRemoveList.at(i);
                uint remaining = info.pair.balanceOf(shareholder);
                info.tempRemoveList.remove(shareholder);
                if (remaining < info.minLpAmount) {
                    info.tokenHolder.remove(shareholder);
                    lpstaking.clear(shareholder, true);
                }
                if (i == 0) {
                    break;
                } else {
                    i--;
                }
            }
        }
    }

    function withdrawOtherTokens(
        address token,
        address to,
        uint256 value
    ) external onlyOwner {
        require(token != address(this), "other tokens");
        safeTransfer(token, to, value);
    }

   
}
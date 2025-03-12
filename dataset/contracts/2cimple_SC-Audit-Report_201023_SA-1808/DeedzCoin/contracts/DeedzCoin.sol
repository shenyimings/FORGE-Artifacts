// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
abstract contract Owned {
    address public immutable owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}

abstract contract SafeMath {
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a);
    }
}

abstract contract ERC1132 {
    /**
     * @dev Reasons why a user's tokens have been locked
     */
    mapping(address => bytes32[]) public lockReason;

    /**
     * @dev locked token structure
     */
    struct LockToken {
        uint256 amount;
        uint256 validity;
        bool claimed;
    }

    /**
     * @dev Holds number & validity of tokens locked for a given reason for
     *      a specified address
     */
    mapping(address => mapping(bytes32 => LockToken)) public locked;

    /**
     * @dev Records data of all the tokens Locked
     */
    event Locked(
        address indexed addressOf,
        bytes32 indexed reason,
        uint256 amount,
        uint256 validity
    );

    /**
     * @dev Records data of all the tokens unlocked
     */
    event Unlocked(
        address indexed addressOf,
        bytes32 indexed reason,
        uint256 amount
    );

    /**
     * @dev Locks a specified amount of tokens against an address,
     *      for a specified reason and time
     * @param reason The reason to lock tokens
     * @param amount Number of tokens to be locked
     * @param time Lock time in seconds
     */
    function lock(
        bytes32 reason,
        uint256 amount,
        uint256 time
    ) external virtual returns (bool);

    /**
     * @dev Returns tokens locked for a specified address for a
     *      specified reason
     *
     * @param addressOf The address whose tokens are locked
     * @param reason The reason to query the lock tokens for
     */
    function tokensLocked(
        address addressOf,
        bytes32 reason
    ) external view virtual returns (uint256);

    /**
     * @dev Returns tokens locked for a specified address for a
     *      specified reason at a specific time
     *
     * @param addressOf The address whose tokens are locked
     * @param reason The reason to query the lock tokens for
     * @param time The timestamp to query the lock tokens for
     */
    function tokensLockedAtTime(
        address addressOf,
        bytes32 reason,
        uint256 time
    ) external view virtual returns (uint256);

    /**
     * @dev Returns total tokens held by an address (locked + transferable)
     * @param addressOf The address to query the total balance of
     */
    function totalBalanceOf(
        address addressOf
    ) external view virtual returns (uint256);

    /**
     * @dev Extends lock for a specified reason and time
     * @param reason The reason to lock tokens
     * @param time Lock extension time in seconds
     */
    function extendLock(
        bytes32 reason,
        uint256 time
    ) external virtual returns (bool);

    /**
     * @dev Increase number of tokens locked for a specified reason
     * @param reason The reason to lock tokens
     * @param amount Number of tokens to be increased
     */
    function increaseLockAmount(
        bytes32 reason,
        uint256 amount
    ) external virtual returns (bool);

    /**
     * @dev Returns unlockable tokens for a specified address for a specified reason
     * @param addressOf The address to query the the unlockable token count of
     * @param reason The reason to query the unlockable tokens for
     */
    function tokensUnlockable(
        address addressOf,
        bytes32 reason
    ) external view virtual returns (uint256);

    /**
     * @dev Unlocks the unlockable tokens of a specified address
     * @param addressOf Address of user, claiming back unlockable tokens
     */
    function unlock(address addressOf) external virtual returns (uint256);

    /**
     * @dev Gets the unlockable tokens of a specified address
     * @param addressOf The address to query the the unlockable token count of
     */
    function getUnlockableTokens(
        address addressOf
    ) external view virtual returns (uint256);
}

abstract contract SupplierRole is Owned {
    address private _supplier;

    function setSupplier(address supplierAddress) internal {
        _supplier = supplierAddress;
    }

    function supplier() public view virtual returns (address) {
        return _supplier;
    }

    event SupplierRoleTransferred(
        address indexed previousSupplier,
        address indexed newSupplier
    );

    error InvalidSupplier(address owner);

    modifier onlySupplier() {
        require(msg.sender == _supplier);
        _;
    }
}

contract DeedzCoin is ERC1132, ERC20, SafeMath, SupplierRole {
    string internal constant ALREADY_LOCKED = "Tokens already locked";
    string internal constant NOT_LOCKED = "No tokens locked";
    string internal constant AMOUNT_ZERO = "Amount can not be 0";
    uint256 internal constant TOTAL_SUPPLY =
        500_000_000_000_000_000_000_000_000;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    /**
     * @dev constructor to mint initial tokens
     * Shall update to _mint once openzepplin updates their npm package.
     */
    constructor(address supplierAddress) ERC20("DEEDZ COIN", "DEEDZ") {
        setSupplier(supplierAddress);
        balances[supplier()] = TOTAL_SUPPLY; //MEW address here
        //Transfer(address(0), 0x367edD7806d157F3881c0A884E7634A4e100Aea2, _totalSupply);//MEW address here
        _mint(supplier(), TOTAL_SUPPLY); //MEW address here
    }

    function _transferSupplierRole(address newSupplier) internal virtual {
        address oldSupplier = supplier();
        setSupplier(newSupplier);
        emit SupplierRoleTransferred(oldSupplier, supplier());
        _transfer(oldSupplier, newSupplier, balanceOf(oldSupplier));
        balances[supplier()] = safeAdd(
            balanceOf(oldSupplier),
            balances[supplier()]
        );
        balances[oldSupplier] = 0;
    }

    function transferSupplierRole(
        address newSupplier
    ) external virtual onlyOwner {
        if (newSupplier == address(0)) {
            revert InvalidSupplier(address(0));
        }
        _transferSupplierRole(newSupplier);
    }

    /**
     * @dev Locks a specified amount of tokens against an address,
     *      for a specified reason and time
     * @param reason The reason to lock tokens
     * @param amount Number of tokens to be locked
     * @param time Lock time in seconds
     */
    function lock(
        bytes32 reason,
        uint256 amount,
        uint256 time
    ) external virtual override returns (bool) {
        uint256 validUntil = safeAdd(block.timestamp, time); //solhint-disable-line

        // If tokens are already locked, then functions extendLock or
        // increaseLockAmount should be used to make any changes
        require(tokensLocked(msg.sender, reason) == 0, ALREADY_LOCKED);
        require(amount != 0, AMOUNT_ZERO);

        if (locked[msg.sender][reason].amount == 0)
            lockReason[msg.sender].push(reason);

        transfer(address(this), amount);

        locked[msg.sender][reason] = LockToken(amount, validUntil, false);

        emit Locked(msg.sender, reason, amount, validUntil);
        return true;
    }

    /**
     * @dev Transfers and Locks a specified amount of tokens,
     *      for a specified reason and time
     * @param to adress to which tokens are to be transfered
     * @param reason The reason to lock tokens
     * @param amount Number of tokens to be transfered and locked
     * @param time Lock time in seconds
     */
    function transferWithLock(
        address to,
        bytes32 reason,
        uint256 amount,
        uint256 time
    ) external onlySupplier returns (bool) {
        uint256 validUntil = safeAdd(block.timestamp, time); //solhint-disable-line
        require(tokensLocked(to, reason) == 0, ALREADY_LOCKED);
        require(amount != 0, AMOUNT_ZERO);

        if (locked[to][reason].amount == 0) lockReason[to].push(reason);

        transfer(address(this), amount);
        balances[supplier()] = balances[supplier()] - amount;
        locked[to][reason] = LockToken(amount, validUntil, false);

        emit Locked(to, reason, amount, validUntil);
        return true;
    }

    /**
     * @dev Transfers and Locks a specified amount of tokens for a specified reason and until a specific time.
     *      The lock time is given as an actual timestamp.
     * @param to The address to which tokens are to be transferred
     * @param reason The reason for locking tokens
     * @param amount The number of tokens to be transferred and locked
     * @param time The lock time as an actual timestamp
     * @return A boolean indicating whether the transfer and lock operation was successful
     */
    function transferWithLockActualTime(
        address to,
        bytes32 reason,
        uint256 amount,
        uint256 time
    ) external onlySupplier returns (bool) {
        require(
            time > block.timestamp,
            "Invalid time: lock time must be in the future"
        );
        uint256 validUntil = time;
        require(
            tokensLocked(to, reason) == 0,
            "Tokens already locked for the specified reason"
        );
        require(
            amount != 0,
            "Invalid amount: must transfer and lock a non-zero amount of tokens"
        );

        if (locked[to][reason].amount == 0) {
            lockReason[to].push(reason);
        }

        transfer(address(this), amount);

        locked[to][reason] = LockToken(amount, validUntil, false);

        emit Locked(to, reason, amount, validUntil);
        return true;
    }

    /**
     * @dev Returns tokens locked for a specified address for a
     *      specified reason
     *
     * @param addressOf The address whose tokens are locked
     * @param reason The reason to query the lock tokens for
     */
    function tokensLocked(
        address addressOf,
        bytes32 reason
    ) public view virtual override returns (uint256 amount) {
        if (!locked[addressOf][reason].claimed)
            amount = locked[addressOf][reason].amount;
    }

    /**
     * @dev Returns tokens locked for a specified address for a
     *      specified reason at a specific time
     *
     * @param addressOf The address whose tokens are locked
     * @param reason The reason to query the lock tokens for
     * @param time The timestamp to query the lock tokens for
     */
    function tokensLockedAtTime(
        address addressOf,
        bytes32 reason,
        uint256 time
    ) external view virtual override returns (uint256 amount) {
        if (locked[addressOf][reason].validity > time)
            amount = locked[addressOf][reason].amount;
    }

    /**
     * @dev Returns total tokens held by an address (locked + transferable)
     * @param addressOf The address to query the total balance of
     */
    function totalBalanceOf(
        address addressOf
    ) external view virtual override returns (uint256 amount) {
        amount = balanceOf(addressOf);

        for (uint256 i = 0; i < lockReason[addressOf].length; i++) {
            amount = safeAdd(
                amount,
                tokensLocked(addressOf, lockReason[addressOf][i])
            );
        }
    }

    /**
     * @dev Extends lock for a specified reason and time
     * @param reason The reason to lock tokens
     * @param time Lock extension time in seconds
     */
    function extendLock(
        bytes32 reason,
        uint256 time
    ) external virtual override returns (bool) {
        require(tokensLocked(msg.sender, reason) > 0, NOT_LOCKED);

        locked[msg.sender][reason].validity = safeAdd(
            locked[msg.sender][reason].validity,
            time
        );

        emit Locked(
            msg.sender,
            reason,
            locked[msg.sender][reason].amount,
            locked[msg.sender][reason].validity
        );
        return true;
    }

    /**
     * @dev Increase number of tokens locked for a specified reason
     * @param reason The reason to lock tokens
     * @param amount Number of tokens to be increased
     */
    function increaseLockAmount(
        bytes32 reason,
        uint256 amount
    ) external virtual override returns (bool) {
        require(tokensLocked(msg.sender, reason) > 0, NOT_LOCKED);
        transfer(address(this), amount);

        locked[msg.sender][reason].amount = safeAdd(
            amount,
            locked[msg.sender][reason].amount
        );

        emit Locked(
            msg.sender,
            reason,
            locked[msg.sender][reason].amount,
            locked[msg.sender][reason].validity
        );
        return true;
    }

    /**
     * @dev Returns unlockable tokens for a specified address for a specified reason
     * @param addressOf The address to query the the unlockable token count of
     * @param reason The reason to query the unlockable tokens for
     */
    function tokensUnlockable(
        address addressOf,
        bytes32 reason
    ) public view virtual override returns (uint256 amount) {
        if (
            locked[addressOf][reason].validity <= block.timestamp &&
            !locked[addressOf][reason].claimed
        )
            //solhint-disable-line
            amount = locked[addressOf][reason].amount;
    }

    /**
     * @dev Unlocks the unlockable tokens of a specified address
     * @param addressOf Address of user, claiming back unlockable tokens
     */
    function unlock(
        address addressOf
    ) external virtual override returns (uint256 unlockableTokens) {
        uint256 lockedTokens;

        for (uint256 i = 0; i < lockReason[addressOf].length; i++) {
            lockedTokens = tokensUnlockable(
                addressOf,
                lockReason[addressOf][i]
            );
            if (lockedTokens > 0) {
                unlockableTokens = safeAdd(lockedTokens, unlockableTokens);
                locked[addressOf][lockReason[addressOf][i]].claimed = true;
                emit Unlocked(
                    addressOf,
                    lockReason[addressOf][i],
                    lockedTokens
                );
            }
        }

        if (unlockableTokens > 0) transfer(addressOf, unlockableTokens);
    }

    /**
     * @dev Gets the unlockable tokens of a specified address
     * @param addressOf The address to query the the unlockable token count of
     */
    function getUnlockableTokens(
        address addressOf
    ) external view virtual override returns (uint256 unlockableTokens) {
        for (uint256 i = 0; i < lockReason[addressOf].length; i++) {
            unlockableTokens = safeAdd(
                unlockableTokens,
                tokensUnlockable(addressOf, lockReason[addressOf][i])
            );
        }
    }
}

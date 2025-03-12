// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@amxx/hre/contracts/ENSReverseRegistration.sol";
import "@amxx/hre/contracts/tokens/utils/Splitters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "../amm/UniswapV2Router02.sol";
import "../amm/libraries/UniswapV2Math.sol";
import "../../tokens/extensions/IERC1363.sol";
// import "../../utils/Timers.sol";

/// @custom:security-contact security@p00ls.com
contract Locking is AccessControl, Multicall, IERC1363Receiver, IERC1363Spender {
    using Distributions for Distributions.Uint256;
    using Splitters     for Splitters.Splitter;
    using Timers        for uint64;
    using Timers        for Timers.Timestamp;

    bytes32 public  constant LOCKING_MANAGER_ROLE = keccak256("LOCKING_MANAGER_ROLE");
    uint64  public  constant DELAY                =      30 days;
    uint64  public  constant MIN_DURATION         =  3 * 30 days;
    uint64  public  constant MAX_DURATION         = 36 * 30 days;
    uint256 private constant EXTRA_FACTOR_BASE    = 1e18; // sqrt(1e36) = 1e18 → double for 1 extra

    UniswapV2Router02 public immutable router;
    IERC20            public immutable p00ls;

    /*****************************************************************************************************************
     *                                                    Storage                                                    *
     *****************************************************************************************************************/
    struct Vault {
        Timers.Timestamp delay;
        uint256          value;
        uint256          extra;
    }

    struct Lock {
        Timers.Timestamp          delay;
        Splitters.Splitter        splitter;
        uint256                   rate;
        mapping(address => Vault) vaults;
    }

    mapping(IERC20 => Lock) private _locks;

    /*****************************************************************************************************************
     *                                                    Events                                                     *
     *****************************************************************************************************************/
    event LockSetup(IERC20 indexed token);
    event VaultSetup(IERC20 indexed token, address indexed account, uint64 expiration);
    event Deposit(IERC20 indexed token, address indexed account, uint256 amount, uint256 extra, uint256 newWeight);
    event Withdraw(IERC20 indexed token, address indexed account, address to, uint256 reward);

    /*****************************************************************************************************************
     *                                                   Modifiers                                                   *
     *****************************************************************************************************************/
    modifier onlyUnsetLock(IERC20 token) {
        require(_locks[token].delay.isUnset(), "Locking already configured");
        _;
    }

    modifier onlyActiveLock(IERC20 token) {
        require(_locks[token].delay.isPending(), "Locking not currently authorized for this token");
        _;
    }

    modifier onlyExpiredLock(IERC20 token) {
        require(_locks[token].delay.isExpired(), "Locking is not closed for this token");
        _;
    }

    modifier onlyUnsetVault(IERC20 token, address account) {
        require(_locks[token].vaults[account].delay.isUnset(), "Vault already configured");
        _;
    }

    modifier onlyActiveVault(IERC20 token, address account) {
        require(_locks[token].vaults[account].delay.isPending(), "Vault doesn't accept deposit");
        _;
    }

    modifier onlyExpiredVault(IERC20 token, address account) {
        require(_locks[token].vaults[account].delay.isExpired(), "Vault is locked");
        _;
    }

    /*****************************************************************************************************************
     *                                                   Functions                                                   *
     *****************************************************************************************************************/
    constructor(address _admin, UniswapV2Router02 _router, IERC20 _p00ls)
    {
        _setupRole(DEFAULT_ADMIN_ROLE,   _admin);
        _setupRole(LOCKING_MANAGER_ROLE, _admin);
        router   = _router;
        p00ls    = _p00ls;
    }

    function lockDetails(IERC20 token)
        external
        view
        returns (uint64 start, uint256 rate, uint256 reward, uint256 totalWeight)
    {
        Lock storage lock = _locks[token];
        return (
            // lock.delay.toUint64(),
            lock.delay.getDeadline(),
            lock.rate,
            SafeCast.toUint256(SafeCast.toInt256(lock.splitter._bounty) + lock.splitter._released._total),
            lock.splitter.totalSupply()
        );
    }

    function vaultDetails(IERC20 token, address account)
        external
        view
        returns (uint64 maturity, uint256 value, uint256 extra, uint256 weight)
    {
        Lock  storage lock  = _locks[token];
        Vault storage vault = lock.vaults[account];
        return (
            // vault.delay.toUint64(),
            vault.delay.getDeadline(),
            vault.value,
            vault.extra,
            lock.splitter.balanceOf(account)
        );
    }

    function lockSetup(IERC20 token)
        external
        onlyUnsetLock(token)
        onlyRole(LOCKING_MANAGER_ROLE)
    {
        Lock storage lock = _locks[token];

        address[] memory path = new address[](2);
        path[0] = address(p00ls);
        path[1] = address(token);

        // lock.delay = uint64(block.timestamp + DELAY).toTimestamp();
        lock.delay.setDeadline(uint64(block.timestamp + DELAY));
        lock.splitter.reward(token.balanceOf(address(this)));
        lock.rate = router.getAmountsOut(1e18, path)[1]; // this is subject to pricefeed manipulation if executed in refreshWeight

        emit LockSetup(token);
    }

    function vaultSetup(IERC20 token, uint64 duration)
        external
        onlyActiveLock(token)
        onlyUnsetVault(token, msg.sender)
    {
        require(duration >= MIN_DURATION);
        require(duration <= MAX_DURATION);

        Lock  storage lock  = _locks[token];
        Vault storage vault = lock.vaults[msg.sender];

        // uint64 expiration = lock.delay.toUint64() + duration;
        // vault.delay = expiration.toTimestamp();
        uint64 expiration = lock.delay.getDeadline() + duration;
        vault.delay.setDeadline(expiration);

        emit VaultSetup(token, msg.sender, expiration);
    }

    function onTransferReceived(address, address from, uint256 value, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        (IERC20 token, address to) = abi.decode(data, (IERC20, address));

        if (msg.sender == address(token)) {
            _deposit(token, from, value, 0, to, true);
        } else if (msg.sender == address(p00ls)) {
            _deposit(token, from, 0, value, to, true);
        } else {
            revert('invalid data');
        }

        return this.onTransferReceived.selector;
    }

    function onApprovalReceived(address from, uint256 value, bytes memory data)
        external
        override
        returns (bytes4)
    {
        (IERC20 token, address to) = abi.decode(data, (IERC20, address));

        if (msg.sender == address(token)) {
            _deposit(token, from, value, 0, to, false);
        } else if (msg.sender == address(p00ls)) {
            _deposit(token, from, 0, value, to, false);
        } else {
            revert('invalid data');
        }

        return this.onApprovalReceived.selector;
    }

    function deposit(IERC20 token, uint256 amount, uint256 extra)
        external
    {
        _deposit(token, msg.sender, amount, extra, msg.sender, false);
    }

    function depositFor(IERC20 token, uint256 amount, uint256 extra, address to)
        external
    {
        _deposit(token, msg.sender, amount, extra, to, false);
    }

    function withdraw(IERC20 token)
        external
    {
        _withdraw(token, msg.sender, msg.sender);
    }

    function withdrawTo(IERC20 token, address to)
        external
    {
        _withdraw(token, msg.sender, to);
    }

    function _deposit(IERC20 token, address from, uint256 amount, uint256 extra, address to, bool erc1363received)
        internal
        onlyActiveLock(token)
        onlyActiveVault(token, to)
    {
        Lock  storage lock  = _locks[token];
        Vault storage vault = lock.vaults[to];

        if (amount > 0) {
            if (!erc1363received) SafeERC20.safeTransferFrom(token, from, address(this), amount);
            vault.value += amount;
        }

        if (extra > 0) {
            if (!erc1363received) SafeERC20.safeTransferFrom(p00ls, from, address(this), extra);
            vault.extra += extra;
        }

        uint256 weight = estimateWeight(
            token,
            // vault.delay.toUint64() - lock.delay.toUint64(),
            vault.delay.getDeadline() - lock.delay.getDeadline(),
            vault.value,
            vault.extra
        );
        lock.splitter._shares._balances.set(to, weight);

        emit Deposit(token, to, amount, extra, weight);
    }

    function _withdraw(IERC20 token, address from, address to)
        internal
        onlyExpiredVault(token, from)
    {
        Lock  storage lock  = _locks[token];
        Vault storage vault = lock.vaults[from];

        uint256 reward = lock.splitter.release(from);
        SafeERC20.safeTransfer(token, to, vault.value + reward);
        SafeERC20.safeTransfer(p00ls, to, vault.extra);

        delete lock.vaults[from];

        emit Withdraw(token, from, to, reward);
    }

    function estimateWeight(IERC20 token, uint256 duration, uint256 value, uint256 extra)
        public
        view
        returns (uint256)
    {
        uint256 rate        = _locks[token].rate;
        uint256 factor      = duration * UniswapV2Math.sqrt(duration);
        uint256 extrafactor = value == 0 ? 0 : UniswapV2Math.sqrt(Math.mulDiv(
            1e54,
            rate * extra, // rate is * 1e18
            value
        )); // = 1e18 * sqrt(extravalue / value)

        return Math.mulDiv(
            value * factor,                  // base weight
            EXTRA_FACTOR_BASE + extrafactor, // extra factor
            EXTRA_FACTOR_BASE                // renormalization
        );
    }

    function setName(address ensregistry, string calldata ensname)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ENSReverseRegistration.setName(ensregistry, ensname);
    }
}

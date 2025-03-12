// SPDX-License-Identifier: GPL-2.0-or-later
// TokenX Contracts v1.0.0 (contracts/InvestmentTokenI.sol)
pragma solidity 0.8.14;

import "../extensions/ERC20AllowListableProxy.sol";
import "../extensions/EmergencyWithdrawable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @dev {ERC20} token, including:
 *
 *  - Manual minting initial supply.
 *  - Ability for holders to burn (destroy) their tokens.
 *  - The owner is allowed to stop all token transfers.
 *  - The owner is allowed to add a specific address to allowlist for transfer and receive token.
 *
 * This contract uses {Ownable} to include access control capabilities.
 * This contract uses {Pausable} to include pause capabilities.
 * This contract uses {ERC20Burnable} to include burn capabilities.
 * This contract uses {ERC20AllowListableProxy} to include transfer and receive control capabilities.
 * This contract uses {EmergencyWithdrawable} to include emergency withdraw capabilities.
 */
contract InvestmentTokenI is Ownable, Pausable, ERC20Burnable, ERC20AllowListableProxy, EmergencyWithdrawable {
    bool private _initializedSupply;

    /**
     * @dev Emitted when supply has initialized.
     */
    event InitializedSupply(uint256 amount);

    constructor(string memory name_, string memory symbol_, address allowlistRegistry_) ERC20(name_, symbol_) {
        _setAllowlistRegistry(allowlistRegistry_);
    }

    /**
     * @dev Throws if sender or receiver are not allowlisted account.
     */
    modifier onlyAllowlist(address sender, address receiver) {
        address _msgSender = _msgSender();
        if (_msgSender != owner()) {
            bool _isAllowlist = isAllowlist(sender) && isAllowlist(receiver) && isAllowlist(_msgSender);
            require(_isAllowlist, "InvestmentTokenI: account are not allowlisted");
        }
        _;
    }

    /**
     * @dev Set the `allowlistRegistry` contract address.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function setAllowlistRegistry(address allowlistRegistry) external virtual onlyOwner {
        _setAllowlistRegistry(allowlistRegistry);
    }

    /**
     * @dev Returns a initialized supply status.
     */
    function initializedSupply() public view returns (bool) {
        return _initializedSupply;
    }

    /**
     * @dev Initialize supply.
     *
     * Emits an {InitializedSupply} event indicating minted supply.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function initializeSupply(uint256 amount) external virtual onlyOwner {
        require(!_initializedSupply, "InvestmentTokenI: supply has initialized");

        _mint(msg.sender, amount);

        _initializedSupply = true;

        emit InitializedSupply(amount);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     * - the caller and `to` must be allowlisted account.
     * - The contract must not be paused.
     */
    function transfer(address to, uint256 amount) public virtual override onlyAllowlist(msg.sender, to) whenNotPaused returns (bool) {
        return super.transfer(to, amount);
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
     * - the caller and `spender` must be allowlisted account.
     * - The contract must not be paused.
     */
    function approve(address spender, uint256 amount) public virtual override onlyAllowlist(msg.sender, spender) whenNotPaused returns (bool) {
        return super.approve(spender, amount);
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
     * - the caller and `spender` must be allowlisted account.
     * - The contract must not be paused.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override onlyAllowlist(from, to) whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
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
     * - the caller and `spender` must be allowlisted account.
     * - The contract must not be paused.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual override onlyAllowlist(msg.sender, spender) whenNotPaused returns (bool) {
        return super.increaseAllowance(spender, addedValue);
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
     * - the caller and `spender` must be allowlisted account.
     * - The contract must not be paused.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override onlyAllowlist(msg.sender, spender) whenNotPaused returns (bool) {
        return super.decreaseAllowance(spender, subtractedValue);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     *
     * Requirements:
     *
     * - the caller must be allowlisted account.
     * - The contract must not be paused.
     */
    function burn(uint256 amount) public virtual override onlyAllowlist(msg.sender, msg.sender) whenNotPaused {
        super.burn(amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     * - the caller and `account` must be allowlisted account.
     * - The contract must not be paused.
     */
    function burnFrom(address account, uint256 amount) public virtual override onlyAllowlist(msg.sender, account) whenNotPaused {
        super.burnFrom(account, amount);
    }

    /**
     * @dev Force transfer by the owner.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - `to` cannot be the zero address.
     * - `to` must be allowlisted account.
     * - the caller must be owner.
     * - The contract must not be paused.
     */
    function adminTransfer(address from, address to, uint256 amount) external virtual onlyOwner {
        _transfer(from, to, amount);
    }

    /**
     * @dev Force burn by the owner.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have a balance of at least `amount`.
     * - the caller must be owner.
     */
     function adminBurn(address account, uint256 amount) external virtual onlyOwner {
         _burn(account, amount);
     }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Withdraw ERC20 `token` from (this) contract to owner.
     *
     * See {EmergencyWithdrawable-_emergencyWithdrawToken}.
     *
     * Requirements:
     *
     * - the caller must be owner.
     */
    function emergencyWithdrawToken(address token) external onlyOwner {
        _emergencyWithdrawToken(owner(), token);
    }
}

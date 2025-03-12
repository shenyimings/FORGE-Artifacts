// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.19;

import "./interfaces/IHYDT.sol";

import "./utils/AccessControl.sol";
import "./utils/ERC20Permit.sol";

contract HYDT is IHYDT, AccessControl, ERC20Permit {

    /* ========== STATE VARIABLES ========== */

    bytes32 public constant CALLER_ROLE = keccak256(abi.encodePacked("Caller"));

    /// @dev Initialization variables.
    address private immutable _initializer;
    bool private _isInitialized;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Minting inital supply at contract creation.
     * @param treasury_ The address of the `Treasury` wallet.
     */
    constructor(address treasury_)
        ERC20("High Yield Dollar Stable Token", "HYDT")
        ERC20Permit("High Yield Dollar Stable Token")
    {
        require(treasury_ != address(0), "HYDT: invalid Treasury address");

        /// @dev 10,000 Tokens minted at contract creation
        _mint(treasury_, 10000 * 1e18);

        _initializer = _msgSender();
    }

    /* ========== INITIALIZE ========== */

    /**
     * @notice Initializes external dependencies and state variables.
     * @dev This function can only be called once.
     * @param control_ The address of the `Control` contract.
     * @param earn_ The address of the `Earn` contract.
     */
    function initialize(address control_, address earn_) external {
        require(_msgSender() == _initializer, "HYDT: caller is not the initializer");
        require(!_isInitialized, "HYDT: already initialized");

        require(control_ != address(0), "HYDT: invalid Control address");
        require(earn_ != address(0), "HYDT: invalid Earn address");
        _grantRole(CALLER_ROLE, control_);
        _grantRole(CALLER_ROLE, earn_);
        /// @dev Renounce Role after setup is complete.
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _isInitialized = true;
    }

    /* ========== FUNCTIONS ========== */

    /**
     * @dev See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `Caller` role.
     */
    function mint(address to, uint256 amount) external override onlyRole(CALLER_ROLE) returns (bool) {
        _mint(to, amount);
        return true;
    }

    /**
     * @dev See {ERC20-_burn}.
     */
    function burn(uint256 amount) external override returns (bool) {
        address owner = _msgSender();
        _burn(owner, amount);
        return true;
    }

    /**
     * @dev Destorys `amount` tokens from `from` using the allowance
     * mechanism. `amount` is then deducted from the caller's allowance.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least `amount`.
     */
    function burnFrom(address from, uint256 amount) external override onlyRole(CALLER_ROLE) returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _burn(from, amount);
        return true;
    }
}
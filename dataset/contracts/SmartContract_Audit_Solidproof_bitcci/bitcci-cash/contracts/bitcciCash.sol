 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
/**
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract bitcciCash is Context, AccessControlEnumerable, ERC20Burnable, ERC20Pausable{
    uint256 immutable private _cap;
    uint8 immutable private _decimals;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC20-constructor}.
     */
     /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor(string memory bitcciCashName, string memory bitcciCashSymbol, uint8 decimals_,uint256 cap_) ERC20(bitcciCashName, bitcciCashSymbol) {
         require(cap_ > 0, "ERC20Capped: cap is 0");
        _cap = cap_;
        _decimals = decimals_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

     /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function addBlackListed(address account) public {
        grantRole(BLACKLISTED_ROLE, account);
    }

    function removeBlackListed(address account) public {
        revokeRole(BLACKLISTED_ROLE, account);
    }

    function renounceRole(bytes32 role, address account)
        public
        virtual
        override
    {
        require(role != BLACKLISTED_ROLE, "bitcciCash: cannot renounce blacklisted role");

        super.renounceRole(role, account);
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public virtual {
        require(ERC20.totalSupply() + amount <= cap(), "bitcciCash: cap exceeded");
        require(hasRole(MINTER_ROLE, _msgSender()), "bitcciCash: must have minter role to mint");
        _mint(to, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "bitcciCash: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "bitcciCash: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20, ERC20Pausable) {
         require(!(hasRole(BLACKLISTED_ROLE, msg.sender)), "bitcciCash: sender is Blacklisted");
         require(!(hasRole(BLACKLISTED_ROLE, to)),"bitcciCash: receiver is Blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }
}

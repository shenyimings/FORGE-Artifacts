// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Template is AccessControl, Pausable, ERC20Burnable {
    using SafeERC20 for IERC20;

    uint8 private _decimals;
    mapping(address => bool) internal blackListAccounts;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    

    /**
     * @dev Emitted when the account is added to blacklist.
     */
    event BlackListAccount(address indexed account);

    /**
     * @dev Emitted when the account is removed from blacklist.
     */
    event UnblackListAccount(address indexed account);


    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `OPERATOR_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC20-constructor}.
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_, address owner_) ERC20(name_, symbol_) {
        _setupRole(DEFAULT_ADMIN_ROLE, owner_);
        _setupRole(MINTER_ROLE, owner_);   
        _setupRole(OPERATOR_ROLE, owner_); 

        _setupDecimals(decimals_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
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
    function mint(address to, uint256 amount) public virtual onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `DEFAULT_ADMIN_ROLE`.
     */
    function pause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `DEFAULT_ADMIN_ROLE`.
     */
    function unpause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function blackListAccount(address account) public onlyRole(OPERATOR_ROLE) {
        blackListAccounts[account] = true;
        emit BlackListAccount(account);
    }

    function unblackListAccount(address account) public onlyRole(OPERATOR_ROLE) {
        blackListAccounts[account] = false;
        emit UnblackListAccount(account);
    }

    function blackListed(address account) public view returns (bool) {
        return blackListAccounts[account];
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        
        require(!paused(), "_beforeTokenTransfer: token transfer while paused");
        require(!blackListed(from), "_beforeTokenTransfer: sender is blacklisted");
        require(!blackListed(to), "_beforeTokenTransfer: recipient is blacklisted");
    }

    function withdrawERC20(address tokenAddress, address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(to, balance);
    }

    function withdrawERC721(address tokenAddress, address to, uint256 tokenId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC721(tokenAddress).transferFrom(address(this), to, tokenId);
    }
}

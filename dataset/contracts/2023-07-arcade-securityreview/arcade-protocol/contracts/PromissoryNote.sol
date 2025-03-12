// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/IPromissoryNote.sol";
import "./interfaces/ILoanCore.sol";
import "./interfaces/INFTDescriptor.sol";
import "./nft/ERC721Permit.sol";

import {
    PN_ZeroAddress,
    PN_MintingRole,
    PN_BurningRole
} from "./errors/Lending.sol";

/**
 * @title PromissoryNote
 * @author Non-Fungible Technologies, Inc.
 *
 * Built off Openzeppelin's ERC721PresetMinterPauserAutoId. Used for
 * representing rights and obligations in the context of a loan - the
 * right to claim collateral for lenders (instantiated as LenderNote),
 * and the right to recover collateral upon repayment for borrowers
 * (instantiated as BorrowerNote).
 *
 * @dev {ERC721} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - token ID and URI autogeneration
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract PromissoryNote is
    Context,
    AccessControl,
    ERC721Enumerable,
    ERC721Permit,
    IPromissoryNote
{
    using Counters for Counters.Counter;


    // ============================================ STATE ==============================================

    // =================== Constants =====================

    /// @dev After loanCore initialization, admin role is permanently revoked.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant MINT_BURN_ROLE = keccak256("MINT/BURN");
    bytes32 public constant RESOURCE_MANAGER_ROLE = keccak256("RESOURCE_MANAGER");

    // ================= State Variables ==================

    /// @dev Contract for returning tokenURI resources.
    INFTDescriptor public descriptor;

    Counters.Counter private _tokenIdTracker;

    // ========================================= CONSTRUCTOR ===========================================

    /**
     * @dev Creates the promissory note contract, granting minter, burner
     *      and pauser roles to the specified owner address (which in practice
     *      will be LoanCore).
     *
     * @param name                  The name of the token (see ERC721).
     * @param symbol                The symbol of the token (see ERC721).
     * @param _descriptor           The resource descriptor contract.
     */
    constructor(
        string memory name,
        string memory symbol,
        address _descriptor
    ) ERC721(name, symbol) ERC721Permit(name) {
        if (_descriptor == address(0)) revert PN_ZeroAddress();

        descriptor = INFTDescriptor(_descriptor);

        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(RESOURCE_MANAGER_ROLE, msg.sender);

        // Allow admin to set mint/burn role, which they will do
        // during initialize. After initialize, admin role is
        // permanently revoked, so mint/burn role becomes immutable
        // and initialize cannot be called again.
        // Do not set role admin for admin role.
        _setRoleAdmin(MINT_BURN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(RESOURCE_MANAGER_ROLE, RESOURCE_MANAGER_ROLE);

        // We don't want token IDs of 0
        _tokenIdTracker.increment();
    }

    /**
     * @notice Grants mint/burn access to the specified address, which should be an
     *         instance of LoanCore. Once role is set, it is immutable,
     *         and cannot be set again.
     *
     * @param loanCore              The address of the admin.
     */
    function initialize(address loanCore) external onlyRole(ADMIN_ROLE) {
        // Grant mint/burn role to loanCore
        _setupRole(MINT_BURN_ROLE, loanCore);

        // Revoke admin role from msg.sender. Since there is no ROLE_ADMIN,
        // nobody can ever get ADMIN_ROLE again.
        renounceRole(ADMIN_ROLE, msg.sender);
    }

    // ======================================= TOKEN OPERATIONS =========================================

    /**
     * @notice Create a new token and assign it to a specified owner. The token ID
     *         should match the loan ID, and can only be called by the minter. Also
     *         updates the mapping to lookup loan IDs by note IDs.
     *
     * @dev See {ERC721-_mint}.
     *
     * @param to                    The owner of the minted token.
     * @param loanId                The ID of the token to mint, should match a loan.
     *
     * @return tokenId              The newly minted token ID.
     */
    function mint(address to, uint256 loanId) external override returns (uint256) {
        if (!hasRole(MINT_BURN_ROLE, msg.sender)) revert PN_MintingRole(msg.sender);
        _mint(to, loanId);

        return loanId;
    }

    /**
     * @notice Burn a token assigned to a specified owner. The token ID should match a loan ID,
     *         and can only be called by a burner - in practice LoanCore, which burns notes when
     *         a loan ends.
     *
     * @dev See {ERC721-_burn}.
     *
     * @param tokenId               The ID of the token to burn, should match a loan.
     */
    function burn(uint256 tokenId) external override {
        if (!hasRole(MINT_BURN_ROLE, msg.sender)) revert PN_BurningRole(msg.sender);
        _burn(tokenId);
    }

    // ===================================== ERC721 UTILITIES ============================================

    /**
     * @notice Getter of specific URI for an ERC721 token ID.
     *
     * @param tokenId               The ID of the token to get the URI for.
     *
     * @return                      The token ID's URI.
     */
    function tokenURI(uint256 tokenId) public view override(INFTWithDescriptor, ERC721) returns (string memory) {
        _exists(tokenId);

        return descriptor.tokenURI(address(this), tokenId);
    }

    /**
     * @notice Changes the descriptor contract for reporting tokenURI
     *         resources. Can only be called by a resource manager.
     *
     * @param _descriptor           The new descriptor contract.
     */
    function setDescriptor(address _descriptor) external onlyRole(RESOURCE_MANAGER_ROLE) {
        if (_descriptor == address(0)) revert PN_ZeroAddress();

        descriptor = INFTDescriptor(_descriptor);

        emit SetDescriptor(msg.sender, _descriptor);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Hook that is called before any token transfer.
     *      This notifies the promissory note about the ownership transfer.
     *
     * @dev Does not let tokens be transferred when contract is paused.
     *
     * @param from                  The previous owner of the token.
     * @param to                    The owner of the token after transfer.
     * @param tokenId               The token ID.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}

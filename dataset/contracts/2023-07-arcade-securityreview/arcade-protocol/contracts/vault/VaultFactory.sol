// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/IVaultFactory.sol";
import "../interfaces/IAssetVault.sol";
import "../interfaces/IFeeController.sol";
import "../interfaces/INFTDescriptor.sol";
import "../nft/ERC721Permit.sol";

import {
    VF_ZeroAddress,
    VF_TokenIdOutOfBounds,
    VF_NoTransferWithdrawEnabled,
    VF_InsufficientMintFee
} from "../errors/Vault.sol";

/**
 * @title VaultFactory
 * @author Non-Fungible Technologies, Inc.
 *
 * The Vault factory is used for creating and registering AssetVault contracts, which
 * is also an ERC721 that maps "ownership" of its tokens to ownership of created
 * vault assets (see OwnableERC721).
 *
 * Each Asset Vault is created via "intializeBundle", and uses a specified template
 * and the OpenZeppelin Clones library to cheaply deploy a new clone pointing to logic
 * in the template. The address the newly created vault is deployed to is converted
 * into a uint256, which ends up being the token ID minted.
 *
 * Using OwnableERC721, created Asset Vaults then map their own address back into
 * a uint256, and check the ownership of the token ID matching that uint256 within the
 * VaultFactory in order to determine their own contract owner. The VaultFactory contains
 * conveniences to allow switching between the address and uint256 formats.
 */
contract VaultFactory is IVaultFactory, ERC165, ERC721Permit, AccessControl, ERC721Enumerable {
    using Strings for uint256;
    // ============================================ STATE ==============================================

    // =================== Constants =====================

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant FEE_CLAIMER_ROLE = keccak256("FEE_CLAIMER");
    bytes32 public constant RESOURCE_MANAGER_ROLE = keccak256("RESOURCE_MANAGER");

    /// @dev Lookup identifier for minting fee in fee controller
    bytes32 public constant FL_01 = keccak256("VAULT_MINT_FEE");

    // ================= State Variables ==================

    /// @dev The template contract for asset vaults
    address public immutable template;
    /// @dev The CallWhitelist contract definining the calling restrictions for vaults.
    address public immutable whitelist;
    /// @dev The contract specifying minting fees, if non-zero
    IFeeController public immutable feeController;

    /// @dev Contract for returning tokenURI resources.
    INFTDescriptor public descriptor;

    // ========================================== CONSTRUCTOR ===========================================

    /**
     * @notice Deploys a new VaultFactory, with a given template and whitelist.
     *
     * @param _template          The address of the template contract for vaults.
     * @param _whitelist         The address of the CallWhitelist contract.
     * @param _feeController     The contract reporting fees for vault minting.
     * @param _descriptor        The resource descriptor contract.
     */
    constructor(
        address _template,
        address _whitelist,
        address _feeController,
        address _descriptor
    ) ERC721("Asset Vault", "AV") ERC721Permit("Asset Vault") {
        if (_template == address(0)) revert VF_ZeroAddress();
        if (_whitelist == address(0)) revert VF_ZeroAddress();
        if (_feeController == address(0)) revert VF_ZeroAddress();
        if (_descriptor == address(0)) revert VF_ZeroAddress();

        template = _template;
        whitelist = _whitelist;
        descriptor = INFTDescriptor(_descriptor);
        feeController = IFeeController(_feeController);

        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);

        _setupRole(FEE_CLAIMER_ROLE, msg.sender);
        _setRoleAdmin(FEE_CLAIMER_ROLE, ADMIN_ROLE);

        _setRoleAdmin(RESOURCE_MANAGER_ROLE, ADMIN_ROLE);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @notice Check if the given address is a vault instance created by this factory.
     *
     * @param instance              The address to check.
     *
     * @return validity             Whether the address is a valid vault instance.
     */
    function isInstance(address instance) external view override returns (bool validity) {
        return _exists(uint256(uint160(instance)));
    }

    /**
     * @notice Return the number of instances created by this factory.
     *         Also the total supply of ERC721 bundle tokens.
     *
     * @return count                The total number of instances.
     */
    function instanceCount() external view override returns (uint256 count) {
        return totalSupply();
    }

    /**
     * @notice Return the address of the instance for the given token ID.
     *
     * @param tokenId               The token ID for which to find the instance.
     *
     * @return instance             The address of the derived instance.
     */
    function instanceAt(uint256 tokenId) external view override returns (address instance) {
        // check _owners[tokenId] != address(0)
        if (!_exists(tokenId)) revert VF_TokenIdOutOfBounds(tokenId);

        return address(uint160(tokenId));
    }

    /**
     * @notice Return the address of the instance for the given index. Allows
     *         for enumeration over all instances.
     *
     * @param index                 The index for which to find the instance.
     *
     * @return instance             The address of the instance, derived from the corresponding
     *                              token ID at the specified index.
     */
    function instanceAtIndex(uint256 index) external view override returns (address instance) {
        return address(uint160(tokenByIndex(index)));
    }

    // ==================================== FACTORY OPERATIONS ==========================================

    /**
     * @notice Creates a new bundle token and vault contract for `to`. Its token ID will be
     * automatically assigned (and available on the emitted {IERC721-Transfer} event)
     *
     * See {ERC721-_mint}.
     *
     * @param to                    The address that will own the new vault.
     *
     * @return tokenID              The token ID of the bundle token, derived from the vault address.
     */
    function initializeBundle(address to) external payable override returns (uint256) {
        uint256 mintFee = feeController.get(FL_01);

        if (msg.value < mintFee) revert VF_InsufficientMintFee(msg.value, mintFee);

        address vault = _create();

        _mint(to, uint256(uint160(vault)));

        if (msg.value > mintFee) payable(msg.sender).transfer(msg.value - mintFee);

        emit VaultCreated(vault, to);
        return uint256(uint160(vault));
    }

    /**
     * @dev Creates and initializes a minimal proxy vault instance,
     *      using the OpenZeppelin Clones library.
     *
     * @return vault                The address of the newly created vault.
     */
    function _create() internal returns (address vault) {
        vault = Clones.clone(template);
        IAssetVault(vault).initialize(whitelist);
        return vault;
    }

    /**
     * @notice Claim any accrued minting fees. Only callable by FEE_CLAIMER_ROLE.
     */
    function claimFees(address to) external onlyRole(FEE_CLAIMER_ROLE) {
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);

        emit ClaimFees(to, balance);
    }

    // ===================================== ERC721 UTILITIES ===========================================

    /**
     * @notice Getter of specific URI for a bundle token ID.
     *
     * @param tokenId               The ID of the bundle to get the URI for.
     *
     * @return                      The bundle ID's URI string.
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
    function setDescriptor(address _descriptor) external override onlyRole(RESOURCE_MANAGER_ROLE) {
        if (_descriptor == address(0)) revert VF_ZeroAddress();

        descriptor = INFTDescriptor(_descriptor);

        emit SetDescriptor(msg.sender, _descriptor);
    }

    /**
     * @dev Hook that is called before any token transfer.
     * @dev This notifies the vault contract about the ownership transfer.
     *
     * @dev Does not let tokens with withdraw enabled be transferred, which ensures
     *      that items cannot be withdrawn in a frontrunning attack before loan origination.
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
        IAssetVault vault = IAssetVault(address(uint160(tokenId)));
        if (vault.withdrawEnabled()) revert VF_NoTransferWithdrawEnabled(tokenId);

        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC165, ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

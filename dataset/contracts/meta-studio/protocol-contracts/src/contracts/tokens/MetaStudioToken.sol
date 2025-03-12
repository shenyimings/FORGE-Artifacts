// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC165Upgradeable.sol";
import "../metatx/ERC2771ContextUpgradeable.sol";
import "../metatx/IERC2771Upgradeable.sol";
import "../ERC1363/ERC1363Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1363Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "./IPausable.sol";

/// @title The Metastudio's ERC20 token
/// @dev This is an ERC20 contract implementing many features: ERC165, ERC1363, ERC2771, ERC20Votes, ERC20Permit, ERC1967, ERC1822, Pausable and AccessControl.
/// @custom:security-contact it@theblockchainxdev.com
contract MetaStudioToken is
    Initializable,
    ContextUpgradeable,
    IERC165Upgradeable,
    ERC20Upgradeable,
    ERC1363Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ERC2771ContextUpgradeable,
    UUPSUpgradeable
{
    /// @notice Role allowed to update implementation behind Proxy
    /// @dev Role allowed to update implementation behind Proxy
    /// @return compute the Keccak-256 hash of the PROXY_ROLE
    bytes32 public constant PROXY_ROLE = keccak256("PROXY_ROLE");

    /// @notice Role allowed to update the trusted forwarder (meta-tx)
    /// @dev Role allowed to update the trusted forwarder (meta-tx)
    /// @return compute the Keccak-256 hash of the FORWARDER_ROLE
    bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");

    /// @notice Role allowed to switch contract between active/paused state
    /// @dev Role allowed to switch contract between active/paused state
    /// @return compute the Keccak-256 hash of the PAUSER_ROLE
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Contract initialization. 5_000_000_000 tokens are minted
    /// @dev Initialization of the contract required by the `proxy pattern` replacing the `constructor`
    /// @param tokensOwner Admin of the contract & recipient address of the minted tokens
    /// @param forwarder Initial ERC2771 trusted forwarder
    function initialize(address tokensOwner, address forwarder) external initializer {
        require(tokensOwner != address(0), "tokensOwner is mandatory");
        __ERC20_init("METAS", "METAS");
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();
        __ERC2771_init(forwarder);
        __Pausable_init();
        __ERC20Permit_init("METAS");
        __ERC20Votes_init();
        __ERC1363_init();

        /// @dev Defining default roles: The token Owner is granted to all roles
        _grantRole(DEFAULT_ADMIN_ROLE, tokensOwner);
        _grantRole(PROXY_ROLE, tokensOwner);
        _grantRole(FORWARDER_ROLE, tokensOwner);
        _grantRole(PAUSER_ROLE, tokensOwner);

        // Minting all tokens on creation
        _mint(tokensOwner, 5_000_000_000 * 10**decimals());
    }

    /// @dev get current block chain identifier
    /// @return number representing current block chain identifier
    function getChainId() external view returns (uint256) {
        return block.chainid;
    }

    /// @notice Supported interface ask machine.
    /// @dev ERC165 implementation
    /// @param interfaceId interface's id
    /// @return true if the specified interface is implemented by the contract
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        override(IERC165Upgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC165Upgradeable).interfaceId ||
            interfaceId == type(IERC20Upgradeable).interfaceId ||
            interfaceId == type(IPausable).interfaceId ||
            interfaceId == type(IERC2771Upgradeable).interfaceId ||
            interfaceId == type(IERC20PermitUpgradeable).interfaceId ||
            interfaceId == type(IERC1363Upgradeable).interfaceId ||
            interfaceId == type(IAccessControlUpgradeable).interfaceId ||
            interfaceId == type(IAccessControlEnumerableUpgradeable).interfaceId;
    }

    /// @notice Pause the contract aka `Emergency Stop Mechanism`. No action available on the contract except `unpause`
    /// @dev Only owner can pause
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause the contract.
    /// @dev Only owner can unpause
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @inheritdoc ERC20Upgradeable
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused nonReentrant {
        super._beforeTokenTransfer(from, to, amount);
    }

    // @dev only PROXY_ROLE granted address can upgrade
    function _authorizeUpgrade(address)
        internal
        view
        override
        onlyRole(PROXY_ROLE)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._afterTokenTransfer(from, to, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function _mint(address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._mint(to, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function _burn(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._burn(account, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function approve(address spender, uint256 amount) public virtual override(ERC20Upgradeable) returns (bool) {
        return super.approve(spender, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function allowance(address holder, address spender) public view override(ERC20Upgradeable) returns (uint256) {
        return super.allowance(holder, spender);
    }

    /// @inheritdoc ERC20Upgradeable
    function balanceOf(address tokenHolder) public view override(ERC20Upgradeable) returns (uint256) {
        return super.balanceOf(tokenHolder);
    }

    /// @inheritdoc ERC20Upgradeable
    function decimals() public pure override(ERC20Upgradeable) returns (uint8) {
        return 18;
    }

    /// @inheritdoc ERC20Upgradeable
    function name() public view override(ERC20Upgradeable) returns (string memory) {
        return super.name();
    }

    /// @inheritdoc ERC20Upgradeable
    function symbol() public view override(ERC20Upgradeable) returns (string memory) {
        return super.symbol();
    }

    /// @inheritdoc ERC20Upgradeable
    function totalSupply() public view override(ERC20Upgradeable) returns (uint256) {
        return super.totalSupply();
    }

    /// @inheritdoc ERC20Upgradeable
    function transfer(address recipient, uint256 amount) public override(ERC20Upgradeable) returns (bool) {
        return super.transfer(recipient, amount);
    }

    /// @inheritdoc ERC20Upgradeable
    function transferFrom(
        address holder,
        address recipient,
        uint256 amount
    ) public override(ERC20Upgradeable) returns (bool) {
        return super.transferFrom(holder, recipient, amount);
    }

    /*
    Extended ERC2771
   */

    /// @notice Allows FORWARDER_ROLE granted account to change the `trusted forwarder`
    /// @dev should be declared here because we need to protect calls with onlyRole(FORWARDER_ROLE)
    /// @param forwarder New trusted forwarder's address
    function setTrustedForwarder(address forwarder) external onlyRole(FORWARDER_ROLE) {
        super._setTrustedForwarder(forwarder);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}

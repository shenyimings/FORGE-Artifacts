// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../utils/RegistryOwnable.sol";
import "./P00lsTokenBase.sol";
import "./interfaces.sol";

/// @custom:security-contact security@p00ls.com
contract P00lsTokenCreator_Polygon is
    P00lsTokenBase, // includes multicall
    AccessControlUpgradeable,
    RegistryOwnable
{
    bytes32 public constant WHITELISTER = keccak256("WHITELISTER");
    bytes32 public constant WHITELISTED = keccak256("WHITELISTED");

    IP00lsTokenXCreator public xCreatorToken;
    bool                public isOpen;

    event Opened();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address registry)
        RegistryOwnable(registry)
        initializer()
    {}

    function initialize(string calldata name, string calldata symbol, address child)
        external
        initializer()
    {
        __AccessControl_init();
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        _setRoleAdmin(WHITELISTED, WHITELISTER);
        _grantRole(WHITELISTER, owner());

        xCreatorToken = IP00lsTokenXCreator(child);
    }

    /**
     * Default admin is overriden to use the NFT mechanism
     */
    function hasRole(bytes32 role, address account)
        public
        view
        virtual
        override
        returns (bool)
    {
        return role == DEFAULT_ADMIN_ROLE ? account == owner() : super.hasRole(role, account);
    }

    function _grantRole(bytes32 role, address account)
        internal
        override
    {
        require(role != DEFAULT_ADMIN_ROLE, "Admin role is managed by NFT");
        super._grantRole(role, account);
    }

    function _revokeRole(bytes32 role, address account)
        internal
        override
    {
        require(role != DEFAULT_ADMIN_ROLE, "Admin role is managed by NFT");
        super._revokeRole(role, account);
    }

    /**
     * Bridging logic
     */
    function mint(address user, uint256 amount) external {
        require(msg.sender == address(ownershipRegistry));
        _mint(user, amount);
    }

    function withdraw(address to, uint256 amount) external {
        _burn(msg.sender, amount);
        IP00lsCreatorRegistry_Polygon(address(ownershipRegistry)).__withdraw(to, amount);
    }

    function withdrawFrom(address from, address to, uint256 amount) external {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        IP00lsCreatorRegistry_Polygon(address(ownershipRegistry)).__withdraw(to, amount);
    }

    /**
     * Whitelist
     */
    function open() public virtual onlyOwner() {
        isOpen = true;
        emit Opened();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(
            from == address(0)         || // mint should always be allowed to avoid funds gettign stuck in the bridge
            isOpen                     || // if contract is open, all transfer are allowed
            hasRole(WHITELISTED, from) || // if either from or to is whitelisted, transfer can happen
            hasRole(WHITELISTED, to),
            "Transfer restricted to whitelisted"
        );
    }

    /**
     * Overrides
     */
    function owner()
        public
        view
        override(P00lsTokenBase, RegistryOwnable)
        returns (address)
    {
        return super.owner();
    }

    /**
     * xCreatorToken bindings
     */
    function _delegate(address delegator, address delegatee)
        internal
        override
    {
        super._delegate(delegator, delegatee);
        xCreatorToken.__delegate(delegator, delegatee);
    }

    function allowance(address holder, address spender)
        public
        view
        override
        returns (uint256)
    {
        return spender == address(xCreatorToken)
            ? type(uint256).max
            : super.allowance(holder, spender);
    }
}

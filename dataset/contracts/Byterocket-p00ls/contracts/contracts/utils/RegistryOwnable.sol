// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./convert.sol";

/// @custom:security-contact security@p00ls.com
abstract contract RegistryOwnable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IERC721 public immutable ownershipRegistry;

    modifier onlyOwner() {
        require(owner() == msg.sender, "RegistryOwnable: caller is not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(admin() == msg.sender, "RegistryOwnable: caller is not the admin");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address ownershipRegistry_)
    {
        ownershipRegistry = IERC721(ownershipRegistry_);
    }

    function owner()
        public
        view
        virtual
        returns (address)
    {
        return ownershipRegistry.ownerOf(addressToUint256(address(this)));
    }

    function admin()
        public
        view
        virtual
        returns (address)
    {
        return ownershipRegistry.ownerOf(addressToUint256(address(ownershipRegistry)));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        ownershipRegistry.transferFrom(owner(), newOwner, addressToUint256(address(this)));
    }
}

/// @custom:security-contact security@p00ls.com
abstract contract RegistryOwnableUpgradeable is Initializable {
    IERC721 public ownershipRegistry;

    modifier onlyOwner() {
        require(owner() == msg.sender, "RegistryOwnable: caller is not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(admin() == msg.sender, "RegistryOwnable: caller is not the admin");
        _;
    }

    function __RegistryOwnable_init(address ownershipRegistry_)
        internal
        initializer
    {
        ownershipRegistry = IERC721(ownershipRegistry_);
    }

    function owner()
        public
        view
        virtual
        returns (address)
    {
        return ownershipRegistry.ownerOf(addressToUint256(address(this)));
    }

    function admin()
        public
        view
        virtual
        returns (address)
    {
        return ownershipRegistry.ownerOf(addressToUint256(address(ownershipRegistry)));
    }

    function transferOwnership(address newOwner)
        public
        virtual
        onlyOwner
    {
        ownershipRegistry.transferFrom(owner(), newOwner, addressToUint256(address(this)));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@amxx/hre/contracts/ENSReverseRegistration.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../utils/Beacon.sol";
import "../utils/BeaconProxy.sol";
import "../utils/RegistryOwnable.sol";
import "./P00lsTokenCreator.sol";
import "./P00lsTokenXCreator.sol";

/// @custom:security-contact security@p00ls.com
contract P00lsRegistryBase is
    AccessControlUpgradeable,
    ERC721Upgradeable,
    RegistryOwnableUpgradeable,
    UUPSUpgradeable,
    MulticallUpgradeable
{
    bytes32 public constant REGISTRY_MANAGER_ROLE = keccak256("REGISTRY_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE         = keccak256("UPGRADER_ROLE");

    Beacon private __beaconCreator;
    Beacon private __beaconXCreator;
    string private __baseURI;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor()
        initializer()
    {}

    function initialize(
        address       _admin,
        string memory _name,
        string memory _symbol
    )
        external
        initializer()
    {
        __AccessControl_init();
        __ERC721_init(_name, _symbol);
        __RegistryOwnable_init(address(this));

        _mint(_admin, addressToUint256(address(this)));
        _grantRole(REGISTRY_MANAGER_ROLE, _admin);
        _grantRole(UPGRADER_ROLE,         _admin);

        __beaconCreator  = new Beacon();
        __beaconXCreator = new Beacon();
    }

    function _createProxy(Beacon beacon) internal returns (address) {
        return address(new BeaconProxy(beacon));
    }

    function _createProxy(Beacon beacon, bytes32 salt) internal returns (address) {
        return address(new BeaconProxy{ salt: salt }(beacon));
    }

    function _predictProxy(Beacon beacon, bytes32 salt) internal view returns (address) {
        return Create2.computeAddress(salt, keccak256(bytes.concat(type(BeaconProxy).creationCode, abi.encode(beacon))));
    }

    /**
     * Support transferOwnership by the tokenized contracts
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        // super call will revert of tokenId does not exist
        return super._isApprovedOrOwner(spender, tokenId) || addressToUint256(spender) == tokenId;
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
        // here owner() == admin()
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
     * Token URI customization
     */
    function setBaseURI(string memory baseURI)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        __baseURI = baseURI;
    }

    function _baseURI()
        internal
        view
        override
        returns (string memory)
    {
        return __baseURI;
    }

    /**
     * Beacon
     */
    function beaconCreator()
        public
        view
        returns (Beacon)
    {
        return __beaconCreator;
    }

    function beaconXCreator()
        public
        view
        returns (Beacon)
    {
        return __beaconXCreator;
    }

    function upgradeCreatorToken(address newImplementation)
        external
        onlyRole(UPGRADER_ROLE)
    {
        __beaconCreator.upgradeTo(newImplementation);
    }

    function upgradeXCreatorToken(address newImplementation)
        external
        onlyRole(UPGRADER_ROLE)
    {
        __beaconXCreator.upgradeTo(newImplementation);
    }

    /**
     * ENS
     */
    function setName(address ensregistry, string calldata ensname)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ENSReverseRegistration.setName(ensregistry, ensname);
    }

    /**
     * Upgradeability
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

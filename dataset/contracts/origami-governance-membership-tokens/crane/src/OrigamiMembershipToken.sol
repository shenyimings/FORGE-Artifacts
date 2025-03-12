// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IVotesToken} from "src/interfaces/IVotesToken.sol";
import {IVotes} from "src/interfaces/IVotes.sol";
import {Votes} from "src/utils/Votes.sol";

import {AccessControlUpgradeable} from "@oz-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@oz-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@oz-upgradeable/security/PausableUpgradeable.sol";
import {IERC721Upgradeable, ERC721Upgradeable} from "@oz-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@oz-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@oz-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {CountersUpgradeable} from "@oz-upgradeable/utils/CountersUpgradeable.sol";

/// @title Origami Membership Token
/// @author Stephen Caudill
/// @notice This contract is a configurable NFT used to represent membership in a DAO supported by the Origami platform and ecosystem.
/// @custom:security-contact contract-security@joinorigami.com
contract OrigamiMembershipToken is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    Votes
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /// @notice the role hash for granting the ability to pause the contract. By default, this role is granted to the contract admin.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @notice the role hash for granting the ability to mint new membership tokens. By default, this role is granted to the contract admin.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice the role hash for granting the ability to revoke membership tokens. By default, this role is granted to the contract admin.
    bytes32 public constant REVOKER_ROLE = keccak256("REVOKER_ROLE");

    CountersUpgradeable.Counter private _tokenIdCounter;
    // @notice: timestamp is purely informative and may vary by up to 900 seconds from actual time of execution
    mapping(uint256 => uint256) public tokenIdToBlockTimestamp;

    /// @notice this sets the base URI of the token's URI and is used to generate the token's URI. This is set during initialization or by calling setBaseURI.
    // slither-disable-next-line naming-convention (consistent with contract naming convention)
    string public _metadataBaseURI;
    /// @notice this private variable denotes whether or not the contract allows token transfers. By default, this is disabled.
    bool private _transferEnabled;

    /// @notice this event is fired when a new token is minted. Origami's platform uses this event to determine which tokenId was minted to a particular member's wallet.
    event Mint(address indexed _to, uint256 indexed _tokenId);
    /// @notice monitoring: this is fired when the baseURI is changed.
    event BaseURIChanged(address indexed caller, string value);
    /// @notice monitoring: this is fired when the transferEnabled state is changed.
    event TransferEnabled(address indexed caller, bool value);
    /// @notice monitoring: this is fired when a token is revoked.
    event TokenRevoked(address indexed caller, address indexed tokenOwner, uint256 indexed tokenId);
    /// @notice monitoring: this is fired when the paused state is changed.
    event Paused(address indexed caller, bool value);

    /// @notice the constructor is not used since the contract is upgradeable except to disable initializers in the implementations that are deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev this function is used to initialize the contract. It is called during contract deployment.
    /// @notice this function is not intended to be called by external users.
    /// @param admin the address of the contract admin. This address receives all roles by default and should be used to delegate them to DAO committees and/or permanent members.
    /// @param _name the name of the token. Typically this is the name of the DAO.
    /// @param symbol the symbol of the token. Typically this is a short abbreviation of the DAO's name.
    /// @param baseURI_ the base URI of the token. This is used to generate the token's URI.
    // slither-disable-next-line naming-convention (name is a shadowed variable)
    function initialize(address admin, string memory _name, string memory symbol, string memory baseURI_)
        public
        initializer
    {
        require(admin != address(0x0), "Admin address cannot be zero");

        __ERC721_init(_name, symbol);
        __ERC721Enumerable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();

        // grant all roles to the admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(REVOKER_ROLE, admin);

        _metadataBaseURI = baseURI_;
        _transferEnabled = false;
    }

    /// @dev this overrides the ERC721Upgradeable's function to return our internal base URI variable. It is called by `super.tokenURI`.
    function _baseURI() internal view override returns (string memory) {
        return _metadataBaseURI;
    }

    function name() public view virtual override(ERC721Upgradeable, IVotesToken) returns (string memory) {
        return super.name();
    }

    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    function balanceOf(address owner)
        public
        view
        override(ERC721Upgradeable, IERC721Upgradeable, IVotesToken)
        returns (uint256)
    {
        return super.balanceOf(owner);
    }

    /// @dev this is only callable by the contract admin.
    /// @notice this allows setting the base URI of the token. This is used to generate the token's URI. An event is fired when the base URI is changed.
    /// @param baseURI_ the new value for the base URI of the token. Typically this is either a string representation of JSON metadata or a URI.
    function setBaseURI(string memory baseURI_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        emit BaseURIChanged(_msgSender(), baseURI_);
        _metadataBaseURI = baseURI_;
    }

    /// @dev this is only callable by an address that has the PAUSER_ROLE
    /// @notice this function pauses the contract, restricting mints, transfers and burns regardless of the independent state of other configurations.
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
        emit Paused(_msgSender(), true);
    }

    /// @dev this is only callable by an address that has the PAUSER_ROLE
    /// @notice this function unpauses the contract
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
        emit Paused(_msgSender(), false);
    }

    /// @dev this is only callable by an address that has the MINTER_ROLE. The Origami platform airdrops membership tokens to members' wallets.
    /// @notice this function mints a new membership token to the recipient's wallet. An event is fired when the token is minted. Only one token may be minted to any given wallet.
    /// @param to the address of the recipient's wallet.
    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        tokenIdToBlockTimestamp[tokenId] = block.timestamp;
        emit Mint(to, tokenId);
    }

    /**
     * @dev this is only callable by an address that has the MINTER_ROLE. The Origami platform airdrops membership tokens to members' wallets. A best effort is made to check the addreses and avoid attempting mints that would fail.
     * @notice this function mints membership tokens to all wallets in the recipients array.
     * @param recipients - an array of addresses to mint tokens to.
     */
    function safeBatchMint(address[] calldata recipients) public onlyRole(MINTER_ROLE) {
        require(recipients.length > 0, "Must mint at least one token");
        require(recipients.length <= 100, "Cannot mint more than 100 tokens at once");
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] != address(0) && balanceOf(recipients[i]) == 0) {
                safeMint(recipients[i]);
            }
        }
    }

    /// @dev this is only callable by an address that has the REVOKER_ROLE. Membership in a DAO may be revoked by the DAO.
    /// @notice this function revokes a membership token from the recipient's wallet. An event is fired when the token is revoked.
    /// @param from the address of the owner's wallet to revoke the token from.
    function revoke(address from) public onlyRole(REVOKER_ROLE) {
        require(balanceOf(from) == 1, "Revoke: cannot revoke");
        uint256 tokenId = tokenOfOwnerByIndex(from, 0);
        _burn(tokenId);
        emit TokenRevoked(_msgSender(), from, tokenId);
    }

    /// @notice indicates whether or not membership tokens are transferrable
    /// @return true if tokens are transferrable, false otherwise.
    function transferrable() public view returns (bool) {
        return _transferEnabled;
    }

    /// @dev this emits an event indicating that the transferrable state has been set to enabled.
    /// @notice this function enables transfers of membership tokens. Only the contract admin can call this function.
    function enableTransfer() public onlyRole(DEFAULT_ADMIN_ROLE) whenNontransferrable {
        _transferEnabled = true;
        emit TransferEnabled(_msgSender(), _transferEnabled);
    }

    /// @dev this emits an event indicating that the transferrable state has been set to disabled.
    /// @notice this function disables transfers of membership tokens. Only the contract admin can call this function.
    function disableTransfer() public onlyRole(DEFAULT_ADMIN_ROLE) whenTransferrable {
        _transferEnabled = false;
        emit TransferEnabled(_msgSender(), _transferEnabled);
    }

    /// @dev this is overridden so we can apply the `whenTransferrable` modifier
    /// @notice this allows transfers when the transferrable state is enabled.
    function transferFrom(address from, address to, uint256 tokenId)
        public
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        whenTransferrable
    {
        super.transferFrom(from, to, tokenId);
    }

    /// @dev this is overridden so we can apply the `whenTransferrable` modifier
    /// @notice this allows transfers when the transferrable state is enabled.
    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        whenTransferrable
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    /// @dev this is overridden so we can apply the `whenTransferrable` modifier
    /// @notice this allows transfers when the transferrable state is enabled.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        whenTransferrable
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /// @dev this is overridden so we can apply the `limitBalance` and `whenNotPaused` modifiers
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        limitBalance(to)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable)
    {
        transferVotingUnits(from, to, batchSize);
        super._afterTokenTransfer(from, to, tokenId, batchSize);
    }

    /// @inheritdoc ERC721Upgradeable
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
        require(tokenId > 0, "Invalid token ID");
        require(tokenId <= _tokenIdCounter.current(), "Invalid token ID");
        return super.tokenURI(tokenId);
    }

    /// @inheritdoc ERC721Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IVotes).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice this modifier allows us to ensure that no more than one token is minted to a given wallet.
    modifier limitBalance(address recipient) {
        // allow unlimited transfers to the burn address
        require(recipient == address(0) || balanceOf(recipient) == 0, "Holders may only have one token");
        _;
    }

    /// @notice this modifier allows us to ensure that something may only occur when transfers are disabled
    modifier whenNontransferrable() {
        require(!transferrable(), "Transferrable: transfers are enabled");
        _;
    }

    /// @notice this modifier allows us to ensure that something may only occur when the transfers are enabled
    modifier whenTransferrable() {
        require(transferrable(), "Transferrable: transfers are disabled");
        _;
    }
}

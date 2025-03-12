//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./utils/Base64.sol";
import "./utils/SVG.sol";
import "./INFTUpgradeable.sol";

contract NFTUpgradeable is ERC721Upgradeable, INFTUpgradeable {
    using Strings for uint256;

    // ACL
    address private _owner;
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }
    mapping(bytes32 => RoleData) private _roles;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bool private _paused;

    uint256 private _tokenCount;
    mapping(uint256 => string) private _tokenURIs;
    NFTUpgradeableConfig public config;

    function __NFTUpgradeable_init(string memory name_, string memory symbol_, address owner_) internal {
        __ERC721_init(name_, symbol_);
        _owner = owner_;
        _grantRole(0x00, owner_);
        _grantRole(PAUSER_ROLE, owner_);
        _grantRole(MINTER_ROLE, owner_);
        _paused = false;
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(INFTUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }
    
    // Ownable
    modifier onlyOwner() {
        require(owner() == msg.sender);
        _;
    }

    function owner() public view override returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual override {
        require(owner() == msg.sender);
        require(newOwner != address(0));
        
        _owner = newOwner;
    }

    // AccessControl
    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    function grantRole(bytes32 role, address account) public virtual override {
        require(hasRole(_roles[role].adminRole, msg.sender));
        _grantRole(role, account);
    }

    // Pausable
    function setPaused(bool paused_) public virtual override {
        require(hasRole(PAUSER_ROLE, msg.sender));
        _paused = paused_;
    }

    function paused() public view virtual override returns (bool) {
        return _paused;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(!paused());
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721Upgradeable, IERC721MetadataUpgradeable) returns (string memory) {
        require(_exists(tokenId));

        if (bytes(_tokenURIs[tokenId]).length > 0) {
            return _tokenURIs[tokenId];
        }

        string memory base = _baseURI();
        return bytes(base).length > 0 ? string(abi.encodePacked(base, tokenId.toString())) : "";
    }

    function burn(uint256 tokenId) public virtual override{
        require(_isApprovedOrOwner(_msgSender(), tokenId));
        _burn(tokenId);
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
    
    function setConfig(NFTUpgradeableConfig memory config_) public virtual override {
        require(owner() == msg.sender);
        
        config = config_;
    }

    function tokenCount() public view override returns (uint256) {
        return _tokenCount;
    }

    function creator() public view override returns (address) {
        return address(0) == config.creator ? owner() : config.creator;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return config.baseURI;
    }

    function _mint(address to, uint256 tokenId) internal virtual override {
        super._mint(to, tokenId);
        _tokenCount += 1;
    }

    function _mint(address to, uint256 tokenId, string memory uri) internal virtual {
        _mint(to, tokenId);
        _tokenURIs[tokenId] = uri;
    }
}

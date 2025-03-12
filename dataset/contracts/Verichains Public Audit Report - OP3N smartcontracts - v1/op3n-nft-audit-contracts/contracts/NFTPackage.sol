//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "./NFTUpgradeable.sol";
import "./INFTPackage.sol";

contract NFTPackage is NFTUpgradeable, INFTPackage {
    using Strings for uint256;
    using Base64 for bytes;
    using SVG for string;
    
    mapping(string => NFTPackageConfig) public packages;
    mapping(uint256 => string) private _tokenPackage;
    mapping(string => uint256) private _packageTokenCount;

    function initialize(string memory name_, string memory symbol_, address owner_) public virtual override initializer {
        __NFTUpgradeable_init(name_, symbol_, owner_);
    }

    function supportsInterface(bytes4 interfaceId) public view override(NFTUpgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(INFTPackage).interfaceId || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(NFTUpgradeable, IERC721MetadataUpgradeable) returns (string memory) {
        string memory _tokenURI = super.tokenURI(tokenId);
        if (0 < bytes(_tokenURI).length) return _tokenURI;

        string memory tokenIdString = tokenId.toString();
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                abi.encodePacked(
                    '{"name":"#',
                    tokenIdString,
                    '","description":"',
                    packages[_tokenPackage[tokenId]].desc,
                    '","image":"data:image/svg+xml;base64,',
                    tokenIdString.textShadow(packages[_tokenPackage[tokenId]].cover).encode(),
                    '","attributes":[',
                    '{"trait_type":"package","value":"',
                    packages[_tokenPackage[tokenId]].name,
                    '"}]}'
                ).encode()
            )
        );
    }

    function setPackage(NFTPackageConfig memory package_) public virtual override {
        require(owner() == msg.sender);
        require(0 == tokenCount());
        
        packages[package_.name] = package_;
    }

    function packageTokenCount(string memory pkg) public view override returns (uint256) {
        return _packageTokenCount[pkg];
    }

    function tokenPackage(uint256 tokenId) public view override returns (string memory) {
        return _tokenPackage[tokenId];
    }

    function mintTo(address to, string memory pkg, string memory uri) public virtual override {
        require(hasRole(MINTER_ROLE, msg.sender), "403");
        require(packageTokenCount(pkg) < packages[pkg].totalSupply, "429");
        
        uint256 tokenId = tokenCount()+1;
        super._mint(to, tokenId, uri);
        _tokenPackage[tokenId] = pkg;
        _packageTokenCount[pkg] += 1;
        emit Minted(to, tokenId, pkg);
    }
}

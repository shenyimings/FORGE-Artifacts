// contracts/HashNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "double-contracts/contracts/4907/ERC4907.sol";
import "./interfaces/IERC4907a.sol";


contract ERC4907a is ERC4907, IERC4907a, Ownable {
    using Strings for uint256;

    mapping (address => mapping (address => bool)) public override isSetterApprovedForAll;
    mapping (uint256 => address) public override isSetterApproved;
    uint256 public nextId;

    constructor(string memory name_, string memory symbol_)
     ERC4907(name_, symbol_) {
        nextId = 1;
     }

    function _isSetterOrOwner(address setter, uint256 tokenId) public view returns(bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (setter == owner || isSetterApprovedForAll[owner][setter] || isSetterApproved[tokenId] == setter);
    }

    function approveSetterForAll(address setter, bool approved) external override {
        require(msg.sender != setter, "ERC4907X: approve to caller");
        isSetterApprovedForAll[msg.sender][setter] = approved;
        emit ApproveSetterForAll(msg.sender, setter, approved);
    }

    function approveSetter(address setter, uint256 tokenId) external override {
        address owner = ERC721.ownerOf(tokenId);
        require(setter != owner, "ERC4907X: approval to current owner");
        _approveSetter(setter, tokenId);
    }

    function _approveSetter(address setter, uint256 tokenId) internal {
        isSetterApproved[tokenId] = setter;
        emit ApproveSetter(msg.sender, setter, tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from, to, tokenId);
        _approveSetter(address(0), tokenId);
    }

    /// @notice set the user and expires of a NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(uint256 tokenId, address user, uint64 expires) public override {
        UserInfo memory ui = _users[tokenId];
        if (ui.user != msg.sender) {
            require(_isSetterOrOwner(msg.sender, tokenId),"ERC4907X: caller is not owner nor approved");
            require(ui.expires < block.timestamp, "ERC4907X: not expired");
        } else {
            require(expires <= ui.expires, "ERC4907X: no extend");
        }

        _approveSetter(address(0), tokenId);
        UserInfo storage info = _users[tokenId];
        info.user = user;
        info.expires = expires;
        emit UpdateUser(tokenId,user,expires);
    }

    function mint(address to) external onlyOwner virtual returns(uint256 tokenId) {
        tokenId = nextId;
        nextId += 1;
        _mint(to, tokenId);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4907).interfaceId || super.supportsInterface(interfaceId);
    }
}
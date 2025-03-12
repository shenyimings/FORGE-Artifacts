// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/core/ISBT721.sol";

contract BABTMock is ISBT721 {
    mapping(uint256 => address) private _ownerMap;
    mapping(address => uint256) private _tokenMap;

    uint256 private _tokenId;

    function attest(address to) external returns (uint256) {
        require(to != address(0), "Address is empty");
        require(_tokenMap[to] == 0, "SBT already exists");

        uint256 tokenId = _tokenId;
        tokenId++;

        _tokenMap[to] = tokenId;
        _ownerMap[tokenId] = to;

        emit Attest(to, tokenId);
        emit Transfer(address(0), to, tokenId);

        _tokenId = tokenId;
        return tokenId;
    }

    function revoke(address from) external {
        require(from != address(0), "Address is empty");
        require(_tokenMap[from] > 0, "The account does not have any SBT");

        uint256 tokenId = _tokenMap[from];

        _tokenMap[from] = 0;
        _ownerMap[tokenId] = address(0);

        emit Revoke(from, tokenId);
        emit Transfer(from, address(0), tokenId);
    }

    function burn() external {
        require(_tokenMap[msg.sender] > 0, "The account does not have any SBT");

        uint256 tokenId = _tokenMap[msg.sender];

        _tokenMap[msg.sender] = 0;
        _ownerMap[tokenId] = address(0);

        emit Burn(msg.sender, tokenId);
        emit Transfer(msg.sender, address(0), tokenId);
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _tokenMap[owner] > 0 ? 1 : 0;
    }

    function tokenIdOf(address from) external view returns (uint256) {
        require(_tokenMap[from] > 0, "The wallet has not attested any SBT");
        return _tokenMap[from];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        require(_ownerMap[tokenId] != address(0), "Invalid tokenId");
        return _ownerMap[tokenId];
    }

    function totalSupply() external view returns (uint256) {
        return _tokenId;
    }
}

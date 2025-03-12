// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Assets.sol";

contract AssetsMock {
    using Assets for Assets.Pages;
    Assets.Pages private _assets;

    function page(address owner, uint256 i) public view returns (uint256) {
        return _assets.page(owner, i);
    }

    function get(address owner, uint256 tokenId) public view returns (bool) {
        return _assets.exists(owner, tokenId);
    }

    function set(address owner, uint256 tokenId) public {
        _assets.set(owner, tokenId);
    }

    function unset(address owner, uint256 tokenId) public {
        _assets.unset(owner, tokenId);
    }

    function setRange(address owner, uint256 from, uint256 count) public {
        _assets.setRange(owner, from, count);
    }

    function unsetRange(address owner, uint256 from, uint256 count) public {
        _assets.unsetRange(owner, from, count);
    }
}

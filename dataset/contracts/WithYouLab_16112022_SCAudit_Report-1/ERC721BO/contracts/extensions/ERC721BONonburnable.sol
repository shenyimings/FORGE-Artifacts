// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC721BO.sol";

abstract contract ERC721BONonburnable is ERC721BO {

    function totalBurnt() public virtual override view returns (uint256){
        return 0;
    }

    function tokenByIndex(uint256 index) public virtual override view returns (uint256){
        if (index >= totalSupply()) revert IndexOutOfRange();
        return index;
    }

    function _exists(uint256 tokenId) internal view virtual override returns (bool) {
        return totalSupply() > tokenId;
    }

    function _remint(address, uint256) internal virtual override {
        revert("Not supported");
    }

    function _burn(uint256) internal virtual override {
        revert("Not supported");
    }
}

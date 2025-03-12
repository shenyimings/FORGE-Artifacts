//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "./interfaces/IERC5192.sol";

abstract contract SBT is ERC721, IERC5192 {
    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function _transfer(
        address, /*from*/
        address, /*to*/
        uint256 /*tokenId*/
    ) internal pure virtual override {
        revert("SBT: cannot transfer");
    }

    function locked(
        uint256 /*tokenId*/
    ) external pure override returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IERC5192).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

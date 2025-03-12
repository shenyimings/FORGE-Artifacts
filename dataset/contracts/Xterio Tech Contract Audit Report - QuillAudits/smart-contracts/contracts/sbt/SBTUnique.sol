//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SBT.sol";

abstract contract SBTUnique is SBT {
    constructor(string memory name, string memory symbol) SBT(name, symbol) {}

    mapping(address => uint256) private address2token;

    function tokenOf(address x) public view returns (uint256) {
        return address2token[x];
    }

    /**
     * Override the _beforeTokenTransfer hook to ensure that the recipient
     * does not already have a token.
     * 
     * @dev See {IERC721-balanceOf}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 /* batchSize */
    ) internal virtual override {
        if (to != address(0)) {
            // mint
            require(from == address(0), "SBTUnique: can not transfer");
            require(
                balanceOf(to) == 0,
                "SBTUnique: the recipient already has a token"
            );

            address2token[to] = tokenId;
        } else {
            // burn
            require(
                balanceOf(from) == 1,
                "SBTUnique: the sender does not have a token"
            );

            address2token[from] = 0;
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

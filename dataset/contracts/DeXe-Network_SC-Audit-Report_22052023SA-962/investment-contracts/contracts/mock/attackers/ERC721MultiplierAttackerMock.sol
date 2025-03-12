// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/gov/ERC721/multipliers/IAbstractERC721Multiplier.sol";

contract ERC721MultiplierAttackerMock {
    function attackLockUnlock(
        IAbstractERC721Multiplier erc721Multiplier,
        uint256 tokenId
    ) external {
        erc721Multiplier.lock(tokenId);
        erc721Multiplier.unlock();
    }
}

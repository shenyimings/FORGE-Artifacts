// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MockERC1155 is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    /**
     * @dev Initializes ERC1155 token
     */
    constructor() ERC1155("") {}

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function mint(address to, uint256 amount) public virtual {
        _mint(to, _tokenIdTracker.current(), amount, "");
        _tokenIdTracker.increment();
    }
}

contract MockERC1155Metadata is MockERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    mapping(uint256 => string) public tokenURIs;

    constructor() MockERC1155() {}

    function mint(
        address to,
        uint256 amount,
        string memory tokenUri
    ) public virtual {
        uint256 tokenId = _tokenIdTracker.current();
        _mint(to, tokenId, amount, "");
        _tokenIdTracker.increment();
        _setTokenURI(tokenId, tokenUri);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        string[] memory tokenUris,
        bytes memory data
    ) public virtual {
        super._mintBatch(to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _setTokenURI(ids[i], tokenUris[i]);
        }
    }

    function _setTokenURI(uint256 tokenId, string memory tokenUri) internal {
        tokenURIs[tokenId] = tokenUri;
    }
}

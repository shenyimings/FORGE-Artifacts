// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SimpleERC721 is ERC721Enumerable {
	using Strings for string;
    using Counters for Counters.Counter; 

    Counters.Counter private _tokenIds;
	  string public baseURI;

    constructor(string memory name_, string memory symbol_, string memory baseURI_) ERC721(name_, symbol_) {
        baseURI = baseURI_;
    }

    function mint(uint256 amount) public {
        for (uint256 index; index < amount; ++index) {
            uint256 newItemId = _tokenIds.current();
            _safeMint(_msgSender(), newItemId);
            _tokenIds.increment();
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
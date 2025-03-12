// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "./Libraries/LibShare.sol";

contract TokenERC1155 is Ownable, ERC1155Supply {
    event RoyaltiesSetForCollection(LibShare.Share[] royalties);
    event RoyaltiesSetForTokenId(uint256 tokenId, LibShare.Share[] royalties);

    struct RoyaltiesSet {
        bool set; // true if Royalties are set for that particular tokenId
        LibShare.Share[] royalties;
    }

    LibShare.Share[] public collectionRoyalties;
    mapping(uint256 => RoyaltiesSet) public royaltiesByTokenId;
    mapping(uint256 => string) _uris;

    constructor(string memory uri) ERC1155(uri) {}

    // https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

     function _setTokenUri(string memory _uri, uint256 _tokenId) private {
        _uris[_tokenId] = _uri;
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        string memory _uri,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
        _setTokenUri(_uri, id);
    }

    function burn(uint256 _id, uint256 _amount) public {
        require(balanceOf(msg.sender, _id) >= _amount);

        _burn(msg.sender, _id, _amount);
    }

    function setRoyaltiesByTokenId(
        uint256 _tokenId,
        RoyaltiesSet memory royaltiesSet
    ) public onlyOwner {
        delete royaltiesByTokenId[_tokenId];
        royaltiesByTokenId[_tokenId].set = royaltiesSet.set;
        _setRoyaltiesArray(
            royaltiesByTokenId[_tokenId].royalties,
            royaltiesSet.royalties
        );
        emit RoyaltiesSetForTokenId(_tokenId, royaltiesSet.royalties);
    }

    function setRoyaltiesForCollection(LibShare.Share[] memory royalties)
        public
        onlyOwner
    {
        delete collectionRoyalties;
        _setRoyaltiesArray(collectionRoyalties, royalties);
        emit RoyaltiesSetForCollection(royalties);
    }

    function getRoyalties(uint256 _tokenId)
        external
        view
        returns (LibShare.Share[] memory)
    {
        if (royaltiesByTokenId[_tokenId].set) {
            return royaltiesByTokenId[_tokenId].royalties;
        }
        return collectionRoyalties;
    }

    function _setRoyaltiesArray(
        LibShare.Share[] storage royaltiesArr,
        LibShare.Share[] memory royalties
    ) internal {
        require(royalties.length <= 10);
        uint256 sumRoyalties = 0;
        for (uint256 i = 0; i < royalties.length; i++) {
            require(
                royalties[i].account != address(0x0),
                "Royalty recipient should be present"
            );
            require(royalties[i].value != 0, "Royalty value should be > 0");
            royaltiesArr.push(royalties[i]);
            sumRoyalties += royalties[i].value;
        }
        require(sumRoyalties < 10000, "Sum of Royalties > 100%");
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}

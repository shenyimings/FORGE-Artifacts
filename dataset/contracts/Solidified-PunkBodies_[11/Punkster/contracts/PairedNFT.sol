// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "./interfaces/IERC721Permit.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PairedNFT is ERC721 {
    using SafeMath for uint256;

    IERC721 public immutable token0;
    IERC721 public immutable token1;

    uint256 constant multiplier = 10000; // tokenId = tokenId0 * multiplier + tokenId1

    // Should consider additional check for zero
    mapping(uint256 => uint256) public token0ToTokenId;
    mapping(uint256 => uint256) public token1ToTokenId;

    constructor(address _token0, address _token1, string memory name, string memory symbol, string memory _baseURI)  ERC721(name, symbol) {
        token0 = IERC721(_token0);
        token1 = IERC721(_token1);
        _setBaseURI(_baseURI);
    }

    function mint(uint256 tokenId0, uint256 tokenId1) external {
        token0.transferFrom(msg.sender, address(this), tokenId0);
        token1.transferFrom(msg.sender, address(this), tokenId1);

        _mint(msg.sender, tokenId0, tokenId1);
    }

    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "PairedNFT: caller is not owner nor approved");

        uint256 tokenId0 = tokenId.div(multiplier);
        uint256 tokenId1 = tokenId.mod(multiplier);

        token0.transferFrom(address(this), msg.sender, tokenId0);
        token1.transferFrom(address(this), msg.sender, tokenId1);

        token0ToTokenId[tokenId0] = 0;
        token1ToTokenId[tokenId1] = 0;
        
        _burn(tokenId);
    }

    function _mint(address to, uint256 tokenId0, uint256 tokenId1) internal {
        require(tokenId1 < multiplier);

        uint256 tokenId = tokenId0.mul(multiplier).add(tokenId1);

        token0ToTokenId[tokenId0] = tokenId;
        token1ToTokenId[tokenId1] = tokenId;
        
        _mint(to, tokenId);
    }
}

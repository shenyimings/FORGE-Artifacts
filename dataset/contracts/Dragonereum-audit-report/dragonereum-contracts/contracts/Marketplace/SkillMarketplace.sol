pragma solidity 0.4.25;


import "../Common/Upgradable.sol";
import "../Common/SafeMath256.sol";

contract SkillMarketplace is Upgradable {
    using SafeMath256 for uint256;

    mapping (uint256 => uint256) allTokensIndex;
    mapping (uint256 => uint256) tokenToPrice;

    uint256[] allTokens;

    function _checkTokenExistence(uint256 _id) internal view {
        require(tokenToPrice[_id] > 0, "skill is not on sale");
    }

    function sellToken(
        uint256 _tokenId,
        uint256 _price
    ) external onlyController {
        require(_price > 0, "price must be more than 0");

        if (tokenToPrice[_tokenId] == 0) {
            allTokensIndex[_tokenId] = allTokens.length;
            allTokens.push(_tokenId);
        }
        tokenToPrice[_tokenId] = _price;
    }

    function removeFromAuction(uint256 _tokenId) external onlyController {
        _checkTokenExistence(_tokenId);
        _remove(_tokenId);
    }

    function _remove(uint256 _tokenId) internal {
        require(allTokens.length > 0, "no auctions");

        delete tokenToPrice[_tokenId];

        uint256 tokenIndex = allTokensIndex[_tokenId];
        uint256 lastTokenIndex = allTokens.length.sub(1);
        uint256 lastToken = allTokens[lastTokenIndex];

        allTokens[tokenIndex] = lastToken;
        allTokens[lastTokenIndex] = 0;

        allTokens.length--;
        allTokensIndex[_tokenId] = 0;
        allTokensIndex[lastToken] = tokenIndex;
    }

    // GETTERS

    function getAuction(uint256 _id) external view returns (uint256) {
        _checkTokenExistence(_id);
        return tokenToPrice[_id];
    }

    function getAllTokens() external view returns (uint256[]) {
        return allTokens;
    }

    function totalSupply() public view returns (uint256) {
        return allTokens.length;
    }
}

pragma solidity 0.4.25;


import "../Common/Upgradable.sol";
import "../Common/SafeMath256.sol";

contract Marketplace is Upgradable {
    using SafeMath256 for uint256;

    struct Auction {
        address seller;
        uint256 startPrice;
        uint256 endPrice;
        uint16 period; // in hours
        uint256 created;
        bool isGold; // gold or ether
    }

    uint256 constant MULTIPLIER = 1000000; // for more accurate calculations
    uint16 constant MAX_PERIOD = 8760; // 8760 hours = 1 year

    uint8 constant FLAT_TYPE = 0;
    uint8 constant INCREASING_TYPE = 1;
    uint8 constant DUTCH_TYPE = 2;

    mapping (address => uint256[]) internal ownedTokens;
    mapping (uint256 => uint256) internal ownedTokensIndex;
    mapping (uint256 => uint256) allTokensIndex;
    mapping (uint256 => Auction) tokenToAuction;

    uint256[] allTokens;

    // uint256 onlyGoldDate; // the date from which you can only sell for gold

    constructor() public {
        // TODO: CHANGE BEFORE RELEASE
        // onlyGoldDate = now.add(2 days); // solium-disable-line security/no-block-members
    }

    function sellToken(
        uint256 _tokenId,
        address _seller,
        uint256 _startPrice,
        uint256 _endPrice,
        uint16 _period,
        bool _isGold
    ) external onlyController {
        Auction memory _auction;

        // require(_isGold || now < onlyGoldDate, "now you can only sell for gold"); // solium-disable-line security/no-block-members

        require(_startPrice > 0 && _endPrice > 0, "price must be more than 0");
        if (_startPrice != _endPrice) {
            require(_period > 0 && _period <= MAX_PERIOD, "wrong period value");
        }
        _auction = Auction(_seller, _startPrice, _endPrice, _period, now, _isGold); // solium-disable-line security/no-block-members

        // if auction doesn't exist
        if (tokenToAuction[_tokenId].seller == address(0)) {
            uint256 length = ownedTokens[_seller].length;
            ownedTokens[_seller].push(_tokenId);
            ownedTokensIndex[_tokenId] = length;

            allTokensIndex[_tokenId] = allTokens.length;
            allTokens.push(_tokenId);
        }
        tokenToAuction[_tokenId] = _auction;
    }

    function removeFromAuction(uint256 _tokenId) external onlyController {
        address _seller = tokenToAuction[_tokenId].seller;
        require(_seller != address(0), "token is not on sale");
        _remove(_seller, _tokenId);
    }

    function buyToken(
        uint256 _tokenId,
        uint256 _value,
        uint256 _expectedPrice,
        bool _expectedIsGold
    ) external onlyController returns (uint256 price) {
        Auction memory _auction = tokenToAuction[_tokenId];

        require(_auction.seller != address(0), "invalid address");
        require(_auction.isGold == _expectedIsGold, "wrong currency");
        price = _getCurrentPrice(_tokenId);
        require(price <= _expectedPrice, "wrong price");
        require(price <= _value, "not enough ether/gold");

        _remove(_auction.seller, _tokenId);
    }

    function _remove(address _from, uint256 _tokenId) internal {
        require(allTokens.length > 0, "no auctions");

        delete tokenToAuction[_tokenId];

        _removeFrom(_from, _tokenId);

        uint256 tokenIndex = allTokensIndex[_tokenId];
        uint256 lastTokenIndex = allTokens.length.sub(1);
        uint256 lastToken = allTokens[lastTokenIndex];

        allTokens[tokenIndex] = lastToken;
        allTokens[lastTokenIndex] = 0;

        allTokens.length--;
        allTokensIndex[_tokenId] = 0;
        allTokensIndex[lastToken] = tokenIndex;
    }

    function _removeFrom(address _from, uint256 _tokenId) internal {
        require(ownedTokens[_from].length > 0, "no seller auctions");

        uint256 tokenIndex = ownedTokensIndex[_tokenId];
        uint256 lastTokenIndex = ownedTokens[_from].length.sub(1);
        uint256 lastToken = ownedTokens[_from][lastTokenIndex];

        ownedTokens[_from][tokenIndex] = lastToken;
        ownedTokens[_from][lastTokenIndex] = 0;

        ownedTokens[_from].length--;
        ownedTokensIndex[_tokenId] = 0;
        ownedTokensIndex[lastToken] = tokenIndex;
    }

    function _getCurrentPrice(uint256 _id) internal view returns (uint256) {
        Auction memory _auction = tokenToAuction[_id];
        if (_auction.startPrice == _auction.endPrice) {
            return _auction.startPrice;
        }
        return _calculateCurrentPrice(
            _auction.startPrice,
            _auction.endPrice,
            _auction.period,
            _auction.created
        );
    }

    function _calculateCurrentPrice(
        uint256 _startPrice,
        uint256 _endPrice,
        uint16 _period,
        uint256 _created
    ) internal view returns (uint256) {
        bool isIncreasingType = _startPrice < _endPrice;
        uint256 _fullPeriod = uint256(1 hours).mul(_period); // price changing period
        uint256 _interval = isIncreasingType ? _endPrice.sub(_startPrice) : _startPrice.sub(_endPrice);
        uint256 _pastTime = now.sub(_created); // solium-disable-line security/no-block-members
        if (_pastTime >= _fullPeriod) return _endPrice;
        // how much is _pastTime in percents to period
        uint256 _percent = MULTIPLIER.sub(_fullPeriod.sub(_pastTime).mul(MULTIPLIER).div(_fullPeriod));
        uint256 _diff = _interval.mul(_percent).div(MULTIPLIER);
        return isIncreasingType ? _startPrice.add(_diff) : _startPrice.sub(_diff);
    }

    // GETTERS

    function sellerOf(uint256 _id) external view returns (address) {
        return tokenToAuction[_id].seller;
    }

    function getAuction(uint256 _id) external view returns (
        address, uint256, uint256, uint256, uint16, uint256, bool
    ) {
        Auction memory _auction = tokenToAuction[_id];
        return (
            _auction.seller,
            _getCurrentPrice(_id),
            _auction.startPrice,
            _auction.endPrice,
            _auction.period,
            _auction.created,
            _auction.isGold
        );
    }

    function tokensOfOwner(address _owner) external view returns (uint256[]) {
        return ownedTokens[_owner];
    }

    function getAllTokens() external view returns (uint256[]) {
        return allTokens;
    }

    function totalSupply() public view returns (uint256) {
        return allTokens.length;
    }
}

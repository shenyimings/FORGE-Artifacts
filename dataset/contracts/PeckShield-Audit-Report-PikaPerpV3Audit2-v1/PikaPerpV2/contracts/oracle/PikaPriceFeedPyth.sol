// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "../access/Governable.sol";
import '@pythnetwork/pyth-sdk-solidity/IPyth.sol';
import '@pythnetwork/pyth-sdk-solidity/PythStructs.sol';

contract PikaPriceFeedPyth is Governable {
    using SafeMath for uint256;

    address public owner;
    address public pyth;
    uint256 public priceDuration = 20; // 20 seconds
    mapping (address => uint256) public maxPriceDiffs;
    mapping (address => uint256) public spreads;
    mapping(address => bool) public keepers;
    mapping (address => bytes32) public pythFeedMapping; // productToken => pythPriceFeedId
    mapping (address => bool) public isChainlinkAvailable;
    bool public isSpreadEnabled = false;
    uint256 public defaultMaxPriceDiff = 2e16; // 2%
    uint256 public defaultSpread = 30; // 0.3%

    event PriceSet(address token, uint256 price, uint256 timestamp);
    event PythSet(address pyth);
    event PriceDurationSet(uint256 priceDuration);
    event DefaultMaxPriceDiffSet(uint256 maxPriceDiff);
    event MaxPriceDiffSet(address token, uint256 maxPriceDiff);
    event KeeperSet(address keeper, bool isActive);
    event IsSpreadEnabledSet(bool isSpreadEnabled);
    event DefaultSpreadSet(uint256 defaultSpread);
    event SpreadSet(address token, uint256 spread);
    event IsChainlinkAvailableSet(address productToken, bool isChainlinkAvailable);
    event SetOwner(address owner);

    uint256 public constant MAX_PRICE_DURATION = 30 minutes;
    uint256 public constant PRICE_BASE = 10000;

    constructor() {
        owner = msg.sender;
    }

    function getPrice(address token, bool isMax) external view returns (uint256) {
        (uint256 price, bool isStale) = getPriceAndStaleness(token);
        if (isSpreadEnabled || isStale) {
            uint256 spread = spreads[token] == 0 ? defaultSpread : spreads[token];
            return isMax ? price * (PRICE_BASE + spread) / PRICE_BASE : price * (PRICE_BASE - spread) / PRICE_BASE;
        }
        return price;
    }

    function shouldHaveSpread(address token) external view returns (bool) {
        (,bool isStale) = getPriceAndStaleness(token);
        return isSpreadEnabled || isStale;
    }

    function getPrice(address token) public view returns (uint256) {
        (uint256 price,) = getPriceAndStaleness(token);
        return price;
    }

    function getPriceAndStaleness(address token) public view returns (uint256, bool) {
        (uint256 pythPrice, uint256 publishTime) = _getPythPrice(pythFeedMapping[token]);
        if (isChainlinkAvailable[token]) {
            (uint256 chainlinkPrice, uint256 chainlinkTimestamp) = getChainlinkPrice(token);
            if (block.timestamp > publishTime.add(priceDuration) && chainlinkTimestamp > publishTime.add(priceDuration)) {
                return (chainlinkPrice, true);
            }
            uint256 priceDiff = pythPrice > chainlinkPrice ? (pythPrice.sub(chainlinkPrice)).mul(1e18).div(chainlinkPrice) :
            (chainlinkPrice.sub(pythPrice)).mul(1e18).div(chainlinkPrice);
            uint256 maxPriceDiff = maxPriceDiffs[token] == 0 ? defaultMaxPriceDiff : maxPriceDiffs[token];
            if (priceDiff > maxPriceDiff) {
                return (chainlinkPrice, true);
            }
        }
        return block.timestamp > publishTime.add(priceDuration) ? (pythPrice, true) : (pythPrice, false);
    }

    function getChainlinkPrice(address token) public view returns (uint256 priceToReturn, uint256 chainlinkTimestamp) {
        require(token != address(0), '!feed-error');

        (,int256 price,,uint256 timeStamp,) = AggregatorV3Interface(token).latestRoundData();

        require(price > 0, '!price');
        require(timeStamp > 0, '!timeStamp');
        uint8 decimals = AggregatorV3Interface(token).decimals();
        chainlinkTimestamp = timeStamp;
        if (decimals != 8) {
            priceToReturn = uint256(price) * (10**8) / (10**uint256(decimals));
        } else {
            priceToReturn = uint256(price);
        }
    }

    function getPrices(address[] memory tokens) external view returns (uint256[] memory){
        uint256[] memory curPrices = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            curPrices[i] = getPrice(tokens[i]);
        }
        return curPrices;
    }

    function getLastNPrices(address token, uint256 n) external view returns(uint256[] memory) {
        require(token != address(0), '!feed-error');

        uint256[] memory prices = new uint256[](n);
        uint8 decimals = AggregatorV3Interface(token).decimals();
        (uint80 roundId,,,,) = AggregatorV3Interface(token).latestRoundData();

        for (uint256 i = 0; i < n; i++) {
            (,int256 price,,,) = AggregatorV3Interface(token).getRoundData(roundId - uint80(i));
            require(price > 0, '!price');
            uint256 priceToReturn;
            if (decimals != 8) {
                priceToReturn = uint256(price) * (10**8) / (10**uint256(decimals));
            } else {
                priceToReturn = uint256(price);
            }
            prices[i] = priceToReturn;
        }
        return prices;
    }

    /// @dev Returns pyth price converted to 8 decimals
    function _getPythPrice(bytes32 priceFeedId) private view returns (uint256, uint256) {

        PythStructs.Price memory retrievedPrice = IPyth(pyth).getPriceUnsafe(priceFeedId);
        uint256 baseConversion = 10 ** uint256(int256(18) + retrievedPrice.expo);

        // Convert price to 8 decimals
        uint256 price = uint256(retrievedPrice.price * int256(baseConversion)) / (10 ** 10);
        uint256 publishTime = retrievedPrice.publishTime;

        return (price, publishTime);
    }

    function setPrices(bytes[] calldata priceUpdateData) external payable onlyKeeper {
        uint256 fee = IPyth(pyth).getUpdateFee(priceUpdateData);
        require(msg.value >= fee, '!fee');
        IPyth(pyth).updatePriceFeeds{value: fee}(priceUpdateData);
    }

    function setPyth(address _pyth) external onlyOwner {
        pyth = _pyth;
        emit PythSet(_pyth);
    }

    function setPriceDuration(uint256 _priceDuration) external onlyOwner {
        require(_priceDuration <= MAX_PRICE_DURATION, "!priceDuration");
        priceDuration = _priceDuration;
        emit PriceDurationSet(_priceDuration);
    }

    function setDefaultMaxPriceDiff(uint256 _defaultMaxPriceDiff) external onlyOwner {
        require(_defaultMaxPriceDiff < 3e16, "too big"); // must be smaller than 3%
        defaultMaxPriceDiff = _defaultMaxPriceDiff;
        emit DefaultMaxPriceDiffSet(_defaultMaxPriceDiff);
    }

    function setMaxPriceDiff(address _token, uint256 _maxPriceDiff) external onlyOwner {
        require(_maxPriceDiff < 3e16, "too big"); // must be smaller than 3%
        maxPriceDiffs[_token] = _maxPriceDiff;
        emit MaxPriceDiffSet(_token, _maxPriceDiff);
    }

    function setKeeper(address _keeper, bool _isActive) external onlyOwner {
        keepers[_keeper] = _isActive;
        emit KeeperSet(_keeper, _isActive);
    }

    function setIsSpreadEnabled(bool _isSpreadEnabled) external onlyOwner {
        isSpreadEnabled = _isSpreadEnabled;
        emit IsSpreadEnabledSet(_isSpreadEnabled);
    }

    function setDefaultSpread(uint256 _defaultSpread) external onlyOwner {
        defaultSpread = _defaultSpread;
        emit DefaultSpreadSet(_defaultSpread);
    }

    function setSpread(address _token, uint256 _spread) external onlyOwner {
        spreads[_token] = _spread;
        emit SpreadSet(_token, _spread);
    }

    function setIsChainlinkAvailable(address[] calldata _productTokens, bool[] calldata _isAvailables) external onlyOwner {
        require(_productTokens.length == _isAvailables.length, "not same length");
        for (uint256 i = 0; i < _productTokens.length; i++) {
            isChainlinkAvailable[_productTokens[i]] = _isAvailables[i];
            emit IsChainlinkAvailableSet(_productTokens[i], _isAvailables[i]);
        }
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit SetOwner(_owner);
    }

    modifier onlyKeeper() {
        require(keepers[msg.sender], "!keepers");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }
}

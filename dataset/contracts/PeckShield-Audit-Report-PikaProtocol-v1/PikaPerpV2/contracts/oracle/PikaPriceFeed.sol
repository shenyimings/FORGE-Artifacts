// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "../access/Governable.sol";

contract PikaPriceFeed is Governable {
    using SafeMath for uint256;

    address owner;
    uint256 public lastUpdatedTime;
    uint256 public priceDuration = 600; // 10 mins
    uint256 public updateInterval = 120; // 2 mins
    mapping (address => uint256) public priceMap;
    mapping (address => uint256) public maxPriceDiffs;
    mapping (address => uint256) public spreads;
    mapping (address => uint256) lastUpdatedTimes;
    mapping(address => bool) public keepers;
    mapping (address => bool) public voters;
    mapping (address => bool) public disableFastOracleVotes;
    uint256 public minVoteCount = 2;
    uint256 public disableFastOracleVote;
    bool public isChainlinkOnly = false;
    bool public isPikaOracleOnly = false;
    bool public isSpreadEnabled = false;
    uint256 public delta = 20; // 20bp
    uint256 public decay = 9000; // 0.9
    uint256 public defaultMaxPriceDiff = 2e16; // 2%
    uint256 public defaultSpread = 30; // 0.3%

    event PriceSet(address token, uint256 price, uint256 timestamp);
    event PriceDurationSet(uint256 priceDuration);
    event UpdateIntervalSet(uint256 updateInterval);
    event DefaultMaxPriceDiffSet(uint256 maxPriceDiff);
    event MaxPriceDiffSet(address token, uint256 maxPriceDiff);
    event KeeperSet(address keeper, bool isActive);
    event VoterSet(address voter, bool isActive);
    event DeltaAndDecaySet(uint256 delta, uint256 decay);
    event IsSpreadEnabledSet(bool isSpreadEnabled);
    event DefaultSpreadSet(uint256 defaultSpread);
    event SpreadSet(address token, uint256 spread);
    event IsChainlinkOnlySet(bool isChainlinkOnlySet);
    event IsPikaOracleOnlySet(bool isPikaOracleOnlySet);
    event SetOwner(address owner);
    event DisableFastOracle(address voter);
    event EnableFastOracle(address voter);
    event MinVoteCountSet(uint256 minVoteCount);

    uint256 public constant MAX_PRICE_DURATION = 30 minutes;
    uint256 public constant PRICE_BASE = 10000;

    constructor() {
        owner = msg.sender;
        keepers[msg.sender] = true;
    }

    function getPrice(address token, bool isMax) external view returns (uint256) {
        (uint256 price, bool isChainlink) = getPriceAndSource(token);
        if (isSpreadEnabled || isChainlink || disableFastOracleVote >= minVoteCount) {
            uint256 spread = spreads[token] == 0 ? defaultSpread : spreads[token];
            return isMax ? price * (PRICE_BASE + spread) / PRICE_BASE : price * (PRICE_BASE - spread) / PRICE_BASE;
        }
        return price;
    }

    function shouldHaveSpread(address token) external view returns (bool) {
        (,bool isChainlink) = getPriceAndSource(token);
        return isSpreadEnabled || isChainlink || disableFastOracleVote >= minVoteCount;
    }

    function shouldUpdatePrice() external view returns (bool) {
        return lastUpdatedTime + updateInterval < block.timestamp;
    }

    function shouldUpdatePriceForToken(address token) external view returns (bool) {
        return lastUpdatedTimes[token] + updateInterval < block.timestamp;
    }

    function shouldUpdatePriceForTokens(address[] calldata tokens) external view returns (bool) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (lastUpdatedTimes[tokens[i]] + updateInterval < block.timestamp) {
                return true;
            }
        }
        return false;
    }

    function getPrice(address token) public view returns (uint256) {
        (uint256 price,) = getPriceAndSource(token);
        return price;
    }

    function getPriceAndSource(address token) public view returns (uint256, bool) {
        (uint256 chainlinkPrice, uint256 chainlinkTimestamp) = getChainlinkPrice(token);
        if (isChainlinkOnly || (!isPikaOracleOnly && (block.timestamp > lastUpdatedTimes[token].add(priceDuration) && chainlinkTimestamp > lastUpdatedTimes[token]))) {
            return (chainlinkPrice, true);
        }
        uint256 pikaPrice = priceMap[token];
        uint256 priceDiff = pikaPrice > chainlinkPrice ? (pikaPrice.sub(chainlinkPrice)).mul(1e18).div(chainlinkPrice) :
            (chainlinkPrice.sub(pikaPrice)).mul(1e18).div(chainlinkPrice);
        uint256 maxPriceDiff = maxPriceDiffs[token] == 0 ? defaultMaxPriceDiff : maxPriceDiffs[token];
        if (priceDiff > maxPriceDiff) {
            return (chainlinkPrice, true);
        }
        return (pikaPrice, false);
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

    function setPrices(address[] memory tokens, uint256[] memory prices) external onlyKeeper {
        require(tokens.length == prices.length, "!length");
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            priceMap[token] = prices[i];
            lastUpdatedTimes[token] = block.timestamp;
            emit PriceSet(token, prices[i], block.timestamp);
        }
        lastUpdatedTime = block.timestamp;
    }

    function disableFastOracle() external onlyVoter {
        require(!disableFastOracleVotes[msg.sender], "already voted");
        disableFastOracleVotes[msg.sender] = true;
        disableFastOracleVote = disableFastOracleVote + 1;

        emit DisableFastOracle(msg.sender);
    }

    function enableFastOracle() external onlyVoter {
        require(disableFastOracleVotes[msg.sender], "already enabled");
        disableFastOracleVotes[msg.sender] = false;
        disableFastOracleVote = disableFastOracleVote - 1;

        emit EnableFastOracle(msg.sender);
    }

    function setMinVoteCount(uint256 _minVoteCount) external onlyOwner {
        minVoteCount = _minVoteCount;

        emit MinVoteCountSet(_minVoteCount);
    }

    function setPriceDuration(uint256 _priceDuration) external onlyOwner {
        require(_priceDuration <= MAX_PRICE_DURATION, "!priceDuration");
        priceDuration = _priceDuration;
        emit PriceDurationSet(_priceDuration);
    }

    function setUpdatedInterval(uint256 _updateInterval) external onlyOwner {
        updateInterval = _updateInterval;
        emit UpdateIntervalSet(_updateInterval);
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

    function setVoter(address _voter, bool _isActive) external onlyOwner {
        voters[_voter] = _isActive;
        emit VoterSet(_voter, _isActive);
    }

    function setIsChainlinkOnly(bool _isChainlinkOnly) external onlyOwner {
        isChainlinkOnly = _isChainlinkOnly;
        emit IsChainlinkOnlySet(isChainlinkOnly);
    }

    function setIsPikaOracleOnly(bool _isPikaOracleOnly) external onlyOwner {
        isPikaOracleOnly = _isPikaOracleOnly;
        emit IsPikaOracleOnlySet(isPikaOracleOnly);
    }

    function setDeltaAndDecay(uint256 _delta, uint256 _decay) external onlyOwner {
        delta = _delta;
        decay = _decay;
        emit DeltaAndDecaySet(delta, decay);
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

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit SetOwner(_owner);
    }

    modifier onlyVoter() {
        require(voters[msg.sender], "!voter");
        _;
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

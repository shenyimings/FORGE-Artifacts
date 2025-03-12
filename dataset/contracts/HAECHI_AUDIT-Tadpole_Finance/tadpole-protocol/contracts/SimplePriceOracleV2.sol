pragma solidity ^0.5.16;

import "./PriceOracle.sol";
import "./CErc20.sol";
import "./EIP20Interface.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/ownership/Ownable.sol";
import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV3Interface.sol";

contract SimplePriceOracleV2 is Ownable, PriceOracle {
    mapping (address => uint)    public prices;
    mapping (address => address) public chainlinkFeed;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);

    constructor() public {
        // USDT
        prices[0x55d398326f99059fF775485246999027B3197955] = 1000000000000000000;
        // BUSD
        prices[0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56] = 1000000000000000000;

        // Chainlink Feeds
        // BNB
        chainlinkFeed[0x0000000000000000000000000000000000000000] = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
        // USDT
        chainlinkFeed[0x55d398326f99059fF775485246999027B3197955] = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320;
        // BUSD
        chainlinkFeed[0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56] = 0xcBb98864Ef56E9042e7d2efef76141f15731B82f;
    }

    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        address underlying = underlyingAddress(cToken);

        if (chainlinkFeed[underlying] != address(0)) {
            uint tokenDecimals = 18;
            if (underlying != address(0)) {
                tokenDecimals = EIP20Interface(underlying).decimals();
            }
            return getChainlinkPrice(chainlinkFeed[underlying], tokenDecimals);

        } else {
            return prices[underlying];
        }
    }

    function getChainlinkPrice(address chainlinkFeedAddress, uint tokenDecimals) public view returns(uint) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(chainlinkFeedAddress);
        (
            /*uint80 roundID*/,
            int256 price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        uint8 decimals = priceFeed.decimals();
        uint priceMantissa = uint(price);
        
        priceMantissa = priceMantissa * 10**(36 - uint(decimals) - tokenDecimals);

        return priceMantissa;
    }

    function setChainlinkFeed(CToken cToken, address chainlinkFeedAddress) external onlyOwner {
        chainlinkFeed[underlyingAddress(cToken)] = chainlinkFeedAddress;
    }

    function setUnderlyingChainlinkFeed(address underlying, address chainlinkFeedAddress) external onlyOwner {
        chainlinkFeed[underlying] = chainlinkFeedAddress;
    }

    function setUnderlyingPrice(CToken cToken, uint underlyingPriceMantissa) public onlyOwner {
        address asset = underlyingAddress(cToken);
        setDirectPrice(asset, underlyingPriceMantissa);
    }

    function setUnderlyingPriceBatch(CToken[] memory cTokens, uint[] memory newPrices) public onlyOwner {
        for ( uint i = 0; i < cTokens.length; i++ ) {
            address asset = underlyingAddress(cTokens[i]);
            setDirectPrice(asset, newPrices[i]);
        }
    }

    function setDirectPrice(address asset, uint price) public onlyOwner {
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    // v1 price oracle interface for use as backing of proxy
    function assetPrices(address asset) external view returns (uint) {
        if (chainlinkFeed[asset] != address(0)) {
            uint tokenDecimals = 18;
            if (asset != address(0)) {
                tokenDecimals = EIP20Interface(asset).decimals();
            }
            return getChainlinkPrice(chainlinkFeed[asset], tokenDecimals);
        }
        return prices[asset];
    }

    function underlyingAddress(CToken cToken) internal view returns (address) {
        if (compareStrings(cToken.symbol(), "tadBNB")) {
            return address(0);
        }
        return address(CErc20(address(cToken)).underlying());
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}



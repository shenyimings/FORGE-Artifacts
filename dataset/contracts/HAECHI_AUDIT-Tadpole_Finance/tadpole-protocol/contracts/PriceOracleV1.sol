pragma solidity ^0.5.16;

import "./PriceOracle.sol";
import "./CErc20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract PriceOracleV1 is Ownable, PriceOracle {
    mapping(address => uint) prices;
    mapping(address => bool) reporters;
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);

    function senderMustBeReporter() internal{
        require(reporters[msg.sender] == true, "Sender is not an allowed reporter");
    }

    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        if (compareStrings(cToken.symbol(), "cETH")) {
            return prices[address(0)]; //consider 0x0 address as ETH
        } else {
            return prices[address(CErc20(address(cToken)).underlying())];
        }
    }

    function setUnderlyingPrice(CToken cToken, uint underlyingPriceMantissa) internal {

        if (compareStrings(cToken.symbol(), "cETH")) {
            address asset = address(0);
        }
        else {
            address asset = address(CErc20(address(cToken)).underlying());
        }
        emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
        prices[asset] = underlyingPriceMantissa;
    }

    function setDirectPrice(address asset, uint price) internal {

        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    function setUnderlyingPrices(CToken[] memory cTokens, uint[] memory underlyingPricesMantissa) public {
        
        senderMustBeReporter();

        require(cTokens.length == underlyingPricesMantissa.length, "cTokens and underlyingPricesMantissa must be the same length");
        for(uint index=0; index<cTokens.length; index++){
            setUnderlyingPrice(cTokens[index], underlyingPricesMantissa[index]);
        }
    }

    function setDirectPrices(address[] memory assets, uint[] memory prices) public {
        
        senderMustBeReporter();

        require(cTokens.length == underlyingPricesMantissa.length, "cTokens and underlyingPricesMantissa must be the same length");
        for(uint index=0; index<assets.length; index++){
            setDirectPrice(assets[index], prices[index]);
        }
    }

    // v1 price oracle interface for use as backing of proxy
    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    //only owner can set or delete a reporter
    function setReporter(address reporter) public onlyOwner{
        reporters[reporter] = true;
    }

    //only owner can set or delete a reporter
    function deleteReporter(address reporter) public onlyOwner{
        reporters[reporter] = false;
        delete reporters[reporter];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}

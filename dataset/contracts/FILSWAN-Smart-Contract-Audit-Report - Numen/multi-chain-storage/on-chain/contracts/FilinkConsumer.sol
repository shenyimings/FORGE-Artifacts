// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/access/Ownable.sol";

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice get filecoin storage price for deal
contract FilinkConsumer is ChainlinkClient, Ownable {
    using Chainlink for Chainlink.Request;
  
    mapping(bytes32 => string) private mapRequestDeal;
    mapping(string => uint256) private mapDealPrice;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    uint256 public price;

    /**
     * LINK Token address: 0xb0897686c545045afc77cf20ec7a532e3120e0f1
     * Oracle address: 0x3d5552a177Fe380CDDe28a034EA93C2d30b80b2D
     * Fee: 0.1 LINK
     */
    constructor(address _chainlinkToken, address _oracle, uint256 _fee) {
        setChainlinkToken(_chainlinkToken);
        setChainlinkOracle(_oracle);
        oracle = _oracle;
        jobId = "a052732022e04e89be3e0fc06e457985";
        fee = _fee; // (Varies by network and job)
    }

    function concatenate(
        string memory s1,
        string memory s2
    ) private pure returns (string memory) {
        return string(abi.encodePacked(s1, s2));
    }
    
    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */

    /// @notice Creates a Chainlink GET request to retrieve storage_price of given deal and network
    function requestDealInfo(string calldata deal, string calldata network) public returns (bytes32 requestId) {
        require(mapDealPrice[deal] == 0, "deal price is already on-chain, call getPrice(deal)");

        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        // <deal>?network=<network>
        string memory tmp = concatenate(deal, "?network=");
        string memory params = concatenate(tmp, network);

        string memory key = concatenate(deal, network);
        
        /**
         * GET https://flink-adapter.filswan.com/deal/<deal>?network=<network>
         * ex. GET https://flink-adapter.filswan.com/deal/123456?network=filecoin_mainnet, data.deal.storage_price = 42855481110
         */ 
        request.add("get", concatenate("https://flink-adapter.filswan.com/deal/", params));
        request.add("path", "data,deal,storage_price");
        request.addInt('times', 1);
        
        bytes32 id = sendChainlinkRequestTo(oracle, request, fee);
        mapRequestDeal[id] = key;

        return id;
    }
    
    
    /// @dev Chainlink oracle will call this function to set the price
    function fulfill( bytes32  _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId) {
        price = _price;
        mapDealPrice[mapRequestDeal[_requestId]] = _price;
    }

    /// @notice get the storage price for given deal and network
    function getPrice(string calldata deal, string calldata network) public view returns (uint256) {
        string memory key = concatenate(deal, network);
        return mapDealPrice[key];
    }

    function withdrawTokens(address tokenAddress) public onlyOwner {
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(msg.sender, balance);
    }
}
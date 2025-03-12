
pragma solidity ^0.6.7;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./strings.sol";

contract HistoricalPriceConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using strings for *;

    uint256 constant private PHASE_OFFSET = 64;

    AggregatorV3Interface internal priceFeed;
    address private proxyAddress;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    uint private searchTimestamp;

    uint80 public answerRound;
    uint80 public previousRound;
    uint80 public nextRound;

    int public priceAnswer;
    uint public priceTimestamp;

    int public previousPrice;
    uint public previousPriceTimestamp;

    int public nextPrice;
    uint public nextPriceTimestamp;

    constructor() public {
        setPublicChainlinkToken();
        //set oracle and jobId to the deployed adapter and job run by LinkRiver
        oracle = 0xF405B99ACa8578B9eb989ee2b69D518aaDb90c1F;
        jobId = "cc69bee28b51437197ef15387645236e";
        fee = 0; // 0.1 * 10 ** 18; // 0.1 LINK

    }

    /**
     * Returns historical price for a unix epoch time and proxy address
     *

      "aggregatorAddress": "0x9326BFA02ADD2366b30bacB125260Af641031331",
      "unixDateTime": 1612137600,
      "ISODateTime": "2021-02-01 00:00:00"

     */
    function getHistoricalPrice(address _proxyAddress, uint _unixTime) public returns (bytes32 requestId)
    {

        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.singleResponseFulfill.selector);

        // Set the URL to perform the GET request on
        request.add("proxyAddress", addressToString(_proxyAddress));
        request.add("unixDateTime", uint2str(_unixTime));


        //set the timestamp being searched, we will use it for verification after
        searchTimestamp = _unixTime;

        //create proxy contract to be used in the verification
        proxyAddress = _proxyAddress;
        priceFeed = AggregatorV3Interface(proxyAddress);

        //reset any previous values
        answerRound = 0;
        previousRound = 0;
        nextRound = 0;
        nextPrice = 0;
        nextPriceTimestamp = 0;
        previousPrice = 0;
        previousPriceTimestamp = 0;
        priceAnswer = 0;
        priceTimestamp = 0;


        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }

   function multiResponseFulfill(bytes32 _requestId, uint80 _answerRound, uint80 _previousRound, uint80 _nextRound) public recordChainlinkFulfillment(_requestId)
    {
        answerRound = _answerRound;
        previousRound = _previousRound;
        nextRound = _nextRound;

        //verify the responses
        //first get back the responses for each round
        (
            uint80 id,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.getRoundData(_answerRound);
        require(timeStamp > 0, "Round not complete");
        priceAnswer = price;
        priceTimestamp = timeStamp;

        (
             id,
             price,
             startedAt,
             timeStamp,
             answeredInRound
        ) = priceFeed.getRoundData(_previousRound);
        require(timeStamp > 0, "Round not complete");
        previousPrice = price;
        previousPriceTimestamp = timeStamp;

        (
             id,
             price,
             startedAt,
             timeStamp,
             answeredInRound
        ) = priceFeed.getRoundData(_nextRound);
        require(timeStamp > 0, "Round not complete");
        nextPrice = price;
        nextPriceTimestamp = timeStamp;


        //first, make sure order of rounds is correct
        require(previousPriceTimestamp < timeStamp, "Previous price timetamp must be < answer timestamp");
        require(timeStamp < nextPriceTimestamp, "Answer timetamp must be < next round timestamp");

        //next, make sure prev round is before timestamp that was searched, and next round is after
        require(previousPriceTimestamp < searchTimestamp, "Previous price timetamp must be < search timestamp");
        require(searchTimestamp < nextPriceTimestamp, "Search timetamp must be < next round timestamp");

        //check if gaps in round numbers, and if so, ensure there's no valid data in between
        if (answerRound - previousRound > 1) {
            for (uint80 i= previousRound; i<answerRound; i++) {
                (uint80 id,
                int price,
                uint startedAt,
                uint timeStamp,
                uint80 answeredInRound
                ) = priceFeed.getRoundData(i);
                require(timeStamp == 0, "Missing Round Data");
            }
        }

        if (nextRound - answerRound > 1) {
            for (uint80 i= answerRound; i<nextRound; i++) {
                (uint80 id,
                int price,
                uint startedAt,
                uint timeStamp,
                uint80 answeredInRound
                ) = priceFeed.getRoundData(i);
                require(timeStamp == 0, "Missing Round Data");
            }
        }

        //if the checks above all passed, it means verification is successful, the correct answer is stored in priceAnswer

    }

    function singleResponseFulfill(bytes32 _requestId, bytes32 _oracleResponse) public recordChainlinkFulfillment(_requestId)
    {


        //aggregator phase number and round responses are in a delimited string. we need to strip them out first
        uint phaseId;
        uint roundIdAgg;
        uint prevRoundAgg;
        uint nextRoundAgg;

        //strip out the response JSON into individual strings
        (phaseId, roundIdAgg, prevRoundAgg, nextRoundAgg) = parseResponse(_oracleResponse);


        //now we need to convert these rounds all back to phased roundIds
        answerRound = uint80(uint256(phaseId) << PHASE_OFFSET | roundIdAgg);
        previousRound = uint80(uint256(phaseId) << PHASE_OFFSET | prevRoundAgg);
        nextRound = uint80(uint256(phaseId) << PHASE_OFFSET | nextRoundAgg);



        //verify the responses

        //first get back the responses for each round and make sure its > 0 (ie a valid round)
        (
            uint80 id,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.getRoundData(answerRound);
        require(timeStamp > 0, "Round not complete");
        priceAnswer = price;
        priceTimestamp = timeStamp;

        (
             id,
             price,
             startedAt,
             timeStamp,
             answeredInRound
        ) = priceFeed.getRoundData(previousRound);
        require(timeStamp > 0, "Round not complete");
        previousPrice = price;
        previousPriceTimestamp = timeStamp;

        (
             id,
             price,
             startedAt,
             timeStamp,
             answeredInRound
        ) = priceFeed.getRoundData(nextRound);
        require(timeStamp > 0, "Round not complete");
        nextPrice = price;
        nextPriceTimestamp = timeStamp;


        //next, make sure order of rounds is correct
        require(previousPriceTimestamp < priceTimestamp, "Previous price timetamp must be less than answer timestamp");
        require(priceTimestamp < nextPriceTimestamp, "Answer timetamp must be less than next round timestamp");


        //next, make sure prev round is before timestamp that was searched, and next round is after, and answer timestamp is <= search timestamp
        require(previousPriceTimestamp < searchTimestamp, "Previous price timetamp must be less than search timestamp");
        require(searchTimestamp < nextPriceTimestamp, "Search timetamp must be less than next round timestamp");
        require(priceTimestamp <= searchTimestamp, "Answer timetamp must be less than or equal to searchTimestamp timestamp");

        //check if gaps in round numbers, and if so, ensure there's no valid data in between
        if (answerRound - previousRound > 1) {
            for (uint80 i= previousRound; i<answerRound; i++) {
                (uint80 id,
                int price,
                uint startedAt,
                uint timeStamp,
                uint80 answeredInRound
                ) = priceFeed.getRoundData(i);
                require(timeStamp == 0, "Missing Round Data");
            }
        }

        if (nextRound - answerRound > 1) {
            for (uint80 i= answerRound; i<nextRound; i++) {
                (uint80 id,
                int price,
                uint startedAt,
                uint timeStamp,
                uint80 answeredInRound
                ) = priceFeed.getRoundData(i);
                require(timeStamp == 0, "Missing Round Data");
            }
        }

        //if the checks above all passed, it means verification is successful, the correct answer is stored in priceAnswer

    }

    function parseResponse (bytes32 _response) public pure returns (uint phaseId, uint roundAnswer, uint prevRound, uint nextRound) {
        uint phaseId;
        uint roundId;
        uint prevRound;
        uint nextRound;

        strings.slice memory s = string(abi.encodePacked(_response)).toSlice();//  bytes32ToString(_response).toSlice();
        strings.slice memory delim = ",".toSlice();

        //store each string in an array
        string[] memory splitResults = new string[](s.count(delim)+ 1);
        for (uint i = 0; i < splitResults.length; i++) {
           splitResults[i] = s.split(delim).toString();
        }

        //Now for each one, convert to uint
        phaseId = stringToUint(splitResults[0]);
        roundId = stringToUint(splitResults[1]);
        prevRound = stringToUint(splitResults[2]);
        nextRound = stringToUint(splitResults[3]);

        return (phaseId, roundId, prevRound, nextRound);
    }

    function getSearchTimestamp() public view returns (uint) {
        return searchTimestamp;
    }

    function getProxyContract() public view returns (string memory) {
        return addressToString(proxyAddress);
    }

    function uint2str(uint256 _i) internal pure returns (string memory str)
    {
    if (_i == 0)
    {
        return "0";
    }
    uint256 j = _i;
    uint256 length;
    while (j != 0)
    {
        length++;
        j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length;
    j = _i;
    while (j != 0)
    {
        bstr[--k] = bytes1(uint8(48 + j % 10));
        j /= 10;
    }
    str = string(bstr);
    }

    function stringToUint(string memory s) public pure returns (uint result) {
        bytes memory b = bytes(s);
        uint i;
        result = 0;

        for (i = 0; i < b.length; i++) {
            uint c = uint(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }

    function addressToString(address _address) public pure returns(string memory) {
       bytes32 _bytes = bytes32(uint256(_address));
       bytes memory HEX = "0123456789abcdef";
       bytes memory _string = new bytes(42);
       _string[0] = '0';
       _string[1] = 'x';
       for(uint i = 0; i < 20; i++) {
           _string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
           _string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
       }
       return string(_string);
    }

}



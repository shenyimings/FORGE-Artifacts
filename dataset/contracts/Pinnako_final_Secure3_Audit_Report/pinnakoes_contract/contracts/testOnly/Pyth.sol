// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";



interface PythStructs {
    struct Price {
        int64 price;// Price
        uint64 conf;// Confidence interval around the price
        int32 expo;// Price exponent
        uint publishTime;// Unix timestamp describing when the price was published
    }
    // PriceFeed represents a current aggregate price from pyth publisher feeds.
    struct PriceFeed {
        bytes32 id;// The price ID.
        Price price;// Latest available price
        Price emaPrice;// Latest available exponentially-weighted moving average price
    }
}

interface IPyth {
    function queryPriceFeed(bytes32 id) external view returns (PythStructs.Price memory price);
    function priceFeedExists(bytes32 id) external view returns (bool exists);
    function getValidTimePeriod() external view returns(uint validTimePeriod);
    function getPrice(bytes32 id) external view returns (PythStructs.Price memory price);
    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
    function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price);
}


// contract Pyth {
//     using SafeMath for uint256;
    
//     function queryPriceFeed(bytes32 id) external view returns (PythStructs.Price memory price){
//         PythStructs.Price memory _price;
//         return _price;
//     }

//     function priceFeedExists(bytes32 id) external view returns (bool exists){
//         return true;
//     }
//     function getPrice(bytes32 id) external view returns (PythStructs.Price memory price){
//         PythStructs.Price memory _price;
//         return _price;
//     }
//     function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price){
//         PythStructs.Price memory _price;
//         return _price;
//     }
//     function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price){
//         PythStructs.Price memory _price;
//         return _price;
//     }

// }

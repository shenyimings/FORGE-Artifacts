// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../interfaces/pyth/PythStructs.sol";

// Pyth mock contract for local test
contract PythMock {
    mapping(bytes32 => PythStructs.Price) private prices;
    bool public autoRefresh;

    function setAutoRefresh(bool _autoRefresh) external {
        autoRefresh = _autoRefresh;
    }

    function getUpdateFee(bytes[] calldata) external pure returns (uint) {
        // 1 wei
        return 1;
    }

    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
        require(prices[id].publishTime > 0, "PythMock: no price");
        if (!autoRefresh) {
            return prices[id];
        } else {
            price = prices[id];
            price.publishTime = block.timestamp + 1;
            return price;
        }
    }

    function updatePriceFeeds(bytes[] calldata updateData) external payable {
        require(msg.value == 1, "PythMock: fee insufficient");
        for (uint i = 0; i < updateData.length; ++i) {
            (bytes32 id, int64 price, int32 expo, uint publishTime) = abi.decode(
                updateData[i],
                (bytes32, int64, int32, uint)
            );
            if (publishTime >= prices[id].publishTime) {
                prices[id] = PythStructs.Price(price, 0, expo, publishTime);
            }
        }
    }
}

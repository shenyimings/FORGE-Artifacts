// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./PriceOracle.sol";
import "./CErc20.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract SimplePriceOracle is PriceOracle {
    IPyth immutable pyth;

    constructor(IPyth pyth_) {
        pyth = pyth_;
    }

    function _getPrice(
        CToken cToken
    ) internal view returns (PythStructs.Price memory) {
        return pyth.getPriceNoOlderThan(cToken.pythFeedID(), 24 * 60 * 60);
    }

    function getUnderlyingPrice(
        CToken cToken
    ) public view override returns (uint) {
        PythStructs.Price memory price = _getPrice(cToken);
        require(price.expo >= -18, "price too precise");
        return (uint256(uint64(price.price)) *
            (10 **
                uint256(
                    uint32(36 - int32(uint32(cToken.decimals())) + price.expo)
                )));
    }
}

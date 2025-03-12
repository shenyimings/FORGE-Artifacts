pragma solidity 0.4.25;

import "./TRC20Interface.sol";

interface ExpectedRateInterface {
    function getExpectedRate(TRC20 src, TRC20 dest, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);
    function getExpectedFeeRate(TRC20 token, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);
}

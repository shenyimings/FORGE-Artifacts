pragma solidity ^0.6.2;

import "../core/CookDistribution.sol";
import "../oracle/IOracle.sol";

contract MockCookDistribution is CookDistribution {
    uint256 internal _today;

    constructor(
        IERC20 token_,
        address[] memory beneficiaries_,
        uint256[] memory amounts_,
        uint256 start, // in unix
        uint256 duration, // in day
        uint32 interval, // in day
        address oracle_,
        address priceConsumer_
    )
        public
        CookDistribution(
            token_,
            beneficiaries_,
            amounts_,
            start,
            duration,
            interval,
            oracle_,
            priceConsumer_
        )
    {}

    function setToday(uint256 dayNumber) public {
        _today = dayNumber;
    }

    function today() public view override returns (uint256 dayNumber) {
        return _today;
    }
}

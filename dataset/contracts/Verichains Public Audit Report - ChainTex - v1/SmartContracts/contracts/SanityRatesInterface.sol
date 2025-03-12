pragma solidity 0.4.25;


import "./TRC20Interface.sol";

interface SanityRatesInterface {
    function getSanityRate(TRC20 src, TRC20 dest) external view returns(uint);
}

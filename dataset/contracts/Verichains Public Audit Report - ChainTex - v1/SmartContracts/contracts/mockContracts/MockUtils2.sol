pragma solidity 0.4.25;


import "../Utils2.sol";


/// @title Utils2 contract
contract MockUtils2 is Utils2 {
    function mockGetDecimalsSafe(TRC20 token) public view returns(uint) {
        return decimals[token];
    }

    function mockSetDecimalsSafe(TRC20 token) public {
        setDecimals(token);
    }

    function mockCalcRateFromQty(uint srcAmount, uint destAmount, uint srcDecimals, uint dstDecimals)
        public pure returns(uint rateResult)
    {
        rateResult = calcRateFromQty(srcAmount, destAmount, srcDecimals, dstDecimals);
    }
}

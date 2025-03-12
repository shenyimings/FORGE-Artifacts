/*
MIT License

Copyright (c) 2021 Reflexer Labs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

pragma solidity 0.6.7;

import "./GebUniswapV3ManagerBase.sol";

abstract contract OracleLike {
    function priceSource() virtual public view returns (address);
    function getResultWithValidity() virtual public view returns (uint256, bool);
}
 abstract contract OracleRelayerLike {
    function redemptionPrice() virtual public returns (uint256);
    function collateralTypes(bytes32) virtual public view returns (
        OracleLike orcl,
        uint256 safetyCRatio,
        uint256 liquidationCRatio
    );
}

contract GebUniswapV3OracleAdapter is OracleForUniswapLike {
    // --- Constants ---
    uint256           public constant WAD_COMPLEMENT = 10 ** 9;
    OracleRelayerLike public immutable oracleRelayer;
    bytes32           public immutable collateral;

    /**
     * @notice Constructor that sets initial parameters for this contract
     * @param _oracleRelayer The address of the oracleRelayer
     * @param _collateral The collateral for this oracle
     */
    constructor(OracleRelayerLike _oracleRelayer, bytes32 _collateral) public {
        oracleRelayer = _oracleRelayer;
        collateral = _collateral;
    }

     /**
     * @notice Function to get both the redemption price and the other pool token's price
     * @return redemptionPrice a WAD representing the redemption price
     * @return collateralPrice a WAD representing the collateral price
     * @return valid a boolean indicating weather the contract is valid
     */
    function getResultsWithValidity() public override returns (uint256, uint256, bool){
        uint256 redemptionPrice = oracleRelayer.redemptionPrice();

        (OracleLike priceSource, , ) = oracleRelayer.collateralTypes(collateral);

        (uint256 collateralPrice, bool valid) = priceSource.getResultWithValidity();
        require(valid, "GebUniswapV3LiquidityManager/invalid-col-price-feed");

        return (redemptionPrice / WAD_COMPLEMENT, collateralPrice, true);
    }
}

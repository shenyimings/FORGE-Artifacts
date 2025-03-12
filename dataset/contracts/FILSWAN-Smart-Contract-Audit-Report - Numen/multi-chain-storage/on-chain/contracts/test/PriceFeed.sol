//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "../interfaces/IPriceFeed.sol";

/// @notice convert price between two tokens
contract PriceFeed is IPriceFeed {

    using SafeMath for uint112;
    using SafeMath for uint256;

    address private _dexPair;

    uint8 private _tokenIndex; // wfil token address index in the pair
    uint8 public _decimal;
    uint8 private TEMP_DECIMAL = 15;

    /// @param dexPair Uniswap LP Token address
    /// @param tokenIndex index of the input token
    /// @param decimal decimal of the output token
    constructor(address dexPair, uint8 tokenIndex, uint8 decimal) {
        _dexPair = dexPair;
        _tokenIndex = tokenIndex;
        _decimal = decimal;
    }

    // how many tokens of tokenIput are equal amount of wfil
    /// @notice converts amount of tokenIndex token to the other token
    function consult(
        address tokenInput,
        uint256 amount
    ) external 
    override
    view returns (uint256){
        require(amount>0, "amount must greater than 0");
        (uint112 _reserve0, uint112 _reserve1, ) = IUniswapV2Pair(_dexPair).getReserves();

        uint256 cp = uint(_reserve0).mul(_reserve1);
        uint256 retAmount = 0;

        if(_tokenIndex == 0){
            uint256 tAmt = _reserve0.sub(10**TEMP_DECIMAL);
            require(tAmt>0, "not enough token to return");
            uint256 amt = cp.div(tAmt);
            retAmount = amt.sub(_reserve1);
        }else if(_tokenIndex == 1){
            uint256 tAmt = _reserve1.sub(10**TEMP_DECIMAL);
            require(tAmt>0, "not enough token to return");
            uint256 amt = cp.div(tAmt);
            retAmount = amt.sub(_reserve0);
        }
        // we use 0.001(10^15) because the LP is small, so we multiply 10^3 afterwards.
        // we multiply 10^12 because USDC has 6 decimal instead of 18
        // now we have the price of 1 WFIL, so we multiply by amount / 18 decimals
        // convert 0.001 WFIL to USD * 10^12 * 10^3 * amount / 10^18
        // return retAmount.mul(10**(18-TEMP_DECIMAL)).mul(10**(18-_decimal)).mul(amount).div(10**18);
        return retAmount.mul(10**(18-TEMP_DECIMAL)).mul(amount).div(10**(18-_decimal));
    }
}
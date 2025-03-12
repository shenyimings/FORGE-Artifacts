// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/*

    ███████╗██████╗  █████╗ ███╗   ██╗██╗  ██╗███████╗███╗   ██╗███████╗████████╗███████╗██╗███╗   ██╗
    ██╔════╝██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝██╔════╝████╗  ██║██╔════╝╚══██╔══╝██╔════╝██║████╗  ██║
    █████╗  ██████╔╝███████║██╔██╗ ██║█████╔╝ █████╗  ██╔██╗ ██║███████╗   ██║   █████╗  ██║██╔██╗ ██║
    ██╔══╝  ██╔══██╗██╔══██║██║╚██╗██║██╔═██╗ ██╔══╝  ██║╚██╗██║╚════██║   ██║   ██╔══╝  ██║██║╚██╗██║
    ██║     ██║  ██║██║  ██║██║ ╚████║██║  ██╗███████╗██║ ╚████║███████║   ██║   ███████╗██║██║ ╚████║
    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚══════╝╚═╝╚═╝  ╚═══╝
                                                                      
    Website: https://frankenstein.finance/
    twitter: https://twitter.com/FrankenDefi
*/

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IHelp.sol";

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract GetPricesFTM  {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // WBNB token address
    IERC20 private constant WBNB = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    // BUSD token address
    IERC20 private constant BUSD = IERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);    
    // Lp BNB_BUSD_POOL token address
    address private constant BNB_BUSD_POOL = 0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c;

    // Returns the price of bnb in usd
    function bnbPriceInUSD() public view returns(uint) {
        uint _busd = BUSD.balanceOf(BNB_BUSD_POOL).mul(1e18);
        uint _wbnb = WBNB.balanceOf(BNB_BUSD_POOL).mul(1e6);
        return _busd.mul(1e18).div(_wbnb);
    }

    // Returns the price of a token in BNB
    function tokenPriceInBNB(address _token, IFactory factory) public view returns(uint) {
        address pair = factory.getPair(_token, address(WBNB));
        uint decimal = uint(ERC20(_token).decimals());
        return WBNB.balanceOf(pair).mul(10**decimal).div(IERC20(_token).balanceOf(pair));
    }

    // Returns the price of a token in BNB
    function priceInBNB(address _token, address pair) public view returns(uint) {
        return WBNB.balanceOf(pair).mul(1e18).div(IERC20(_token).balanceOf(pair));
    }    

    // Returns the price of a token in usd
    function tokenPriceInUSD(address _token, IFactory factory) public view returns(uint) {
        uint _priceInBNB = tokenPriceInBNB(_token, factory);
        uint priceBNB = bnbPriceInUSD();
        return priceBNB.mul(_priceInBNB);
    }  

}
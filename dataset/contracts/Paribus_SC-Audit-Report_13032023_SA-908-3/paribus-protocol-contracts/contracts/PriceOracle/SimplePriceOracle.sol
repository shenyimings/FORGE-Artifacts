// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "./Impl/StablecoinsPriceOracle.sol";
import "../Utils/Ownable.sol";

// SimplePriceOracle contract is used in unit tests only and allows to set the prices manually
// use StablecoinsPriceOracle here to simplify implementation, just add the setUnderlyingPrice function with proper decimals calculation
contract SimplePriceOracle is StablecoinsPriceOracle, Ownable {
    function getUnderlyingDecimalsAndAddress(PToken pToken) public view returns (uint256, address) {
        if (compareStrings(pToken.symbol(), "pETH")) return (18, address(0));

        else {
            PErc20 pErc20 = PErc20(address(pToken));
            return (EIP20Interface(pErc20.underlying()).decimals(), pErc20.underlying());
        }
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    /**
      * @notice Admin function to set the new price for a given pToken
      * @param pToken The token
      * @param underlyingPriceMantissa The new price. Expected decimals: 36 - underlying decimals
      */
    function setUnderlyingPrice(PToken pToken, uint underlyingPriceMantissa) public onlyOwner {
        (uint underlyingDecimals, address underlyingAddress) = getUnderlyingDecimalsAndAddress(pToken);
        stablecoinsPrices[underlyingAddress] = adjustDecimals(SafeMath.sub(36, underlyingDecimals), 18, underlyingPriceMantissa);
    }
}

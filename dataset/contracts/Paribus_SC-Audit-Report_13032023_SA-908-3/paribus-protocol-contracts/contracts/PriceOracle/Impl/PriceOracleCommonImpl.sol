// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

import "../../Utils/SafeMath.sol";
import "../PriceOracleInterface.sol";
import "../../PToken/PErc20/PErc20.sol";

contract PriceOracleCommonImpl is PriceOracleInterface {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeMath for int;

    /// @notice The address of pEther. We need this because pEther has no .underlying() property for obvious reason
    address public pEtherAddress;

    /**
      * @notice Get the decimals and address of a given pToken's underlying asset
      * @param pToken The token
      * @return (decimals of underlying, address of underlying (address(0) for pEther))
      */
    function getUnderlyingDecimalsAndAddress(PToken pToken) public view returns (uint256, address) {
        if (address(pToken) == pEtherAddress) return (18, address(0));

        else {
            PErc20 pErc20 = PErc20(address(pToken));
            return (EIP20Interface(pErc20.underlying()).decimals(), pErc20.underlying());
        }
    }

    function adjustDecimals(uint valueDecimals, uint wantedDecimals, uint value) internal pure returns (uint) {
        if (wantedDecimals >= valueDecimals) return value.mul(10 ** wantedDecimals.sub(valueDecimals));
        else return value.div(10 ** valueDecimals.sub(wantedDecimals));
    }

    function isPTokenSupported(PToken pToken) public view returns (bool) {
        (, address underlyingAddress) = getUnderlyingDecimalsAndAddress(pToken);
        return isTokenSupported(underlyingAddress);
    }

    function getUnderlyingPrice(PToken pToken) public view returns (uint256) {
        (uint256 underlyingDecimals, address underlyingAddress) = getUnderlyingDecimalsAndAddress(pToken);
        return getPriceOfUnderlying(underlyingAddress, SafeMath.sub(36, underlyingDecimals));
    }
}

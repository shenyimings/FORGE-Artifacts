// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";

library DexPair {

    bytes4 private constant FACTORY_SELECTOR = bytes4(keccak256(bytes('factory()')));
    address constant internal _wbnb = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address constant internal _busd = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    function _isPair(
        address pair_
    )
    internal
    returns (bool)
    {

        (bool success, bytes memory data) =
        pair_.call((abi.encodeWithSelector(FACTORY_SELECTOR)));
        return success && data.length > 0;
    }

    function _createPair(
        address router_,
        address pairedToken_
    )
    internal
    returns (address)
    {
        return IUniswapV2Factory(IUniswapV2Router02(router_).factory())
        .createPair(address(this), pairedToken_);
    }
}
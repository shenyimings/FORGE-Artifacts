// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

/*

░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝

*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/// @title The oracle V2 interface by Woo.Network.
/// @notice update and posted the latest price info by Woo.
interface IWooracleV2 {
    // function woPrice(address base) external view returns (uint256);

    function woSpread(address base) external view returns (uint256);

    function woCoeff(address base) external view returns (uint256);

    // Wooracle price of the base token
    function woPrice(address base) external view returns (uint256 price, uint256 timestamp);

    function woState(address base)
        external
        view
        returns (
            uint256 price,
            uint256 spread,
            uint256 coeff,
            uint256 timestamp
        );

    // ChainLink price of the base token / quote token
    function cloPrice(address base) external view returns (uint256 price, uint256 timestamp);

    function cloAddress(address base) external view returns (address clo);

    // Returns Woooracle price if available, otherwise fallback to ChainLink
    function price(address base) external view returns (uint256 priceNow, uint256 timestamp);

    function decimals(address base) external view returns (uint8);

    function quoteToken() external view returns (address);

    function timestamp() external view returns (uint256);

    function isWoFeasible(address base) external view returns (bool);
}

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

import './libraries/InitializableOwnable.sol';
import './interfaces/IWooracleV2.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

/// @title Wooracle V2 contract
contract WooracleV2 is InitializableOwnable, IWooracleV2 {
    /* ----- State variables ----- */

    // Oracle addresses for BSC
    address public btcOracle = 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf; // decimal: 8
    address public ethOracle = 0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e; // decimal: 8
    address public bnbOracle = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE; // decimal: 8
    address public wooOracle = 0x02Bfe714e78E2Ad1bb1C2beE93eC8dc5423B66d4; // decimal: 8

    address public quoteOracle = 0xB97Ad0E74fa7d920791E90258A6E2085088b4320; // USDT/USD, 8

    // 128 + 64 + 64 = 256 bits (slot size)
    struct TokenInfo {
        uint64 price; // as chainlink oracle (e.g. decimal = 8)
        uint64 coeff; // 18.
        uint64 spread; // 18. spread <= 2e18   (2^64 = 1.84e19)
    }

    mapping(address => TokenInfo) public infos;

    address public override quoteToken;
    uint256 public override timestamp;

    uint256 public staleDuration;

    mapping(address => bool) public wooFeasible;
    mapping(address => bool) public clFeasible;
    mapping(address => uint8) public override decimals;

    constructor() public {
        initOwner(msg.sender);
        staleDuration = uint256(300);
    }

    /* ----- External Functions ----- */

    // TODO for wooracle V2

    /// @dev Set the quote token address.
    /// @param _oracle the token address
    function setQuoteToken(address _quote, address _oracle) external onlyOwner {
        // quoteToken = newQuoteToken;
    }

    // function decimals(address base) external view returns (uint8) {
    //     uint8 d = decimals[base];
    //     return d == 0 ? 8 : d;
    // }

    /// @dev Set the staleDuration.
    /// @param newStaleDuration the new stale duration
    function setStaleDuration(uint256 newStaleDuration) external onlyOwner {
        staleDuration = newStaleDuration;
    }

    /// @dev Update the base token prices.
    /// @param base the baseToken address
    /// @param newPrice the new prices for the base token
    function postPrice(address base, uint128 newPrice) external onlyOwner {
        infos[base].price = uint64(newPrice);
        timestamp = block.timestamp;
    }

    /// @dev batch update baseTokens prices
    /// @param bases list of baseToken address
    /// @param newPrices the updated prices list
    function postPriceList(address[] calldata bases, uint128[] calldata newPrices) external onlyOwner {
        uint256 length = bases.length;
        require(length == newPrices.length, 'Wooracle: length_INVALID');

        for (uint256 i = 0; i < length; i++) {
            infos[bases[i]].price = uint64(newPrices[i]);
        }

        timestamp = block.timestamp;
    }

    /// @dev update the spreads info.
    /// @param base baseToken address
    /// @param newSpread the new spreads
    function postSpread(address base, uint64 newSpread) external onlyOwner {
        infos[base].spread = newSpread;
        timestamp = block.timestamp;
    }

    /// @dev batch update the spreads info.
    /// @param bases list of baseToken address
    /// @param newSpreads list of spreads info
    function postSpreadList(address[] calldata bases, uint64[] calldata newSpreads) external onlyOwner {
        uint256 length = bases.length;
        require(length == newSpreads.length, 'Wooracle: length_INVALID');

        for (uint256 i = 0; i < length; i++) {
            infos[bases[i]].spread = newSpreads[i];
        }

        timestamp = block.timestamp;
    }

    /// @dev update the state of the given base token.
    /// @param base baseToken address
    /// @param newPrice the new prices
    /// @param newSpread the new spreads
    /// @param newCoeff the new slippage coefficent
    function postState(
        address base,
        uint128 newPrice,
        uint64 newSpread,
        uint64 newCoeff
    ) external onlyOwner {
        _setState(base, newPrice, newSpread, newCoeff);
        timestamp = block.timestamp;
    }

    /// @dev batch update the prices, spreads and slipagge coeffs info.
    /// @param bases list of baseToken address
    /// @param newPrices the prices list
    /// @param newSpreads the spreads list
    /// @param newCoeffs the slippage coefficent list
    function postStateList(
        address[] calldata bases,
        uint128[] calldata newPrices,
        uint64[] calldata newSpreads,
        uint64[] calldata newCoeffs
    ) external onlyOwner {
        uint256 length = bases.length;
        for (uint256 i = 0; i < length; i++) {
            _setState(bases[i], newPrices[i], newSpreads[i], newCoeffs[i]);
        }
        timestamp = block.timestamp;
    }

    // function price(address base) external view override returns (uint256 priceNow, bool feasible) {
    //     priceNow = uint256(infos[base].price);
    //     feasible = priceNow != 0 && block.timestamp <= (timestamp + staleDuration * 1 seconds);
    //     return (priceNow, feasible);
    // }

    function price(address base) external view override returns (uint256 priceNow, uint256 timestampNow) {
        return (uint256(infos[base].price), 0);
    }

    function spread(address base) external view returns (uint256) {
        return uint256(infos[base].spread);
    }

    function coeff(address base) external view returns (uint256) {
        return uint256(infos[base].coeff);
    }

    function isFeasible(address base) public view returns (bool) {
        return infos[base].price != 0 && block.timestamp <= (timestamp + staleDuration * 1 seconds);
    }

    function setWooFeasible(address base, bool feasible) external onlyOwner {
        wooFeasible[base] = feasible;
    }

    function setCLFeasible(address base, bool feasible) external onlyOwner {
        clFeasible[base] = feasible;
    }

    /* ----- Private Functions ----- */

    function _setState(
        address base,
        uint128 newPrice,
        uint64 newSpread,
        uint64 newCoeff
    ) private {
        TokenInfo storage info = infos[base];
        info.price = uint64(newPrice);
        info.spread = newSpread;
        info.coeff = newCoeff;
    }

    function cloPrice(address base) external view override returns (uint256 priceNow, uint256 timestampNow) {
        return (0, 0);
    }

    function isWoFeasible(address base) external view override returns (bool) {
        return true;
    }

    function woSpread(address base) external view override returns (uint256) {
        return 0;
    }

    function woCoeff(address base) external view override returns (uint256) {
        return 0;
    }

    // Wooracle price of the base token
    function woPrice(address base) external view override returns (uint256 priceNow, uint256 timestampNow) {
        return (0, 0);
    }

    function woState(address base)
        external
        view
        override
        returns (
            uint256 priceNow,
            uint256 spreadNow,
            uint256 coeffNow,
            uint256 timestampNow
        )
    {
        return (0, 0, 0, 0);
    }

    function cloAddress(address base) external view override returns (address clo) {
        clo = 0x02Bfe714e78E2Ad1bb1C2beE93eC8dc5423B66d4;
        return clo;
    }
}

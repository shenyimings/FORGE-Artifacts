// SPDX-License-Identifier: MIT

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.13;
pragma experimental ABIEncoderV2;

import "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Curve.sol";
import "./interfaces/IERC20Detailed.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/ICurve.sol";
import "./interfaces/ICurveFactory.sol";

// import "forge-std/Test.sol";

contract Zap {
    using SafeMath for uint256;
    using SafeERC20 for IERC20Detailed;

    struct ZapData {
        address curve;
        address base;
        address quote;
        uint256 zapAmount;
        uint256 curveBaseBal;
        uint8 curveBaseDecimals;
        uint256 curveQuoteBal;
    }

    struct ZapDepositData {
        uint256 curBaseAmount;
        uint256 curQuoteAmount;
        uint256 maxBaseAmount;
        uint256 maxQuoteAmount;
    }

    ICurveFactory public immutable curveFactory;

    modifier isDFXCurve(address _curve) {
        require(curveFactory.isDFXCurve(_curve), "zap/invalid-curve");
        _;
    }

    constructor(address _factory) {
        curveFactory = ICurveFactory(_factory);
    }

    function unzap(
        address _curve,
        uint256 _lpAmount,
        uint256 _deadline,
        uint256 _minTokenAmount,
        address _token,
        bool _toETH
    ) public isDFXCurve(_curve) returns (uint256) {
        address wETH = ICurve(_curve).getWeth();
        IERC20Detailed base = IERC20Detailed(
            Curve(payable(_curve)).numeraires(0)
        );
        IERC20Detailed quote = IERC20Detailed(
            Curve(payable(_curve)).numeraires(1)
        );
        require(
            _token == address(base) || _token == address(quote),
            "zap/token-not-supported"
        );
        IERC20Detailed(_curve).safeTransferFrom(
            msg.sender,
            address(this),
            _lpAmount
        );
        Curve(payable(_curve)).withdraw(_lpAmount, _deadline);
        // from base
        if (_token == address(base)) {
            uint256 baseAmount = base.balanceOf(address(this));
            base.safeApprove(_curve, 0);
            base.safeApprove(_curve, type(uint256).max);
            Curve(payable(_curve)).originSwap(
                address(base),
                address(quote),
                baseAmount,
                0,
                _deadline
            );
            uint256 quoteAmount = quote.balanceOf(address(this));
            require(
                quoteAmount >= _minTokenAmount,
                "!Unzap/not-enough-token-amount"
            );
            if (address(quote) == wETH && _toETH) {
                IWETH(wETH).withdraw(quoteAmount);
                (bool success, ) = payable(msg.sender).call{value: quoteAmount}(
                    ""
                );
                require(success, "zap/unzap-to-eth-failed");
            } else quote.safeTransfer(msg.sender, quoteAmount);
            return quoteAmount;
        } else {
            uint256 quoteAmount = quote.balanceOf(address(this));
            quote.safeApprove(_curve, 0);
            quote.safeApprove(_curve, type(uint256).max);
            Curve(payable(_curve)).originSwap(
                address(quote),
                address(base),
                quoteAmount,
                0,
                _deadline
            );
            uint256 baseAmount = base.balanceOf(address(this));
            require(
                baseAmount >= _minTokenAmount,
                "!Unzap/not-enough-token-amount"
            );
            if (address(base) == wETH && _toETH) {
                IWETH(wETH).withdraw(quoteAmount);
                (bool success, ) = payable(msg.sender).call{value: baseAmount}(
                    ""
                );
                require(success, "zap/unzap-to-eth-failed");
            } else base.safeTransfer(msg.sender, baseAmount);
            return baseAmount;
        }
    }

    /// @notice Zaps from a single token into the LP pool
    /// @param _curve The address of the curve
    /// @param _zapAmount The amount to zap, denominated in the ERC20's decimal placing
    /// @param _deadline Deadline for this zap to be completed by
    /// @param _minLPAmount Min LP amount to get
    /// @return uint256 - The amount of LP tokens received
    function zap(
        address _curve,
        uint256 _zapAmount,
        uint256 _deadline,
        uint256 _minLPAmount,
        address _token
    ) public isDFXCurve(_curve) returns (uint256) {
        IERC20Detailed base = IERC20Detailed(
            Curve(payable(_curve)).numeraires(0)
        );
        IERC20Detailed quote = IERC20Detailed(
            Curve(payable(_curve)).numeraires(1)
        );
        require(
            _token == address(base) || _token == address(quote),
            "zap/token-not-supported"
        );
        bool isFromBase = _token == address(base) ? true : false;
        (, uint256 swapAmount) = calcSwapAmountForZap(
            // (, uint256 swapAmount) = calcSwapAmountForZap(
            _curve,
            _zapAmount,
            isFromBase
        );

        // Swap on curve
        if (isFromBase)
            _zapFromBase(
                _curve,
                base,
                address(quote),
                swapAmount,
                _deadline,
                _zapAmount
            );
        else
            _zapFromQuote(
                _curve,
                address(base),
                quote,
                swapAmount,
                _deadline,
                _zapAmount
            );
        return zap_(_curve, base, quote, _deadline, _minLPAmount);
    }

    function zapETH(
        address _curve,
        uint256 _deadline,
        uint256 _minLPAmount
    ) public payable isDFXCurve(_curve) returns (uint256) {
        require(msg.value > 0, "zap/zap-amount-is-zero");
        // token is weth, zapAmount is msg.value - coming eth amount
        address _token = ICurve(_curve).getWeth();
        // first convert coming ETH to WETH & send wrapped amount to user back
        IWETH(_token).deposit{value: msg.value}();
        IERC20Detailed(_token).safeTransferFrom(
            address(this),
            msg.sender,
            msg.value
        );

        IERC20Detailed base = IERC20Detailed(
            Curve(payable(_curve)).numeraires(0)
        );
        IERC20Detailed quote = IERC20Detailed(
            Curve(payable(_curve)).numeraires(1)
        );
        require(
            _token == address(base) || _token == address(quote),
            "zap/token-not-supported"
        );
        bool isFromBase = _token == address(base) ? true : false;
        (, uint256 swapAmount) = calcSwapAmountForZap(
            _curve,
            msg.value,
            isFromBase
        );

        // Swap on curve
        if (isFromBase)
            _zapFromBase(
                _curve,
                base,
                address(quote),
                swapAmount,
                _deadline,
                msg.value
            );
        else
            _zapFromQuote(
                _curve,
                address(base),
                quote,
                swapAmount,
                _deadline,
                msg.value
            );
        return zap_(_curve, base, quote, _deadline, _minLPAmount);
    }

    // helpers for zap
    function _zapFromBase(
        address _curve,
        IERC20Detailed _base,
        address _quote,
        uint256 _swapAmount,
        uint256 _deadline,
        uint256 _zapAmount
    ) private {
        (_base).safeTransferFrom(msg.sender, address(this), _zapAmount);
        (_base).safeApprove(_curve, 0);
        (_base).safeApprove(_curve, _swapAmount);

        Curve(payable(_curve)).originSwap(
            address(_base),
            _quote,
            _swapAmount,
            0,
            _deadline
        );
    }

    function _zapFromQuote(
        address _curve,
        address _base,
        IERC20Detailed _quote,
        uint256 _swapAmount,
        uint256 _deadline,
        uint256 _zapAmount
    ) private {
        _quote.safeTransferFrom(msg.sender, address(this), _zapAmount);
        _quote.safeApprove(_curve, 0);
        _quote.safeApprove(_curve, _swapAmount);

        Curve(payable(_curve)).originSwap(
            address(_quote),
            _base,
            _swapAmount,
            0,
            _deadline
        );
    }

    function zap_(
        address _curve,
        IERC20Detailed _base,
        IERC20Detailed _quote,
        uint256 _deadline,
        uint256 _minLPAmount
    ) private returns (uint256) {
        // Calculate deposit amount
        (uint256 depositAmount, , ) = _calcDepositAmount(
            _curve,
            _base,
            ZapDepositData({
                curBaseAmount: _base.balanceOf(address(this)),
                curQuoteAmount: _quote.balanceOf(address(this)),
                maxBaseAmount: _base.balanceOf(address(this)),
                maxQuoteAmount: _quote.balanceOf(address(this))
            })
        );

        // Can only deposit the smaller amount as we won't have enough of the
        // token to deposit
        _base.safeApprove(_curve, 0);
        _base.safeApprove(_curve, _base.balanceOf(address(this)));

        _quote.safeApprove(_curve, 0);
        _quote.safeApprove(_curve, _quote.balanceOf(address(this)));
        (uint256 lpAmount, ) = Curve(payable(_curve)).deposit(
            depositAmount,
            0,
            0,
            type(uint256).max,
            type(uint256).max,
            _deadline
        );
        require(lpAmount >= _minLPAmount, "!Zap/not-enough-lp-amount");
        // send lp to user
        IERC20Detailed(_curve).safeTransfer(
            msg.sender,
            IERC20Detailed(_curve).balanceOf(address(this))
        );
        // Transfer all remaining balances back to user
        _base.safeTransfer(msg.sender, _base.balanceOf(address(this)));
        _quote.safeTransfer(msg.sender, _quote.balanceOf(address(this)));

        return lpAmount;
    }

    // **** View only functions **** //

    /// @notice Iteratively calculates how much base to swap
    /// @param _curve The address of the curve
    /// @param _zapAmount The amount to zap, denominated in the ERC20's decimal placing
    /// @return uint256 - The amount to swap
    function calcSwapAmountForZapFromBase(
        address _curve,
        uint256 _zapAmount
    ) public returns (uint256) {
        (, uint256 ret) = calcSwapAmountForZap(_curve, _zapAmount, true);
        return ret;
    }

    /// @notice Iteratively calculates how much quote to swap
    /// @param _curve The address of the curve
    /// @param _zapAmount The amount to zap, denominated in the ERC20's decimal placing
    /// @return uint256 - The amount to swap
    function calcSwapAmountForZapFromQuote(
        address _curve,
        uint256 _zapAmount
    ) public returns (uint256) {
        (, uint256 ret) = calcSwapAmountForZap(_curve, _zapAmount, false);
        return ret;
    }

    /// @notice Iteratively calculates how much to swap
    /// @param _curve The address of the curve
    /// @param _zapAmount The amount to zap, denominated in the ERC20's decimal placing
    /// @param isFromBase Is the swap originating from the base?
    /// @return address - The address of the base
    /// @return uint256 - The amount to swap
    function calcSwapAmountForZap(
        address _curve,
        uint256 _zapAmount,
        bool isFromBase
    ) public returns (address, uint256) {
        // Base will always be index 0
        address base = Curve(payable(_curve)).reserves(0);
        IERC20Detailed quote = IERC20Detailed(
            Curve(payable(_curve)).reserves(1)
        );

        // Ratio of base quote in 18 decimals
        uint256 curveBaseBal = IERC20Detailed(base).balanceOf(_curve);
        uint8 curveBaseDecimals = IERC20Detailed(base).decimals();
        uint256 curveQuoteBal = quote.balanceOf(_curve);

        // How much user wants to swap
        uint256 initialSwapAmount = _zapAmount.div(2);

        // Calc Base Swap Amount
        if (isFromBase) {
            return (
                base,
                _calcBaseSwapAmount(
                    initialSwapAmount,
                    ZapData({
                        curve: _curve,
                        base: base,
                        quote: address(quote),
                        zapAmount: _zapAmount,
                        curveBaseBal: curveBaseBal,
                        curveBaseDecimals: curveBaseDecimals,
                        curveQuoteBal: curveQuoteBal
                    })
                )
            );
        }

        // Calc quote swap amount
        return (
            base,
            _calcQuoteSwapAmount(
                initialSwapAmount,
                ZapData({
                    curve: _curve,
                    base: base,
                    quote: address(quote),
                    zapAmount: _zapAmount,
                    curveBaseBal: curveBaseBal,
                    curveBaseDecimals: curveBaseDecimals,
                    curveQuoteBal: curveQuoteBal
                })
            )
        );
    }

    // **** Helper functions ****

    /// @notice Given a quote amount, calculate the maximum deposit amount, along with the
    ///         the number of LP tokens that will be generated, along with the maximized
    ///         base/quote amounts
    /// @param _curve The address of the curve
    /// @param _quoteAmount The amount of quote tokens
    /// @return uint256 - The deposit amount
    /// @return uint256 - The LPTs received
    /// @return uint256[] memory - The baseAmount and quoteAmount
    function calcMaxDepositAmountGivenQuote(
        address _curve,
        uint256 _quoteAmount
    ) public returns (uint256, uint256, uint256[] memory) {
        uint256 maxBaseAmount = calcMaxBaseForDeposit(_curve, _quoteAmount);
        address base = Curve(payable(_curve)).reserves(0);

        return
            _calcDepositAmount(
                _curve,
                IERC20Detailed(base),
                ZapDepositData({
                    curBaseAmount: maxBaseAmount,
                    curQuoteAmount: _quoteAmount,
                    maxBaseAmount: maxBaseAmount,
                    maxQuoteAmount: _quoteAmount
                })
            );
    }

    /// @notice Given a base amount, calculate the maximum deposit amount, along with the
    ///         the number of LP tokens that will be generated, along with the maximized
    ///         base/quote amounts
    /// @param _curve The address of the curve
    /// @param _baseAmount The amount of base tokens
    /// @return uint256 - The deposit amount
    /// @return uint256 - The LPTs received
    /// @return uint256[] memory - The baseAmount and quoteAmount
    function calcMaxDepositAmountGivenBase(
        address _curve,
        uint256 _baseAmount
    ) public returns (uint256, uint256, uint256[] memory) {
        uint256 maxQuoteAmount = calcMaxQuoteForDeposit(_curve, _baseAmount);
        address base = Curve(payable(_curve)).reserves(0);

        return
            _calcDepositAmount(
                _curve,
                IERC20Detailed(base),
                ZapDepositData({
                    curBaseAmount: _baseAmount,
                    curQuoteAmount: maxQuoteAmount,
                    maxBaseAmount: _baseAmount,
                    maxQuoteAmount: maxQuoteAmount
                })
            );
    }

    /// notice Given a base amount, calculate the max base amount to be deposited
    /// param payable _curve The address of the curve
    /// param _quoteAmount The amount of base tokens
    /// return uint256 - The max quote amount
    function calcMaxBaseForDeposit(
        address _curve,
        uint256 _quoteAmount
    ) public view returns (uint256) {
        (, uint256[] memory outs) = Curve(payable(_curve)).viewDeposit(2e18);
        uint256 baseAmount = outs[0].mul(_quoteAmount).div(1e6);

        return baseAmount;
    }

    /// @notice Given a base amount, calculate the max quote amount to be deposited
    /// @param _curve The address of the curve
    /// @param _baseAmount The amount of quote tokens
    /// @return uint256 - The max quote amount
    function calcMaxQuoteForDeposit(
        address _curve,
        uint256 _baseAmount
    ) public returns (uint256) {
        uint8 curveBaseDecimals = IERC20Detailed(
            Curve(payable(_curve)).reserves(0)
        ).decimals();
        (, uint256[] memory outs) = Curve(payable(_curve)).viewDeposit(2e18);
        uint256 ratio = outs[0].mul(10 ** (36 - curveBaseDecimals)).div(
            outs[1].mul(1e12)
        );
        uint256 quoteAmount = _baseAmount
            .mul(10 ** (36 - curveBaseDecimals))
            .div(ratio)
            .div(1e12);

        return quoteAmount;
    }

    // **** Internal function ****

    // Stack too deep
    function _roundDown(uint256 a) internal pure returns (uint256) {
        return a.mul(99999999).div(100000000);
    }

    /// @notice Calculate how many quote tokens needs to be swapped into base tokens to
    ///         respect the pool's ratio
    /// @param initialSwapAmount The initial amount to swap
    /// @param zapData           Zap data encoded
    /// @return uint256 - The amount of quote tokens to be swapped into base tokens
    function _calcQuoteSwapAmount(
        uint256 initialSwapAmount,
        ZapData memory zapData
    ) internal view returns (uint256) {
        uint256 swapAmount = initialSwapAmount;
        uint256 delta = initialSwapAmount.div(2);
        uint256 recvAmount;
        uint256 curveRatio;
        uint256 userRatio;

        // Computer bring me magic number
        for (uint256 i = 0; i < 32; i++) {
            // How much will we receive in return
            recvAmount = Curve(payable(zapData.curve)).viewOriginSwap(
                zapData.quote,
                zapData.base,
                swapAmount
            );

            // Update user's ratio
            userRatio = recvAmount
                .mul(10 ** (36 - uint256(zapData.curveBaseDecimals)))
                .div(zapData.zapAmount.sub(swapAmount).mul(1e12));
            curveRatio = zapData
                .curveBaseBal
                .sub(recvAmount)
                .mul(10 ** (36 - uint256(zapData.curveBaseDecimals)))
                .div(zapData.curveQuoteBal.add(swapAmount).mul(1e12));

            // If user's ratio is approx curve ratio, then just swap
            // I.e. ratio converges
            if (userRatio.div(1e16) == curveRatio.div(1e16)) {
                return swapAmount;
            }
            // Otherwise, we keep iterating
            else if (userRatio > curveRatio) {
                // We swapping too much
                swapAmount = swapAmount.sub(delta);
            } else if (userRatio < curveRatio) {
                // We swapping too little
                swapAmount = swapAmount.add(delta);
            }

            // Cannot swap more than zapAmount
            if (swapAmount > zapData.zapAmount) {
                swapAmount = zapData.zapAmount - 1;
            }

            // Keep halving
            delta = delta.div(2);
        }

        revert("Zap/not-converging");
    }

    /// @notice Calculate how many base tokens needs to be swapped into quote tokens to
    ///         respect the pool's ratio
    /// @param initialSwapAmount The initial amount to swap
    /// @param zapData           Zap data encoded
    /// @return uint256 - The amount of base tokens to be swapped into quote tokens
    function _calcBaseSwapAmount(
        uint256 initialSwapAmount,
        ZapData memory zapData
    ) internal view returns (uint256) {
        uint256 swapAmount = initialSwapAmount;
        uint256 delta = initialSwapAmount.div(2);
        uint256 recvAmount;
        uint256 curveRatio;
        uint256 userRatio;

        // Computer bring me magic number
        for (uint256 i = 0; i < 32; i++) {
            // How much will we receive in return
            recvAmount = Curve(payable(zapData.curve)).viewOriginSwap(
                zapData.base,
                zapData.quote,
                swapAmount
            );

            // Update user's ratio
            userRatio = zapData
                .zapAmount
                .sub(swapAmount)
                .mul(10 ** (36 - uint256(zapData.curveBaseDecimals)))
                .div(recvAmount.mul(1e12));
            curveRatio = zapData
                .curveBaseBal
                .add(swapAmount)
                .mul(10 ** (36 - uint256(zapData.curveBaseDecimals)))
                .div(zapData.curveQuoteBal.sub(recvAmount).mul(1e12));

            // If user's ratio is approx curve ratio, then just swap
            // I.e. ratio converges
            if (userRatio.div(1e16) == curveRatio.div(1e16)) {
                return swapAmount;
            }
            // Otherwise, we keep iterating
            else if (userRatio > curveRatio) {
                // We swapping too little
                swapAmount = swapAmount.add(delta);
            } else if (userRatio < curveRatio) {
                // We swapping too much
                swapAmount = swapAmount.sub(delta);
            }

            // Cannot swap more than zap
            if (swapAmount > zapData.zapAmount) {
                swapAmount = zapData.zapAmount - 1;
            }

            // Keep halving
            delta = delta.div(2);
        }

        revert("Zap/not-converging");
    }

    /// @notice Given a ZapDepositData structure, calculate the max depositAmount, the max
    ///          LP tokens received, and the required amounts
    /// param _curve The address of the curve
    /// @param _base  The base address in the curve
    /// @param dd     Deposit data

    /// @return uint256 - The deposit amount
    /// @return uint256 - The LPTs received
    /// @return uint256[] memory - The baseAmount and quoteAmount
    function _calcDepositAmount(
        address _curve,
        IERC20Detailed _base,
        ZapDepositData memory dd
    ) internal returns (uint256, uint256, uint256[] memory) {
        // Calculate _depositAmount
        IERC20Detailed quote = IERC20Detailed(
            Curve(payable(_curve)).numeraires(1)
        );
        uint256 curveRatio = _base
            .balanceOf(_curve)
            .mul(10 ** (36 - _base.decimals()))
            .div(quote.balanceOf(_curve).mul(1e12));

        // Deposit amount is denomiated in USD value (based on pool LP ratio)
        // Things are 1:1 on USDC side on deposit
        uint256 quoteDepositAmount = dd.curQuoteAmount.mul(1e12);

        // Things will be based on ratio on deposit
        uint256 baseDepositAmount = dd.curBaseAmount.mul(
            10 ** (18 - _base.decimals())
        );

        // Trim out decimal values
        uint256 depositAmount = quoteDepositAmount.add(
            baseDepositAmount.mul(1e18).div(curveRatio)
        );
        depositAmount = _roundDown(depositAmount);

        // // Make sure we have enough of our inputs
        (uint256 lps, uint256[] memory outs) = Curve(payable(_curve))
            .viewDeposit(depositAmount);

        uint256 baseDelta = outs[0] > dd.maxBaseAmount
            ? outs[0].sub(dd.curBaseAmount)
            : 0;
        uint256 quoteDelta = outs[1] > dd.maxQuoteAmount
            ? outs[1].sub(dd.curQuoteAmount)
            : 0;

        // Make sure we can deposit
        if (baseDelta > 0 || quoteDelta > 0) {
            dd.curBaseAmount = _roundDown(dd.curBaseAmount.sub(baseDelta));
            dd.curQuoteAmount = _roundDown(dd.curQuoteAmount.sub(quoteDelta));

            return _calcDepositAmount(_curve, _base, dd);
        }

        return (depositAmount, lps, outs);
    }
}

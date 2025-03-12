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
import './libraries/DecimalMath.sol';
import './interfaces/IWooracle.sol';
import './interfaces/IWooPP.sol';
import './interfaces/IWooFeeManager.sol';
import './interfaces/IWooGuardian.sol';
import './interfaces/AggregatorV3Interface.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

/// @title Woo private pool for swaping.
/// @notice the implementation class for interface IWooPP, mainly for query and swap tokens.
contract WooPP is InitializableOwnable, ReentrancyGuard, Pausable, IWooPP {
    /* ----- Type declarations ----- */

    using SafeMath for uint256;
    using DecimalMath for uint256;
    using SafeERC20 for IERC20;

    /* ----- State variables ----- */

    mapping(address => TokenInfo) public tokenInfo;
    mapping(address => bool) public isStrategist;

    /// @inheritdoc IWooPP
    address public immutable override quoteToken;
    address public wooracle;
    IWooGuardian public wooGuardian;
    IWooFeeManager public feeManager;
    string public pairsInfo; // e.g. BNB/ETH/BTCB/WOO-USDT

    /* ----- Modifiers ----- */

    modifier onlyStrategist() {
        require(msg.sender == _OWNER_ || isStrategist[msg.sender], 'WooPP: NOT_STRATEGIST');
        _;
    }

    constructor(
        address newQuoteToken,
        address newWooracle,
        address newFeeManager,
        address newWooGuardian
    ) public {
        require(newQuoteToken != address(0), 'WooPP: INVALID_QUOTE');
        require(newWooracle != address(0), 'WooPP: newWooracle_ZERO_ADDR');
        require(newFeeManager != address(0), 'WooPP: newFeeManager_ZERO_ADDR');
        require(newWooGuardian != address(0), 'WooPP: newWooGuardian_ZERO_ADDR');

        initOwner(msg.sender);
        quoteToken = newQuoteToken;
        wooracle = newWooracle;
        feeManager = IWooFeeManager(newFeeManager);
        require(feeManager.quoteToken() == newQuoteToken, 'WooPP: feeManager_quoteToken_INVALID');
        wooGuardian = IWooGuardian(newWooGuardian);

        TokenInfo storage quoteInfo = tokenInfo[newQuoteToken];
        quoteInfo.isValid = true;
    }

    /* ----- External Functions ----- */

    /// @inheritdoc IWooPP
    function querySellBase(address baseToken, uint256 baseAmount)
        external
        view
        override
        whenNotPaused
        returns (uint256 quoteAmount)
    {
        require(baseToken != address(0), 'WooPP: baseToken_ZERO_ADDR');
        require(baseToken != quoteToken, 'WooPP: baseToken==quoteToken');
        wooGuardian.checkInputAmount(baseToken, baseAmount);

        TokenInfo memory baseInfo = tokenInfo[baseToken];
        require(baseInfo.isValid, 'WooPP: TOKEN_DOES_NOT_EXIST');
        TokenInfo memory quoteInfo = tokenInfo[quoteToken];
        _autoUpdate(baseToken, baseInfo, quoteInfo);

        quoteAmount = getQuoteAmountSellBase(baseToken, baseAmount, baseInfo, quoteInfo);
        wooGuardian.checkSwapAmount(baseToken, quoteToken, baseAmount, quoteAmount);
        uint256 lpFee = quoteAmount.mulCeil(feeManager.feeRate(baseToken));
        quoteAmount = quoteAmount.sub(lpFee);

        require(quoteAmount <= IERC20(quoteToken).balanceOf(address(this)), 'WooPP: INSUFF_QUOTE');
    }

    /// @inheritdoc IWooPP
    function querySellQuote(address baseToken, uint256 quoteAmount)
        external
        view
        override
        whenNotPaused
        returns (uint256 baseAmount)
    {
        require(baseToken != address(0), 'WooPP: baseToken_ZERO_ADDR');
        require(baseToken != quoteToken, 'WooPP: baseToken==quoteToken');
        wooGuardian.checkInputAmount(quoteToken, quoteAmount);

        TokenInfo memory baseInfo = tokenInfo[baseToken];
        require(baseInfo.isValid, 'WooPP: TOKEN_DOES_NOT_EXIST');
        TokenInfo memory quoteInfo = tokenInfo[quoteToken];
        _autoUpdate(baseToken, baseInfo, quoteInfo);

        uint256 lpFee = quoteAmount.mulCeil(feeManager.feeRate(baseToken));
        quoteAmount = quoteAmount.sub(lpFee);
        baseAmount = getBaseAmountSellQuote(baseToken, quoteAmount, baseInfo, quoteInfo);
        wooGuardian.checkSwapAmount(quoteToken, baseToken, quoteAmount, baseAmount);

        require(baseAmount <= IERC20(baseToken).balanceOf(address(this)), 'WooPP: INSUFF_BASE');
    }

    /// @inheritdoc IWooPP
    function sellBase(
        address baseToken,
        uint256 baseAmount,
        uint256 minQuoteAmount,
        address to,
        address rebateTo
    ) external override nonReentrant whenNotPaused returns (uint256 quoteAmount) {
        require(baseToken != address(0), 'WooPP: baseToken_ZERO_ADDR');
        require(to != address(0), 'WooPP: to_ZERO_ADDR');
        require(baseToken != quoteToken, 'WooPP: baseToken==quoteToken');
        wooGuardian.checkInputAmount(baseToken, baseAmount);

        address from = msg.sender;
        TokenInfo memory baseInfo = tokenInfo[baseToken];
        require(baseInfo.isValid, 'WooPP: TOKEN_DOES_NOT_EXIST');
        TokenInfo memory quoteInfo = tokenInfo[quoteToken];
        _autoUpdate(baseToken, baseInfo, quoteInfo);

        TransferHelper.safeTransferFrom(baseToken, from, address(this), baseAmount);

        quoteAmount = getQuoteAmountSellBase(baseToken, baseAmount, baseInfo, quoteInfo);
        wooGuardian.checkSwapAmount(baseToken, quoteToken, baseAmount, quoteAmount);

        uint256 lpFee = quoteAmount.mulCeil(feeManager.feeRate(baseToken));
        quoteAmount = quoteAmount.sub(lpFee);
        require(quoteAmount >= minQuoteAmount, 'WooPP: quoteAmount<minQuoteAmount');

        TransferHelper.safeApprove(quoteToken, address(feeManager), lpFee);
        feeManager.collectFee(lpFee, rebateTo);

        uint256 balanceBefore = IERC20(quoteToken).balanceOf(to);
        TransferHelper.safeTransfer(quoteToken, to, quoteAmount);
        require(IERC20(quoteToken).balanceOf(to).sub(balanceBefore) >= minQuoteAmount, 'WooPP: INSUFF_OUTPUT_AMOUNT');

        _updateReserve(baseToken, baseInfo, quoteInfo);

        tokenInfo[baseToken] = baseInfo;
        tokenInfo[quoteToken] = quoteInfo;

        emit WooSwap(baseToken, quoteToken, baseAmount, quoteAmount, from, to, rebateTo);
    }

    /// @inheritdoc IWooPP
    function sellQuote(
        address baseToken,
        uint256 quoteAmount,
        uint256 minBaseAmount,
        address to,
        address rebateTo
    ) external override nonReentrant whenNotPaused returns (uint256 baseAmount) {
        require(baseToken != address(0), 'WooPP: baseToken_ZERO_ADDR');
        require(to != address(0), 'WooPP: to_ZERO_ADDR');
        require(baseToken != quoteToken, 'WooPP: baseToken==quoteToken');
        wooGuardian.checkInputAmount(quoteToken, quoteAmount);

        address from = msg.sender;
        TokenInfo memory baseInfo = tokenInfo[baseToken];
        require(baseInfo.isValid, 'WooPP: TOKEN_DOES_NOT_EXIST');
        TokenInfo memory quoteInfo = tokenInfo[quoteToken];
        _autoUpdate(baseToken, baseInfo, quoteInfo);

        TransferHelper.safeTransferFrom(quoteToken, from, address(this), quoteAmount);

        uint256 lpFee = quoteAmount.mulCeil(feeManager.feeRate(baseToken));
        quoteAmount = quoteAmount.sub(lpFee);
        baseAmount = getBaseAmountSellQuote(baseToken, quoteAmount, baseInfo, quoteInfo);
        require(baseAmount >= minBaseAmount, 'WooPP: baseAmount<minBaseAmount');

        TransferHelper.safeApprove(quoteToken, address(feeManager), lpFee);
        feeManager.collectFee(lpFee, rebateTo);

        wooGuardian.checkSwapAmount(quoteToken, baseToken, quoteAmount, baseAmount);

        uint256 balanceBefore = IERC20(baseToken).balanceOf(to);
        TransferHelper.safeTransfer(baseToken, to, baseAmount);
        require(IERC20(baseToken).balanceOf(to).sub(balanceBefore) >= minBaseAmount, 'WooPP: INSUFF_OUTPUT_AMOUNT');

        _updateReserve(baseToken, baseInfo, quoteInfo);

        tokenInfo[baseToken] = baseInfo;
        tokenInfo[quoteToken] = quoteInfo;

        emit WooSwap(quoteToken, baseToken, quoteAmount.add(lpFee), baseAmount, from, to, rebateTo);
    }

    /// @dev Set the pairsInfo
    /// @param newPairsInfo the pairs info to set
    function setPairsInfo(string calldata newPairsInfo) external nonReentrant onlyStrategist {
        pairsInfo = newPairsInfo;
    }

    /// @dev Get the pool's balance of token
    /// @param token the token pool to query
    function poolSize(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @dev Set wooracle from newWooracle
    /// @param newWooracle Wooracle address
    function setWooracle(address newWooracle) external nonReentrant onlyStrategist {
        require(newWooracle != address(0), 'WooPP: newWooracle_ZERO_ADDR');
        wooracle = newWooracle;
        emit WooracleUpdated(newWooracle);
    }

    /// @dev Set wooGuardian from newWooGuardian
    /// @param newWooGuardian WooGuardian address
    function setWooGuardian(address newWooGuardian) external nonReentrant onlyStrategist {
        require(newWooGuardian != address(0), 'WooPP: newWooGuardian_ZERO_ADDR');
        wooGuardian = IWooGuardian(newWooGuardian);
        emit WooGuardianUpdated(newWooGuardian);
    }

    /// @dev Set the feeManager.
    /// @param newFeeManager the fee manager
    function setFeeManager(address newFeeManager) external nonReentrant onlyStrategist {
        require(newFeeManager != address(0), 'WooPP: newFeeManager_ZERO_ADDR');
        feeManager = IWooFeeManager(newFeeManager);
        require(feeManager.quoteToken() == quoteToken, 'WooPP: feeManager_quoteToken_INVALID');
        emit FeeManagerUpdated(newFeeManager);
    }

    /// @dev Add the base token for swap
    /// @param baseToken the base token
    /// @param threshold the balance threshold info
    /// @param R the rebalance refactor
    function addBaseToken(
        address baseToken,
        uint256 threshold,
        uint256 R
    ) external nonReentrant onlyStrategist {
        require(baseToken != address(0), 'WooPP: BASE_TOKEN_ZERO_ADDR');
        require(baseToken != quoteToken, 'WooPP: baseToken==quoteToken');
        require(threshold <= type(uint112).max, 'WooPP: THRESHOLD_OUT_OF_RANGE');
        require(R <= 1e18, 'WooPP: R_OUT_OF_RANGE');

        TokenInfo memory info = tokenInfo[baseToken];
        require(!info.isValid, 'WooPP: TOKEN_ALREADY_EXISTS');

        info.threshold = uint112(threshold);
        info.R = uint64(R);
        info.target = max(info.threshold, info.target);
        info.isValid = true;

        tokenInfo[baseToken] = info;

        emit ParametersUpdated(baseToken, threshold, R);
    }

    /// @dev Remove the base token
    /// @param baseToken the base token
    function removeBaseToken(address baseToken) external nonReentrant onlyStrategist {
        require(baseToken != address(0), 'WooPP: BASE_TOKEN_ZERO_ADDR');
        require(tokenInfo[baseToken].isValid, 'WooPP: TOKEN_DOES_NOT_EXIST');
        delete tokenInfo[baseToken];
        emit ParametersUpdated(baseToken, 0, 0);
    }

    /// @dev Tune the token params
    /// @param token the token to tune
    /// @param newThreshold the new balance threshold info
    /// @param newR the new rebalance refactor
    function tuneParameters(
        address token,
        uint256 newThreshold,
        uint256 newR
    ) external nonReentrant onlyStrategist {
        require(token != address(0), 'WooPP: token_ZERO_ADDR');
        require(newThreshold <= type(uint112).max, 'WooPP: THRESHOLD_OUT_OF_RANGE');
        require(newR <= 1e18, 'WooPP: R>1');

        TokenInfo memory info = tokenInfo[token];
        require(info.isValid, 'WooPP: TOKEN_DOES_NOT_EXIST');

        info.threshold = uint112(newThreshold);
        info.R = uint64(newR);
        info.target = max(info.threshold, info.target);

        tokenInfo[token] = info;
        emit ParametersUpdated(token, newThreshold, newR);
    }

    /* ----- Admin Functions ----- */

    /// @dev Pause the contract.
    function pause() external onlyStrategist {
        super._pause();
    }

    /// @dev Restart the contract.
    function unpause() external onlyStrategist {
        super._unpause();
    }

    /// @dev Update the strategist info.
    /// @param strategist the strategist to set
    /// @param flag true or false
    function setStrategist(address strategist, bool flag) external nonReentrant onlyStrategist {
        require(strategist != address(0), 'WooPP: strategist_ZERO_ADDR');
        isStrategist[strategist] = flag;
        emit StrategistUpdated(strategist, flag);
    }

    /// @dev Withdraw the token.
    /// @param token the token to withdraw
    /// @param to the destination address
    /// @param amount the amount to withdraw
    function withdraw(
        address token,
        address to,
        uint256 amount
    ) public nonReentrant onlyOwner {
        require(token != address(0), 'WooPP: token_ZERO_ADDR');
        require(to != address(0), 'WooPP: to_ZERO_ADDR');
        TransferHelper.safeTransfer(token, to, amount);
        emit Withdraw(token, to, amount);
    }

    function withdrawAll(address token, address to) external onlyOwner {
        withdraw(token, to, IERC20(token).balanceOf(address(this)));
    }

    /// @dev Withdraw the token to the OWNER address
    /// @param token the token
    function withdrawAllToOwner(address token) external nonReentrant onlyStrategist {
        require(token != address(0), 'WooPP: token_ZERO_ADDR');
        uint256 amount = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransfer(token, _OWNER_, amount);
        emit Withdraw(token, _OWNER_, amount);
    }

    /* ----- Private Functions ----- */

    function _autoUpdate(
        address baseToken,
        TokenInfo memory baseInfo,
        TokenInfo memory quoteInfo
    ) private view {
        require(baseToken != address(0), 'WooPP: BASETOKEN_ZERO_ADDR');
        _updateReserve(baseToken, baseInfo, quoteInfo);

        // NOTE: only consider the least 32 bigs integer number is good engouh
        uint32 priceTimestamp = uint32(IWooracle(wooracle).timestamp());
        if (priceTimestamp != baseInfo.lastResetTimestamp) {
            baseInfo.target = max(baseInfo.threshold, baseInfo.reserve);
            baseInfo.lastResetTimestamp = priceTimestamp;
        }
        if (priceTimestamp != quoteInfo.lastResetTimestamp) {
            quoteInfo.target = max(quoteInfo.threshold, quoteInfo.reserve);
            quoteInfo.lastResetTimestamp = priceTimestamp;
        }
    }

    function _updateReserve(
        address baseToken,
        TokenInfo memory baseInfo,
        TokenInfo memory quoteInfo
    ) private view {
        uint256 baseReserve = IERC20(baseToken).balanceOf(address(this));
        uint256 quoteReserve = IERC20(quoteToken).balanceOf(address(this));
        require(baseReserve <= type(uint112).max);
        require(quoteReserve <= type(uint112).max);
        baseInfo.reserve = uint112(baseReserve);
        quoteInfo.reserve = uint112(quoteReserve);
    }

    // When baseSold >= 0 , users sold the base token
    function getQuoteAmountLowQuoteSide(
        uint256 p,
        uint256 k,
        uint256 r,
        uint256 baseAmount
    ) private pure returns (uint256) {
        // priceFactor = 1 + k * baseAmount * p * r;
        uint256 priceFactor = DecimalMath.ONE.add(k.mulCeil(baseAmount).mulCeil(p).mulCeil(r));
        // return baseAmount * p / priceFactor;
        return baseAmount.mulFloor(p).divFloor(priceFactor); // round down
    }

    // When baseSold >= 0
    function getBaseAmountLowQuoteSide(
        uint256 p,
        uint256 k,
        uint256 r,
        uint256 quoteAmount
    ) private pure returns (uint256) {
        // priceFactor = (1 - k * quoteAmount * r);
        uint256 priceFactor = DecimalMath.ONE.sub(k.mulFloor(quoteAmount).mulFloor(r));
        // return quoteAmount / p / priceFactor;
        return quoteAmount.divFloor(p).divFloor(priceFactor);
    }

    // When quoteSold >= 0
    function getBaseAmountLowBaseSide(
        uint256 p,
        uint256 k,
        uint256 r,
        uint256 quoteAmount
    ) private pure returns (uint256) {
        // priceFactor = 1 + k * quoteAmount * r;
        uint256 priceFactor = DecimalMath.ONE.add(k.mulCeil(quoteAmount).mulCeil(r));
        // return quoteAmount / p / priceFactor;
        return quoteAmount.divFloor(p).divFloor(priceFactor); // round down
    }

    // When quoteSold >= 0
    function getQuoteAmountLowBaseSide(
        uint256 p,
        uint256 k,
        uint256 r,
        uint256 baseAmount
    ) private pure returns (uint256) {
        // priceFactor = 1 - k * baseAmount * p * r;
        uint256 priceFactor = DecimalMath.ONE.sub(k.mulFloor(baseAmount).mulFloor(p).mulFloor(r));
        // return baseAmount * p / priceFactor;
        return baseAmount.mulFloor(p).divFloor(priceFactor); // round down
    }

    function getBoughtAmount(
        TokenInfo memory baseInfo,
        TokenInfo memory quoteInfo,
        uint256 p,
        uint256 k,
        bool isSellBase
    ) private pure returns (uint256 baseBought, uint256 quoteBought) {
        uint256 baseSold = 0;
        if (baseInfo.reserve < baseInfo.target) {
            baseBought = uint256(baseInfo.target).sub(uint256(baseInfo.reserve));
        } else {
            baseSold = uint256(baseInfo.reserve).sub(uint256(baseInfo.target));
        }
        uint256 quoteSold = 0;
        if (quoteInfo.reserve < quoteInfo.target) {
            quoteBought = uint256(quoteInfo.target).sub(uint256(quoteInfo.reserve));
        } else {
            quoteSold = uint256(quoteInfo.reserve).sub(uint256(quoteInfo.target));
        }

        if (baseSold.mulCeil(p) > quoteSold) {
            baseSold = baseSold.sub(quoteSold.divFloor(p));
            quoteSold = 0;
        } else {
            quoteSold = quoteSold.sub(baseSold.mulCeil(p));
            baseSold = 0;
        }

        uint256 virtualBaseBought = getBaseAmountLowBaseSide(p, k, DecimalMath.ONE, quoteSold);
        if (isSellBase == (virtualBaseBought < baseBought)) {
            baseBought = virtualBaseBought;
        }
        uint256 virtualQuoteBought = getQuoteAmountLowQuoteSide(p, k, DecimalMath.ONE, baseSold);
        if (isSellBase == (virtualQuoteBought > quoteBought)) {
            quoteBought = virtualQuoteBought;
        }
    }

    function getQuoteAmountSellBase(
        address baseToken,
        uint256 baseAmount,
        TokenInfo memory baseInfo,
        TokenInfo memory quoteInfo
    ) private view returns (uint256 quoteAmount) {
        uint256 p;
        uint256 s;
        uint256 k;
        bool isFeasible;
        (p, s, k, isFeasible) = IWooracle(wooracle).state(baseToken);
        require(isFeasible, 'WooPP: ORACLE_PRICE_NOT_FEASIBLE');

        wooGuardian.checkSwapPrice(p, baseToken, quoteToken);

        // price: p * (1 - s / 2)
        p = p.mulFloor(DecimalMath.ONE.sub(s.divCeil(DecimalMath.TWO)));

        uint256 baseBought;
        uint256 quoteBought;
        (baseBought, quoteBought) = getBoughtAmount(baseInfo, quoteInfo, p, k, true);

        if (baseBought > 0) {
            uint256 quoteSold = getQuoteAmountLowBaseSide(p, k, baseInfo.R, baseBought);
            if (baseAmount > baseBought) {
                uint256 newBaseSold = baseAmount.sub(baseBought);
                quoteAmount = quoteSold.add(getQuoteAmountLowQuoteSide(p, k, DecimalMath.ONE, newBaseSold));
            } else {
                uint256 newBaseBought = baseBought.sub(baseAmount);
                quoteAmount = quoteSold.sub(getQuoteAmountLowBaseSide(p, k, baseInfo.R, newBaseBought));
            }
        } else {
            uint256 baseSold = getBaseAmountLowQuoteSide(p, k, DecimalMath.ONE, quoteBought);
            uint256 newBaseSold = baseAmount.add(baseSold);
            uint256 newQuoteBought = getQuoteAmountLowQuoteSide(p, k, DecimalMath.ONE, newBaseSold);
            quoteAmount = newQuoteBought > quoteBought ? newQuoteBought.sub(quoteBought) : 0;
        }
    }

    function getBaseAmountSellQuote(
        address baseToken,
        uint256 quoteAmount,
        TokenInfo memory baseInfo,
        TokenInfo memory quoteInfo
    ) private view returns (uint256 baseAmount) {
        uint256 p;
        uint256 s;
        uint256 k;
        bool isFeasible;
        (p, s, k, isFeasible) = IWooracle(wooracle).state(baseToken);
        require(isFeasible, 'WooPP: ORACLE_PRICE_NOT_FEASIBLE');

        wooGuardian.checkSwapPrice(p, baseToken, quoteToken);

        // price: p * (1 + s / 2)
        p = p.mulCeil(DecimalMath.ONE.add(s.divCeil(DecimalMath.TWO)));

        uint256 baseBought;
        uint256 quoteBought;
        (baseBought, quoteBought) = getBoughtAmount(baseInfo, quoteInfo, p, k, false);

        if (quoteBought > 0) {
            uint256 baseSold = getBaseAmountLowQuoteSide(p, k, baseInfo.R, quoteBought);
            if (quoteAmount > quoteBought) {
                uint256 newQuoteSold = quoteAmount.sub(quoteBought);
                baseAmount = baseSold.add(getBaseAmountLowBaseSide(p, k, DecimalMath.ONE, newQuoteSold));
            } else {
                uint256 newQuoteBought = quoteBought.sub(quoteAmount);
                baseAmount = baseSold.sub(getBaseAmountLowQuoteSide(p, k, baseInfo.R, newQuoteBought));
            }
        } else {
            uint256 quoteSold = getQuoteAmountLowBaseSide(p, k, DecimalMath.ONE, baseBought);
            uint256 newQuoteSold = quoteAmount.add(quoteSold);
            uint256 newBaseBought = getBaseAmountLowBaseSide(p, k, DecimalMath.ONE, newQuoteSold);
            baseAmount = newBaseBought > baseBought ? newBaseBought.sub(baseBought) : 0;
        }
    }

    function max(uint112 a, uint112 b) private pure returns (uint112) {
        return a >= b ? a : b;
    }
}

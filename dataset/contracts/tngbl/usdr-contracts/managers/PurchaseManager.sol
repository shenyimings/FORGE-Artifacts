// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../constants/addresses.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/ITokenSwap.sol";
import "../AddressAccessor.sol";

interface IUSDRExchange {
    struct MintingStats {
        uint256 tngblToUSDR;
        uint256 underlyingToUSDR;
        uint256 usdrToPromissory;
        uint256 usdrToTNGBL;
        uint256 usdrToUnderlying;
        uint256 usdrFromGains;
        uint256 usdrFromRebase;
    }

    function mintingStats() external view returns (MintingStats memory);
}

interface IUSDR is IERC20Upgradeable {
    function totalSupply() external view returns (uint256);
}

abstract contract PurchaseManager is AddressAccessor {
    function _validatePurchase(uint256 amount) internal view {
        if (amount == 0) {
            return; // all good, no underlying spending, only usdr
        }
        (address treasury, address underlying, address usdr) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TREASURY_ADDRESS, UNDERLYING_ADDRESS, USDR_ADDRESS)
            ),
            (address, address, address)
        );

        uint256 stableMintedRedeemedThreshold = uint256(
            ITreasury(treasury).purchaseStableMintedRedeemedThreshold()
        );

        uint256 totalSTValue = IERC20(underlying).balanceOf(treasury);
        // we can spend % of underlying compared to marketcap

        // we can spend only what is above 10% of marketcap
        uint256 percentMarketcapValue = _convertToCorrectDecimals(
            ((IUSDR(usdr).totalSupply() * stableMintedRedeemedThreshold) / 100),
            IERC20Metadata(usdr).decimals(),
            IERC20Metadata(underlying).decimals()
        );
        //amount we want to spend must be
        // amount < (totalSTValue - percentMarketcapValue) | maxSpendMintedRedeemedValue
        uint256 ableToSpend = percentMarketcapValue < totalSTValue
            ? (totalSTValue - percentMarketcapValue)
            : 0;

        require(
            ableToSpend >= amount,
            string(
                abi.encodePacked(
                    "ST ",
                    Strings.toString(ableToSpend),
                    " not enough for amount ",
                    Strings.toString(amount)
                )
            )
        );
    }

    //need to add second part - to convert treasury token to payment token
    function _convertTreasuryTokenToPayment(
        IERC20 paymentToken,
        uint256 amountReserveToken,
        bool instantLiquidity_,
        uint256 itemPrice,
        uint256 toFillUpToItemPrice
    ) internal {
        (
            address instantLiquidity,
            address marketplace,
            address tokenSwap,
            address underlying
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        INSTANT_LIQUIDITY_ADDRESS,
                        TANGIBLE_MARKETPLACE_ADDRESS,
                        TOKEN_SWAP_ADDRESS,
                        UNDERLYING_ADDRESS
                    )
                ),
                (address, address, address, address)
            );
        IERC20(underlying).approve(tokenSwap, amountReserveToken);
        ITokenSwap(tokenSwap).exchange(
            underlying,
            address(paymentToken),
            amountReserveToken,
            toFillUpToItemPrice,
            ITokenSwap.EXCHANGE_TYPE.EXACT_OUTPUT
        );

        if (!instantLiquidity_) {
            paymentToken.approve(marketplace, itemPrice);
        } else {
            paymentToken.approve(instantLiquidity, itemPrice);
        }
    }

    function _convertToCorrectDecimals(
        uint256 price,
        uint8 inTokenDecimals,
        uint8 outTokenDecimals
    ) internal pure returns (uint256) {
        if (uint256(inTokenDecimals) > outTokenDecimals) {
            return price / (10**(inTokenDecimals - outTokenDecimals));
        } else if (uint256(inTokenDecimals) < outTokenDecimals) {
            return price * (10**(outTokenDecimals - inTokenDecimals));
        }
        return price;
    }

    function _checkPaymentTokenAndAmountNeeded(
        IERC20 paymentToken,
        uint256 amount
    ) internal view returns (uint256 reserveAmount) {
        if (amount == 0) {
            return reserveAmount;
        }
        (address tokenSwap, address underlying) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TOKEN_SWAP_ADDRESS, UNDERLYING_ADDRESS)
            ),
            (address, address)
        );
        uint8 paymentDecimals = IERC20Metadata(address(paymentToken))
            .decimals();
        uint8 underlyingDecimals = IERC20Metadata(underlying).decimals();
        // we use this algorithm because curve doesn't have ability to calculate quoteIn
        reserveAmount = _convertToCorrectDecimals(
            amount,
            paymentDecimals,
            underlyingDecimals
        );
        uint256 calcAmount;
        do {
            calcAmount = ITokenSwap(tokenSwap).quoteOut(
                underlying,
                address(paymentToken),
                reserveAmount
            );

            if (calcAmount < amount) {
                reserveAmount =
                    reserveAmount +
                    _convertToCorrectDecimals(
                        amount - calcAmount,
                        paymentDecimals,
                        underlyingDecimals
                    ) +
                    10**uint256(underlyingDecimals); // add 1 dollar
            }
        } while (calcAmount < amount);
    }
}

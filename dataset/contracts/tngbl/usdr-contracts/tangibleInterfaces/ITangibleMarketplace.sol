// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITangibleInterfaces.sol";

interface IFactoryExt {
    struct TnftWithId {
        ITangibleNFT tnft;
        uint256 tnftTokenId;
        bool initialSaleDone;
    }

    function storageManagers(ITangibleFractionsNFT ftnft)
        external
        view
        returns (IFractionStorageManager);

    function defUSD() external view returns (IERC20);

    function paymentTokens(IERC20 token) external view returns (bool);

    function fractionToTnftAndId(ITangibleFractionsNFT fraction)
        external
        view
        returns (TnftWithId memory);

    function initReSeller() external view returns (address);
}

/// @title ITangibleMarketplace interface defines the interface of the Marketplace
interface ITangibleMarketplace {
    struct Lot {
        ITangibleNFT nft;
        IERC20 paymentToken;
        uint256 tokenId;
        address seller;
        uint256 price;
        bool minted;
    }

    struct LotFract {
        ITangibleFractionsNFT nft;
        IERC20 paymentToken;
        uint256 tokenId;
        address seller;
        uint256 price; //total wanted price for share
        uint256 minShare;
        uint256 initialShare;
    }

    function marketplace(address tnft, uint256 tokenId)
        external
        view
        returns (Lot memory);

    function marketplaceFract(address ftnft, uint256 fractionId)
        external
        view
        returns (LotFract memory);

    function factory() external view returns (IFactoryExt);

    /// @dev The function allows anyone to put on sale the TangibleNFTs they own
    /// if price is 0 - use oracle when selling
    function sellBatch(
        ITangibleNFT nft,
        IERC20 paymentToken,
        uint256[] calldata tokenIds,
        uint256[] calldata price
    ) external;

    /// @dev The function allows the owner of the minted TangibleNFT items to remove them from the Marketplace
    function stopBatchSale(ITangibleNFT nft, uint256[] calldata tokenIds)
        external;

    /// @dev The function allows the user to buy any TangibleNFT from the Marketplace for USDC
    function buy(
        ITangibleNFT nft,
        uint256 tokenId,
        uint256 _years
    ) external;

    /// @dev The function allows the user to buy any TangibleNFT from the Marketplace for USDC this is for unminted items
    function buyUnminted(
        ITangibleNFT nft,
        uint256 _fingerprint,
        uint256 _years,
        bool _onlyLock
    ) external;

    function buyFraction(
        ITangibleFractionsNFT ftnft,
        uint256 fractTokenId,
        uint256 share
    ) external;

    function sellFraction(
        ITangibleFractionsNFT ftnft,
        IERC20 paymentToken,
        uint256 fractTokenId,
        uint256[] calldata shares,
        uint256 price,
        uint256 minPurchaseShare
    ) external;

    /// @dev The function which buys additional storage to token.
    function payStorage(
        ITangibleNFT nft,
        uint256 tokenId,
        uint256 _years
    ) external;

    function sellFractionInitial(
        ITangibleNFT tnft,
        IERC20 paymentToken,
        uint256 tokenId,
        uint256 keepShare,
        uint256 sellShare,
        uint256 sellSharePrice,
        uint256 minPurchaseShare
    ) external returns (ITangibleFractionsNFT ftnft, uint256 tokenToSell);

    function stopFractSale(ITangibleFractionsNFT ftnft, uint256 tokenId)
        external;
}

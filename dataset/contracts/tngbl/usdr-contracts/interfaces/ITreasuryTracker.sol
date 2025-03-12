// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ITreasuryTracker {
    struct FractionIdData {
        address tnft;
        uint256 tnftTokenId;
        uint256 share;
        uint256 fractionId;
    }

    function tnftTreasuryPlaced(
        address tnft,
        uint256 tokenId,
        bool placed
    ) external;

    function ftnftTreasuryPlaced(
        address ftnft,
        uint256 tokenId,
        bool placed
    ) external;

    function updateFractionData(address ftnft, uint256 tokenId) external;

    function getFractionTokensDataInTreasury(address ftnft)
        external
        view
        returns (FractionIdData[] memory fData);

    function getRwaUsdValue(IERC20Metadata token)
        external
        view
        returns (
            uint256 usdValue,
            uint256 usdValueEscrow,
            bool priceUpToDate
        );

    function addValueAfterPurchase(
        string calldata currency,
        uint256 value,
        bool notInEscrow,
        uint256 ptAmount,
        uint8 ptDecimals
    ) external;

    function subValueAfterPurchase(string calldata currency, uint256 value)
        external;
}

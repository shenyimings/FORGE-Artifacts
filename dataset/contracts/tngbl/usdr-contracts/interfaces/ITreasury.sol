// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ITreasury {
    struct TNGBLLiquidity {
        uint256 tngbl;
        uint256 underlying;
        uint256 liquidity;
    }

    struct TreasuryValue {
        uint256 stable;
        uint256 usdr;
        uint256 rwa;
        uint256 tngbl;
        uint256 liquidity;
        TNGBLLiquidity tngblLiquidity;
        uint256 debt;
        uint256 total;
        uint256 rwaVaults;
        uint256 rwaEscrow;
        bool rwaValueNotLatest;
    }

    struct AddressHolder {
        address calculator;
        address oracle;
        address tngbl;
        address underlying;
        address usdr;
        address liquidityManager;
        address tngblLiquidityManager;
        address promissory;
        address tracker;
        address marketplace;
    }

    event RentClaimed(address indexed rentToken, uint256 amountClaimed);
    event TNGBLClaimed(address indexed tngbl, uint256 claimedAmountTngbl);
    event RevenueShareClaimed(
        address indexed revenueToken,
        uint256 claimedAmountRev
    );

    function purchaseStableMintedRedeemedThreshold()
        external
        view
        returns (uint8);

    function purchaseStableMarketcapThreshold() external view returns (uint8);

    function multicall(address[] calldata contracts, bytes[] calldata data)
        external
        returns (bytes[] memory results);

    function withdraw(
        address token,
        uint256 amount,
        address receiver
    ) external;

    function getTreasuryValue() external view returns (TreasuryValue memory);

    function updateTrackerFtnftExt(
        address ftnft,
        uint256 tokenId,
        bool placed
    ) external;

    function updateTrackerTnftExt(
        address tnft,
        uint256 tokenId,
        bool placed
    ) external;

    function purchaseReInitialSale(
        IERC20 paymentToken,
        address ftnft,
        uint256 fractTokenId,
        uint256 share,
        uint256 ptAmount
    ) external;
}

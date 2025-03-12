// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITangibleInterfaces.sol";

/// @title IInstantLiquidity defines interaface of InstantLiquidity engine
interface IInstantLiquidity {
    struct InstantLot {
        address nft;
        uint256 tokenId;
        address seller;
        bool fraction;
    }

    event ExchangeAddressSet(
        address indexed oldAddress,
        address indexed newAddress
    );

    event FactoryAddressSet(
        address indexed oldAddress,
        address indexed newAddress
    );

    event TNGBLOracleAddressSet(
        address indexed oldAddress,
        address indexed newAddress
    );

    event IILCalculatorAddressSet(
        address indexed oldAddress,
        address indexed newAddress
    );

    event DefaultToken(IERC20 token);

    function sellInstant(
        ITangibleNFT _nft,
        uint256 _fingerprint,
        uint256 _tokenId
    ) external;

    function buyInstant(ITangibleNFT _nft, uint256 _tokenId) external;

    function sellInstantFraction(ITangibleFractionsNFT _nft, uint256 _tokenId)
        external;

    function buyFractionInstant(
        ITangibleFractionsNFT _ftnft,
        uint256 _tokenFractId
    ) external;

    function withdrawUSDC() external;

    function withdrawTNGBL() external;
}

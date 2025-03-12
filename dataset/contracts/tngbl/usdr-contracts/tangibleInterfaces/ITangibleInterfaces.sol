// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

interface ITangibleNFT {
    function storagePricePerYear() external view returns (uint256);

    function storagePercentagePricePerYear() external view returns (uint256);

    function storagePriceFixed() external view returns (bool);

    function storageRequired() external view returns (bool);

    function tnftToPassiveNft(uint256 tokenId) external view returns (uint256);

    function claim(uint256 tokenId, uint256 amount) external;

    function tokensFingerprint(uint256 tokenId) external view returns (uint256);
}

interface ITangibleFractionsNFT {
    function defractionalize(uint256[] memory tokenIds) external;

    function tnft() external view returns (ITangibleNFT nft);

    function tnftTokenId() external view returns (uint256 tokenId);

    function tnftFingerprint() external view returns (uint256 fingerprint);

    function fractionShares(uint256 fractionId)
        external
        view
        returns (uint256 share);

    function fullShare() external view returns (uint256 fullShare);

    function claim(uint256 fractionId, uint256 amount) external;

    function claimableIncome(uint256 fractionId)
        external
        view
        returns (uint256);
}

interface IFractionStorageManager {
    function payShareStorage(uint256 tokenId) external;
}

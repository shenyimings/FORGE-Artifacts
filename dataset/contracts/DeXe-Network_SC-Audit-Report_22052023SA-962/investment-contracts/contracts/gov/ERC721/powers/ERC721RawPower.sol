// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "./AbstractERC721Power.sol";

contract ERC721RawPower is AbstractERC721Power {
    using Math for uint256;

    function __ERC721RawPower_init(
        string calldata name,
        string calldata symbol,
        uint64 startTimestamp,
        address _collateralToken,
        uint256 _reductionPercent,
        uint256 _nftMaxRawPower,
        uint256 _nftRequiredCollateral
    ) external initializer {
        __AbstractERC721Power_init(
            name,
            symbol,
            startTimestamp,
            _collateralToken,
            _reductionPercent,
            _nftMaxRawPower,
            _nftRequiredCollateral
        );
    }

    function addCollateral(uint256 amount, uint256 tokenId) external override {
        _addCollateral(amount, tokenId);
    }

    function removeCollateral(uint256 amount, uint256 tokenId) external override {
        _removeCollateral(amount, tokenId);
    }

    function recalculateNftPowers(uint256[] calldata tokenIds) external override {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _recalculateRawNftPower(tokenIds[i]);
        }
    }

    function totalPower() external view override returns (uint256) {
        return totalRawPower;
    }

    function getNftMaxPower(uint256 tokenId) public view override returns (uint256) {
        return _getRawNftMaxPower(tokenId).min(totalRawPower);
    }

    function getNftMinPower(uint256 tokenId) public view override returns (uint256) {
        return _getRawNftMinPower(tokenId).min(totalRawPower);
    }

    function getNftPower(uint256 tokenId) public view override returns (uint256) {
        return _getRawNftPower(tokenId).min(totalRawPower);
    }

    function getNftRequiredCollateral(uint256 tokenId) external view override returns (uint256) {
        return _getNftRequiredCollateral(tokenId);
    }
}

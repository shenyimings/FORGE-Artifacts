// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../libs/math/MathHelper.sol";

import "./AbstractERC721Power.sol";

contract ERC721EquivalentPower is AbstractERC721Power {
    using Math for uint256;
    using MathHelper for uint256;

    uint256 internal _powerEquivalent;

    function __ERC721EquivalentPower_init(
        string calldata name,
        string calldata symbol,
        uint64 startTimestamp,
        address _collateralToken,
        uint256 _reductionPercent,
        uint256 _nftMaxRawPower,
        uint256 _nftRequiredCollateral,
        uint256 powerEquivalent
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

        _powerEquivalent = powerEquivalent;
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
        return _powerEquivalent;
    }

    function getNftMaxPower(uint256 tokenId) public view override returns (uint256) {
        return _getEquivalentPower(_getRawNftMaxPower(tokenId));
    }

    function getNftMinPower(uint256 tokenId) public view override returns (uint256) {
        return _getEquivalentPower(_getRawNftMinPower(tokenId));
    }

    function getNftPower(uint256 tokenId) public view override returns (uint256) {
        return _getEquivalentPower(_getRawNftPower(tokenId));
    }

    function getNftRequiredCollateral(uint256 tokenId) external view override returns (uint256) {
        return _getNftRequiredCollateral(tokenId);
    }

    function _getEquivalentPower(uint256 power) internal view returns (uint256) {
        return
            totalRawPower == 0
                ? 0
                : _powerEquivalent.ratio(power, totalRawPower).min(_powerEquivalent);
    }
}

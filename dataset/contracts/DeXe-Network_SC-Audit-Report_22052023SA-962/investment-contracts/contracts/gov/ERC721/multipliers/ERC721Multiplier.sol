// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../libs/math/MathHelper.sol";

import "./AbstractERC721Multiplier.sol";

import "../../../core/Globals.sol";

contract ERC721Multiplier is AbstractERC721Multiplier {
    using MathHelper for uint256;

    function mint(
        address to,
        uint256 multiplier,
        uint64 duration,
        string calldata uri_
    ) external onlyOwner {
        _mint(to, multiplier, duration, uri_);
    }

    function changeToken(uint256 tokenId, uint256 multiplier, uint64 duration) external onlyOwner {
        _changeToken(tokenId, multiplier, duration);
    }

    function getExtraRewards(
        address whose,
        uint256 rewards
    ) external view override returns (uint256) {
        (, uint256 multiplier, ) = _getCurrentMultiplier(whose);

        return rewards.ratio(multiplier, PRECISION);
    }

    function getCurrentMultiplier(
        address whose
    ) external view returns (uint256 multiplier, uint256 timeLeft) {
        (, multiplier, timeLeft) = _getCurrentMultiplier(whose);
    }
}

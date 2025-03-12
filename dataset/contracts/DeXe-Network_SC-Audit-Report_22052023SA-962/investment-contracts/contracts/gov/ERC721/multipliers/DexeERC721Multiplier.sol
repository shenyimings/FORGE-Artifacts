// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../interfaces/gov/ERC721/multipliers/IDexeERC721Multiplier.sol";

import "../../../libs/math/MathHelper.sol";

import "./AbstractERC721Multiplier.sol";

contract DexeERC721Multiplier is IDexeERC721Multiplier, AbstractERC721Multiplier, UUPSUpgradeable {
    using MathHelper for uint256;
    using Math for uint256;

    uint256 public constant MULTIPLIER_SLASHING_PERCENTAGE = PERCENTAGE_100 / 10; // 10%

    mapping(address => uint256) internal _averageBalances; // user => average balance
    mapping(uint256 => uint256) internal _multiplierSlashing; // token => slashing percentage

    event AverageBalanceChanged(address user, uint256 averageBalance);

    function mint(
        address to,
        uint256 multiplier,
        uint64 duration,
        uint256 averageBalance,
        string calldata uri_
    ) external onlyOwner {
        _mint(to, multiplier, duration, uri_);

        _averageBalances[to] = averageBalance;

        emit AverageBalanceChanged(to, averageBalance);
    }

    function changeToken(
        uint256 tokenId,
        uint256 multiplier,
        uint64 duration,
        uint256 averageBalance
    ) external onlyOwner {
        _changeToken(tokenId, multiplier, duration);

        address owner = ownerOf(tokenId);

        _averageBalances[owner] = averageBalance;

        emit AverageBalanceChanged(owner, averageBalance);
    }

    function getExtraRewards(
        address whose,
        uint256 rewards
    ) external view override returns (uint256) {
        (uint256 multiplier, ) = getCurrentMultiplier(whose, rewards);

        return rewards.ratio(multiplier, PRECISION);
    }

    function getCurrentMultiplier(
        address whose,
        uint256 rewards
    ) public view returns (uint256 multiplier, uint256 timeLeft) {
        uint256 tokenId;
        (tokenId, multiplier, timeLeft) = _getCurrentMultiplier(whose);

        uint256 averageBalance = _averageBalances[whose];

        if (multiplier == 0 || averageBalance == 0) {
            return (multiplier, timeLeft);
        }

        multiplier = multiplier.percentage(PERCENTAGE_100 - _multiplierSlashing[tokenId]);

        uint256 coefficient = rewards.ratio(PRECISION, averageBalance).ratio(
            PRECISION,
            multiplier
        );

        if (coefficient > PRECISION) {
            multiplier = multiplier.ratio(PRECISION, coefficient);
        }

        multiplier = multiplier.max(PRECISION) - PRECISION;
    }

    function _afterTokenUnlock(uint256 tokenId) internal override {
        super._afterTokenUnlock(tokenId);

        _multiplierSlashing[tokenId] = (_multiplierSlashing[tokenId] +
            MULTIPLIER_SLASHING_PERCENTAGE).min(PERCENTAGE_100);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

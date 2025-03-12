// SPDX-Identifier: MIT
pragma solidity 0.8.16;

interface ILeoEvents {
    event CampaignBalanceUpdated(
        bytes8 indexed identifier,
        uint256 indexed newMaximum
    );

    event CampaignCreated(
        bytes8 indexed identifier,
        address indexed pool,
        address indexed token,
        uint256 details, // [tick lower, tick upper, owner],
        uint256 times // [starting, ending]
    );

    event CampaignUpdated(
        bytes8 indexed identifier,
        address indexed pool,
        uint256 indexed perSecond,
        uint256 extras // [tick lower, tick upper, starting, ending]
    );
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRDNTRewardManager {
    /* ============ External Getters ============ */

    function totalStaked(address _asset) external view returns (uint256);

    function balanceOf(address _asset, address _account) external view returns (uint256);

    function entitledPerToken(address _asset) external view returns (uint256);

    function entitledRDNT(address _account) external view returns (uint256);

    function entitledRDNTByAsset(address _asset, address _account) external view returns (uint256);

    function entitledRdntGauge()
        external
        view
        returns (uint256 totalWeight, address[] memory assets, uint256[] memory weights);

    /* ============ External Functions ============ */

    function updateFor(address _account, address _asset) external;

    function vestRDNT() external;

    /* ============ Admin Functions ============ */

    function updateRewardQueuer(address _rewardManager, bool _allowed) external;

    function queueEntitledRDNT(address _asset, uint256 _rdntAmount) external;

    function addRegisteredReceipt(address _receiptToken) external;
}

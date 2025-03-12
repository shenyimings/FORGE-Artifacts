// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../libs/MinerTypes.sol";

interface IMinerFormulas {
    function BASE_DIVIDER() external view returns (uint256);

    function METAMINER_MINER_POOL_SHARE_PERCENT()
        external
        view
        returns (uint256);

    function MACROMINER_ARCHIVE_HARD_CAP_OF_FIRST_FORMULA()
        external
        view
        returns (uint256);

    function MACROMINER_ARCHIVE_HARD_CAP_OF_SECOND_FORMULA()
        external
        view
        returns (uint256);

    function MACROMINER_ARCHIVE_DAILY_MAX_REWARD()
        external
        view
        returns (uint256);

    function MACROMINER_FULLNODE_HARD_CAP_OF_FIRST_FORMULA()
        external
        view
        returns (uint256);

    function MACROMINER_FULLNODE_HARD_CAP_OF_SECOND_FORMULA()
        external
        view
        returns (uint256);

    function MACROMINER_FULLNODE_DAILY_MAX_REWARD()
        external
        view
        returns (uint256);

    function MACROMINER_LIGHT_HARD_CAP_OF_FIRST_FORMULA()
        external
        view
        returns (uint256);

    function MACROMINER_LIGHT_HARD_CAP_OF_SECOND_FORMULA()
        external
        view
        returns (uint256);

    function MACROMINER_LIGHT_DAILY_MAX_REWARD()
        external
        view
        returns (uint256);

    function SECONDS_IN_A_DAY() external view returns (uint256);

    function calculateMetaminerReward() external view returns (uint256);

    function calculateMetaPointsReward() external pure returns (uint256);

    function calculateDailyPoolRewardsFromFirstFormula(
        MinerTypes.NodeType nodeType
    ) external view returns (uint256);

    function calculateDailyPoolRewardsFromSecondFormula(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external view returns (uint256);

    function getDate() external pure returns (uint256);
}

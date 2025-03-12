// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @dev Interface of the VeDxp
 */
interface ITokenFarm {
    function claimable(address _account) external view returns (uint256);
    function cooldownDuration() external view returns (uint256);
    function getTierNav(address _account) external view returns (uint256);
    function getStakedNav(address _account) external view returns (uint256, uint256);
    function getStakedNLP(address _account) external view returns (uint256, uint256);
    function getTotalVested(address _account) external view returns (uint256);
    function pendingTokens(bool _isNavPool, address _user) external view returns (
        address[] memory,
        string[] memory,
        uint256[] memory,
        uint256[] memory
    );
}

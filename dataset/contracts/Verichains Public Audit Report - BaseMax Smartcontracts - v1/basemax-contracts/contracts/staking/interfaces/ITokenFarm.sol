// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @dev Interface of the VeDxp
 */
interface ITokenFarm {
    function claimable(address _account) external view returns (uint256);
    function cooldownDuration() external view returns (uint256);
    function getTierBsm(address _account) external view returns (uint256);
    function getStakedBsm(address _account) external view returns (uint256, uint256);
    function getStakedBLP(address _account) external view returns (uint256, uint256);
    function getTotalVested(address _account) external view returns (uint256);
    function pendingTokens(bool _isBsmPool, address _user) external view returns (
        address[] memory,
        string[] memory,
        uint256[] memory,
        uint256[] memory
    );
}

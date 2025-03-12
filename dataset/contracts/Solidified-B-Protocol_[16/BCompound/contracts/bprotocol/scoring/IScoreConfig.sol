pragma solidity 0.5.16;

/**
 * @notice Interface to connect with Compound's ScoreConfig contract
 */
interface IScoreConfig {
    function getUserScore(address user) external view returns (uint256);
    function getGlobalScore() external view returns (uint256);
}

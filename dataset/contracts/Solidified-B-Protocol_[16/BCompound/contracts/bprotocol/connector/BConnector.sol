pragma solidity 0.5.16;

import { IScoreConfig } from "../scoring/IScoreConfig.sol";

/**
 * @notice B.Protocol Compound connector contract, which is used by Jar contract
 */
contract BConnector {

    IScoreConfig public scoreConfig;

    /**
     * @dev Constructor
     * @param _scoreConfig Address of ScoringConfig contract
     */
    constructor(address _scoreConfig) public {
        scoreConfig = IScoreConfig(_scoreConfig);
    }

    /**
     * @dev Get the User's total score from ScoringConfig contract
     * @param user User address in bytes32
     * @return The user's total score
     */
    function getUserScore(bytes32 user) external view returns (uint256) {
        return scoreConfig.getUserScore(toUser(user));
    }
    
    /**
     * @dev Get the Global score from the ScoringConfig contract
     * @return The total global score
     */
    function getGlobalScore() external view returns (uint256) {
        return scoreConfig.getGlobalScore();
    }
    
    function toUser(bytes32 user) public pure returns (address) {
        // Following the way described in 
        // the warning section https://solidity.readthedocs.io/en/v0.5.16/types.html#address

        // Extract left most 20 bytes from `bytes32` type and convert to `address` type
        return address(uint160(bytes20(user)));
    }
}
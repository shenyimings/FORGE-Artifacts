pragma solidity 0.5.16;

import { IBTokenScore } from "./IBTokenScore.sol";

import { ScoringConfig } from "../../../user-rating/contracts/score/ScoringConfig.sol";

/**
 * @notice Scoring Config implementation for Compound
 */
contract BScoringConfig is ScoringConfig {

    constructor(
        uint256 _debtScoreFactor,
        uint256 _collScoreFactor,
        uint256 _slashedScoreFactor,
        uint256 _slasherScoreFactor,
        address _scoringMachine
    ) 
        public
        ScoringConfig(
            _debtScoreFactor,
            _collScoreFactor,
            _slashedScoreFactor,
            _slasherScoreFactor,
            _scoringMachine
        )
    {}

    // @override
    function getUserDebtScore(address user, address token) internal view returns (uint256) {
        return getScoringMachine().getDebtScore(user, token, now, 0);
    }

    // @override
    function getUserCollScore(address user, address token) internal view returns (uint256) {
        return getScoringMachine().getCollScore(user, token, now, 0);
    }

    // @override
    function getUserSlashedScore(address user, address token) internal view returns (uint256) {
        return getScoringMachine().getSlashedScore(user, token, now, 0);
    }

    // @override
    function getUserSlasherScore(address user, address token) internal view returns (uint256) {
        return getScoringMachine().getSlasherScore(user, token, now, 0);
    }

    // @override
    function getGlobalDebtScore(address token) internal view returns (uint256) {
        return getScoringMachine().getDebtGlobalScore(token, now, 0);
    }

    // @override
    function getGlobalCollScore(address token) internal view returns (uint256) {
        return getScoringMachine().getCollGlobalScore(token, now, 0);
    }

    // @override
    function getGlobalSlashedScore(address token) internal view returns (uint256) {
        return getScoringMachine().getSlashedGlobalScore(token, now, 0);
    }

    // @override
    function getGlobalSlasherScore(address token) internal view returns (uint256) {
        return getScoringMachine().getSlasherGlobalScore(token, now, 0);
    }

    /**
     * @dev Get instance of ScoringMachine for Compound
     * @return IBTokenScore interface
     */
    function getScoringMachine() internal view returns (IBTokenScore) {
        return IBTokenScore(scoringMachine);
    }
}
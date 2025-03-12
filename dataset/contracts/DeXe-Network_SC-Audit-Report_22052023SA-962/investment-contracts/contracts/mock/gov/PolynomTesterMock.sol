// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/gov/IGovPool.sol";
import "../../interfaces/gov/user-keeper/IGovUserKeeper.sol";

contract PolynomialTesterMock {
    mapping(address => bool) internal _expertStatus;
    mapping(address => mapping(IGovPool.VoteType => uint256)) internal _votes;

    uint256 internal _totalVotes;

    function setExpertStatus(address user, bool isExpert) external {
        _expertStatus[user] = isExpert;
    }

    function setVotes(
        address user,
        uint256 personalVote,
        uint256 micropoolVote,
        uint256 treasuryVote
    ) external {
        _votes[user][IGovPool.VoteType.PersonalVote] = personalVote;
        _votes[user][IGovPool.VoteType.MicropoolVote] = micropoolVote;
        _votes[user][IGovPool.VoteType.TreasuryVote] = treasuryVote;
    }

    function setTotalVotes(uint256 votes) external {
        _totalVotes = votes;
    }

    function getHelperContracts()
        external
        view
        returns (
            address settings,
            address userKeeper,
            address validators,
            address poolRegistry,
            address votePower
        )
    {
        address zero = address(0);
        return (zero, address(this), zero, zero, zero);
    }

    receive() external payable {}

    function getExpertStatus(address user) external view returns (bool) {
        return _expertStatus[user];
    }

    function votingPower(
        address[] calldata users,
        IGovPool.VoteType[] calldata voteTypes,
        bool
    ) external view returns (IGovUserKeeper.VotingPowerView[] memory votingPowers) {
        votingPowers = new IGovUserKeeper.VotingPowerView[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            votingPowers[i].rawPower = _votes[users[i]][voteTypes[i]];
        }
    }

    function getTotalPower() external view returns (uint256) {
        return _totalVotes;
    }
}

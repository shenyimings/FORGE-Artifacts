// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../interfaces/gov/IGovPool.sol";
import "../../interfaces/gov/proposals/IDistributionProposal.sol";
import "../../interfaces/gov/proposals/IProposalValidator.sol";

import {GovPool} from "../GovPool.sol";

import "../../libs/math/MathHelper.sol";
import "../../libs/utils/TokenBalance.sol";

import "../../core/Globals.sol";

contract DistributionProposal is IDistributionProposal, IProposalValidator, Initializable {
    using SafeERC20 for IERC20Metadata;
    using MathHelper for uint256;
    using DecimalsConverter for *;
    using TokenBalance for address;

    address public govAddress;

    mapping(uint256 => IDistributionProposal.DPInfo) public proposals;

    event DistributionProposalClaimed(
        uint256 proposalId,
        address token,
        uint256 amount,
        address sender
    );

    modifier onlyGov() {
        require(msg.sender == govAddress, "DP: not a Gov contract");
        _;
    }

    function __DistributionProposal_init(address _govAddress) external initializer {
        require(_govAddress != address(0), "DP: _govAddress is zero");

        govAddress = _govAddress;
    }

    function execute(
        uint256 proposalId,
        address token,
        uint256 amount
    ) external payable override onlyGov {
        IDistributionProposal.DPInfo storage proposal = proposals[proposalId];

        require(proposal.rewardAddress == address(0), "DP: proposal already exists");
        require(token != address(0), "DP: zero address");
        require(amount > 0, "DP: zero amount");

        uint256 actualAmount = _getActualRewardAmount(proposalId, amount);

        if (token == ETHEREUM_ADDRESS) {
            require(amount == msg.value, "DP: wrong native amount");

            (bool ok, ) = payable(msg.sender).call{value: amount - actualAmount}("");
            require(ok, "DP: failed to send back eth");
        } else {
            require(msg.value == 0, "DP: wrong native amount");

            IERC20Metadata(token).safeTransferFrom(
                msg.sender,
                address(this),
                actualAmount.from18Safe(token)
            );
        }

        proposal.rewardAddress = token;
        proposal.rewardAmount = actualAmount;
    }

    function claim(address voter, uint256[] calldata proposalIds) external override {
        require(proposalIds.length > 0, "DP: zero array length");
        require(voter != address(0), "DP: zero address");

        for (uint256 i; i < proposalIds.length; i++) {
            DPInfo storage dpInfo = proposals[proposalIds[i]];
            address rewardToken = dpInfo.rewardAddress;

            require(rewardToken != address(0), "DP: zero address");
            require(!dpInfo.claimed[voter], "DP: already claimed");

            uint256 reward = getPotentialReward(proposalIds[i], voter);

            dpInfo.claimed[voter] = true;

            rewardToken.sendFunds(voter, reward);

            emit DistributionProposalClaimed(proposalIds[i], rewardToken, reward, voter);
        }
    }

    function validate(
        IGovPool.ProposalAction[] calldata actions
    ) external view override returns (bool valid) {
        uint256 proposalId = uint256(bytes32(actions[actions.length - 1].data[4:36]));

        return proposalId == GovPool(payable(govAddress)).latestProposalId();
    }

    function isClaimed(uint256 proposalId, address voter) external view override returns (bool) {
        return proposals[proposalId].claimed[voter];
    }

    function getPotentialReward(
        uint256 proposalId,
        address voter
    ) public view override returns (uint256) {
        (uint256 coreRawVotesFor, , uint256 personalRawTotalVoted, bool isVoteFor) = IGovPool(
            govAddress
        ).getTotalVotes(proposalId, voter, IGovPool.VoteType.PersonalVote);

        if (coreRawVotesFor == 0 || !isVoteFor) {
            return 0;
        }

        return proposals[proposalId].rewardAmount.ratio(personalRawTotalVoted, coreRawVotesFor);
    }

    function _getActualRewardAmount(
        uint256 proposalId,
        uint256 reward
    ) internal view returns (uint256) {
        (uint256 coreRawVotesFor, uint256 coreRawVotesAgainst, , ) = IGovPool(govAddress)
            .getTotalVotes(proposalId, address(0), IGovPool.VoteType.PersonalVote);

        return (reward * coreRawVotesFor) / (coreRawVotesFor + coreRawVotesAgainst);
    }
}

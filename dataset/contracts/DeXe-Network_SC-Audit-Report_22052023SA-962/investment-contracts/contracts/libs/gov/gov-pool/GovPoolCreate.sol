// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@solarity/solidity-lib/libs/utils/TypeCaster.sol";

import "../../../interfaces/factory/IPoolRegistry.sol";

import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/proposals/IProposalValidator.sol";
import "../../../interfaces/gov/user-keeper/IGovUserKeeper.sol";
import "../../../interfaces/gov/settings/IGovSettings.sol";
import "../../../interfaces/gov/validators/IGovValidators.sol";
import "../../../interfaces/gov/ERC721/experts/IERC721Expert.sol";

import "../../utils/DataHelper.sol";

import "../../../gov/GovPool.sol";

import "../../../libs/utils/TypeHelper.sol";
import "../../../libs/math/MathHelper.sol";

library GovPoolCreate {
    using EnumerableSet for EnumerableSet.UintSet;
    using DataHelper for bytes;
    using TypeCaster for *;
    using TypeHelper for *;
    using MathHelper for uint256;

    event ProposalCreated(
        uint256 proposalId,
        string proposalDescription,
        IGovPool.ProposalAction[] actionsOnFor,
        IGovPool.ProposalAction[] actionsOnAgainst,
        uint256 quorum,
        uint256 proposalSettings,
        address rewardToken,
        address sender
    );
    event MovedToValidators(uint256 proposalId, address sender);

    function createProposal(
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        mapping(address => IGovPool.UserInfo) storage userInfos,
        string calldata _descriptionURL,
        IGovPool.ProposalAction[] calldata actionsOnFor,
        IGovPool.ProposalAction[] calldata actionsOnAgainst
    ) external {
        (IGovSettings.ProposalSettings memory settings, uint256 settingsId) = _validateProposal(
            actionsOnFor,
            actionsOnAgainst
        );

        uint256 proposalId = GovPool(payable(address(this))).latestProposalId();

        uint256 exemptedTreasury = _exemptUserTreasuryFromVoting(
            userInfos,
            actionsOnFor,
            proposalId
        );

        if (exemptedTreasury != 0) {
            settings.quorum = uint128(
                _calculateNewQuorum(uint256(settings.quorum), exemptedTreasury)
            );

            assert(settings.quorum > 0);
        }

        IGovPool.Proposal storage proposal = proposals[proposalId];

        proposal.core = IGovPool.ProposalCore({
            settings: settings,
            voteEnd: uint64(block.timestamp + settings.duration),
            executeAfter: 0,
            executed: false,
            votesFor: 0,
            votesAgainst: 0,
            rawVotesFor: 0,
            rawVotesAgainst: 0,
            givenRewards: 0
        });
        proposal.descriptionURL = _descriptionURL;

        for (uint256 i; i < actionsOnFor.length; i++) {
            proposal.actionsOnFor.push(actionsOnFor[i]);
        }

        for (uint256 i; i < actionsOnAgainst.length; i++) {
            proposal.actionsOnAgainst.push(actionsOnAgainst[i]);
        }

        _canCreate(settings);

        emit ProposalCreated(
            proposalId,
            _descriptionURL,
            actionsOnFor,
            actionsOnAgainst,
            settings.quorum,
            settingsId,
            settings.rewardsInfo.rewardToken,
            msg.sender
        );
    }

    function moveProposalToValidators(
        mapping(uint256 => IGovPool.Proposal) storage proposals,
        uint256 proposalId
    ) external {
        IGovPool.ProposalCore storage core = proposals[proposalId].core;
        (, , address govValidators, , ) = IGovPool(address(this)).getHelperContracts();

        require(
            IGovPool(address(this)).getProposalState(proposalId) ==
                IGovPool.ProposalState.WaitingForVotingTransfer,
            "Gov: can't be moved"
        );

        IGovValidators(govValidators).createExternalProposal(
            proposalId,
            IGovValidators.ProposalSettings(
                core.settings.durationValidators,
                core.settings.executionDelay,
                core.settings.quorumValidators
            )
        );

        emit MovedToValidators(proposalId, msg.sender);
    }

    function _validateProposal(
        IGovPool.ProposalAction[] calldata actionsFor,
        IGovPool.ProposalAction[] calldata actionsAgainst
    ) internal view returns (IGovSettings.ProposalSettings memory settings, uint256 settingsId) {
        require(actionsFor.length != 0, "Gov: invalid array length");

        address mainExecutor = actionsFor[actionsFor.length - 1].executor;

        _validateProposalCreation(mainExecutor, actionsFor);

        (address govSettingsAddress, , , , ) = IGovPool(address(this)).getHelperContracts();
        IGovSettings govSettings = IGovSettings(govSettingsAddress);

        settingsId = govSettings.executorToSettings(mainExecutor);

        bool forceDefaultSettings = _handleDataForProposal(settingsId, govSettings, actionsFor);

        if (actionsAgainst.length != 0) {
            _validateMetaGovernance(actionsFor, actionsAgainst);
        }

        if (forceDefaultSettings) {
            settingsId = uint256(IGovSettings.ExecutorType.DEFAULT);
            settings = govSettings.getDefaultSettings();
        } else {
            settings = govSettings.getExecutorSettings(mainExecutor);
        }
    }

    function _exemptUserTreasuryFromVoting(
        mapping(address => IGovPool.UserInfo) storage userInfos,
        IGovPool.ProposalAction[] calldata actions,
        uint256 proposalId
    ) internal returns (uint256 exemptedTreasury) {
        IGovPool govPool = IGovPool(address(this));

        (, address userKeeperAddress, , , ) = govPool.getHelperContracts();
        (, address expertNft, address dexeExpertNft, ) = govPool.getNftContracts();

        IGovUserKeeper userKeeper = IGovUserKeeper(userKeeperAddress);

        for (uint256 i; i < actions.length; i++) {
            IGovPool.ProposalAction calldata action = actions[i];
            bytes4 selector = action.data.getSelector();
            address user;

            if (
                (action.executor == expertNft || action.executor == dexeExpertNft) &&
                selector == IERC721Expert.burn.selector
            ) {
                user = abi.decode(action.data[4:], (address));
            } else if (
                action.executor == address(this) &&
                (selector == IGovPool.delegateTreasury.selector ||
                    selector == IGovPool.undelegateTreasury.selector)
            ) {
                user = abi.decode(action.data[4:36], (address));
            } else {
                continue;
            }

            if (userInfos[user].treasuryExemptProposals.add(proposalId)) {
                exemptedTreasury += userKeeper
                .votingPower(
                    user.asSingletonArray(),
                    IGovPool.VoteType.TreasuryVote.asSingletonArray(),
                    false
                )[0].rawPower;
            }
        }
    }

    function _validateProposalCreation(
        address executor,
        IGovPool.ProposalAction[] calldata actionsFor
    ) internal view {
        (bool ok, bytes memory data) = executor.staticcall(
            abi.encodeWithSelector(IProposalValidator.validate.selector, actionsFor)
        );

        require(!ok || data.length == 0 || abi.decode(data, (bool)), "Gov: validation failed");
    }

    function _canCreate(IGovSettings.ProposalSettings memory settings) internal view {
        IGovPool govPool = IGovPool(address(this));

        (, , address dexeExpertNft, ) = govPool.getNftContracts();

        if (IERC721Expert(dexeExpertNft).isExpert(msg.sender)) {
            return;
        }

        (, address userKeeper, , , ) = govPool.getHelperContracts();

        require(
            IGovUserKeeper(userKeeper).canCreate(
                msg.sender,
                settings.delegatedVotingAllowed
                    ? IGovPool.VoteType.DelegatedVote
                    : IGovPool.VoteType.PersonalVote,
                settings.minVotesForCreating
            ),
            "Gov: low creating power"
        );
    }

    function _handleDataForInternalProposal(
        IGovSettings govSettings,
        IGovPool.ProposalAction[] calldata actions
    ) internal view {
        for (uint256 i; i < actions.length; i++) {
            bytes4 selector = actions[i].data.getSelector();
            uint256 executorSettings = govSettings.executorToSettings(actions[i].executor);

            if (actions[i].value != 0) {
                require(
                    executorSettings == uint256(IGovSettings.ExecutorType.INTERNAL) &&
                        selector == IGovPool.delegateTreasury.selector,
                    "Gov: invalid internal data"
                );
            } else {
                require(
                    executorSettings == uint256(IGovSettings.ExecutorType.INTERNAL) &&
                        (selector == IGovSettings.addSettings.selector ||
                            selector == IGovSettings.editSettings.selector ||
                            selector == IGovSettings.changeExecutors.selector ||
                            selector == IGovUserKeeper.setERC20Address.selector ||
                            selector == IGovUserKeeper.setERC721Address.selector ||
                            selector == IGovPool.changeVotePower.selector ||
                            selector == IGovPool.editDescriptionURL.selector ||
                            selector == IGovPool.setNftMultiplierAddress.selector ||
                            selector == IGovPool.changeVerifier.selector ||
                            selector == IGovPool.delegateTreasury.selector ||
                            selector == IGovPool.undelegateTreasury.selector ||
                            selector == IGovPool.changeBABTRestriction.selector ||
                            selector == IGovPool.setCreditInfo.selector),
                    "Gov: invalid internal data"
                );
            }
        }
    }

    function _handleDataForProposal(
        uint256 settingsId,
        IGovSettings govSettings,
        IGovPool.ProposalAction[] calldata actions
    ) internal view returns (bool) {
        if (settingsId == uint256(IGovSettings.ExecutorType.INTERNAL)) {
            _handleDataForInternalProposal(govSettings, actions);
            return false;
        }

        if (settingsId == uint256(IGovSettings.ExecutorType.VALIDATORS)) {
            _handleDataForValidatorBalanceProposal(actions);
            return false;
        }

        if (settingsId == uint256(IGovSettings.ExecutorType.DEFAULT)) {
            return false;
        }

        return _handleDataForExistingSettingsProposal(govSettings, settingsId, actions);
    }

    function _handleDataForExistingSettingsProposal(
        IGovSettings govSettings,
        uint256 lastSettings,
        IGovPool.ProposalAction[] calldata actions
    ) internal view returns (bool) {
        for (uint256 i; i < actions.length - 1; i++) {
            bytes4 selector = actions[i].data.getSelector();

            if (
                govSettings.executorToSettings(actions[i].executor) != lastSettings &&
                (actions[i].value != 0 ||
                    (selector != IERC20.approve.selector && // same as selector != IERC721.approve.selector
                        selector != IERC721.setApprovalForAll.selector)) // same as IERC1155.setApprovalForAll.selector
            ) {
                return true; // should use default settings
            }
        }

        return false;
    }

    function _calculateNewQuorum(
        uint256 quorum,
        uint256 exemptedTreasury
    ) internal view returns (uint256) {
        (, address userKeeper, , , ) = IGovPool(address(this)).getHelperContracts();

        uint256 totalVoteWeight = IGovUserKeeper(userKeeper).getTotalPower();
        uint256 newTotalVoteWeight = (totalVoteWeight - exemptedTreasury).percentage(quorum);

        return PERCENTAGE_100.ratio(newTotalVoteWeight, totalVoteWeight);
    }

    function _validateMetaGovernance(
        IGovPool.ProposalAction[] calldata actionsFor,
        IGovPool.ProposalAction[] calldata actionsAgainst
    ) internal view {
        require(actionsFor.length == actionsAgainst.length, "Gov: invalid actions length");

        address metaGovPool = _validateVote(
            actionsFor[actionsFor.length - 1],
            actionsAgainst[actionsAgainst.length - 1]
        );

        for (uint256 i; i < actionsFor.length - 1; i++) {
            _validateApproveOrDeposit(actionsFor[i], actionsAgainst[i], metaGovPool);
        }
    }

    function _validateVote(
        IGovPool.ProposalAction calldata actionFor,
        IGovPool.ProposalAction calldata actionAgainst
    ) internal view returns (address metaGovPool) {
        (, , , address poolRegistryAddress, ) = IGovPool(address(this)).getHelperContracts();

        metaGovPool = actionFor.executor;

        require(metaGovPool == actionAgainst.executor, "Gov: invalid executor");
        require(
            IPoolRegistry(poolRegistryAddress).isGovPool(metaGovPool),
            "Gov: invalid executor"
        );

        bytes4 selector = actionFor.data.getSelector();

        require(
            selector == IGovPool.vote.selector && selector == actionAgainst.data.getSelector(),
            "Gov: invalid selector"
        );

        (
            uint256 proposalIdFor,
            bool isVoteForFor,
            uint256 voteAmountFor,
            uint256[] memory voteNftsFor
        ) = _decodeVoteFunction(actionFor);
        (
            uint256 proposalIdAgainst,
            bool isVoteForAgainst,
            uint256 voteAmountAgainst,
            uint256[] memory voteNftsAgainst
        ) = _decodeVoteFunction(actionAgainst);

        require(proposalIdFor == proposalIdAgainst, "Gov: invalid proposal id");
        require(isVoteForFor && !isVoteForAgainst, "Gov: invalid vote");
        require(voteAmountFor == voteAmountAgainst, "Gov: invalid vote amount");
        require(voteNftsFor.length == voteNftsAgainst.length, "Gov: invalid nfts length");

        for (uint256 i = 0; i < voteNftsFor.length; i++) {
            require(voteNftsFor[i] == voteNftsAgainst[i], "Gov: invalid nft vote");
        }
    }

    function _validateApproveOrDeposit(
        IGovPool.ProposalAction calldata actionFor,
        IGovPool.ProposalAction calldata actionAgainst,
        address metaGovPool
    ) internal view {
        (, address metaUserKeeper, , , ) = IGovPool(metaGovPool).getHelperContracts();

        require(actionFor.executor == actionAgainst.executor, "Gov: invalid executor");

        bytes4 selector = actionFor.data.getSelector();

        require(selector == actionAgainst.data.getSelector(), "Gov: invalid selector");

        if (selector == IERC20.approve.selector) {
            _validateApprove(actionFor, actionAgainst, metaUserKeeper);
        } else if (selector == IERC721.setApprovalForAll.selector) {
            _validateSetApprovalForAll(actionFor, actionAgainst, metaUserKeeper);
        } else if (selector == IGovPool.deposit.selector) {
            _validateDeposit(actionFor, actionAgainst, metaGovPool);
        } else {
            revert("Gov: selector not supported");
        }
    }

    function _validateApprove(
        IGovPool.ProposalAction calldata actionFor,
        IGovPool.ProposalAction calldata actionAgainst,
        address metaUserKeeper
    ) internal view {
        address metaToken = IGovUserKeeper(metaUserKeeper).tokenAddress();
        address metaNft = IGovUserKeeper(metaUserKeeper).nftAddress();

        require(
            actionFor.executor == metaToken || actionFor.executor == metaNft,
            "Gov: invalid executor"
        );

        (address spenderFor, uint256 amountFor) = _decodeApproveFunction(actionFor);
        (address spenderAgainst, uint256 amountAgainst) = _decodeApproveFunction(actionAgainst);

        require(
            spenderFor == metaUserKeeper && spenderFor == spenderAgainst,
            "Gov: invalid spender"
        );
        require(amountFor == amountAgainst, "Gov: invalid amount");
    }

    function _validateSetApprovalForAll(
        IGovPool.ProposalAction calldata actionFor,
        IGovPool.ProposalAction calldata actionAgainst,
        address metaUserKeeper
    ) internal view {
        address metaNft = IGovUserKeeper(metaUserKeeper).nftAddress();

        require(actionFor.executor == metaNft, "Gov: invalid executor");

        (address operatorFor, bool approvedFor) = _decodeSetApprovalForAllFunction(actionFor);
        (address operatorAgainst, bool approvedAgainst) = _decodeSetApprovalForAllFunction(
            actionAgainst
        );

        require(
            operatorFor == metaUserKeeper && operatorFor == operatorAgainst,
            "Gov: invalid operator"
        );
        require(approvedFor == approvedAgainst, "Gov: invalid approve");
    }

    function _validateDeposit(
        IGovPool.ProposalAction calldata actionFor,
        IGovPool.ProposalAction calldata actionAgainst,
        address metaGovPool
    ) internal pure {
        (uint256 amountFor, uint256[] memory nftIdsFor) = _decodeDepositFunction(actionFor);
        (uint256 amountAgainst, uint256[] memory nftIdsAgainst) = _decodeDepositFunction(
            actionAgainst
        );

        require(actionFor.executor == metaGovPool, "Gov: invalid executor");
        require(amountFor == amountAgainst, "Gov: invalid amount");
        require(actionFor.value == actionAgainst.value, "Gov: invalid value");
        require(nftIdsFor.length == nftIdsAgainst.length, "Gov: invalid nfts length");

        for (uint256 i = 0; i < nftIdsFor.length; i++) {
            require(nftIdsFor[i] == nftIdsAgainst[i], "Gov: invalid nft deposit");
        }
    }

    function _handleDataForValidatorBalanceProposal(
        IGovPool.ProposalAction[] calldata actions
    ) internal pure {
        require(actions.length == 1, "Gov: invalid executors length");

        for (uint256 i; i < actions.length; i++) {
            bytes4 selector = actions[i].data.getSelector();

            require(
                actions[i].value == 0 && (selector == IGovValidators.changeBalances.selector),
                "Gov: invalid internal data"
            );
        }
    }

    function _decodeVoteFunction(
        IGovPool.ProposalAction calldata action
    )
        internal
        pure
        returns (
            uint256 proposalId,
            bool isVoteFor,
            uint256 voteAmount,
            uint256[] memory voteNftIds
        )
    {
        (proposalId, isVoteFor, voteAmount, voteNftIds) = abi.decode(
            action.data[4:],
            (uint256, bool, uint256, uint256[])
        );
    }

    function _decodeDepositFunction(
        IGovPool.ProposalAction calldata action
    ) internal pure returns (uint256 amount, uint256[] memory nftIds) {
        (amount, nftIds) = abi.decode(action.data[4:], (uint256, uint256[]));
    }

    function _decodeApproveFunction(
        IGovPool.ProposalAction calldata action
    ) internal pure returns (address spender, uint256 amount) {
        (spender, amount) = abi.decode(action.data[4:], (address, uint256));
    }

    function _decodeSetApprovalForAllFunction(
        IGovPool.ProposalAction calldata action
    ) internal pure returns (address operator, bool approved) {
        (operator, approved) = abi.decode(action.data[4:], (address, bool));
    }
}

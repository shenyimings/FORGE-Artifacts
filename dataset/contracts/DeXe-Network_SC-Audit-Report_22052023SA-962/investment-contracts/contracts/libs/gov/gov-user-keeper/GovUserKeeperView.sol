// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/data-structures/memory/Vector.sol";
import "@solarity/solidity-lib/libs/utils/TypeCaster.sol";

import "../../../interfaces/gov/user-keeper/IGovUserKeeper.sol";
import "../../../interfaces/gov/voting/IVotePower.sol";
import "../../../interfaces/gov/ERC721/powers/IERC721Power.sol";

import "../../math/MathHelper.sol";
import "../../utils/TypeHelper.sol";

import "../../../gov/user-keeper/GovUserKeeper.sol";

library GovUserKeeperView {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Vector for Vector.UintVector;
    using MathHelper for uint256;
    using Math for uint256;
    using TypeCaster for *;
    using TypeHelper for *;

    function transformedVotingPower(
        mapping(address => IGovUserKeeper.UserInfo) storage usersInfo,
        IGovUserKeeper.NFTInfo storage nftInfo,
        address tokenAddress,
        address voter,
        uint256 amount,
        uint256[] calldata nftIds
    ) external view returns (uint256 personalPower, uint256 fullPower) {
        IGovUserKeeper.VotingPowerView[] memory votingPowers = votingPower(
            usersInfo,
            nftInfo,
            tokenAddress,
            [voter, voter].asDynamic(),
            [IGovPool.VoteType.MicropoolVote, IGovPool.VoteType.TreasuryVote].asDynamic(),
            false
        );

        (uint256 nftPower, ) = getTotalNftsPower(
            usersInfo,
            nftInfo,
            nftIds,
            IGovPool.VoteType.PersonalVote,
            voter,
            false
        );

        (, , , , address votePower) = IGovPool(GovUserKeeper(payable(address(this))).owner())
            .getHelperContracts();

        personalPower = amount + nftPower;
        fullPower = personalPower + votingPowers[0].rawPower + votingPowers[1].rawPower;

        personalPower = IVotePower(votePower).transformVotes(voter, personalPower);
        fullPower = IVotePower(votePower).transformVotes(voter, fullPower);
    }

    function votingPower(
        mapping(address => IGovUserKeeper.UserInfo) storage usersInfo,
        IGovUserKeeper.NFTInfo storage nftInfo,
        address tokenAddress,
        address[] memory users,
        IGovPool.VoteType[] memory voteTypes,
        bool perNftPowerArray
    ) public view returns (IGovUserKeeper.VotingPowerView[] memory votingPowers) {
        GovUserKeeper userKeeper = GovUserKeeper(payable(address(this)));
        votingPowers = new IGovUserKeeper.VotingPowerView[](users.length);

        for (uint256 i = 0; i < users.length; i++) {
            IGovUserKeeper.VotingPowerView memory power = votingPowers[i];

            if (tokenAddress != address(0)) {
                (power.power, power.ownedBalance) = userKeeper.tokenBalance(
                    users[i],
                    voteTypes[i]
                );

                power.rawPower = power.power - power.ownedBalance;
            }

            if (nftInfo.nftAddress != address(0)) {
                uint256[] memory nftIds;
                uint256 length;

                if (!perNftPowerArray) {
                    (, length) = userKeeper.nftBalance(users[i], voteTypes[i]);
                } else {
                    (nftIds, length) = userKeeper.nftExactBalance(users[i], voteTypes[i]);
                }

                (power.nftPower, power.perNftPower) = getTotalNftsPower(
                    usersInfo,
                    nftInfo,
                    nftIds,
                    voteTypes[i],
                    users[i],
                    perNftPowerArray
                );

                if (perNftPowerArray) {
                    assembly {
                        mstore(nftIds, sub(mload(nftIds), length))
                    }
                }

                (power.rawNftPower, ) = getTotalNftsPower(
                    usersInfo,
                    nftInfo,
                    nftIds,
                    voteTypes[i],
                    users[i],
                    perNftPowerArray
                );

                if (perNftPowerArray) {
                    assembly {
                        mstore(nftIds, add(mload(nftIds), length))
                    }
                }

                power.nftIds = nftIds;
                power.ownedLength = length;

                power.power += power.nftPower;
                power.rawPower += power.rawNftPower;
            }
        }
    }

    function getTotalNftsPower(
        mapping(address => IGovUserKeeper.UserInfo) storage usersInfo,
        IGovUserKeeper.NFTInfo storage nftInfo,
        uint256[] memory nftIds,
        IGovPool.VoteType voteType,
        address user,
        bool perNftPowerArray
    ) public view returns (uint256 nftPower, uint256[] memory perNftPower) {
        if (nftInfo.nftAddress == address(0)) {
            return (nftPower, perNftPower);
        }

        if (user != address(0)) {
            if (
                voteType == IGovPool.VoteType.MicropoolVote ||
                voteType == IGovPool.VoteType.TreasuryVote
            ) {
                if (perNftPowerArray) {
                    uint256 individualPower = nftInfo.individualPower;
                    perNftPower = new uint256[](nftIds.length);

                    if (!nftInfo.isSupportPower) {
                        for (uint256 i = 0; i < perNftPower.length; i++) {
                            perNftPower[i] = individualPower;
                        }

                        return (nftIds.length * individualPower, perNftPower);
                    }

                    for (uint256 i = 0; i < nftIds.length; ++i) {
                        uint256 currentNftPower = nftInfo.nftMinPower[nftIds[i]];

                        nftPower += currentNftPower;
                        perNftPower[i] = currentNftPower;
                    }

                    return (nftPower, perNftPower);
                } else {
                    return
                        nftInfo.isSupportPower
                            ? (usersInfo[user].nftsPowers[voteType], perNftPower)
                            : (
                                usersInfo[user].balances[voteType].nfts.length() *
                                    nftInfo.individualPower,
                                perNftPower
                            );
                }
            } else {
                return
                    _getActualNftPowers(
                        IERC721Power(nftInfo.nftAddress).getNftPower,
                        nftInfo,
                        nftIds,
                        perNftPowerArray
                    );
            }
        } else {
            return
                _getActualNftPowers(
                    IERC721Power(nftInfo.nftAddress).getNftMinPower,
                    nftInfo,
                    nftIds,
                    perNftPowerArray
                );
        }
    }

    function delegations(
        mapping(address => IGovUserKeeper.UserInfo) storage usersInfo,
        IGovUserKeeper.NFTInfo storage nftInfo,
        address user,
        bool perNftPowerArray
    )
        external
        view
        returns (uint256 power, IGovUserKeeper.DelegationInfoView[] memory delegationsInfo)
    {
        IGovUserKeeper.UserInfo storage userInfo = usersInfo[user];

        delegationsInfo = new IGovUserKeeper.DelegationInfoView[](userInfo.delegatees.length());

        for (uint256 i; i < delegationsInfo.length; i++) {
            IGovUserKeeper.DelegationInfoView memory delegation = delegationsInfo[i];
            address delegatee = userInfo.delegatees.at(i);

            IGovUserKeeper.BalanceInfo storage delegatedBalance = userInfo.delegatedBalances[
                delegatee
            ];

            delegation.delegatee = delegatee;
            delegation.delegatedTokens = delegatedBalance.tokens;
            delegation.delegatedNfts = delegatedBalance.nfts.values();

            (delegation.nftPower, delegation.perNftPower) = getTotalNftsPower(
                usersInfo,
                nftInfo,
                delegation.delegatedNfts,
                IGovPool.VoteType.MicropoolVote,
                delegatee,
                perNftPowerArray
            );

            power += delegation.delegatedTokens + delegation.nftPower;
        }
    }

    function getWithdrawableAssets(
        uint256[] calldata lockedProposals,
        uint256[] calldata unlockedNfts,
        IGovUserKeeper.UserInfo storage userInfo,
        mapping(uint256 => uint256) storage nftLockedNums
    ) external view returns (uint256 withdrawableTokens, uint256[] memory withdrawableNfts) {
        IGovUserKeeper.BalanceInfo storage balanceInfo = userInfo.balances[
            IGovPool.VoteType.PersonalVote
        ];

        uint256 newLockedAmount;

        for (uint256 i; i < lockedProposals.length; i++) {
            newLockedAmount = newLockedAmount.max(userInfo.lockedInProposals[lockedProposals[i]]);
        }

        withdrawableTokens = balanceInfo.tokens.max(newLockedAmount) - newLockedAmount;

        Vector.UintVector memory nfts = Vector.newUint();
        uint256 nftsLength = balanceInfo.nfts.length();

        for (uint256 i; i < nftsLength; i++) {
            uint256 nftId = balanceInfo.nfts.at(i);
            uint256 nftLockAmount = nftLockedNums[nftId];

            if (nftLockAmount != 0) {
                for (uint256 j = 0; j < unlockedNfts.length; j++) {
                    if (unlockedNfts[j] == nftId) {
                        nftLockAmount--;
                    }
                }
            }

            if (nftLockAmount == 0) {
                nfts.push(nftId);
            }
        }

        withdrawableNfts = nfts.toArray();
    }

    function _getActualNftPowers(
        function(uint256) external view returns (uint256) powerFunc,
        IGovUserKeeper.NFTInfo storage nftInfo,
        uint256[] memory nftIds,
        bool perNftPowerArray
    ) internal view returns (uint256 nftPower, uint256[] memory perNftPower) {
        if (perNftPowerArray) {
            perNftPower = new uint256[](nftIds.length);
        }

        if (!nftInfo.isSupportPower) {
            uint256 individualPower = nftInfo.individualPower;

            nftPower = nftIds.length * individualPower;

            if (perNftPowerArray) {
                for (uint256 i = 0; i < perNftPower.length; i++) {
                    perNftPower[i] = individualPower;
                }
            }
        } else {
            for (uint256 i = 0; i < nftIds.length; ++i) {
                uint256 currentNftPower = powerFunc(nftIds[i]);

                nftPower += currentNftPower;

                if (perNftPowerArray) {
                    perNftPower[i] = currentNftPower;
                }
            }
        }
    }
}

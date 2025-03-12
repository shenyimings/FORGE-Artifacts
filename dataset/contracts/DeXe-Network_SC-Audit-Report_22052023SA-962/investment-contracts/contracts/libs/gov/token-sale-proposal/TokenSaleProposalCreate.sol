// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";

import "../../../gov/proposals/TokenSaleProposal.sol";

import "../../../core/Globals.sol";

library TokenSaleProposalCreate {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using DecimalsConverter for *;

    function createTier(
        mapping(uint256 => ITokenSaleProposal.Tier) storage tiers,
        uint256 newTierId,
        ITokenSaleProposal.TierInitParams memory _tierInitParams
    ) external {
        _validateTierInitParams(_tierInitParams);

        ITokenSaleProposal.Tier storage tier = tiers[newTierId];

        _setParticipationInfo(tier, _tierInitParams.participationDetails);
        _setRates(tier, _tierInitParams);
        _setVestingParameters(tier, _tierInitParams);

        ITokenSaleProposal.TierInitParams storage tierInitParams = tier.tierInitParams;

        _setBasicParameters(tierInitParams, _tierInitParams);

        IERC20(tierInitParams.saleTokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tierInitParams.totalTokenProvided.from18Safe(_tierInitParams.saleTokenAddress)
        );
    }

    function modifyTier(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.TierInitParams calldata newSettings
    ) external {
        require(
            block.timestamp < tier.tierInitParams.saleStartTime,
            "TSP: token sale already started"
        );
        require(
            newSettings.saleTokenAddress == tier.tierInitParams.saleTokenAddress,
            "TSP: can't change sale token"
        );

        ITokenSaleProposal.TierInitParams storage tierInitParams = tier.tierInitParams;

        _validateTierInitParams(newSettings);

        _clearTierData(tier);

        _setParticipationInfo(tier, newSettings.participationDetails);
        _setRates(tier, newSettings);
        _setVestingParameters(tier, newSettings);

        uint256 oldSupply = tierInitParams.totalTokenProvided;
        uint256 newSupply = newSettings.totalTokenProvided;

        _setBasicParameters(tierInitParams, newSettings);

        if (oldSupply < newSupply) {
            IERC20(newSettings.saleTokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                (newSupply - oldSupply).from18Safe(newSettings.saleTokenAddress)
            );
        } else if (oldSupply > newSupply) {
            IERC20(newSettings.saleTokenAddress).safeTransfer(
                msg.sender,
                (oldSupply - newSupply).from18Safe(newSettings.saleTokenAddress)
            );
        }
    }

    function changeParticipationDetails(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.ParticipationDetails[] calldata newSettings
    ) external {
        require(block.timestamp <= tier.tierInitParams.saleEndTime, "TSP: token sale is over");

        _clearParticipationData(tier);

        _setParticipationInfo(tier, newSettings);

        tier.tierAdditionalInfo.lastModified = _getBlockNumber();
    }

    function getTierViews(
        mapping(uint256 => ITokenSaleProposal.Tier) storage tiers,
        uint256 offset,
        uint256 limit
    ) external view returns (ITokenSaleProposal.TierView[] memory tierViews) {
        uint256 to = (offset + limit).min(TokenSaleProposal(address(this)).latestTierId()).max(
            offset
        );

        tierViews = new ITokenSaleProposal.TierView[](to - offset);

        for (uint256 i = offset; i < to; i++) {
            ITokenSaleProposal.Tier storage tier = tiers[i + 1];

            tierViews[i - offset] = ITokenSaleProposal.TierView({
                tierInitParams: tier.tierInitParams,
                tierInfo: tier.tierInfo,
                tierAdditionalInfo: tier.tierAdditionalInfo
            });
        }
    }

    function getParticipationDetails(
        ITokenSaleProposal.Tier storage tier
    )
        external
        view
        returns (ITokenSaleProposal.ParticipationInfoView memory participationDetails)
    {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;
        ITokenSaleProposal.TierAdditionalInfo storage additionalInfo = tier.tierAdditionalInfo;

        participationDetails.isWhitelisted = participationInfo.isWhitelisted;
        participationDetails.isBABTed = participationInfo.isBABTed;
        participationDetails.requiredDaoVotes = participationInfo.requiredDaoVotes;
        participationDetails.merkleRoot = additionalInfo.merkleRoot;
        participationDetails.merkleUri = additionalInfo.merkleUri;

        uint256 length = participationInfo.requiredTokenLock.length();

        address[] memory addresses = new address[](length);
        uint256[] memory amounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (addresses[i], amounts[i]) = participationInfo.requiredTokenLock.at(i);
        }

        participationDetails.requiredTokenAddresses = addresses;
        participationDetails.requiredTokenAmounts = amounts;

        length = participationInfo.requiredNftLock.length();
        addresses = new address[](length);
        amounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (addresses[i], amounts[i]) = participationInfo.requiredNftLock.at(i);
        }

        participationDetails.requiredNftAddresses = addresses;
        participationDetails.requiredNftAmounts = amounts;
    }

    function _setBasicParameters(
        ITokenSaleProposal.TierInitParams storage tierInitParams,
        ITokenSaleProposal.TierInitParams memory _tierInitParams
    ) private {
        tierInitParams.metadata = _tierInitParams.metadata;
        tierInitParams.totalTokenProvided = _tierInitParams.totalTokenProvided;
        tierInitParams.saleStartTime = _tierInitParams.saleStartTime;
        tierInitParams.saleEndTime = _tierInitParams.saleEndTime;
        tierInitParams.claimLockDuration = _tierInitParams.claimLockDuration;
        tierInitParams.saleTokenAddress = _tierInitParams.saleTokenAddress;
        tierInitParams.purchaseTokenAddresses = _tierInitParams.purchaseTokenAddresses;
        tierInitParams.exchangeRates = _tierInitParams.exchangeRates;
        tierInitParams.minAllocationPerUser = _tierInitParams.minAllocationPerUser;
        tierInitParams.maxAllocationPerUser = _tierInitParams.maxAllocationPerUser;
        tierInitParams.vestingSettings = _tierInitParams.vestingSettings;
    }

    function _setVestingParameters(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.TierInitParams memory _tierInitParams
    ) private {
        uint64 vestingStartTime = _tierInitParams.vestingSettings.vestingDuration == 0
            ? 0
            : _tierInitParams.saleEndTime + _tierInitParams.vestingSettings.cliffPeriod;
        tier.tierInfo.vestingTierInfo = ITokenSaleProposal.VestingTierInfo({
            vestingStartTime: vestingStartTime,
            vestingEndTime: vestingStartTime + _tierInitParams.vestingSettings.vestingDuration
        });
    }

    function _setParticipationInfo(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.ParticipationDetails[] memory participationSettings
    ) private {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;

        for (uint256 i = 0; i < participationSettings.length; i++) {
            ITokenSaleProposal.ParticipationDetails
                memory participationDetails = participationSettings[i];

            if (
                participationDetails.participationType ==
                ITokenSaleProposal.ParticipationType.DAOVotes
            ) {
                require(participationDetails.data.length == 32, "TSP: invalid DAO votes data");

                uint256 requiredDaoVotes = abi.decode(participationDetails.data, (uint256));

                require(requiredDaoVotes > 0, "TSP: zero DAO votes");
                require(
                    participationInfo.requiredDaoVotes == 0,
                    "TSP: multiple DAO votes requirements"
                );

                participationInfo.requiredDaoVotes = requiredDaoVotes;
            } else if (
                participationDetails.participationType ==
                ITokenSaleProposal.ParticipationType.Whitelist
            ) {
                require(participationDetails.data.length == 0, "TSP: invalid whitelist data");
                require(!participationInfo.isWhitelisted, "TSP: multiple whitelist requirements");

                participationInfo.isWhitelisted = true;
            } else if (
                participationDetails.participationType == ITokenSaleProposal.ParticipationType.BABT
            ) {
                require(participationDetails.data.length == 0, "TSP: invalid BABT data");
                require(!participationInfo.isBABTed, "TSP: multiple BABT requirements");

                participationInfo.isBABTed = true;
            } else if (
                participationDetails.participationType ==
                ITokenSaleProposal.ParticipationType.TokenLock
            ) {
                require(participationDetails.data.length == 64, "TSP: invalid token lock data");

                (address token, uint256 amount) = abi.decode(
                    participationDetails.data,
                    (address, uint256)
                );

                require(amount > 0, "TSP: zero token lock amount");
                require(
                    participationInfo.requiredTokenLock.set(token, amount),
                    "TSP: multiple token lock requirements"
                );
            } else if (
                participationDetails.participationType ==
                ITokenSaleProposal.ParticipationType.NftLock
            ) {
                require(participationDetails.data.length == 64, "TSP: invalid nft lock data");

                (address nft, uint256 amount) = abi.decode(
                    participationDetails.data,
                    (address, uint256)
                );

                require(amount > 0, "TSP: zero nft lock amount");
                require(
                    participationInfo.requiredNftLock.set(nft, amount),
                    "TSP: multiple nft lock requirements"
                );
            } else {
                /// @dev ITokenSaleProposal.ParticipationType.MerkleWhitelist
                require(
                    participationDetails.data.length >= 96,
                    "TSP: invalid Merkle Whitelist data"
                );

                ITokenSaleProposal.TierAdditionalInfo storage additionalInfo = tier
                    .tierAdditionalInfo;

                require(
                    additionalInfo.merkleRoot == bytes32(0),
                    "TSP: multiple Merkle whitelist requirements"
                );

                (bytes32 merkleRoot, string memory merkleUri) = abi.decode(
                    participationDetails.data,
                    (bytes32, string)
                );

                require(merkleRoot != bytes32(0), "TSP: zero Merkle Root");

                additionalInfo.merkleRoot = merkleRoot;
                additionalInfo.merkleUri = merkleUri;
            }

            tier.tierInitParams.participationDetails.push(participationDetails);
        }
    }

    function _setRates(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.TierInitParams memory tierInitParams
    ) private {
        for (uint256 i = 0; i < tierInitParams.purchaseTokenAddresses.length; i++) {
            require(tierInitParams.exchangeRates[i] != 0, "TSP: rate cannot be zero");
            require(
                tierInitParams.purchaseTokenAddresses[i] != address(0),
                "TSP: purchase token cannot be zero"
            );
            require(
                tier.rates[tierInitParams.purchaseTokenAddresses[i]] == 0,
                "TSP: purchase tokens are duplicated"
            );

            tier.rates[tierInitParams.purchaseTokenAddresses[i]] = tierInitParams.exchangeRates[i];
        }
    }

    function _clearTierData(ITokenSaleProposal.Tier storage tier) private {
        for (uint256 i = 0; i < tier.tierInitParams.purchaseTokenAddresses.length; i++) {
            tier.rates[tier.tierInitParams.purchaseTokenAddresses[i]] = 0;
        }

        _clearParticipationData(tier);
    }

    function _clearParticipationData(ITokenSaleProposal.Tier storage tier) private {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;
        ITokenSaleProposal.TierAdditionalInfo storage additionalInfo = tier.tierAdditionalInfo;

        participationInfo.isWhitelisted = false;
        participationInfo.isBABTed = false;
        participationInfo.requiredDaoVotes = 0;
        _clearEnumerableMap(participationInfo.requiredTokenLock);
        _clearEnumerableMap(participationInfo.requiredNftLock);
        additionalInfo.merkleRoot = bytes32(0);
        additionalInfo.merkleUri = "";

        ITokenSaleProposal.ParticipationDetails[] storage participationDetails = tier
            .tierInitParams
            .participationDetails;
        assembly {
            sstore(participationDetails.slot, 0)
        }
    }

    function _validateTierInitParams(
        ITokenSaleProposal.TierInitParams memory tierInitParams
    ) private pure {
        require(tierInitParams.saleTokenAddress != address(0), "TSP: sale token cannot be zero");
        require(
            tierInitParams.saleTokenAddress != ETHEREUM_ADDRESS,
            "TSP: cannot sale native currency"
        );
        require(tierInitParams.totalTokenProvided != 0, "TSP: sale token is not provided");
        require(
            tierInitParams.saleStartTime <= tierInitParams.saleEndTime,
            "TSP: saleEndTime is less than saleStartTime"
        );
        require(
            tierInitParams.minAllocationPerUser <= tierInitParams.maxAllocationPerUser,
            "TSP: wrong allocation"
        );
        require(
            _validateVestingSettings(tierInitParams.vestingSettings),
            "TSP: vesting settings validation failed"
        );
        require(
            tierInitParams.claimLockDuration <= tierInitParams.vestingSettings.cliffPeriod,
            "TSP: claimLock > cliff"
        );
        require(
            tierInitParams.purchaseTokenAddresses.length != 0,
            "TSP: purchase tokens are not provided"
        );
        require(
            tierInitParams.purchaseTokenAddresses.length == tierInitParams.exchangeRates.length,
            "TSP: tokens and rates lengths mismatch"
        );
    }

    function _validateVestingSettings(
        ITokenSaleProposal.VestingSettings memory vestingSettings
    ) private pure returns (bool) {
        if (
            vestingSettings.vestingPercentage == 0 &&
            vestingSettings.vestingDuration == 0 &&
            vestingSettings.unlockStep == 0 &&
            vestingSettings.cliffPeriod == 0
        ) {
            return true;
        }

        return
            vestingSettings.vestingDuration != 0 &&
            vestingSettings.vestingPercentage != 0 &&
            vestingSettings.unlockStep != 0 &&
            vestingSettings.vestingPercentage <= PERCENTAGE_100 &&
            vestingSettings.vestingDuration >= vestingSettings.unlockStep;
    }

    function _clearEnumerableMap(EnumerableMap.AddressToUintMap storage map) internal {
        for (uint256 i = map.length(); i > 0; i--) {
            (address key, ) = map.at(i - 1);
            map.remove(key);
        }
    }

    function _getBlockNumber() internal view returns (uint256 block_) {
        return block.number;
    }
}

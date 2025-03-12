// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IConeLens {
    struct Pool {
        address id;
        string symbol;
        bool stable;
        address token0Address;
        address token1Address;
        address gaugeAddress;
        address bribeAddress;
        address[] bribeTokensAddresses;
        address fees;
        uint256 totalSupply;
    }

    struct PoolReserveData {
        address id;
        address token0Address;
        address token1Address;
        uint256 token0Reserve;
        uint256 token1Reserve;
        uint8 token0Decimals;
        uint8 token1Decimals;
    }

    struct PositionVe {
        uint256 tokenId;
        uint256 balanceOf;
        uint256 locked;
    }

    struct PositionBribesByTokenId {
        uint256 tokenId;
        PositionBribe[] bribes;
    }

    struct PositionBribe {
        address bribeTokenAddress;
        uint256 earned;
    }

    struct PositionPool {
        address id;
        uint256 balanceOf;
    }

    function poolsLength() external view returns (uint256);

    function voterAddress() external view returns (address);

    function veAddress() external view returns (address);

    function poolsFactoryAddress() external view returns (address);

    function gaugesFactoryAddress() external view returns (address);

    function minterAddress() external view returns (address);

    function coneAddress() external view returns (address);

    function vePositionsOf(address) external view returns (PositionVe[] memory);

    function bribeAddresByPoolAddress(address) external view returns (address);

    function gaugeAddressByPoolAddress(address) external view returns (address);

    function poolsPositionsOf(address)
    external
    view
    returns (PositionPool[] memory);

    function poolsPositionsOf(
        address,
        uint256,
        uint256
    ) external view returns (PositionPool[] memory);

    function poolInfo(address) external view returns (Pool memory);
}


interface IUnkwnLens {
    struct ProtocolAddresses {
        address unkwnPoolFactoryAddress;
        address ConeLensAddress;
        address UnkwnAddress;
        address vlUnkwnAddress;
        address unConeAddress;
        address voterProxyAddress;
        address coneAddress;
        address voterAddress;
        address poolsFactoryAddress;
        address gaugesFactoryAddress;
        address minterAddress;
        address veAddress;
        address userProxyInterfaceAddress;
        address votingSnapshotAddress;
    }

    struct UserPosition {
        address userProxyAddress;
        uint256 veTotalBalanceOf;
        IConeLens.PositionVe[] vePositions;
        IConeLens.PositionPool[] poolsPositions;
        IUserProxy.PositionStakingPool[] stakingPools;
        uint256 unConeanceOf;
        uint256 unkwnBalanceOf;
        uint256 coneBalanceOf;
        uint256 vlUnkwnBalanceOf;
    }

    struct TokenMetadata {
        address id;
        string name;
        string symbol;
        uint8 decimals;
        uint256 priceUsdc;
    }

    struct UnkwnPoolData {
        address id;
        address stakingAddress;
        uint256 stakedTotalSupply;
        uint256 totalSupply;
        IConeLens.Pool poolData;
    }

    struct Pool {
        address id;
        string symbol;
        bool stable;
        address token0Address;
        address token1Address;
        address gaugeAddress;
        address bribeAddress;
        address[] bribeTokensAddresses;
        address fees;
    }

    struct RewardTokenData {
        address id;
        uint256 rewardRate;
        uint256 periodFinish;
    }

    /* ========== PUBLIC VARS ========== */

    function unkwnPoolFactoryAddress() external view returns (address);

    function rewardsDistributorAddress() external view returns (address);

    function userProxyFactoryAddress() external view returns (address);

    function coneLensAddress() external view returns (address);

    function unkwnAddress() external view returns (address);

    function vlUnkwnAddress() external view returns (address);

    function unConeAddress() external view returns (address);

    function voterProxyAddress() external view returns (address);

    function veAddress() external view returns (address);

    function coneAddress() external view returns (address);

    function unConeRewardsPoolAddress() external view returns (address);

    function partnersRewardsPoolAddress() external view returns (address);

    function treasuryAddress() external view returns (address);

    function cvlUnkwnAddress() external view returns (address);

    function unkwnV1RewardsAddress() external view returns (address);

    function unkwnV1RedeemAddress() external view returns (address);

    function unkwnV1Address() external view returns (address);

    function tokensAllowlistAddress() external view returns (address);

    /* ========== PUBLIC VIEW FUNCTIONS ========== */

    function voterAddress() external view returns (address);

    function poolsFactoryAddress() external view returns (address);

    function gaugesFactoryAddress() external view returns (address);

    function minterAddress() external view returns (address);

    function protocolAddresses()
    external
    view
    returns (ProtocolAddresses memory);

    function positionsOf(address accountAddress)
    external
    view
    returns (UserPosition memory);

    function rewardTokensPositionsOf(address, address)
    external
    view
    returns (IUserProxy.RewardToken[] memory);

    function veTotalBalanceOf(IConeLens.PositionVe[] memory positions)
    external
    pure
    returns (uint256);

    function unkwnPoolsLength() external view returns (uint256);

    function userProxiesLength() external view returns (uint256);

    function userProxyByAccount(address accountAddress)
    external
    view
    returns (address);

    function userProxyByIndex(uint256 index) external view returns (address);

    function gaugeByConePool(address) external view returns (address);

    function conePoolByUnkwnPool(address unkwnPoolAddress)
    external
    view
    returns (address);

    function unkwnPoolByConePool(address conePoolAddress)
    external
    view
    returns (address);

    function stakingRewardsByConePool(address conePoolAddress)
    external
    view
    returns (address);

    function stakingRewardsByUnkwnPool(address conePoolAddress)
    external
    view
    returns (address);

    function isUnkwnPool(address unkwnPoolAddress) external view returns (bool);

    function unkwnPoolsAddresses() external view returns (address[] memory);

    function unkwnPoolData(address unkwnPoolAddress)
    external
    view
    returns (UnkwnPoolData memory);

    function unkwnPoolsData(address[] memory _unkwnPoolsAddresses)
    external
    view
    returns (UnkwnPoolData[] memory);

    function unkwnPoolsData() external view returns (UnkwnPoolData[] memory);

    function isPartner(address userProxyAddress) external view returns (bool);

    function stakedUnConeBalanceOf(address accountAddress)
    external
    view
    returns (uint256 stakedBalance);

    function coneInflationSinceInception() external view returns (uint256);
}


interface IUserProxy {
    struct PositionStakingPool {
        address stakingPoolAddress;
        address unkwnPoolAddress;
        address conePoolAddress;
        uint256 balanceOf;
        RewardToken[] rewardTokens;
    }

    function initialize(
        address,
        address,
        address,
        address[] memory
    ) external;

    struct RewardToken {
        address rewardTokenAddress;
        uint256 rewardRate;
        uint256 rewardPerToken;
        uint256 getRewardForDuration;
        uint256 earned;
    }

    struct Vote {
        address poolAddress;
        int256 weight;
    }

    function convertNftToUnCone(uint256) external;

    function convertConeToUnCone(uint256) external;

    function depositLpAndStake(address, uint256) external;

    function depositLp(address, uint256) external;

    function stakingAddresses() external view returns (address[] memory);

    function initialize(address, address) external;

    function stakingPoolsLength() external view returns (uint256);

    function unstakeLpAndWithdraw(
        address,
        uint256,
        bool
    ) external;

    function unstakeLpAndWithdraw(address, uint256) external;

    function unstakeLpWithdrawAndClaim(address) external;

    function unstakeLpWithdrawAndClaim(address, uint256) external;

    function withdrawLp(address, uint256) external;

    function stakeUnkwnLp(address, uint256) external;

    function unstakeUnkwnLp(address, uint256) external;

    function ownerAddress() external view returns (address);

    function stakingPoolsPositions()
    external
    view
    returns (PositionStakingPool[] memory);

    function stakeUnCone(uint256) external;

    function unstakeUnCone(uint256) external;

    function unstakeUnCone(address, uint256) external;

    function convertConeToUnConeAndStake(uint256) external;

    function convertNftToUnConeAndStake(uint256) external;

    function claimUnConeStakingRewards() external;

    function claimPartnerStakingRewards() external;

    function claimStakingRewards(address) external;

    function claimStakingRewards(address[] memory) external;

    function claimStakingRewards() external;

    function claimVlUnkwnRewards() external;

    function depositUnkwn(uint256, uint256) external;

    function withdrawUnkwn(bool, uint256) external;

    function voteLockUnkwn(uint256, uint256) external;

    function withdrawVoteLockedUnkwn(uint256, bool) external;

    function relockVoteLockedUnkwn(uint256) external;

    function removeVote(address) external;

    function registerStake(address) external;

    function registerUnstake(address) external;

    function resetVotes() external;

    function setVoteDelegate(address) external;

    function clearVoteDelegate() external;

    function vote(address, int256) external;

    function vote(Vote[] memory) external;

    function votesByAccount(address) external view returns (Vote[] memory);

    function migrateUnConeToPartner() external;

    function stakeUnConeInUnkwnV1(uint256) external;

    function unstakeUnConeInUnkwnV1(uint256) external;

    function redeemUnkwnV1(uint256) external;

    function redeemAndStakeUnkwnV1(uint256) external;

    function whitelist(address) external;

    function implementationsAddresses()
    external
    view
    returns (address[] memory);
}


library UnknownLibrary {

    function getUserLpBalance(
        IUnkwnLens unkwnLens,
        address conePair,
        address userAddress
    ) internal view returns (uint256 lpBalance) {
        address userProxyThis = unkwnLens.userProxyByAccount(userAddress);
        address stakingAddress = unkwnLens.stakingRewardsByConePool(conePair);
        lpBalance = IERC20(stakingAddress).balanceOf(userProxyThis);
    }
}

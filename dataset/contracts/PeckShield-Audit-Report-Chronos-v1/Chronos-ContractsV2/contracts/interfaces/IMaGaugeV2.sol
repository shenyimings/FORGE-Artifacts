// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/IMaGaugeStruct.sol";


interface IMaGaugeV2 {
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event ClaimFees(address indexed from, uint256 claimed0, uint256 claimed1);
    event Deposit(address indexed user, uint256 amount);
    event DistributionSet(address distribution);
    event EmergencyModeSet(bool isEmergency);
    event Harvest(address indexed user, uint256 reward);
    event Increase(
        address indexed user,
        uint256 id,
        uint256 oldAmount,
        uint256 newAmount
    );
    event Initialized(uint8 version);
    event InternalBribeSet(address bribe);
    event Merge(address indexed user, uint256 fromId, uint256 toId);
    event RewardAdded(uint256 reward);
    event Split(address indexed user, uint256 id);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Withdraw(address indexed user, uint256 amount);

    function DISTRIBUTION() external view returns (address);

    function DURATION() external view returns (uint256);

    function LP_LAST_EPOCH_ID() external view returns (uint256);

    function TOKEN() external view returns (address);

    function _VE() external view returns (address);

    function _epochs(uint256) external view returns (uint256);

    function _lastTotalWeightUpdateTime() external view returns (uint256);
    
    function allInfo(uint _tokenId) external view returns(IMaGaugeStruct.MaNftInfo memory _maNftInfo);

    function _lpTotalSupplyPostLimit() external view returns (uint256);

    function _lpTotalSupplyPreLimit() external view returns (uint256);

    function _periodFinish() external view returns (uint256);

    function _positionEntries(uint256) external view returns (uint256);

    function _weightIncrement() external view returns (uint256);

    function activateEmergencyMode() external;

    function approve(address to, uint256 tokenId) external;

    function balanceOf(address owner) external view returns (uint256);

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function deposit(uint256 amount) external returns (uint256 _maNFTId);

    function depositAll() external returns (uint256 _maNFTId);

    function depositTo(uint256 amount, address _to)
        external
        returns (uint256 _maNFTId);

    function update() external returns(bool);

    function depositFromMigration(
        uint amount,
        address _to,
        uint entry
    ) external returns (uint _maNFTId);

    function earned(uint256 _maNFTId) external view returns (uint256);

    function earned(address _user) external view returns (uint256);

    function emergency() external view returns (bool);

    function emergencyWithdraw(uint256 _maNFTId) external;

    function emergencyWithdrawAll() external;

    function external_bribe() external view returns (address);

    function fees0() external view returns (uint256);

    function fees1() external view returns (uint256);

    function gaugeFactory() external view returns (address);

    function getAllReward() external;

    function getApproved(uint256 tokenId) external view returns (address);

    function getReward(uint256 _maNFTId) external;

    function getRewardFromVoter(uint256 _maNFTId) external;
    function getRewardFromVoter(address _user) external;

    function idRewardPerTokenPaid(uint256) external view returns (uint256);

    function increase(uint256 _maNFTId, uint256 amount) external;

    function _maturityMultiplier(uint256 _maNFTId) external view returns(uint _multiplier);

    function initialize(
        address _rewardToken,
        address _ve,
        address _token,
        address _distribution,
        address _internal_bribe,
        address _external_bribe,
        bool _isForPair
    ) external;

    function internal_bribe() external view returns (address);

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function isApprovedOrOwner(address user, uint256 _maNFTId)
        external
        view
        returns (bool);

    function isForPair() external view returns (bool);

    function lastTimeRewardApplicable() external view returns (uint256);

    function lastUpdateTime() external view returns (uint256);

    function lpBalanceOfUser(address account)
        external
        view
        returns (uint256 amount);

    function weightOfUser(address account)
        external
        view
        returns (uint256 amount);

    function lpBalanceOfmaNFT(uint256 _maNFTId) external view returns (uint256);

    function lpTotalSupply() external view returns (uint256);

    function maNFTWeight(uint256 _maNFTId) external view returns (uint256);

    function merge(uint256 _maNFTIdFrom, uint256 _maNFTIdTo) external;

    function name() external view returns (string memory);

    function notifyRewardAmount(address token, uint256 reward) external;

    function ownerOf(uint256 tokenId) external view returns (address);

    function periodFinish() external view returns (uint256);

    function rewardForDuration() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function rewardPerTokenStored() external view returns (uint256);

    function rewardRate() external view returns (uint256);

    function rewardToken() external view returns (address);

    function rewards(uint256) external view returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function setDistribution(address _distribution) external;

    function setInternalBribe(address _int) external;

    function split(uint256 _maNFTId, uint256[] memory weights) external;

    function stopEmergencyMode() external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function sync() external;

    function tokenByIndex(uint256 index) external view returns (uint256);

    function tokenId() external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);

    function tokenURI(uint256 _maNFTId) external view returns (string memory);

    function tokensOfOwner(address _owner)
        external
        view
        returns (uint256[] memory);

    function totalSupply() external view returns (uint256);

    function totalWeight() external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function version() external view returns (string memory);

    function withdraw(uint256 _maNFTId) external;

    function withdrawAll() external;
}

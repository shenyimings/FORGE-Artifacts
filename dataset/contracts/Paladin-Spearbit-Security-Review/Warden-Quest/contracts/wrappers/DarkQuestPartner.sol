//██████╗  █████╗ ██╗      █████╗ ██████╗ ██╗███╗   ██╗
//██╔══██╗██╔══██╗██║     ██╔══██╗██╔══██╗██║████╗  ██║
//██████╔╝███████║██║     ███████║██║  ██║██║██╔██╗ ██║
//██╔═══╝ ██╔══██║██║     ██╔══██║██║  ██║██║██║╚██╗██║
//██║     ██║  ██║███████╗██║  ██║██████╔╝██║██║ ╚████║
//╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═══╝
 

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../oz/interfaces/IERC20.sol";
import "../oz/libraries/SafeERC20.sol";
import "../utils/Owner.sol";
import "../oz/utils/ReentrancyGuard.sol";
import "../utils/Errors.sol";
import "../DarkQuestBoard.sol";
import "../QuestTreasureChest.sol";
import "../interfaces/ISimpleDistributor.sol";

/** @title Warden Dark Quest Creator contract */
/// @author Paladin
/*
    Contract allowing to create (and manage) Quests on DarkQuestBoard
    while sharing fees if the partner
    Alows to set a blacklist of claimers to be applied to all Quests
    created by that contract
*/

contract DarkQuestPartner is Owner, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /** @notice 1e18 scale */
    uint256 private constant UNIT = 1e18;
    /** @notice Max BPS value (100%) */
    uint256 private constant MAX_BPS = 10000;


    DarkQuestBoard public immutable board;

    QuestTreasureChest public immutable chest;

    address public immutable partner;

    address public immutable feesReceiver;

    uint256 public partnerShare; //BPS

    uint256[] public partnerQuests;

    mapping(uint256 => address) public creators;

    mapping(uint256 => address) public rewardTokens;

    bool public killed;


    event NewPartnerQuest(uint256 indexed questID, address indexed creator);

    event AddVoterBlacklist(address account);

    event RemoveVoterBlacklist(address account);

    event PartnerShareUpdate(uint256 newShare);

    event Killed();


    modifier onlyPartner(){
        if(msg.sender != partner) revert Errors.CallerNotAllowed();
        _;
    }

    modifier onlyAllowed(){
        if(msg.sender != partner && msg.sender != owner()) revert Errors.CallerNotAllowed();
        _;
    }

    modifier notKilled(){
        if(killed) revert Errors.Killed();
        _;
    }

    constructor(
        address _board,
        address _chest,
        address _partner,
        address _receiver,
        uint256 _share
    ){
        if(_board == address(0)) revert Errors.ZeroAddress();
        if(_chest == address(0)) revert Errors.ZeroAddress();
        if(_partner == address(0)) revert Errors.ZeroAddress();
        if(_receiver == address(0)) revert Errors.ZeroAddress();
        if(_share == 0) revert Errors.NullAmount();
        if(_share > 5000) revert Errors.InvalidParameter();

        board = DarkQuestBoard(_board);
        chest = QuestTreasureChest(_chest);

        partner = _partner;

        feesReceiver = _receiver;

        partnerShare = _share;
    }

    function getPartnerQuests() external view returns(uint256[] memory){
        return partnerQuests;
    }

    function createQuest(
        address gauge,
        address rewardToken,
        uint48 duration,
        uint256 objective,
        uint256 rewardPerVote,
        uint256 totalRewardAmount,
        uint256 feeAmount,
        address[] calldata blacklist
    ) external notKilled nonReentrant returns(uint256) {
        if(gauge == address(0) || rewardToken == address(0)) revert Errors.ZeroAddress();
        if(duration == 0) revert Errors.IncorrectDuration();
        if(rewardPerVote == 0 || totalRewardAmount == 0 || feeAmount == 0) revert Errors.NullAmount();
        // Check for the objective is handled by the QuestBoard contract

        // Verifiy the given amounts of reward token are correct
        uint256 rewardPerPeriod = (objective * rewardPerVote) / UNIT;

        if((rewardPerPeriod * duration) != totalRewardAmount) revert Errors.IncorrectTotalRewardAmount();

        require(_pullTokens(rewardToken, msg.sender, totalRewardAmount + feeAmount));

        uint256 newQuestId = board.createQuest(gauge, rewardToken, duration, objective, rewardPerVote, totalRewardAmount, feeAmount, blacklist);

        creators[newQuestId] = msg.sender;
        rewardTokens[newQuestId] = rewardToken;

        require(_sendPartnerShare(rewardToken, feeAmount));

        emit NewPartnerQuest(newQuestId, msg.sender);

        return newQuestId;

    }

    function withdrawUnusedRewards(uint256 questID, address recipient) external notKilled nonReentrant {
        if(msg.sender != creators[questID]) revert Errors.CallerNotAllowed();
        
        board.withdrawUnusedRewards(questID, recipient);
    }

    function increaseQuestDuration(
        uint256 questID,
        uint48 addedDuration,
        uint256 addedRewardAmount,
        uint256 feeAmount
    ) external notKilled nonReentrant {
        if(msg.sender != creators[questID]) revert Errors.CallerNotAllowed();

        address rewardToken = rewardTokens[questID];
        if(rewardToken == address(0)) revert Errors.ZeroAddress();

        if(addedRewardAmount == 0 || feeAmount == 0) revert Errors.NullAmount();
        if(addedDuration == 0) revert Errors.IncorrectAddDuration();

        require(_pullTokens(rewardToken, msg.sender, addedRewardAmount + feeAmount));

        board.increaseQuestDuration(questID, addedDuration, addedRewardAmount, feeAmount);

        require(_sendPartnerShare(rewardToken, feeAmount));

    }

    function increaseQuestReward(
        uint256 questID,
        uint256 newRewardPerVote,
        uint256 addedRewardAmount,
        uint256 feeAmount
    ) external notKilled nonReentrant {
        if(msg.sender != creators[questID]) revert Errors.CallerNotAllowed();

        address rewardToken = rewardTokens[questID];
        if(rewardToken == address(0)) revert Errors.ZeroAddress();

        if(newRewardPerVote == 0 || addedRewardAmount == 0 || feeAmount == 0) revert Errors.NullAmount();

        require(_pullTokens(rewardToken, msg.sender, addedRewardAmount + feeAmount));

        board.increaseQuestReward(questID, newRewardPerVote, addedRewardAmount, feeAmount);

        require(_sendPartnerShare(rewardToken, feeAmount));

    }

    function increaseQuestObjective(
        uint256 questID,
        uint256 newObjective,
        uint256 addedRewardAmount,
        uint256 feeAmount
    ) external notKilled nonReentrant {
        if(msg.sender != creators[questID]) revert Errors.CallerNotAllowed();

        address rewardToken = rewardTokens[questID];
        if(rewardToken == address(0)) revert Errors.ZeroAddress();

        if(newObjective == 0 || addedRewardAmount == 0 || feeAmount == 0) revert Errors.NullAmount();

        require(_pullTokens(rewardToken, msg.sender, addedRewardAmount + feeAmount));

        board.increaseQuestObjective(questID, newObjective, addedRewardAmount, feeAmount);

        require(_sendPartnerShare(rewardToken, feeAmount));
    }

    function retrieveRewards(
        address distributor,
        uint256 questID,
        uint256 period,
        uint256 index,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external notKilled nonReentrant {
        if(msg.sender != creators[questID]) revert Errors.CallerNotAllowed();
        if(distributor == address(0)) revert Errors.ZeroAddress();

        address rewardToken = rewardTokens[questID];
        if(rewardToken == address(0)) revert Errors.ZeroAddress();

        ISimpleDistributor(distributor).claim(questID, period, index, address(this), amount, merkleProof);

        IERC20(rewardToken).safeTransfer(msg.sender, amount);

    }

    function emergencyWithdraw(uint256 questID, address recipient) external notKilled nonReentrant {
        if(msg.sender != creators[questID]) revert Errors.CallerNotAllowed();
        
        board.emergencyWithdraw(questID, recipient);
    }

    function _pullTokens(address token, address source, uint256 amount) internal returns(bool){
        IERC20(token).safeTransferFrom(source, address(this), amount);

        IERC20(token).safeIncreaseAllowance(address(board), amount);

        return true;
    }

    function _sendPartnerShare(address token, uint256 feesAmount) internal returns(bool){
        uint256 partnerAmount = (feesAmount * partnerShare) / MAX_BPS;

        chest.transferERC20(token, feesReceiver, partnerAmount);

        return true;
    }

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable onlyAllowed notKilled returns (bool, bytes memory) {
        // Since this contract is approved as a manager for the QuestTreasuryChest contract
        // we do not want this method to be allowed to call the contract.
        // And not allowed to call the Quest Board either, since we already have methods for that
        if(to == address(board) || to == address(chest)) revert Errors.ForbiddenCall();

        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, _getRevertMsg(result));

        return (success, result);
    }

    function _getRevertMsg(bytes memory _returnData)
        internal
        pure
        returns (string memory)
    {
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            _returnData := add(_returnData, 0x04)
        }

        return abi.decode(_returnData, (string));
    }


    // Partner methods
    function recoverERC20(address token) external onlyAllowed returns(bool) {
        uint256 amount = IERC20(token).balanceOf(address(this));
        if(amount == 0) revert Errors.NullAmount();
        IERC20(token).safeTransfer(owner(), amount);

        return true;
    }


    // Admin methods

    function updatePartnerShare(uint256 newShare) external onlyOwner {
        if(newShare > 5000) revert Errors.InvalidParameter();
        partnerShare = newShare;

        emit PartnerShareUpdate(newShare);
    }

    function kill() external onlyOwner {
        if(killed) revert Errors.AlreadyKilled();
        killed = true;

        emit Killed();
    }

}
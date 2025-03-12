// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IBEP20.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/ILuckyPower.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/IBetMining.sol";
import "../interfaces/IReferral.sol";
import "../interfaces/ILottery.sol";
import "../libraries/SafeBEP20.sol";

contract LuckyPower is ILuckyPower, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _updaters;
    EnumerableSet.AddressSet private _teamAddrs;

    // Power quantity info of each user.
    struct UserInfo {
        uint256 quantity;
        uint256 lpQuantity;
        uint256 bankerQuantity;
        uint256 playerQuantity;
        uint256 referrerQuantity;
        uint256 lotteryQuantity;
    }

    // Reward info of each user for each bonus
    struct UserRewardInfo {
        uint256 pendingReward;
        uint256 rewardDebt;
        uint256 accRewardAmount;
    }

    // Info of each pool.
    struct BonusInfo {
        address token; // Address of bonus token contract.
        uint256 lastRewardBlock; // Last block number that reward tokens distribution occurs.
        uint256 accRewardPerShare; // Accumulated reward tokens per share, times 1e12.
        uint256 allocRewardAmount;
        uint256 accRewardAmount;
    }

    uint256 public quantity;

    // Lc token
    IBEP20 public lcToken;
    // Info of each bonus.
    BonusInfo[] public bonusInfo;
    // token address to its corresponding id
    mapping(address => uint256) public tokenIdMap;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;
    // user pending bonus 
    mapping(uint256 => mapping(address => UserRewardInfo)) public userRewardInfo;

    uint256 public withdrawLpBonus;
    uint256 public withdrawBankerBonus;
    uint256 public withdrawPlayerBonus;
    uint256 public withdrawReferrerBonus;
    uint256 public withdrawLotteryBonus;

    IOracle public oracle;
    IMasterChef public masterChef;
    IBetMining public betMining;
    IReferral public referral;
    ILottery public lottery;

    function isUpdater(address account) public view returns (bool) {
        return EnumerableSet.contains(_updaters, account);
    }

    // modifier for updater
    modifier onlyUpdater() {
        require(isUpdater(msg.sender), "caller is not a updater");
        _;
    }

    function addUpdater(address _addUpdater) public onlyOwner returns (bool) {
        require(_addUpdater != address(0), "Token: _addUpdater is the zero address");
        return EnumerableSet.add(_updaters, _addUpdater);
    }

    function delUpdater(address _delUpdater) public onlyOwner returns (bool) {
        require(_delUpdater != address(0), "Token: _delUpdater is the zero address");
        return EnumerableSet.remove(_updaters, _delUpdater);
    } 

    event UpdatePower(address indexed user, uint256 quantity, uint256 lpQuantity, uint256 bankerQuantity, uint256 playerQuantity, uint256 referrerQuantity, uint256 lotteryQuantity);
    event Withdraw(address indexed user);
    event EmergencyWithdraw(address indexed user);
    event SetMasterChef(address indexed _masterChefAddr);
    event SetBetMining(address indexed _betMiningAddr);
    event SetReferral(address indexed _referralAddr);
    event SetLottery(address indexed _lotteryAddr);

    constructor(
        address _lcTokenAddr,
        address _oracleAddr,
        address _masterChefAddr,
        address _betMiningAddr,
        address _referralAddr,
        address _lotteryAddr
    ) public {
        lcToken = IBEP20(_lcTokenAddr);
        oracle = IOracle(_oracleAddr);
        masterChef = IMasterChef(_masterChefAddr);
        betMining = IBetMining(_betMiningAddr);
        referral = IReferral(_referralAddr);
        lottery = ILottery(_lotteryAddr);
    }

    // Add a new token to the pool. Can only be called by the owner.
    function addBonus(address _token) public onlyOwner {
        require(_token != address(0), "BetMining: _token is the zero address");

        require(!EnumerableSet.contains(_tokens, _token), "BetMining: _token is already added to the pool");
        // return EnumerableSet.add(_tokens, _token);
        EnumerableSet.add(_tokens, _token);

        bonusInfo.push(
            BonusInfo({
                token: _token,
                lastRewardBlock: block.number,
                accRewardPerShare: 0,
                allocRewardAmount: 0,
                accRewardAmount: 0
            })
        );
        tokenIdMap[_token] = getBonusLength() - 1;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updateBonus(address bonusToken, uint256 amount) public override onlyUpdater {
        uint256 bonusId = tokenIdMap[bonusToken];
        require(bonusId < bonusInfo.length, "BonusId must be less than bonusInfo length");

        uint256 length = EnumerableSet.length(_teamAddrs);
        for(uint256 i = 0; i < length; i ++){
            address teamAddr = EnumerableSet.at(_teamAddrs, i);
            updatePower(teamAddr);
        }

        BonusInfo storage bonus = bonusInfo[bonusId];
        if(bonus.token != bonusToken || quantity <= 0){
            return;
        }

        bonus.accRewardPerShare = bonus.accRewardPerShare.add(amount.mul(1e12).div(quantity));
        bonus.allocRewardAmount = bonus.allocRewardAmount.add(amount);
        bonus.accRewardAmount = bonus.accRewardAmount.add(amount);
        bonus.lastRewardBlock = block.number;
    }

    function getPower(address account) public override view returns (uint256) {
        return userInfo[account].quantity;
    }

        // add pending rewardss.
    function addPendingRewards(address account) internal{
        UserInfo storage user = userInfo[account];
        if (user.quantity > 0) {
            for(uint256 i = 0; i < bonusInfo.length; i ++){
                BonusInfo storage bonus = bonusInfo[i];
                UserRewardInfo storage userReward = userRewardInfo[i][account];
                uint256 pendingReward = user.quantity.mul(bonus.accRewardPerShare).div(1e12).sub(userReward.rewardDebt);
                if (pendingReward > 0) {
                    userReward.pendingReward = userReward.pendingReward.add(pendingReward);
                    userReward.accRewardAmount = userReward.accRewardAmount.add(pendingReward);
                }
            }
        }
    }

    function pendingPower(address account) public override view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tmpQuantity, uint256 tmpLpQuantity, uint256 tmpBankerQuantity) = masterChef.getLuckyPower(account);

        uint256 tmpPlayerQuantity = 0;
        uint256 tmpReferrerQuantity = 0;
        uint256 tmpLotteryQuantity = 0;
        if(address(betMining) != address(0)){
            tmpPlayerQuantity = betMining.getLuckyPower(account);
            tmpQuantity = tmpQuantity.add(tmpPlayerQuantity);
        }
        
        if(address(referral) != address(0)){
            tmpReferrerQuantity = referral.getLuckyPower(account);
            tmpQuantity = tmpQuantity.add(tmpReferrerQuantity);
        }

        if(address(lottery) != address(0)){
            tmpLotteryQuantity = lottery.getLuckyPower(account);
            tmpQuantity = tmpQuantity.add(tmpLotteryQuantity);
        }

        return (tmpQuantity, tmpLpQuantity, tmpBankerQuantity, tmpPlayerQuantity, tmpReferrerQuantity, tmpLotteryQuantity);
    }

    function updatePower(address account) public override{
        require(account != address(0), "LuckyPower: account is zero address");

        for(uint256 i = 0; i < bonusInfo.length; i ++){
            BonusInfo storage bonus = bonusInfo[i];
            if(bonus.token != address(lcToken)){
                oracle.update(bonus.token, address(lcToken));
            }
        }

        addPendingRewards(account);

        (uint256 tmpQuantity, uint256 tmpLpQuantity, uint256 tmpBankerQuantity, uint256 tmpPlayerQuantity, uint256 tmpReferrerQuantity, uint256 tmpLotteryQuantity) = pendingPower(account);
        if(userInfo[account].quantity != tmpQuantity){
            quantity = quantity.sub(userInfo[account].quantity).add(tmpQuantity);
        }

        userInfo[account] = UserInfo({
            quantity: tmpQuantity,
            lpQuantity: tmpLpQuantity,
            bankerQuantity: tmpBankerQuantity,
            playerQuantity: tmpPlayerQuantity,
            referrerQuantity: tmpReferrerQuantity,
            lotteryQuantity: tmpLotteryQuantity
        });

        for(uint256 i = 0; i < bonusInfo.length; i ++){
            BonusInfo storage bonus = bonusInfo[i];
            UserRewardInfo storage userReward = userRewardInfo[i][account];
            userReward.rewardDebt = tmpQuantity.mul(bonus.accRewardPerShare).div(1e12);
        }

        emit UpdatePower(account, tmpQuantity, tmpLpQuantity, tmpBankerQuantity, tmpPlayerQuantity, tmpReferrerQuantity, tmpLotteryQuantity);
    }

    function pendingRewards(address account) public view returns (address[] memory, uint256[] memory, uint256) {
        uint256 length = bonusInfo.length;
        address[] memory tokens = new address[](length);
        uint256[] memory amounts = new uint256[](length);
        UserInfo storage user = userInfo[account];
        for(uint256 i = 0; i < length; i ++){
            BonusInfo storage bonus = bonusInfo[i];
            UserRewardInfo storage userReward = userRewardInfo[i][account];
            uint256 pendingReward = user.quantity.mul(bonus.accRewardPerShare).div(1e12).sub(userReward.rewardDebt);
            tokens[i] = bonus.token;
            amounts[i] = userReward.pendingReward.add(pendingReward);
        }
        return (tokens, amounts, length);
    }

    function pendingRewardsBUSD(address account) public view returns (uint256) {
        UserInfo storage user = userInfo[account];
        uint256 totalBonus = 0;
        for(uint256 i = 0; i < bonusInfo.length; i ++){
            BonusInfo storage bonus = bonusInfo[i];
            UserRewardInfo storage userReward = userRewardInfo[i][account];
            uint256 pendingReward = user.quantity.mul(bonus.accRewardPerShare).div(1e12).sub(userReward.rewardDebt);
            if(pendingReward > 0 || userReward.pendingReward > 0){
                totalBonus = totalBonus.add(oracle.getQuantityBUSD(bonus.token, userReward.pendingReward.add(pendingReward)));
            }
        }
        return totalBonus;
    }

    function withdraw() public override nonReentrant {
        address account = msg.sender;
        updatePower(account);

        uint256 tmpReward = 0;
        uint256 totalRewards = 0;
        for(uint256 i = 0; i < bonusInfo.length; i ++){
            BonusInfo storage bonus = bonusInfo[i];
            UserRewardInfo storage userReward = userRewardInfo[i][account];
            tmpReward = userReward.pendingReward;
            userReward.pendingReward = 0;
            if(tmpReward > 0){
                IBEP20(bonus.token).safeTransfer(account, tmpReward);
                totalRewards = totalRewards.add(oracle.getQuantityBUSD(bonus.token, tmpReward));
            }
        }

        UserInfo storage user = userInfo[account];
        withdrawLpBonus = withdrawLpBonus.add(totalRewards.mul(user.lpQuantity).div(quantity));
        withdrawBankerBonus = withdrawBankerBonus.add(totalRewards.mul(user.bankerQuantity).div(quantity));
        withdrawPlayerBonus = withdrawPlayerBonus.add(totalRewards.mul(user.playerQuantity).div(quantity));
        withdrawReferrerBonus = withdrawReferrerBonus.add(totalRewards.mul(user.referrerQuantity).div(quantity));
        withdrawLotteryBonus = withdrawLotteryBonus.add(totalRewards.mul(user.lotteryQuantity).div(quantity));

        emit Withdraw(msg.sender);
    }

    
    function emergencyWithdraw() public nonReentrant {
        address account = msg.sender;
        updatePower(account);

        uint256 tmpReward = 0;
        for(uint256 i = 0; i < bonusInfo.length; i ++){
            BonusInfo storage bonus = bonusInfo[i];
            UserRewardInfo storage userReward = userRewardInfo[i][account];
            tmpReward = userReward.pendingReward;
            userReward.pendingReward = 0;
            if(tmpReward > 0){
                IBEP20(bonus.token).safeTransfer(account, tmpReward);
            }
        }

        emit EmergencyWithdraw(msg.sender);
    }

    function setOracle(address _oracleAddr) public onlyOwner {
        require(_oracleAddr != address(0), "BetMining: new oracle is the zero address");
        oracle = IOracle(_oracleAddr);
    }

    function setMasterChef(address _masterChefAddr) public onlyOwner {
        require(_masterChefAddr != address(0), "Zero");
        masterChef = IMasterChef(_masterChefAddr);
        emit SetMasterChef(_masterChefAddr);
    }

    function setBetMining(address _betMiningAddr) public onlyOwner {
        require(_betMiningAddr != address(0), "Zero");
        betMining = IBetMining(_betMiningAddr);
        emit SetBetMining(_betMiningAddr);
    }

    function setReferral(address _referralAddr) public onlyOwner {
        require(_referralAddr != address(0), "Zero");
        referral = IReferral(_referralAddr);
        emit SetReferral(_referralAddr);
    }

    function setLottery(address _lotteryAddr) public onlyOwner {
        require(_lotteryAddr != address(0), "Zero");
        lottery = ILottery(_lotteryAddr);
        emit SetLottery(_lotteryAddr);
    }

    function getLpTokensLength() public view returns (uint256) {
        return EnumerableSet.length(_tokens);
    }

    function getLpToken(uint256 _index) public view returns (address) {
        return EnumerableSet.at(_tokens, _index);
    }

    function addTeamAddr(address _teamAddr) public onlyOwner returns (bool) {
        require(_teamAddr != address(0), "Addr: _teamAddr is the zero address");
        return EnumerableSet.add(_teamAddrs, _teamAddr);
    }

    function delTeamAddr(address _teamAddr) public onlyOwner returns (bool) {
        require(_teamAddr != address(0), "Addr: _teamAddr is the zero address");
        return EnumerableSet.remove(_teamAddrs, _teamAddr);
    }

    function isTeamAddr(address _teamAddr) public view returns (bool) {
        return EnumerableSet.contains(_teamAddrs, _teamAddr);
    }

    function isBonusToken(address _token) public view returns (bool) {
        return EnumerableSet.contains(_tokens, _token);
    }

    function getUpdaterLength() public view returns (uint256) {
        return EnumerableSet.length(_updaters);
    }

    function getUpdater(uint256 _index) public view returns (address) {
        return EnumerableSet.at(_updaters, _index);
    }

    function getBonusLength() public view returns (uint256) {
        return bonusInfo.length;
    }

}

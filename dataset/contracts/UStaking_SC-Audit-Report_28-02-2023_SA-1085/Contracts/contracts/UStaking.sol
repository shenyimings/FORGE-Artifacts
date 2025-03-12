// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IBEP20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

 /// @title A staking contract
/// @author Ustaking team
/// @dev the contract for stacking the Ustaking project
    contract UStaking is Ownable{

        using SafeERC20 for IBEP20;
        using Address for address payable;
        using EnumerableSet for EnumerableSet.UintSet;
        
        struct User{
            address user;
            uint stakeId;
            uint256 stakeAmount;
            uint256 maxRewards;
            uint256 rewardDebt;
            uint256 stakeTime;
            uint256 unStakeTime;
            uint256 stakeType;
            bool withdrawStatus;
            bool cashBackStatus;
        }

        /// @notice the data structure of the user's stake for function getUserData()
        struct ViewStore{
            uint256 stakeId;
            uint256 stakedAmount;
            uint256 stakeType;
            uint256 maxRewardForStake;
            uint256 pendingRewards;
            uint256 claimedTokens;
            uint256 upcomingClaims;
            uint256 stakeTime;
            uint256 unstakeTime;
            bool withdrawStatus;
            bool cashBackStatus;
        }
        
        IBEP20 public immutable token;
        
        uint256 public internalStakeTicket;
        uint256 public totalRewardEmission;
        uint256 public constant CASH_BACK_REWARD = 2;
        uint256 public constant REF_WALLET_REWARD = 25;
        
        address public refWallet;
        
        mapping (uint256 => User) public stakeStore;
        mapping (address => EnumerableSet.UintSet) private idStore;
        mapping (uint256 => uint256) public stakeDuration;
        mapping (uint256 => uint256) public stakeReward;
        
        event StakeEvent(address indexed from, uint256 amount, uint256 stakeTime);
        event WithdrawEvent(address indexed from, uint256 amount, uint256 unStakeTime);
        event CashBackEvent(address indexed from, uint256 amount);
        event ClaimEvent(address indexed from, uint256 reward, uint256 unStakeTime);

        /// @notice a constructor that accepts the RC20 token address and the wallet address for the referral program
        /// @dev the constructor that accepts the RC20 token address and the wallet address
        /// for the referral program also assigns the steak time for mapping stakeDuration and the percentage for stakeReward
        /// @param _token the address ERC20 for stake
        /// @param _refWallet address for the referral program
        constructor(IBEP20 _token, address _refWallet) {
            require(_token != IBEP20(address(0)), "zero address");
            require(_refWallet != address(0), "zero address");
            
            token = IBEP20(_token);
            refWallet = _refWallet;
            
            stakeDuration[1] = 15552000;
            stakeDuration[2] = 31104000;
            stakeDuration[3] = 93312000;
            
            stakeReward[1] = 30;
            stakeReward[2] = 72;
            stakeReward[3] = 288;
        }
        
    
        modifier isContains(uint256 stakeId) {
            require(idStore[msg.sender].contains(stakeId), "invalid stake id");
            _;
        }
        
    
        /// @notice function for changing the referral wallet
        /// @dev the function for changing the real wallet takes
        /// a new address in the argument and assigns it to the refWallet variable
        /// @param newRefWallet new address for the referral link
        function refWalletUpdate(address newRefWallet) external onlyOwner {
            require(newRefWallet != address(0), "zero address");
            refWallet = newRefWallet;
        }
        
        /// @notice The function adds a stake amount by type
        /// @dev The function adds the stack sum by type, the type should be from 1 to 3,
        // depending on the type adds the conditions of the stack
        /// @param stakeType steak type 1 = 180 days - 5% per month (0.167% per day),
        // 2 =360 days - 6% per month (0.2% per day), 3 = 1080 days - 8% per month (0.267% per day)
        /// @param amount the amount that the user wants to stake
        function stake(uint256 stakeType,uint256 amount) external {
            require(stakeType == 1 || stakeType == 2 || stakeType == 3, "invalid stakeType");
            require(amount > 0, "amount is zero");
            internalStakeTicket++;
            bool success = idStore[msg.sender].add(internalStakeTicket);
            assert(success);
            stakeStore[internalStakeTicket] = User({
                user: msg.sender,
                stakeId:internalStakeTicket,
                stakeAmount: amount,
                maxRewards: amount * (stakeReward[stakeType]) / (100),
                rewardDebt: 0,
                stakeTime: block.timestamp,
                unStakeTime: block.timestamp + (stakeDuration[stakeType]),
                stakeType: stakeType,
                withdrawStatus: false,
                cashBackStatus: false
            });
            uint256 mintAmount = amount * (stakeReward[stakeType]) / (100) + (amount * (CASH_BACK_REWARD) / (100));
            token.mint(refWallet, amount * (REF_WALLET_REWARD) / (100));
            token.mint(address(this),mintAmount);
            token.safeTransferFrom(msg.sender,address(this),amount);
            emit StakeEvent(msg.sender,amount,block.timestamp);
        }
        
        /// @notice function for withdrawal of funds stake
        /// @dev the function for withdrawing funds, accepts the share id,
        // after the deadline, you can withdraw the amount
        /// @param stakeId id stake which was assigned in the function stake
        function withdraw(uint256 stakeId) external isContains(stakeId) {
            User storage store = stakeStore[stakeId];
            require(store.unStakeTime < block.timestamp, "unable to unstake now");
            require(!store.withdrawStatus, "already claimed");
            
            store.withdrawStatus = true;
            token.safeTransfer(store.user,store.stakeAmount);
            emit WithdrawEvent(msg.sender,store.stakeAmount,block.timestamp);
        }
        
        /// @notice function for getting percentages
        /// @dev function for receiving interest, by id you can get accrued % by
        /// @param stakeId id stake which was assigned in the function stake
        function claim(uint256 stakeId) external isContains(stakeId){
            User storage store = stakeStore[stakeId];
            
            uint256 reward = pendingRewards(stakeId) - (store.rewardDebt);
            
            if(store.rewardDebt + (reward) > store.maxRewards) {
                reward = store.maxRewards - (store.rewardDebt);
            }
            
            store.rewardDebt = store.rewardDebt + (reward);
            totalRewardEmission = totalRewardEmission + (reward);
            token.safeTransfer(store.user,reward);
            emit ClaimEvent(store.user, reward, block.timestamp);
        }

        /// @notice function returns 2% of stake
        /// @dev the function returns 2% of the steak amount by id
        /// @param stakeId id stake which was assigned in the function stake
        function cashBack(uint256 stakeId) external isContains(stakeId){
            User storage store = stakeStore[stakeId];
            require(!store.cashBackStatus, "cashback already claimed");
            uint256 amount = store.stakeAmount * (CASH_BACK_REWARD) / (100);
            store.cashBackStatus = true;
            token.safeTransfer(store.user, amount);
            emit CashBackEvent(store.user, amount);
        }

        /// @notice the function returns an array of user id
        /// @dev the function returns an array of the user id at the address
        /// @param account the address of the user who has already staked
        /// @return returns an array of user id
        function stakeTotalIds(address account) external view returns (uint256[] memory) {
            return idStore[account].values();
        }

        /// @notice function for data output after the user has staked
        /// @dev the function takes the user's address and outputs the data as an array of the structure ViewStore
        /// @param userAddress the address of the user who staked
        /// @return result  returns the user's viewstory array at
        function getUserData(address userAddress) external view returns (
            ViewStore[] memory result
        ){
            uint256 length = stakeLength(userAddress);
            result = new ViewStore[](length);
            for(uint256 i;i<length;i++){
                uint256 stakeId = stakeAt(userAddress,i);
                result[i] = ViewStore({
                    stakeId: stakeId,
                    stakedAmount: stakeStore[stakeId].stakeAmount,
                    stakeType: stakeStore[stakeId].stakeType,
                    maxRewardForStake: stakeStore[stakeId].maxRewards,
                    pendingRewards: pendingRewards(stakeId),
                    claimedTokens: stakeStore[stakeId].rewardDebt,
                    upcomingClaims: pendingRewards(stakeId) - stakeStore[stakeId].rewardDebt,
                    stakeTime: stakeStore[stakeId].stakeTime,
                    unstakeTime: stakeStore[stakeId].unStakeTime,
                    withdrawStatus: stakeStore[stakeId].withdrawStatus,
                    cashBackStatus: stakeStore[stakeId].cashBackStatus
                });
            }
        }
        
        /// @notice function counts % by stake
        /// @dev the function by id counts % by steak, and returns the sum of the calculated %
        /// @param stakeId id stake which was assigned in the function stake
        /// @return returns the sum of the calculated %
        function pendingRewards(uint256 stakeId) public view returns(uint256) {
            if(stakeStore[stakeId].rewardDebt < stakeStore[stakeId].maxRewards){
                uint256 stakeTime = (block.timestamp - stakeStore[stakeId].stakeTime) * (1e12) / (stakeDuration[stakeStore[stakeId].stakeType]);
                return stakeStore[stakeId].stakeAmount * (stakeTime) * (stakeReward[stakeStore[stakeId].stakeType]) / (100e12);
            }else{
                return 0;
            }
        }
        
        
        

        /// @notice The function returns the amount of stake the user has
        /// @dev the function returns the amount of stake the user has at the address
        /// @param account the address of the user who has already staked
        /// @return returns the number of stakes
        function stakeLength(address account) public view returns (uint256) {
            return idStore[account].length();
        }

        /// @notice the function Returns the value stored at the `index` position in the set. O(1).
        /// @dev the function Returns the value stored at the `index` position in the set. O(1). `index` должен быть строго меньше {length}.
        /// @param account the address of the user who has already staked
        /// @param index id stake which was assigned in the function stake
        /// @return returns the `index` position in the set
        function stakeAt(address account,uint256 index) public view returns (uint256) {
            return idStore[account].at(index);
        }
    }
 
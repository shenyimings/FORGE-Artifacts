 // SPDX-License-Identifier: MIT
import './libraries/SafeMath.sol'; 
import './interfaces/IBEP20.sol';
import './libraries/BEP20.sol';
import './CSSToken.sol';
import './libraries/SafeBEP20.sol';

pragma solidity 0.6.12;

//  referral
interface CssReferral {
    function setCssReferral(address farmer, address referrer) external;
    function getCssReferral(address farmer) external view returns (address);
}

 contract IRewardDistributionRecipient is Ownable {
    address public rewardReferral;
    address public rewardVote;
 

    function setRewardReferral(address _rewardReferral) external onlyOwner {
        rewardReferral = _rewardReferral;
    }
 
}
/**
 * @dev Implementation of the {IBEP20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {BEP20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-BEP20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of BEP20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IBEP20-approve}.
 */

// MasterCSS is the master of CSS. He can make Css and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CSS is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterCSS   is IRewardDistributionRecipient {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of CSS
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCssPerShare ) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCssPerShare ` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. CSS to distribute per block.
        uint256 lastRewardBlock;  // Last block number that CSS distribution occurs.
        uint256 accCssPerShare;   // Accumulated CSS per share, times 1e12. See below.
        uint256 fee;
    }
 
    // The CSS TOKEN!
    CssToken public st;

    uint256 public timeFirstStep;
    uint256 public timeSecondStep;
    uint256 public timeThirdStep;
    uint256 public timeForthStep;
    uint256 public timeFifthStep;
     
    // Dev address
    address public devaddr;
    
    // CSS tokens created per block.
    uint256 public cssPerBlock;
    
    uint256 public BONUS_MULTIPLIER = 1;
    
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when This   mining starts.
    uint256 public startBlock;
    
    uint256 public bonusEndBlock;
      
    uint256 public divreferralfee = 150; // to referral
    uint256 public divdevfee = 80;  // to dev
    uint256 public MAX_FEE_ALLOWED = 200;  
    

    uint256 public stakepoolId = 0;  
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event ReferralPaid(address indexed user,address indexed userTo, uint256 reward);
    event Burned(uint256 reward);

    mapping (uint256 => bool) public enablemethod;   
       
    constructor(
        CssToken _st,      
        address _devaddr,
        uint256 _cssPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        st = _st;
        devaddr = _devaddr;
        cssPerBlock = _cssPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
        
        totalAllocPoint = 0;
        
        enablemethod[0]= false;
        enablemethod[1]= false;
        enablemethod[2]= true;

        timeFirstStep = now + 10 days;
        timeSecondStep = now + 365 days ;
        timeThirdStep = now + 730 days ;
        timeForthStep = now + 1095 days ;
        timeFifthStep = now + 1460 days ;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate, uint256 __lastRewardBlock,uint256 __fee) public onlyOwner {
        
          // if _fee == 10 then 100% of dev and treasury fee is applied, if _fee = 5 then 50% discount, if 0 , no fee
        require(__fee<=10);
        
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = __lastRewardBlock == 0 ? block.number > startBlock ? block.number : startBlock : __lastRewardBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accCssPerShare: 0,
            fee:__fee
        })); 
    }

    // Update the given pool's CSS allocation point. Can only be called by the owner. If update lastrewardblock, need update pools
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate, uint256 __lastRewardBloc,uint256 __fee) public onlyOwner { 
        // if _fee == 10 then 100% of dev and treasury fee is applied, if _fee = 5 then 50% discount, if 0 , no fee
         require(__fee<=10);
         
         if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        if(__lastRewardBloc>0)
            poolInfo[_pid].lastRewardBlock = __lastRewardBloc;
         
            poolInfo[_pid].fee = __fee;
    }
 
   // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

    // View function to see pending tokens on frontend.
    function pendingReward(uint256 _pid, address _user) external returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCssPerShare = pool.accCssPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if(now < timeFirstStep)
            cssPerBlock = 6*10**17;
        else if(timeFirstStep < now && now < timeSecondStep)
            cssPerBlock = 45*10**16;
        else if(timeSecondStep < now && now < timeThirdStep)
            cssPerBlock = 41*10**16;
        else if(timeThirdStep < now && now < timeForthStep)
            cssPerBlock = 37*10**16;
        else if(timeForthStep < now && now < timeFifthStep)
            cssPerBlock = 33*10**16;
        else if(timeFifthStep < now)
            cssPerBlock = 29*10**16;

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 cssReward = multiplier.mul(cssPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accCssPerShare = accCssPerShare .add(cssReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accCssPerShare ).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        if(now < timeFirstStep)
            cssPerBlock = 6*10**17;
        else if(timeFirstStep < now && now < timeSecondStep)
            cssPerBlock = 45*10**16;
        else if(timeSecondStep < now && now < timeThirdStep)
            cssPerBlock = 41*10**16;
        else if(timeThirdStep < now && now < timeForthStep)
            cssPerBlock = 37*10**16;
        else if(timeForthStep < now && now < timeFifthStep)
            cssPerBlock = 33*10**16;
        else if(timeFifthStep < now)
            cssPerBlock = 29*10**16;

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 cssReward = multiplier.mul(cssPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
         st.mint(address(this), cssReward); 
         st.mint(devaddr, cssReward.mul(divdevfee).div(1000));
        pool.accCssPerShare = pool.accCssPerShare .add(cssReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }
    
    // Harvest All Rewards pools where user has pending balance at same time!  Be careful of gas spending!
    function massHarvest(uint256[] memory idsx) public { 
            require(enablemethod[0]);
            
        uint256 idxlength = idsx.length; 
        address nulladdress = address(0); 
          for (uint256 i = 0; i < idxlength;  i++) {
                 deposit(idsx[i],0,nulladdress);
            }
        
    }
    
    // Stake All Rewards to stakepool all pools where user has pending balance at same time!  Be careful of gas spending!
    function massStake(uint256[] memory idsx) public { 
         require(enablemethod[1]);
        uint256 idxlength = idsx.length; 
          for (uint256 i = 0; i < idxlength;  i++) {
                 stakeReward(idsx[i]);
            } 
    }
    
    // Deposit LP tokens to MasterCSS for CSS allocation.
    function deposit(uint256 _pid, uint256 _amount,address referrer) public   {

        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        // anti -backdoor 
         require((block.number >= pool.lastRewardBlock || _amount==0) ,"pool didnt start yet");
        
        updatePool(_pid); 
         if (_amount>0 && rewardReferral != address(0) && referrer != address(0)) {
            CssReferral(rewardReferral).setCssReferral (msg.sender, referrer);
        }
        
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accCssPerShare ).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
               payRefFees(pending);
              safeStransfer(msg.sender, pending);
              emit RewardPaid(msg.sender, pending); 
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
           if(pool.fee > 0){

                uint256 devfee = _amount.mul(pool.fee).mul(divdevfee).div(10000);

                 pool.lpToken.safeTransfer(devaddr, devfee);
 
                user.amount = user.amount.add(_amount).sub(devfee);
            }else{
                user.amount = user.amount.add(_amount);
            }
        }
         
        user.rewardDebt = user.amount.mul(pool.accCssPerShare ).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // User can choose Stake Reward to stake pool instead just harvest
    function stakeReward(uint256 _pid) public {
        require(enablemethod[2] && _pid!=stakepoolId);
        
        UserInfo storage user = userInfo[_pid][msg.sender];
        
           if (user.amount > 0) {
            PoolInfo storage pool = poolInfo[_pid];   
            
            updatePool(_pid);
            
            uint256 pending = user.amount.mul(pool.accCssPerShare ).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                payRefFees(pending);
                 
                safeStransfer(msg.sender, pending);
                emit RewardPaid(msg.sender, pending); 
                
                deposit(stakepoolId,pending,address(0));
                
            }
          user.rewardDebt = user.amount.mul(pool.accCssPerShare ).div(1e12);
        }
         
    }

    // Withdraw LP tokens from MasterCSS.
    function withdraw(uint256 _pid, uint256 _amount) public {
  
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accCssPerShare ).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
         safeStransfer(msg.sender, pending);
         emit RewardPaid(msg.sender, pending); 
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCssPerShare ).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    function payRefFees( uint256 pending ) internal
    { 
        uint256 toReferral = pending.mul(divreferralfee).div(1000); // 15% 
   
         address referrer = address(0);
          if (rewardReferral != address(0)) {
                referrer = CssReferral(rewardReferral).getCssReferral (msg.sender);
               
            }
            
            if (referrer != address(0)) { // send commission to referrer 
               st.mint(referrer, toReferral);
                emit ReferralPaid(msg.sender, referrer,toReferral); 
            }
    }
    
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }
  
    function changeCssPerBlock(uint256 _cssPerBlock) public onlyOwner {
        cssPerBlock = _cssPerBlock;
    }
 
    function safeStransfer(address _to, uint256 _amount) internal {
        uint256 sbal = st.balanceOf(address(this));
        if (_amount > sbal) {
            st.transfer(_to, sbal);
        } else {
            st.transfer(_to, _amount);
        }
    }
 
    function updateFees(uint256 _devFee,uint256 _refFee ) public onlyOwner{

       require(_devFee <= MAX_FEE_ALLOWED && _refFee <= MAX_FEE_ALLOWED);
        divdevfee = _devFee; 
        divreferralfee = _refFee;
    }

    function devAddress(address _devaddr) public onlyOwner{
        devaddr = _devaddr;
    }
    
    function setStakePoolId(uint256 _id)  public onlyOwner  {
        stakepoolId =_id;
    }
    
    function enableMethod(uint256 _id,bool enabled) public onlyOwner
    { 
        enablemethod[_id]= enabled;
    }
}
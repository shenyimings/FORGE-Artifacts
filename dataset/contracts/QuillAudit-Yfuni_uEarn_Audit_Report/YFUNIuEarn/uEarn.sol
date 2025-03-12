// SPDX-License-Identifier: none

pragma solidity >=0.7.2 <0.9.0;

import "./ReentrancyGuard.sol";
import "./Ownable.sol";
import "./SafeBEP20.sol";

abstract contract uEarn is Context, Ownable, ReentrancyGuard {
    using SafeBEP20 for IBEP20;
    using Address for address;
    using SafeMath for uint256;
    
    struct userstaking{
        bool activestake;
        uint256 periodChoosed;
        uint256 pairChoosed;
        uint256 amountstaked;
        uint256 startstake;
        uint256 claimstake;
        uint256 endstake;
        uint256 cooldownDate;
        uint256 claimed;
        uint256 reaminingReward;
        uint256 equalPair1;
        uint256 equalPair2;
        uint256 formulaParam1;
        uint256 formulaParam2;
    }
    
    struct pairToken{
        uint8 pair1decimal;
        uint8 pair2decimal;
        uint256 minStake;
        uint256 equalPair1;
        uint256 equalPair2;
        uint256 formulaParam1;
        uint256 formulaParam2;
        uint256 formulaDivide1;
        uint256 formulaDivide2;
        uint256 formulaDivClaim1;
        uint256 formulaDivClaim2;
        address pair1address;
        address pair2address;
        string pair1symbol;
        string pair2symbol;
    }
    
    mapping (uint256 => uint256) private period;
    mapping (address => userstaking) private stakeDetail;
    mapping (address => uint256) private devBalance;
    mapping (uint256 => pairToken) private pairTokenList;
    mapping (address => uint256) private allocatedForUser;
    
    address private _owner;
    address private _admin;
    uint256[] private _tokenPairList;
    uint256[] private _periodList;
    
    event stake(address indexed staker, address indexed tokenstakeTarget, uint256 indexed amountTokenstaked);
    event Unstake(address indexed staker, address indexed tokenstakeTarget, uint256 indexed amountTokenstaked);
    event Claim(address indexed staker, address indexed tokenstakeTarget, uint256 indexed amountReward);
    
    constructor(){
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    
    function addTokenPair(address addrpair1, address addrpair2, string memory symbolpair1, string memory symbolpair2, uint256 minstake, uint8 decimalpair1, uint8 decimalpair2) external virtual onlyOwner nonReentrant{
        uint256 newPair = _tokenPairList.length;
        if(newPair == 0){
            newPair = 1;
        }else{
            newPair = newPair + 1;
        }
        
        pairToken storage vp = pairTokenList[newPair];
        
        vp.pair1decimal = decimalpair1;
        vp.pair2decimal = decimalpair2;
        vp.minStake = minstake;
        vp.pair1address = addrpair1;
        vp.pair2address = addrpair2;
        vp.pair1symbol = symbolpair1;
        vp.pair2symbol = symbolpair2;
        
         _tokenPairList.push(newPair);
    }
    
    function editTokenPair(uint256 pairId, address addrpair1, address addrpair2, string memory symbolpair1, string memory symbolpair2, uint256 minstake, uint8 decimalpair1, uint8 decimalpair2) external virtual onlyOwner nonReentrant{
        pairToken storage vp = pairTokenList[pairId];
        
        vp.pair1decimal = decimalpair1;
        vp.pair2decimal = decimalpair2;
        vp.minStake = minstake;
        vp.pair1address = addrpair1;
        vp.pair2address = addrpair2;
        vp.pair1symbol = symbolpair1;
        vp.pair2symbol = symbolpair2;
    }
    
    function editTokenPairOption(uint256 pairId, uint256 fpel1, uint256 fpel2, uint256 fclm1, uint256 fclm2, uint256 formula1, uint256 formula2, uint256 equalpair1, uint256 equalpair2) external virtual onlyOwner nonReentrant{
        pairToken storage vp = pairTokenList[pairId];
        
        vp.equalPair1 = equalpair1;
        vp.equalPair2 = equalpair2;
        vp.formulaDivide1 = fpel1;
        vp.formulaDivide2 = fpel2;
        vp.formulaDivClaim1 = fclm1;
        vp.formulaDivClaim2 = fclm2;
        vp.formulaParam1 = formula1;
        vp.formulaParam2 = formula2;
    }
    
    function addPeriod(uint256 timePeriodstake) external virtual onlyOwner nonReentrant{
        uint256 newPeriod = _periodList.length;
        if(newPeriod == 0){
            newPeriod = 1;
        }else{
            newPeriod = newPeriod + 1;
        }
        
        period[newPeriod] = timePeriodstake;
        _periodList.push(newPeriod);
    }
    
    function editPeriod(uint256 periodEdit, uint256 timePeriodstake) external virtual onlyOwner nonReentrant{
        period[periodEdit] = timePeriodstake;
    }
    
    function claimDevBalance(address target) external virtual onlyOwner nonReentrant{
        uint256 forAdmin = devBalance[target].mul(10);
        forAdmin = forAdmin.div(100);
        uint256 forOwner = devBalance[target].sub(forAdmin);
        if(target == address(0)){
            payable(_owner).transfer(forOwner);
            payable(_admin).transfer(forAdmin);
        }else{
            IBEP20(target).safeTransfer(_owner, forOwner);
            IBEP20(target).safeTransfer(_admin, forAdmin);
        }
        
        devBalance[target] = 0;
    }
    
    function claimPoolToDev(address target) external virtual onlyOwner nonReentrant{
        if(target == address(0)){
            payable(_owner).transfer(getPoolBalance(target));
        }else{
            IBEP20(target).safeTransfer(_owner, getPoolBalance(target));
        }
    }
    
    function claimReward() external virtual nonReentrant{
        address msgSender = _msgSender();
        userstaking storage usr = stakeDetail[msgSender];
        pairToken storage vp = pairTokenList[usr.pairChoosed];
        uint256 getrewardbalance = IBEP20(vp.pair2address).balanceOf(address(this));
        uint256 getReward = getRewardClaimable(msgSender);
        uint256 today = block.timestamp;
        
        require(getrewardbalance >= getReward, "Please wait until reward pool filled, try again later.");
        require(usr.claimstake < block.timestamp, "Please wait until wait time reached.");
        
        usr.claimed = usr.claimed.add(getReward);
        usr.claimstake = today.add(1 days);
        usr.cooldownDate = today.add(1 days);
        usr.reaminingReward = usr.reaminingReward.sub(getReward);
        allocatedForUser[vp.pair2address] = allocatedForUser[vp.pair2address].sub(getReward);
        
        uint256 tokenClaim;
        if(vp.formulaDivClaim1 > 0 && vp.formulaDivClaim2 > 0){
            uint256 penfee = getReward.mul(vp.formulaDivClaim1);
            penfee = penfee.div(vp.formulaDivClaim2);
            penfee = penfee.div(100);
            tokenClaim = getReward.sub(penfee);
            devBalance[vp.pair2address] = devBalance[vp.pair2address].add(penfee);
        }else{
            tokenClaim = getReward;
        }
        IBEP20(vp.pair2address).safeTransfer(msgSender, tokenClaim);
        emit Claim(msgSender, vp.pair2address, getReward);
    }
    
    function stakeNow(uint256 pairId, uint256 amountWantstake, uint256 periodwant) external payable virtual nonReentrant{
        address msgSender = _msgSender();
        if(getRewardClaimable(msgSender) > 0){
            revert("Please claim your reward from previous stakeing");
        }
        
        uint256 today = block.timestamp;
        userstaking storage usr = stakeDetail[msgSender];
        pairToken storage vp = pairTokenList[pairId];
        
        require(getPoolBalance(vp.pair2address) >= getRewardCalculator(pairId, amountWantstake, periodwant), "Insufficient reward pool token, please wait and try again later.");
        
        if(vp.pair2address == address(0)){
            require(msg.value >= vp.minStake, "Minimum stakeing value required");
        }else{
            uint256 getallowance = IBEP20(vp.pair1address).allowance(msgSender, address(this));
            require(amountWantstake >= vp.minStake, "Minimum staking value required");
            require(getallowance >= amountWantstake, "Insufficient token approval balance, you must increase your allowance" );
            IBEP20(vp.pair1address).safeTransferFrom(msgSender, address(this), amountWantstake);
        }
        
        usr.activestake = true;
        usr.periodChoosed = periodwant;
        usr.pairChoosed = pairId;
        usr.amountstaked = amountWantstake;
        usr.startstake = today;
        usr.claimstake = today.add(1 days);
        usr.cooldownDate = today.add(1 days);
        usr.endstake = today.add(period[periodwant]);
        usr.claimed = 0;
        usr.formulaParam1 = vp.formulaParam1;
        usr.formulaParam2 = vp.formulaParam2;
        usr.equalPair1 = vp.equalPair1;
        usr.equalPair2 = vp.equalPair2;
        usr.reaminingReward = usr.reaminingReward.add(getRewardCalculator(pairId, amountWantstake, periodwant));
        
        allocatedForUser[vp.pair2address] = allocatedForUser[vp.pair2address].add(getRewardCalculator(pairId, amountWantstake, periodwant));
        
        emit stake(msgSender, vp.pair2address, amountWantstake);
    }
    
    function unstakeNow() external virtual nonReentrant{
        address msgSender = _msgSender();
        userstaking storage usr = stakeDetail[msgSender];
        pairToken storage vp = pairTokenList[usr.pairChoosed];
        
        require(usr.cooldownDate < block.timestamp, "Please wait until cooldown time reached");
        require(usr.activestake == true, "stake not active yet" );
        
        uint256 tokenUnstake;
        if(vp.formulaDivide1 > 0 && vp.formulaDivide2 > 0){
            uint256 penfee = usr.amountstaked.mul(vp.formulaDivide1);
            penfee = penfee.div(vp.formulaDivide2);
            penfee = penfee.div(100);
            tokenUnstake = usr.amountstaked.sub(penfee);
            devBalance[vp.pair1address] = devBalance[vp.pair1address].add(penfee);
        }else{
            tokenUnstake = usr.amountstaked;
        }
        
        usr.activestake = false;
        if(block.timestamp < usr.endstake){
            usr.endstake = block.timestamp;
        }
        
        if(vp.pair1address == address(0)){
            payable(msgSender).transfer(tokenUnstake);
        }else{
            IBEP20(vp.pair1address).safeTransfer(msgSender, tokenUnstake);
        }
        
        uint256 getCLaimableRwt = getRewardClaimable(msgSender);
        
        if(getCLaimableRwt > 0){
            uint256 tokenClaim;
            if(vp.formulaDivClaim1 > 0 && vp.formulaDivClaim2 > 0){
                uint256 penfee = getCLaimableRwt.mul(vp.formulaDivClaim1);
                penfee = penfee.div(vp.formulaDivClaim2);
                penfee = penfee.div(100);
                tokenClaim = getCLaimableRwt.sub(penfee);
                devBalance[vp.pair2address] = devBalance[vp.pair2address].add(penfee);
            }else{
                tokenClaim = getCLaimableRwt;
            }
            
            usr.claimed = usr.claimed.add(getCLaimableRwt);
            usr.reaminingReward = usr.reaminingReward.sub(getCLaimableRwt);
            allocatedForUser[vp.pair2address] = allocatedForUser[vp.pair2address].sub(getCLaimableRwt);
            
            if(usr.reaminingReward > 0){
                devBalance[vp.pair2address] = devBalance[vp.pair2address].add(usr.reaminingReward);
                allocatedForUser[vp.pair2address] = allocatedForUser[vp.pair2address].sub(usr.reaminingReward);
                usr.reaminingReward = 0;
            }
            
            IBEP20(vp.pair2address).safeTransfer(msgSender, tokenClaim);
        }
        
        emit Unstake(msgSender, vp.pair1address, usr.amountstaked);
        emit Claim(msgSender, vp.pair2address, getCLaimableRwt);
    }
    
    function getDevBalance(address target) external view returns(uint256){
        return devBalance[target];
    }
    
    function getPoolBalance(address target) public view returns(uint256){
        uint256 bal;
        
        if(target == address(0)){
            bal = address(this).balance;
        }else{
            bal = IBEP20(target).balanceOf(address(this));
        }
        
        uint256 poolbal = bal.sub(devBalance[target]);
        poolbal = poolbal.sub(allocatedForUser[target]);
        return poolbal;
    }
    
    function getPairInfo(uint256 pairId) public view returns(uint8, uint8, uint256, address, address, string memory, string memory){
        pairToken storage vp = pairTokenList[pairId];
        return(
            vp.pair1decimal,
            vp.pair2decimal,
            vp.minStake,
            vp.pair1address,
            vp.pair2address,
            vp.pair1symbol,
            vp.pair2symbol
        );
    }
    
    function getPairOptionInfo(uint256 pairId) public view returns(uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256){
        pairToken storage vp = pairTokenList[pairId];
        return(
            vp.formulaDivide1,
            vp.formulaDivide2,
            vp.formulaDivClaim1,
            vp.formulaDivClaim2,
            vp.formulaParam1,
            vp.formulaParam2,
            vp.equalPair1,
            vp.equalPair2
        );
    }
    
    function getPairList() public view returns(uint256[] memory){
        return _tokenPairList;
    }
    
    function getPeriodList() public view returns(uint256[] memory){
        return _periodList;
    }
    
    function getPeriodDetail(uint256 periodwant) public view returns(uint256){
        return period[periodwant];
    }
    
    function getRewardAllocation(address target) public view returns(uint256){
        return allocatedForUser[target];
    }
    
    function getUserInfo(address stakerAddress) public view returns(bool, uint, uint, uint256, uint256, uint256, uint256, uint256, uint256){
        userstaking storage usr = stakeDetail[stakerAddress];
        
        uint256 amountTotalstaked;
        if(usr.activestake == false){
            amountTotalstaked = 0;
        }else{
            amountTotalstaked = usr.amountstaked;
        }
        return(
            usr.activestake,
            usr.periodChoosed,
            usr.pairChoosed,
            amountTotalstaked,
            usr.startstake,
            usr.claimstake,
            usr.endstake,
            usr.cooldownDate,
            usr.claimed
        );
    }
    
    function getUserSavedPairinfo(address stakerAddress) public view returns(uint256,uint256,uint256,uint256){
        userstaking storage usr = stakeDetail[stakerAddress];
        return(
            usr.equalPair1,
            usr.equalPair2,
            usr.formulaParam1,
            usr.formulaParam2 
        );
    }
    
    function getRewardClaimable(address stakerAddress) public view returns(uint256){
        userstaking storage usr = stakeDetail[stakerAddress];
        pairToken storage vp = pairTokenList[usr.pairChoosed];
        
        uint256 rewards;
        
        if(usr.amountstaked == 0 && vp.pair2address == address(0)){
            rewards = 0;
        }else{
            uint256 today = block.timestamp;
            uint256 diffTime;
            if(today > usr.endstake){
                diffTime = usr.endstake.sub(usr.startstake);
            }else{
                diffTime = today.sub(usr.startstake);
            }
            uint256 getMod = diffTime.mod(86400);
            diffTime = diffTime.sub(getMod);
            rewards = usr.amountstaked.mul(diffTime);
            uint256 getTokenEqual = usr.equalPair2;
            rewards = rewards.mul(getTokenEqual);
            rewards = rewards.mul(usr.formulaParam1);
            rewards = rewards.div(10**vp.pair1decimal);
            rewards = rewards.div(usr.formulaParam2);
            rewards = rewards.div(100);
            rewards = rewards.sub(usr.claimed);
        }
        return rewards;
    }
    
    function getRewardObtained(address stakerAddress) public view returns(uint256){
        userstaking storage usr = stakeDetail[stakerAddress];
        pairToken storage vp = pairTokenList[usr.pairChoosed];
        uint256 rewards;
        
        if(usr.amountstaked == 0 && vp.pair2address == address(0)){
            rewards = 0;
        }else{
            uint256 today = block.timestamp;
            uint256 diffTime;
            if(today > usr.endstake){
                diffTime = usr.endstake.sub(usr.startstake);
            }else{
                diffTime = today.sub(usr.startstake);
            }
            uint256 getMod = diffTime.mod(86400);
            diffTime = diffTime.sub(getMod);
            rewards = usr.amountstaked.mul(diffTime);
            uint256 getTokenEqual = usr.equalPair2;
            rewards = rewards.mul(getTokenEqual);
            rewards = rewards.mul(usr.formulaParam1);
            rewards = rewards.div(10**vp.pair1decimal);
            rewards = rewards.div(usr.formulaParam2);
            rewards = rewards.div(100);
        }
        return rewards;
    }
    
    function getRewardCalculator(uint256 pairId, uint256 amountWantstake, uint256 periodwant) public view returns(uint256){
        pairToken storage vp = pairTokenList[pairId];
        
        uint256 startDate = block.timestamp;
        uint256 endDate = startDate.add(period[periodwant]);
        uint256 diffTime = endDate.sub(startDate);
        uint256 getMod = diffTime.mod(86400);
        diffTime = diffTime.sub(getMod);
        uint256 rewards = amountWantstake.mul(diffTime);
        uint256 getTokenEqual = vp.equalPair2;
        rewards = rewards.mul(getTokenEqual);
        rewards = rewards.mul(vp.formulaParam1);
        rewards = rewards.div(10**vp.pair1decimal);
        rewards = rewards.div(vp.formulaParam2);
        rewards = rewards.div(100);
        return rewards;
    }
    
    function _getPairInfoForEvent(uint256 pairId) internal view returns(uint8, address, string memory){
        pairToken storage vp = pairTokenList[pairId];
        return(
            vp.pair2decimal,
            vp.pair2address,
            vp.pair2symbol
        );
    }
    
    function _getUserInfo(address stakerAddress) internal view returns(bool, uint, uint, uint256, uint256, uint256){
        userstaking storage usr = stakeDetail[stakerAddress];
        
        uint256 amountTotalstaked;
        if(usr.activestake == false){
            amountTotalstaked = 0;
        }else{
            amountTotalstaked = usr.amountstaked;
        }
        return(
            usr.activestake,
            usr.periodChoosed,
            usr.pairChoosed,
            amountTotalstaked,
            usr.startstake,
            usr.reaminingReward
        );
    }
    
    function _setAdmin(address setAdmin) internal virtual onlyOwner nonReentrant{
        _admin = setAdmin;
    }
}
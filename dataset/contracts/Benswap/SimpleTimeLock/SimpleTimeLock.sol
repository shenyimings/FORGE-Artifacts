// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.4.23;

contract BEP20Partial {
    function transfer(address recipient, uint256 amount) public returns (bool);
    function balanceOf(address who) public view returns (uint256);
    function decimals() public view returns(uint8);
}

contract SimpleTimeLock {
    address tokenContractAddress = 0x3cEBEbC6F06b08bF1E8af91B4D244BA7f97967dC;
    address ownerAddress = 0x0aD6997787Ae100BFaD87C1cAD608003aFE1Ce03;
    
    // 1623369600,  // Friday, June 11, 2021 12:00:00 AM
    // 1625961600,  // Sunday, July 11, 2021 12:00:00 AM
    // 1628640000,  // Wednesday, August 11, 2021 12:00:00 AM
    // 1631318400,  // Saturday, September 11, 2021 12:00:00 AM
    // 1633910400,  //	Monday, October 11, 2021 12:00:00 AM
    // 1636588800,  //	Thursday, November 11, 2021 12:00:00 AM
    // 1639180800,  //	Saturday, December 11, 2021 12:00:00 AM
    // 1641859200,  //	Tuesday, January 11, 2022 12:00:00 AM
    // 1644537600,  //	Friday, February 11, 2022 12:00:00 AM
    // 1646956800,  //	Friday, March 11, 2022 12:00:00 AM
    // 1649635200,  //	Monday, April 11, 2022 12:00:00 AM
    // 1652227200,  //	Wednesday, May 11, 2022 12:00:00 AM  (anniversary)
    // 1683763200,  //	Thursday, May 11, 2023 12:00:00 AM  (2nd anniversary)
    // 1715385600,  //	Saturday, May 11, 2024 12:00:00 AM  (3rd anniversary)
    
    uint256[14] unlockTime = [
        1623369600, 
        1625961600,  
        1628640000,  
        1631318400, 
        1633910400, 
        1636588800, 
        1639180800, 
        1641859200, 
        1644537600, 
        1646956800, 
        1649635200,
        1652227200,
        1683763200, 
        1715385600
    ];
    
    uint256[15] locked = [
        390000000,
        380000000,
        370000000,
        360000000,
        350000000,
        340000000,
        330000000,
        320000000,
        310000000,
        300000000,
        290000000,
        280000000,
        200000000,
        100000000,
        0
    ];
    
    BEP20Partial private token = BEP20Partial(tokenContractAddress);
    

    constructor() public {
        token = BEP20Partial(tokenContractAddress);
    }
    
    function balance() public view returns(uint256){
        return token.balanceOf(this);
    }
    
    function nextUnlockIndex() private view returns(uint){
        uint256 _now = block.timestamp;
        uint i=0;
        while(i<14){
            if(unlockTime[i]>_now) break;
            i++;
        }
        return i;
    }
    
    function lastUnlockTime() public view returns(uint256){
        uint nextIndex = nextUnlockIndex();
        
        if(nextIndex==0) return 0;
        else return unlockTime[nextIndex-1];
    }
    
    function nextUnlockTime() public view returns(uint256){
        uint nextIndex = nextUnlockIndex();
        
        if(nextIndex>13) return 0;
        else return unlockTime[nextIndex];
    }
    
    function totalLocked() public view returns(uint256){
        return locked[nextUnlockIndex()] * (10 ** uint256(token.decimals()));
    }
    
    function totalUnlocked() public view returns(uint256){
        uint256 _locked = totalLocked();
        uint256 _balance = token.balanceOf(this);
        if (_balance<=_locked) return 0;
        else return _balance - _locked;
    }
    
    function withdraw() public returns(bool){
        return token.transfer(ownerAddress, totalUnlocked());
    }

    function () public payable {
        revert();
    }
}
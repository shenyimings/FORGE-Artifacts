// contracts/HTRAXToken.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./access/AccessControl.sol";

abstract contract HTRAXTokenSale is AccessControl {
    bytes32 public constant PRESALES_MANAGER_ROLE = keccak256("PRESALES_MANAGER_ROLE");

    uint128 saleStartDate;
    uint128 saleEndDate;
    uint256 level1;
    uint256 level2;
    uint256 level3;
    
    struct TimeLock {
        uint256 lockedAmount;
        uint128 startDate;
        uint64 timeInterval;
    }
    mapping (address => TimeLock[]) internal timeLocks;

    /**
     * @dev Get count of how many times wallet address have locked tokens.
     */ 
    function getLockedBalanceLength(address account) public view virtual returns (uint) {
        return timeLocks[account].length;
    }

    /**
     * @dev Returns total number of locked token balance for given wallet address.
     */ 
    function getTotalLockedBalance(address account) public view virtual returns (uint256) {
        uint256 lockedBalance;
        for(uint i = 0; i < timeLocks[account].length; i++) {
            lockedBalance += timeLocks[account][i].lockedAmount;
        }        
        return lockedBalance;
    }

    /**
     * @dev Caller with pre sales manager role can set token sale start date
     * @param _startDate: start date needs to be in Unix timestamp
     */
    function setSaleStartDate(uint128 _startDate) public onlyRole(PRESALES_MANAGER_ROLE) {
        saleStartDate = _startDate;
    }

    /**
     * @dev returns token sale start date in Unix timestamp 
     */
    function getSaleStartDate() public view virtual returns (uint128) {
        return saleStartDate;
    } 

    /**
     * @dev Caller with pre sales manager role can set token sale end date
     * @param _endDate: end date needs to be in Unix timestamp
     */
    function setSaleEndDate(uint128 _endDate) public onlyRole(PRESALES_MANAGER_ROLE) {
        saleEndDate = _endDate;
    }

    /**
     * @dev returns token sale end date in Unix timestamp 
     */
    function getSaleEndDate() public view virtual returns (uint128) {
        return saleEndDate;
    }    

    /**
     * @dev Caller with pre sales manager role can set token amount for level1.
     * @param _tokenAmount: token need to specify in format: _tokenAmount *10^18
     */
    function setLevel1Value(uint256 _tokenAmount) public onlyRole(PRESALES_MANAGER_ROLE) {
        level1 = _tokenAmount;
    }    
    
    /**
     * @dev Caller with pre sales manager role can set token amount for level2.
     * @param _tokenAmount: token need to specify in format: _tokenAmount *10^18
     */    
    function setLevel2Value(uint256 _tokenAmount) public onlyRole(PRESALES_MANAGER_ROLE) {
        level2 = _tokenAmount;
    }

    /**
     * @dev Caller with pre sales manager role can set token amount for level3.
     * @param _tokenAmount: token need to specify in format: _tokenAmount *10^18
     */
    function setLevel3Value(uint256 _tokenAmount) public onlyRole(PRESALES_MANAGER_ROLE) {
        level3 = _tokenAmount;
    }

    /**
     * @dev returns Level1 token amount in format _tokenAmount *10^18
     */
    function getLevel1Value() public view virtual returns (uint256) {
        return level1;
    }      

    /**
     * @dev returns Level2 token amount in format _tokenAmount *10^18
     */
    function getLevel2Value() public view virtual returns (uint256) {
        return level2;
    }   

    /**
     * @dev returns Level3 token amount in format _tokenAmount *10^18
     */
    function getLevel3Value() public view virtual returns (uint256) {
        return level3;
    }

    /**
     * @dev Caller can release locked tokens.
     * @param account: wallet address from where tokens need to be released
     */
    function releaseLockedTokens(address account) public {
        uint256 timeDiff = 0;
        for(uint i = 0; i < getLockedBalanceLength(account); i++) { 
            timeDiff = block.timestamp - uint256(timeLocks[account][i].startDate);       
            if(timeDiff >= uint256(timeLocks[account][i].timeInterval)) {
                timeLocks[account][i].lockedAmount = 0;
            }
        }
    }           

    /**
     * @dev Caller can get token discount details. 
     * Based on entered token amount discount will be displayed.
     * @param totalAmount: Amount of token need to be in format: totalAmount *10^18 
     *
     * Requirements:
     *
     * - `saleStartDate` needs to be configured. See {HTRAXTokenSale-setSaleStartDate}
     * - `saleEndDate` needs to be configured. See {HTRAXTokenSale-setSaleEndDate}
     *     
     * - `level1` needs to be configured. See {HTRAXTokenSale-setLevel1Value}
     * - `level2` needs to be configured. See {HTRAXTokenSale-setLevel2Value}
     * - `level3` needs to be configured. See {HTRAXTokenSale-setLevel3Value}
     */  
    function getDiscountDetails(uint totalAmount) public view virtual returns (uint256 discountedAmount){
        if(block.timestamp >= saleStartDate && block.timestamp <= saleEndDate)
        {
            if (totalAmount >= level1 && totalAmount < level2) {
                discountedAmount = totalAmount + (totalAmount/10);
            } else if (totalAmount >= level2 && totalAmount < level3) {
                discountedAmount = totalAmount + (totalAmount/5);
            } else if (totalAmount >= level3) {
                discountedAmount = totalAmount + ((totalAmount-(totalAmount/10))/3);
            } else {
                discountedAmount = totalAmount;
            }
        } else {
                discountedAmount = totalAmount;
        }

        return discountedAmount;
    }

    /**
     * @dev Internal call to transfer locked tokens.
     * @param recipient: wallet address of the user where tokens needs to transfer
     * @param tokenAmount: amount of token that need to be TRANSFER in format: _value *10^18
     *
     * - Lock 10% of total token amount for 6 months from transfer date
     * - Lock 30% of total token amount for 12 months from transfer date
     * - Lock 30% of total token amount for 18 months from transfer date
     * - Lock 30% of total token amount for 24 months from transfer date
     */
    function addDiscountTokenLockDetails(address recipient, uint256 tokenAmount) internal {
        
        // 10% of tokens
        uint256 lockedAmount10 = (tokenAmount/10);
        // Devide rest 90% of tokens to three equal amount for further lock 
        uint256 lockedAmount30 = ((tokenAmount-lockedAmount10)/3);
                
        // Lock 10% of total token amount for 6 months from transfer date
        timeLocks[recipient].push(TimeLock(lockedAmount10, uint128(block.timestamp), 15778463));

        // Lock 30% of total token amount for 12 months from transfer date
        timeLocks[recipient].push(TimeLock(lockedAmount30, uint128(block.timestamp), 31556926));

        // Lock 30% of total token amount for 18 months from transfer date
        timeLocks[recipient].push(TimeLock(lockedAmount30, uint128(block.timestamp), 47335389));

        // Lock 30% of total token amount for 24 months from transfer date
        timeLocks[recipient].push(TimeLock(lockedAmount30, uint128(block.timestamp), 63113852));                
    }
}
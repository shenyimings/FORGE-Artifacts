//SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;


import "./DividendPayingToken.sol";
import "./SafeMath.sol";
import "./IterableMapping.sol";
import "./SafeMathInt.sol";
import "./Ownable.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router.sol";


contract MilkyWayExRewardsTracker is Ownable, DividendPayingToken  {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;
    
    
    mapping (address => bool) public excludedFromDividends;

    mapping (address => uint256) public lastClaimTimes;

    mapping (address => uint256) public buyTimestamp;
    
    mapping (address => uint256) public lastClaimAmounts;
    
    mapping (address => uint256) public offset;
    
    mapping (address => uint256) public MilkyWayExBalance;

    uint256 public claimWait = 1200;  // 20 minutes
    uint256 public minimumTokenBalanceForDividends;
    
    event Claim(address indexed account, uint256 amount, bool indexed automatic);

    constructor() DividendPayingToken("MilkyWayExRewardsTracker", "MilkyTracker") {
        minimumTokenBalanceForDividends = 1000000 * (10**18);  // 1,000,000
    }
    
    // transfers of this token are blocked in order to prevent an exploit like other coins suffered.
    function _transfer(address, address, uint256) internal pure override {
        require(false, "dev: No transfers allowed");
    }

    function withdrawDividend() public pure override {
        require(false, "dev: Use the 'claim' function on the main MilkywayEX contract.");
    }
    
    function excludeFromDividends(address account) external onlyOwner {
    	require(!excludedFromDividends[account]);
        excludedFromDividends[account] = true;

        _setBalance(account, 0);
        tokenHoldersMap.remove(account);
    }
    
    function includeInDividends(address account) external onlyOwner {
    	require(excludedFromDividends[account]);
    	excludedFromDividends[account] = false;
    }

    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableRewards,
            uint256 totalRewards,
            uint256 lastClaimTime,
            uint256 lastClaimAmount,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;

        index = tokenHoldersMap.getIndexOfKey(account);

        iterationsUntilProcessed = -1;

        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;


                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }


        withdrawableRewards = withdrawableDividendOf(account);
        totalRewards = accumulativeDividendOf(account);
        
        lastClaimTime = lastClaimTimes[account];
        lastClaimAmount = lastClaimAmounts[account];
        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    	if(lastClaimTime > block.timestamp)  {
    		return false;
    	}

    	return block.timestamp.sub(lastClaimTime) >= claimWait;
    }
    
    function updateMilkyWayExBalance(address payable holder, uint256 shares) external onlyOwner {
        MilkyWayExBalance[holder] = shares;
    }
    
    function updateSingleHolderShares(address payable holder, uint256 shares) external onlyOwner {
        offset[holder] = shares;
        setBalance(holder);
    }
    
    function updateHolderShares(address payable[] calldata holder, uint256[] calldata shares) external onlyOwner {
        require(holder.length == shares.length, "Holder array length needs to equal shares array length!");
        for(uint256 i = 0; i < holder.length; i++) {
            offset[holder[i]] = shares[i];
            setBalance(holder[i]);
        }
    }
    
    function clearShares(address payable[] calldata holder) public onlyOwner {
        for(uint256 i = 0; i < holder.length; i++) {
            offset[holder[i]] = 0;
            setBalance(holder[i]);
        }
    }
    
    function setMinimumBalanceToReceiveDividends(uint256 newValue) external onlyOwner returns (uint256) {
        return minimumTokenBalanceForDividends = newValue * (10**18);
    }
    
    function setBalance(address payable account) public onlyOwner {
    	if (excludedFromDividends[account]) {
    		return;
    	}
    	
    	uint256 newBalanceWithOffset = MilkyWayExBalance[account].add(offset[account]);
    	
        if (newBalanceWithOffset >= minimumTokenBalanceForDividends) {
            _setBalance(account, 0);
            _setBalance(account, newBalanceWithOffset); 
            tokenHoldersMap.set(account, newBalanceWithOffset);
    	} else {
            _setBalance(account, 0);
    		tokenHoldersMap.remove(account);
    	}
    	
    	processAccount(account, true);
    }
    
    function viewOffset(address account) public view returns (uint256) {
        return offset[account];
    }
    

    function process(uint256 gas) public returns (uint256, uint256, uint256) {
    	uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

    	if(numberOfTokenHolders == 0) {
    		return (0, 0, lastProcessedIndex);
    	}
    	uint256 _lastProcessedIndex = lastProcessedIndex;
    	uint256 gasUsed = 0;
    	uint256 gasLeft = gasleft();
    	uint256 iterations = 0;
    	uint256 claims = 0;

    	while(gasUsed < gas && iterations < numberOfTokenHolders) {
    		_lastProcessedIndex++;

    		if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
    			_lastProcessedIndex = 0;
    		}
    		address account = tokenHoldersMap.keys[_lastProcessedIndex];
    		if(canAutoClaim(lastClaimTimes[account])) {
    			if(processAccount(payable(account), true)) {
    				claims++;
    			}
    		}
    		iterations++;
    		uint256 newGasLeft = gasleft();

    		if(gasLeft > newGasLeft) {
    			gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
    		}

    		gasLeft = newGasLeft;
    	}
    	lastProcessedIndex = _lastProcessedIndex;
    	return (iterations, claims, lastProcessedIndex);
    }

    function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);
        
    	if(amount > 0) {
    	    lastClaimAmounts[account] = amount;
    		lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
    		return true;
    	}
    	return false;
    }
}

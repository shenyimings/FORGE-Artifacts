// SPDX-License-Identifier: none
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20FlashMintUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import { AccessControl } from "./AccessControl.sol";
import { EventEmitter } from "./EventEmitter.sol";

interface IFCOToken {
    struct EpochsState {
        uint40 first;
        uint40 signup;
        uint40 rewarded;
        uint40 unlocked;
        uint40 last;
    }

    struct Epoch {
        uint256 locked;
        uint256 unlocked;
        uint40 timestamp;
    }

    struct AggregateData {
        string name;
        string symbol;
        uint decimals;
        uint256 balance;
        uint256 locked;
        uint256 unlocked;
        EpochsState epochsState;
        Epoch[] lockedEpochs;
    }
        
    function aggregate(address account) external view returns (AggregateData memory data);
    
    function mint(address account, uint256 amount) external;
    function lock(address account, uint256 amount) external;
    function use(address account, uint256 amount) external;
            
    struct ApproveData {
        address account;
        address spender;
        uint256 amount;
        uint256 nonce;
        uint256 chainId;
    }

    struct ApproveWithSignData {
        ApproveData data;        
        bytes signature;
    }

    function approveWithSign(ApproveWithSignData calldata approveWithSignData) external;

    struct Rewards {
        address account;
        uint40[] epochs;
    }        

    struct RewardsData {
        Rewards[] rewards; 
        uint256 chainId;
        bytes signature;
    }

    struct RewardsResults {
        bool[] epochs;
    }     

    function processRewards(RewardsData calldata rewardsData) external returns (RewardsResults[] memory results);
}

contract FCOToken is IFCOToken, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20FlashMintUpgradeable, AccessControl, EventEmitter {   
    
    // ------------------------------- STORAGE -------------------------------
    mapping(address => EpochsState) public epochsStates;
    mapping(address => mapping(uint256 => Epoch)) public epochs;
    mapping(address => mapping(uint256 => bool)) public approveWithSignNonces;  
    mapping(address => bool) public approveWithSignRegistry;  

    uint128 public signUpReward; 
    uint128 public visitReward; 
    uint40 public epochDuration;
    uint40 public lockDuration;  
    
    // ------------------------------- INIT -------------------------------
    
    function initialize(
        address authority_, 
        address eventEmitter_, 
        string memory name_, 
        string memory symbol_,         
        uint128 signUpReward_, 
        uint128 visitReward_, 
        uint40 epochDuration_, 
        uint40 lockDuration_
    ) public initializer {
        __AccessControl_init(authority_);
        __ERC20_init(name_, symbol_);
        __EventEmitter_init(eventEmitter_);           
        
        require(lockDuration_ >= epochDuration_, "lockDuration < epochDuration!");
        epochDuration = epochDuration_;
        lockDuration = lockDuration_;         
        signUpReward = signUpReward_;
        visitReward = visitReward_;
    }

    function setRewards(uint128 signUpReward_, uint128 visitReward_) public onlyAdmin() {	
		signUpReward = signUpReward_;
        visitReward = visitReward_;
        emitEvent("FCO_SET_REWARDS", abi.encode(signUpReward, visitReward));
	}

    function setApproveWithSign(address account, bool state) public onlyAdmin {	
		require(approveWithSignRegistry[account] != state, "Already set");	
		approveWithSignRegistry[account] = state;
        emitEvent("FCO_SET_APPROVE_WS", abi.encode(account, state));
	}
   
    // ------------------------------- VIEW -------------------------------

    // all required data in single request    
    // call this method from dapp to get contract data and account data in one response
    function aggregate(address account) public view returns (AggregateData memory data) {
        data.name = name();
        data.symbol = symbol();
        data.decimals = decimals();
        data.balance = balanceOf(account);       
        data.epochsState = epochsStates[account];
        (data.locked, data.unlocked, data.lockedEpochs) = internalBalanceOf(account, true);
	}

    function balanceOf(address account) public view override returns (uint256) {
        (,uint256 unlocked,) = internalBalanceOf(account, false);
        return super.balanceOf(account) + unlocked;
    }

    function mintedBalanceOf(address account) public view returns (uint256) {
        return ERC20Upgradeable.balanceOf(account);
    }
    
    // calculates current locked and unlocked tokens of account at current time
    // with includeEpochs return array of all user unlocked epochs
    function internalBalanceOf(address account, bool includeEpochs) public view returns (uint256 locked, uint256 unlocked, Epoch[] memory lockedEpochs) {
		EpochsState memory epochsState = epochsStates[account];   
		if (epochsState.first != 0) {
            if (includeEpochs) lockedEpochs = new Epoch[]((epochsState.last - epochsState.unlocked) / epochDuration);     

            uint idx;
            for (uint40 epochTimestamp = epochsState.unlocked; epochTimestamp < epochsState.last;) {
                epochTimestamp += epochDuration;        
                Epoch memory epoch = epochs[account][epochTimestamp];
                if (epoch.timestamp + lockDuration > block.timestamp) {
                    locked += epoch.locked - epoch.unlocked;
                } else {
                    unlocked += epoch.locked - epoch.unlocked;
                }

                if (includeEpochs) {
                    lockedEpochs[idx] = epoch;  
                    idx ++;    
                } 	         
            }     
        }		
	}

    // calculates current epoch
    function currentEpoch() public view returns (uint40) {
        return uint40(block.timestamp / epochDuration * epochDuration);
    }
    
    // ------------------------------- PUBLIC -------------------------------
        
    function flashLoan(IERC3156FlashBorrowerUpgradeable receiver, address token, uint256 amount, bytes calldata data) public override returns (bool result) {
        token = address(this);
        result = super.flashLoan(receiver, token, amount, data);                
    }
    
    // ------------------------------- MINTER -------------------------------

    function mint(address account, uint256 amount) public onlyOperator {
        _mint(account, amount);
    }

    function mintBatch(address[] calldata accounts, uint256[] calldata amounts) public onlyOperator {
        for (uint256 i = 0; i < accounts.length; i++) {
            _mint(accounts[i], amounts[i]);
        }
    }

    function lock(address account, uint256 amount) public onlyOperator {
        _nonZeroAmount(amount, true);
        _lock(account, amount);        
    }

    function use(address account, uint256 amount) public onlyOperator {
        _nonZeroAmount(amount, true);        
        require(tx.origin == account, "Not allowed");
        uint256 balance = mintedBalanceOf(account);
        
        if (amount > balance) { // if minted not enough 
            (uint256 locked, uint256 unlocked,) = internalBalanceOf(account, false); 
            require(amount <= balance + locked + unlocked, "Low total available"); 
            _unlock(account, amount - balance);            
            _burn(account, balance); 
        } else {
            _burn(account, amount);
        } 
    }

    // ------------------------------- REWARDS -------------------------------
    
    // process signup or rewards distribution
    function processRewards(RewardsData calldata rewardsData) public returns (RewardsResults[] memory results) {
        uint256 length = rewardsData.rewards.length;        
        if (length == 0) return results;
                
        if (!authority.operators(msg.sender)) {
            if (rewardsData.rewards[0].epochs.length == 0) return results; 
            require(rewardsData.chainId == authority.chainId(), "Bad chain");                                 
            address signer = ECDSAUpgradeable.recover(ECDSAUpgradeable.toEthSignedMessageHash(keccak256(abi.encode(rewardsData.rewards, rewardsData.chainId))), rewardsData.signature);
            require(authority.operators(signer), "Bad rewards signature");
        } 

        uint40 currEpoch = currentEpoch();

        results = new RewardsResults[](length);
        for (uint256 a = 0; a < length; a++) {            
            Rewards memory rewards = rewardsData.rewards[a];
            address account = rewards.account;
            EpochsState storage epochsState = epochsStates[account];
            results[a].epochs = new bool[](rewards.epochs.length);
            for (uint256 b = 0; b < rewards.epochs.length; b++) {
                uint40 epochTimestamp = rewards.epochs[b];
                if (epochTimestamp % epochDuration == 0 && 
                    epochTimestamp > epochsState.rewarded && 
                    epochTimestamp > epochsState.unlocked && 
                    epochTimestamp <= currEpoch
                ) {
                    epochsState.rewarded = epochTimestamp;
                    Epoch storage epoch = epochs[account][epochTimestamp];

                    if (epochsState.signup != 0) {
                        epoch.locked += visitReward;
                        emitEvent("FCO_VISIT_REWARD", abi.encode(account, epochTimestamp));
                    } else {
                        epochsState.signup = epochTimestamp;
                        epoch.locked += signUpReward;
                        emitEvent("FCO_SIGNUP_REWARD", abi.encode(account, epochTimestamp));
                    }

                    if (epoch.timestamp == 0) {
                        epoch.timestamp = epochTimestamp;
                    }

                    if (epochsState.first == 0) {
                        epochsState.first = epochTimestamp;
                        epochsState.unlocked = epochTimestamp - epochDuration;
                    }

                    if (epochsState.last < epochTimestamp) {
                        epochsState.last = epochTimestamp;
                    }
                    
                    results[a].epochs[b] = true;
                }              
            }
        }
    }

    // ------------------------------- APPROVE -------------------------------

    function approveWithSign(ApproveWithSignData calldata approveWithSignData) public {
        address account = approveWithSignData.data.account;
        require(tx.origin == account, "Bad tx origin for approve ws");
        require(approveWithSignRegistry[msg.sender], "Bad tx sender for approve ws");
        require(msg.sender == approveWithSignData.data.spender, "Bad spender for approve ws");
        require(approveWithSignData.data.chainId == authority.chainId(), "Bad chain");  
        
        require(!approveWithSignNonces[account][approveWithSignData.data.nonce], "Nonce already used");        
        require(ECDSAUpgradeable.recover(ECDSAUpgradeable.toEthSignedMessageHash(keccak256(abi.encode(approveWithSignData.data))), approveWithSignData.signature) == account, "Bad signature");
        approveWithSignNonces[account][approveWithSignData.data.nonce] = true;   
        _approve(account, approveWithSignData.data.spender, approveWithSignData.data.amount);   
    }

    // ------------------------------- INTERNAL -------------------------------

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {        
        _nonZeroAmount(amount, true);
                      
        if (from != address(0)) {
            uint256 unlocked = _unlock(from, 0); // unlock all possible locks first if they expired in every transfer                     
            if (unlocked != 0) _mint(from, unlocked);
        }
               
        emitEvent("FCO_TRANSFER", abi.encode(from, to, amount));
    }
    
    function _lock(address account, uint256 amount) private {
        EpochsState storage epochsState = epochsStates[account];
        uint40 currEpoch = currentEpoch();

        Epoch storage epoch = epochs[account][currEpoch];

        epoch.locked += amount;

        if (epoch.timestamp == 0) {
            epoch.timestamp = currEpoch;
        }

        if (epochsState.first == 0) {
            epochsState.first = currEpoch;
            epochsState.unlocked = currEpoch - epochDuration;
        }

        if (epochsState.last < currEpoch) {
            epochsState.last = currEpoch;
        }
      
        emitEvent("FCO_LOCK", abi.encode(account, amount));
    }
        
    function _unlock(address account, uint256 amount) private returns (uint256 unlocked) {
        EpochsState storage epochsState = epochsStates[account];
        if (epochsState.first == 0 || epochsState.unlocked == epochsState.last) return unlocked; // if no locks present skip next
       
        for (uint256 epochTimestamp = epochsState.unlocked; epochTimestamp < epochsState.last;) {
            epochTimestamp += epochDuration;
            Epoch storage epoch = epochs[account][epochTimestamp];        

            if (epoch.locked == 0) continue;

            if (amount == 0) { // if unlock amount not specified
                if (epoch.timestamp + lockDuration <= block.timestamp) { // unlock all expired locks                    
                    unlocked += epoch.locked - epoch.unlocked;  // unlock entire 
                    epoch.unlocked = epoch.locked;                    
                    epochsState.unlocked = uint40(epoch.timestamp);  // shift unlocked forward                         
                } else {
                    break;
                }
            } else { // if unlock amount requested (consumer)
                uint256 remaining = amount - unlocked; // determine remaining amount                
                if (remaining > epoch.locked - epoch.unlocked) { // if remaining amount higher then current lock amount
                    unlocked += epoch.locked - epoch.unlocked; // unlock entire 
                    epoch.unlocked = epoch.locked;
                } else {
                    epoch.unlocked += remaining; // unlock only remaining
                    break;
                }                
            }            
        }

        if (unlocked != 0) {
            emitEvent("FCO_UNLOCK", abi.encode(account, unlocked));
        }             
    }
    
    function _nonZeroAmount(uint256 amount, bool revertOnFalse) internal pure returns (bool success) {
        success = amount != 0;
        if (revertOnFalse) {
            require(success, "Zero amount");
        }         
    }

    uint256[50] private __gap;
}
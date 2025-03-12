// SPDX-License-Identifier: MIT

import "./interfaces/IERC20.sol";
import "./core/Ownable.sol";

pragma solidity ^0.8.0;

contract AvatarArtLuckyBox is Ownable{
    //BNU token
    IERC20 public bnuToken;
    
    //BNU amount is used to buy a ticket
    uint256 public ticketPrice;
    
    //Mapping the account address and their reward quantity
    mapping(address => uint256) public rewards;
    
    //Assign `ticketPrice` and `bnuToken`
    constructor(){
        ticketPrice = 10000000000000000000;     //10 BNU for a ticket
        bnuToken = IERC20(0x4954e0062E0A7668A2FE3df924cD20E6440a7b77);
    }
    
    /**
     * @dev User claims all his reward
     */ 
    function claimReward() public returns(bool){
        uint256 rewardQuantity = rewards[_msgSender()];
        require(rewardQuantity > 0, "No thing to claim");
        
        bnuToken.transfer(_msgSender(), rewardQuantity);
        
        rewards[_msgSender()] -= rewardQuantity;
        return true;
    }
    
    /**
     * @dev Owner add `rewardQuantity` for `account`
     */ 
    function addReward(address account, uint256 rewardQuantity) public onlyOwner returns(bool){
        require(account != address(0), "Zero address");
        require(rewardQuantity > 0, "No thing to add");
        
        rewards[account] += rewardQuantity;
        return true;
    }
    
    /**
     * @dev User use BNU to buy the ticket to join luckybox
     */ 
    function buyTicket() public returns(bool){
        if(ticketPrice > 0)
            bnuToken.transferFrom(_msgSender(), _owner, ticketPrice);
            
        emit TicketBought(_msgSender());
        return true;
    }
    
     /**
     * @dev Set BNU token address
     */ 
    function setBnuToken(address newAddress) public onlyOwner returns(bool){
        require(newAddress != address(0), "Zero address");
        bnuToken = IERC20(newAddress);
        return true;
    }
    
    /**
     * @dev Set ticket price by BNU quantity
     */ 
    function setTicketPrice(uint256 ticketPrice_) public onlyOwner returns(bool){
        ticketPrice = ticketPrice_;
        return true;
    }
    
    /**
     * @dev Withdraw all specific token by `tokenAddress` from contract
     */ 
    function withdrawToken(address tokenAddress) public onlyOwner returns(bool){
        require(tokenAddress != address(0), "Zero address");
        IERC20 token = IERC20(tokenAddress);
        token.transfer(_msgSender(), token.balanceOf(address(this)));
        return true;
    }
    
    //Event for broadcast when an user buy ticket
    event TicketBought(address account);
}
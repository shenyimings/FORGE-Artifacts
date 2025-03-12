//SPDX-License-Identifier:UNLICENSED
/*
S-CRO Decentralized Escrow Service
Copyright 2022 S-CRO Holdings LLC
All Rights Reserved
https://s-cro.finance
*/

pragma solidity ^0.8.0;

import "abc.sol";

contract escrow is abc {

    uint256 public mode=2; // 0:disabled; 1:claim only; 2:create and claim;
    
    uint256 public fee=0.001 ether;

    uint256 public minParentBal=1000000000; // 100,000 +4 decimals; for zero fees

    uint256 public ownerBalance=0; // BNB

    uint256 public totalRevenue=0; // BNB

    address public PARENT_CA=0xf7BcC36137eFB85320E57CCCE5C69B5B65283Ab5; // client specified

    struct envelope{
        uint256 status; // 0:cancelled; 1:holding; 2:claimed/released;
        address sender;
        address receiver;
        address token;
        uint256 amount;
        uint256 claimableAmount;
        uint256 created;
        uint256 holdTimeSec;
        uint256 closed;
    }

    uint256 public txcount=1000;

    mapping(address => bool) public feeWhitelisted;

    mapping(address => uint256[]) public userTxns;

    mapping(uint256 => envelope) public envelopes;

    mapping(address => mapping(uint256 => uint256)) public frontendStatus;

    constructor() {
        address _owner=0x1884377d1FeB3d3089884cE0947C2bf1675bf052; // client specified
        setOriginalOwner(_owner);
        feeWhitelisted[msg.sender]=true;
        feeWhitelisted[_owner]=true;
    }

    ////////////////////////////////////////////////////////////////////////////////////

    // ADMIN FUNCTIONS

    function setMode(uint256 _mode) external adminOnly {
        mode=_mode;
    }

    function setFee(uint256 _fee) external adminOnly {
        fee=_fee;
    }

    function setMinParentBal(uint256 _minParentBal) external adminOnly {
        minParentBal=_minParentBal;
    }

    function setPARENT_CA(address _PARENT_CA) external adminOnly {
        PARENT_CA=_PARENT_CA;
    }

    function addToFeeWhitelist(address _account) external adminOnly {
        feeWhitelisted[_account]=true;
    }

    function removeFromFeeWhitelist(address _account) external adminOnly {
        feeWhitelisted[_account]=false;
    }

    ////////////////////////////////////////////////////////////////////////////////////

    // CORE FUNCTIONS

    function sendEnvelope(address receiver,address token,uint256 amount,uint256 holdTimeSec,uint256 frontendID) external payable{
        // check mode
        require(mode==2,"New escrow transactions are paused.");

        // determine fee
        uint256 finalFee=fee;
        if(IERC20(PARENT_CA).balanceOf(msg.sender)>=minParentBal || feeWhitelisted[msg.sender]){
            finalFee=0;
        }

        // to send BNB supply the contract's own address as token
        bool isBNB=token==address(this)?true:false;

        // Sending BNB
        if(isBNB){
            require(msg.value>=amount+finalFee,"Insufficient value"); // fee and amount must be paid
        }

        // Sending Tokens
        if(!isBNB){
            require(msg.value>=finalFee,"Insufficient fee"); // fee must be paid
            require(IERC20(token).allowance(msg.sender,address(this))>=amount,"Insufficient allowance"); // must have sufficient allowance
            require(IERC20(token).balanceOf(msg.sender)>=amount,"Insufficient balance"); // must have sufficient token balance
        }

        // get a new txid
        txcount=math.add(txcount,1);
        uint256 txid=txcount;

        // transfer the token amount to this contract
        if(!isBNB){
            require(IERC20(token).transferFrom(msg.sender,address(this),amount),"Transfer failed.");
        }

        // store fee as revenue
        ownerBalance=math.add(ownerBalance,finalFee);
        totalRevenue=math.add(totalRevenue,finalFee);
        
        // create the envelope
        envelopes[txid]=envelope(1,msg.sender,receiver,token,amount,amount,block.timestamp,holdTimeSec,0);

        // add txid to user's transaction list
        userTxns[msg.sender].push(txid);
        if(msg.sender!=receiver)
            userTxns[receiver].push(txid);

        frontendStatus[msg.sender][frontendID]=txid;
    }

    function openEnvelope(uint256 txid,uint256 returnToSender) external {    
        // check mode
        require(mode>0,"The service is paused.");

        // check valid parties
        require(msg.sender==envelopes[txid].sender || msg.sender==envelopes[txid].receiver,"Not allowed");

        // check if already claimed or cancelled
        require(envelopes[txid].claimableAmount==envelopes[txid].amount && envelopes[txid].status==1,"Claimed, cancelled, or expired");

        // check if ready for claiming; otherwise sender can still release it
        require((block.timestamp>envelopes[txid].created+envelopes[txid].holdTimeSec)||(msg.sender==envelopes[txid].sender),"Still in holding period");

        // ensure contract has balance
        bool isBNB=envelopes[txid].token==address(this)?true:false;
        if(isBNB)
            require(address(this).balance>=envelopes[txid].amount,"Insufficient contract balance");
        if(!isBNB)
            require(IERC20(envelopes[txid].token).balanceOf(address(this))>=envelopes[txid].amount,"Insufficient token balance in contract");

        // prevent re-entrant attacks
        envelopes[txid].claimableAmount=0; // zero-out claimable
        if(returnToSender==1)
            envelopes[txid].status=0; // set cancelled status
        else
            envelopes[txid].status=2; // set sent status

        // release/return the funds
        if(isBNB){
            address payable pDest=payable(envelopes[txid].receiver);
            if(returnToSender==1) pDest=payable(envelopes[txid].sender);
            pDest.transfer(envelopes[txid].amount);
        }
        if(!isBNB){
            if(returnToSender==1)
                require(IERC20(envelopes[txid].token).transfer(envelopes[txid].sender,envelopes[txid].amount),"Transfer failed.");            
            else
                require(IERC20(envelopes[txid].token).transfer(envelopes[txid].receiver,envelopes[txid].amount),"Transfer failed.");            
        }
        
        // set date closed
        envelopes[txid].closed=block.timestamp;
    }

    function withdraw() external ownerOnly{
        require(ownerBalance!=0,"ownerBalance is 0");
        uint256 bal=ownerBalance;
        ownerBalance=0;
        address payable pOwner=payable(ownerAddress);
        pOwner.transfer(bal);
    }

    ////////////////////////////////////////////////////////////////////////////////////

    function getFee(address account) external view returns (uint256){
        if(IERC20(PARENT_CA).balanceOf(account)>=minParentBal || feeWhitelisted[account]){
            return 0;
        }
        else{
            return fee;
        }
    }

    function countRecords(address account) external view returns (uint256){
        return userTxns[account].length;
    }

    function getRecordByIndex(address account,uint256 index) external view returns (uint256 _txid,address sender,address receiver,uint256 status,address token,uint256 amount,uint256 claimableAmount,uint256 created,uint256 holdTimeSec,uint256 closed,bool isClaimable){
        uint256 txid=userTxns[account][index];
        return getRecordByTxid(txid);
    }

    function getRecordByTxid(uint256 txid) public view returns (uint256 _txid,address sender,address receiver,uint256 status,address token,uint256 amount,uint256 claimableAmount,uint256 created,uint256 holdTimeSec,uint256 closed,bool isClaimable){
        envelope memory e=envelopes[txid];
        isClaimable=(block.timestamp>e.created+e.holdTimeSec)&&(e.status==1)?true:false;
        return(txid,e.sender,e.receiver,e.status,e.token,e.amount,e.claimableAmount,e.created,e.holdTimeSec,e.closed,isClaimable);
    }

    function allowance(address token,address owner) external view returns (uint256){
        return IERC20(token).allowance(owner,address(this));
    }

    function contractBalance(address token) external view returns (uint256){
        if(token==address(this)){
            return address(this).balance;
        }
        else{
            return IERC20(token).balanceOf(address(this));
        }
    }
}




import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * Token Contract call and send Functions
*/
interface Token {
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function approveAndCall(address spender, uint tokens, bytes memory data) external returns (bool success);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/* Lock Contract Starts here */
contract WorthTokenTimeLock is Ownable{
    using SafeMath for uint256;
    
    /*
     * deposit vars
    */
    struct Items {
        address tokenAddress;
        address withdrawalAddress;
        uint256 tokenAmount;
        uint256 unlockTime;
        bool withdrawn;
    }
    
    uint256 public depositId;
    uint256[] public allDepositIds;
    mapping (address => uint256[]) public depositsByWithdrawalAddress;
    mapping (uint256 => Items) public lockedToken;
    mapping (address => mapping(address => uint256)) public walletTokenBalance;
    
    event LogWithdrawal(address SentToAddress, uint256 AmountTransferred);
    
    /* Function     : This function will Lock the token */
    /* Parameters 1 : Token address */
    /* Parameters 2 : Withdrawal address */
    /* Parameters 1 : Amount to Lock */
    /* Parameters 2 : Unlock time - UNIX Timestamp */
    /* Public View Function */
    function lockTokens (address _tokenAddress, address _withdrawalAddress, uint256 _amount, uint256 _unlockTime) public returns (uint256 _id) {
        require(_amount > 0);
        require(_unlockTime < 10000000000);
        
        //update balance in address
        walletTokenBalance[_tokenAddress][_withdrawalAddress] = walletTokenBalance[_tokenAddress][_withdrawalAddress].add(_amount);
        
        _id = ++depositId;
        lockedToken[_id].tokenAddress = _tokenAddress;
        lockedToken[_id].withdrawalAddress = _withdrawalAddress;
        lockedToken[_id].tokenAmount = _amount;
        lockedToken[_id].unlockTime = _unlockTime;
        lockedToken[_id].withdrawn = false;
        
        allDepositIds.push(_id);
        depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
        
        // transfer tokens into contract
        require(Token(_tokenAddress).transferFrom(msg.sender, address(this), _amount));
    }
    
    /* Function     : This function will Create Multiple Lock at the same time */
    /* Parameters are in [] Array Format */
    /* Parameters 1 : Token address */
    /* Parameters 2 : Withdrawal address */
    /* Parameters 1 : Amount to Lock */
    /* Parameters 2 : Unlock time - UNIX Timestamp */
    /* Public View Function */
    function createMultipleLocks (address _tokenAddress, address _withdrawalAddress, uint256[] memory _amounts, uint256[] memory _unlockTimes) public returns (uint256 _id) {
        require(_amounts.length > 0);
        require(_amounts.length == _unlockTimes.length);
        
        uint256 i;
        for(i=0; i<_amounts.length; i++){
            require(_amounts[i] > 0);
            require(_unlockTimes[i] < 10000000000);
            
            //update balance in address
            walletTokenBalance[_tokenAddress][_withdrawalAddress] = walletTokenBalance[_tokenAddress][_withdrawalAddress].add(_amounts[i]);
            
            _id = ++depositId;
            lockedToken[_id].tokenAddress = _tokenAddress;
            lockedToken[_id].withdrawalAddress = _withdrawalAddress;
            lockedToken[_id].tokenAmount = _amounts[i];
            lockedToken[_id].unlockTime = _unlockTimes[i];
            lockedToken[_id].withdrawn = false;
            
            allDepositIds.push(_id);
            depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
            
            //transfer tokens into contract
            require(Token(_tokenAddress).transferFrom(msg.sender, address(this), _amounts[i]));
        }
    }
    
    /* Function     : This function will Extend the lock duration of the Locked tokens */
    /* Parameters 1 : Lock ID */
    /* Parameters 2 : Unlock Time - in UNIX Timestamp */
    /* Public Function */
    function extendLockDuration (uint256 _id, uint256 _unlockTime) public {
        require(_unlockTime < 10000000000);
        require(!lockedToken[_id].withdrawn);
        require(msg.sender == lockedToken[_id].withdrawalAddress);
        
        //set new unlock time
        lockedToken[_id].unlockTime = _unlockTime;
    }
    
    /* Function     : This function will transfer the lock to another wallet address */
    /* Parameters 1 : Lock ID */
    /* Parameters 2 : New Recievers wallet Address */
    /* Public Function */
    function transferLocks (uint256 _id, address _receiverAddress) public {
        require(!lockedToken[_id].withdrawn);
        require(msg.sender == lockedToken[_id].withdrawalAddress);
        
        //decrease sender's token balance
        walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender] = walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender].sub(lockedToken[_id].tokenAmount);
        
        //increase receiver's token balance
        walletTokenBalance[lockedToken[_id].tokenAddress][_receiverAddress] = walletTokenBalance[lockedToken[_id].tokenAddress][_receiverAddress].add(lockedToken[_id].tokenAmount);
        
        //remove this id from sender address
        uint256 j;
        uint256 arrLength = depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length;
        for (j=0; j<arrLength; j++) {
            if (depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] == _id) {
                depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] = depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][arrLength - 1];
                depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].pop();
                break;
            }
        }
        
        //Assign this id to receiver address
        lockedToken[_id].withdrawalAddress = _receiverAddress;
        depositsByWithdrawalAddress[_receiverAddress].push(_id);
    }
    
    /* Function     : This function will withdraw the tokens once lock time is reached */
    /* Parameters   : Lock ID */
    /* Public Function */
    function withdrawTokens (uint256 _id) public {
        require(block.timestamp >= lockedToken[_id].unlockTime);
        require(msg.sender == lockedToken[_id].withdrawalAddress);
        require(!lockedToken[_id].withdrawn);
        
        lockedToken[_id].withdrawn = true;
        
        //update balance in address
        walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender] = walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender].sub(lockedToken[_id].tokenAmount);
        
        //remove this id from this address
        uint256 j;
        uint256 arrLength = depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length;
        for (j=0; j<arrLength; j++) {
            if (depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] == _id) {
                depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] = depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][arrLength - 1];
                depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].pop();
                break;
            }
        }
        
        // transfer tokens to wallet address
        require(Token(lockedToken[_id].tokenAddress).transfer(msg.sender, lockedToken[_id].tokenAmount));
        emit LogWithdrawal(msg.sender, lockedToken[_id].tokenAmount);
    }

    /* Function     : This function will total balance of token inside contract */
    /* Parameters   : Token address */
    /* Public View Function */
    function getTotalTokenBalance (address _tokenAddress) view public returns (uint256)
    {
       return Token(_tokenAddress).balanceOf(address(this));
    }
    
    /* Function     : This function will return Token Locked by the user */
    /* Parameters 1 : Token address */
    /* Parameters 2 : Withdrawal address */
    /* Public View Function */
    function getTokenBalanceByAddress (address _tokenAddress, address _walletAddress) view public returns (uint256)
    {
       return walletTokenBalance[_tokenAddress][_walletAddress];
    }
    
    /* Function     : This function will return all Lock ID details */
    /* Parameters   : -- */
    /* Public View Function */
    function getAllDepositIds() view public returns (uint256[] memory)
    {
        return allDepositIds;
    }
    
    /* Function     : This function will return Lock details */
    /* Parameters   : ID of the Lock */
    /* Public View Function */
    function getDepositDetails (uint256 _id) view public returns (address _tokenAddress, address _withdrawalAddress, uint256 _tokenAmount, uint256 _unlockTime, bool _withdrawn)
    {
        return(lockedToken[_id].tokenAddress,lockedToken[_id].withdrawalAddress,lockedToken[_id].tokenAmount,
        lockedToken[_id].unlockTime,lockedToken[_id].withdrawn);
    }
    
    /* Function     : This function will return Lock details */
    /* Parameters   : Withdrawal address */
    /* Public View Function */
    function getDepositsByWithdrawalAddress (address _withdrawalAddress) view public returns (uint256[] memory)
    {
        return depositsByWithdrawalAddress[_withdrawalAddress];
    }
}

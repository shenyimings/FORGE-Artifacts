// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./StakingToken.sol";
import "./GovernanceToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


/**
 * @title Staking 
 * @dev To facilitate staking of AUDT tokens.
 * Participants can stake their AUDT tokens during the period specified in 
 * the constructor _stakingDateStart and _stakingDateEnd
 * Contract will issue one staking token for each AUDT Token staked
 * Contract will burn all redeemed staking tokens upon redemption
 * Staking is prohibited in all block heights following the block height 
 * of the initiation of the staking period
 * Contract will eliminate staking rewards for redemptions made during the staking period
 */
contract Staking is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    mapping(address => uint256) public deposits;        //track deposits per user
    mapping(address => uint256) public released;        //track redeemed deposits per user
    mapping(address => uint256) public cancelled;       //track cancelled deposits per user
    mapping(address => bool) public blacklistedAddress; //store addresses not eligible for staking

    uint256 public totalReleased;                       //track total number of redeemed deposits
    uint256 public totalCancelled;                      //track total number of cancelled deposits
    uint256 public stakedAmount;                        //total number of staked tokens    
    IERC20 private _auditToken;                         //AUDT token 
    GovernanceToken private _governanceToken;           //Governance token 
    uint256 public governanceTokenRatio;                //Governance token ratio
    uint256 public stakingDateStart;                    //Staking date start
    uint256 public stakingDateEnd;                      //Staking date end
    uint256 public totalReward;                         //Total reward available
    StakingToken private _stakingToken;                 //staking token address

    
    ///@dev Emitted when when staking token is issued
    event LogStakingTokensIssued(address indexed to, uint256 amount);

    ///@dev Emitted when when deposit is received
    event LogDepositReceived(address indexed from, uint amount);

    ///@dev Emitted when staking tokens are returned
    event LogStakingTokenReturned(address indexed from, uint amount);

    ///@dev Emitted when reward has been delivered
    event LogRewardDelivered(address indexed from, uint256 amount);

    ///@dev Emitted when deposit is withdrawn before end of staking
    event LogDepositCancelled(address indexed from, uint256 amount);

    ///@dev Emitted when address is entered into blacklist
    event LogBlacklisted(address indexed to);

    ///@dev Emitted when unauthorized tokens are refunded
    event LogUnauthorizedTokensReturn(address indexed to, address token, uint256 amount);

    ///@dev Emitted when redeem has complete
    event LogTokensRedeemed(address indexed to, uint256 amount);

    /**
     * @dev Sets the below variables 
     * @param _auditTokenAddress - address of the AUDT token
     * @param _governanceTokenAddress - address of the governance token
     * @param _stakingDateStart - date staking starts
     * @param _stakingDateEnd - date staking ends
     * @param _totalReward - amount of rewards to be sent to contract after staking ended
     */
    constructor(IERC20 _auditTokenAddress, 
                GovernanceToken _governanceTokenAddress, 
                uint256 _stakingDateStart, 
                uint256 _stakingDateEnd, 
                uint256 _totalReward,
                uint256 _govTokenRatio) public {

        require(_stakingDateEnd != 0, "Staking:constructor - Staking end date can't be 0" );
        require(_stakingDateStart != 0, "Staking:constructor - Staking start date can't be 0" );
        require(_govTokenRatio != 0, "Staking:constructor - Governance token ratio can't be 0");
        require(_auditTokenAddress != IERC20(0), "Staking:constructor - Audit token address can't be 0");
        require(_governanceTokenAddress != GovernanceToken(0), "Staking:constructor - Governance token address can't be 0");
        require(_totalReward < 2**238 -1 , "The reward is too high");  // max uint256 subtracted with 18 digits to accommodate
                                                                       // for multiplications in later code. 
        require(_govTokenRatio <= 10**17 , "The ratio is too high");   // largest gov token ratio in 4 capsule

        _auditToken = _auditTokenAddress;
        stakingDateStart = _stakingDateStart;
        stakingDateEnd = _stakingDateEnd;
        totalReward =  _totalReward;
        _governanceToken = _governanceTokenAddress;
        governanceTokenRatio = _govTokenRatio;

    }

     /**
     * @dev Function to store addresses exempt from staking
     * @param blacklisted - array of addresses to enter    
     */
    function blacklistAddresses(address[] memory blacklisted) public onlyOwner() {

        uint256 length = blacklisted.length;

        for (uint256 i = 0; i < length; i++) {
           blacklistedAddress[ blacklisted[i]] = true;
           LogBlacklisted(blacklisted[i]);
        }
        
    }

     /**
     * @dev Function to manually update staking periods
     * @param _stakingDateStart - start date of staking
     * @param _stakingDateEnd - end date of staking    
     */
    function updateStakingPeriods(uint256 _stakingDateStart, uint256 _stakingDateEnd) public onlyOwner() {

        require(_stakingDateEnd != 0, "Staking:constructor - Staking end date can't be 0" );
        require(_stakingDateStart != 0, "Staking:constructor - Staking start date can't be 0" );
        require(_stakingDateStart > block.number, "Staking:constructor - Staking date start can't be less than current block");
        require(_stakingDateEnd > _stakingDateStart, "Staking:constructor - Staking date end can't be less than Staking date start");
        stakingDateStart = _stakingDateStart;
        stakingDateEnd = _stakingDateEnd;

    }

    /**
     * @dev Function to manually return tokens which were send directly to the contract
     * @param token - address of the token
     * @param recipient - address of recipient
     * @param amount - amount refunded   
     */
    function returnUnauthorizedTokens(address token, address recipient, uint256 amount) public onlyOwner() {
       
        // ensure that only extra tokens can be returned.
        
        if (address(token) == address(_auditToken))
            require(_auditToken.balanceOf(address(this)).sub(amount)  >= totalReward.add(stakedAmount).sub(totalReleased), "Staking:returnUnauthorizedtokens - You are refunding more than available. ");
        IERC20(token).transfer(recipient, amount);
        LogUnauthorizedTokensReturn(recipient, token, amount);
    }

    /**
     * @dev Function to return earning ratio 
     * @return number representing earning ratio with precision to 18 decimal values       
     */
    function returnEarningRatio() public view returns (uint256) {

        if (stakedAmount == 0)
            return totalReward; // At this stage there is no contributions
         else
            return (totalReward.mul(1e18) / stakedAmount) + 1e18 ;
    }

     /**
     * @dev Function to return earning ratio per given amount
     * @param amount - amount in question   
     * @return number representing earning ratio for given amount       
     */
    function returnEarningsPerAmount(uint256 amount) public view returns(uint256) {

        return (amount.mul(returnEarningRatio())).div(1e18);
    }

    /**
     * @dev Function to send reward amount to the contract 
     * @param amount of AUDT tokens       
     */
    function fundStaking(uint256 amount) public onlyOwner(){

        require(amount == totalReward, "Staking:fundStaking - The amount of tokens sent doesn't match amount declared:");

        _auditToken.safeTransferFrom(msg.sender, address(this), amount);
        // totalReward += amount;
        emit LogDepositReceived(msg.sender, amount);
    }

    /**
     * @dev Function to set the staking token address 
     * @param stakingTokenAddress address of staking token
     */
    function updateStakingTokenAddress(StakingToken stakingTokenAddress) public onlyOwner() {

        require(address(stakingTokenAddress) != address(0), "Staking Token address can't be 0");

        _stakingToken = stakingTokenAddress;

    }

    /**
     * @dev Function to accept contribution to staking
     * @param amount number of AUDT tokens sent to contract for staking     
     */

    function stake(uint256 amount) public {

        require(amount >= 100e18, "Staking:stake - Minimum contribution amount is 100 AUDT tokens");
        require(stakingDateStart >= block.number, "Staking:stake - deposit period ended. ");      
        require(blacklistedAddress[msg.sender] == false, "This address has been blacklisted");
        stakedAmount = stakedAmount.add(amount);  // track tokens contributed so far
        _receiveDeposit(amount);
        _deliverStakingTokens( amount);
        emit LogStakingTokensIssued(msg.sender, amount);
    }
    

    /**
     * @dev Function to receive and process deposits called from stake() function
     * @param amount number of tokens deposited
     */
    function _receiveDeposit(uint amount) internal  {      

        _auditToken.safeTransferFrom(msg.sender, address(this), amount);
        deposits[msg.sender] = deposits[msg.sender].add(amount);
        emit LogDepositReceived(msg.sender, amount);
    }

   

     /**
     * @dev Function to deliver staking tokens upon receipt of deposit called from stake() function
     * @param amount number of tokens issued
     */
    function _deliverStakingTokens(uint256 amount) internal {
        _stakingToken.mint(msg.sender, amount);
    }


    /**
     * @dev Function to deliver governance tokens called from _deliverRewards function
     * @param amount number of tokens to be issued
     */
    function _deliverGovernanceToken(uint256 amount) internal {

        _governanceToken.mint(msg.sender, amount);
    }
  
     /**
     * @dev Function to redeem contribution. Based on the staking period function may send rewards or just deposit. 
     * If user redeems after staking ended, reward will be added to deposit. If staking is still in progress, 
     * user only receives amount contributed.
     * @param amount number of tokens being redeemed
     */
    function redeem(uint256 amount) public {

        require(_stakingToken.balanceOf(msg.sender) >= amount, "Staking:redeem - you are claiming more than your balance.");    
        _burnStakedToken(amount);

        if (block.number > stakingDateEnd){
            _deliverRewards(amount);       
            emit LogTokensRedeemed(msg.sender, returnEarningsPerAmount(amount));            
        } 
        else{
            _returnDeposit(amount);
            emit LogTokensRedeemed(msg.sender, amount);
        }
    }

     /**
     * @dev Function to burn staking tokens after redeeming 
     * @param amount number of tokens to burn
     */
    function _burnStakedToken(uint256 amount) internal {

        _stakingToken.burn(msg.sender, amount);
        LogStakingTokenReturned(msg.sender, amount);
    }

     /**
     * @dev Function to deliver rewards called from redeem() function
     * @param amount number of tokens to deliver (token originally deposited + staking rewards)
     */
    function _deliverRewards(uint256 amount) internal {

        uint256 amountRedeemed;
        
        amountRedeemed = returnEarningsPerAmount(amount);
        released[msg.sender] = released[msg.sender].add(amountRedeemed);
        totalReleased = totalReleased.add(amountRedeemed);
        _auditToken.safeTransfer(msg.sender, amountRedeemed);
        _deliverGovernanceToken((governanceTokenRatio.mul(amount)).div(1e18));
        LogRewardDelivered(msg.sender, amountRedeemed);
    }

     /**
     * @dev Function to return deposit in case user requests before the end of staking period. 
     * @param amount number of tokens to return 
     */
    function _returnDeposit(uint256 amount) internal {

        cancelled[msg.sender] = cancelled[msg.sender].add(amount);
        stakedAmount = stakedAmount.sub(amount);
        totalCancelled = totalCancelled.add(amount);
        _auditToken.safeTransfer(msg.sender, amount);
        LogDepositCancelled(msg.sender, amount);
    }
}
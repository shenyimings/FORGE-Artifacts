// SPDX-License-Identifier: agpl-3.0

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License


pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Interfaces.sol";
 
contract Campaign {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    address public factory;
    address public campaignOwner;
    address public token;
    uint256 public softCap;            
    uint256 public hardCap;  
    uint256 public tokenSalesQty;
    uint256 public feePcnt;
    uint256 public qualifyingTokenQty;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public midDate;         // Start of public sales for WhitelistedFirstThenEveryone type
    uint256 public minBuyLimit;            
    uint256 public maxBuyLimit;    
    
    // Liquidity
    uint256 public lpBnbQty;    
    uint256 public lpTokenQty;
    uint256 public lpLockDuration; 
    uint256[2] private lpInPool; // This is the actual LP provided in pool.
    bool private recoveredUnspentLP;
    
    // Config
    bool public burnUnSold;    
   
    // Misc variables //
    uint256 public unlockDate;
    uint256 public collectedBNB;
    uint256 public lpTokenAmount;

    // States
    bool public tokenFunded;        
    bool public finishUpSuccess; 
    bool public liquidityCreated;
    bool public cancelled;          

   // Token claiming by users
    mapping(address => bool) public claimedRecords; 
    bool public tokenReadyToClaim;    

    // Map user address to amount invested in BNB //
    mapping(address => uint256) public participants; 
    uint256 public numOfParticipants;

    address public constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    // Whitelisting support
    enum Accessibility {
        Everyone, 
        WhitelistedOnly, 
        WhitelistedFirstThenEveryone
    }
    Accessibility public accessibility;
    uint256 public numOfWhitelisted;
    mapping(address => bool) public whitelistedMap;
    

    // Vesting Feature Support
    uint256 internal constant PERCENT100 = 1e6;

    struct VestingInfo {
        uint256[]  periods;
        uint256[]  percents;
        uint256 totalVestedBnb;
        uint256 startTime;
        bool enabled;
        bool vestingTimerStarted;
    }
    VestingInfo public vestInfo;
    mapping(address=>mapping(uint256=>bool)) investorsClaimMap;
    mapping(uint256=>bool) campaignOwnerClaimMap;


    // Events
    event Purchased(
        address indexed user,
        uint256 timeStamp,
        uint256 amountBnb,
        uint256 amountToken
    );

    event LiquidityAdded(
        uint256 amountBnb,
        uint256 amountToken,
        uint256 amountLPToken
    );

    event LiquidityLocked(
        uint256 timeStampStart,
        uint256 timeStampExpiry
    );

    event LiquidityWithdrawn(
        uint256 amount
    );

    event TokenClaimed(
        address indexed user,
        uint256 timeStamp,
        uint256 amountToken
    );

    event Refund(
        address indexed user,
        uint256 timeStamp,
        uint256 amountBnb
    );

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can call");
        _;
    }

    modifier onlyCampaignOwner() {
        require(msg.sender == campaignOwner, "Only campaign owner can call");
        _;
    }

    modifier onlyFactoryOrCampaignOwner() {
        require(msg.sender == factory || msg.sender == campaignOwner, "Only factory or campaign owner can call");
        _;
    }

    constructor() public{
        factory = msg.sender;
    }
    
    /**
     * @dev Initialize  a new campaign.
     * @notice - Access control: External. Can only be called by the factory contract.
     */
    function initialize
    (
        address _token,
        address _campaignOwner,
        uint256[5] calldata _stats,  
        uint256[3] calldata _dates, 
        uint256[2] calldata _buyLimits,    
        Campaign.Accessibility _access,  
        uint256[3] calldata _liquidity, 
        bool _burnUnSold
    ) external
    {
        require(msg.sender == factory,'Only factory allowed to initialize');
        token = _token;
        campaignOwner = _campaignOwner; 
        softCap = _stats[0];
        hardCap = _stats[1];
        tokenSalesQty = _stats[2];
        feePcnt = _stats[3];
        qualifyingTokenQty = _stats[4];
        startDate = _dates[0];
        endDate = _dates[1];
        midDate = _dates[2];
        minBuyLimit = _buyLimits[0];
        maxBuyLimit = _buyLimits[1];
        accessibility = _access;
        lpBnbQty = _liquidity[0];
        lpTokenQty = _liquidity[1];
        lpLockDuration = _liquidity[2];
        burnUnSold = _burnUnSold;
    }
    
    /**
     * @dev Allows campaign owner to fund in his token.
     * @notice - Access control: External, OnlyCampaignOwner
     */
    function fundIn() external onlyCampaignOwner {
        require(!tokenFunded, "Campaign is already funded");
        uint256 amt = getCampaignFundInTokensRequired();
        require(amt > 0, "Invalid fund in amount");

        tokenFunded = true;
        ERC20(token).safeTransferFrom(msg.sender, address(this), amt);  
    }

    // In case of a "cancelled" campaign, or softCap not reached, 
    // the campaign owner can retrieve back his funded tokens.
    function fundOut() external onlyCampaignOwner {
        require(failedOrCancelled(), "Only failed or cancelled campaign can un-fund");

        ERC20 ercToken = ERC20(token);
        uint256 totalTokens = ercToken.balanceOf(address(this));
        sendTokensTo(campaignOwner, totalTokens);
        tokenFunded = false;
    }

    /**
     * @dev Allows user to buy token.
     * @notice - Access control: Public
     */
    function buyTokens() public payable {
        
        require(isLive(), "Campaign is not live");
        require(checkQualifyingTokens(msg.sender), "Insufficient LAUNCH tokens to qualify"); 
        require(checkWhiteList(msg.sender), "You are not whitelisted");

        // Check for min purchase amount
        require(msg.value >= minBuyLimit, "Less than minimum purchase amount");

        // Check for over purchase
        uint256 invested =  participants[msg.sender];
        require(invested.add(msg.value) <= maxBuyLimit, "Exceeded max amount"); 
        require(msg.value <= getRemaining(),"Insufficent token left");

        uint256 buyAmt = calculateTokenAmount(msg.value);
        
        if (invested == 0) {
            numOfParticipants = numOfParticipants.add(1);
        }

        participants[msg.sender] = participants[msg.sender].add(msg.value);
        collectedBNB = collectedBNB.add(msg.value);

        emit Purchased(msg.sender, block.timestamp, msg.value, buyAmt);
    }

    /**
     * @dev Add liquidity and lock it up. Called after a campaign has ended successfully.
     * @notice - Access control: Public. onlyFactoryOrCampaignOwner. This allows the admin or campaignOwner to
     * coordinate the adding of LP when all campaigns are completed. This ensure a fairer arrangement, esp
     * when multiple campaigns are running in parallel.
     */
    function addAndLockLP() external onlyFactoryOrCampaignOwner {

        require(!isLive(), "Presale is still live");
        require(!failedOrCancelled(), "Presale failed or cancelled , can't provide LP");
        require(softCap <= collectedBNB, "Did not reach soft cap");

        if ((lpBnbQty > 0 && lpTokenQty > 0) && !liquidityCreated) {
        
            liquidityCreated = true;

            IFactoryGetters fact = IFactoryGetters(factory);
            address lpRouterAddress = fact.getLpRouter();
            require(ERC20(address(token)).approve(lpRouterAddress, lpTokenQty)); // Uniswap doc says this is required //
 
            (uint256 retTokenAmt, uint256 retBNBAmt, uint256 retLpTokenAmt) = IUniswapV2Router02(lpRouterAddress).addLiquidityETH
                {value : lpBnbQty}
                (address(token),
                lpTokenQty,
                0,
                0,
                address(this),
                block.timestamp + 100000000);
            
            lpTokenAmount = retLpTokenAmt;
            lpInPool[0] = retBNBAmt;
            lpInPool[1] = retTokenAmt;

            emit LiquidityAdded(retBNBAmt, retTokenAmt, retLpTokenAmt);
            
            unlockDate = (block.timestamp).add(lpLockDuration);
            emit LiquidityLocked(block.timestamp, unlockDate);
        }
    }

    /**
     * @dev Get the actual liquidity added to LP Pool
     * @return - uint256[2] consist of BNB amount, Token amount.
     * @notice - Access control: Public, View
     */
    function getPoolLP() external view returns (uint256, uint256) {
        return (lpInPool[0], lpInPool[1]);
    }

    /**
     * @dev There are situations that the campaign owner might call this.
     * @dev 1: Pancakeswap pool SC failure when we call addAndLockLP().
     * @dev 2: Pancakeswap pool already exist. After we provide LP, thee's some excess bnb/tokens
     * @dev 3: Campaign owner decided to change LP arrangement after campaign is successful.
     * @dev In that case, campaign owner might recover it and provide LP manually.
     * @dev Note: This function can only be called once by factory, as this is not a normal workflow.
     * @notice - Access control: External, onlyFactory
     */
    function recoverUnspentLp() external onlyFactory {
        
        require(!recoveredUnspentLP, "You have already recovered unspent LP");
        recoveredUnspentLP = true;

        uint256 bnbAmt;
        uint256 tokenAmt;

        if (liquidityCreated) {
            // Find out any excess bnb/tokens after LP provision is completed.
            bnbAmt = lpBnbQty.sub(lpInPool[0]);
            tokenAmt = lpTokenQty.sub(lpInPool[1]);
        } else {
            // liquidity not created yet. Just returns the full portion of the planned LP
            // Only finished success campaign can recover Unspent LP
            require(finishUpSuccess, "Campaign not finished successfully yet");
            bnbAmt = lpBnbQty;
            tokenAmt = lpTokenQty;
        }

        // Return bnb, token if any
        if (bnbAmt > 0) {
            (bool ok, ) = campaignOwner.call{value: bnbAmt}("");
            require(ok, "Failed to return BNB Lp");
        }

        if (tokenAmt > 0) {
            ERC20(token).safeTransfer(campaignOwner, tokenAmt);
        }
    }

    /**
     * @dev When a campaign reached the endDate, this function is called.
     * @dev Add liquidity to uniswap and burn the remaining tokens.
     * @dev Can be only executed when the campaign completes.
     * @dev Anyone can call. Only called once.
     * @notice - Access control: Public
     */
    function finishUp() external {
       
        require(!finishUpSuccess, "finishUp is already called");
        require(!isLive(), "Presale is still live");
        require(!failedOrCancelled(), "Presale failed or cancelled , can't call finishUp");
        require(softCap <= collectedBNB, "Did not reach soft cap");
        finishUpSuccess = true;

        uint256 feeAmt = getFeeAmt(collectedBNB);
        uint256 unSoldAmtBnb = getRemaining();
        uint256 remainBNB = collectedBNB.sub(feeAmt);
        
        // If lpBnbQty, lpTokenQty is 0, we won't provide LP.
        if ((lpBnbQty > 0 && lpTokenQty > 0)) {
            remainBNB = remainBNB.sub(lpBnbQty);
        }
        
        // Send fee to fee address
        if (feeAmt > 0) {
            (bool sentFee, ) = getFeeAddress().call{value: feeAmt}("");
            require(sentFee, "Failed to send Fee to platform");
        }

        // Send remain bnb to campaign owner if not in vested Mode
        if (!vestInfo.enabled) {
            (bool sentBnb, ) = campaignOwner.call{value: remainBNB}("");
            require(sentBnb, "Failed to send remain BNB to campaign owner");
        } else {
            vestInfo.totalVestedBnb = remainBNB;
        }

        // Calculate the unsold amount //
        if (unSoldAmtBnb > 0) {
            uint256 unsoldAmtToken = calculateTokenAmount(unSoldAmtBnb);
            // Burn or return UnSold token to owner 
            sendTokensTo(burnUnSold ? BURN_ADDRESS : campaignOwner, unsoldAmtToken);  
        }     
    }


    /**
     * @dev Allow either Campaign owner or Factory owner to call this
     * @dev to set the flag to enable token claiming.
     * @dev This is useful when 1 project has multiple campaigns that
     * @dev to sync up the timing of token claiming After LP provision.
     * @notice - Access control: External,  onlyFactoryOrCampaignOwner
     */
    function setTokenClaimable() external onlyFactoryOrCampaignOwner {
        
        require(finishUpSuccess, "Campaign not finished successfully yet");

        // Token is only claimable in non-vested mode
        require(!vestInfo.enabled, "Not applicable to vested mode");

        tokenReadyToClaim = true;
    }

    /**
     * @dev Allow users to claim their tokens. 
     * @notice - Access control: External
     */
    function claimTokens() external {

        require(tokenReadyToClaim, "Tokens not ready to claim yet");
        require( claimedRecords[msg.sender] == false, "You have already claimed");
        
        uint256 amtBought = getTotalTokenPurchased(msg.sender);
        if (amtBought > 0) {
            claimedRecords[msg.sender] = true;
            ERC20(token).safeTransfer(msg.sender, amtBought);
            emit TokenClaimed(msg.sender, block.timestamp, amtBought);
        }
    }

     /**
     * @dev Allows campaign owner to withdraw LP after the lock duration.
     * @dev Only able to withdraw LP if lockActivated and lock duration has expired.
     * @dev Can call multiple times to withdraw a portion of the total lp.
     * @param _lpToken - The LP token address
     * @notice - Access control: Internal, OnlyCampaignOwner
     */
    function withdrawLP(address _lpToken,uint256 _amount) external onlyCampaignOwner 
    {
        require(liquidityCreated, "liquidity is not yet created");
        require(block.timestamp >= unlockDate ,"Unlock date not reached");
        
        ERC20(_lpToken).safeTransfer(msg.sender, _amount);
        emit LiquidityWithdrawn( _amount);
    }

    /**
     * @dev Allows Participants to withdraw/refunds when campaign fails
     * @notice - Access control: Public
     */
    function refund() external {
        require(failedOrCancelled(),"Can refund for failed or cancelled campaign only");

        uint256 investAmt = participants[msg.sender];
        require(investAmt > 0 ,"You didn't participate in the campaign");

        participants[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: investAmt}("");
        require(ok, "Failed to refund BNB to user");

        if (numOfParticipants > 0) {
            numOfParticipants -= 1;
        }

        emit Refund(msg.sender, block.timestamp, investAmt);
    }

    /**
     * @dev To calculate the total token amount based on user's total invested BNB
     * @param _user - The user's wallet address
     * @return - The total amount of token
     * @notice - Access control: Public
     */
     function getTotalTokenPurchased(address _user) public view returns (uint256) {
        uint256 investAmt = participants[_user];
        return calculateTokenAmount(investAmt);
    }

    // Whitelisting Support 
    /**
     * @dev Allows campaign owner to append to the whitelisted addresses.
     * @param _addresses - Array of addresses
     * @notice - Access control: Public, OnlyCampaignOwner
     */
    function appendWhitelisted(address[] memory _addresses) external onlyFactory {
        uint256 len = _addresses.length;
        for (uint256 n=0; n<len; n++) {
            address a = _addresses[n];
            if (whitelistedMap[a] == false) {
                whitelistedMap[a] = true;
                numOfWhitelisted = numOfWhitelisted.add(1);
            }
        }
    }

    /**
     * @dev Allows campaign owner to remove from the whitelisted addresses.
     * @param _addresses - Array of addresses
     * @notice - Access control: Public, OnlyCampaignOwner
     */
    function removeWhitelisted(address[] memory _addresses) external onlyFactory {
        uint256 len = _addresses.length;
        for (uint256 n=0; n<len; n++) {
            address a = _addresses[n];
            if (whitelistedMap[a] == true) {
                whitelistedMap[a] = false;
                numOfWhitelisted = numOfWhitelisted.sub(1);
            }
        }
    }

    /**
     * @dev To check whether this address has accessibility to buy token
     * @param _address - The user's wallet address
     * @return - A bool value
     * @notice - Access control: Internal
     */
    function checkWhiteList(address _address) public view returns(bool){
        if (accessibility == Accessibility.Everyone) {
            return true;
        }
        
        // Either WhitelistedOnly or WhitelistedFirstThenEveryone
        bool ok = whitelistedMap[_address];
        if (accessibility == Accessibility.WhitelistedOnly) {
            return ok;
        } else {
            return (ok || block.timestamp >= midDate);
        }
    }
  
    // Helpers //
    /**
     * @dev To send all XYZ token to either campaign owner or burn address when campaign finishes or cancelled.
     * @param _to - The destination address
     * @param _amount - The amount to send
     * @notice - Access control: Internal
     */
    function sendTokensTo(address _to, uint256 _amount) internal {

        // Security: Can only be sent back to campaign owner or burned //
        require((_to == campaignOwner)||(_to == BURN_ADDRESS), "Can only be sent to campaign owner or burn address");

         // Burn or return UnSold token to owner 
        ERC20 ercToken = ERC20(token);
        ercToken.safeTransfer(_to, _amount);
    } 
     
    /**
     * @dev To calculate the amount of fee in BNB
     * @param _amt - The amount in BNB
     * @return - The amount of fee in BNB
     * @notice - Access control: Internal
     */
    function getFeeAmt(uint256 _amt) internal view returns (uint256) {
        return _amt.mul(feePcnt).div(1e6);
    }

    /**
     * @dev To get the fee address
     * @return - The fee address
     * @notice - Access control: Internal
     */
    function getFeeAddress() internal view returns (address) {
        IFactoryGetters fact = IFactoryGetters(factory);
        return fact.getFeeAddress();
    }

    /**
     * @dev To check whether the campaign failed (softcap not met) or cancelled
     * @return - Bool value
     * @notice - Access control: Public
     */
    function failedOrCancelled() public view returns(bool) {
        if (cancelled) return true;
        
        return (block.timestamp >= endDate) && (softCap > collectedBNB) ;
    }

    /**
     * @dev To check whether the campaign is isLive? isLive means a user can still invest in the project.
     * @return - Bool value
     * @notice - Access control: Public
     */
    function isLive() public view returns(bool) {
        if (!tokenFunded || cancelled) return false;
        if((block.timestamp < startDate)) return false;
        if((block.timestamp >= endDate)) return false;
        if((collectedBNB >= hardCap)) return false;
        return true;
    }

    /**
     * @dev Calculate amount of token receivable.
     * @param _bnbInvestment - Amount of BNB invested
     * @return - The amount of token
     * @notice - Access control: Public
     */
    function calculateTokenAmount(uint256 _bnbInvestment) public view returns(uint256) {
        return _bnbInvestment.mul(tokenSalesQty).div(hardCap);
    }
    

    /**
     * @dev Gets remaining BNB to reach hardCap.
     * @return - The amount of BNB.
     * @notice - Access control: Public
     */
    function getRemaining() public view returns (uint256){
        return (hardCap).sub(collectedBNB);
    }

    /**
     * @dev Set a campaign as cancelled.
     * @dev This can only be set before tokenReadyToClaim, finishUpSuccess, liquidityCreated .
     * @dev ie, the users can either claim tokens or get refund, but Not both.
     * @notice - Access control: Public, OnlyFactory
     */
    function setCancelled() onlyFactory external {

        // If we are in VestingMode, then we should be able to cancel even if finishUp() is called 
        if (vestInfo.enabled && !vestInfo.vestingTimerStarted)
        {
            cancelled = true;
            return;
        }

        require(!tokenReadyToClaim, "Too late, tokens are claimable");
        require(!finishUpSuccess, "Too late, finishUp called");
        require(!liquidityCreated, "Too late, Lp created");

        cancelled = true;
    }

    /**
     * @dev Calculate and return the Token amount need to be deposit by the project owner.
     * @return - The amount of token required
     * @notice - Access control: Public
     */
    function getCampaignFundInTokensRequired() public view returns(uint256) {
        return tokenSalesQty.add(lpTokenQty);
    }


    /**
     * @dev Check whether the user address has enough Launcher Tokens to participate in project.
     * @param _user - The address of user
     * @return - Bool result
     * @notice - Access control: External
     */  
    function checkQualifyingTokens(address _user) public  view returns(bool) {

        if (qualifyingTokenQty == 0) {
            return true;
        }

        IFactoryGetters fact = IFactoryGetters(factory);
        address launchToken = fact.getLauncherToken();
        
        IERC20 ercToken = IERC20(launchToken);
        uint256 balance = ercToken.balanceOf(_user);
        return (balance >= qualifyingTokenQty);
    }


    // Vesting feature support
    /**
     * @dev Setup and turn on the vesting feature
     * @param _periods - Array of period of the vesting.
     * @param _percents - Array of percents release of the vesting.
     * @notice - Access control: External. onlyFactory.
     */  
    function setupVestingMode(uint256[] calldata _periods, uint256[] calldata _percents) external onlyFactory {
        uint256 len = _periods.length;
        require(len>0, "Invalid length");
        require(len == _percents.length, "Wrong ranges");

        // check that all percentages should add up to 100% //
        // 100% is 1e6
        uint256 totalPcnt;
        for (uint256 n=0; n<len; n++) {
            totalPcnt = totalPcnt.add(_percents[n]);
        }
        require(totalPcnt == PERCENT100, "Percentages add up should be 100%");

        vestInfo = VestingInfo({ periods:_periods, percents:_percents, totalVestedBnb:0, startTime:0, enabled:true, vestingTimerStarted:false});
    }
        

    /**
     * @dev Start the vesting counter. This is normally done after public rounds and manual LP is provided.
     * @notice - Access control: External. onlyFactory.
     */  
    function startVestingMode() external onlyFactory {
        require(finishUpSuccess, "Campaign not finished successfully yet");
        require(vestInfo.enabled, "Vesting not enabled");

        // Can be started only once 
        require(!vestInfo.vestingTimerStarted, "Vesting already started");

        vestInfo.startTime = now;
        vestInfo.vestingTimerStarted = true;
    }

    /**
     * @dev Check whether vesting feature is enabled
     * @return - Bool result
     * @notice - Access control: External. onlyFactory.
     */  
    function isVestingEnabled() external view returns(bool) {
        return vestInfo.enabled;
    }

    /**
     * @dev Check whether a particular vesting index has elapsed and claimable
     * @return - Bool: Claimable, uint256: If started and not claimable, returns the time needed to be claimable.
     * @notice - Access control: Public.
     */  
    function isVestingClaimable(uint256 _index) public view returns(bool, uint256) {

        if (!vestInfo.vestingTimerStarted) {
            return (false,0);
        }
        uint256 period = vestInfo.periods[_index];
        uint256 releaseTime = vestInfo.startTime.add(period);
        bool claimable = (now > releaseTime);
        uint256 remainTime;
        if (!claimable) {
            remainTime = releaseTime.sub(now); 
        }
        return (claimable, remainTime);
    }

    /**
     * @dev Allow users to claim their vested token, according to the index of the vested period.
     * @param _index - The index of the vesting period.
     * @notice - Access control: External.
     */  
    function claimVestedTokens(uint256 _index) external {
        
        (bool claimable, ) = isVestingClaimable(_index);
        require(claimable, "Not claimable at this time");

        uint256 amtTotalToken = getTotalTokenPurchased(msg.sender);

        require(amtTotalToken > 0, "You have not purchased the tokens");

        bool claimed = investorsClaimMap[msg.sender][_index];
        require(!claimed, "This vest amount is already claimed");

        investorsClaimMap[msg.sender][_index] = true;
        uint256 amtTokens = vestInfo.percents[_index].mul(amtTotalToken).div(PERCENT100);
            
        ERC20(token).safeTransfer(msg.sender, amtTokens);
        emit TokenClaimed(msg.sender, block.timestamp, amtTokens);
    }

    /**
     * @dev Allow campaign owner to claim their bnb, according to the index of the vested period.
     * @param _index - The index of the vesting period.
     * @notice - Access control: External. onlyCampaignOwner.
     */  
    function claimVestedBnb(uint256 _index) external onlyCampaignOwner {

        (bool claimable, ) = isVestingClaimable(_index);
        require(claimable, "Not claimable at this time");

        require(!campaignOwnerClaimMap[_index], "This vest amount is already claimed");
        campaignOwnerClaimMap[_index] = true;

        uint256 amtBnb = vestInfo.percents[_index].mul(vestInfo.totalVestedBnb).div(PERCENT100);

        (bool sentBnb, ) = campaignOwner.call{value: amtBnb}("");
        require(sentBnb, "Failed to send remain BNB to campaign owner");
    }

     /**
     * @dev To get the next vesting claim for a user.
     * @param _user - The user's address.
     * @return - int256 : the next period. -1 to indicate none found.
     * @return - uint256 : the amount of token claimable
     * @return - uint256 : time left to claim. If 0 (and next claim period is valid), it is currently claimable.
     * @notice - Access control: External. View.
     */  
    function getNextVestingClaim(address _user) external view returns(int256, uint256, uint256) {

        if (!vestInfo.vestingTimerStarted) {
            return (-1,0,0);
        }

        uint256 amtTotalToken = getTotalTokenPurchased(_user);
        if (amtTotalToken==0) {
            return (-1,0,0);
        }

        uint256 len = vestInfo.periods.length;
        for (uint256 n=0; n<len; n++) {
            (bool claimable, uint256 time) = isVestingClaimable(n);
            uint256 amtTokens = vestInfo.percents[n].mul(amtTotalToken).div(PERCENT100);
            bool claimed = investorsClaimMap[_user][n];
           
            if (!claimable) {
                return (int256(n), amtTokens, time);
            } else {
                if (!claimed) {
                    return ( int256(n), amtTokens, 0);
                }
            }
        }
        // All claimed 
        return (-1,0,0);
    }
}
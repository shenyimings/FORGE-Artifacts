// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../crowdsale/Crowdsale.sol";
import "../crowdsale/validation/WhitelistCrowdsale.sol";
import "../crowdsale/validation/TimedCrowdsale.sol";
import "../crowdsale/validation/CappedCrowdsale.sol";
import "../crowdsale/validation/PausableCrowdsale.sol";
import "../crowdsale/distribution/FinalizableCrowdsale.sol";

import "../ico/payMETokenVesting.sol";

error InsufficientBalance(uint256 balance, uint256 expected);
error IndividuallyMinimumCappedCrowdsale(uint256);
error IndividuallyMaximumCappedCrowdsale(uint256);
error NotAllowed(address);
error TotalExceedTotalSupply(uint256);


contract payMETokenCrowdsale is Ownable, 
CappedCrowdsale, TimedCrowdsale, WhitelistCrowdsale, 
FinalizableCrowdsale, PausableCrowdsale  {
   
   using SafeERC20 for IERC20;

   using SafeMath for uint256;

   address public vestingAddress;

   IERC20 public bUSDT;

   uint256 public tokenGenerationEventTime;

   uint256 public cliff;

   uint256 public duration;

   uint256 public minimumSale;

   uint256 public maximumSale;

    // The Project Team comprises 10% of the Max supply.
    // Technical Developers comprise 5% of the Max supply.
    // Business Development comprises 20% of the Max supply, 

   //Percentage
   uint256 public constant projectTeamPercentage = 10;
   uint256 public constant techincalDevelopersPercentage = 5;
   uint256 public constant businessDevelopmentPercentage = 20;

   //Vesting contract 
    // payMETokenVesting public projectTeamVesting;
    // payMETokenVesting public techincalDevelopersVesting;
    // payMETokenVesting public businessDevelopmentVesting; 

   Investor[] private investors;

   mapping(address => uint256) private _contributions;

   struct Investor{
       address investor;
       uint256 investment;
       bool created;
   }


   constructor(
        IERC20 iBUSDT,
        address iVestingAddress,
        uint256 iRate,    // rate in PayME
        address payable iWallet,
        IERC20 iToken,
        uint256 iCap,
        uint256 iOpeningTime,
        uint256 iClosingTime,
        uint256 iTGETime,
        uint256 iDuration
        
    )
        Crowdsale(iRate, iWallet, iToken ) 
        CappedCrowdsale(iCap)
        TimedCrowdsale(iOpeningTime, iClosingTime)
        
    {
        require(address(iBUSDT) != address(0), "Valid BUSD required");
        require(iVestingAddress != address(0), "Valid Vesting contract required");
        require(iCap != uint256(0), "Cap must be greater than Zero");
        require(iOpeningTime >= block.timestamp, "opening time is before current time");
        require(iClosingTime > iOpeningTime, "opening time is not before closing time");
        require(iTGETime > iOpeningTime, "Token Generation Event time is not before the closing time");
        require(iDuration > 15768000, "Duration must be greater than 6months");




        bUSDT = iBUSDT;
        tokenGenerationEventTime = iTGETime;
        cliff = 0;
        duration = iDuration;
        vestingAddress = iVestingAddress;
        minimumSale = 100;
        maximumSale = 1000;

    }

    function buyTokensInBUSD(address beneficiary, uint256 amount) public nonReentrant payable {
        require(address(beneficiary) != address(0), "Valid Beneficiary address is required");
        require(amount > 0, "Amount must be greater than zero(0)");

        uint256 weiAmount = amount;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        //_weiRaised = _weiRaised.add(weiAmount);

        _processPurchase(beneficiary, tokens);
        
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

        _updatePurchasingState(beneficiary, weiAmount);

        _forwardFunds(weiAmount);

        _postValidatePurchase(beneficiary, weiAmount);
    }

    function buyTokens(address beneficiary) override  public nonReentrant payable {
        revert NotAllowed(beneficiary);
    }

    function _forwardFunds(uint256 weiAmount) internal {
         //Send funds to the wallet
        bUSDT.safeTransferFrom(msg.sender, wallet(), weiAmount);

       
    }

    

    function _preValidatePurchase(address beneficiary, uint256 weiAmount) 
    internal 
    override(CappedCrowdsale, PausableCrowdsale, WhitelistCrowdsale, TimedCrowdsale)
    view {
        uint256 beneficiaryBalance = bUSDT.balanceOf(msg.sender);

        //Ensure that team owner has funds to create challenge
        if (weiAmount > beneficiaryBalance) {
          revert InsufficientBalance(beneficiaryBalance, weiAmount);
        }

        //Set Max and Min Purchase
        if(weiAmount < minimumSale){
            revert IndividuallyMinimumCappedCrowdsale(weiAmount);
        }
        
        if(_contributions[beneficiary].add(weiAmount) > maximumSale){
            revert IndividuallyMaximumCappedCrowdsale(maximumSale.sub(_contributions[beneficiary]));
        }

        super._preValidatePurchase(beneficiary, weiAmount);
    }

    function createInvestor(address beneficiary, uint256 tokenAmount) internal{
                
                investors.push(Investor(
                            beneficiary,
                            tokenAmount,
                            false
                ));
    }

    

    function _processPurchase(address beneficiary, uint256 tokenAmount) 
    override
    internal {
        createInvestor(beneficiary, tokenAmount);
    }

    /**
     * @dev Extend parent behavior to update beneficiary contributions.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount) override internal {
        super._updatePurchasingState(beneficiary, weiAmount);

        _contributions[beneficiary] = _contributions[beneficiary].add(weiAmount);
    }

    /**
     * @dev Can be overridden to add finalization logic. The overriding function
     * should call super._finalization() to ensure the chain of finalization is
     * executed entirely.
     */
    function _finalization() override internal {
        //TODO: Creating Vesting Shedule for others: technical team, director, e.t.c
        IERC20  payMEToken = token();

        uint256 totalSupply = payMEToken.totalSupply();


        uint256 totalWei =  weiRaised();
        uint256 tokenRate = rate();

        
        uint256 ptShare = totalSupply.mul(projectTeamPercentage).div(100);
        uint256 tdShare = totalSupply.mul(techincalDevelopersPercentage).div(100);
        uint256 bdShare = totalSupply.mul(businessDevelopmentPercentage).div(100);
        uint256 totalShare = ptShare.add(tdShare).add(bdShare);
        uint256 totalSales = totalWei.mul(tokenRate);
        
        //Send raised Payme Token to vesting contract

        //check if totalShare + totalSales <= totalSupply 
        uint total = totalShare.add(totalSales);
        if(total >  totalSupply){
          revert TotalExceedTotalSupply(total);
        }
        
        payMEToken.safeTransfer(vestingAddress, totalShare.add(totalSales));
         
        //Create Vesting shedule for all investor
        createInvestors();

        super._finalization();
    }

    function createInvestors() public {
       require(hasClosed(), "FinalizableCrowdsale: not closed");

       payMETokenVesting vesting = payMETokenVesting(vestingAddress);

      for(uint i = 0; i < investors.length; i++){
            Investor memory _investor = investors[i];

            if(_investor.created){
                continue;
            }
            
            vesting.createVestingSchedule(
                _investor.investor,
                tokenGenerationEventTime,
                cliff,
                duration,
                1,
                false,
                _investor.investment,
                true
            );

            _investor.created = true;
        }

    
    }

    /**
     * @dev Must be called after crowdsale ends, to do some extra finalization
     * work. Calls the contract's finalization function.
     */
    function finalize() override public onlyOwner {
         super.finalize();
    }

    // function getCurrentTime()
    //     internal
    //     virtual
    //     view
    //     returns(uint256){
    //     return block.timestamp;
    // }

    



}
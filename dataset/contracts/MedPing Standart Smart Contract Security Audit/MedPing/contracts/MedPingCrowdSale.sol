pragma solidity 0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MedPingToken.sol"; 
import "./MedPingInvestorsVault.sol"; 

contract MedPingCrowdSale  is Ownable, ReentrancyGuard{
    /**
    * @Legend: CrowdsalePeriodExtended = CPE
    * @Legend: CrowdsaleOperationFinished = COF
    */
    using SafeMath for uint256;
    MedPingToken public _tokenContract;
    MedPingInvestorsVault public _vaultContract;
    IERC20 public _BUSDContract;
    AggregatorV3Interface internal BNBUSD;

    uint256 public _rate;
    uint256 public _tokensSold;
    uint256 public _weiRaised;
    uint256  _tokensReamaining; 
    uint256 _crossDecimal = 10**8;
    
    // Track investor contributions
    uint256  investorMinCap;
    uint256  investorMaxCap;
    uint256  medPingHardCap;
    uint256  medPingSoftCap;
    uint numParticipants;
    uint256 _startTime;
    uint256 _endTime;
    bool private _finalized = false;
    bool private _vaultLocked= false;
    
    // Crowdsale Stages
    enum CrowdsaleStage { PreSale,PrivateSale,PublicSale,Paused,Ended }
    // Default to presale stage
    CrowdsaleStage public stage = CrowdsaleStage.Paused;
    
    mapping(CrowdsaleStage=> mapping(address => uint256)) _contributions;
    mapping(CrowdsaleStage=> mapping(address => uint256)) _receiving;
    mapping(CrowdsaleStage=> uint256) public CrowdsaleStageBalance;
    mapping(address => TeamMembersLock) public TeamMembersLockandEarlyInvestorsProfile;
    /**
     * @dev ADDRESSES.
     */
    address BNBUSD_Aggregator = 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526;
    address payable admin;
    address payable  _wallet;
    address payable public _DevMarketing;
    address payable public _TeamToken;
    address payable public _ListingLiquidity;
    address payable public _OperationsManagement;

    struct TeamMembersLock{
        uint256 _percent;
        uint256 _releasePercent;
        uint256 _releaseInterval;
        uint256 _releaseStarts;
        uint256 _holdDuration;
        uint256 _vaultKeyId;
    }
    
    /**
    * @dev EVENTS:
    */
    event COF();
    event CPE(uint256 oldEndTime, uint256 newEndTime);
    event BuyPing(
        address indexed _from,
        uint256 indexed _tokens,
        uint256  _value
    );
    event VaultCreated(
        uint256 indexed _vaultKey,
        address indexed _beneficiary,
        uint256  releaseDay,
        uint256 amount
    );

    /**
     * @dev Reverts if not in crowdsale time range.
     */
    modifier onlyWhileOpen {
        require(isOpen(), "Crowdsale: not open");
        _;
    }

    constructor(
                MedPingToken token,
                MedPingInvestorsVault vault,
                IERC20 _BUSD,
                uint256 startingTime,
                uint256 endingTime,
                address payable wallet,
                address payable DevMarketing,
                address payable TeamToken,
                address payable ListingLiquidity,
                address payable OperationsManagement
                )
    Ownable() ReentrancyGuard()
    {
        // 
        require(startingTime >= block.timestamp, "Crowdsale: start time is before current time");
        //
        require(endingTime > startingTime, "Crowdsale: start time is invalid");
        //assign an admin
        admin =  payable (msg.sender);
        //link to token contract 
        _tokenContract = token;
        //link to token contract 
        _vaultContract = vault;
        _BUSDContract = _BUSD;
        //token wallet 
        _wallet = wallet;
        //set default stage balance 
        updateStage(4);
        
        BNBUSD = AggregatorV3Interface(BNBUSD_Aggregator);
         //set periods manaagement
        _startTime = startingTime;
        _endTime = endingTime;
        _finalized = false;

        //set tokenomics
        _DevMarketing = DevMarketing;
        _TeamToken = TeamToken;
        _ListingLiquidity = ListingLiquidity;
        _OperationsManagement = OperationsManagement;
    }
    function participateBNB(uint80 _roundId) payable public onlyWhileOpen returns (bool){
        uint256 _numberOfTokens = _MedPingReceiving(msg.value,_roundId);
        _preValidateParticipation(msg.value, _numberOfTokens, msg.sender);
        //require that the transaction is successful 
        _processParticipationBNB(msg.sender, _numberOfTokens);
        _postParticipation(msg.sender,msg.value,_numberOfTokens);  

        emit BuyPing(msg.sender,_numberOfTokens,msg.value); 
        return true;
    }
    function participateBUSD(uint80 _roundId) public onlyWhileOpen returns(bool){
        require(_BUSDContract.allowance(msg.sender, address(this)) > 0);
        uint busdVal = _BUSDContract.allowance(msg.sender, address(this));
        uint bnbEquv = (busdVal.div(uint256(getBNBUSDPrice(_roundId)))).mul(_crossDecimal);
        uint256 _numberOfTokens = _MedPingReceiving(bnbEquv,_roundId);
        _preValidateParticipation(bnbEquv, _numberOfTokens, msg.sender);
        require(_BUSDContract.transferFrom(msg.sender, address(this), busdVal));
        _processParticipationBUSD(msg.sender, _numberOfTokens,busdVal);
        _postParticipation(msg.sender,bnbEquv,_numberOfTokens);
        emit BuyPing(msg.sender,_numberOfTokens,busdVal); 
       return true;
    }
    function _MedPingReceiving(uint256 _weiSent, uint80 _roundId) internal view returns (uint256 ){
        int _channelRate = 0;
        _channelRate  =  getBNBUSDPrice(_roundId);
        int _MedRate = int(_rate)/(_channelRate/int(_crossDecimal));
        uint256 _weiMedRate =  uint256((_MedRate * 10 **18 )/int(_crossDecimal));
        uint256 tempR = _weiSent.div(_weiMedRate);
        return tempR * 10 ** 18;
    }
    //sets the ICO Stage, rates  and the CrowdsaleStageBalance 
    function updateStage(uint _stage)public onlyOwner returns (bool success){

         if(uint(CrowdsaleStage.PreSale) == _stage) {
          stage = CrowdsaleStage.PreSale;
          CrowdsaleStageBalance[stage]=12500000 * (10**18) ; //
          investorMinCap   = 0.1 * (10**18);
          investorMaxCap  = 1.5 * (10**18);
          _rate = 0.0095 * (10**8); //usd 
        }else if (uint(CrowdsaleStage.PrivateSale) == _stage) {
         stage = CrowdsaleStage.PrivateSale;
          CrowdsaleStageBalance[stage]=37500000 * (10**18); //
          investorMinCap   = 0.2 * (10**18);
          investorMaxCap  = 5 * (10**18);
           _rate = 0.025 * (10**8); // usd
        }
        else if (uint(CrowdsaleStage.PublicSale) == _stage) {
         stage = CrowdsaleStage.PublicSale;
          CrowdsaleStageBalance[stage]=20000000 * (10**18); //
          investorMinCap   = 0.1 * (10**18);
          investorMaxCap  = 5 * (10**18);
           _rate = 0.075 * (10**8); // usd
        }else if(uint(CrowdsaleStage.Paused) == _stage){
            stage = CrowdsaleStage.Paused;
            CrowdsaleStageBalance[stage]=0;
            _rate = 0; //0.00 eth
        }else if(uint(CrowdsaleStage.Ended) == _stage){
            stage = CrowdsaleStage.Ended;
            CrowdsaleStageBalance[stage]=0;
            _rate = 0; //0.00 eth
        }
        return true;
    }
    function getStageBalance() public view returns (uint256) {
        return CrowdsaleStageBalance[stage];
    }
    function getParticipantGivings(address _participant) public view returns (uint256){
        return _contributions[stage][_participant];
    }
    function getParticipantReceivings(address _participant) public view returns (uint256){
        return _receiving[stage][_participant];
    }
    function _updateParticipantBalance(address _participant, uint256 _giving,uint256 _numOfTokens) internal returns (bool){
        uint256 oldGivings = getParticipantGivings(_participant);
        uint256 oldReceivings = getParticipantReceivings(_participant);
        
        uint256 newGivings = oldGivings.add(_giving);
        uint256 newReceiving = oldReceivings.add(_numOfTokens);
        
        _contributions[stage][_participant] = newGivings;
        _receiving[stage][_participant] = newReceiving;
        return true;
    }
    function _isIndividualCapped(address _participant, uint256 _weiAmount)  internal view returns (bool){
        uint256 _oldGiving = getParticipantGivings(_participant);
        uint256 _newGiving = _oldGiving.add(_weiAmount);
        require(_newGiving >= investorMinCap && _newGiving <= investorMaxCap);
        return true;
    }
    function _addToCrowdsaleStageBalance(uint256 amount)  internal{
        uint256 currentBal = getStageBalance();
        uint256 newBal = currentBal.add(amount);
        CrowdsaleStageBalance[stage]=newBal;
    }
    function _subFromCrowdsaleStageBalance(uint256 amount)  internal{
        uint256 currentBal = getStageBalance();
        uint256 newBal = currentBal.sub(amount);
        CrowdsaleStageBalance[stage]=newBal;
    }
    function _preValidateParticipation(uint256 _sentValue,uint256 _numberOfTokens, address _participant) internal view {
        //Require that contract has enough tokens 
        require(_tokenContract.balanceOf(address(this)) >= _numberOfTokens,'token requested not available');
        //require that participant giving is between the caped range per stage
        require(_isIndividualCapped(_participant,  _sentValue),'request not within the cap range');
    }
    function _processParticipationBNB(address recipient, uint256 amount) nonReentrant() internal{
        require( _forwardBNBFunds());
        require(_tokenContract.transfer(recipient, amount));
    }
    function _processParticipationBUSD(address recipient, uint256 amount,uint256 weiAmount) nonReentrant() internal{
        require( _forwardBUSDFunds(weiAmount));
        require(_tokenContract.transfer(recipient, amount));
    }
    function _postParticipation(address _participant,uint256 amount , uint256 _numberOfTokens) nonReentrant() internal returns(bool){
        //record participant givings and receivings
        require(_updateParticipantBalance(_participant,amount,_numberOfTokens));
        //track number of tokens sold  and amount raised
        _tokensSold += _numberOfTokens;
        _weiRaised += amount;
        //subtract from crowdsale stage balance 
        _subFromCrowdsaleStageBalance(_numberOfTokens);
        //lock investments of initial investors 
       if(stage == CrowdsaleStage.PreSale || stage == CrowdsaleStage.PrivateSale ){
            _tokenContract.addToLock(_numberOfTokens, _participant);
        }
        return true;
    }
    function releaseRistrictions () public onlyOwner() {
        require(_tokenContract.getFirstListingDate() != 1,"First listing date has to be set");
        require(isFinalized(),"Crowdsale is not finanlized");
        _tokenContract.releaseTokenTransfer();
    }
    /**
     * Returns the BNBUSD latest price
     */
    function getBNBUSDPrice(uint80 roundId) public view returns (int) {
        (
            uint80 id, 
            int price,
            uint startedAt,
            uint timeStamp,
        ) = BNBUSD.getRoundData(roundId);
         require(timeStamp > 0, "Round not complete");
         require(block.timestamp <= timeStamp + 1 days);
        return price;
    }
    /**
    * @dev forwards funds to the sale Wallet
    */
    function _forwardBNBFunds() internal returns (bool){
        _wallet.transfer(msg.value);
        return true;
    }
    /**
    * @dev forwards funds to the sale Wallet
    */
    function _forwardBUSDFunds(uint256 weiAmount) internal returns (bool){
        _BUSDContract.transfer(_wallet,weiAmount);
        return true;
    }

    function startTime() public view returns (uint256) {
        return _startTime;
    }
    function endTime() public view returns (uint256) {
        return _endTime;
    }
    function isOpen() public view returns (bool) {
       require(block.timestamp >= _startTime && block.timestamp <= _endTime ,"Crowdsale: not opened");
       require(stage != CrowdsaleStage.Paused && stage != CrowdsaleStage.Ended,"Crowdsale: not opened");
       return true;
    }
    function hasClosed() public view returns (bool) {
        return block.timestamp > _endTime;
    }
    function extendTime(uint256 newEndTime) public onlyOwner {
        require(!hasClosed(), "Crowdsale: close already");
        require(newEndTime > _endTime, "Crowdsale: new endtime must be after current endtime");
        _endTime = newEndTime;
        emit CPE(_endTime, newEndTime);
    }
    function setCaps(uint256 _softCap, uint256 _hardCap) public onlyOwner returns (bool){
        medPingSoftCap = _softCap;
        medPingHardCap =_hardCap;
        return true;
    }
    function getSoftCap() public view returns (uint256){
        return medPingSoftCap;
    }
    function getHardCap() public view returns (uint256){
        return medPingHardCap;
    }
    function getInvestorMinCap() public view returns (uint256){
        return investorMinCap;
    }
    function getInvestorMaxCap() public view returns (uint256){
        return investorMaxCap;
    }
    function vaultIsLocked() public view returns (bool) {
        return _vaultLocked;
    }
    function isFinalized() public view returns (bool) {
        return _finalized;
    }
    function calculatePercent(uint numerator, uint denominator) internal  pure returns (uint){
        return (denominator * (numerator * 100) ) /10000;
    }

    function lockVault() public onlyOwner(){
        require(hasClosed(), "Crowdsale: has not ended");
        require(_tokenContract.getFirstListingDate() != 1,"First listing date for token has to be set");
        uint256 listingDate = _tokenContract.getFirstListingDate();
        //Dev&Marketing
        require(distributeToVault(_DevMarketing,listingDate));
        // Team Token
        require(distributeToVault(_TeamToken,listingDate));
        //Listing & Liquidity
        require(distributeToVault(_ListingLiquidity,listingDate));
        //Operations & Management
        require(distributeToVault(_OperationsManagement,listingDate));
         _vaultLocked = true;
    }

    function finalize() public onlyOwner{
        require(!isFinalized(), "Crowdsale: already finalized");
        require(vaultIsLocked(), "Vault not locked");
        _finalized = true;
        uint256 crowdsaleBal = _tokenContract.balanceOf(address(this)); //balance of crowdsale contract
        //transfer remaining tokens back to admin account then update the balance sheet
         require(_tokenContract.transfer(admin, crowdsaleBal),"crowdsale balance transfer failed");
         require(_tokenContract.updatecrowdsaleBal(crowdsaleBal),"crowdsale balance update failed");
        emit COF();
    }
    function setTeamMembersLock(address _beneficiary, uint percent,uint releaseInterval,  uint releasePercent, uint holdDuration, uint vaultKeyId,uint releaseStarts ) public onlyOwner returns (bool){
        TeamMembersLock memory lock;
        lock._percent = percent;
        lock._releasePercent = releasePercent;
        lock._releaseInterval = releaseInterval;
        lock._releaseStarts = releaseStarts;
        lock._holdDuration = holdDuration;
        lock._vaultKeyId = vaultKeyId;
        TeamMembersLockandEarlyInvestorsProfile[_beneficiary] = lock;
        return true;
    }
    function getTeamMembersLock(address _beneficiary) public view returns (uint256 percent,uint256 holdDuration,uint256 interval,uint256 releaserpercent,uint256 vualtKeyId,uint256 releaseStarts){
        TeamMembersLock storage lock = TeamMembersLockandEarlyInvestorsProfile[_beneficiary];
        return (lock._percent,lock._holdDuration,lock._releaseInterval,lock._releasePercent,lock._vaultKeyId,lock._releaseStarts);
    }
    function distributeToVault(address _beneficiary,uint listingDate) internal returns (bool){
        uint totalSup = _tokenContract.totalSupply();
        uint releaseDay;
        TeamMembersLock storage lock = TeamMembersLockandEarlyInvestorsProfile[_beneficiary];
        uint totalFunds    = calculatePercent(lock._percent, totalSup);
        uint amountDue = calculatePercent(lock._releasePercent, totalFunds);
        uint interval = lock._releaseInterval;
        uint startsFrom = lock._releaseStarts;
        uint hold = lock._holdDuration;
        for (uint i=interval; i <= hold; i += interval ){  //for loop example check to see iff the dates are incremented successfully
                releaseDay = listingDate + (startsFrom + i) * 30 days; 
                uint key = _vaultContract.recordShareToVault(_beneficiary, amountDue , releaseDay,lock._vaultKeyId);
                emit VaultCreated(key,_beneficiary, releaseDay,amountDue);
        }
        return true;
    }
    
}
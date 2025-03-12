pragma solidity 0.8.1;

import "./ERC20BurnableCustomized.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";


contract QAOToken is ERC20Burnable, Ownable {

    uint256 private constant DAY_IN_SEC = 86400;
    uint256 private constant DIV_ACCURACY = 1 ether;

    uint256 public constant DAILY_MINT_AMOUNT = 100000000 ether;
    uint256 public constant ANNUAL_TREASURY_MINT_AMOUNT = 1000000000000 ether;
    uint256 private _mintMultiplier = 1 ether;

    uint256 private _mintAirdropShare = 0.45 ether;
    uint256 private _mintLiqPoolShare = 0.45 ether;
    uint256 private _mintApiRewardShare = 0.1 ether;

    /* by default minting will be disabled */
    bool private mintingIsActive = false;

    /* track the total airdrop amount, because we need a stable value to avoid fifo winners on withdrawing airdrops */
    uint256 private _totalAirdropAmount;

    /* timestamp which specifies when the next mint phase should happen */
    uint256 private _nextMintTimestamp;

    /* treasury minting and withdrawing variables */
    uint256 private _annualTreasuryMintCounter = 0; 
    uint256 private _annualTreasuryMintTimestamp = 0;
    address private _treasuryGuard;
    bool private _treasuryLockGuard = false;
    bool private _treasuryLockOwner = false;

    /* pools */
    address private _airdropPool;
    address private _liquidityPool;
    address private _apiRewardPool;

    /* voting engine */
    address private _votingEngine;


    constructor( address swapLiqPool, address treasuryGuard) ERC20("QAO", unicode"🌐") {

        _mint(swapLiqPool, 9000000000000 ether);

        _treasuryGuard = treasuryGuard;
        _annualTreasuryMint();
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _applyMintSchedule();
        _annualTreasuryMint();
        return ERC20.transfer(recipient, amount);
    }

    /*******************************************************************
     * Standard minting functionality
     *******************************************************************/

    /* turn on minting. make sure you specified the addresses of the receiving pools first */
    function activateMinting() public onlyOwner {
        require(!mintingIsActive, "QAO Token: Minting has already been activated");
        require(_airdropPool != address(0), "QAO Token: Please specify the address of the airdrop pool before activating minting.");
        require(_liquidityPool != address(0), "QAO Token: Please specify the address of the liquidity pool before activating minting.");
        require(_apiRewardPool != address(0), "QAO Token: Please specify the address of the api reward pool before activating minting.");

        mintingIsActive = true;
        _mintToPools();
        _nextMintTimestamp = block.timestamp + DAY_IN_SEC;
    }

    /* apply minting for the current day and reprocess any missed day */
    function _applyMintSchedule() private {
        if (mintingIsActive){
            while (block.timestamp >= _nextMintTimestamp){
                _mintToPools();
                _nextMintTimestamp = _nextMintTimestamp + DAY_IN_SEC;
            }
        }
    }

    /* calculate minting supply for each pool and mint tokens to them */
    function _mintToPools() private {
        uint256 totalMintAmount = (DAILY_MINT_AMOUNT * _mintMultiplier) / DIV_ACCURACY;
        uint256 airdropAmount = (totalMintAmount * _mintAirdropShare) / DIV_ACCURACY;
        uint256 liqPoolAmount = (totalMintAmount * _mintLiqPoolShare) / DIV_ACCURACY;
        uint256 apiRewardAmount = (totalMintAmount * _mintApiRewardShare) / DIV_ACCURACY;

        _mint(_airdropPool, airdropAmount);
        _mint(_liquidityPool, liqPoolAmount);
        _mint(_apiRewardPool, apiRewardAmount);
    }

    /* Get amount of days passed since the provided timestamp */
    function _getPassedDays(uint256 timestamp) private view returns (uint256) {
        uint256 secondsDiff = block.timestamp - timestamp;
        return (secondsDiff / DAY_IN_SEC);
    }

    /*******************************************************************
     * Treasury functionality
     *******************************************************************/
    function _annualTreasuryMint() private {
        if (block.timestamp >= _annualTreasuryMintTimestamp && _annualTreasuryMintCounter < 4) {
            _annualTreasuryMintTimestamp = block.timestamp + (365 * DAY_IN_SEC);
            _annualTreasuryMintCounter = _annualTreasuryMintCounter + 1;
            _mint(address(this), ANNUAL_TREASURY_MINT_AMOUNT);
        }
    }

    function unlockTreasuryByGuard() public {
        require(_msgSender() == _treasuryGuard, "QAO Token: You shall not pass!");
        _treasuryLockGuard = true;
    }
    function unlockTreasuryByOwner() public onlyOwner {
        _treasuryLockOwner = true;
    }

    function withdrawFromTreasury(address recipient, uint256 amount) public onlyOwner {
        require(_treasuryLockGuard && _treasuryLockOwner, "QAO Token: Treasury is not unlocked.");
        _transfer(address(this), recipient, amount);
        _treasuryLockGuard = false;
        _treasuryLockOwner = false;
    }

    /*******************************************************************
     * Voting engine support functionality
     *******************************************************************/
    function setVotingEngine(address votingEngineAddr) public onlyOwner {
        _votingEngine = votingEngineAddr;
    }

    function votingEngine() public view returns (address) {
        return _votingEngine;
    }

    function mintVoteStakeReward(uint256 amount) public {
        require(_votingEngine != address(0), "QAO Token: Voting engine not set.");
        require(_msgSender() == _votingEngine, "QAO Token: Only the voting engine can call this function.");
        _mint(_votingEngine, amount);
    }

    /*******************************************************************
     * Getters/ Setters for mint multiplier
     *******************************************************************/ 
    function mintMultiplier() public view returns (uint256) {
        return _mintMultiplier;
    }
    function setMintMultiplier(uint256 newMultiplier) public onlyOwner {
        require(newMultiplier < _mintMultiplier, "QAO Token: Value of new multiplier needs to be lower than the current one.");
        _mintMultiplier = newMultiplier;
    }

    /*******************************************************************
     * Getters/ Setters for minting pools
     *******************************************************************/  
    function airdropPool() public view returns (address){
        return _airdropPool;
    }
    function setAirdropPool(address newAddress) public onlyOwner {
        require(newAddress != address(0), "QAO Token: Address Zero cannot be the airdrop pool.");
        _airdropPool = newAddress;
    }

    function liquidityPool() public view returns (address){
        return _liquidityPool;
    }
    function setLiquidityPool(address newAddress) public onlyOwner {
        require(newAddress != address(0), "QAO Token: Address Zero cannot be the liquidity pool.");
        _liquidityPool = newAddress;
    }

    function apiRewardPool() public view returns (address){
        return _apiRewardPool;
    }
    function setApiRewardPool(address newAddress) public onlyOwner {
        require(newAddress != address(0), "QAO Token: Address Zero cannot be the reward pool.");
        _apiRewardPool = newAddress;
    }

    /*******************************************************************
     * Getters/ Setters for minting distribution shares
     *******************************************************************/
    function mintAirdropShare() public view returns (uint256){
        return _mintAirdropShare;
    }
    function setMintAirdropShare(uint256 newShare) public onlyOwner {
        require((newShare + _mintLiqPoolShare + _mintApiRewardShare) <= 1 ether, "QAO Token: Sum of mint shares is greater than 100%.");
        _mintAirdropShare = newShare;
    }

    function mintLiqPoolShare() public view returns (uint256){
        return _mintLiqPoolShare;
    }
    function setMintLiqPoolShare(uint256 newShare) public onlyOwner {
        require((newShare + _mintAirdropShare + _mintApiRewardShare) <= 1 ether, "QAO Token: Sum of mint shares is greater than 100%.");
        _mintLiqPoolShare = newShare;
    }

    function mintApiRewardShare() public view returns (uint256){
        return _mintApiRewardShare;
    }
    function setMintApiRewardShare(uint256 newShare) public onlyOwner {
        require((newShare + _mintAirdropShare + _mintLiqPoolShare) <= 1 ether, "QAO Token: Sum of mint shares is greater than 100%.");
        _mintApiRewardShare = newShare;
    }
}

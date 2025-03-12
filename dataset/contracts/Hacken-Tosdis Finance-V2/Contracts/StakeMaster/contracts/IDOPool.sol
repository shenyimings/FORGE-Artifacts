pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Pausable.sol";
import "./Whitelist.sol";
import "./interfaces/IidoMaster.sol";
import "./interfaces/ITierSystem.sol";

 contract IDOPool is Ownable, Pausable, Whitelist, ReentrancyGuard  {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    uint256 public tokenPrice;
    ERC20 public rewardToken;
    uint256 public decimals;
    uint256 public startTimestamp;
    uint256 public finishTimestamp;
    uint256 public startClaimTimestamp;
    uint256 public minEthPayment;
    uint256 public maxEthPayment;
    uint256 public maxDistributedTokenAmount;
    uint256 public tokensForDistribution;
    uint256 public distributedTokens;


    ITierSystem  public  tierSystem;
    IidoMaster  public  idoMaster;
    uint256 public feeFundsPercent;
    bool public enableTierSystem;

    struct UserInfo {
        uint debt;
        uint total;
        uint totalInvestedETH;
    }

    mapping(address => UserInfo) public userInfo;

    event TokensDebt(
        address indexed holder,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    
    event TokensWithdrawn(address indexed holder, uint256 amount);
    event HasWhitelistingUpdated(bool newValue);
    event EnableTierSystemUpdated(bool newValue);
    event FundsWithdrawn(uint256 amount);
    event FundsFeeWithdrawn(uint256 amount);
    event NotSoldWithdrawn(uint256 amount);

    uint256 public vestingPercent;
    uint256 public vestingStart;
    uint256 public vestingInterval;
    uint256 public vestingDuration;

    event VestingUpdated(uint256 _vestingPercent,
                    uint256 _vestingStart,
                    uint256 _vestingInterval,
                    uint256 _vestingDuration);
    event VestingCreated(address indexed holder, uint256 amount);
    event VestingReleased(uint256 amount);

    struct Vesting {
        uint256 balance;
        uint256 released;
    }

    mapping (address => Vesting) private _vestings;

    constructor(
        IidoMaster _idoMaster,
        uint256 _feeFundsPercent, 
        uint256 _tokenPrice,
        ERC20 _rewardToken,
        uint256 _startTimestamp,
        uint256 _finishTimestamp,
        uint256 _startClaimTimestamp,
        uint256 _minEthPayment,
        uint256 _maxEthPayment,
        uint256 _maxDistributedTokenAmount,
        bool _hasWhitelisting,
        bool _enableTierSystem,
        ITierSystem _tierSystem
        
    ) public Whitelist(_hasWhitelisting) {
        idoMaster = _idoMaster;
        feeFundsPercent = _feeFundsPercent;
        tokenPrice = _tokenPrice;
        rewardToken = _rewardToken;
        decimals = rewardToken.decimals();

        require( _startTimestamp < _finishTimestamp,  "Start must be less than finish");
        require( _finishTimestamp > now, "Finish must be more than now");
        
        startTimestamp = _startTimestamp;
        finishTimestamp = _finishTimestamp;
        startClaimTimestamp = _startClaimTimestamp;
        minEthPayment = _minEthPayment;
        maxEthPayment = _maxEthPayment;
        maxDistributedTokenAmount = _maxDistributedTokenAmount;
        enableTierSystem = _enableTierSystem;
        tierSystem = _tierSystem;
    }


  function setVesting(uint256 _vestingPercent,
                    uint256 _vestingStart,
                    uint256 _vestingInterval,
                    uint256 _vestingDuration) external onlyOwner {

        require(now < startTimestamp, "Already started");

        require(_vestingPercent <= 100, "Vesting percent must be <= 100");
        if(_vestingPercent > 0)
        {
            require(_vestingInterval > 0 , "interval must be greater than 0");
            require(_vestingDuration >= _vestingInterval, "interval cannot be bigger than duration");
        }

        vestingPercent = _vestingPercent;
        vestingStart = _vestingStart;
        vestingInterval = _vestingInterval;
        vestingDuration = _vestingDuration;

        emit VestingUpdated(vestingPercent,
                            vestingStart,
                            vestingInterval,
                            vestingDuration);
    }


    function pay() payable external nonReentrant onlyWhitelisted whenNotPaused{
        require(msg.value >= minEthPayment, "Less then min amount");
        require(now >= startTimestamp, "Not started");
        require(now < finishTimestamp, "Ended");
        
        uint256 tokenAmount = getTokenAmount(msg.value);
        require(tokensForDistribution.add(tokenAmount) <= maxDistributedTokenAmount, "Overfilled");

        UserInfo storage user = userInfo[msg.sender];

        if(enableTierSystem){
            require(user.totalInvestedETH.add(msg.value) <= tierSystem.getMaxEthPayment(msg.sender, maxEthPayment), "More then max amount");
        }
        else{
            require(user.totalInvestedETH.add(msg.value) <= maxEthPayment, "More then max amount");
        }

        tokensForDistribution = tokensForDistribution.add(tokenAmount);
        user.totalInvestedETH = user.totalInvestedETH.add(msg.value);
        user.total = user.total.add(tokenAmount);
        user.debt = user.debt.add(tokenAmount);
        
        emit TokensDebt(msg.sender, msg.value, tokenAmount);
    }

    function getTokenAmount(uint256 ethAmount)
        internal
        view
        returns (uint256)
    {
        return ethAmount.mul(10**decimals).div(tokenPrice);
    }


    /// @dev Allows to claim tokens for the specific user.
    /// @param _addresses Token receivers.
    function claimFor(address[] memory _addresses) external whenNotPaused{
         for (uint i = 0; i < _addresses.length; i++) {
            proccessClaim(_addresses[i]);
        }
    }

    /// @dev Allows to claim tokens for themselves.
    function claim() external whenNotPaused{
        proccessClaim(msg.sender);
    }

    /// @dev Proccess the claim.
    /// @param _receiver Token receiver.
    function proccessClaim(
        address _receiver
    ) internal nonReentrant{
        require(now > startClaimTimestamp, "Distribution not started");
        UserInfo storage user = userInfo[_receiver];
        uint256 _amount = user.debt;
        if (_amount > 0) {
            user.debt = 0;            
            distributedTokens = distributedTokens.add(_amount);

            if(vestingPercent > 0)
            {   
                uint256 vestingAmount = _amount.mul(vestingPercent).div(100);
                createVesting(_receiver, vestingAmount);
                _amount = _amount.sub(vestingAmount);
            }

            rewardToken.safeTransfer(_receiver, _amount);
            emit TokensWithdrawn(_receiver,_amount);
        }
    }

    function setHasWhitelisting(bool value) external onlyOwner{
        hasWhitelisting = value;
        emit HasWhitelistingUpdated(hasWhitelisting);
    } 

    function setEnableTierSystem(bool value) external onlyOwner{
        enableTierSystem = value;
        emit EnableTierSystemUpdated(enableTierSystem);
    } 

    function setTierSystem(ITierSystem _tierSystem) external onlyOwner {    
        tierSystem = _tierSystem;
    }

    function withdrawFunds() external onlyOwner nonReentrant{
        if(feeFundsPercent>0){
            uint256 feeAmount = address(this).balance.mul(feeFundsPercent).div(100);
            idoMaster.feeWallet().transfer(feeAmount); /* Fee Address */
            emit FundsFeeWithdrawn(feeAmount);
        }
        uint256 amount = address(this).balance;
        msg.sender.transfer(amount);
        emit FundsWithdrawn(amount);
    } 
     

    function withdrawNotSoldTokens() external onlyOwner nonReentrant{
        require(now > finishTimestamp, "Allow after finish time");
        uint256 amount = rewardToken.balanceOf(address(this)).add(distributedTokens).sub(tokensForDistribution);
        rewardToken.safeTransfer(msg.sender, amount);
        emit NotSoldWithdrawn(amount);
    }

    function getVesting(address beneficiary) public view returns (uint256, uint256) {
        Vesting memory v = _vestings[beneficiary];
        return (v.balance, v.released);
    }

    function createVesting(
        address beneficiary,
        uint256 amount
    ) private {
        Vesting storage vest = _vestings[beneficiary];
        require(vest.balance == 0, "Vesting already created");

        vest.balance = amount;

        emit VestingCreated(beneficiary, amount);
    }

     function release(address beneficiary) external nonReentrant {
        uint256 unreleased = releasableAmount(beneficiary);
        require(unreleased > 0, "Nothing to release");

        Vesting storage vest = _vestings[beneficiary];

        vest.released = vest.released.add(unreleased);
        vest.balance = vest.balance.sub(unreleased);

        rewardToken.safeTransfer(beneficiary, unreleased);
        emit VestingReleased(unreleased);
    }

    function releasableAmount(address beneficiary) public view returns (uint256) {
        return vestedAmount(beneficiary).sub(_vestings[beneficiary].released);
    }

    function vestedAmount(address beneficiary) public view returns (uint256) {
        if (block.timestamp < vestingStart) {
            return 0;
        }

        Vesting memory vest = _vestings[beneficiary];
        uint256 currentBalance = vest.balance;
        uint256 totalBalance = currentBalance.add(vest.released);

        if (block.timestamp >= vestingStart.add(vestingDuration)) {
            return totalBalance;
        } else {
            uint256 numberOfInvervals = block.timestamp.sub(vestingStart).div(vestingInterval);
            uint256 totalIntervals = vestingDuration.div(vestingInterval);
            return totalBalance.mul(numberOfInvervals).div(totalIntervals);
        }
    }

    // ============ Version Control ============
    function version() external pure returns (uint256) {
        return 101; // 1.0.1
    }
}

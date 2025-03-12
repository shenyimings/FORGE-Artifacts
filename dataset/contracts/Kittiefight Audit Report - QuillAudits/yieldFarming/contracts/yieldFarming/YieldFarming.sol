/**
* @title YieldFarming
* @author @Ola, @ziweidream, @Xaleee
* @notice This contract will track uniswap pool contract and addresses that deposit "UNISWAP pool" tokens 
*         and allow each individual address to DEPOSIT and  withdraw percentage of KTY and SDAO tokens 
*         according to number of "pool" tokens they own, relative to total pool tokens.
*         This contract contains two tokens in contract KTY and SDAO. The contract will also return 
*         certain statistics about rates, availability and timing period of the program.
*/
pragma solidity ^0.5.5;

import "../libs/openzeppelin_upgradable_v2_5_0/ownership/Ownable.sol";
import "../libs/openzeppelin_upgradable_v2_5_0/math/SafeMath.sol";
import '../uniswapKTY/uniswap-v2-core/interfaces/IUniswapV2Pair.sol';
import "../uniswapKTY/uniswap-v2-core/interfaces/IERC20.sol";
import "./YieldFarmingHelper.sol";
import "./YieldsCalculator.sol";
import '../interfaces/IVolcieToken.sol';
import '../uniswapKTY/uniswap-v2-periphery/libraries/UniswapV2Library.sol';

contract YieldFarming is Ownable {
    using SafeMath for uint256;

    /*                                               GENERAL VARIABLES                                                */
    /* ============================================================================================================== */

    IVolcieToken public volcie;                          // VolcieToken contract
    IERC20 public kittieFightToken;                      // KittieFightToken contract variable
    IERC20 public superDaoToken;                         // SuperDaoToken contract variable
    YieldFarmingHelper public yieldFarmingHelper;        // YieldFarmingHelper contract variable
    YieldsCalculator public yieldsCalculator;            // YieldFarmingHelper contract variable

    uint256 constant internal base18 = 1000000000000000000;
    uint256 constant internal base6 = 1000000;

    uint256 constant public MONTH = 30 days;// 30 * 24 * 60 * 60;  // MONTH duration is 30 days, to keep things standard
    uint256 constant public DAY = 1 days;// 24 * 60 * 60;

    uint256 public totalNumberOfPairPools;              // Total number of Uniswap V2 pair pools associated with YieldFarming

    uint256 public EARLY_MINING_BONUS;
    //uint256 public totalLockedLPinEarlyMining;
    uint256 public adjustedTotalLockedLPinEarlyMining;

    //uint256 public totalDepositedLP;                    // Total Uniswap Liquidity tokens deposited
    uint256 public totalLockedLP;                       // Total Uniswap Liquidity tokens locked
    uint256 public totalRewardsKTY;                     // Total KittieFightToken rewards
    uint256 public totalRewardsSDAO;                    // Total SuperDaoToken rewards
    uint256 public totalRewardsKTYclaimed;              // KittieFightToken rewards already claimed
    uint256 public totalRewardsSDAOclaimed;             // SuperDaoToken rewards already claimed

    uint256 public programDuration;                     // Total time duration for Yield Farming Program
    uint256 public programStartAt;                      // Start Time of Yield Farming Program 
    uint256 public programEndAt;                        // End Time of Yield Farming Program 
    uint256[6] public monthsStartAt;                    // an array of the start time of each month.
  
    uint256[6] public KTYunlockRates;                   // Reward Unlock Rates of KittieFightToken for eahc of the 6 months for the entire program duration
    uint256[6] public SDAOunlockRates;                  // Reward Unlock Rates of KittieFightToken for eahc of the 6 months for the entire program duration

    // Properties of a Staker
    struct Staker {
        uint256[2][] totalDeposits;                      // A 2d array of total deposits [[pairCode, batchNumber], [[pairCode, batchNumber], ...]]
        uint256[][200] batchLockedLPamount;              // A 2d array showing the locked amount of Liquidity tokens in each batch of each Pair Pool
        uint256[][200] adjustedBatchLockedLPamount;      // A 2d array showing the locked amount of Liquidity tokens in each batch of each Pair Pool, adjusted to LP bubbling factor
        uint256[][200] adjustedStartingLPamount;
        uint256[][200] factor;                           // A 2d array showing the LP bubbling factor in each batch of each Pair Pool
        uint256[][200] batchLockedAt;                    // A 2d array showing the locked time of each batch in each Pair Pool
        uint256[200] totalLPlockedbyPairCode;            // Total amount of Liquidity tokens locked by this stader from all pair pools
        //uint256 rewardsKTYclaimed;                     // Total amount of KittieFightToken rewards already claimed by this Staker
        //uint256 rewardsSDAOclaimed;                    // Total amount of SuperDaoToken rewards already claimed by this Staker
        uint256[] depositNumberForEarlyBonus;            // An array of all the deposit number eligible for early bonus for this staker
    }

    /// @dev a VOLCIE Token NFT's associated properties
    struct VolcieToken {
        address originalOwner;   // the owner of this token at the time of minting
        uint256 generation;      // the generation of this token, between number 0 and 5
        uint256 depositNumber;   // the deposit number associated with this token and the original owner
        uint256 LP;              // the original LP locked in this volcie token
        uint256 pairCode;        // the pair code of the uniswap pair pool from which the LP come from
        uint256 lockedAt;        // the unix time at which this funds is locked
        bool tokenBurnt;         // true if this token has been burnt
        uint256 tokenBurntAt;    // the time when this token was burnt, 0 if token is not burnt
        address tokenBurntBy;    // who burnt this token (if this token was burnt)
        uint256 ktyRewards;      // KTY rewards distributed upon burning this token
        uint256 sdaoRewards;     // SDAO rewards distributed upon burning this token
    }

    mapping(address => Staker) internal stakers;

    mapping(uint256 => address) internal pairPoolsInfo;

    /// @notice mapping volcieToken NFT to its properties
    mapping(uint256 => VolcieToken) internal volcieTokens;

    /// @notice mapping of every month to the total deposits made during that month, adjusted to the bubbling factor
    mapping(uint256 => uint256) public adjustedMonthlyDeposits;

    /// @notice mapping staker to the rewards she has already claimed
    mapping(address => uint256[2]) internal rewardsClaimed;

    /// @notice mapping of pair code to total deposited LPs associated with this pair code
    mapping(uint256 => uint256) internal totalDepositedLPbyPairCode;

    uint256 private unlocked;

    uint256 public calculated;
    uint256 public calculated1;

    /*                                                   MODIFIERS                                                    */
    /* ============================================================================================================== */
    modifier lock() {
        require(unlocked == 1, 'Locked');
        unlocked = 0;
        _;
        unlocked = 1;
    }          

    /*                                                   INITIALIZER                                                  */
    /* ============================================================================================================== */
    function initialize
    (
        address[] calldata _pairPoolAddr,
        IVolcieToken _volcie,
        IERC20 _kittieFightToken,
        IERC20 _superDaoToken,
        YieldFarmingHelper _yieldFarmingHelper,
        YieldsCalculator _yieldsCalculator,
        uint256[6] calldata _ktyUnlockRates,
        uint256[6] calldata _sdaoUnlockRates,
        uint256 _programStartTime
    )
        external initializer
    {
        Ownable.initialize(_msgSender());
        setVolcieToken(_volcie);
        setRewardsToken(_kittieFightToken, true);
        setRewardsToken(_superDaoToken, false);

        for (uint256 i = 0; i < _pairPoolAddr.length; i++) {
            addNewPairPool(_pairPoolAddr[i]);
        }

        // setKittieFightToken(_kittieFightToken);
        // setSuperDaoToken(_superDaoToken);
        setYieldFarmingHelper(_yieldFarmingHelper);
        setYieldsCalculator(_yieldsCalculator);

        // Set total rewards in KittieFightToken and SuperDaoToken
        totalRewardsKTY = 7000000 * base18; // 7000000 * base18;
        totalRewardsSDAO = 7000000 * base18; //7000000 * base18;

        // Set early mining bonus
        EARLY_MINING_BONUS = 700000 * base18; //700000 * base18;

        // Set reward unlock rate for the program duration
        for (uint256 j = 0; j < 6; j++) {
            setRewardUnlockRate(j, _ktyUnlockRates[j], true);
            setRewardUnlockRate(j, _sdaoUnlockRates[j], false);
        }

        // Set program duration (for a period of 6 months). Month starts at time of program deployment/initialization
        setProgramDuration(6, _programStartTime);

        //Reentrancy lock
        unlocked = 1;
    }

    /*                                                      EVENTS                                                    */
    /* ============================================================================================================== */
    event Deposited(
        address indexed sender,
        uint256 indexed volcieTokenID,
        uint256 depositNumber,
        uint256 indexed pairCode,
        uint256 lockedLP,
        uint256 depositTime
    );

    event VolcieTokenBurnt(
        address indexed burner,
        address originalOwner,
        uint256 indexed volcieTokenID,
        uint256 indexed depositNumber,
        uint256 pairCode,
        uint256 batchNumber,
        uint256 KTYamount,
        uint256 SDAOamount,
        uint256 LPamount,
        uint256 withdrawTime
    );

    // event WithDrawn(
    //     address indexed sender,
    //     uint256 indexed pairCode,
    //     uint256 KTYamount,
    //     uint256 SDAOamount,
    //     uint256 LPamount,
    //     uint256 startBatchNumber,
    //     uint256 endBatchNumber, 
    //     uint256 withdrawTime
    // );

    /*                                                 YIELD FARMING FUNCTIONS                                        */
    /* ============================================================================================================== */

    /**
     * @notice Deposit Uniswap Liquidity tokens
     * @param _amountLP the amount of Uniswap Liquidity tokens to be deposited
     * @param _pairCode the Pair Code associated with the Pair Pool of which the Liquidity tokens are to be deposited
     * @return bool true if the deposit is successful
     * @dev    Each new deposit of a staker makes a new deposit with Deposit Number for this staker.
     *         Deposit Number for each staker starts from 0 (for the first deposit), and increment by 1 for 
     *         subsequent deposits. Each deposit with a Deposit Number is associated with a Pair Code 
     *         and a Batch Number.
     *         For each staker, each Batch Number in each Pair Pool associated with a Pair Code starts 
     *         from 0 (for the first deposit), and increment by 1 for subsequent batches each.
     */
    function deposit(uint256 _amountLP, uint256 _pairCode) external lock returns (bool) {
        require(block.timestamp >= programStartAt && block.timestamp <= programEndAt, "Program is not active");
        
        require(_amountLP > 0, "Cannot deposit 0 tokens");

        require(IUniswapV2Pair(pairPoolsInfo[_pairCode]).transferFrom(msg.sender, address(this), _amountLP), "Fail to deposit liquidity tokens");

        uint256 _depositNumber = stakers[msg.sender].totalDeposits.length;

        _addDeposit(msg.sender, _depositNumber, _pairCode, _amountLP, block.timestamp);

        (,address _LPaddress,) = getPairPool(_pairCode);

        uint256 _volcieTokenID = _mint(msg.sender, _LPaddress, _amountLP);

        _updateMint(msg.sender, _depositNumber, _amountLP, _pairCode, _volcieTokenID);

        emit Deposited(msg.sender, _volcieTokenID, _depositNumber, _pairCode, _amountLP, block.timestamp);

        return true;
    }

    /**
     * @notice Withdraw Uniswap Liquidity tokens locked in a batch with _batchNumber specified by the staker
     * @notice Three tokens (Uniswap Liquidity Tokens, KittieFightTokens, and SuperDaoTokens) are transferred
     *         to the user upon successful withdraw
     * @param _volcieID the deposit number of the deposit from which the user wishes to withdraw the Uniswap Liquidity tokens locked 
     * @return bool true if the withdraw is successful
     */
    function withdrawByVolcieID(uint256 _volcieID) external lock returns (bool) {
        (bool _isPayDay,) = yieldFarmingHelper.isPayDay();
        require(_isPayDay, "Can only withdraw on pay day");

        address currentOwner = volcie.ownerOf(_volcieID);
        require(currentOwner == msg.sender, "Only the owner of this token can burn it");

        // require this token has not been burnt already
        require(volcieTokens[_volcieID].tokenBurnt == false, "This Volcie Token has already been burnt");

        address _originalOwner = volcieTokens[_volcieID].originalOwner;
        uint256 _depositNumber = volcieTokens[_volcieID].depositNumber;

        uint256 _pairCode = stakers[_originalOwner].totalDeposits[_depositNumber][0];
        uint256 _batchNumber = stakers[_originalOwner].totalDeposits[_depositNumber][1];

        // get the locked Liquidity token amount in this batch
        uint256 _amountLP = stakers[_originalOwner].batchLockedLPamount[_pairCode][_batchNumber];
        require(_amountLP > 0, "No locked tokens in this deposit");

        uint256 _lockDuration = block.timestamp.sub(volcieTokens[_volcieID].lockedAt);
        require(_lockDuration > MONTH, "Need to stake at least 30 days");

        volcie.burn(_volcieID);

        (uint256 _KTY, uint256 _SDAO) = yieldsCalculator.calculateRewardsByBatchNumber(_originalOwner, _batchNumber, _pairCode);

        _updateWithdrawByBatchNumber(_originalOwner, _pairCode, _batchNumber, _amountLP, _KTY, _SDAO);

        _updateBurn(msg.sender, _volcieID, _KTY, _SDAO);

        _transferTokens(msg.sender, _pairCode, _amountLP, _KTY, _SDAO);

        emit VolcieTokenBurnt(
            msg.sender, _originalOwner, _volcieID, _depositNumber, _pairCode,
            _batchNumber, _KTY, _SDAO, _amountLP, block.timestamp
        );

        return true;
    }

    /*                                                 SETTER FUNCTIONS                                               */
    /* ============================================================================================================== */
    /**
     * @dev Add new pairPool
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function addNewPairPool(address _pairPoolAddr) public onlyOwner {
        uint256 _pairCode = totalNumberOfPairPools;

        IUniswapV2Pair pair = IUniswapV2Pair(_pairPoolAddr);
        address token0 = pair.token0();
        address token1 = pair.token1();
        require(token0 == address(kittieFightToken) || token1 == address(kittieFightToken), "Pair should contain KTY");

        pairPoolsInfo[_pairCode] = _pairPoolAddr;

        totalNumberOfPairPools = totalNumberOfPairPools.add(1);
    }

    /**
     * @dev Set VOLCIE contract
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setVolcieToken(IVolcieToken _volcie) public onlyOwner {
        volcie = _volcie;
    }

    /**
     * @dev Set KittieFightToken contract
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setRewardsToken(IERC20 _rewardsToken, bool forKTY) public onlyOwner {
        if (forKTY) {
            kittieFightToken = _rewardsToken;
        } else {
            superDaoToken = _rewardsToken;
        }   
    }

    /**
     * @dev Set YieldFarmingHelper contract
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setYieldFarmingHelper(YieldFarmingHelper _yieldFarmingHelper) public onlyOwner {
        yieldFarmingHelper = _yieldFarmingHelper;
    }

    /**
     * @dev Set YieldsCalculator contract
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setYieldsCalculator(YieldsCalculator _yieldsCalculator) public onlyOwner {
        yieldsCalculator = _yieldsCalculator;
    }

    /**
     * @notice This function transfers tokens out of this contract to a new address
     * @dev This function is used to transfer unclaimed KittieFightToken or SuperDaoToken Rewards to a new address,
     *      or transfer other tokens erroneously tranferred to this contract back to their original owner
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function returnTokens(address _token, uint256 _amount, address _newAddress) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        require(_amount <= balance, "Exceeds balance");
        require(IERC20(_token).transfer(_newAddress, _amount), "Fail to transfer tokens");
    }

    /**
     * @notice Modify Reward Unlock Rate for KittieFightToken and SuperDaoToken for any month (from 0 to 5)
     *         within the program duration (a period of 6 months)
     * @param _month uint256 the month (from 0 to 5) for which the unlock rate is to be modified
     * @param _rate  uint256 the unlock rate
     * @param forKTY bool true if this modification is for KittieFightToken, false if it is for SuperDaoToken
     * @dev    This function can only be carreid out by the owner of this contract.
     */
    function setRewardUnlockRate(uint256 _month, uint256 _rate, bool forKTY) public onlyOwner {
        if (forKTY) {
            KTYunlockRates[_month] = _rate;
        } else {
            SDAOunlockRates[_month] = _rate;
        }
    }

    /**
     * @notice Set Yield Farming Program time duration
     * @param _totalNumberOfMonths uint256 total number of months in the entire program duration
     * @param _programStartAt uint256 time when Yield Farming Program starts
     * @dev    This function can only be carreid out by the owner of this contract.
     */
    function setProgramDuration(uint256 _totalNumberOfMonths, uint256 _programStartAt) public onlyOwner {
        programDuration = _totalNumberOfMonths.mul(MONTH);
        programStartAt = _programStartAt;
        programEndAt = programStartAt.add(MONTH.mul(6));

        monthsStartAt[0] = _programStartAt;
        for (uint256 i = 1; i < _totalNumberOfMonths; i++) {
            monthsStartAt[i] = monthsStartAt[i.sub(1)].add(MONTH); 
        }
    }

    /**
     * @notice Set total KittieFightToken rewards and total SuperDaoToken rewards for the entire program duration
     * @param _rewardsKTY uint256 total KittieFightToken rewards for the entire program duration
     * @param _rewardsSDAO uint256 total SuperDaoToken rewards for the entire program duration
     * @dev    This function can only be carreid out by the owner of this contract.
     */
    function setTotalRewards(uint256 _rewardsKTY, uint256 _rewardsSDAO) public onlyOwner {
        totalRewardsKTY = _rewardsKTY;
        totalRewardsSDAO = _rewardsSDAO;
    }

    /*                                                 GETTER FUNCTIONS                                               */
    /* ============================================================================================================== */
    
    /**
     * @param _pairCode uint256 Pair Code assocated with the Pair Pool 
     * @return the address of the pair pool associated with _pairCode
     */
    function getPairPool(uint256 _pairCode)
        public view
        returns (string memory, address, address)
    {
        IUniswapV2Pair pair = IUniswapV2Pair(pairPoolsInfo[_pairCode]);
        address token0 = pair.token0();
        address token1 = pair.token1();
        address otherToken = (token0 == address(kittieFightToken))?token1:token0;
        string memory pairName = string(abi.encodePacked(kittieFightToken.symbol(),"-",IERC20(otherToken).symbol()));
        return (pairName, pairPoolsInfo[_pairCode], otherToken);
    }

    /**
     * @param _volcieTokenID uint256 Volcie Token ID 
     * @return the properties of this Volcie Token 
     */
    function getVolcieToken(uint256 _volcieTokenID) public view
        returns (
            address originalOwner, uint256 depositNumber, uint256 generation,
            uint256 LP, uint256 pairCode, uint256 lockTime, bool tokenBurnt,
            address tokenBurntBy, uint256 ktyRewardsDistributed, uint256 sdaoRewardsDistributed
        )
    {
        originalOwner = volcieTokens[_volcieTokenID].originalOwner;
        depositNumber = volcieTokens[_volcieTokenID].depositNumber;
        generation = volcieTokens[_volcieTokenID].generation;
        LP = volcieTokens[_volcieTokenID].LP;
        pairCode = volcieTokens[_volcieTokenID].pairCode;
        lockTime = volcieTokens[_volcieTokenID].lockedAt;
        tokenBurnt = volcieTokens[_volcieTokenID].tokenBurnt;
        tokenBurntBy = volcieTokens[_volcieTokenID].tokenBurntBy;
        ktyRewardsDistributed = volcieTokens[_volcieTokenID].ktyRewards;
        sdaoRewardsDistributed = volcieTokens[_volcieTokenID].sdaoRewards;

    }

    /**
     * @return uint[2][2] a 2d array containing all the deposits made by the staker in this contract,
     *         each item in the 2d array consisting of the Pair Code and the Batch Number associated this
     *         the deposit. The Deposit Number of the deposit is the same as its index in the 2d array.
     */
    function getAllDeposits(address _staker)
        external view returns (uint256[2][] memory)
    {
        return stakers[_staker].totalDeposits;
    }

    /**
     * @return the total number of deposits this _staker has made
     */
    function getNumberOfDeposits(address _staker)
        external view returns (uint256)
    {
        return stakers[_staker].totalDeposits.length;
    }

    /**
     * @param _staker address the staker who has deposited Uniswap Liquidity tokens
     * @param _depositNumber deposit number for the _staker
     * @return pair pool code and batch number associated with this _depositNumber for the _staker
     */

    function getBatchNumberAndPairCode(address _staker, uint256 _depositNumber)
        public view returns (uint256, uint256)
    {
        uint256 _pairCode = stakers[_staker].totalDeposits[_depositNumber][0];
        uint256 _batchNumber = stakers[_staker].totalDeposits[_depositNumber][1];
        return (_pairCode, _batchNumber);
    }

    /**
     * @param _staker address the staker who has deposited Uniswap Liquidity tokens
     * @param _pairCode uint256 Pair Code assocated with a Pair Pool from whichh the batches are to be shown
     * @return uint256[] an array of the amount of locked Lquidity tokens in every batch of the _staker in
     *         the _pairCode. The index of the array is the Batch Number associated with the batch, since
     *         batch for a stakder starts from batch 0, and increment by 1 for subsequent batches each.
     * @dev    Each new deposit of a staker makes a new batch in _pairCode.
     */
    function getAllBatchesPerPairPool(address _staker, uint256 _pairCode)
        external view returns (uint256[] memory)
    {
        return stakers[_staker].batchLockedLPamount[_pairCode];
    }

    // function getAllDepositedLPs(address _staker)
    //     external view returns (uint256)
    // {
    //     return stakers[_staker].totalDepositedLPs;
    // }

    /**
     * @param _staker address the staker who has deposited Uniswap Liquidity tokens
     * @param _pairCode uint256 Pair Code assocated with a Pair Pool 
     * @param _batchNumber uint256 the batch number of which deposit the staker wishes to see the locked amount
     * @return uint256 the amount of Uniswap Liquidity tokens locked,
     *         and its adjusted amount, and the time when this batch was locked,
     *         in the batch with _batchNumber in _pairCode by the staker 
     */
    function getLPinBatch(address _staker, uint256 _pairCode, uint256 _batchNumber)
        external view returns (uint256, uint256, uint256, uint256)
    {
        uint256 _LP = stakers[_staker].batchLockedLPamount[_pairCode][_batchNumber];
        uint256 _adjustedLP = stakers[_staker].adjustedBatchLockedLPamount[_pairCode][_batchNumber];
        uint256 _adjustedStartingLP = stakers[_staker].adjustedStartingLPamount[_pairCode][_batchNumber];        
        uint256 _lockTime = stakers[_staker].batchLockedAt[_pairCode][_batchNumber];
        
        return (_LP, _adjustedLP, _adjustedStartingLP, _lockTime);
    }

    /**
     * @param _staker address the staker who has deposited Uniswap Liquidity tokens
     * @param _pairCode uint256 Pair Code assocated with a Pair Pool 
     * @param _batchNumber uint256 the batch number of which deposit the staker wishes to see the locked amount
     * @return uint256 the bubble factor of LP associated with this batch
     */
    function getFactorInBatch(address _staker, uint256 _pairCode, uint256 _batchNumber)
        external view returns (uint256)
    {
        return stakers[_staker].factor[_pairCode][_batchNumber];
    }

    /**
     * @return uint256 the total amount of locked liquidity tokens of a staker assocaited with _pairCode
     */
    function getLockedLPbyPairCode(address _staker, uint256 _pairCode)
        external view returns (uint256)
    {
        return stakers[_staker].totalLPlockedbyPairCode[_pairCode];
    }

    function getDepositsForEarlyBonus(address _staker) external view returns(uint256[] memory) {
        return stakers[_staker].depositNumberForEarlyBonus;
    }

    /**
     * @param _staker address the staker who has deposited Uniswap Liquidity tokens
     * @param _batchNumber uint256 the batch number of which deposit the staker wishes to see the locked amount
     * @param _pairCode uint256 Pair Code assocated with a Pair Pool 
     * @return bool true if the batch with the _batchNumber in the _pairCode of the _staker is eligible for Early Bonus, false if it is not eligible.
     * @dev    A batch needs to be locked within 7 days since contract deployment to be eligible for claiming yields.
     */
    function isBatchEligibleForEarlyBonus(address _staker, uint256 _batchNumber, uint256 _pairCode)
        public view returns (bool)
    {
        // get locked time
        uint256 lockedAt = stakers[_staker].batchLockedAt[_pairCode][_batchNumber];
        if (lockedAt > 0 && lockedAt <= programStartAt.add(DAY.mul(21))) {
            return true;
        }
        return false;
    }

    /**
     * @param _staker address the staker who has received the rewards
     * @return uint256 the total amount of KittieFightToken that have been claimed by this _staker
     * @return uint256 the total amount of SuperDaoToken that have been claimed by this _staker
     */
    function getTotalRewardsClaimedByStaker(address _staker) external view returns (uint256[2] memory) {
        return rewardsClaimed[_staker];
    }

    /**
     * @return unit256 the total monthly deposits of LPs, adjusted to LP factor.
     * @dev    LP factor reflects the difference of the intrinsic value of LP from different uniswap pair contracts
     */
    function getAdjustedTotalMonthlyDeposits(uint256 _month) external view returns (uint256) {
        return adjustedMonthlyDeposits[_month];
    }

    /**
     * @return unit256 the current month 
     * @dev    There are 6 months in this program in total, starting from month 0 to month 5.
     */
    function getCurrentMonth() public view returns (uint256) {
        uint256 currentMonth;
        for (uint256 i = 5; i >= 0; i--) {
            if (block.timestamp >= monthsStartAt[i]) {
                currentMonth = i;
                break;
            }
        }
        return currentMonth;
    }

    /**
     * @param _month uint256 the month (from 0 to 5) for which the Reward Unlock Rate is returned
     * @return uint256 the Reward Unlock Rate for KittieFightToken for the _month
     * @return uint256 the Reward Unlock Rate for SuperDaoToken for the _month
     */
    function getRewardUnlockRateByMonth(uint256 _month) external view returns (uint256, uint256) {
        uint256 _KTYunlockRate = KTYunlockRates[_month];
        uint256 _SDAOunlockRate = SDAOunlockRates[_month];
        return (_KTYunlockRate, _SDAOunlockRate);
    }

    /**
     * @return unit256 the starting time of a month
     * @dev    There are 6 months in this program in total, starting from month 0 to month 5.
     */

    function getMonthStartAt(uint256 month) external view returns (uint256) {
        return monthsStartAt[month];
    }

    function getTotalDepositsPerPairCode(uint256 _pairCode) external view returns (uint256) {
        return totalDepositedLPbyPairCode[_pairCode];
    }

    /**
     * This function is returning APY of yieldFarming program.
     * @return uint256 APY
     */
    function getAPY(address _pair_KTY_SDAO) external view returns (uint256) {
        if(totalLockedLP == 0)
            return 0;
        uint256 rateKTYSDAO = getExpectedPrice_KTY_SDAO(_pair_KTY_SDAO);

        uint256 totalRewardsInKTY = totalRewardsKTY.add(totalRewardsSDAO.mul(rateKTYSDAO).div(base18));

        uint256 lockedKTYs;

        for(uint256 i = 0; i < totalNumberOfPairPools; i++) {
            if(totalDepositedLPbyPairCode[i] == 0)
                continue;
            uint256 balance = kittieFightToken.balanceOf(pairPoolsInfo[i]);
            uint256 supply = IERC20(pairPoolsInfo[i]).totalSupply();
            uint256 KTYs = balance.mul(totalDepositedLPbyPairCode[i]).mul(2).div(supply);
            lockedKTYs = lockedKTYs.add(KTYs);
        }

        return base18.mul(200).mul(lockedKTYs.add(totalRewardsInKTY)).div(lockedKTYs);
    }

    /**
     * @dev returns the SDAO KTY price on uniswap, that is, how many KTYs for 1 SDAO
     */
    function getExpectedPrice_KTY_SDAO(address _pair_KTY_SDAO) public view returns (uint256) {
        // uint256 KTYbalance = kittieFightToken.balanceOf(_pair_KTY_SDAO);
        // uint256 SDAObalance = superDaoToken.balanceOf(_pair_KTY_SDAO);
        // return KTYbalance.mul(base18).div(SDAObalance);

        uint256 _amountSDAO = 1e18;  // 1 SDAO
        (uint256 _reserveKTY, uint256 _reserveSDAO) = yieldFarmingHelper.getReserve(
            address(kittieFightToken), address(superDaoToken), _pair_KTY_SDAO
            );
        return UniswapV2Library.getAmountIn(_amountSDAO, _reserveKTY, _reserveSDAO);
    }

    /*                                                 PRIVATE FUNCTIONS                                             */
    /* ============================================================================================================== */

    /**
     * @dev    Internal functions used in function deposit()
     * @param _sender address the address of the sender
     * @param _pairCode uint256 Pair Code assocated with a Pair Pool 
     * @param _amount uint256 the amount of Uniswap Liquidity tokens to be deposited
     * @param _lockedAt uint256 the time when this depoist is made
     */
    function _addDeposit
    (
        address _sender, uint256 _depositNumber, uint256 _pairCode, uint256 _amount, uint256 _lockedAt
    ) private {
        // uint256 _depositNumber = stakers[_sender].totalDeposits.length;
        uint256 _batchNumber = stakers[_sender].batchLockedLPamount[_pairCode].length;
        uint256 _currentMonth = getCurrentMonth();
        uint256 _factor = yieldFarmingHelper.bubbleFactor(_pairCode);
        uint256 _adjustedAmount = _amount.mul(base6).div(_factor);

        stakers[_sender].totalDeposits.push([_pairCode, _batchNumber]);
        stakers[_sender].batchLockedLPamount[_pairCode].push(_amount);
        stakers[_sender].adjustedBatchLockedLPamount[_pairCode].push(_adjustedAmount);
        stakers[_sender].factor[_pairCode].push(_factor);
        stakers[_sender].batchLockedAt[_pairCode].push(_lockedAt);
        stakers[_sender].totalLPlockedbyPairCode[_pairCode] = stakers[_sender].totalLPlockedbyPairCode[_pairCode].add(_amount);
        //stakers[_sender].totalDepositedLPs = stakers[_sender].totalDepositedLPs.add(_amount);

        uint256 _currentDay = yieldsCalculator.getCurrentDay();

        if (yieldsCalculator.getElapsedDaysInMonth(_currentDay, _currentMonth) > 0) {
            uint256 currentDepositedAmount = yieldsCalculator.getFirstMonthAmount(
                _currentDay,
                _currentMonth,
                adjustedMonthlyDeposits[_currentMonth],
                _adjustedAmount
            );

            stakers[_sender].adjustedStartingLPamount[_pairCode].push(currentDepositedAmount);
            adjustedMonthlyDeposits[_currentMonth] = adjustedMonthlyDeposits[_currentMonth].add(currentDepositedAmount);
        } else {
            stakers[_sender].adjustedStartingLPamount[_pairCode].push(_adjustedAmount);
            adjustedMonthlyDeposits[_currentMonth] = adjustedMonthlyDeposits[_currentMonth]
                                                     .add(_adjustedAmount);
        }

        if (_currentMonth < 5) {
            for (uint256 i = _currentMonth.add(1); i < 6; i++) {
                adjustedMonthlyDeposits[i] = adjustedMonthlyDeposits[i]
                                             .add(_adjustedAmount);
            }
        }

        //totalDepositedLP = totalDepositedLP.add(_amount);
        totalDepositedLPbyPairCode[_pairCode] = totalDepositedLPbyPairCode[_pairCode].add(_amount);
        totalLockedLP = totalLockedLP.add(_amount);

        if (block.timestamp <= programStartAt.add(DAY.mul(21))) {
            adjustedTotalLockedLPinEarlyMining = adjustedTotalLockedLPinEarlyMining.add(_adjustedAmount);
            stakers[_sender].depositNumberForEarlyBonus.push(_depositNumber);
        }
    }

    /**
     * @dev Updates funder profile when minting a new token to a funder
     */
    function _updateMint
    (
        address _originalOwner,
        uint256 _depositNumber,
        uint256 _LP,
        uint256 _pairCode,
        uint256 _volcieTokenID
    )
        internal
    {
        volcieTokens[_volcieTokenID].generation = getCurrentMonth();
        volcieTokens[_volcieTokenID].depositNumber = _depositNumber;
        volcieTokens[_volcieTokenID].LP = _LP;
        volcieTokens[_volcieTokenID].pairCode = _pairCode;
        volcieTokens[_volcieTokenID].lockedAt = now;
        volcieTokens[_volcieTokenID].originalOwner = _originalOwner;
    }

    /**
     * @param _sender address the address of the sender
     * @param _pairCode uint256 Pair Code assocated with a Pair Pool 
     * @param _KTY uint256 the amount of KittieFightToken
     * @param _SDAO uint256 the amount of SuperDaoToken
     * @param _LP uint256 the amount of Uniswap Liquidity tokens
     */
    function _updateWithdrawByBatchNumber
    (
        address _sender, uint256 _pairCode, uint256 _batchNumber,
        uint256 _LP, uint256 _KTY, uint256 _SDAO
    ) 
        private
    {
        // ========= update staker info =========
        // batch info
        uint256 adjustedLP = stakers[_sender].adjustedBatchLockedLPamount[_pairCode][_batchNumber];
        stakers[_sender].batchLockedLPamount[_pairCode][_batchNumber] = 0;
        stakers[_sender].adjustedBatchLockedLPamount[_pairCode][_batchNumber] = 0;
        stakers[_sender].adjustedStartingLPamount[_pairCode][_batchNumber] = 0;
        stakers[_sender].batchLockedAt[_pairCode][_batchNumber] = 0;

        // all batches in pair code info
        stakers[_sender].totalLPlockedbyPairCode[_pairCode] = stakers[_sender].totalLPlockedbyPairCode[_pairCode].sub(_LP);

        // ========= update public variables =========
        totalRewardsKTYclaimed = totalRewardsKTYclaimed.add(_KTY);
        totalRewardsSDAOclaimed = totalRewardsSDAOclaimed.add(_SDAO);
        totalLockedLP = totalLockedLP.sub(_LP);

        uint256 _currentMonth = getCurrentMonth();

        if (_currentMonth < 5) {
            for (uint i = _currentMonth; i < 6; i++) {
                adjustedMonthlyDeposits[i] = adjustedMonthlyDeposits[i]
                                             .sub(adjustedLP);
            }
        }

        // if eligible for Early Mining Bonus but unstake before program end, deduct it from totalLockedLPinEarlyMining
        if (block.timestamp < programEndAt && isBatchEligibleForEarlyBonus(_sender, _batchNumber, _pairCode)) {
            adjustedTotalLockedLPinEarlyMining = adjustedTotalLockedLPinEarlyMining.sub(adjustedLP);
        }
    }

    /**
     * @dev Updates funder profile when an existing Ethie Token NFT is burnt
     * @param _burner address who burns this NFT
     * @param _volcieTokenID uint256 the ID of the burnt Ethie Token NFT
     */
    function _updateBurn
    (
        address _burner,
        uint256 _volcieTokenID,
        uint256 _ktyRewards,
        uint256 _sdaoRewards
    )
        internal
    {
        // set values to 0 can get gas refund
        volcieTokens[_volcieTokenID].LP = 0;
        volcieTokens[_volcieTokenID].lockedAt = 0;
        volcieTokens[_volcieTokenID].tokenBurnt = true;
        volcieTokens[_volcieTokenID].tokenBurntAt = now;
        volcieTokens[_volcieTokenID].tokenBurntBy = _burner;
        volcieTokens[_volcieTokenID].ktyRewards = _ktyRewards;
        volcieTokens[_volcieTokenID].sdaoRewards = _sdaoRewards;

        rewardsClaimed[_burner][0] = rewardsClaimed[_burner][0].add(_ktyRewards);
        rewardsClaimed[_burner][1] = rewardsClaimed[_burner][1].add(_sdaoRewards);
    }

    /**
     * @param _user address the address of the _user to whom the tokens are transferred
     * @param _pairCode uint256 Pair Code assocated with a Pair Pool 
     * @param _amountLP uint256 the amount of Uniswap Liquidity tokens to be transferred to the _user
     * @param _amountKTY uint256 the amount of KittieFightToken to be transferred to the _user
     * @param _amountSDAO uint256 the amount of SuperDaoToken to be transferred to the _user
     */
    function _transferTokens(address _user, uint256 _pairCode, uint256 _amountLP, uint256 _amountKTY, uint256 _amountSDAO)
        private
    {
        // transfer liquidity tokens
        require(IUniswapV2Pair(pairPoolsInfo[_pairCode]).transfer(_user, _amountLP), "Fail to transfer liquidity token");

        // transfer rewards
        require(kittieFightToken.transfer(_user, _amountKTY), "Fail to transfer KTY");
        require(superDaoToken.transfer(_user, _amountSDAO), "Fail to transfer SDAO");
    }

     /**
     * @dev Called by deposit(), pass values to generate Volcie Token NFT with all atrributes as listed in params
     * @param _to address who this Ethie Token NFT is minted to
     * @param _LPaddress address of the uniswap pair contract of which the LPs are 
     * @param _LPamount uint256 the amount of LPs associated with this NFT
     * @return uint256 ID of the LP Token NFT minted
     */
    function _mint
    (
        address _to,
        address _LPaddress,
        uint256 _LPamount
    )
        private
        returns (uint256)
    {
        return volcie.mint(_to, _LPaddress, _LPamount);
    }
}

pragma solidity ^0.5.5;

import "../libs/openzeppelin_upgradable_v2_5_0/ownership/Ownable.sol";
import "../libs/openzeppelin_upgradable_v2_5_0/math/SafeMath.sol";
import '../uniswapKTY/uniswap-v2-core/interfaces/IUniswapV2Pair.sol';
import '../uniswapKTY/uniswap-v2-periphery/libraries/UniswapV2Library.sol';
import "../uniswapKTY/uniswap-v2-core/interfaces/IERC20.sol";
import './YieldFarming.sol';
import './YieldsCalculator.sol';

contract YieldFarmingHelper is Ownable {
    using SafeMath for uint256;

    /*                                               GENERAL VARIABLES                                                */
    /* ============================================================================================================== */

    YieldFarming public yieldFarming;
    YieldsCalculator public yieldsCalculator;

    address public ktyWethPair;
    address public daiWethPair;

    address public kittieFightTokenAddr;
    address public superDaoTokenAddr;
    address public wethAddr;
    address public daiAddr;

    uint256 constant public base18 = 1000000000000000000;
    uint256 constant public base6 = 1000000;

    uint256 constant public MONTH = 30 days;// 30 * 24 * 60 * 60;  // MONTH duration is 30 days, to keep things standard
    uint256 constant public DAY = 1 days;// 24 * 60 * 60;

    /*                                                   INITIALIZER                                                  */
    /* ============================================================================================================== */

    function initialize
    (
        YieldFarming _yieldFarming,
        YieldsCalculator _yieldsCalculator,
        address _ktyWethPair,
        address _daiWethPair,
        address _kittieFightToken,
        address _superDaoToken,
        address _weth,
        address _dai
    ) 
        public initializer
    {
        Ownable.initialize(_msgSender());
        setYieldFarming(_yieldFarming);
        setYieldsCalculator(_yieldsCalculator);
        setKtyWethPair(_ktyWethPair);
        setDaiWethPair(_daiWethPair);
        setRwardsTokenAddress(_kittieFightToken, true);
        setRwardsTokenAddress(_superDaoToken, false);
        setWethAddress(_weth);
        setDaiAddress(_dai);
    }

    /*                                                 SETTER FUNCTIONS                                               */
    /* ============================================================================================================== */

    /**
     * @dev Set Uniswap KTY-Weth Pair contract
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setYieldFarming(YieldFarming _yieldFarming) public onlyOwner {
        yieldFarming = _yieldFarming;
    }

    /**
     * @dev Set Uniswap KTY-Weth Pair contract
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setYieldsCalculator(YieldsCalculator _yieldsCalculator) public onlyOwner {
        yieldsCalculator= _yieldsCalculator;
    }

    /**
     * @dev Set Uniswap KTY-Weth Pair contract address
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setKtyWethPair(address _ktyWethPair) public onlyOwner {
        ktyWethPair = _ktyWethPair;
    }

    /**
     * @dev Set Uniswap Dai-Weth Pair contract address
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setDaiWethPair(address _daiWethPair) public onlyOwner {
        daiWethPair = _daiWethPair;
    }

    /**
     * @dev Set tokens address
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setRwardsTokenAddress(address _rewardToken, bool forKTY) public onlyOwner {
        if (forKTY) {
            kittieFightTokenAddr = _rewardToken;
        } else {
            superDaoTokenAddr = _rewardToken;
        }        
    }

    /**
     * @dev Set Weth contract address
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setWethAddress(address _weth) public onlyOwner {
        wethAddr = _weth;
    }

    /**
     * @dev Set Dai contract address
     * @dev This function can only be carreid out by the owner of this contract.
     */
    function setDaiAddress(address _dai) public onlyOwner {
        daiAddr = _dai;
    }

    /*                                                 GETTER FUNCTIONS                                               */
    /* ============================================================================================================== */

    // Getters YieldFarming

    /**
     * @return KTY reserves and the total supply of LPs from a uniswap pair contract associated with a
              pair code in Yield Farming.
     */
    function getLPinfo(uint256 _pairCode)
        public view returns (uint256 reserveKTY, uint256 totalSupplyLP) 
    {
        (,address pairPoolAddress, address _tokenAddr) = yieldFarming.getPairPool(_pairCode);
        (reserveKTY,) = getReserve(kittieFightTokenAddr, _tokenAddr, pairPoolAddress);
        totalSupplyLP = IUniswapV2Pair(pairPoolAddress).totalSupply();
    }

    /**
     * @return returns the LP “Bubble Factor” of LP from a uniswap pair contract associate with a pair code. 
     * @dev calculation is based on formula: LP1 / LP =  (T1 x R) / (T x R1)
     * @dev returned value is amplified 1000000 times to avoid float imprecision
     */
    function bubbleFactor(uint256 _pairCode) external view returns (uint256)
    {
        (uint256 reserveKTY, uint256 totalSupply) = getLPinfo(0);
        (uint256 reserveKTY_1, uint256 totalSupply_1) = getLPinfo(_pairCode);

        uint256 factor = totalSupply_1.mul(reserveKTY).mul(base6).div(totalSupply.mul(reserveKTY_1));
        return factor;
    }

    /**
     * @return true and 0 if now is pay day, false if now is not pay day and the time until next pay day
     * @dev Pay Day is the first day of each month, starting from the second month.
     * @dev After program ends, every day is Pay Day.
     */
    function isPayDay()
        public view
        returns (bool, uint256)
    {
        uint256 month1StartTime = yieldFarming.getMonthStartAt(1);
        if (block.timestamp < month1StartTime) {
            return (false, month1StartTime.sub(block.timestamp));
        }
        if (block.timestamp >= yieldFarming.programEndAt()) {
            return (true, 0);
        }
        uint256 currentMonth = yieldFarming.getCurrentMonth();
        if (block.timestamp >= yieldFarming.getMonthStartAt(currentMonth)
            && block.timestamp <= yieldFarming.getMonthStartAt(currentMonth).add(DAY)) {
            return (true, 0);
        }
        if (block.timestamp > yieldFarming.getMonthStartAt(currentMonth).add(DAY)) {
            uint256 nextPayDay = yieldFarming.getMonthStartAt(currentMonth.add(1));
            return (false, nextPayDay.sub(block.timestamp));
        }
    }

    /**
     * @return uint256 the total amount of Uniswap Liquidity tokens locked in this contract
     */
    function getTotalLiquidityTokenLocked() external view returns (uint256) {
        return yieldFarming.totalLockedLP();
    }

    /**
     * @return uint256 the total locked LPs in Yield Farming in DAI value
     */
    function totalLockedLPinDAI() external view returns (uint256) {
        uint256 _totalLockedLPinDAI = 0;
        uint256 _LPinDai;
        uint256 totalNumberOfPairPools = yieldFarming.totalNumberOfPairPools();
        for (uint256 i = 0; i < totalNumberOfPairPools; i++) {
            _LPinDai = getTotalLiquidityTokenLockedInDAI(i);
            _totalLockedLPinDAI = _totalLockedLPinDAI.add(_LPinDai);
        }

        return _totalLockedLPinDAI;
    }

    /**
     * @return bool true if this _staker has made any deposit, false if this _staker has no deposit
     * @return uint256 the deposit number for this _staker associated with the _batchNumber and _pairCode
     */
    function getDepositNumber(address _staker, uint256 _pairCode, uint256 _batchNumber)
        external view returns (bool, uint256)
    {
        uint256 _pair;
        uint256 _batch;

        uint256 _totalDeposits = yieldFarming.getNumberOfDeposits(_staker);
        if (_totalDeposits == 0) {
            return (false, 0);
        }
        for (uint256 i = 0; i < _totalDeposits; i++) {
            (_pair, _batch) = yieldFarming.getBatchNumberAndPairCode(_staker, i);
            if (_pair == _pairCode && _batch == _batchNumber) {
                return (true, i);
            }
        }
    }

    /**
     * @return A staker's total LPs locked associated with a pair code, qualifying for claiming early bonus, and its values adjusted
     *         to the LP “Bubble Factor”.
     */
    function totalLPforEarlyBonusPerPairCode(address _staker, uint256 _pairCode)
        public view returns (uint256, uint256) {
        uint256[] memory depositsEarlyBonus = yieldFarming.getDepositsForEarlyBonus(_staker);
        uint256 totalLPEarlyBonus = 0;
        uint256 adjustedTotalLPEarlyBonus = 0;
        uint256 depositNum;
        uint256 batchNum;
        uint256 pairCode;
        uint256 lockTime;
        uint256 lockedLP;
        uint256 adjustedLockedLP;
        for (uint256 i = 0; i < depositsEarlyBonus.length; i++) {
            depositNum = depositsEarlyBonus[i];
            (pairCode, batchNum) = yieldFarming.getBatchNumberAndPairCode(_staker, depositNum);
            (lockedLP,adjustedLockedLP,, lockTime) = yieldFarming.getLPinBatch(_staker, pairCode, batchNum);
            if (pairCode == _pairCode && lockTime > 0 && lockedLP > 0) {
                totalLPEarlyBonus = totalLPEarlyBonus.add(lockedLP);
                adjustedTotalLPEarlyBonus = adjustedTotalLPEarlyBonus.add(adjustedLockedLP);
            }
        }

        return (totalLPEarlyBonus, adjustedTotalLPEarlyBonus);
    }

    /**
     * @return A staker's total LPs locked qualifying for claiming early bonus, and its values adjusted
     *         to the LP “Bubble Factor”.
     */
    function totalLPforEarlyBonus(address _staker) public view returns (uint256, uint256) {
        uint256[] memory _depositsEarlyBonus = yieldFarming.getDepositsForEarlyBonus(_staker);
        if (_depositsEarlyBonus.length == 0) {
            return (0, 0);
        }
        uint256 _totalLPEarlyBonus = 0;
        uint256 _adjustedTotalLPEarlyBonus = 0;
        uint256 _depositNum;
        uint256 _batchNum;
        uint256 _pair;
        uint256 lockTime;
        uint256 lockedLP;
        uint256 adjustedLockedLP;
        for (uint256 i = 0; i < _depositsEarlyBonus.length; i++) {
            _depositNum = _depositsEarlyBonus[i];
            (_pair, _batchNum) = yieldFarming.getBatchNumberAndPairCode(_staker, _depositNum);
            (lockedLP,adjustedLockedLP,, lockTime) = yieldFarming.getLPinBatch(_staker, _pair, _batchNum);
            if (lockTime > 0 && lockedLP > 0) {
                _totalLPEarlyBonus = _totalLPEarlyBonus.add(lockedLP);
                _adjustedTotalLPEarlyBonus = _adjustedTotalLPEarlyBonus.add(adjustedLockedLP);
            }
        }

        return (_totalLPEarlyBonus, _adjustedTotalLPEarlyBonus);
    }

    /**
     * @return uint256, uint256 a staker's total early bonus (KTY and SDAO) he/she has accrued.
     */
    function getTotalEarlyBonus(address _staker) external view returns (uint256, uint256) {
        (, uint256 totalEarlyLP) = totalLPforEarlyBonus(_staker);
        uint256 earlyBonus = yieldsCalculator.getEarlyBonus(totalEarlyLP);
        // early bonus for KTY is the same amount as early bonus for SDAO
        return (earlyBonus, earlyBonus);
    }

    /**
     * @return uint256 the total amount of KittieFightToken that have been claimed
     * @return uint256 the total amount of SuperDaoToken that have been claimed
     */
    function getTotalRewardsClaimed() external view returns (uint256, uint256) {
        uint256 totalKTYclaimed = yieldFarming.totalRewardsKTYclaimed();
        uint256 totalSDAOclaimed = yieldFarming.totalRewardsSDAOclaimed();
        return (totalKTYclaimed, totalSDAOclaimed);
    }

    /**
     * @return uint256 the total amount of KittieFightToken rewards
     * @return uint256 the total amount of SuperDaoFightToken rewards
     */
    function getTotalRewards() public view returns (uint256, uint256) {
        uint256 rewardsKTY = yieldFarming.totalRewardsKTY();
        uint256 rewardsSDAO = yieldFarming.totalRewardsSDAO();
        return (rewardsKTY, rewardsSDAO);
    }

    /**
     * @return uint256 the total amount of Uniswap Liquidity tokens deposited
     *         including both locked tokens and withdrawn tokens
     */
    function getTotalDeposits() public view returns (uint256) {
        uint256 totalPools = yieldFarming.totalNumberOfPairPools();
        uint256 totalDeposits = 0;
        uint256 deposits;
        for (uint256 i = 0; i < totalPools; i++) {
            deposits = yieldFarming.getTotalDepositsPerPairCode(i);
            totalDeposits = totalDeposits.add(deposits);
        }
        return totalDeposits;
    }

    /**
     * @return uint256 the dai value of the total amount of Uniswap Liquidity tokens deposited 
     *         including both locked tokens and withdrawn tokens 
     */
    function getTotalDepositsInDai() external view returns (uint256) {
        uint256 totalPools = yieldFarming.totalNumberOfPairPools();
        uint256 totalDepositsInDai = 0;
        uint256 deposits;
        uint256 depositsInDai;
        for (uint256 i = 0; i < totalPools; i++) {
            deposits = yieldFarming.getTotalDepositsPerPairCode(i);
            depositsInDai = deposits > 0 ? getLPvalueInDai(i, deposits) : 0;
            totalDepositsInDai = totalDepositsInDai.add(depositsInDai);
        }
        return totalDepositsInDai;
    }

    /**
     * @return uint256 the total amount of KittieFightToken rewards yet to be distributed
     * @return uint256 the total amount of SuperDaoFightToken rewards yet to be distributed
     */
    function getLockedRewards() public view returns (uint256, uint256) {
        (uint256 totalRewardsKTY, uint256 totalRewardsSDAO) = getTotalRewards();
        (uint256 unlockedKTY, uint256 unlockedSDAO) = getUnlockedRewards();
        uint256 lockedKTY = totalRewardsKTY.sub(unlockedKTY);
        uint256 lockedSDAO = totalRewardsSDAO.sub(unlockedSDAO);
        return (lockedKTY, lockedSDAO);
    }

    /**
     * @return uint256 the total amount of KittieFightToken rewards already distributed
     * @return uint256 the total amount of SuperDaoFightToken rewards already distributed
     */
    function getUnlockedRewards() public view returns (uint256, uint256) {
        uint256 unlockedKTY = IERC20(kittieFightTokenAddr).balanceOf(address(yieldFarming));
        uint256 unlockedSDAO = IERC20(superDaoTokenAddr).balanceOf(address(yieldFarming));
        return (unlockedKTY, unlockedSDAO);
    }

    /**
     * @dev get info on program duration and month
     */
    function getProgramDuration() external view 
    returns
    (
        uint256 entireProgramDuration,
        uint256 monthDuration,
        uint256 startMonth,
        uint256 endMonth,
        uint256 currentMonth,
        uint256 daysLeft,
        uint256 elapsedMonths
    ) 
    {
        uint256 currentDay = yieldsCalculator.getCurrentDay();
        entireProgramDuration = yieldFarming.programDuration();
        monthDuration = yieldFarming.MONTH();
        startMonth = 0;
        endMonth = 5;
        currentMonth = yieldFarming.getCurrentMonth();
        daysLeft = currentDay >= 180 ? 0 : 180 - currentDay;
        elapsedMonths = currentMonth == 0 ? 0 : currentMonth;
    }

     /**
     * @return uint256 the amount of total Rewards for KittieFightToken for early mining bonnus
     * @return uint256 the amount of total Rewards for SuperDaoToken for early mining bonnus
     */
    function getTotalEarlyMiningBonus() external view returns (uint256, uint256) {
        // early mining bonus is the same amount in KTY and SDAO
        return (yieldFarming.EARLY_MINING_BONUS(), yieldFarming.EARLY_MINING_BONUS());
    }

    /**
     * @return uint256 the amount of locked liquidity tokens,
     *         and its adjusted amount, and when this deposit was made,
     *         in a deposit of a staker assocaited with _depositNumber
     */
    function getLockedLPinDeposit(address _staker, uint256 _depositNumber)
        external view returns (uint256, uint256, uint256)
    {
        (uint256 _pairCode, uint256 _batchNumber) = yieldFarming.getBatchNumberAndPairCode(_staker, _depositNumber); 
        (uint256 _LP, uint256 _adjustedLP,, uint256 _lockTime) = yieldFarming.getLPinBatch(_staker, _pairCode, _batchNumber);
        return (_LP, _adjustedLP, _lockTime);
    }

    /**
     * @param _staker address the staker who has deposited Uniswap Liquidity tokens
     * @param _batchNumber uint256 the batch number of which deposit the staker wishes to see the locked amount
     * @param _pairCode uint256 Pair Code assocated with a Pair Pool 
     * @return bool true if the batch with the _batchNumber in the _pairCode of the _staker is a valid batch, false if it is non-valid.
     * @dev    A valid batch is a batch which has locked Liquidity tokens in it. 
     * @dev    A non-valid batch is an empty batch which has no Liquidity tokens in it.
     */
    function isBatchValid(address _staker, uint256 _pairCode, uint256 _batchNumber)
        public view returns (bool)
    {
        (uint256 _LP,,,) = yieldFarming.getLPinBatch(_staker, _pairCode, _batchNumber);
        return _LP > 0;
    }

    /**
     * @return uint256 DAI value representation of ETH in uniswap KTY - ETH pool, according to 
     *         all Liquidity tokens locked in this contract.
     */
    function getTotalLiquidityTokenLockedInDAI(uint256 _pairCode) public view returns (uint256) {
        (,address pairPoolAddress,) = yieldFarming.getPairPool(_pairCode);
        uint256 balance = IUniswapV2Pair(pairPoolAddress).balanceOf(address(yieldFarming));
        uint256 totalSupply = IUniswapV2Pair(pairPoolAddress).totalSupply();
        uint256 percentLPinYieldFarm = balance.mul(base18).div(totalSupply);
        
        uint256 totalKtyInPairPool = IERC20(kittieFightTokenAddr).balanceOf(pairPoolAddress);

        return totalKtyInPairPool.mul(2).mul(percentLPinYieldFarm).mul(KTY_DAI_price())
               .div(base18).div(base18);
    }

    /**
     * @param _pairCode uint256 the pair code of which the LPs are 
     * @param _LP uint256 the amount of LPs
     * @return uint256 DAI value of the amount LPs which are from a pair pool associated with the pair code
     * @dev the calculations is as below:
     *      For example, if I have 1 of 1000 LP of KTY-WETH, and there is total 10000 KTY and 300 ETH 
     *      staked in this pair, then 1 have 10 KTY + 0.3 ETH. And that is equal to 20 KTY or 0.6 ETH total.
     */
    function getLPvalueInDai(uint256 _pairCode, uint256 _LP) public view returns (uint256) {
        (,address pairPoolAddress,) = yieldFarming.getPairPool(_pairCode);
    
        uint256 totalSupply = IUniswapV2Pair(pairPoolAddress).totalSupply();
        uint256 percentLPinYieldFarm = _LP.mul(base18).div(totalSupply);
        
        uint256 totalKtyInPairPool = IERC20(kittieFightTokenAddr).balanceOf(pairPoolAddress);

        return totalKtyInPairPool.mul(2).mul(percentLPinYieldFarm).mul(KTY_DAI_price())
               .div(base18).div(base18);
    }

    function getWalletBalance(address _staker, uint256 _pairCode) external view returns (uint256) {
        (,address pairPoolAddress,) = yieldFarming.getPairPool(_pairCode);
        return IUniswapV2Pair(pairPoolAddress).balanceOf(_staker);
    }

    function isProgramActive() external view returns (bool) {
        return block.timestamp >= yieldFarming.programStartAt() && block.timestamp <= yieldFarming.programEndAt();
    }

    // Getters Uniswap

    /**
     * @dev returns the amount of reserves for the two tokens in uniswap pair contract.
     */
    function getReserve(address _tokenA, address _tokenB, address _pairPool)
        public view returns (uint256 reserveA, uint256 reserveB)
    {
        IUniswapV2Pair pair = IUniswapV2Pair(_pairPool);
        address token0 = pair.token0();
        if (token0 == _tokenA) {
            (reserveA,,) = pair.getReserves();
            (,reserveB,) = pair.getReserves();
        } else if (token0 == _tokenB) {
            (,reserveA,) = pair.getReserves();
            (reserveB,,) = pair.getReserves();
        }
    }

    /**
     * @dev returns the KTY to ether price on uniswap, that is, how many ether for 1 KTY
     */
    function KTY_ETH_price() public view returns (uint256) {
        uint256 _amountKTY = 1e18;  // 1 KTY
        (uint256 _reserveKTY, uint256 _reserveETH) = getReserve(kittieFightTokenAddr, wethAddr, ktyWethPair);
        return UniswapV2Library.getAmountIn(_amountKTY, _reserveETH, _reserveKTY);
    } 

    /**
     * @dev returns the ether KTY price on uniswap, that is, how many KTYs for 1 ether
     */
    function ETH_KTY_price() public view returns (uint256) {
        uint256 _amountETH = 1e18;  // 1 KTY
        (uint256 _reserveKTY, uint256 _reserveETH) = getReserve(kittieFightTokenAddr, wethAddr, ktyWethPair);
        return UniswapV2Library.getAmountIn(_amountETH, _reserveKTY, _reserveETH);
    }

    /**
     * @dev returns the DAI to ether price on uniswap, that is, how many ether for 1 DAI
     */
    function DAI_ETH_price() public view returns (uint256) {
        uint256 _amountDAI = 1e18;  // 1 KTY
        (uint256 _reserveDAI, uint256 _reserveETH) = getReserve(daiAddr, wethAddr, daiWethPair);
        return UniswapV2Library.getAmountIn(_amountDAI, _reserveETH, _reserveDAI);
    }

    /**
     * @dev returns the ether to DAI price on uniswap, that is, how many DAI for 1 ether
     */
    function ETH_DAI_price() public view returns (uint256) {
        uint256 _amountETH = 1e18;  // 1 KTY
        (uint256 _reserveDAI, uint256 _reserveETH) = getReserve(daiAddr, wethAddr, daiWethPair);
        return UniswapV2Library.getAmountIn(_amountETH, _reserveDAI, _reserveETH);
    }

    /**
     * @dev returns the KTY to DAI price derived from uniswap price in pair contracts, that is, how many DAI for 1 KTY
     */
    function KTY_DAI_price() public view returns (uint256) {
        // get the amount of ethers for 1 KTY
        uint256 etherPerKTY = KTY_ETH_price();
        // get the amount of DAI for 1 ether
        uint256 daiPerEther = ETH_DAI_price();
        // get the amount of DAI for 1 KTY
        uint256 daiPerKTY = etherPerKTY.mul(daiPerEther).div(base18);
        return daiPerKTY;
    }

    /**
     * @dev returns the DAI to KTY price derived from uniswap price in pair contracts, that is, how many KTY for 1 DAI
     */
    function DAI_KTY_price() public view returns (uint256) {
        // get the amount of ethers for 1 DAI
        uint256 etherPerDAI = DAI_ETH_price();
        // get the amount of KTY for 1 ether
        uint256 ktyPerEther = ETH_KTY_price();
        // get the amount of KTY for 1 DAI
        uint256 ktyPerDAI = etherPerDAI.mul(ktyPerEther).div(base18);
        return ktyPerDAI;
    }
   
}

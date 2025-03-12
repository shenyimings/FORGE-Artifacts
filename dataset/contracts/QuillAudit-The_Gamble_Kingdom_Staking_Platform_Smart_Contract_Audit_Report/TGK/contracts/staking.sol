// SPDX-License-Identifier: MIT
pragma solidity =0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

interface IUniswapV2Pair {

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

}

interface IETHPrice{
   function getLatestPrice() external view returns(int);
}

contract StakingPlatform is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;

    uint256 public APY;

    uint256 public fees = 700;

    uint256 public stakingDuration;
    uint256 public  stakingMax;

    uint256 public startPeriod;
    uint256 public lockupPeriod;
    uint256 public endPeriod;

    uint256 public rewarded;
    address[] public stakers;
    mapping(address => bool) public hasStaked;

    uint256 public _totalStaked;
    uint256 internal _precision = 1E6;

    mapping(address => uint256) public staked;
    mapping(address => uint256) private _rewardsToClaim;
    mapping(address => uint256) private _userStartTime;
    mapping(address => uint256) private _userLastTime;

    IUniswapV2Pair public pairContract;
    IETHPrice public ETHPrice;
    uint256 public _index;

    uint256 public minimumStakingPrice = 4700000000000000000;
    uint256 public classicPrice = 5000000000000000000;
    uint256 public silverPrice = 10000000000000000000;
    uint256 public goldPrice = 15000000000000000000;
    uint256 public diamondPrice = 20000000000000000000;

    mapping(string => uint256) public tierUserLimit;
    mapping(string => uint256) public tierUsers;


    event Deposit(address indexed owner, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);
    event WithdrawAndFeesPaid(address indexed owner, uint256 amount, uint256 fees);
    event Claim(address indexed stakeHolder, uint256 amount);
    event ResidualWithdraw(uint256 amount);
    event StartStaking(uint256 startPeriod, uint256 endingPeriod);
    event minimumStakingPriceUpdated(uint256 amount);
    event classicPriceUpdated(uint256 price);
    event SilverPriceUpdated(uint256 price);
    event GoldPriceUpdated(uint256 price);
    event DiamondPriceUpdated(uint256 price);
    event PairContractUpdated(address pair);
    event TokenAddressUpdated(address token);
    event ETHOracleUpdated(IETHPrice price);
    event APYUpdated(uint256 apy);
    event UpdateFees(uint256 fees);
    event EndTimeUpdated(uint256 end, uint256 duration);
    event LockUpPeriodUpdated(uint256 period);
    event MaxStakeUpdated(uint256 max);
    event PrecisionUpdated(uint256 precision);
    event RewardsStaked(address user, uint256 amount);
    event UserLimitUpdated(string level, uint256 limit);

    /**
     * @notice constructor contains all the parameters of the staking platform
     * @dev all parameters are 
     */
    constructor(
        address _token,
        uint256 _APY,
        uint256 _duration,
        uint _maxAmountStaked,
        address pair,
        address oracle,
        uint256 holdingPeriod
    ) {
        stakingDuration = _duration;
        token = IERC20(_token);
        APY = _APY;
        stakingMax = _maxAmountStaked;
        startPeriod = block.timestamp;
        lockupPeriod = holdingPeriod;
        endPeriod = block.timestamp + stakingDuration;
        pairContract = IUniswapV2Pair(pair);
          ETHPrice = IETHPrice(oracle);
        (address token0, ) = (pairContract.token0(), pairContract.token1());
        _index = _token == token0 ? 0 : 1;
        tierUserLimit["classic"] = 2000;
        tierUserLimit["silver"] = 1000;
        tierUserLimit["gold"] = 500;
        tierUserLimit["diamond"] = 200;

        emit StartStaking(startPeriod,  endPeriod);
       
    }
    

    function UpdateMinimumStakingPrice(uint256 price) external onlyOwner{
       
       minimumStakingPrice = price;
       emit minimumStakingPriceUpdated (price);

    }
    
    function UpdateclassicPrice(uint256 price) external onlyOwner{
       
       classicPrice = price;
       emit classicPriceUpdated (price);
       
    }

    function updateUserLimit(string memory level, uint256 limit) external onlyOwner{

        tierUserLimit[level] = limit;
        emit UserLimitUpdated(level, limit);

    }

    function UpdateSilverPrice(uint256 price) external onlyOwner{
       
       silverPrice = price;
       emit SilverPriceUpdated (price);
       
    }

    function UpdateGoldPrice(uint256 price) external onlyOwner{
       
       goldPrice = price;
       emit GoldPriceUpdated (price);
       
    }

    function UpdateDiamondPrice(uint256 price) external onlyOwner{
       
       diamondPrice = price;
       emit DiamondPriceUpdated (price);
       
    }

    function UpdatePairContract(address pair) external onlyOwner{
       
       pairContract = IUniswapV2Pair(pair);
       (address token0, ) = (pairContract.token0(), pairContract.token1());
        _index = token == IERC20(token0) ? 0 : 1;
       emit PairContractUpdated (pair);
       
    }


    function updateTokenAddress(address _token) external onlyOwner{

        token = IERC20(_token);
        emit TokenAddressUpdated(_token);

    }

    function updateETHOracle(IETHPrice oracle) external onlyOwner{

        ETHPrice = oracle;
        emit ETHOracleUpdated(oracle);

    }

    function updateAPY(uint256 apy) external onlyOwner{

        APY = apy;
        emit APYUpdated(apy);

    }

    function updateFee(uint256 fee) external onlyOwner{

        fees = fee;
        emit UpdateFees(fee);

    }

    function updateEndPeriod(uint256 duration) external onlyOwner{

        stakingDuration = duration;
        endPeriod = startPeriod + duration;
        emit EndTimeUpdated(endPeriod, duration);

    }
   
    function updateLockUpPeriod(uint256 period) external onlyOwner{

        lockupPeriod = period;
        emit LockUpPeriodUpdated(period);

    }

    function updateMaxStake(uint256 max) external onlyOwner{

        stakingMax = max;
        emit MaxStakeUpdated(max);

    }
    
    function updatePrecision(uint256 precision) external onlyOwner{

        _precision = precision;
        emit PrecisionUpdated( precision);

    }
    

    function getTokensFromPrice(uint256 requiredPrice) public view returns(uint256 amount){
       uint256 price = TgkPriceInUSD();
       return(requiredPrice*(10**18)/price);
    }

    function TgkPriceInUSD() public view returns(uint256){
        (uint112 reserve0, uint112 reserve1, ) = pairContract.getReserves();
        uint256 _ETHPrice = uint256(ETHPrice.getLatestPrice());
       uint256 price = _index == 0? (reserve1*(10**8))/(reserve0): (reserve0*(10**8))/(reserve1);
        
        return(price*(_ETHPrice));
    }



    function getUserLevel(address user) public view returns(string memory level){
        if(staked[user]>=getTokensFromPrice(minimumStakingPrice) && staked[user]<getTokensFromPrice(silverPrice)){
            return("classic");
        }
        else if(staked[user]>=getTokensFromPrice(silverPrice) && staked[user]<getTokensFromPrice(goldPrice))
            return("Silver");
        else if(staked[user]>=getTokensFromPrice(goldPrice) && staked[user]<getTokensFromPrice(diamondPrice))
            return("Gold");
        else if(staked[user]>=getTokensFromPrice(diamondPrice))
            return("Diamond");
    }

    function getStakers() external view returns(uint256 length){
        return(stakers.length);
    }
   
    function deposit(uint256 amount) external {
        require(amount >= getTokensFromPrice(minimumStakingPrice),"Amount Too Low");
        require(
            endPeriod == 0 || endPeriod > block.timestamp,
            "Staking period ended"
        );
        require(
            _totalStaked + amount <= stakingMax,
            "Amount staked exceeds MaxStake"
        );
        require(amount > 0, "Amount must be greater than 0");
        if(hasStaked[_msgSender()] == false ){
            stakers.push(_msgSender());
            hasStaked[_msgSender()] = true;
        }

        if (_userStartTime[_msgSender()] == 0) {
            _userStartTime[_msgSender()] = block.timestamp;
        }

        _userLastTime[msg.sender] = block.timestamp;

        _updateRewards();

        staked[_msgSender()] += amount;
        _totalStaked += amount;
        token.safeTransferFrom(_msgSender(), address(this), amount);
        string memory level = getUserLevel(_msgSender());
        tierUsers[level] += 1;
        require(tierUserLimit[level] >= tierUsers[level],"User limit Exceeded");
        emit Deposit(_msgSender(), amount);
    }

    function canWithdrawWithoutFees(address user) external view returns(bool){
        return(block.timestamp >= _userLastTime[user] + lockupPeriod);
    }

   
    function withdraw(uint256 amount) external {
        require(
            block.timestamp >= _userLastTime[msg.sender] + lockupPeriod,
            "No withdraw until lockup ends"
        );
        require(amount > 0, "Amount must be greater than 0");
        require(
            amount <= staked[_msgSender()],
            "Amount higher than stakedAmount"
        );
        string memory level = getUserLevel(_msgSender());
        tierUsers[level] -= 1;

        _updateRewards();
        if (_rewardsToClaim[_msgSender()] > 0) {
            _claimRewards();
        }
        _totalStaked -= amount;
        staked[_msgSender()] -= amount;
        token.safeTransfer(_msgSender(), amount);
        string memory newLevel = getUserLevel(_msgSender());
        tierUsers[newLevel] += 1;

        emit Withdraw(_msgSender(), amount);
    }

    function withdrawAndPayFees(uint256 amount) external {
        require(
            block.timestamp <= _userLastTime[msg.sender] + lockupPeriod,
            "Already Unlocked"
        );
        require(amount > 0, "Amount must be greater than 0");
        require(
            amount <= staked[_msgSender()],
            "Amount higher than stakedAmount"
        );
        string memory level = getUserLevel(_msgSender());
        tierUsers[level] -= 1;

        _updateRewards();
        if (_rewardsToClaim[_msgSender()] > 0) {
            _claimRewards();
        }
        _totalStaked -= amount;
        staked[_msgSender()] -= amount;
        uint256 _fees = amount*fees/10000;
        token.safeTransfer(_msgSender(), amount - _fees);
        string memory newLevel = getUserLevel(_msgSender());
        tierUsers[newLevel] += 1;

        emit WithdrawAndFeesPaid(_msgSender(), amount - _fees, _fees);
    }

    
    function withdrawAll() external {
        require(
            block.timestamp >= _userLastTime[msg.sender] + lockupPeriod,
            "No withdraw until lockup ends"
        );
        string memory level = getUserLevel(_msgSender());
        tierUsers[level] -= 1;

        _updateRewards();
        if (_rewardsToClaim[_msgSender()] > 0) {
            _claimRewards();
        }

        _userStartTime[_msgSender()] = 0;
        _userLastTime[_msgSender()] = 0;
        _totalStaked -= staked[_msgSender()];
        uint256 stakedBalance = staked[_msgSender()];
        staked[_msgSender()] = 0;
        token.safeTransfer(_msgSender(), stakedBalance);

        emit Withdraw(_msgSender(), stakedBalance);
    }

    function withdrawAllAndPayFees() external {
        require(
            block.timestamp <= _userLastTime[msg.sender] + lockupPeriod,
            "Already Unlocked"
        );
        string memory level = getUserLevel(_msgSender());
        tierUsers[level] -= 1;

        _updateRewards();
        if (_rewardsToClaim[_msgSender()] > 0) {
            _claimRewards();
        }

        _userStartTime[_msgSender()] = 0;
        _userLastTime[_msgSender()] = 0;
        _totalStaked -= staked[_msgSender()];
        uint256 stakedBalance = staked[_msgSender()];
        staked[_msgSender()] = 0;
        uint256 _fees = stakedBalance*fees/10000;
        token.safeTransfer(_msgSender(), stakedBalance - _fees);

        emit WithdrawAndFeesPaid(_msgSender(), stakedBalance - _fees, _fees);
    }

    /**
     * @notice claim all remaining balance on the contract
     * Residual balance is all the remaining tokens that have not been distributed
     * (e.g, in case the number of stakeholders is not sufficient)
     * @dev Can only be called one year after the end of the staking period
     * Cannot claim initial stakeholders deposit
     */
    function withdrawResidualBalance() external onlyOwner {
        require(
            endPeriod < block.timestamp,
            "Staking period not ended"
        );
        uint256 balance = token.balanceOf(address(this));
        uint256 residualBalance = balance - (_totalStaked);
        require(residualBalance > 0, "No residual Balance to withdraw");
        token.safeTransfer(owner(), residualBalance);
        emit ResidualWithdraw(residualBalance);
    }

    /**
     * @notice function that returns the amount of total Staked tokens
     * for a specific user
     * @param stakeHolder, address of the user to check
     * @return uint256 amount of the total deposited Tokens by the caller
     */
    function amountStaked(address stakeHolder)
        external
        view
        returns (uint256)
    {
        return staked[stakeHolder];
    }

    /**
     * @notice function that returns the amount of total Staked tokens
     * on the smart contract
     * @return uint256 amount of the total deposited Tokens
     */
    function totalDeposited() external view returns (uint256) {
        return _totalStaked;
    }

    /**
     * @notice function that returns the amount of pending rewards
     * that can be claimed by the user
     * @param stakeHolder, address of the user to be checked
     * @return uint256 amount of claimable rewards
     */
    function rewardOf(address stakeHolder)
        external
        view
        returns (uint256)
    {
        return _calculateRewards(stakeHolder);
    }

    /**
     * @notice function that claims pending rewards
     * @dev transfer the pending rewards to the `msg.sender`
     */
    function claimRewards() external {
        _claimRewards();
    }

    function stakeReward() external {
        _rewardsToClaim[_msgSender()] = _calculateRewards(_msgSender());
        _userStartTime[_msgSender()] = (block.timestamp >= endPeriod)
            ? endPeriod
            : block.timestamp;
        uint256 rewardsToClaim = _rewardsToClaim[_msgSender()];
        require(rewardsToClaim > 0, "Nothing to claim");
        _rewardsToClaim[_msgSender()] = 0;
        rewarded += rewardsToClaim;
        token.safeTransfer(address(this), rewardsToClaim);
        require(
            _totalStaked + rewardsToClaim <= stakingMax,
            "Amount staked exceeds MaxStake"
        );

        if (_userStartTime[_msgSender()] == 0) {
            _userStartTime[_msgSender()] = block.timestamp;
        }

        _userLastTime[msg.sender] = block.timestamp;

        _updateRewards();

        staked[_msgSender()] += rewardsToClaim;
        _totalStaked += rewardsToClaim;

        string memory level = getUserLevel(_msgSender());
        tierUsers[level] += 1;
        require(tierUserLimit[level] >= tierUsers[level],"User limit Exceeded");

        emit RewardsStaked(_msgSender(), rewardsToClaim);

    }

    /**
     * @notice calculate rewards based on the `APY`, `_percentageTimeRemaining()`
     * @dev the higher is the precision and the more the time remaining will be precise
     * @param stakeHolder, address of the user to be checked
     * @return uint256 amount of claimable tokens of the specified address
     */
    function _calculateRewards(address stakeHolder)
        internal
        view
        returns (uint256)
    {
        if (staked[stakeHolder] == 0) {
            return 0;
        }

        return
            (((staked[stakeHolder] * APY) *
                _percentageTimeRemaining(stakeHolder)) / (_precision * 100)) +
            _rewardsToClaim[stakeHolder];
    }


    function _percentageTimeRemaining(address stakeHolder)
        internal
        view
        returns (uint256)
    {
    
        uint256 startTime;
        if (endPeriod > block.timestamp) {
            startTime = _userStartTime[stakeHolder];
            uint256 timeRemaining = stakingDuration -
                (block.timestamp - startTime);
            return
                (_precision * (stakingDuration - timeRemaining)) /
                stakingDuration;
        }
        startTime = stakingDuration - (endPeriod - _userStartTime[stakeHolder]);
        return (_precision * (stakingDuration - startTime)) / stakingDuration;
    }

    function _claimRewards() private {
        _updateRewards();

        uint256 rewardsToClaim = _rewardsToClaim[_msgSender()];
        require(rewardsToClaim > 0, "Nothing to claim");

        _rewardsToClaim[_msgSender()] = 0;
        rewarded += rewardsToClaim;
        token.safeTransfer(_msgSender(), rewardsToClaim);
        emit Claim(_msgSender(), rewardsToClaim);
    }

    function _updateRewards() private {
        _rewardsToClaim[_msgSender()] = _calculateRewards(_msgSender());
        _userStartTime[_msgSender()] = (block.timestamp >= endPeriod)
            ? endPeriod
            : block.timestamp;
    }
}

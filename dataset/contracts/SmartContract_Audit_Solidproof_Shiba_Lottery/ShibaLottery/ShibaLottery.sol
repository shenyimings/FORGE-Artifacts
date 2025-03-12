/**
 * Shiba Lottery Contract V2 - Dec 2021
 * Website: https://shibalottery.io
 * TG: https://t.me/ShibaLotteryOfficial
 */

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * SAFEMATH LIBRARY
 */
library SafeMath {

    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        if (b > a) return (false, 0);
        return (true, a - b);
    }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
    unchecked {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    unchecked {
        require(b <= a, errorMessage);
        return a - b;
    }
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    unchecked {
        require(b > 0, errorMessage);
        return a / b;
    }
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    unchecked {
        require(b > 0, errorMessage);
        return a % b;
    }
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function getOwner() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address _owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Auth {
    address internal owner;
    mapping(address => bool) internal authorizations;

    constructor(address _owner) {
        owner = _owner;
        authorizations[_owner] = true;
    }

    /**
     * Function modifier to require caller to be contract owner
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER");
        _;
    }

    /**
     * Function modifier to require caller to be authorized
     */
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED");
        _;
    }

    /**
     * Authorize address. Owner only
     */
    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
    }

    /**
     * Remove address' authorization. Owner only
     */
    function unauthorize(address adr) public onlyOwner {
        authorizations[adr] = false;
    }

    /**
     * Check if address is owner
     */
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    /**
     * Return address' authorization status
     */
    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    /**
     * Transfer ownership to new address. Caller must be owner. Leaves old owner authorized
     */
    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }

    event OwnershipTransferred(address owner);
}

interface IPancakeVault {
    function enterStaking(uint256 _amount) external;

    function leaveStaking(uint256 _amount) external;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    function userInfo(uint256 _poolId, address _user) external returns (uint256 amount, uint256 rewardDebt);
}

interface IPancakeFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IPancakeRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract ShibaLottery is IBEP20, Auth {
    using SafeMath for uint256;
    enum PrizeStatus {OPEN, CLAIMED}

    event ConvertFee(uint256 dailyFee, uint256 weeklyFee);
    event Buyback(uint256 amount);
    event Stacking(address addressStake, uint256 amountStake);

    address public WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public SHIBA = 0x2859e4544C4bB03966803b044A93563Bd2D0DD4D;
    address public CAKE_VAULT = 0x73feaa1eE314F8c655E354234017bE2193C9E24E;
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    IBEP20 BUSD = IBEP20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IBEP20 CAKE = IBEP20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IBEP20 REWARD_TOKEN = IBEP20(SHIBA);

    string constant _name = "Shiba Lottery";
    string constant _symbol = "SLOT";
    uint8 constant _decimals = 18;

    uint256 _totalSupply = 1_000_000_000 * (10 ** _decimals);

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;

    IPancakeRouter public router;
    IPancakeVault public vault;
    address public pair;
    mapping(address => bool) isFeeExempt;
    address public devAddress;
    address public marketingAddress;

    // struct Pool
    struct Locker {
        address addressUser;
        uint256 totalLocked;
    }

    mapping(uint64 => mapping(address => Locker)) public dailyLocker;
    mapping(uint64 => mapping(address => Locker)) public weeklyLocker;

    // struct use to generate ticket for holder
    struct UserTicket {
        uint32 startTicket;
        uint32 endTicket;
    }

    // struct use to record prize each round
    struct PrizeLottery {
        uint32 luckyNumber;
        address winnerAddress;
        uint256 prizeAmount;
        PrizeStatus status;
    }

    bool processingDrawDailyLottery = false;
    bool processingDrawWeeklyLottery = false;
    uint64 public currentDailyLotteryId = 0; // daily round
    uint64 public currentWeeklyLotteryId = 0; // weekly round
    uint32 public currentDailyTicket = 0; // save current ticket that issued for daily lottery
    uint32 public currentWeeklyTicket = 0; // save current ticket that issued for weekly lottery
    mapping(uint64 => mapping(address => UserTicket[])) public dailyTicket;
    mapping(uint64 => mapping(address => UserTicket[])) public weeklyTicket;
    mapping(uint64 => PrizeLottery[]) public dailyWinner;
    mapping(uint64 => PrizeLottery[]) public weeklyWinner;

    // prizes percent
    uint8[13] prizePercent = [uint8(50), 20, 10, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    uint8 public devPercent = 5;
    uint8 public burnPercent = 5;
    uint8 public marketingPercent = 5;
    uint8 public prizeDenominator = 100;
    uint8 totalPrizes = 13;
    uint256[] public historyDailyAmountPrize;
    uint256[] public historyWeeklyAmountPrize;
    uint256 public prevDailyAmountPrize = 0;
    uint256 public dailyAmountPrize;

    // fee for each transaction
    uint8 public feeInDailyPool = 2;
    uint8 public feeInWeeklyPool = 8;
    uint8 public totalFee = 10;
    uint8 feeDenominator = 100;

    uint256 public launchedAt;
    uint256 public launchedAtTimestamp;

    bool inSwap;
    modifier swapping() {inSwap = true;
        _;
        inSwap = false;}

    constructor (

    ) Auth(msg.sender) {
        router = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IPancakeFactory(router.factory()).createPair(WBNB, address(this));
        _allowances[address(this)][address(router)] = _totalSupply;
        WBNB = router.WETH();
        vault = IPancakeVault(CAKE_VAULT);

        isFeeExempt[msg.sender] = true;

        approve(address(router), _totalSupply);
        approve(address(pair), _totalSupply);
        CAKE.approve(address(router), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        CAKE.approve(CAKE_VAULT, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    function totalSupply() external view override returns (uint256) {return _totalSupply;}

    function decimals() external pure override returns (uint8) {return _decimals;}

    function symbol() external pure override returns (string memory) {return _symbol;}

    function name() external pure override returns (string memory) {return _name;}

    function getOwner() external view override returns (address) {return owner;}

    function balanceOf(address account) public view override returns (uint256) {return _balances[account];}

    function allowance(address holder, address spender) external view override returns (uint256) {return _allowances[holder][spender];}

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, _totalSupply);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != _totalSupply) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if (inSwap) {return _basicTransfer(sender, recipient, amount);}

        checkLockToken(sender, amount);

        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        uint256 amountReceived = shouldTakeFee(sender) ? takeFee(sender, amount) : amount;

        _balances[recipient] = _balances[recipient].add(amountReceived);

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        return true;
    }

    function checkLockToken(address sender, uint256 amount) internal view {
        uint256 availableToken = _balances[sender];
        Locker memory dailyLockerInfo = dailyLocker[currentDailyLotteryId][sender];
        if (dailyLockerInfo.totalLocked > 0) {
            availableToken = availableToken.sub(dailyLockerInfo.totalLocked);
        }
        Locker memory weeklyLockerInfo = weeklyLocker[currentWeeklyLotteryId][sender];
        if (weeklyLockerInfo.totalLocked > 0) {
            availableToken = availableToken.sub(weeklyLockerInfo.totalLocked);
        }
        require(availableToken >= amount, "Insufficient Balance");
    }

    function shouldTakeFee(address sender) internal view returns (bool) {
        return !isFeeExempt[sender];
    }

    function getFee() public view returns (uint256) {
        if (launchedAt == 0 || launchedAt + 1 >= block.number) {return feeDenominator - 1;}
        return totalFee;
    }

    function takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = amount.mul(getFee()).div(feeDenominator);

        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        return amount.sub(feeAmount);
    }

    function swapFeeToBNB(uint256 amount) internal {
        address[] memory pathFee = new address[](2);
        pathFee[0] = address(this);
        pathFee[1] = WBNB;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            pathFee,
            address(this),
            block.timestamp
        );
        emit Transfer(address(this), pair, amount);
    }

    function convertFee() external swapping authorized {
        require(processingDrawDailyLottery, "Enable processing flag");
        uint256 tokenAmount = _balances[address(this)];
        uint256 dailyFeeAmount = tokenAmount.mul(feeInDailyPool).div(totalFee);
        uint256 weeklyFeeAmount = tokenAmount.mul(feeInWeeklyPool).div(totalFee);

        // snapshot amount for daily prize
        dailyAmountPrize = dailyFeeAmount;

        // swap weekly fee to WBNB
        swapFeeToBNB(weeklyFeeAmount);

        emit ConvertFee(dailyFeeAmount, weeklyFeeAmount);
    }

    function launched() internal view returns (bool) {
        return launchedAt != 0;
    }

    /**
    * @dev Function to set block start launch project
    */
    function launch() external authorized {
        require(launchedAt == 0, "Already launched boi");
        launchedAt = block.number;
        launchedAtTimestamp = block.timestamp;
    }

    function setIsFeeExempt(address holder, bool exempt) external authorized {
        isFeeExempt[holder] = exempt;
    }

    function setFees(uint8 _feeInDailyPool, uint8 _feeInWeeklyPool, uint8 _feeDenominator) external authorized {
        feeInDailyPool = _feeInDailyPool;
        feeInWeeklyPool = _feeInWeeklyPool;
        totalFee = _feeInDailyPool + _feeInWeeklyPool;
        feeDenominator = _feeDenominator;
        require(totalFee < feeDenominator / 4);
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }
    //-------------------- daily lottery --------------------//

    /**
    * @dev Function to holder commit token into daily lottery pool.
    * Holder commit token will receive ticket to join draw daily lottery.
    *
    * @param lotteryId - current daily lottery
    * @param amount - number token that holder commit into daily pool
    */
    function stakeDailyLottery(uint64 lotteryId, uint256 amount) external returns (bool){
        require(msg.sender != address(0), "Stake from the zero address");
        require(currentDailyLotteryId == lotteryId, "LotteryId invalidate");
        require(!processingDrawDailyLottery, "Time for draw lottery");

        checkLockToken(msg.sender, amount);
        uint32 numberTicket = uint32(amount.div(10 ** _decimals));
        require(numberTicket >= 1, "Amount invalid");

        // record to lock token
        Locker memory lockerInfo = dailyLocker[currentDailyLotteryId][msg.sender];
        if (lockerInfo.totalLocked > 0) {
            lockerInfo.totalLocked = lockerInfo.totalLocked.add(amount);
            dailyLocker[currentDailyLotteryId][msg.sender] = lockerInfo;
        } else {
            dailyLocker[currentDailyLotteryId][msg.sender] = Locker(msg.sender, amount);
        }

        emit Stacking(msg.sender, amount);

        // assign ticket number
        uint32 endTicket = currentDailyTicket + numberTicket;
        dailyTicket[currentDailyLotteryId][msg.sender].push(UserTicket(currentDailyTicket, endTicket - 1));
        currentDailyTicket = endTicket;
        return true;
    }

    /**
    * @dev Function to determine who will win the daily lottery
   *
   */
    function dailyDrawLottery() external onlyOwner {
        require(processingDrawDailyLottery, "Enable processing flag");
        require(dailyAmountPrize > 0, "Prize amount not grater than zero");
        require(currentDailyTicket > 0, "Do not have any user stake");
        require(devAddress != address(0), "Dev address is zero");

        // draw lucky number, first number is present for first prize and so on
        for (uint i = 0; i < totalPrizes; i++) {
            uint32 luckyNum = uint32(random(i).mod(currentDailyTicket));
            uint256 prizeAmount = dailyAmountPrize.mul(prizePercent[i]).div(prizeDenominator);
            dailyWinner[currentDailyLotteryId].push(PrizeLottery(luckyNum, address(0), prizeAmount, PrizeStatus.OPEN));
        }

        // add dev fee to maintain system
        uint256 devAmount = dailyAmountPrize.mul(devPercent).div(prizeDenominator);
        _balances[devAddress] = _balances[devAddress].add(devAmount);
        _balances[address(this)] = _balances[address(this)].sub(devAmount);

        emit Transfer(address(this), devAddress, devAmount);

        // burn 5% token
        uint256 burnAmount = dailyAmountPrize.mul(burnPercent).div(prizeDenominator);
        _balances[DEAD] = _balances[DEAD].add(burnAmount);
        _balances[address(this)] = _balances[address(this)].sub(burnAmount);

        emit Transfer(address(this), DEAD, burnAmount);

        prevDailyAmountPrize = dailyAmountPrize.sub(devAmount).sub(burnAmount);
        historyDailyAmountPrize.push(dailyAmountPrize);
        dailyAmountPrize = 0;
        currentDailyTicket = 0;
        currentDailyLotteryId = currentDailyLotteryId + 1;
        processingDrawDailyLottery = false;
    }

    /**
    * @dev Function to holder claim reward of daily lottery
    *
    * @param lotteryId - this Id of round that holder win daily lottery.
    * @param luckyNumber - ticket number of holder that win daily lottery.
    */
    function claimDailyReward(uint64 lotteryId, uint32 luckyNumber) external {
        require(msg.sender != address(0), "Claim reward from the zero address");
        require(!processingDrawDailyLottery, "Time for draw lottery.");
        require(currentDailyLotteryId - 1 == lotteryId, "Lottery ID invalid");

        uint256 totalAmountPrize = 0;
        PrizeLottery[] memory lstPrizeLottery = dailyWinner[lotteryId];
        for (uint i = 0; i < lstPrizeLottery.length; i++) {
            if (lstPrizeLottery[i].luckyNumber == luckyNumber && lstPrizeLottery[i].status == PrizeStatus.OPEN) {
                UserTicket[] memory userTickets = dailyTicket[lotteryId][msg.sender];
                for (uint j = 0; j < userTickets.length; j++) {
                    if (userTickets[j].startTicket <= luckyNumber && luckyNumber <= userTickets[j].endTicket) {
                        totalAmountPrize = totalAmountPrize.add(lstPrizeLottery[i].prizeAmount);
                        dailyWinner[lotteryId][i].winnerAddress = msg.sender;
                        dailyWinner[lotteryId][i].status = PrizeStatus.CLAIMED;
                    }
                }
            }
        }
        require(totalAmountPrize > 0, "Lucky number is invalid");

        _balances[msg.sender] = _balances[msg.sender].add(totalAmountPrize);
        _balances[address(this)] = _balances[address(this)].sub(totalAmountPrize);
        prevDailyAmountPrize = prevDailyAmountPrize.sub(totalAmountPrize);

        emit Transfer(address(this), msg.sender, totalAmountPrize);
    }

    /**
    * @dev Function return list ticket of holder
    */
    function getDailyTicket(uint64 lotteryId) external view returns (UserTicket[] memory) {
        require(msg.sender != address(0), "Get ticket from the zero address");

        return dailyTicket[lotteryId][msg.sender];
    }

    /**
    * @dev Function return list winner of the lottery
    */
    function getDailyWinner(uint64 lotteryId) external view returns (uint32[] memory) {
        require(lotteryId < currentDailyLotteryId, "Lottery Id invalid");

        uint32[] memory result = new uint32[](totalPrizes);
        PrizeLottery[] memory lstPrizeLottery = dailyWinner[lotteryId];
        for (uint i = 0; i < lstPrizeLottery.length; i++) {
            result[i] = lstPrizeLottery[i].luckyNumber;
        }
        return result;
    }

    /**
    * @dev Function return detail about locker token of msg.sender
    */
    function getDailyLockerInfo() external view returns (bool, uint256){
        require(msg.sender != address(0), "Get locker from the zero address");

        Locker memory lockerInfo = dailyLocker[currentDailyLotteryId][msg.sender];
        if (lockerInfo.totalLocked <= 0) {
            return (false, 0);
        } else {
            return (true, lockerInfo.totalLocked);
        }
    }

    /**
    * @dev Function return current daily reward
    */
    function getCurrentDailyReward() external view returns (uint256) {
        uint256 prevAmount = currentDailyLotteryId == 0 ? 0 : prevDailyAmountPrize;

        if (processingDrawDailyLottery) {
            return dailyAmountPrize;
        }
        uint256 currentPrize = _balances[address(this)].sub(prevAmount);

        return currentPrize == 0 ? currentPrize : currentPrize.mul(feeInDailyPool).div(totalFee);
    }

    /**
    * @dev Function return list of daily reward
    * @param to - index that want to get info from here
    * @param offset - length of list daily reward
    */
    function getListDailyReward(uint64 to, uint64 offset) external view returns (uint256[] memory){
        require(to < currentDailyLotteryId, "Invalidate to index");
        require(offset <= 10, "Invalidate offset");
        require(offset > 0, "Invalidate offset");

        uint64 from = 0;
        if (offset == 1) {
            from = to;
        }
        if (to < offset) {
            from = 0;
        } else {
            from = to - offset + 1;
        }
        uint64 index = 0;
        uint256[] memory result = new uint256[](offset);
        for (uint64 i = from; i <= to; i++) {
            result[index] = historyDailyAmountPrize[i];
            index = index + 1;
        }

        return result;
    }

    /**
    * @dev Function to set status of draw daily lottery
    */
    function setDailyDrawFlag(bool enable) external authorized {
        processingDrawDailyLottery = processingDrawDailyLottery == enable ? processingDrawDailyLottery : enable;
    }

    /**
    * @dev Function to check status of array luck number
    */
    function checkDailyReward(uint64 lotteryId, uint32[] memory luckyNumbers) external view returns (bool[] memory){
        require(luckyNumbers.length == totalPrizes, "Input invalid");
        require(lotteryId < currentDailyLotteryId, "Lottery Id invalid");

        PrizeLottery[] memory lstPrize = dailyWinner[lotteryId];
        bool[] memory result = new bool[](totalPrizes);
        for (uint i = 0; i < totalPrizes; i++) {
            bool status = lstPrize[i].status == PrizeStatus.CLAIMED ? true : false;
            result[i] = status;
        }
        return result;
    }
    //-------------------- end: daily lottery --------------------//

    //-------------------- weekly lottery --------------------//

    /**
    * @dev Function to holder commit token into weekly lottery pool.
    * Holder commit token will receive ticket to join draw weekly lottery.
    *
    * @param lotteryId - current weekly lottery
    * @param amount - number token that holder commit into weekly pool
    */
    function stakeWeeklyLottery(uint64 lotteryId, uint256 amount) external returns (bool){
        require(msg.sender != address(0), "Stake from the zero address");
        require(currentWeeklyLotteryId == lotteryId, "LotteryId invalidate");
        require(!processingDrawWeeklyLottery, "Time for draw lottery.");

        checkLockToken(msg.sender, amount);
        uint32 numberTicket = uint32(amount.div(10 ** _decimals));
        require(numberTicket >= 1, "Amount invalid");

        Locker memory lockerInfo = weeklyLocker[currentWeeklyLotteryId][msg.sender];
        if (lockerInfo.totalLocked > 0) {
            lockerInfo.totalLocked = lockerInfo.totalLocked.add(amount);
            weeklyLocker[currentWeeklyLotteryId][msg.sender] = lockerInfo;
        } else {
            weeklyLocker[currentWeeklyLotteryId][msg.sender] = Locker(msg.sender, amount);
        }

        emit Stacking(msg.sender, amount);

        // assign ticket number
        uint32 endTicket = currentWeeklyTicket + numberTicket;
        weeklyTicket[currentWeeklyLotteryId][msg.sender].push(UserTicket(currentWeeklyTicket, endTicket - 1));
        currentWeeklyTicket = endTicket;

        return true;
    }

    /**
    * @dev Function to determine who will win the weekly lottery
    *
    */
    function weeklyDrawLottery() external onlyOwner {
        require(processingDrawWeeklyLottery, "Enable processing flag");
        require(currentWeeklyTicket > 0, "Do not have any user stake");
        require(devAddress != address(0), "Dev address is zero");
        require(marketingAddress != address(0), "Marketing address is zero");

        uint256 weeklyPrizeAmount = REWARD_TOKEN.balanceOf(address(this));
        require(weeklyPrizeAmount > 0, "Reward not enough");

        // draw lucky number, first number is present for first prize and so on
        for (uint i = 0; i < totalPrizes; i++) {
            uint32 luckyNum = uint32(random(i).mod(currentWeeklyTicket));
            uint256 prizeAmount = weeklyPrizeAmount.mul(prizePercent[i]).div(prizeDenominator);
            weeklyWinner[currentWeeklyLotteryId].push(PrizeLottery(luckyNum, address(0), prizeAmount, PrizeStatus.OPEN));
        }

        // transfer 5% for dev
        uint256 devAmount = weeklyPrizeAmount.mul(devPercent).div(prizeDenominator);
        REWARD_TOKEN.transfer(devAddress, devAmount);

        // transfer 5% for marketing
        uint256 marketingAmount = weeklyPrizeAmount.mul(marketingPercent).div(prizeDenominator);
        REWARD_TOKEN.transfer(marketingAddress, marketingAmount);

        historyWeeklyAmountPrize.push(weeklyPrizeAmount);
        currentWeeklyTicket = 0;
        currentWeeklyLotteryId = currentWeeklyLotteryId + 1;
        processingDrawWeeklyLottery = false;
    }

    /**
    * @dev Function to holder claim reward of weekly lottery
    *
    * @param lotteryId - this Id of round that holder win weekly lottery.
    * @param luckyNumber - ticket number of holder that win weekly lottery.
    */
    function claimWeeklyReward(uint64 lotteryId, uint32 luckyNumber) external {
        require(msg.sender != address(0), "Claim reward from the zero address");
        require(!processingDrawWeeklyLottery, "Time for draw lottery.");
        require(currentWeeklyLotteryId - 1 == lotteryId, "Lottery ID invalid");

        uint256 totalAmountPrize = 0;
        PrizeLottery[] memory lstPrizeLottery = weeklyWinner[lotteryId];
        for (uint i = 0; i < lstPrizeLottery.length; i++) {
            if (lstPrizeLottery[i].luckyNumber == luckyNumber && lstPrizeLottery[i].status == PrizeStatus.OPEN) {
                UserTicket[] memory userTickets = weeklyTicket[lotteryId][msg.sender];
                for (uint j = 0; j < userTickets.length; j++) {
                    if (userTickets[j].startTicket <= luckyNumber && luckyNumber <= userTickets[j].endTicket) {
                        totalAmountPrize = totalAmountPrize.add(lstPrizeLottery[i].prizeAmount);
                        weeklyWinner[lotteryId][i].status = PrizeStatus.CLAIMED;
                        weeklyWinner[lotteryId][i].winnerAddress = msg.sender;
                    }
                }
            }
        }
        require(totalAmountPrize > 0, "Lucky number is invalid");

        // Transfer weekly reward for winner
        REWARD_TOKEN.transfer(msg.sender, totalAmountPrize);
    }

    /**
    * @dev Function return list ticket of holder
    */
    function getWeeklyTicket(uint64 lotteryId) external view returns (UserTicket[] memory) {
        require(msg.sender != address(0), "Get ticket from the zero address");

        return weeklyTicket[lotteryId][msg.sender];
    }

    /**
    * @dev Function return list winner of the lottery
    */
    function getWeeklyWinner(uint64 lotteryId) external view returns (uint32[] memory) {
        require(lotteryId < currentWeeklyLotteryId, "Invalidate lotteryId");

        uint32[] memory result = new uint32[](totalPrizes);
        PrizeLottery[] memory lstPrizeLottery = weeklyWinner[lotteryId];
        for (uint i = 0; i < lstPrizeLottery.length; i++) {
            result[i] = lstPrizeLottery[i].luckyNumber;
        }
        return result;
    }

    /**
    * @dev Function return detail about locker weekly token of msg.sender
    */
    function getWeeklyLockerInfo() external view returns (bool, uint256){
        require(msg.sender != address(0), "Get locker from the zero address");

        Locker memory lockerInfo = weeklyLocker[currentWeeklyLotteryId][msg.sender];
        if (lockerInfo.totalLocked <= 0) {
            return (false, 0);
        } else {
            return (true, lockerInfo.totalLocked);
        }
    }

    /**
    * @dev Function to set status of draw weekly lottery
    */
    function setWeeklyDrawFlag(bool enable) external authorized {
        processingDrawWeeklyLottery = processingDrawWeeklyLottery == enable ? processingDrawWeeklyLottery : enable;
    }

    /**
    * @dev Function to check status of array luck number
    */
    function checkWeeklyReward(uint64 lotteryId, uint32[] memory luckyNumbers) external view returns (bool[] memory){
        require(luckyNumbers.length == totalPrizes, "Input invalid");
        require(lotteryId < currentWeeklyLotteryId, "Lottery Id invalid");

        bool[] memory result = new bool[](totalPrizes);
        PrizeLottery[] memory lstPrize = weeklyWinner[lotteryId];
        for (uint i = 0; i < totalPrizes; i++) {
            bool status = lstPrize[i].status == PrizeStatus.CLAIMED ? true : false;
            result[i] = status;
        }
        return result;
    }

    /**
    * @dev Function return list of weekly reward
    * @param to - index that want to get info from here
    * @param offset - length of list weekly reward
    */
    function getListWeeklyReward(uint64 to, uint64 offset) external view returns (uint256[] memory){
        require(to < currentWeeklyLotteryId, "Invalidate to index");
        require(offset <= 10, "Invalidate offset");
        require(offset > 0, "Invalidate offset");

        uint64 from = 0;
        if (offset == 1) {
            from = to;
        }
        if (to < offset) {
            from = 0;
        } else {
            from = to - offset + 1;
        }
        uint64 index = 0;
        uint256[] memory result = new uint256[](offset);
        for (uint64 i = from; i <= to; i++) {
            result[index] = historyWeeklyAmountPrize[i];
            index = index + 1;
        }

        return result;
    }

    //-------------------- end: weekly lottery --------------------//


    function random(uint index) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, index)));
    }

    function setDevAddress(address _devAddress) external authorized {
        require(_devAddress != address(0), "Address set zero");

        devAddress = _devAddress;
    }

    function setMarketingAddress(address _marketingAddress) external authorized {
        require(_marketingAddress != address(0), "Address set zero");

        marketingAddress = _marketingAddress;
    }

    // stake in manual cake pool
    function stakeCake() internal {
        uint256 cakeAmount = CAKE.balanceOf(address(this));
        vault.enterStaking(cakeAmount);
    }

    // buy & stake cake
    function buyAndStakeCake() external authorized {
        // buy cake
        uint256 balance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(CAKE);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value : balance}(
            0,
            path,
            address(this),
            block.timestamp
        );

        // stake cake
        stakeCake();
    }

    function getCakeStaked() internal returns (uint256) {
        (uint256 cakeStakedAmount, uint256 rewardDebt) = vault.userInfo(0, (address(this)));
        return cakeStakedAmount;
    }

    // unstake cake and convert weekly prize
    function unstakeCakeAndConvertWeeklyPrize(uint256 prizePercentage, uint256 buybackPercentage, uint256 compoundStakePercentage) external authorized {
        require(processingDrawWeeklyLottery, "Enable processing flag");
        require(prizePercentage.add(buybackPercentage).add(compoundStakePercentage) == 100, "Wrong percentage!");
        // unstake cake
        vault.leaveStaking(getCakeStaked());

        uint256 cakeAmount = CAKE.balanceOf(address(this));
        // convert to weekly prize
        if (prizePercentage > 0) {
            uint256 prizeAmount = cakeAmount.mul(prizePercentage).div(100);

            address[] memory pathPrize = new address[](2);
            pathPrize[0] = address(CAKE);
            pathPrize[1] = address(REWARD_TOKEN);

            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                prizeAmount,
                0,
                pathPrize,
                address(this),
                block.timestamp
            );
        }

        // convert to buyback
        if (buybackPercentage > 0) {
            uint256 buybackAmount = cakeAmount.mul(buybackPercentage).div(100);

            address[] memory pathBuyback = new address[](2);
            pathBuyback[0] = address(CAKE);
            pathBuyback[1] = WBNB;

            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                buybackAmount,
                0,
                pathBuyback,
                address(this),
                block.timestamp
            );
            buyback();
        }

        // stake cake remaining
        stakeCake();
    }

    function buyback() internal swapping {
        uint256 balance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value : balance}(
            0,
            path,
            DEAD,
            block.timestamp
        );
        emit Buyback(balance);
    }

    function approveCake() external authorized {
        CAKE.approve(address(router), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        CAKE.approve(CAKE_VAULT, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    function setRewardToken(address _rewardToken) external authorized {
        require(_rewardToken != address(0), "Address set zero");

        if (address(REWARD_TOKEN) != _rewardToken) {
            REWARD_TOKEN = IBEP20(_rewardToken);
        }
    }

    function getRewardToken() external view returns (address) {
        return address(REWARD_TOKEN);
    }

    function withdrawBNB(uint256 amount) external authorized {
        payable(msg.sender).transfer(amount);
    }

    function drainToken(address _token, uint256 amount) external authorized {
        require(_token != address(0), "Invalidate token address");
        require(devAddress != address(0), "Dev address is zero");

        IBEP20 token = IBEP20(_token);
        uint256 tokenBalance = token.balanceOf(address(this));

        require(tokenBalance >= amount, "Insufficient amount");

        token.transfer(devAddress, tokenBalance);
    }

    function setPrizePercent(uint8[] memory _prizePercent, uint8 _devPercent, uint8 _marketingPercent, uint8 _burnPercent, uint8 _prizeDenominator) external authorized {
        require(_prizePercent.length == totalPrizes, "Invalidate _prizePercent");

        devPercent = _devPercent;
        marketingPercent = _marketingPercent;
        burnPercent = _burnPercent;
        prizeDenominator = _prizeDenominator;

        uint8 totalPrizesPercent = 0;
        for (uint8 i = 0; i < _prizePercent.length; i++) {
            prizePercent[i] = _prizePercent[i];
            totalPrizesPercent = totalPrizesPercent + _prizePercent[i];
        }

        require(totalPrizesPercent + devPercent + burnPercent == prizeDenominator);
        require(totalPrizesPercent + devPercent + marketingPercent == prizeDenominator);
    }

    function getPrizePercent() external view returns (uint8[13] memory){
        return prizePercent;
    }
}
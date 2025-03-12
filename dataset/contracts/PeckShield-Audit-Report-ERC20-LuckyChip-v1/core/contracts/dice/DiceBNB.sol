// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IBEP20.sol";
import "../interfaces/IWBNB.sol";
import "../interfaces/IDice.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/ILuckyChipRouter02.sol";
import "../interfaces/IBetMining.sol";
import "../interfaces/ILuckyPower.sol";
import "../interfaces/IRandomGenerator.sol";
import "../libraries/SafeBEP20.sol";
import "../token/DiceToken.sol";
import "../token/LCToken.sol";

contract DiceBNB is IDice, Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    uint256 public prevBankerAmount;
    uint256 public bankerAmount;
    uint256 public netValue;
    uint256 public currentEpoch;
    uint256 public playerEndBlock;
    uint256 public bankerEndBlock;
    uint256 public totalDevAmount;
    uint256 public totalBurnAmount;
    uint256 public totalBonusAmount;
    uint256 public totalLotteryAmount;
    uint256 public intervalBlocks;
    uint256 public playerTimeBlocks;
    uint256 public bankerTimeBlocks;
    uint256 public constant TOTAL_RATE = 10000; // 100%
    uint256 public gapRate = 200; // 2% for non-lc table
    uint256 public devRate = 500; // 5% in gap
    uint256 public burnRate = 500; // 5% in gap
    uint256 public bonusRate = 2000; // 20% in gap
    uint256 public lotteryRate = 500; // 5% in gap
    uint256 public minBetAmount;
    uint256 public maxBetRatio = 5;
    uint256 public maxLostRatio = 300;
    uint256 public feeAmount;
    uint256 public maxBankerAmount;
    uint256 public maxWithdrawFeeRatio = 20; // 0.2% for withdrawFee
    uint256 public fullyWithdrawTh = 1000; //the threshold to judge whether a user can withdraw fully, default 10%

    // for private dice
    uint256 public privateFeeAmount; // Fee amount for private dice
    uint256 public privateGapRate = 300;// Private gap rate, default 3%
    uint256 public minPrivateBetAmount; // Minimum private bet amount
    uint256 public maxPrivateBetRatio = 100; // Maximum private bet amount

    address public adminAddr;
    address public devAddr;
    address public lotteryAddr;
    IOracle public oracle;
    ILuckyPower public luckyPower;
    address public immutable WBNB;
    LCToken public lcToken;
    DiceToken public diceToken;    
    ILuckyChipRouter02 public swapRouter;
    IBetMining public betMining;
    IRandomGenerator public randomGenerator;

    enum Status {
        Pending,
        Open,
        Locked,
        Claimable,
        Expired
    }

    struct Round {
        uint256 startBlock;
        uint256 lockBlock;
        uint256 secretSentBlock;
        uint256 totalAmount;
        uint256 maxBetAmount;
        uint256[6] betAmounts;
        uint256 burnAmount;
        uint256 bonusAmount;
        uint256 lotteryAmount;
        uint256 betUsers;
        uint8 finalNumber;
        Status status;
    }

    struct BetInfo {
        uint256 amount;
        uint16 numberCount;    
        bool[6] numbers;
        bool claimed; // default false
    }

    struct BankerInfo {
        uint256 diceTokenAmount;
        uint256 avgBuyValue;
    }

    // Info of each private bet.
    struct Bet {
        // Block number
        uint256 blockNumber;
        // Address of a gambler, used to pay out winning bets.
        address gambler;
        // Wager amount in wei.
        uint256 amount;
        // Win amount.
        uint256 winAmount;
        // Final number
        uint8 finalNumber;
        // selected number
        bool[6] numbers;
        // Status of bet settlement
        bool isSettled;
    }

    // for private dice
    Bet[] public bets;
    mapping(uint256 => uint) public betMap; // Mapping requestId returned by Chainlink VRF to bet Id.
    mapping(address => uint256[]) public userBets;

    // for public dice
    mapping(uint256 => Round) public rounds;    
    mapping(uint256 => uint256) public roundMap; // Mapping requestId returned by Chainlink VRF to round Id.
    mapping(uint256 => mapping(address => BetInfo)) public ledger;
    mapping(address => uint256[]) public userRounds;
    mapping(address => BankerInfo) public bankerInfo;

    event SetAdmin(address adminAddr, address devAddr, address lotteryAddr);
    event SetBlocks(uint256 playerTimeBlocks, uint256 bankerTimeBlocks);
    event SetRates(uint256 gapRate, uint256 privateGapRate, uint256 devRate, uint256 burnRate, uint256 bonusRate, uint256 lotteryRate);
    event SetAmounts(uint256 minBetAmount, uint256 feeAmount, uint256 maxBankerAmount, uint256 minPrivateFeeAmount, uint256 minPrivateBetAmount);
    event SetRatios(uint256 maxBetRatio, uint256 maxLostRatio, uint256 withdrawFeeRatio, uint256 maxPrivateBetRatio);
    event SetSwapRouter(address indexed swapRouterAddr);
    event SetOracle(address indexed oracleAddr);
    event SetLuckyPower(address indexed luckyPowerAddr);
    event SetBetMining(address indexed betMiningAddr);
    event SetRandomGenerator(address indexed randomGeneratorAddr);
    event StartRound(uint256 indexed epoch);
    event LockRound(uint256 indexed epoch);
    event SendSecretRound(uint256 indexed epoch, uint8 finalNumber);
    event BetNumber(address indexed sender, uint256 indexed currentEpoch, bool[6] numbers, uint256 amount);
    event ClaimReward(address indexed sender, uint256 amount);
    event RewardsCalculated(uint256 indexed epoch, uint256 burnAmount, uint256 bonusAmount,uint256 lotteryAmount);
    event EndPlayerTime(uint256 epoch);
    event EndBankerTime(uint256 epoch);
    event UpdateNetValue(uint256 epoch, uint256 netValue);
    event Deposit(address indexed user, uint256 tokenAmount);
    event Withdraw(address indexed user, uint256 diceTokenAmount);

    event PrivateBetPlaced(uint256 indexed betId, address gambler, address referrer, uint256 amount, bool[6] numbers);
    event PrivateBetSettled(uint256 indexed betId, address indexed gambler, uint256 amount, uint256 winAmount, bool[6] numbers, uint8 finalNumber);
    event PrivateBetRefunded(uint256 indexed betId, address indexed gambler, uint256 amount);

    constructor(
        address _WBNBAddr,
        address _lcTokenAddr,
        address _diceTokenAddr,
        address _luckyPowerAddr,
        address _randomGeneratorAddr,
        address _devAddr,
        address _lotteryAddr,
        uint256 _intervalBlocks,
        uint256 _playerTimeBlocks,
        uint256 _bankerTimeBlocks,
        uint256 _minBetAmount,
        uint256 _feeAmount,
        uint256 _maxBankerAmount,
        uint256 _minPrivateBetAmount,
        uint256 _privateFeeAmount
    ) public {
        WBNB = _WBNBAddr;
        lcToken = LCToken(_lcTokenAddr);
        diceToken = DiceToken(_diceTokenAddr);
        luckyPower = ILuckyPower(_luckyPowerAddr);
        randomGenerator = IRandomGenerator(_randomGeneratorAddr);
        devAddr = _devAddr;
        lotteryAddr = _lotteryAddr;
        intervalBlocks = _intervalBlocks;
        playerTimeBlocks = _playerTimeBlocks;
        bankerTimeBlocks = _bankerTimeBlocks;
        minBetAmount = _minBetAmount;
        feeAmount = _feeAmount;
        maxBankerAmount = _maxBankerAmount;
        minPrivateBetAmount = _minPrivateBetAmount;
        privateFeeAmount = _privateFeeAmount;
        netValue = uint256(1e12);
        _pause();
    }

    fallback() external payable {}
    receive() external payable {}

    modifier notContract() {
        require((!_isContract(msg.sender)) && (msg.sender == tx.origin), "no contract");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddr, "not admin");
        _;
    }

    // set blocks
    function setBlocks(uint256 _intervalBlocks, uint256 _playerTimeBlocks, uint256 _bankerTimeBlocks) external onlyAdmin {
        intervalBlocks = _intervalBlocks;
        playerTimeBlocks = _playerTimeBlocks;
        bankerTimeBlocks = _bankerTimeBlocks;
        emit SetBlocks(playerTimeBlocks, bankerTimeBlocks);
    }

    // set rates
    function setRates(uint256 _gapRate, uint256 _privateGapRate, uint256 _devRate, uint256 _burnRate, uint256 _bonusRate, uint256 _lotteryRate) external onlyAdmin {
        require(_gapRate <= 1000 && _privateGapRate <= 1000 && _devRate.add(_burnRate).add(_bonusRate).add(_lotteryRate) <= TOTAL_RATE, "rate limit");
        gapRate = _gapRate;
        privateGapRate = _privateGapRate;
        devRate = _devRate;
        burnRate = _burnRate;
        bonusRate = _bonusRate;
        lotteryRate = _lotteryRate;
        emit SetRates(gapRate, privateGapRate, devRate, burnRate, bonusRate, lotteryRate);
    }

    // set amounts
    function setAmounts(uint256 _minBetAmount, uint256 _feeAmount, uint256 _maxBankerAmount, uint256 _privateFeeAmount, uint256 _minPrivateBetAmount) external onlyAdmin {
        minBetAmount = _minBetAmount;
        feeAmount = _feeAmount;
        maxBankerAmount = _maxBankerAmount;
        privateFeeAmount = _privateFeeAmount;
        minPrivateBetAmount = _minPrivateBetAmount;
        emit SetAmounts(minBetAmount, feeAmount, maxBankerAmount, privateFeeAmount, minPrivateBetAmount);
    }

    // set ratios
    function setRatios(uint256 _maxBetRatio, uint256 _maxLostRatio, uint256 _maxWithdrawFeeRatio, uint256 _maxPrivateBetRatio) external onlyAdmin {
        require(_maxBetRatio <= 50 && _maxLostRatio <= 500 && _maxWithdrawFeeRatio <= 100 && maxPrivateBetRatio <= 500, "ratio limit");
        maxBetRatio = _maxBetRatio;
        maxLostRatio = _maxLostRatio;
        maxWithdrawFeeRatio = _maxWithdrawFeeRatio;
        maxPrivateBetRatio = _maxPrivateBetRatio;
        emit SetRatios(maxBetRatio, maxLostRatio, maxWithdrawFeeRatio, maxPrivateBetRatio);
    }

    // set admin address
    function setAdmin(address _adminAddr, address _devAddr, address _lotteryAddr) external onlyOwner {
        require(_adminAddr != address(0) && _devAddr != address(0) && _lotteryAddr != address(0), "Zero");
        adminAddr = _adminAddr;
        devAddr = _devAddr;
        lotteryAddr = _lotteryAddr;
        emit SetAdmin(adminAddr, devAddr, lotteryAddr);
    }

    // Update the swap router.
    function setSwapRouter(address _router) external onlyAdmin {
        swapRouter = ILuckyChipRouter02(_router);
        emit SetSwapRouter(_router);
    }

    // Update the oracle.
    function setOracle(address _oracleAddr) external onlyAdmin {
        oracle = IOracle(_oracleAddr);
        emit SetOracle(_oracleAddr);
    }

    // Update the lucky power.
    function setLuckyPower(address _luckyPowerAddr) external onlyAdmin {
        luckyPower = ILuckyPower(_luckyPowerAddr);
        emit SetLuckyPower(_luckyPowerAddr);
    }

    // Update the bet mining.
    function setBetMining(address _betMiningAddr) external onlyAdmin {
        betMining = IBetMining(_betMiningAddr);
        emit SetBetMining(_betMiningAddr);
    }

    // Update the random generator.
    function setRandomGenerator(address _randomGeneratorAddr) external onlyAdmin {
        require(_randomGeneratorAddr != address(0), "Zero");
        randomGenerator = IRandomGenerator(_randomGeneratorAddr);
        emit SetRandomGenerator(_randomGeneratorAddr);
    }

    function setFullyWithdrawTh(uint256 _fullyWithdrawTh) external onlyAdmin {
        require(_fullyWithdrawTh <= 5000, "range"); // maximum 50%
        fullyWithdrawTh = _fullyWithdrawTh;
    }

    // End banker time
    function endBankerTime(uint256 epoch) external onlyAdmin whenPaused {
        require(epoch == currentEpoch + 1, "Epoch");
        require(bankerAmount > 0, "bankerAmount gt 0");
        prevBankerAmount = bankerAmount;
        _unpause();
        emit EndBankerTime(currentEpoch);
        
        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        playerEndBlock = rounds[currentEpoch].startBlock.add(playerTimeBlocks);
        bankerEndBlock = rounds[currentEpoch].startBlock.add(bankerTimeBlocks);
    }

    // Start the next round n, lock for round n-1
    function executeRound(uint256 epoch) external onlyAdmin whenNotPaused{
        // CurrentEpoch refers to previous round (n-1)
        lockRound(epoch);

        // Increment currentEpoch to current round (n)
        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        require(rounds[currentEpoch].startBlock < playerEndBlock && rounds[currentEpoch].lockBlock <= playerEndBlock, "playerTime");
    }

    // Lock round.
    function lockRound(uint256 epoch) public onlyAdmin whenNotPaused {
        // CurrentEpoch refers to previous round (n-1)
        require(epoch == currentEpoch, "Epoch");
        require(block.number >= rounds[currentEpoch].lockBlock && block.number <= rounds[currentEpoch].lockBlock.add(intervalBlocks), "Within interval");
        rounds[currentEpoch].status = Status.Locked;

        // Get Random Number
        uint256 requestId = randomGenerator.getRandomNumber();
        roundMap[requestId] = currentEpoch;

        emit LockRound(epoch);
    }

    // end player time, triggers banker time
    function endPlayerTime(uint256 epoch) external onlyAdmin whenNotPaused{
        require(epoch == currentEpoch, "epoch");
        _pause();
        netValue = netValue.mul(bankerAmount).div(prevBankerAmount);
        emit UpdateNetValue(epoch, netValue);
        _claimBonusAndLottery();
        emit EndPlayerTime(currentEpoch);
    }

    // send bankSecret
    function sendSecret(uint256 requestId, uint256 randomNumber) public override whenNotPaused{
        require(msg.sender == address(randomGenerator), "Only RandomGenerator");

        uint256 epoch = roundMap[requestId];
        Round storage round = rounds[epoch];
        if(round.status == Status.Locked && block.number >= round.lockBlock && block.number <= round.lockBlock.add(intervalBlocks)){
            _safeSendSecret(epoch, randomNumber);
            _calculateRewards(epoch);
        }
    }

    function _safeSendSecret(uint256 epoch, uint256 randomNumber) internal whenNotPaused {
        Round storage round = rounds[epoch];
        round.secretSentBlock = block.number;
        round.finalNumber = uint8(randomNumber % 6);
        round.status = Status.Claimable;

        emit SendSecretRound(epoch, round.finalNumber);
    }

    // bet number
    function betNumber(bool[6] calldata numbers, address referrer) external payable whenNotPaused notContract nonReentrant {
        Round storage round = rounds[currentEpoch];
        require(msg.value >= feeAmount, "FeeAmount");
        require(round.status == Status.Open, "Not Open");
        require(block.number > round.startBlock && block.number < round.lockBlock, "Not bettable");
        require(ledger[currentEpoch][msg.sender].amount == 0, "Bet once");
        uint16 numberCount = 0;
        for (uint32 i = 0; i < 6; i ++) {
            if (numbers[i]) {
                numberCount = numberCount + 1;    
            }
        }
        require(numberCount > 0, "numberCount > 0");
        uint256 amount = msg.value.sub(feeAmount);
        require(amount >= minBetAmount.mul(uint256(numberCount)) && amount <= round.maxBetAmount.mul(uint256(numberCount)), "range limit");
        uint256 maxBetAmount = 0;
        uint256 betAmount = amount.div(uint256(numberCount));
        for (uint32 i = 0; i < 6; i ++) {
            if (numbers[i]) {
                if(round.betAmounts[i].add(betAmount) > maxBetAmount){
                    maxBetAmount = round.betAmounts[i].add(betAmount);
                }
            }else{
                if(round.betAmounts[i] > maxBetAmount){
                    maxBetAmount = round.betAmounts[i];
                }
            }
        }

        if(maxBetAmount.mul(6) > round.totalAmount.add(amount).sub(maxBetAmount)){
            require(maxBetAmount.mul(6).sub(round.totalAmount.add(amount).sub(maxBetAmount)) < bankerAmount.mul(maxLostRatio).div(TOTAL_RATE), 'MaxLost Limit');
        }
        
        if (feeAmount > 0){
            _safeTransferBNB(adminAddr, feeAmount);
        }

        // Update round data
        round.totalAmount = round.totalAmount.add(amount);
        round.betUsers = round.betUsers.add(1);
        for (uint32 i = 0; i < 6; i ++) {
            if (numbers[i]) {
                round.betAmounts[i] = round.betAmounts[i].add(betAmount);
            }
        }

        // Update user data
        BetInfo storage betInfo = ledger[currentEpoch][msg.sender];
        betInfo.numbers = numbers;
        betInfo.amount = amount;
        betInfo.numberCount = numberCount;
        userRounds[msg.sender].push(currentEpoch);

        if(address(betMining) != address(0)){
            betMining.bet(msg.sender, referrer, WBNB, amount);
        }

        emit BetNumber(msg.sender, currentEpoch, numbers, amount);
    }

    // Claim reward
    function claimReward() external notContract nonReentrant {
        address user = address(msg.sender);
        (uint256 rewardAmount, uint256 startIndex, uint256 endIndex) = pendingReward(user);

        if (rewardAmount > 0){
            uint256 epoch;
            for(uint256 i = startIndex; i < endIndex; i ++){
                epoch = userRounds[user][i];
                ledger[epoch][user].claimed = true;
            }

            _safeTransferBNB(user, rewardAmount);
            emit ClaimReward(user, rewardAmount);
        }
    }

    // View pending reward
    function pendingReward(address user) public view returns (uint256 rewardAmount, uint256 startIndex, uint256 endIndex) {
        uint256 epoch;
        uint256 roundRewardAmount = 0;
        rewardAmount = 0;
        startIndex = 0;
        endIndex = 0;
        if(userRounds[user].length > 0){
            uint256 i = userRounds[user].length.sub(1);
            while(i >= 0){
                epoch = userRounds[user][i];
                if (ledger[epoch][user].claimed){
                    startIndex = i.add(1);
                    break;
                }
                if(i == 0){
                    break;
                }
                i = i.sub(1);
            }

            endIndex = startIndex;
            for (i = startIndex; i < userRounds[user].length; i ++){
                epoch = userRounds[user][i];
                BetInfo storage betInfo = ledger[epoch][user];
                Round storage round = rounds[epoch];
                if (round.status == Status.Claimable){
                    if(betInfo.numbers[round.finalNumber]){
                        uint256 singleAmount = betInfo.amount.div(uint256(betInfo.numberCount));
                        roundRewardAmount = singleAmount.mul(6).mul(TOTAL_RATE.sub(gapRate)).div(TOTAL_RATE);
                        rewardAmount = rewardAmount.add(roundRewardAmount);
                    }
                    endIndex = endIndex.add(1);
                }else{
                    if(block.number > round.lockBlock.add(intervalBlocks)){
                        rewardAmount = rewardAmount.add(betInfo.amount);
                        endIndex = endIndex.add(1);
                    }else{
                        break;
                    }
                }
            }
        }
    }

    // Claim all bonus to LuckyPower
    function _claimBonusAndLottery() internal {
        uint256 tmpAmount = 0;
        if(totalBurnAmount > 0){
            tmpAmount = totalBurnAmount;
            totalBurnAmount = 0;

            if(address(swapRouter) != address(0)){
                address[] memory path = new address[](2);
                path[0] = WBNB;
                path[1] = address(lcToken);
                uint256 amountOut = swapRouter.getAmountsOut(tmpAmount, path)[1];
                uint256 lcAmount = swapRouter.swapExactETHForTokens{value: tmpAmount}(amountOut.mul(5).div(10), path, address(this), block.timestamp + (5 minutes))[1];
                lcToken.burn(address(this), lcAmount);
            }else{
                totalDevAmount = totalDevAmount.add(tmpAmount);
            }
        }
        if(totalBonusAmount > 0){
            tmpAmount = totalBonusAmount;
            totalBonusAmount = 0;
            if(address(luckyPower) != address(0)){
                IWBNB(WBNB).deposit{value: tmpAmount}();
                assert(IWBNB(WBNB).transfer(address(luckyPower), tmpAmount));
                luckyPower.updateBonus(WBNB, tmpAmount);
            }else{
                totalDevAmount = totalDevAmount.add(tmpAmount);
            }
        }
        if(totalDevAmount > 0){
            tmpAmount = totalDevAmount;
            totalDevAmount = 0;
            _safeTransferBNB(devAddr, tmpAmount);
        }
        if(totalLotteryAmount > 0){
            tmpAmount = totalLotteryAmount;
            totalLotteryAmount = 0;
            _safeTransferBNB(lotteryAddr, tmpAmount);
        }
    }

    function getUserRoundCount(address user) external view returns (uint256){
        return userRounds[user].length;
    }

    // Return round epochs that a user has participated
    function getUserRounds(
        address user,
        uint256 fromIndex,
        uint256 toIndex
    ) external view returns (uint256, uint256[] memory) {
        uint256 realToIndex = toIndex;
        if(realToIndex > userRounds[user].length){
            realToIndex = userRounds[user].length;
        }

        if(fromIndex < realToIndex){
            uint256 length = realToIndex - fromIndex;
            uint256[] memory values = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                values[i] = userRounds[user][fromIndex.add(i)];
            }
            return (length, values);
        }
    }

    // Return user bet info
    function getUserBetInfo(uint256 epoch, address user) external view returns (uint256, uint16, bool[6] memory, bool){
        BetInfo storage betInfo = ledger[epoch][user];
        return (betInfo.amount, betInfo.numberCount, betInfo.numbers, betInfo.claimed);
    }

    // Return betAmounts of a round
    function getRoundBetAmounts(uint256 epoch) external view returns (uint256[6] memory){
        return rounds[epoch].betAmounts;
    }

    function getUserBetCount(address user) external view returns (uint256){
        return userBets[user].length;
    }

    // Return round epochs that a user has participated
    function getUserBets(
        address user,
        uint256 fromIndex,
        uint256 toIndex
    ) external view returns (uint256, uint256[] memory) {
        uint256 realToIndex = toIndex;
        if(realToIndex > userRounds[user].length){
            realToIndex = userRounds[user].length;
        }

        if(fromIndex < realToIndex){
            uint256 length = realToIndex - fromIndex;
            uint256[] memory values = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                values[i] = userBets[user][fromIndex.add(i)];
            }
            return (length, values);
        }
    }

    // Manual Start round. Previous round n-1 must lock
    function manualStartRound() external onlyAdmin whenNotPaused {
        require(block.number >= rounds[currentEpoch].lockBlock, "Manual start");
        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        require(rounds[currentEpoch].startBlock < playerEndBlock && rounds[currentEpoch].lockBlock <= playerEndBlock, "playerTime");
    }

    function _startRound(uint256 epoch) internal {
        Round storage round = rounds[epoch];
        round.startBlock = block.number;
        round.lockBlock = block.number.add(intervalBlocks);
        round.totalAmount = 0;
        round.maxBetAmount = bankerAmount.mul(maxBetRatio).div(TOTAL_RATE);
        round.status = Status.Open;

        emit StartRound(epoch);
    }

    // Calculate rewards for round
    function _calculateRewards(uint256 epoch) internal {
        if(rounds[epoch].bonusAmount == 0){
            Round storage round = rounds[epoch];

            { // avoid stack too deep
                uint256 devAmount = 0;
                uint256 burnAmount = 0;
                
                uint256 tmpAmount = 0;
                uint256 gapAmount = 0;
                uint256 tmpBankerAmount = bankerAmount;
                for (uint32 i = 0; i < 6; i ++){
                    if (i == round.finalNumber){
                        tmpBankerAmount = tmpBankerAmount.sub(round.betAmounts[i].mul(6).mul(TOTAL_RATE.sub(gapRate)).div(TOTAL_RATE));
                        gapAmount = round.betAmounts[i].mul(6).mul(gapRate).div(TOTAL_RATE);
                    }else{
                        tmpBankerAmount = tmpBankerAmount.add(round.betAmounts[i]);
                        gapAmount = round.betAmounts[i].mul(gapRate).div(TOTAL_RATE);
                    }
                    tmpAmount = gapAmount.mul(devRate).div(TOTAL_RATE);
                    devAmount = devAmount.add(tmpAmount);
                    tmpBankerAmount = tmpBankerAmount.sub(tmpAmount);

                    tmpAmount = gapAmount.mul(burnRate).div(TOTAL_RATE);
                    burnAmount = burnAmount.add(tmpAmount);
                    tmpBankerAmount = tmpBankerAmount.sub(tmpAmount);
                }
                
                bankerAmount = tmpBankerAmount;
                round.burnAmount = burnAmount;
                totalBurnAmount = totalBurnAmount.add(burnAmount);
                totalDevAmount = totalDevAmount.add(devAmount);
            }

            { // avoid stack too deep
                uint256 bonusAmount = 0;
                uint256 lotteryAmount = 0;
                
                uint256 tmpAmount = 0;
                uint256 gapAmount = 0;
                uint256 tmpBankerAmount = bankerAmount;
                for (uint32 i = 0; i < 6; i ++){
                    if (i == round.finalNumber){
                        gapAmount = round.betAmounts[i].mul(6).mul(gapRate).div(TOTAL_RATE);
                    }else{
                        gapAmount = round.betAmounts[i].mul(gapRate).div(TOTAL_RATE);
                    }
                    tmpAmount = gapAmount.mul(bonusRate).div(TOTAL_RATE);
                    bonusAmount = bonusAmount.add(tmpAmount);
                    tmpBankerAmount = tmpBankerAmount.sub(tmpAmount);

                    tmpAmount = gapAmount.mul(lotteryRate).div(TOTAL_RATE);
                    lotteryAmount = lotteryAmount.add(tmpAmount);
                    tmpBankerAmount = tmpBankerAmount.sub(tmpAmount);
                }
                bankerAmount = tmpBankerAmount;
                round.bonusAmount = bonusAmount;
                round.lotteryAmount = lotteryAmount;

                totalBonusAmount = totalBonusAmount.add(bonusAmount);
                totalLotteryAmount = totalLotteryAmount.add(lotteryAmount);
            }

            emit RewardsCalculated(epoch, round.burnAmount, round.bonusAmount, round.lotteryAmount);
        }
    }

    // Place bet
    function placePrivateBet(bool[6] calldata numbers, address _referrer) external payable nonReentrant notContract {
        // Validate input data.
        address gambler = msg.sender;
        require(msg.value >= privateFeeAmount, "PrivateFeeAmount");
        uint256 numberCount = 0;
        for (uint32 i = 0; i < 6; i ++) {
            if (numbers[i]) {
                numberCount = numberCount + 1;    
            }
        }
        require(numberCount > 0, "numberCount > 0");
        uint256 amount = msg.value.sub(privateFeeAmount);
        require(amount >= minPrivateBetAmount.mul(numberCount) && amount <= bankerAmount.mul(maxPrivateBetRatio).div(TOTAL_RATE).mul(numberCount), "Range limit");

        // Check whether contract has enough funds to accept this bet.
        require(amount.mul(6).div(numberCount) <= bankerAmount, "Insufficient funds");
        if(privateFeeAmount > 0){
            _safeTransferBNB(adminAddr, privateFeeAmount);
        }

        uint256 requestId = randomGenerator.getRandomNumber();
        betMap[requestId] = bets.length;

        userBets[msg.sender].push(bets.length);

        // Record bet in event logs. Placed before pushing bet to array in order to get the correct bets.length.
        emit PrivateBetPlaced(bets.length, gambler, _referrer, amount, numbers);

        // Store bet in bet list.
        bets.push(Bet(
            {
                blockNumber: block.number,
                gambler: gambler,
                amount: amount,
                winAmount: 0,
                finalNumber: 0,
                numbers: numbers,
                isSettled: false
            }
        ));

        if(address(betMining) != address(0)){
            betMining.bet(msg.sender, _referrer, WBNB, amount);
        }
    }

    // Settle bet. Function can only be called by fulfillRandomness function, which in turn can only be called by Chainlink VRF.
    function settlePrivateBet(uint256 requestId, uint256 randomNumber) external nonReentrant {
        require(msg.sender == address(randomGenerator), "Only RandomGenerator");
        
        uint256 betId = betMap[requestId];
        Bet storage bet = bets[betId];
        uint256 amount = bet.amount;

        if(amount > 0 && bet.isSettled == false){ // Validation checks.
            uint256 winAmount = 0;
            uint8 finalNumber = uint8(randomNumber % 6);
            uint256 numberCount = 0;
            for (uint32 i = 0; i < 6; i ++) {
                if (bet.numbers[i]) {
                    numberCount = numberCount + 1;    
                }
            }

            uint256 gapAmount = 0;
            uint256 tmpBankerAmount = bankerAmount;
            if(bet.numbers[finalNumber]){
                if(numberCount == 1){
                    tmpBankerAmount = tmpBankerAmount.sub(amount.mul(6).mul(TOTAL_RATE.sub(privateGapRate)).div(TOTAL_RATE));
                    gapAmount = amount.mul(6).mul(privateGapRate).div(TOTAL_RATE);
                }else{
                    tmpBankerAmount = tmpBankerAmount.add(amount.mul(numberCount.sub(1)).div(numberCount));
                    gapAmount = amount.mul(numberCount.sub(1)).div(numberCount).mul(privateGapRate).div(TOTAL_RATE);

                    tmpBankerAmount = tmpBankerAmount.sub(amount.mul(6).div(numberCount).mul(TOTAL_RATE.sub(privateGapRate)).div(TOTAL_RATE));
                    gapAmount = amount.mul(6).div(numberCount).mul(privateGapRate).div(TOTAL_RATE);
                }

                winAmount = amount.mul(6).div(numberCount).mul(TOTAL_RATE.sub(privateGapRate)).div(TOTAL_RATE);
                _safeTransferBNB(bet.gambler, winAmount);
            }else{
                tmpBankerAmount = tmpBankerAmount.add(amount);
                gapAmount = amount.mul(privateGapRate).div(TOTAL_RATE);
            }

            uint256 devAmount = gapAmount.mul(devRate).div(TOTAL_RATE);
            totalDevAmount = totalDevAmount.add(devAmount);
            tmpBankerAmount = tmpBankerAmount.sub(devAmount);

            uint256 burnAmount = gapAmount.mul(burnRate).div(TOTAL_RATE);
            totalBurnAmount = totalBurnAmount.add(burnAmount);
            tmpBankerAmount = tmpBankerAmount.sub(burnAmount);

            uint256 bonusAmount = gapAmount.mul(bonusRate).div(TOTAL_RATE);
            totalBonusAmount = totalBonusAmount.add(bonusAmount);
            tmpBankerAmount = tmpBankerAmount.sub(bonusAmount);

            uint256 lotteryAmount = gapAmount.mul(lotteryRate).div(TOTAL_RATE);
            totalLotteryAmount = lotteryAmount.add(lotteryAmount);
            tmpBankerAmount = tmpBankerAmount.sub(lotteryAmount);

            bankerAmount = tmpBankerAmount;
            bet.winAmount = winAmount;
            bet.finalNumber = finalNumber;
            bet.isSettled = true;
            
            // Record bet settlement in event log.
            emit PrivateBetSettled(betId, bet.gambler, amount, winAmount, bet.numbers, finalNumber);
        }
    }

    // Return the bet in the very unlikely scenario it was not settled by Chainlink VRF. 
    // In case you find yourself in a situation like this, just contact Polyroll support.
    // However, nothing precludes you from calling this method yourself.
    function refundBet(uint256 betId) external nonReentrant {
        
        Bet storage bet = bets[betId];
        uint256 amount = bet.amount;

        // Validation checks
        require(amount > 0 && bet.isSettled == false, "No refundable");
        require(block.number > bet.blockNumber + playerTimeBlocks, "Wait before requesting refund");

        // Update bet records
        bet.isSettled = true;
        bet.winAmount = amount;

        // Send the refund.
        _safeTransferBNB(bet.gambler, amount);

        // Record refund in event logs
        emit PrivateBetRefunded(betId, bet.gambler, amount);
    }

    // Deposit token to Dice as a banker, get Syrup back.
    function deposit() public payable whenPaused nonReentrant notContract {
        uint256 _tokenAmount = msg.value;
        require(_tokenAmount > 0, "Amount > 0");
        require(bankerAmount.add(_tokenAmount) < maxBankerAmount, 'maxBankerAmount Limit');
        BankerInfo storage banker = bankerInfo[msg.sender];
        uint256 diceTokenAmount = _tokenAmount.mul(1e12).div(netValue);
        diceToken.mint(address(msg.sender), diceTokenAmount);
        uint256 totalDiceTokenAmount = banker.diceTokenAmount.add(diceTokenAmount);
        banker.avgBuyValue = banker.avgBuyValue.mul(banker.diceTokenAmount).div(1e12).add(_tokenAmount).mul(1e12).div(totalDiceTokenAmount);
        banker.diceTokenAmount = totalDiceTokenAmount;
        bankerAmount = bankerAmount.add(_tokenAmount);
        emit Deposit(msg.sender, _tokenAmount);    
    }

    function getWithdrawFeeRatio(address _user) public view returns (uint256 ratio){
        ratio = 0;
        if(address(luckyPower) != address(0) && address(oracle) != address(0)){
            BankerInfo storage banker = bankerInfo[_user];
            (uint256 totalPower,,,,,) = luckyPower.pendingPower(_user);
            uint256 tokenAmount = banker.diceTokenAmount.mul(netValue).div(1e12);
            uint256 bankerTvl = oracle.getQuantity(WBNB, tokenAmount);
            if(bankerTvl > 0 && fullyWithdrawTh > 0 && totalPower < bankerTvl.mul(fullyWithdrawTh).div(TOTAL_RATE)){
                // y = - x * maxWithdrawFeeRatio / fullyWithdrawTh + maxWithdrawFeeRatio
                uint256 x = totalPower.mul(TOTAL_RATE).div(bankerTvl);
                ratio = maxWithdrawFeeRatio.sub(x.mul(maxWithdrawFeeRatio).div(fullyWithdrawTh));
            }
        }
    }

    // Withdraw syrup from dice to get token back
    function withdraw(uint256 _diceTokenAmount) public whenPaused nonReentrant notContract {
        require(_diceTokenAmount > 0, "diceTokenAmount > 0");
        BankerInfo storage banker = bankerInfo[msg.sender];
        require(_diceTokenAmount <= banker.diceTokenAmount, "diceTokenAmount <= banker.diceTokenAmount");
        uint256 ratio = getWithdrawFeeRatio(msg.sender);
        banker.diceTokenAmount = banker.diceTokenAmount.sub(_diceTokenAmount); 
        SafeBEP20.safeTransferFrom(diceToken, msg.sender, address(diceToken), _diceTokenAmount);
        diceToken.burn(address(diceToken), _diceTokenAmount);
        uint256 tokenAmount = _diceTokenAmount.mul(netValue).div(1e12);
        bankerAmount = bankerAmount.sub(tokenAmount);

        if(ratio > 0){
            uint256 withdrawFee = tokenAmount.mul(ratio).div(TOTAL_RATE);
            if(withdrawFee > 0){
                _safeTransferBNB(devAddr, withdrawFee);
            }
            tokenAmount = tokenAmount.sub(withdrawFee);
        }
        
        if(tokenAmount > 0){
            _safeTransferBNB(address(msg.sender), tokenAmount);
        }
        
        emit Withdraw(msg.sender, _diceTokenAmount);
    }

    // Judge address is contract or not
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    // View function to see banker diceToken Value on frontend.
    function canWithdrawToken(address bankerAddr) external view returns (uint256){
        return bankerInfo[bankerAddr].diceTokenAmount.mul(netValue).div(1e12);    
    }

    // View function to see banker diceToken Value on frontend.
    function canWithdrawAmount(uint256 _amount) external override view returns (uint256){
        return _amount.mul(netValue).div(1e12);    
    }

    function _safeTransferBNB(address to, uint256 value) internal {
        (bool success, ) = to.call{gas: 23000, value: value}("");
        require(success, 'BNB_TRANSFER_FAILED');
    }

    function tokenAddr() public override view returns (address){
        return WBNB;
    }

}


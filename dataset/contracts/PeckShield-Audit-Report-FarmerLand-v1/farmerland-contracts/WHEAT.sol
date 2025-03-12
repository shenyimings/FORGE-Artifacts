pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { FarmerLandNFT } from "./FarmerLandNFT.sol";

contract WHEAT is ERC20, Ownable, ReentrancyGuard {
    ERC20 public constant token_USDC = ERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

    struct RoostInfo {
        address series;
        uint tokenId;
    }

    mapping(address => RoostInfo) public minotaurNFTRoost;

    mapping(address => RoostInfo) public farmerNFTRoost;
    mapping(address => RoostInfo) public landNFTRoost;
    mapping(address => RoostInfo) public toolNFTRoost;

    // Mapping of NFT contract address to which NFTs a user has staked.
    mapping(address => bool) public nftAddressAllowList;

    mapping(address => uint256) public stakeCounts;

    event PercentOfLobbyToBePooledChanged(uint oldPercent, uint newPercent);
    event MCAddressSet(address oldAddress, address newAddress);
    event DaoAddressSet(address oldAddress, address newAddress);
    event LotteryShareSet(uint oldValue, uint newValue);
    event DaoUSDCWHEATShares(uint oldUSDCShare, uint oldUWHEATShare, uint newUSDCShare, uint newWHEATShare);
    event MCUSDCWHEATShares(uint oldUSDCShare, uint oldUWHEATShare, uint newUSDCShare, uint newWHEATShare);
    event LastLobbySet(uint oldValue, uint newValue);
    event DividensPoolCalDaysSet(uint oldValue, uint newValue);
    event LoaningStatusSwitched(bool oldValue, bool newValue);
    event VirtualBalanceEnteringSwitched(bool oldValue, bool newValue);
    event StakeSellingStatusSwitched(bool oldValue, bool newValue);
    event LottyPoolFlushed(address destination, uint amount);
    event DevShareOfStakeSellsFlushed(address destination, uint amount);

    event UserStake(address indexed addr, uint rawAmount, uint duration, uint stakeId);

    event UserStakeCollect(address indexed addr, uint rawAmount, uint stakeId, uint bonusAmount);

    event UserLobby(address indexed addr, uint rawAmount, uint extraAmount, address referrer);

    event UserLobbyCollect(address indexed addr, uint rawAmount, uint day, uint boostedAmount, uint masterchefWHEATShare, uint daoWHEATShare, uint ref_bonus_NR, uint ref_bonus_NRR);

    event StakeSellRequest(address indexed addr, uint price, uint rawAmount, uint stakeId);

    event CancelStakeSellRequest(address indexed addr, uint stakeId);

    event StakeBuyRequest(address indexed seller, uint sellerStakeId, address indexed buyer, uint buyerStakeId, uint tradeAmount);

    event StakeLoanRequest(address indexed addr, uint rawAmount, uint returnAmount, uint duration, uint stakeId);

    event CancelStakeLoanRequest(address indexed addr, uint stakeId);

    event StakeLend(address indexed addr, uint lendId, address indexed loaner, uint stakeId, uint amount);

    event StakeLoanFinished(address indexed lender, uint lendId, address indexed loaner, uint stakeId, uint amount);

    event DayLobbyEntry(uint day, uint value);

    event LotteryWinner(address indexed addr, uint amount, uint lastRecord);

    event LotteryUpdate(uint newPool, uint lastRecord);

    event WithdrawSoldStakeFunds(address indexed addr, uint amount);

    event WithdrawLoanedFunds(address indexed addr, uint amount);

    event NftAddressAllowListSet(address series, bool allowed);

    event NFTRoosted(address series, uint tokenId, uint prevTokenId);

    constructor(
        uint launchTime
    ) ERC20("WHEAT", "WHEAT") {
        LAUNCH_TIME = launchTime;
        _mint(msg.sender, 8500 * 1e18); // 8k for breading event, 500 for promos.
        _updatePercentOfLobbyToBePooled();
    }

    function set_nftMasterChefAddress(address _nftMasterChefAddress) external onlyOwner() {
        require(_nftMasterChefAddress != address(0), "!0");

        address oldNftMasterChefAddress = nftMasterChefAddress;

        nftMasterChefAddress = _nftMasterChefAddress;

        emit  MCAddressSet(oldNftMasterChefAddress, _nftMasterChefAddress);
    }

    /* change team wallets address % */
    function changeDaoAddress(address _daoAddress) external onlyOwner() {
        require(_daoAddress != address(0), "!0");

        address oldDaoAddress = daoAddress;

        daoAddress = _daoAddress;

        emit  DaoAddressSet(oldDaoAddress, _daoAddress);
    }

    address public nftMasterChefAddress;
    address public daoAddress = 0x994aF05EB0eA1Bb37dfEBd2EA279133C8059ffa7; // 10% WHEAT, 5% USDC

    // 2% of lobby entried goto lottery pot
    uint public lottery_share_percentage = 200;

    /* Time of contract launch */
    uint internal immutable LAUNCH_TIME;
    uint public currentDay;

    function _updatePercentOfLobbyToBePooled() private {
        uint oldPercentOfLobbyToBePooled = percentOfLobbyToBePooled;
        percentOfLobbyToBePooled = 10000 - (lottery_share_percentage + masterchefUSDCShare + daoUSDCShare);

        emit PercentOfLobbyToBePooledChanged(oldPercentOfLobbyToBePooled, percentOfLobbyToBePooled);
    }

    function set_lottery_share_percentage(uint _lottery_share_percentage) external onlyOwner() {
        // Max 10%
        require(_lottery_share_percentage <= 1000);

        uint oldLotterySharePercentage = lottery_share_percentage;

        lottery_share_percentage = _lottery_share_percentage;

        _updatePercentOfLobbyToBePooled();

        emit LotteryShareSet(oldLotterySharePercentage, _lottery_share_percentage);
    }

    function set_masterchefUSDCWHEATShare(uint _masterchefUSDCShare, uint _masterchefWHEATShare) external onlyOwner() {
        require(_masterchefUSDCShare <= 1000 && _masterchefWHEATShare <= 1000);

        uint oldMasterchefUSDCShare = masterchefUSDCShare;
        uint oldMasterchefWHEATShare = masterchefWHEATShare;

        masterchefUSDCShare = _masterchefUSDCShare;
        masterchefWHEATShare = _masterchefWHEATShare;

        _updatePercentOfLobbyToBePooled();
        
        emit MCUSDCWHEATShares(oldMasterchefUSDCShare, oldMasterchefWHEATShare, _masterchefUSDCShare, _masterchefWHEATShare);
    }

    function set_daoUSDCWHEATShares(uint _daoUSDCShare, uint _daoWHEATShare) external onlyOwner() {
        require(_daoUSDCShare <= 1000 && _daoWHEATShare <= 1000);

        uint oldDaoUSDCShare = daoUSDCShare;
        uint oldDaoWHEATShare = daoWHEATShare;

        daoUSDCShare = _daoUSDCShare;
        daoWHEATShare = _daoWHEATShare;

        _updatePercentOfLobbyToBePooled();

        emit DaoUSDCWHEATShares(oldDaoUSDCShare, oldDaoWHEATShare, _daoUSDCShare, _daoWHEATShare);
    }

    uint public masterchefUSDCShare = 500;
    uint public masterchefWHEATShare = 1000;

    uint public daoUSDCShare = 500;
    uint public daoWHEATShare = 1000;

    function set_lastLobbyPool(uint _lastLobbyPool) external onlyOwner() {
        uint oldLastLobbyPool = lastLobbyPool;

        lastLobbyPool = _lastLobbyPool;

        emit LastLobbySet(oldLastLobbyPool, _lastLobbyPool);
    }


    mapping(uint => uint) public lobbyPool;
    /* last amount of lobby pool that are minted daily to be distributed between lobby participants which starts from 5k */
    uint public lastLobbyPool = 5050505050505050505051;

    /* Every day's lobby pool is % lower than previous day's */
    uint internal constant lobby_pool_decrease_percentage = 100; // 1%

    /* % of every day's lobby entry to be pooled as divs, default 89.5% = 100% - (5% dao + 5% nft staking + 0.5% lottery) */
    uint public percentOfLobbyToBePooled;

    /* The ratio num for calculating stakes bonus tokens */
    uint internal constant bonus_calc_ratio = 310;

    /* Max staking days */
    uint public constant max_stake_days = 180;

    /* Ref bonus NR 3%*/
    uint public constant ref_bonus_NR = 300;

    /* Refered person bonus NR 2%*/
    uint public constant ref_bonus_NRR = 200;

    function set_dividendsPoolCapDays(uint _dividendsPoolCapDays) external onlyOwner() {
        require(_dividendsPoolCapDays > 0 && _dividendsPoolCapDays <= 300);

        uint oldDividendsPoolCapDays = dividendsPoolCapDays;

        dividendsPoolCapDays = _dividendsPoolCapDays;

        emit DividensPoolCalDaysSet(oldDividendsPoolCapDays, _dividendsPoolCapDays);
    }

    /* dividends pool caps at 50 days, meaning that the lobby entery of days > 50 will only devide for next 60 days and no more */
    uint public dividendsPoolCapDays = 50;

    /* Loaning feature is paused? */
    bool public loaningIsPaused = false;

    /* Stake selling feature is paused? */
    bool public stakeSellingIsPaused = false;

    /* virtual Entering feature is paused? */
    bool public virtualBalanceEnteringIsPaused = false;

    // the last referrer per user
    mapping(address => address) public usersLastReferrer;

    /* ------------------ for the sake of UI statistics ------------------ */
    // lobby memebrs overall data
    struct memberLobby_overallData {
        uint overall_collectedTokens;
        uint overall_lobbyEnteries;
        uint overall_stakedTokens;
        uint overall_collectedDivs;
    }

    // total lobby entry
    uint public overall_lobbyEntry;
    // total staked tokens
    uint public overall_stakedTokens;
    // total lobby token collected
    uint public overall_collectedTokens;
    // total stake divs collected
    uint public overall_collectedDivs;
    // total bonus token collected
    uint public overall_collectedBonusTokens;
    // total referrer bonus paid to an address
    mapping(address => uint) public referrerBonusesPaid;
    // counting unique (unique for every day only) lobby enteries for each day
    mapping(uint => uint) public usersCountDaily;
    // counting unique (unique for every day only) users
    uint public usersCount = 0;
    /* Total ever entered as stake tokens */
    uint public saveTotalToken;
    /* ------------------ for the sake of UI statistics ------------------ */

    /* lobby memebrs data */
    struct memberLobby {
        uint extraVirtualTokens;
        uint entryAmount;
        uint entryDay;
        bool collected;
        address referrer;
    }

    function getMapMemberLobbyEntryByDay(address user, uint day) external view returns (uint) {
        return mapMemberLobby[user][day].entryAmount;
    }

    /* new map for every entry (users are allowed to enter multiple times a day) */
    mapping(address => mapping(uint => memberLobby)) public mapMemberLobby;

    /* day's total lobby entry */
    mapping(uint => uint) public lobbyEntry;

    /* User stakes struct */
    struct memberStake {
        address userAddress;
        uint tokenValue;
        uint startDay;
        uint endDay;
        uint stakeId;
        uint price; // use: sell stake
        uint loansReturnAmount; // total of the loans return amount that have been taken on this stake
        bool collected;
        bool hasSold; // stake been sold ?
        bool forSell; // currently asking to sell stake ?
        bool hasLoan; // is there an active loan on stake ?
        bool forLoan; // currently asking for a loan on the stake ?
    }

    /* A map for each user */
    mapping(address => mapping(uint => memberStake)) public mapMemberStake;

    /* Owner switching the loaning feature status */
    function switchLoaningStatus() external onlyOwner() {
        loaningIsPaused = !loaningIsPaused;

        emit LoaningStatusSwitched(!loaningIsPaused, loaningIsPaused);
    }

    /* Owner switching the virtualBalanceEntering feature status */
    function switchVirtualBalanceEntering() external onlyOwner() {
        virtualBalanceEnteringIsPaused = !virtualBalanceEnteringIsPaused;

        emit VirtualBalanceEnteringSwitched(!virtualBalanceEnteringIsPaused, virtualBalanceEnteringIsPaused);
    }

    /* Owner switching the stake selling feature status */
    function switchStakeSellingStatus() external onlyOwner() {
        stakeSellingIsPaused = !stakeSellingIsPaused;
    
        emit StakeSellingStatusSwitched(!stakeSellingIsPaused, stakeSellingIsPaused);
    }

    /* Flushed lottery pool*/
    function flushLottyPool() external onlyOwner() nonReentrant {
        if (lottery_Pool > 0) {
            uint256 amount = lottery_Pool;
            lottery_Pool = 0;
            token_USDC.transfer(daoAddress, amount);
        
            emit LottyPoolFlushed(daoAddress, amount);
        }
    }

    /**
     * @dev flushes the dev share from stake sells
     */
    function flushDevShareOfStakeSells() external onlyOwner() nonReentrant {
        require(devShareOfStakeSellsAndLoanFee > 0);

        token_USDC.transfer(address(daoAddress), devShareOfStakeSellsAndLoanFee);

        uint oldDevShareOfStakeSellsAndLoanFee = devShareOfStakeSellsAndLoanFee;

        devShareOfStakeSellsAndLoanFee = 0;

        emit DevShareOfStakeSellsFlushed(daoAddress, oldDevShareOfStakeSellsAndLoanFee);
    }

    function _clcDay() public view returns (uint) {
        if (block.timestamp <= LAUNCH_TIME) return 0;
        return (block.timestamp - LAUNCH_TIME) / 1 days;
    }

    function updateDaily() public {
        // this is true once a day
        uint _currentDay = _clcDay();
        if (currentDay != _currentDay) {
            if (currentDay < dividendsPoolCapDays) {
                for (uint _day = currentDay + 1; _day <= (currentDay * 2 + 1); _day++) {
                    dayUSDCPool[_day] += currentDay > 0 ? (lobbyEntry[currentDay] * percentOfLobbyToBePooled) / ((currentDay + 1) * 10000) : 0;
                }
            } else {
                for (uint _day = currentDay + 1; _day <= currentDay + dividendsPoolCapDays; _day++) {
                    dayUSDCPool[_day] += (lobbyEntry[currentDay] * percentOfLobbyToBePooled) / (dividendsPoolCapDays * 10000);
                }
            }

            currentDay = _currentDay;
            _updateLobbyPool();
            lobbyPool[currentDay] = lastLobbyPool;

            // total of 12% from every day's lobby entry goes to:
            // 5% dao + 5% nft masterchef
            _sendShares();
            // 2% lottery
            checkLottery();

            emit DayLobbyEntry(currentDay, lobbyEntry[currentDay - 1]);
        }
    }

    /* Every day's lobby pool reduces by a % */
    function _updateLobbyPool() internal {
        lastLobbyPool -= ((lastLobbyPool * lobby_pool_decrease_percentage) /10000);
    }

    /* Gets called once a day */
    function _sendShares() internal {
        require(currentDay > 0);

        if (daoAddress != address(0)) {
            // daoUSDCShare = 5% of every day's lobby entry
            uint daoUSDCRawShare = (lobbyEntry[currentDay - 1] * daoUSDCShare) /10000;
            token_USDC.transfer(address(daoAddress), daoUSDCRawShare);
        }

        if (nftMasterChefAddress != address(0))  {
            // masterchefUSDCShare = 5% of every day's lobby entry
            uint masterchefUSDCRawShare = (lobbyEntry[currentDay - 1] * masterchefUSDCShare) /10000;
            token_USDC.transfer(address(nftMasterChefAddress), masterchefUSDCRawShare);
        }
    }
    /**
     * @dev User enters lobby with all of his finished stake divs and receives 10% extra virtual coins
     * @param referrerAddr address of referring user (optional; 0x0 for no referrer)
     * @param stakeId id of the Stake
     */
    function virtualBalanceEnteringLobby(address referrerAddr, uint stakeId) external nonReentrant {
        require(virtualBalanceEnteringIsPaused == false, "paused");
        require(mapMemberStake[msg.sender][stakeId].endDay <= currentDay, "Locked stake");

        DoEndStake(stakeId, true);

        uint profit = calcStakeCollecting(msg.sender, stakeId);

        // enter lobby with 10% extra virtual USDC
        DoEnterLobby(referrerAddr, profit + ((profit * 10) /100), ((profit * 10) /100));
    }

    /**
     * @dev External function for entering the auction lobby for the current day
     * @param referrerAddr address of referring user (optional; 0x0 for no referrer)
     * @param amount amount of USDC entrying to lobby
     */
    function EnterLobby(address referrerAddr, uint amount) external {
        DoEnterLobby(referrerAddr, amount, 0);
    }

    /**
     * @dev entering the auction lobby for the current day
     * @param referrerAddr address of referring user (optional; 0x0 for no referrer)
     * @param amount amount of USDC entrying to lobby
     * @param virtualExtraAmount the virtual amount of tokens
     */
    function DoEnterLobby(
        address referrerAddr,
        uint amount,
        uint virtualExtraAmount
    ) internal {
        uint rawAmount = amount;
        require(rawAmount > 0, "!0");

        // transfer USDC from user wallet if stake profits have already sent to user
        if (virtualExtraAmount == 0) {
            token_USDC.transferFrom(msg.sender, address(this), amount);
        }

        updateDaily();

        require(currentDay > 0, "lobby disabled on day 0!");

        if (mapMemberLobby[msg.sender][currentDay].entryAmount == 0) {
            usersCount++;
            usersCountDaily[currentDay]++;
        }

        // raw amount is added by 10% virtual extra, since we don't want that 10% to be in the dividends calculation we remove it
        if (virtualExtraAmount > 0) {
            lobbyEntry[currentDay] += (rawAmount - virtualExtraAmount);
            overall_lobbyEntry += (rawAmount - virtualExtraAmount);

            mapMemberLobby[msg.sender][currentDay].extraVirtualTokens += virtualExtraAmount;
        } else {
            lobbyEntry[currentDay] += rawAmount;
            overall_lobbyEntry += rawAmount;
        }

        // mapMemberLobby[msg.sender][currentDay].memberLobbyAddress = msg.sender;
        mapMemberLobby[msg.sender][currentDay].entryAmount += rawAmount;


        if (mapMemberLobby[msg.sender][currentDay].entryAmount > lottery_topBuy_today) {
            // new top buyer
            lottery_topBuy_today = mapMemberLobby[msg.sender][currentDay].entryAmount;
            lottery_topBuyer_today = msg.sender;
        }

        mapMemberLobby[msg.sender][currentDay].entryDay = currentDay;
        mapMemberLobby[msg.sender][currentDay].collected = false;

        if ((referrerAddr == address(0) || referrerAddr == msg.sender) &&
            usersLastReferrer[msg.sender] != address(0) && usersLastReferrer[msg.sender] != msg.sender) {
            mapMemberLobby[msg.sender][currentDay].referrer = usersLastReferrer[msg.sender];
        } else if (referrerAddr != msg.sender && referrerAddr != address(0)) {
            usersLastReferrer[msg.sender] = referrerAddr;
            /* No Self-referred */
            mapMemberLobby[msg.sender][currentDay].referrer = referrerAddr;
        }

        emit UserLobby(msg.sender, rawAmount, virtualExtraAmount, mapMemberLobby[msg.sender][currentDay].referrer);
    }

    /**
     * @dev set which Nfts are allowed to be staked
     * Can only be called by the current operator.
     */
    function setNftAddressAllowList(address _series, bool allowed) external onlyOwner() {
        nftAddressAllowList[_series] = allowed;
    
        emit NftAddressAllowListSet(_series, allowed);
    }

    function getNFTType(address series) internal view returns (uint) {
        return FarmerLandNFT(series).nftType();
    }

    function setUserNFTRoostings(address series, uint tokenId) external nonReentrant {
        require(nftAddressAllowList[series]);
        require(tokenId == 0 || isNftIdRoostingWithOwner(msg.sender, series, tokenId), "!roosted");

        uint nftType = getNFTType(series);

        uint prevTokenId;
        if (nftType == 1) {
            prevTokenId = farmerNFTRoost[msg.sender].tokenId;
            farmerNFTRoost[msg.sender].series = series;
            farmerNFTRoost[msg.sender].tokenId = tokenId;
        } else if (nftType == 2) {
            prevTokenId = landNFTRoost[msg.sender].tokenId;
            landNFTRoost[msg.sender].series = series;
            landNFTRoost[msg.sender].tokenId = tokenId;
        } else if (nftType == 3) {
            prevTokenId = toolNFTRoost[msg.sender].tokenId;
            toolNFTRoost[msg.sender].series = series;
            toolNFTRoost[msg.sender].tokenId = tokenId;
        } else if (nftType == 4) {
            prevTokenId = minotaurNFTRoost[msg.sender].tokenId;
            minotaurNFTRoost[msg.sender].series = series;
            minotaurNFTRoost[msg.sender].tokenId = tokenId;
        }

        emit NFTRoosted(series, tokenId, prevTokenId);
    }

    function isNftIdRoostingWithOwner(address owner, address series, uint tokenId) internal view returns (bool) {
        if (series != address(0))
            return FarmerLandNFT(series).isNftIdRoostingWithOwner(owner, tokenId);
        else
            return false;
    }

    function getNFTAbility(address series, uint tokenId) internal view returns (uint) {
        return FarmerLandNFT(series).getAbility(tokenId);
    }

    // _clcNFTBoost = amount * (1.05 + ability * 0.003)
    function _clcNFTBoost(uint amount, uint ability /* basis points 1e4 */) internal pure returns (uint) {
        return (amount * (1e12 * 105 / 100 + (((1e12 * ability * 3) / 1000) / 1e4))) / 1e12;
    }

    function getNFTRoostingBoostedAmount(uint tokenAmount) public view returns (uint) {
        if (isNftIdRoostingWithOwner(msg.sender, farmerNFTRoost[msg.sender].series, farmerNFTRoost[msg.sender].tokenId)) {
            tokenAmount = _clcNFTBoost(
                tokenAmount,
                getNFTAbility(farmerNFTRoost[msg.sender].series, farmerNFTRoost[msg.sender].tokenId)
            );
            // A Tool NFT can only be used as boost if a farmer is also roosting...
            if (isNftIdRoostingWithOwner(msg.sender, toolNFTRoost[msg.sender].series, toolNFTRoost[msg.sender].tokenId)) {
                tokenAmount = _clcNFTBoost(
                    tokenAmount,
                    getNFTAbility(toolNFTRoost[msg.sender].series, toolNFTRoost[msg.sender].tokenId)
                );
            }
        }

        if (isNftIdRoostingWithOwner(msg.sender, landNFTRoost[msg.sender].series, landNFTRoost[msg.sender].tokenId)) {
            tokenAmount = _clcNFTBoost(
                tokenAmount,
                getNFTAbility(landNFTRoost[msg.sender].series, landNFTRoost[msg.sender].tokenId)
            );
        }

        if (isNftIdRoostingWithOwner(msg.sender, minotaurNFTRoost[msg.sender].series, minotaurNFTRoost[msg.sender].tokenId)) {
            tokenAmount = _clcNFTBoost(
                tokenAmount,
                getNFTAbility(minotaurNFTRoost[msg.sender].series, minotaurNFTRoost[msg.sender].tokenId)
            );
        }

        return tokenAmount;
    }

    /**
     * @dev External function for leaving the lobby / collecting the tokens
     * @param targetDay Target day of lobby to collect
     */
    function ExitLobby(uint targetDay) external {
        require(mapMemberLobby[msg.sender][targetDay].collected == false, "Already collected");
        updateDaily();
        require(targetDay < currentDay);

        uint tokensToPay = clcTokenValue(msg.sender, targetDay);

        uint exitLobbyWHEATAmount = getNFTRoostingBoostedAmount(tokensToPay);

        mapMemberLobby[msg.sender][targetDay].collected = true;

        overall_collectedTokens += exitLobbyWHEATAmount;

        _mint(msg.sender, exitLobbyWHEATAmount);

        if (nftMasterChefAddress != address(0) && exitLobbyWHEATAmount > 0 && masterchefWHEATShare > 0)
            _mint(nftMasterChefAddress, (exitLobbyWHEATAmount * masterchefWHEATShare) /10000);
        if (daoAddress != address(0) && exitLobbyWHEATAmount > 0 && daoWHEATShare > 0)
            _mint(daoAddress, (exitLobbyWHEATAmount * daoWHEATShare) /10000);

        address referrerAddress = mapMemberLobby[msg.sender][targetDay].referrer;
        if (referrerAddress != address(0)) {
            /* there is a referrer, pay their % ref bonus of tokens */
            uint refBonus = (tokensToPay * ref_bonus_NR) /10000;

            referrerBonusesPaid[referrerAddress] += refBonus;

            _mint(referrerAddress, refBonus);

            /* pay the referred user bonus */
            _mint(msg.sender, (tokensToPay * ref_bonus_NRR) /10000);
        }

        emit UserLobbyCollect(msg.sender, tokensToPay, targetDay, exitLobbyWHEATAmount, masterchefWHEATShare, daoWHEATShare, ref_bonus_NR, ref_bonus_NRR);
    }

    /**
     * @dev Calculating user's share from lobby based on their entry value
     * @param _day The lobby day
     */
    function clcTokenValue(address _address, uint _day) public view returns (uint) {
        require(_day != 0, "lobby disabled on day 0!");
        uint _tokenValue;
        uint entryDay = mapMemberLobby[_address][_day].entryDay;

        if (entryDay != 0 && entryDay < currentDay) {
            _tokenValue = (lobbyPool[_day] * mapMemberLobby[_address][_day].entryAmount) / lobbyEntry[entryDay];
        } else {
            _tokenValue = 0;
        }

        return _tokenValue;
    }

    mapping(uint => uint) public dayUSDCPool;
    mapping(uint => uint) public enterytokenMath;
    mapping(uint => uint) public totalTokensInActiveStake;

    /**
     * @dev External function for users to create a stake
     * @param amount Amount of WHEAT tokens to stake
     * @param stakingDays Stake duration in days
     */

    function EnterStake(uint amount, uint stakingDays) external {
        require(amount > 0, "Can't be zero wheat");
        require(stakingDays >= 1, "Staking days < 1");
        require(stakingDays <= max_stake_days, "Staking days > max_stake_days");
        require(balanceOf(msg.sender) >= amount, "!userbalance");

        /* On stake WHEAT tokens get burned */
        _burn(msg.sender, amount);

        updateDaily();
        uint stakeId = stakeCounts[msg.sender];
        stakeCounts[msg.sender]++;

        overall_stakedTokens += amount;

        mapMemberStake[msg.sender][stakeId].stakeId = stakeId;
        mapMemberStake[msg.sender][stakeId].userAddress = msg.sender;
        mapMemberStake[msg.sender][stakeId].tokenValue = amount;
        mapMemberStake[msg.sender][stakeId].startDay = currentDay + 1;
        mapMemberStake[msg.sender][stakeId].endDay = currentDay + 1 + stakingDays;
        mapMemberStake[msg.sender][stakeId].collected = false;
        mapMemberStake[msg.sender][stakeId].hasSold = false;
        mapMemberStake[msg.sender][stakeId].hasLoan = false;
        mapMemberStake[msg.sender][stakeId].forSell = false;
        mapMemberStake[msg.sender][stakeId].forLoan = false;
        // stake calcs for days: X >= startDay && X < endDay
        // startDay included / endDay not included

        for (uint i = currentDay + 1; i <= currentDay + stakingDays; i++) {
            totalTokensInActiveStake[i] += amount;
        }

        saveTotalToken += amount;

        emit UserStake(msg.sender, amount, stakingDays, stakeId);
    }

    /**
     * @dev External function for collecting a stake
     * @param stakeId Id of the Stake
     */
    function EndStake(uint stakeId) external nonReentrant {
        DoEndStake(stakeId, false);
    }

    /**
     * @dev Collecting a stake
     * @param stakeId Id of the Stake
     * @param doNotSendDivs do or not do sent the stake's divs to the user (used when re entring the lobby using the stake's divs)
     */
    function DoEndStake(uint stakeId, bool doNotSendDivs) internal {
        require(mapMemberStake[msg.sender][stakeId].endDay <= currentDay, "Locked stake");
        require(mapMemberStake[msg.sender][stakeId].userAddress == msg.sender);
        require(mapMemberStake[msg.sender][stakeId].collected == false);
        require(mapMemberStake[msg.sender][stakeId].hasSold == false);

        updateDaily();

        /* if the stake is for sell, set it false since it's collected */
        mapMemberStake[msg.sender][stakeId].forSell = false;
        mapMemberStake[msg.sender][stakeId].forLoan = false;

        /* clc USDC divs */
        uint profit = calcStakeCollecting(msg.sender, stakeId);
        overall_collectedDivs += profit;

        mapMemberStake[msg.sender][stakeId].collected = true;

        if (doNotSendDivs == false) {
            token_USDC.transfer(address(msg.sender), profit);
        }

        /* if the stake has loan on it automatically pay the lender and finish the loan */
        if (mapMemberStake[msg.sender][stakeId].hasLoan == true) {
            updateFinishedLoan(
                mapRequestingLoans[msg.sender][stakeId].lenderAddress,
                msg.sender,
                mapRequestingLoans[msg.sender][stakeId].lenderLendId,
                stakeId
            );
        }

        uint stakeReturn = mapMemberStake[msg.sender][stakeId].tokenValue;

        /* Pay the bonus token and stake return, if any, to the staker */
        uint bonusAmount;
        if (stakeReturn != 0) {
            bonusAmount = calcBonusToken(mapMemberStake[msg.sender][stakeId].endDay - mapMemberStake[msg.sender][stakeId].startDay, stakeReturn);
            bonusAmount = getNFTRoostingBoostedAmount(bonusAmount);

            overall_collectedBonusTokens += bonusAmount;

            uint endStakeWHEATMintAmount = stakeReturn + bonusAmount;

            _mint(msg.sender, endStakeWHEATMintAmount);

            if (nftMasterChefAddress != address(0) && bonusAmount > 0 && masterchefWHEATShare > 0)
                _mint(nftMasterChefAddress, (bonusAmount * masterchefWHEATShare) /10000);
            if (daoAddress != address(0) && bonusAmount > 0 && daoWHEATShare > 0)
                _mint(daoAddress, (bonusAmount * daoWHEATShare) /10000);
        }

        emit UserStakeCollect(msg.sender, profit, stakeId, bonusAmount);
    }

    /**
     * @dev Calculating a stakes USDC divs payout value by looping through each day of it
     * @param _address User address
     * @param _stakeId Id of the Stake
     */
    function calcStakeCollecting(address _address, uint _stakeId) public view returns (uint) {
        uint userDivs;
        uint _endDay = mapMemberStake[_address][_stakeId].endDay;
        uint _startDay = mapMemberStake[_address][_stakeId].startDay;
        uint _stakeValue = mapMemberStake[_address][_stakeId].tokenValue;

        for (uint _day = _startDay; _day < _endDay && _day < currentDay; _day++) {
            userDivs += (dayUSDCPool[_day] * _stakeValue * 1e6) / totalTokensInActiveStake[_day];
        }

        userDivs /= 1e6;

        return (userDivs - mapMemberStake[_address][_stakeId].loansReturnAmount);
    }

    /**
     * @dev Calculating a stakes Bonus WHEAT tokens based on stake duration and stake amount
     * @param StakeDuration The stake's days
     * @param StakeAmount The stake's WHEAT tokens amount
     */
    function calcBonusToken(uint StakeDuration, uint StakeAmount) public pure returns (uint) {
        require(StakeDuration <= max_stake_days, "Staking days > max_stake_days");

        uint _bonusAmount = (StakeAmount * (StakeDuration**2) * bonus_calc_ratio) / 1e7;
        // 1.5% big payday bonus every 30 days
        _bonusAmount+= (StakeAmount * (StakeDuration/30) * 150) / 1e4;

        return _bonusAmount;
    }

    /**
     * @dev calculating user dividends for a specific day
     */

    uint public devShareOfStakeSellsAndLoanFee;
    uint public totalStakesSold;
    uint public totalTradeAmount;

    /* withdrawable funds for the stake seller address */
    mapping(address => uint) public soldStakeFunds;

    /**
     * @dev User putting up their stake for sell or user changing the previously setted sell price of their stake
     * @param stakeId stake id
     * @param price sell price for the stake
     */
    function sellStakeRequest(uint stakeId, uint price) external {
        updateDaily();

        require(stakeSellingIsPaused == false, "paused");
        require(mapMemberStake[msg.sender][stakeId].userAddress == msg.sender, "!auth");
        require(mapMemberStake[msg.sender][stakeId].hasLoan == false, "Has active loan");
        require(mapMemberStake[msg.sender][stakeId].hasSold == false, "Stake sold");
        require(mapMemberStake[msg.sender][stakeId].endDay > currentDay, "Has ended");

        /* if stake is for loan, remove it from loan requests */
        if (mapMemberStake[msg.sender][stakeId].forLoan == true) {
            cancelStakeLoanRequest(stakeId);
        }

        require(mapMemberStake[msg.sender][stakeId].forLoan == false);

        mapMemberStake[msg.sender][stakeId].forSell = true;
        mapMemberStake[msg.sender][stakeId].price = price;

        emit StakeSellRequest(msg.sender, price, mapMemberStake[msg.sender][stakeId].tokenValue, stakeId);
    }

    function sellStakeCancelRequest(uint stakeId) external {
        updateDaily();

        require(stakeSellingIsPaused == false, "paused");

        cancelSellStakeRequest(stakeId);
    }

    /**
     * @dev A user buying a stake
     * @param sellerAddress stake seller address (current stake owner address)
     * @param stakeId stake id
     */
    function buyStakeRequest(
        address sellerAddress,
        uint stakeId,
        uint amount
    ) external {
        updateDaily();

        require(stakeSellingIsPaused == false, "paused");
        require(mapMemberStake[sellerAddress][stakeId].userAddress != msg.sender, "no self buy");
        require(mapMemberStake[sellerAddress][stakeId].userAddress == sellerAddress, "!auth");
        require(mapMemberStake[sellerAddress][stakeId].hasSold == false, "Stake sold");
        require(mapMemberStake[sellerAddress][stakeId].forSell == true, "!for sell");
        uint priceP = amount;
        require(mapMemberStake[sellerAddress][stakeId].price == priceP, "!funds");
        require(mapMemberStake[sellerAddress][stakeId].endDay > currentDay);

        token_USDC.transferFrom(msg.sender, address(this), amount);

        /* 10% stake sell fee ==> 2% dev share & 8% buy back to the current day's lobby */
        uint pc90 = (mapMemberStake[sellerAddress][stakeId].price * 90) /100;
        uint pc10 = mapMemberStake[sellerAddress][stakeId].price - pc90;
        uint pc2 = pc10 / 5;
        lobbyEntry[currentDay] += pc10 - pc2;
        devShareOfStakeSellsAndLoanFee += pc2;

        /* stake seller gets 90% of the stake's sold price */
        soldStakeFunds[sellerAddress] += pc90;

        /* setting data for the old owner */
        mapMemberStake[sellerAddress][stakeId].hasSold = true;
        mapMemberStake[sellerAddress][stakeId].forSell = false;
        mapMemberStake[sellerAddress][stakeId].collected = true;

        totalStakesSold += 1;
        totalTradeAmount += priceP;

        /* new stake & stake ID for the new stake owner (the stake buyer) */
        uint newStakeId = stakeCounts[msg.sender];
        stakeCounts[msg.sender]++;
        mapMemberStake[msg.sender][newStakeId].userAddress = msg.sender;
        mapMemberStake[msg.sender][newStakeId].tokenValue = mapMemberStake[sellerAddress][stakeId].tokenValue;
        mapMemberStake[msg.sender][newStakeId].startDay = mapMemberStake[sellerAddress][stakeId].startDay;
        mapMemberStake[msg.sender][newStakeId].endDay = mapMemberStake[sellerAddress][stakeId].endDay;
        mapMemberStake[msg.sender][newStakeId].loansReturnAmount = mapMemberStake[sellerAddress][stakeId].loansReturnAmount;
        mapMemberStake[msg.sender][newStakeId].stakeId = newStakeId;
        mapMemberStake[msg.sender][newStakeId].collected = false;
        mapMemberStake[msg.sender][newStakeId].hasSold = false;
        mapMemberStake[msg.sender][newStakeId].hasLoan = false;
        mapMemberStake[msg.sender][newStakeId].forSell = false;
        mapMemberStake[msg.sender][newStakeId].forLoan = false;
        mapMemberStake[msg.sender][newStakeId].price = 0;

        emit StakeBuyRequest(sellerAddress, stakeId, msg.sender, newStakeId, amount);
    }

    /**
     * @dev User asking to withdraw their funds from their sold stake
     */
    function withdrawSoldStakeFunds() external nonReentrant {
        require(soldStakeFunds[msg.sender] > 0, "!funds");

        uint toBeSend = soldStakeFunds[msg.sender];
        soldStakeFunds[msg.sender] = 0;

        token_USDC.transfer(address(msg.sender), toBeSend);

        emit WithdrawSoldStakeFunds(msg.sender, toBeSend);
    }

    struct loanRequest {
        address loanerAddress; // address
        address lenderAddress; // address (sets after loan request accepted by a lender)
        uint stakeId; // id of the stakes that is being loaned on
        uint lenderLendId; // id of the lends that a lender has given out (sets after loan request accepted by a lender)
        uint loanAmount; // requesting loan USDC amount
        uint returnAmount; // requesting loan USDC return amount
        uint duration; // duration of loan (days)
        uint lend_startDay; // lend start day (sets after loan request accepted by a lender)
        uint lend_endDay; // lend end day (sets after loan request accepted by a lender)
        bool hasLoan;
        bool loanIsPaid; // gets true after loan due date is reached and loan is paid
    }

    struct lendInfo {
        address lenderAddress;
        address loanerAddress;
        uint lenderLendId;
        uint loanAmount;
        uint returnAmount;
        uint endDay;
        bool loanIsPaid;
    }

    /* withdrawable funds for the loaner address */
    mapping(address => uint) public LoanedFunds;
    mapping(address => uint) public LendedFunds;

    uint public totalLoanedAmount;
    uint public totalLoanedCount;

    mapping(address => mapping(uint => loanRequest)) public mapRequestingLoans;
    mapping(address => mapping(uint => lendInfo)) public mapLenderInfo;
    mapping(address => uint) public lendersPaidAmount; // total amounts of paid to lender

    /**
     * @dev User submiting a loan request on their stake or changing the previously setted loan request data
     * @param stakeId stake id
     * @param loanAmount amount of requesting USDC loan
     * @param returnAmount amount of USDC loan return
     * @param loanDuration duration of requesting loan
     */
    function getLoanOnStake(
        uint stakeId,
        uint loanAmount,
        uint returnAmount,
        uint loanDuration
    ) external {
        updateDaily();

        require(loaningIsPaused == false, "paused");
        require(loanAmount < returnAmount, "need loanAmount < returnAmount");
        //require(loanDuration >= 4, "lowest loan duration is 4 days");
        require(mapMemberStake[msg.sender][stakeId].userAddress == msg.sender, "!auth");
        require(mapMemberStake[msg.sender][stakeId].hasLoan == false, "Has active loan");
        require(mapMemberStake[msg.sender][stakeId].hasSold == false, "Stake sold");
        require(mapMemberStake[msg.sender][stakeId].endDay > currentDay + loanDuration);

        /* calc stake divs */
        uint stakeDivs = calcStakeCollecting(msg.sender, stakeId);

        /* max amount of possible stake return can not be higher than stake's divs */
        require(returnAmount <= stakeDivs);

        /* if stake is for sell, remove it from sell requests */
        if (mapMemberStake[msg.sender][stakeId].forSell == true) {
            cancelSellStakeRequest(stakeId);
        }

        require(mapMemberStake[msg.sender][stakeId].forSell == false);

        mapMemberStake[msg.sender][stakeId].forLoan = true;

        /* data of the requesting loan */
        mapRequestingLoans[msg.sender][stakeId].loanerAddress = msg.sender;
        mapRequestingLoans[msg.sender][stakeId].stakeId = stakeId;
        mapRequestingLoans[msg.sender][stakeId].loanAmount = loanAmount;
        mapRequestingLoans[msg.sender][stakeId].returnAmount = returnAmount;
        mapRequestingLoans[msg.sender][stakeId].duration = loanDuration;
        mapRequestingLoans[msg.sender][stakeId].loanIsPaid = false;

        emit StakeLoanRequest(msg.sender, loanAmount, returnAmount, loanDuration, stakeId);
    }

    /**
     * @dev Canceling loan request
     * @param stakeId stake id
     */
    function cancelStakeLoanRequest(uint stakeId) public {
        require(mapMemberStake[msg.sender][stakeId].hasLoan == false);
        mapMemberStake[msg.sender][stakeId].forLoan = false;

        emit CancelStakeLoanRequest(msg.sender, stakeId);
    }

    /**
     * @dev User asking to their stake's sell request
     */
    function cancelSellStakeRequest(uint stakeId) internal {
        require(mapMemberStake[msg.sender][stakeId].userAddress == msg.sender);
        require(mapMemberStake[msg.sender][stakeId].forSell == true);
        require(mapMemberStake[msg.sender][stakeId].hasSold == false);

        mapMemberStake[msg.sender][stakeId].forSell = false;

        emit CancelStakeSellRequest(msg.sender, stakeId);
    }

    /**
     * @dev User filling loan request (lending)
     * @param loanerAddress address of loaner aka the person who is requesting for loan
     * @param stakeId stake id
     * @param amount lend amount that is transferred to the contract
     */
    function lendOnStake(
        address loanerAddress,
        uint stakeId,
        uint amount
    ) external nonReentrant {
        updateDaily();

        require(loaningIsPaused == false, "paused");
        require(mapMemberStake[loanerAddress][stakeId].userAddress != msg.sender, "no self lend");
        require(mapMemberStake[loanerAddress][stakeId].hasLoan == false, "Has active loan");
        require(mapMemberStake[loanerAddress][stakeId].forLoan == true, "!requesting a loan");
        require(mapMemberStake[loanerAddress][stakeId].hasSold == false, "Stake is sold");
        require(mapMemberStake[loanerAddress][stakeId].endDay > currentDay, "Stake finished");

        uint loanAmount = mapRequestingLoans[loanerAddress][stakeId].loanAmount;
        uint returnAmount = mapRequestingLoans[loanerAddress][stakeId].returnAmount;
        uint rawAmount = amount;

        require(rawAmount == mapRequestingLoans[loanerAddress][stakeId].loanAmount);

        token_USDC.transferFrom(msg.sender, address(this), amount);

        /* 2% loaning fee, taken from loaner's stake dividends, 1% buybacks to current day's lobby, 1% dev fee */
        uint theLoanFee = (rawAmount * 2) /100;
        devShareOfStakeSellsAndLoanFee += theLoanFee - (theLoanFee /2);
        lobbyEntry[currentDay] += theLoanFee /2;

        mapMemberStake[loanerAddress][stakeId].loansReturnAmount += returnAmount;
        mapMemberStake[loanerAddress][stakeId].hasLoan = true;
        mapMemberStake[loanerAddress][stakeId].forLoan = false;

        uint lenderLendId = clcLenderLendId(msg.sender);

        mapRequestingLoans[loanerAddress][stakeId].hasLoan = true;
        mapRequestingLoans[loanerAddress][stakeId].loanIsPaid = false;
        mapRequestingLoans[loanerAddress][stakeId].lenderAddress = msg.sender;
        mapRequestingLoans[loanerAddress][stakeId].lenderLendId = lenderLendId;
        mapRequestingLoans[loanerAddress][stakeId].lend_startDay = currentDay;
        mapRequestingLoans[loanerAddress][stakeId].lend_endDay = currentDay + mapRequestingLoans[loanerAddress][stakeId].duration;

        mapLenderInfo[msg.sender][lenderLendId].lenderAddress = msg.sender;
        mapLenderInfo[msg.sender][lenderLendId].loanerAddress = loanerAddress;
        mapLenderInfo[msg.sender][lenderLendId].lenderLendId = lenderLendId; // not same with the stake id on "mapRequestingLoans"
        mapLenderInfo[msg.sender][lenderLendId].loanAmount = loanAmount;
        mapLenderInfo[msg.sender][lenderLendId].returnAmount = returnAmount;
        mapLenderInfo[msg.sender][lenderLendId].endDay = mapRequestingLoans[loanerAddress][stakeId].lend_endDay;

        uint resultAmount = rawAmount - theLoanFee;
        LoanedFunds[loanerAddress] += resultAmount;
        LendedFunds[msg.sender] += resultAmount;
        totalLoanedAmount += resultAmount;
        totalLoanedCount += 1;

        emit StakeLend(msg.sender, lenderLendId, loanerAddress, stakeId, rawAmount);
    }

    /**
     * @dev User asking to withdraw their loaned funds
     */
    function withdrawLoanedFunds() external nonReentrant {
        require(LoanedFunds[msg.sender] > 0, "!funds");

        uint toBeSend = LoanedFunds[msg.sender];
        LoanedFunds[msg.sender] = 0;

        token_USDC.transfer(address(msg.sender), toBeSend);

        emit WithdrawLoanedFunds(msg.sender, toBeSend);
    }

    /**
     * @dev returns a unique id for the lend by lopping through the user's lends and counting them
     * @param _address the lender user address
     */
    function clcLenderLendId(address _address) public view returns (uint) {
        uint stakeCount = 0;

        for (uint i = 0; mapLenderInfo[_address][i].lenderAddress == _address; i++) {
            stakeCount += 1;
        }

        return stakeCount;
    }

    /* 
        after a loan's due date is reached there is no automatic way in contract to pay the lender and set the lend data as finished (for the sake of performance and gas)
        so either the lender user calls the "collectLendReturn" function or the loaner user automatically call the  "updateFinishedLoan" function by trying to collect their stake 
    */

    /**
     * @dev Lender requesting to collect their return amount from their finished lend
     * @param stakeId id of a loaner's stake for that the loaner requested a loan and received a lend
     * @param lenderLendId id of the lends that a lender has given out (different from stakeId)
     */
    function collectLendReturn(uint stakeId, uint lenderLendId) external nonReentrant {
        updateFinishedLoan(msg.sender, mapLenderInfo[msg.sender][lenderLendId].loanerAddress, lenderLendId, stakeId);
    }

    /**
     * @dev Checks if the loan on loaner's stake is finished
     * @param lenderAddress lender address
     * @param loanerAddress loaner address
     * @param lenderLendId id of the lends that a lender has given out (different from stakeId)
     * @param stakeId id of a loaner's stake for that the loaner requested a loan and received a lend
     */
    function updateFinishedLoan(
        address lenderAddress,
        address loanerAddress,
        uint lenderLendId,
        uint stakeId
    ) internal {
        updateDaily();

        require(mapMemberStake[loanerAddress][stakeId].hasLoan == true, "Stake has no active loan");
        require(currentDay >= mapRequestingLoans[loanerAddress][stakeId].lend_endDay, "Due date not yet reached");
        require(mapLenderInfo[lenderAddress][lenderLendId].loanIsPaid == false);
        require(mapRequestingLoans[loanerAddress][stakeId].loanIsPaid == false);
        require(mapRequestingLoans[loanerAddress][stakeId].hasLoan == true);
        require(mapRequestingLoans[loanerAddress][stakeId].lenderAddress == lenderAddress);
        require(mapRequestingLoans[loanerAddress][stakeId].lenderLendId == lenderLendId);

        mapMemberStake[loanerAddress][stakeId].hasLoan = false;
        mapLenderInfo[lenderAddress][lenderLendId].loanIsPaid = true;
        mapRequestingLoans[loanerAddress][stakeId].hasLoan = false;
        mapRequestingLoans[loanerAddress][stakeId].loanIsPaid = true;

        uint toBePaid = mapRequestingLoans[loanerAddress][stakeId].returnAmount;
        lendersPaidAmount[lenderAddress] += toBePaid;

        mapRequestingLoans[loanerAddress][stakeId].returnAmount = 0;

        token_USDC.transfer(address(lenderAddress), toBePaid);

        emit StakeLoanFinished(lenderAddress, lenderLendId, loanerAddress, stakeId, toBePaid);
    }

    /* top lottery buyer of the day (so far) */
    uint public lottery_topBuy_today;
    address public lottery_topBuyer_today;

    /* latest top lottery bought amount*/
    uint public lottery_topBuy_latest;

    /* lottery reward pool */
    uint public lottery_Pool;

    /**
     * @dev Runs once a day and checks for lottry winner
     */
    function checkLottery() internal {
        if (lottery_topBuy_today > lottery_topBuy_latest) {
            // we have a winner
            // 50% of the pool goes to the winner

            lottery_topBuy_latest = lottery_topBuy_today;

            if (currentDay >= 7) {
                uint winnerAmount = (lottery_Pool * 50) /100;
                lottery_Pool -= winnerAmount;
                token_USDC.transfer(address(lottery_topBuyer_today), winnerAmount);

                emit LotteryWinner(lottery_topBuyer_today, winnerAmount, lottery_topBuy_latest);
            }
        } else {
            // no winner, reducing the record by 20%
            lottery_topBuy_latest -= (lottery_topBuy_latest * 200) /1000;
        }

        // 2% of lobby entry of each day goes to lottery_Pool
        lottery_Pool += (lobbyEntry[currentDay - 1] * lottery_share_percentage) /10000;

        lottery_topBuyer_today = address(0);
        lottery_topBuy_today = 0;

        emit LotteryUpdate(lottery_Pool, lottery_topBuy_latest);
    }
}

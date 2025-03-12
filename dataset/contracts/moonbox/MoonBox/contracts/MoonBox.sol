// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import "./ERC20Detailed.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./SafeMathInt.sol";
import "./IERC20.sol";
import "./IPancakeSwapPair.sol";
import "./IPancakeSwapRouter.sol";
import "./IPancakeSwapFactory.sol";
import "./IMoonBoxAffiliate.sol";

contract MoonBox is ERC20Detailed, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);

    string public _name = "MoonBox";
    string public _symbol = "MoonBox";
    uint8 public _decimals = 5;

    IPancakeSwapPair public pairContract;
    mapping(address => bool) _isFeeExempt;
    mapping(address => bool) _isWhiteList;
    mapping(address => bool) public _operators;

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    modifier onlyOperator() {
        require(_operators[msg.sender], "Forbidden");
        _;
    }

    uint256 public constant DECIMALS = 5;
    uint256 public constant MAX_UINT256 = ~uint256(0);
    uint8 public constant RATE_DECIMALS = 7;

    uint256 private constant INITIAL_FRAGMENTS_SUPPLY =
        5000000 * 10**DECIMALS;

    uint256 public limitSellRate = 10;
    uint256 public limitSellRateBonus = 10;
    uint256 public limitSellRateReduce = 5;
    uint256 public limitSellRateBonusPr = 10;
    uint256 public secondLimitSell = 86400;
    uint256 public maxSellTransactionAmount = 1000000 * 10**DECIMALS;

    struct Trader {
        uint256 lastTradeTime;
        uint256 amount;
        uint256 limitAmount;
        uint256 totalBuy;
        uint256 totalSell;
    }

    struct Pr {
        bool enable;
        uint256 amount;
    }

    mapping(address => Trader) public tradeHistory;
    mapping(address => uint256) public boughtAmount;
    mapping(address => Pr) public prs;

    //Buy fee
    uint256 public treasuryFeeB = 20;
    uint256 public insuranceFundFeeB = 0;
    uint256 public totalFeeB = treasuryFeeB.add(insuranceFundFeeB);

    //Sell fee
    uint256 public treasuryFeeS = 50;
    uint256 public insuranceFundFeeS = 20;
    uint256 public totalFeeS = treasuryFeeS.add(insuranceFundFeeS);
    uint256 public feeDenominator = 1000;

    //Transfer
    bool public transferFeeEnable = false;

    //Rate fee
    uint256 public treasuryFeeRate = 778;
    uint256 public insuranceFundFeeRate = 222;

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    address public treasuryReceiver;
    address public insuranceFundReceiver;
    IPancakeSwapRouter public router;
    IMoonBoxAffiliate affiliate;
    address public pair;
    bool inSwap = false;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    uint256 private constant MAX_SUPPLY = 600000000000 * 10**DECIMALS;

    bool public _autoRebase;
    uint256 public _initRebaseStartTime;
    uint256 public _lastRebasedTime;
    uint256 public _totalSupply;
    uint256 private _gonsPerFragment;

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    constructor(address _affiliate)
        ERC20Detailed("MoonBox", "MoonBox", uint8(DECIMALS))
        Ownable()
    {
        require(_affiliate != address(0), "Zero address");
        router = IPancakeSwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IPancakeSwapFactory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );

        treasuryReceiver = 0x1F2Ca13CA482b32B1BBDb12b833E387656b1Bc9E;
        insuranceFundReceiver = 0xF624164837Db5f6B6Cf28849DDD6B48c2207Ac16;

        affiliate = IMoonBoxAffiliate(_affiliate);

        _allowedFragments[address(this)][address(router)] = uint256(-1);
        _allowedFragments[address(this)][pair] = uint256(-1);
        _allowedFragments[address(this)][address(this)] = uint256(-1);
        _allowedFragments[_affiliate][address(router)] = uint256(-1);
        _allowedFragments[_affiliate][pair] = uint256(-1);
        _allowedFragments[_affiliate][_affiliate] = uint256(-1);
        pairContract = IPancakeSwapPair(pair);

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[msg.sender] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        _initRebaseStartTime = block.timestamp;
        _lastRebasedTime = block.timestamp;
        _autoRebase = false;

        _isFeeExempt[insuranceFundReceiver] = true;
        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[msg.sender] = true;
        _isFeeExempt[address(this)] = true;
        _isFeeExempt[address(router)] = true;
        _isFeeExempt[_affiliate] = true;

        _isWhiteList[msg.sender] = true;

        _operators[msg.sender] = true;

        emit Transfer(address(0x0), treasuryReceiver, _totalSupply);
    }

    function forceRebase() external onlyOperator {
        if (shouldRebase()) {
            rebase();
        }
    }

    function rebase() internal {
        if (inSwap) return;
        uint256 rebaseRate;
        uint256 deltaTimeFromInit = block.timestamp - _initRebaseStartTime;
        uint256 deltaTime = block.timestamp - _lastRebasedTime;
        uint256 times = deltaTime.div(15 minutes);
        uint256 epoch = times.mul(15);

        if (deltaTimeFromInit < (365 days)) {
            rebaseRate = 2341;
        } else if (deltaTimeFromInit >= (7 * 365 days)) {
            rebaseRate = 13;
        } else if (deltaTimeFromInit >= ((15 * 365 days) / 10)) {
            rebaseRate = 24;
        } else if (deltaTimeFromInit >= (365 days)) {
            rebaseRate = 146;
        }

        for (uint256 i = 0; i < times; i++) {
            _totalSupply = _totalSupply
                .mul((10**RATE_DECIMALS).add(rebaseRate))
                .div(10**RATE_DECIMALS);
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        _lastRebasedTime = _lastRebasedTime.add(times.mul(15 minutes));

        pairContract.sync();

        emit LogRebase(epoch, _totalSupply);
    }

    function transfer(address to, uint256 value)
        external
        override
        validRecipient(to)
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != uint256(-1)) {
            _allowedFragments[from][msg.sender] = _allowedFragments[from][
                msg.sender
            ].sub(value, "Insufficient Allowance");
        }
        _transferFrom(from, to, value);
        return true;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[from] = _gonBalances[from].sub(gonAmount);
        _gonBalances[to] = _gonBalances[to].add(gonAmount);
        boughtAmount[to] = boughtAmount[to].add(amount);
        emit Transfer(from, to, amount);
        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (_isWhiteList[sender] || _isWhiteList[recipient]) {
            return _basicTransfer(sender, recipient, amount);
        }

        bool isTransfer = sender != pair && recipient != pair;
        bool isSell = recipient == pair;
        bool excludedAccount = _isFeeExempt[sender] || _isFeeExempt[recipient];
        if (inSwap || excludedAccount) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (isSell || isTransfer) {
            require(amount <= maxSellTransactionAmount, "Error amount");
            uint256 blkTime = block.timestamp;
            uint256 txLimitRate = getSellLimitRate(sender);

            if (
                blkTime > tradeHistory[sender].lastTradeTime + secondLimitSell
            ) {
                uint256 limitAmount = balanceOf(sender).mul(txLimitRate).div(
                    feeDenominator
                );
                require(
                    amount <= limitAmount,
                    "ERR: Can't sell more than limit rate"
                );
                tradeHistory[sender].lastTradeTime = blkTime;
                tradeHistory[sender].amount = amount;
                tradeHistory[sender].limitAmount = limitAmount;
            } else {
                require(
                    tradeHistory[sender].amount.add(amount) <=
                        tradeHistory[sender].limitAmount,
                    "ERR: Can't sell more than limit rate in One day"
                );
                tradeHistory[sender].amount = tradeHistory[sender].amount.add(
                    amount
                );
            }
        }

        if (shouldRebase()) {
            rebase();
        }

        if (shouldSwapBack() && (sender == pair || recipient == pair)) {
            swapBack();
        }

        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);
        (uint256 gonAmountReceived, uint256 gonMgmFee) = shouldTakeFee(
            sender,
            recipient
        )
            ? takeFee(sender, recipient, gonAmount, amount)
            : (gonAmount, 0);
        _gonBalances[recipient] = _gonBalances[recipient].add(
            gonAmountReceived
        );

        if (isSell) {
            tradeHistory[sender].totalSell = tradeHistory[sender].totalSell.add(
                amount
            );
        } else {
            tradeHistory[recipient].totalBuy = tradeHistory[recipient]
                .totalBuy
                .add(gonAmountReceived.div(_gonsPerFragment));
        }

        if (gonMgmFee > 0) {
            affiliate.setAffiliateRevenue(
                isSell ? sender : recipient,
                gonMgmFee.div(_gonsPerFragment),
                recipient != pair
            );
        }

        if (recipient != pair) {
            boughtAmount[recipient] = boughtAmount[recipient].add(
                gonAmountReceived.div(_gonsPerFragment)
            );
        }

        emit Transfer(
            sender,
            recipient,
            gonAmountReceived.div(_gonsPerFragment)
        );
        return true;
    }

    function getSellLimitRate(address _address) public view returns (uint256) {
        if (
            prs[_address].enable &&
            tradeHistory[_address].totalSell < prs[_address].amount
        ) {
            return limitSellRate.add(limitSellRateBonusPr);
        }
        uint256 bonus = affiliate.getF0(_address) == address(0)
            ? 0
            : limitSellRateBonus;
        uint256 reduce = tradeHistory[_address].totalBuy > 0 &&
            tradeHistory[_address].totalBuy < tradeHistory[_address].totalSell
            ? limitSellRateReduce
            : 0;
        return limitSellRate.add(bonus).sub(reduce);
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount,
        uint256 amount
    ) internal returns (uint256, uint256) {
        uint256 _totalFee;
        uint256 _mgmFee;
        uint256 taxedGons = gonAmount;

        if (recipient == pair) {
            //Sell
            _totalFee = totalFeeS;
            _mgmFee = affiliate.getTotalAffiliateSell();

            uint256 _boughtAmount = boughtAmount[sender];
            if (_boughtAmount == 0) {
                uint256 affiliateAmount = gonAmount.mul(_mgmFee).div(
                    feeDenominator
                );
                _gonBalances[address(affiliate)] = _gonBalances[
                    address(affiliate)
                ].add(affiliateAmount);

                emit Transfer(
                    sender,
                    address(affiliate),
                    affiliateAmount.div(_gonsPerFragment)
                );
                return (gonAmount.sub(affiliateAmount), affiliateAmount);
            }

            uint256 taxedAmount = amount > _boughtAmount
                ? _boughtAmount
                : amount;
            boughtAmount[sender] = _boughtAmount.sub(taxedAmount);
            taxedGons = taxedAmount.mul(_gonsPerFragment);
        } else {
            //Buy or transfer
            _totalFee = totalFeeB;
            _mgmFee = affiliate.getTotalAffiliateBuy();
        }

        uint256 feeAmount = taxedGons.mul(_totalFee).div(feeDenominator);
        uint256 affiliateAmount = gonAmount.mul(_mgmFee).div(feeDenominator);

        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            feeAmount
        );
        _gonBalances[address(affiliate)] = _gonBalances[address(affiliate)].add(
            affiliateAmount
        );

        emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));

        emit Transfer(
            sender,
            address(affiliate),
            affiliateAmount.div(_gonsPerFragment)
        );
        return (gonAmount.sub(feeAmount).sub(affiliateAmount), affiliateAmount);
    }

    function swapBack() internal swapping {
        uint256 amountToSwap = _gonBalances[address(this)].div(
            _gonsPerFragment
        );

        if (amountToSwap == 0) {
            return;
        }

        uint256 amountEthPayout = swapTokenToBnb(amountToSwap, address(this));
        (bool success, ) = payable(treasuryReceiver).call{
            value: amountEthPayout.mul(treasuryFeeRate).div(feeDenominator),
            gas: 30000
        }("");
        (success, ) = payable(insuranceFundReceiver).call{
            value: amountEthPayout.mul(insuranceFundFeeRate).div(
                feeDenominator
            ),
            gas: 30000
        }("");
    }

    function withdrawAllToTreasury() external swapping onlyOwner {
        uint256 amountToSwap = _gonBalances[address(this)].div(
            _gonsPerFragment
        );
        require(
            amountToSwap > 0,
            "There is no token deposited in token contract"
        );
        swapTokenToBnb(amountToSwap, treasuryReceiver);
    }

    function swapTokenToBnb(uint256 amountToSwap, address to)
        internal
        returns (uint256 amountEthPayout)
    {
        uint256 balanceBefore = address(this).balance;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            to,
            block.timestamp
        );
        amountEthPayout = address(this).balance.sub(balanceBefore);
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        if (_isFeeExempt[from]) {
            return false;
        }
        if (transferFeeEnable) {
            return true;
        }
        return pair == from || pair == to;
    }

    function shouldRebase() internal view returns (bool) {
        return
            _autoRebase &&
            (_totalSupply < MAX_SUPPLY) &&
            msg.sender != pair &&
            !inSwap &&
            block.timestamp >= (_lastRebasedTime + 15 minutes);
    }

    function shouldSwapBack() internal view returns (bool) {
        return !inSwap && msg.sender != pair;
    }

    function setAutoRebase(bool _flag) external onlyOwner {
        if (_flag) {
            _autoRebase = _flag;
            _lastRebasedTime = block.timestamp;
        } else {
            _autoRebase = _flag;
        }
    }

    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(
                subtractedValue
            );
        }
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][
            spender
        ].add(addedValue);
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS.sub(_gonBalances[DEAD]).sub(_gonBalances[ZERO])).div(
                _gonsPerFragment
            );
    }

    function isNotInSwap() external view returns (bool) {
        return !inSwap;
    }

    function manualSync() external {
        IPancakeSwapPair(pair).sync();
    }

    function setFeeReceivers(
        address _treasuryReceiver,
        address _insuranceFundReceiver
    ) external onlyOwner {
        treasuryReceiver = _treasuryReceiver;
        insuranceFundReceiver = _insuranceFundReceiver;
    }

    function setFeeExemp(address[] calldata _addrs, bool flag)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            _isFeeExempt[_addrs[i]] = flag;
        }
    }

    function setWhiteList(address[] calldata _addrs, bool flag)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            _isWhiteList[_addrs[i]] = flag;
        }
    }

    function setFeeS(uint256 _treasuryFeeS, uint256 _insuranceFundFeeS)
        external
        onlyOwner
    {
        treasuryFeeS = _treasuryFeeS;
        insuranceFundFeeS = _insuranceFundFeeS;
        totalFeeS = treasuryFeeS.add(insuranceFundFeeS);
        updateRateFee();
        require(totalFeeS <= 250, "Max 25%");
    }

    function setFeeB(uint256 _treasuryFeeB, uint256 _insuranceFundFeeB)
        external
        onlyOwner
    {
        treasuryFeeB = _treasuryFeeB;
        insuranceFundFeeB = _insuranceFundFeeB;
        totalFeeB = treasuryFeeB.add(insuranceFundFeeB);
        updateRateFee();
        require(totalFeeB <= 250, "Max 25%");
    }

    function updateRateFee() internal {
        uint256 totalTresuryFee = treasuryFeeB.add(treasuryFeeS);
        uint256 totalInsuranceFee = insuranceFundFeeB.add(insuranceFundFeeS);
        uint256 total = totalTresuryFee.add(totalInsuranceFee);
        treasuryFeeRate = totalTresuryFee.mul(feeDenominator).div(total);
        insuranceFundFeeRate = feeDenominator.sub(treasuryFeeRate);
    }

    function setPr(
        address[] calldata _addrs,
        uint256[] calldata _amounts,
        bool flag
    ) external onlyOwner {
        require(_addrs.length == _amounts.length, "1");
        for (uint256 i = 0; i < _addrs.length; i++) {
            prs[_addrs[i]].enable = flag;
            prs[_addrs[i]].amount = _amounts[i];
        }
    }

    function setPairAddress(address _pair) public onlyOwner {
        pair = _pair;
    }

    function setLP(address _address) external onlyOwner {
        pairContract = IPancakeSwapPair(_address);
    }

    function setLimitSaleRate(uint256 _limitSellRate) external onlyOwner {
        limitSellRate = _limitSellRate;
    }

    function setLimitSaleRateBonus(uint256 _limitSellRateBonus)
        external
        onlyOwner
    {
        limitSellRateBonus = _limitSellRateBonus;
    }

    function setLimitSaleRateReduce(uint256 _limitSellRateReduce)
        external
        onlyOwner
    {
        limitSellRateReduce = _limitSellRateReduce;
    }

    function setSecondLimitSell(uint256 _secondLimitSell) external onlyOwner {
        secondLimitSell = _secondLimitSell;
    }

    function setEnableTransferFee(bool enable) external onlyOwner {
        transferFeeEnable = enable;
    }

    function setMaxSellTransaction(uint256 _maxTxn) external onlyOwner {
        maxSellTransactionAmount = _maxTxn;
    }

    function setMoonBoxAffiliate(address addr) external onlyOwner {
        require(addr != address(0), "Zero address");
        affiliate = IMoonBoxAffiliate(addr);
        _allowedFragments[addr][address(router)] = uint256(-1);
        _allowedFragments[addr][pair] = uint256(-1);
        _allowedFragments[addr][addr] = uint256(-1);
        _isFeeExempt[addr] = true;
    }

    function getDecimal() external view override returns (uint256) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function taxFreeAmount(address addr) external view returns (uint256) {
        if (!(boughtAmount[addr] >= _gonBalances[addr].div(_gonsPerFragment))) {
            return
                (_gonBalances[addr].div(_gonsPerFragment)).sub(
                    boughtAmount[addr]
                );
        }
        return 0;
    }

    function setOperator(address operatorAddress, bool value)
        external
        onlyOwner
    {
        require(
            operatorAddress != address(0),
            "operatorAddress is zero address"
        );
        _operators[operatorAddress] = value;
        emit OperatorSetted(operatorAddress, value);
    }

    function toTreasure() external onlyOwner {
        address payable sender = payable(msg.sender);
        sender.transfer(address(this).balance);
    }

    fallback() external payable {}

    receive() external payable {}

    event OperatorSetted(address operatorAddress, bool value);
}

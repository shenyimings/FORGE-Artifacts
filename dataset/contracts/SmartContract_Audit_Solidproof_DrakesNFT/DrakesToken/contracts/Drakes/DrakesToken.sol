//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./Auth.sol";
import "./IBEP20.sol";
import "./SafeMath.sol";
import "./GarbageCleaner.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";

import "./Game/ICrystalToken.sol";
import "./Game/IDrakeMainToken.sol";
import "./Game/IDrakeV0GameMaster.sol";

contract DrakesToken is IBEP20, IDrakeMainToken, Auth, GarbageCleaner {
    using SafeMath for uint256;

    address WETH;
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    string _name;
    string _symbol;
    uint8 constant _decimals = 18;

    uint256 _totalSupply;

    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) isFeeExempt;
    mapping (address => bool) isTxLimitExempt;
    mapping (address => bool) isSystemAddress;

    uint256 buyFee = 500;
    uint256 sellFee = 1500;
    uint256 feeDenominator = 10000;
    uint256 generatedFees = 0;

    uint256 feeMultiplierNumerator = 200;
    uint256 feeMultiplierDenominator = 100;
    uint256 feeMultiplierTriggeredAt;
    uint256 feeMultiplierLength = 120 minutes;

    address public marketingFeeReceiver;

    IDrakeV0GameMaster public gameMaster;
    modifier onlyGameMaster() {
        require(msg.sender == address(gameMaster), "Only GameMaster can call this function");
        _;
    }

    IUniswapV2Router02 public router;
    address public pair;

    bool shouldAutoLaunch = true;
    uint256 public launchedAt;

    uint256 public _maxTxAmount;
    uint256 public maxWalletSize;

    bool public swapEnabled = true;

    bool inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }

    bool priceImpactEnabled = false;
    uint256 priceImpactNumerator = 10000;
    uint256 maxPriceImpact = 333;

    mapping (address => uint256) txHistory;
    uint256 public txCooldown = 10 seconds;
    bool public isCooldownActive = true;

    uint256 firewallLength = 0;

    constructor(
        string memory _token_name,
        string memory _token_symbol,
        address _router_address
    ) Auth(msg.sender) GarbageCleaner(msg.sender) public {
        _name = _token_name;
        _symbol = _token_symbol;

        router = IUniswapV2Router02(_router_address);
        pair = IUniswapV2Factory(router.factory()).createPair(router.WETH(), address(this));
        WETH = router.WETH();

        _allowances[address(this)][address(router)] = uint256(-1);

        _addSystemAddress(address(this), true);
        _addSystemAddress(msg.sender, true);

        isSystemAddress[pair] = true;
        isSystemAddress[DEAD] = true;
        isSystemAddress[ZERO] = true;

        marketingFeeReceiver = msg.sender;

        _mint(msg.sender, 1_000_000_000 * 10 ** 18);

        _maxTxAmount = _totalSupply / 50; // 2%
        maxWalletSize = _totalSupply / 10; // 10%
    }

    receive() external payable { }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external view override returns (uint8) { return _decimals; }
    function symbol() external view override returns (string memory) { return _symbol; }
    function name() external view override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "Burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != uint256(-1)){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (shouldSwapBack()) { swapBack(); }

        if(!launched() && isSystemAddress[sender] && recipient == pair && shouldAutoLaunch) {
            require(_balances[sender] > 0);
            _launch(4, true);
        }

        checkTx(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        bool shouldTakeFee = true;
        if (recipient == pair) {
            shouldTakeFee = !isFeeExempt[sender];
        } else if (sender == pair) {
            shouldTakeFee = !isFeeExempt[recipient];
        }

        uint256 amountReceived = shouldTakeFee ? takeFee(sender, recipient, amount) : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);

        if (address(gameMaster) != address(0)) {
            gameMaster.updateBalance(sender, _balances[sender]);
            gameMaster.updateBalance(recipient, _balances[recipient]);
        }

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function checkTx(address sender, address recipient, uint256 amount) internal {
        if (isSystemAddress[sender] && isSystemAddress[recipient]) { return; }

        require(launched(), "The contract has not launched yet");
        require(amount <= _maxTxAmount || isTxLimitExempt[sender], "TX Limit Exceeded");
        require(isSystemAddress[recipient] || _balances[recipient].add(amount) <= maxWalletSize, "Max Wallet Size Exceeded");

        _checkPriceImpact(sender, recipient, amount);
        _checkAndUpdateCooldown(sender);
        _checkAndUpdateCooldown(recipient);
    }

    function _checkAndUpdateCooldown(address holder) private {
        if (isSystemAddress[holder] || !isCooldownActive) { return; }
        require(txHistory[holder].add(txCooldown) <= block.timestamp, "Cooldown: Too many transactions");
        txHistory[holder] = block.timestamp;
    }

    function _checkPriceImpact(address sender, address recipient, uint256 amount) private view {
        if (checkPriceImpact(sender, recipient)) {
            uint256 priceImpact = gameMaster.priceImpact(pair, amount, priceImpactNumerator);
            require(priceImpact <= maxPriceImpact, "Price Impact too high");
        }
    }

    function checkPriceImpact(address sender, address receiver) internal view returns (bool) {
        return priceImpactEnabled
        && !isTxLimitExempt[sender]
        && receiver == pair
        && balanceOf(pair) > 0
        && address(gameMaster) != address(0);
    }

    function getTotalFee(bool selling) public view returns (uint256) {
        if (launchedAt + firewallLength >= block.number) {
            return feeDenominator.sub(1);
        }

        if (selling && feeMultiplierTriggeredAt.add(feeMultiplierLength) > block.timestamp) {
            uint256 remainingTime = feeMultiplierTriggeredAt.add(feeMultiplierLength).sub(block.timestamp);
            uint256 feeIncrease = sellFee.mul(feeMultiplierNumerator).div(feeMultiplierDenominator).sub(sellFee);
            return sellFee.add(feeIncrease.mul(remainingTime).div(feeMultiplierLength));
        }

        return selling ? sellFee : buyFee;
    }

    function takeFee(address sender, address receiver, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = amount.mul(getTotalFee(receiver == pair)).div(feeDenominator);
        generatedFees = generatedFees.add(feeAmount);

        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        return amount.sub(feeAmount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && generatedFees > 0
        && _balances[address(this)] >= generatedFees;
    }

    function swapBack() internal swapping {
        if (generatedFees == 0) {
            return;
        }

        uint256 amountToSwap = generatedFees;
        generatedFees = 0;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uint256 balanceBefore = address(this).balance;
        try router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        ) {} catch {}

        uint256 ethAmount = address(this).balance.sub(balanceBefore);
        payable(marketingFeeReceiver).transfer(ethAmount.div(2));
    }

    function setSwapBackSettings(bool _enabled) external authorized {
        swapEnabled = _enabled;
    }

    function clearFeeMultiplier() external authorized {
        feeMultiplierTriggeredAt = 0;
    }

    function setFeeMultiplierSettings(uint256 numerator, uint256 denominator, uint256 length) external authorized {
        require(numerator / denominator <= 2 && numerator > denominator);
        feeMultiplierNumerator = numerator;
        feeMultiplierDenominator = denominator;
        feeMultiplierLength = length;
    }

    function setPriceImpactSettings(bool _enabled, uint256 _numerator, uint256 _maxImpact) external authorized {
        require(_numerator >= _maxImpact, "Numerator is invalid");
        priceImpactEnabled = _enabled;
        priceImpactNumerator = _numerator;
        maxPriceImpact = _maxImpact;
    }

    function setWhaleProtectionSettings(
        bool _isCooldownActive,
        uint256 _txCooldown,
        uint256 _maxWalletSize
    ) public authorized {
        isCooldownActive = _isCooldownActive;
        txCooldown = _txCooldown;
        maxWalletSize = _maxWalletSize;
    }

    function setShouldAutoLaunch(bool _shouldAutoLaunch) external authorized {
        shouldAutoLaunch = _shouldAutoLaunch;
    }

    function launch(uint256 _firewallLength) external authorized {
        _launch(_firewallLength, false);
    }

    function stopBotTxs() external authorized {
        launchedAt = 0;
    }

    function _launch(uint256 _firewallLength, bool botLaunch) private {
        launchedAt = block.number;
        feeMultiplierTriggeredAt = block.timestamp;
        firewallLength = _firewallLength;

        _maxTxAmount = _totalSupply / 10;
        maxWalletSize = _totalSupply / 10;

        if (botLaunch) {
            isCooldownActive = false;
            priceImpactEnabled = false;
        } else {
            isCooldownActive = true;
            priceImpactEnabled = true;
        }
    }

    function launched() internal view returns (bool) {
        return launchedAt != 0;
    }

    function setTxLimit(uint256 amount) external authorized {
        require(amount >= _totalSupply / 1000);
        _maxTxAmount = amount;
    }

    function setIsFeeExempt(address holder, bool exempt) external authorized {
        isFeeExempt[holder] = exempt;
    }

    function setIsTxLimitExempt(address holder, bool exempt) external authorized {
        isTxLimitExempt[holder] = exempt;
    }

    function setSystemAddress(address _systemAddress, bool value) external authorized {
        _addSystemAddress(_systemAddress, value);
    }

    function addSystemAddresses(address[] calldata addresses) external authorized {
        for(uint256 i = 0; i < addresses.length; i++) {
            _addSystemAddress(addresses[i], true);
        }
    }

    function _addSystemAddress(address holder, bool value) private {
        isSystemAddress[holder] = value;
        isTxLimitExempt[holder] = value;
        isFeeExempt[holder] = value;
    }

    function setFees(uint256 _buyFee, uint256 _sellFee, uint256 _feeDenominator) external authorized {
        buyFee = _buyFee;
        sellFee = _sellFee;
        feeDenominator = _feeDenominator;
    }

    function setFeeReceiver( address _marketingFeeReceiver) external authorized {
        marketingFeeReceiver = _marketingFeeReceiver;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

    function setRouter(address _router) external authorized {
        require(address(router) != _router, "Router is the same");
        router = IUniswapV2Router02(_router);
    }

    // Game logic
    function setGameMaster(address _gameMaster) external authorized {
        require(_gameMaster != address(gameMaster), "GameMaster is the same");
        require(_gameMaster != address(0), "Wrong GameMaster");

        _addSystemAddress(_gameMaster, true);
        gameMaster = IDrakeV0GameMaster(_gameMaster);
    }

    function swapCrystals(address crystalAddress, uint256 crystalAmount, address player) external override onlyGameMaster returns (bool) {
        require(launched(), "The contract has not launched yet");
        require(IBEP20(crystalAddress).allowance(player, address(this)) >= crystalAmount, "Wrong crystal allowance");

        ICrystalToken(crystalAddress).burnFrom(player, crystalAmount);
        uint256 tokenAmount = IDrakeV0GameMaster(gameMaster).swapAmountForCrystals(crystalAddress, crystalAmount);
        _mint(player, tokenAmount); // Only GameMaster contract can access this function. Dev has no access to it.
        emit CrystalsSwapped(player, crystalAddress, crystalAmount, tokenAmount);
        return true;
    }
}
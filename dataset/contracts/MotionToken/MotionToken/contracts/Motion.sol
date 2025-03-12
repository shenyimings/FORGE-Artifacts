// SPDX-License-Identifier: NOLICENSE
pragma solidity ^0.8.10;
import "./mock_router/UniswapV2Router02.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IBurner {
       function burnSaita() external; 
}

interface IFactory{
        function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) external;

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external ;

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline) external;    
}

contract Motion is IERC20, Ownable {

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) private _isBot;
    mapping(address => bool) private _isPair;

    address[] private _excluded;
    
    // bool private swapping;

    IRouter public router;
    address public pair;
    address public SaitaToken;
    UniswapV2Router02 router02;
    uint8 private constant _decimals = 9;
    uint256 private constant MAX = ~uint256(0);

    uint256 private _tTotal = 10e9* 10**_decimals;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    bool saitaEnabled;
    
    uint256 public swapTokensAtAmount = 1_000 * 10 ** 6;
    uint256 public maxTxAmount = 10_000_000_000 * 10**_decimals;
    
    // Anti Dump //
    mapping (address => uint256) public _lastTrade;
    bool public coolDownEnabled = false;
    uint256 public coolDownTime = 0 seconds;
    address addressThis;
    uint256 public totalMarketingAndBurn;
    uint256 public totalSaitaTax;

    address public treasuryAddress = 0x58Af0b9E13E58d375E801D66020D54705540E129;
    address public marketingAddress = 0xF1c0EAa646b3B1d834274481ce825Bb8F3fce93B;
    address public burnAddress = 0xd21a219f5a4671548cb939625bbB18C8E75eFD15;
    // address public saitaBurner;

    address public USDT = 0xD9c83CCc7BE772B0434c487ADCb9cFd51Abce033;

    string private constant _name = "SaitaMotion";
    string private constant _symbol = "STM";


    struct Taxes {
      uint256 rfi;
      uint256 treasury;
      uint256 marketing;
      uint256 burn;
      uint256 saitaTax;
    }

    Taxes public taxes = Taxes(10,10,20,10,0);

    struct TotFeesPaidStruct {
        uint256 rfi;
        uint256 treasury;
        uint256 marketing;
        uint256 burn;
        uint256 saitaTax;
    }

    TotFeesPaidStruct public totFeesPaid;

    struct valuesFromGetValues{
      uint256 rAmount;
      uint256 rTransferAmount;
      uint256 rRfi;
      uint256 rTreasury;
      uint256 rMarketing;
      uint256 rBurn;
      uint256 rSaitaTax;
      uint256 tTransferAmount;
      uint256 tRfi;
      uint256 tTreasury;
      uint256 tMarketing;
      uint256 tBurn;
      uint256 tSaitaTax;
    }

    event FeesChanged();

    modifier addressValidation(address _addr) {
        require(_addr != address(0), 'Motion Token: Zero address');
        _;
    }

    constructor (address routerAddress, address saitama) {
        IRouter _router = IRouter(routerAddress);
        address _pair = IFactory(_router.factory())
            .createPair(address(this), _router.WETH());
        addressThis = address(this);    
        router = _router;
        pair = _pair;
        SaitaToken = saitama;
        // saitaBurner = _saitaBurner;
        
        addPair(pair);
    
        excludeFromReward(pair);

        _rOwned[owner()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[treasuryAddress] = true;
        _isExcludedFromFee[burnAddress] = true;
        _isExcludedFromFee[marketingAddress] = true;
        
        _transfer(owner(), burnAddress, 25e8*10**_decimals);
        
        emit Transfer(address(0), owner(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }
    function symbol() public pure returns (string memory) {
        return _symbol;
    }
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    
    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount/currentRate;
    }
    
    function enableSaitaTax() public onlyOwner() {
        taxes.saitaTax = 10;
        saitaEnabled = true;
    }

    function disableSaitaTax() public onlyOwner() {
        taxes.saitaTax = 0;
        saitaEnabled = false;
    }
    
    function excludeFromReward(address account) public onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        require(_excluded.length <= 200, "Invalid length");
        require(account != owner(), "Owner cannot be excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }


    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }


    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function addPair(address _pair) public onlyOwner {
        _isPair[_pair] = true;
    }

    function removePair(address _pair) public onlyOwner {
        _isPair[_pair] = false;
    }

    function isPair(address account) public view returns(bool){
        return _isPair[account];
    }

    function setTaxes(uint256 _rfi, uint256 _treasury, uint256 _marketing, uint256 _burn, uint256 _saitaTax) public onlyOwner {
        taxes.rfi = _rfi;
        taxes.treasury = _treasury;
        taxes.marketing = _marketing;
        taxes.burn = _burn;
        taxes.saitaTax = _saitaTax;
        emit FeesChanged();
    }

    function _reflectRfi(uint256 rRfi, uint256 tRfi) private {
        _rTotal -=rRfi;
        totFeesPaid.rfi += tRfi;
    }

    function _takeTreasury(uint256 rTreasury, uint256 tTreasury) private {
        totFeesPaid.treasury += tTreasury;
        if(_isExcluded[treasuryAddress]) _tOwned[treasuryAddress] += tTreasury;
        _rOwned[treasuryAddress] +=rTreasury;
    }
    
    function _takeMarketing(uint256 rMarketing, uint256 tMarketing) private{
        totFeesPaid.marketing += tMarketing;
        if(_isExcluded[address(this)]) _tOwned[address(this)] += tMarketing;
        _rOwned[address(this)] += rMarketing;
    }

    function _takeBurn(uint256 rBurn, uint256 tBurn) private {
        totFeesPaid.burn += tBurn;
        if(_isExcluded[address(this)]) _tOwned[address(this)] += tBurn;
        _rOwned[address(this)] += rBurn;
    }

    function _takeSaita(uint256 rSaitaTax, uint256 tSaitaTax) private { 
        totFeesPaid.saitaTax += tSaitaTax;
        if(_isExcluded[address(this)]) _tOwned[address(this)] += tSaitaTax;
        _rOwned[address(this)]+= rSaitaTax;
    }

    function liquifyMarketingAndBurn() private {
       address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        uint256 MarketAmount = (totalMarketingAndBurn * taxes.marketing)/(taxes.marketing + taxes.burn);
        uint256 BurnAmount = (totalMarketingAndBurn * taxes.burn) / (taxes.marketing + taxes.burn);
   
        _approve(address(this), address(router), totalMarketingAndBurn);
        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            MarketAmount,
            0, // accept any amount of ETH
            path,
            marketingAddress,
            block.timestamp + 1200
        );
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            BurnAmount,
            0, // accept any amount of ETH
            path,
            burnAddress,
            block.timestamp + 1200
        );
        totalMarketingAndBurn = 0;
    }

    function _getValues(uint256 tAmount, bool takeFee) private view returns (valuesFromGetValues memory to_return) {
        to_return = _getTValues(tAmount, takeFee);
        (to_return.rAmount, to_return.rTransferAmount, to_return.rRfi, to_return.rTreasury,to_return.rMarketing, to_return.rBurn, to_return.rSaitaTax) = _getRValues(to_return, tAmount, takeFee, _getRate());
        return to_return;
    }

    function _getTValues(uint256 tAmount, bool takeFee) private view returns (valuesFromGetValues memory s) {

        if(!takeFee) {
          s.tTransferAmount = tAmount;
          return s;
        } else {
            s.tRfi = (tAmount*taxes.rfi)/1000;
            s.tTreasury = (tAmount*taxes.treasury)/1000;
            s.tMarketing = tAmount*taxes.marketing/1000;
            s.tBurn = tAmount*taxes.burn/1000;
            s.tSaitaTax = tAmount*taxes.saitaTax/1000;
            s.tTransferAmount = tAmount-s.tRfi-s.tTreasury-s.tMarketing-s.tBurn-s.tSaitaTax;
            return s;
        } 
    }

    function _getRValues(valuesFromGetValues memory s, uint256 tAmount, bool takeFee, uint256 currentRate) private pure returns (uint256 rAmount, uint256 rTransferAmount, uint256 rRfi,uint256 rTreasury,uint256 rMarketing,uint256 rBurn, uint256 rSaitaTax) {
        rAmount = tAmount*currentRate;

        if(!takeFee) {
          return(rAmount, rAmount, 0,0,0,0,0);
        }else {
            rRfi = s.tRfi*currentRate;
            rTreasury = s.tTreasury*currentRate;
            rMarketing = s.tMarketing*currentRate;
            rBurn = s.tBurn*currentRate;
            rSaitaTax = s.tSaitaTax*currentRate;
            rTransferAmount =  rAmount-rRfi-rTreasury-rMarketing-rBurn-rSaitaTax;
            return (rAmount, rTransferAmount, rRfi,rTreasury,rMarketing,rBurn,rSaitaTax);
        }
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply/tSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply-_rOwned[_excluded[i]];
            tSupply = tSupply-_tOwned[_excluded[i]];
        }

        if (rSupply < _rTotal/_tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Zero amount");
        require(amount <= balanceOf(from),"Insufficient balance");
        require(!_isBot[from] && !_isBot[to], "You are a bot");
        require(amount <= maxTxAmount ,"Amount is exceeding maxTxAmount");
        bool takeFee = true;

        if (coolDownEnabled) {
            uint256 timePassed = block.timestamp - _lastTrade[from];
            require(timePassed > coolDownTime, "You must wait coolDownTime");
        }
        
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);

        _lastTrade[from] = block.timestamp;


        if(from != pair && to != pair && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]){
            address[] memory path = new address[](3);
                path[0] = address(this);
                path[1] = router.WETH();
                path[2] = USDT;
            uint _amount;
            uint _amount1;
                    

            if(totalSaitaTax != 0){
                _amount = router.getAmountsOut(totalSaitaTax, path)[2];  
                if(_amount >= swapTokensAtAmount && saitaEnabled) swapAndBurnSaita();  
            }

            if(totalMarketingAndBurn != 0){
                _amount1 = router.getAmountsOut(totalMarketingAndBurn,path)[2];
                if(_amount1 >= swapTokensAtAmount) liquifyMarketingAndBurn();
            } 
        }
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 tAmount, bool takeFee) private {
        valuesFromGetValues memory s = _getValues(tAmount, takeFee);

        if (_isExcluded[sender] ) {  //from excluded
                _tOwned[sender] = _tOwned[sender] - tAmount;
        }
        if (_isExcluded[recipient]) { //to excluded
                _tOwned[recipient] = _tOwned[recipient] + s.tTransferAmount;
        }

        _rOwned[sender] = _rOwned[sender]-s.rAmount;
        _rOwned[recipient] = _rOwned[recipient]+s.rTransferAmount;
        
        if(s.rRfi > 0 || s.tRfi > 0) _reflectRfi(s.rRfi, s.tRfi);
      
        if(s.rTreasury > 0 || s.tTreasury > 0){
            _takeTreasury(s.rTreasury, s.tTreasury);
            emit Transfer(sender, treasuryAddress, s.tTreasury);
        }
        if(s.rMarketing > 0 || s.tMarketing > 0){
            totalMarketingAndBurn +=  s.tMarketing;
            _takeMarketing(s.rMarketing, s.tMarketing);
            emit Transfer(sender, address(this), s.tMarketing);
        }
        if(s.rBurn > 0 || s.tBurn > 0){
            totalMarketingAndBurn += s.tBurn;
            _takeBurn(s.rBurn, s.tBurn);
            emit Transfer(sender, address(this), s.tBurn);
        }
        if(saitaEnabled && s.rSaitaTax > 0 || s.tSaitaTax > 0){
            totalSaitaTax += s.tSaitaTax;  
            _takeSaita(s.rSaitaTax, s.tSaitaTax);   
            emit Transfer(sender,address(this), s.tSaitaTax);
        }  
        emit Transfer(sender, recipient, s.tTransferAmount);      
    }

    function updateTreasuryWallet(address newWallet) external onlyOwner addressValidation(newWallet) {
        require(treasuryAddress != newWallet, 'SaitaRealty: Wallet already set');
        treasuryAddress = newWallet;
        _isExcludedFromFee[treasuryAddress];
    }

    function updateBurnWallet(address newWallet) external onlyOwner addressValidation(newWallet) {
        require(burnAddress != newWallet, 'SaitaRealty: Wallet already set');
        burnAddress = newWallet;
        _isExcludedFromFee[burnAddress];
    }

    function updateMarketingWallet(address newWallet) external onlyOwner addressValidation(newWallet) {
        require(marketingAddress != newWallet, 'SaitaRealty: Wallet already set');
        marketingAddress = newWallet;
        _isExcludedFromFee[marketingAddress];
    }

    function updateStableCoin(address _usdt) external onlyOwner  addressValidation(_usdt) {
        require(USDT != _usdt, 'SaitaRealty: Wallet already set');
        USDT = _usdt;
    }

    function updateMaxTxAmt(uint256 amount) external onlyOwner {
        require(amount >= 100);
        maxTxAmount = amount * 10**_decimals;
    }

    function updateSwapTokensAtAmount(uint256 amount) external onlyOwner {
        require(amount > 0);
        swapTokensAtAmount = amount * 10**6;
    }

    function updateCoolDownSettings(bool _enabled, uint256 _timeInSeconds) external onlyOwner{
        coolDownEnabled = _enabled;
        coolDownTime = _timeInSeconds * 1 seconds;
    }

    function setAntibot(address account, bool state) external onlyOwner{
        require(_isBot[account] != state, 'SaitaRealty: Value already set');
        _isBot[account] = state;
    }
    
    function bulkAntiBot(address[] memory accounts, bool state) external onlyOwner {
        require(accounts.length <= 100, "SaitaRealty: Invalid");
        for(uint256 i = 0; i < accounts.length; i++){
            _isBot[accounts[i]] = state;
        }
    }
    
    function updateRouterAndPair(address newRouter, address newPair) external onlyOwner {
        router = IRouter(newRouter);
        pair = newPair;
        addPair(pair);
    }
    
    function isBot(address account) public view returns(bool){
        return _isBot[account];
    }
    
    function swapAndBurnSaita() private {
      address dead = 0x000000000000000000000000000000000000dEaD;
      address[] memory path1 = new address[](3);
      path1[0] = address(this);
      path1[1] = router.WETH();
      path1[2] = SaitaToken;
      _approve(address(this), address(router), totalSaitaTax);
      router.swapExactTokensForTokensSupportingFeeOnTransferTokens(totalSaitaTax, 0, path1, dead, block.timestamp+1200);
      totalSaitaTax = 0;
    }

    function airdropTokens(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length,"Invalid size");
         address sender = msg.sender;

         for(uint256 i; i<recipients.length; i++){
            address recipient = recipients[i];
            uint256 rAmount = amounts[i]*_getRate();
            _rOwned[sender] = _rOwned[sender]- rAmount;
            _rOwned[recipient] = _rOwned[recipient] + rAmount;
            emit Transfer(sender, recipient, amounts[i]);
         }

        }

    //Use this in case ETH are sent to the contract by mistake
    function rescueETH(uint256 weiAmount) external onlyOwner{
        require(address(this).balance >= weiAmount, "insufficient ETH balance");
        payable(owner()).transfer(weiAmount);
    }
    
    // Function to allow admin to claim *other* ERC20 tokens sent to this contract (by mistake)
    // Owner cannot transfer out catecoin from this smart contract
    function rescueAnyERC20Tokens(address _tokenAddr, address _to, uint _amount) public onlyOwner {
        IERC20(_tokenAddr).transfer(_to, _amount);
    }

    receive() external payable {
    }
}
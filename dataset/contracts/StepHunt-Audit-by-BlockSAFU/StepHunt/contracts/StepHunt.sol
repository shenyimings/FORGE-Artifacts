// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IPinkAntibot.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Context.sol";
import "./libraries/Auth.sol";
import "./libraries/SafeERC20.sol";

contract StepHunt is Context, Auth, IERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //ERC20
    uint8 private _decimals = 18;
    uint256 private _totalSupply = 1_000_000_000 * (10**_decimals);
    string private _name = "StepHunt Governance Token";
    string private _symbol = "HUNT";
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    //Tokenomic
    uint256 public percentBuy = 500;
    uint256 public percentSell = 500;
    uint256 public percentTaxDenominator = 10000;

    uint256 public minimumSwapForWeth = 1 * (10**_decimals);

    bool public isAutoSwapForWeth = true;
    bool public isTaxBuyEnable = true;
    bool public isTaxSellEnable = true;
    bool public isPinkAntibotEnable = true;

    mapping(address => bool) public isExcludeFromFee;

    address public taxReceiverAddress = 0x2Ce7369d0Bf30A8FCA0a77376da0de196CB0C7EE;
    address ZERO = 0x0000000000000000000000000000000000000000;
    address DEAD = 0x000000000000000000000000000000000000dEaD;

    address public factoryAddress;
    address public wethAddress;
    address public routerAddress;
    
    address public pinkAntibotAddress;
    IPinkAntiBot public pinkAntiBot;
    
    mapping(address => bool) public isPair;

    bool inSwap;

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
      address _routerAddress,
      address _pinkAntiBotAddress
    ) Auth(msg.sender) {

      routerAddress = _routerAddress;

      wethAddress = IUniswapV2Router02(routerAddress).WETH();
      factoryAddress = IUniswapV2Router02(routerAddress).factory();
      IUniswapV2Factory(factoryAddress).createPair(address(this), wethAddress);
      address pairWETH = IUniswapV2Factory(factoryAddress).getPair(address(this), wethAddress);
      isPair[pairWETH] = true;

      isExcludeFromFee[msg.sender] = true;
      isExcludeFromFee[routerAddress] = true;

      pinkAntibotAddress = _pinkAntiBotAddress;
      pinkAntiBot = IPinkAntiBot(_pinkAntiBotAddress);
      pinkAntiBot.setTokenOwner(msg.sender);
      
      _approve(address(this), routerAddress, _totalSupply);

      _balances[msg.sender] = _totalSupply;
      emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function getOwner() public view virtual override returns (address) {
        return _getOwner();
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (_allowances[sender][msg.sender] != _totalSupply) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender]
                .sub(amount, "StepHunt: Insufficient Allowance");
        }
        _transfer(sender,recipient,amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "Blocksafu: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "Blocksafu: approve from the zero address");
        require(spender != address(0), "Blocksafu: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
      _beforeTransferToken(sender, recipient, amount);
      if(isPinkAntibotEnable) pinkAntiBot.onPreTransferCheck(sender, recipient, amount);
      if(shouldTakeFee(sender, recipient)){
        _complexTransfer(sender, recipient, amount);
      } else {
        _basicTransfer(sender, recipient, amount);
      }
      _afterTransferToken(sender, recipient, amount);
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal {
      _balances[sender] = _balances[sender].sub(amount);
      _balances[recipient] = _balances[recipient].add(amount);
      emit Transfer(sender, recipient, amount);
    }

    function _complexTransfer(address sender, address recipient, uint256 amount) internal {
      uint256 amountTransfer = getAmountTransfer(amount, sender);

      if(shouldSwapForWeth(sender)) _swapForWeth(_balances[address(this)]);

      _balances[sender] = _balances[sender].sub(amount);
      _balances[recipient] = _balances[recipient].add(amountTransfer);
      emit Transfer(sender, recipient, amount);
    }

    function getAmountTransfer(uint256 amount, address sender) internal returns(uint256){
      uint256 percentTotalTax;
      uint256 amountTax;
      if(isPair[sender]) {
        percentTotalTax = percentBuy;
      } else {
        percentTotalTax = percentSell;
      }

      amountTax = amount.mul(percentTotalTax).div(percentTaxDenominator);
    
      _balances[address(this)] = _balances[address(this)].add(amountTax);
      emit Transfer(sender, address(this), amount);

      return amount.sub(amountTax);
    }

    function _beforeTransferToken(address sender, address recipient, uint256 amount) internal view {
      
    }

    function _afterTransferToken(address sender, address recipient, uint256 amount) internal {
      
    }

    function burn(uint256 amount) external {
        require(_balances[_msgSender()] >= amount,"StepHunt: Insufficient Amount");
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        _balances[account] = _balances[account].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, DEAD, amount);
    }


    function shouldTakeFee(address sender, address recipient) internal view returns(bool){
      if(inSwap) return false;
      if(isExcludeFromFee[sender]) return false;
      if(isPair[sender] && !isTaxBuyEnable) return false;
      if(isPair[recipient] && !isTaxSellEnable) return false;
      return true;
    }

    function shouldSwapForWeth(address sender) internal view returns(bool){
      return (isAutoSwapForWeth && !isPair[sender] && !inSwap && IERC20(address(this)).balanceOf(address(this)) >= minimumSwapForWeth); 
    }

    function setIsPair(address pairAddress, bool state) external onlyOwner {
      isPair[pairAddress] = state;
    }

    function setPinkAntibotEnable(bool state) external onlyOwner {
      isPinkAntibotEnable = state;
    }

    function setPinkAntibotAddress(address _pinkAntiBotAddress) external onlyOwner {
      pinkAntibotAddress = _pinkAntiBotAddress;
      pinkAntiBot = IPinkAntiBot(_pinkAntiBotAddress); 
      pinkAntiBot.setTokenOwner(msg.sender);
    }

    function setTaxReceiver(address _taxReceiverAddress) external onlyOwner {
      taxReceiverAddress = _taxReceiverAddress;
    }

     function setIsTaxEnable(bool taxBuy, bool taxSell) external onlyOwner {
      isTaxBuyEnable = taxBuy;
      isTaxSellEnable = taxSell;
    }

    function setIsExcludeFromFee(address account, bool state) external authorized {
      isExcludeFromFee[account] = state;
    }

    function setAutoSwapForWeth(bool state,uint256 amount) external onlyOwner {
      require(amount <= _totalSupply,"StepHunt: Amount Swap For Weth max total supply");
      isAutoSwapForWeth = state;
      minimumSwapForWeth = amount;
    }

    function setPercentTaxBuy(uint256 _percentTax) external onlyOwner {
      require(_percentTax <= 5000,"StepHunt: Maximum Tax is 50%");
      percentBuy = _percentTax;
    }

    function setPercentTaxSell(uint256 _percentTax) external onlyOwner {
      require(_percentTax <= 5000,"StepHunt: Maximum Tax is 50%");
      percentSell = _percentTax;
    }
    

    function _buyToken(uint256 amount, address to) internal swapping {
      IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
      address[] memory path = new address[](2);
      path[0] = wethAddress;
      path[1] = address(this);
      
      router.swapExactETHForTokensSupportingFeeOnTransferTokens{value:amount}(
        0,
        path, 
        to, 
        block.timestamp.add(300)
      );
    }

    function _swapForWeth(uint256 amount) internal swapping {
      if(amount > 0) {
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = wethAddress;
        
        uint256[] memory estimate = router.getAmountsOut(amount, path);

        uint256 amountForSwap = estimate[1];

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            amountForSwap,
            path,
            taxReceiverAddress,
            block.timestamp
        );
      }
    }

    function swapForWeth(uint256 amount) external onlyOwner {
      _swapForWeth(amount);
    }
}
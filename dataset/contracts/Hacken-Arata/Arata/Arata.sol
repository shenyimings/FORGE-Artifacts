// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router.sol";
import "./ERC20.sol";

contract Arata is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool private swapping;
    
    // 1 = buy, 2 = sell
    uint256 private PreviousTransfer;

    address public liquidityWallet;

    uint256 public swapTokensAtAmount =  100 * (10 ** 18);
    
    bool public EnableFees;
    
    bool TookFeesOnPreviousTransaction;
    
    uint256 public BuyMiningTax;
    uint256 public BuyLiquidityTax;
    uint256 public TotalBuyTax;
   
    uint256 public SellMiningTax;
    uint256 public SellLiquidityTax;
    uint256 public TotalSellTax;
    
    
    address public MiningAddress;
   
    // exlcude from fees and max transaction amount
    mapping (address => bool) private _isExcludedFromFees;
    
    
    // BlackList Reported address
    mapping(address => bool) _BlackList;
    
   // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event addedLiquidity(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

      constructor() ERC20("Arata", "ARATA") {
    
    	liquidityWallet = msg.sender;
    	
    	MiningAddress = msg.sender;
    	
    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(msg.sender, true);
        excludeFromFees(address(this), true);
        
    
    
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 5000000 * (10**18));
    }

    receive() external payable {
        
    }
    
    function IsBlackListed(address account) public view returns(bool){
        return(_BlackList[account]);
    }
    
    function BlackListAddress(address account,bool exclude) public onlyOwner returns(bool){
        require(_BlackList[account] != exclude,"Same Value");
        _BlackList[account] = exclude;
        return(true);
    }
    
   
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "TIKI: Account is already the value of 'excluded'");
        _isExcludedFromFees[account] = excluded;
    }

  
    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "TIKI: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "TIKI: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }


    function SetMiningAddress(address NewAddress) public onlyOwner returns(bool){
        require(MiningAddress != NewAddress,"Same value");
        MiningAddress = NewAddress;
        return(true);
    }
    
    
    function SetBuyTax(uint256 LiquidityTax,uint256 MiningTaxs) public onlyOwner returns(bool){
        require(LiquidityTax.add(MiningTaxs) <= 10,"Tax Too high");
        BuyLiquidityTax = LiquidityTax;
        BuyMiningTax = MiningTaxs;
        TotalBuyTax = LiquidityTax.add(MiningTaxs);
        return(true);
    }
    
    function SetSellTax(uint256 LiquidityTax,uint256 MiningTaxs) public onlyOwner returns(bool){
        require(LiquidityTax.add(MiningTaxs) <= 10,"Tax Too high");
        SellLiquidityTax = LiquidityTax;
        SellMiningTax = MiningTaxs;
        TotalSellTax = LiquidityTax.add(MiningTaxs);
        return(true);
    }
    
    function EnableAllFees(bool s) public onlyOwner {
        require(s != EnableFees,"Same value");
        EnableFees = s;
    }
    
    
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!_BlackList[from] && !_BlackList[to],"Black listed addresses cannnot do transfers");
        
 
   
        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

       
		uint256 contractTokenBalance = balanceOf(address(this));
        
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if( canSwap &&
            !swapping &&
            TookFeesOnPreviousTransaction &&
            !automatedMarketMakerPairs[from] &&
            from != liquidityWallet &&
            to != liquidityWallet
        ) {
            swapping = true;
            
            if (PreviousTransfer ==  1) {
                
                uint256 swapTokens = BuyLiquidityTax.mul(contractTokenBalance).div(TotalBuyTax);
                swapAndLiquify(swapTokens);
                
                swapAndSendBNBToMiningAddress(balanceOf(address(this)));
                
                
            } else {
                
                uint256 Toswap = SellLiquidityTax.mul(contractTokenBalance).div(TotalSellTax);
                swapAndLiquify(Toswap);
                
                uint256 tosell = balanceOf(address(this));
                swapAndSendBNBToMiningAddress(tosell);
                
                
            }
            swapping = false;
        }


        bool takeFee =  !swapping && EnableFees;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if(takeFee) {
            
            uint256 fees;
            
            if(automatedMarketMakerPairs[from]){
                fees = TotalBuyTax.mul(amount).div(100);
                PreviousTransfer = 1;
            } 
            
            if(automatedMarketMakerPairs[to]){
                fees = TotalSellTax.mul(amount).div(100);
                PreviousTransfer = 2;
            }
            
            // To check if this transaction took fees
            // Saves Gas
            if(fees == 0){
                
                TookFeesOnPreviousTransaction = false;
                
            } else {
                
                TookFeesOnPreviousTransaction = true;
                
            }
            
            amount = amount.sub(fees);
            
            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);

    }

    function swapAndLiquify(uint256 tokens) internal {
        // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); 

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit addedLiquidity(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) internal {

        
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityWallet,
            block.timestamp
        );
        
    }
    
    function swapAndSendBNBToMiningAddress(uint256 tokens) private {
        // swap tokens to eth to transfer to Mining address
        swapTokensForEth(tokens);
        // To prevent unnessary returns from call and send function transfer is used
        // No value to change balance of contract is sent
        // Revert means that the receiver address is a not payble contract
        payable(MiningAddress).transfer(address(this).balance);
    }
    
    
    

   }


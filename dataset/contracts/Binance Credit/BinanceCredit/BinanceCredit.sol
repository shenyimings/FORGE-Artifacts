// https://binance.credit

// https://t.me/binancecredit

pragma solidity ^0.5.4;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) { 
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
}

interface IBITCOIN {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);    
}

interface ISHARES {
    function balanceOf(address account) external view returns (uint256);
    function mint(address spender, uint256 _amount) external;
    function burn(uint256 amount) external;
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract BinanceCredit {
  	address payable internal fundAddress = 0x263d126Da89BC62a6e7188d884eAD3DF391362BF;
 	address payable internal owner = 0x4f5FbcFEf048b8199cA75a1E6bb226503CF6261C; 
    IBITCOIN internal BITCOIN = IBITCOIN(address(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c));
    ISHARES internal SHARES = ISHARES(address(0xe7C6E595dCf44dED3033efD943229A17903FD3C5));

    uint32 private investmentRate = 10;
    uint32 private dripRate = 10; 
    uint32 private powerBurnRate = 100;
	uint32 private cycleLength = 7;
    uint32 private tradingFee = 999;
    uint32 private constant LAUNCH_TIME = 1616538147;
    uint32 private constant FACTOR = 100;

    uint256 private lastDripTime = currentDay(); 
    uint256 private profitPerShare;
    uint256 private dividendsPool;
    uint256 private sharePrice;
    uint256 private totalShares;
    uint256 private totalSupply; 
    uint256 private investable;
    uint256 constant internal MAGNITUDE = 2 ** 64;
 
    mapping(address => uint256) private payoutsTo;
    mapping(address => uint256) private stakedOf;
    mapping(address => uint256) private stakeStart;
    mapping(address => uint256) private power;
    mapping(address => uint256) private burns;

    event Deposit(address _from, uint256 _value);
    event Penalty(address _from, uint256 _lostDivs);
    event Reinvest(address _from, uint256 _divs, uint256 _earned);
    event WithdrawDivs(address _from,uint256 _divs, uint256 _earned);
    event Convert(address _from, uint256 _divs, uint256 _earned);
    event Drip(uint256 _divs, uint256 _investment, uint256 _timestamp);
    event Mint(uint256 _value); 
    event Invest(uint256 _value);  
    event BuyPower(address _from, uint256 _powerAmount); 
    event BuyShares(address _from, uint256 _powerInput, uint256 _sharesOutput, uint256 _sharePriceBefore, uint256 _sharePriceAfter, uint256 _timestamp); 
    event SellShares(address _from, uint256 _sharesInput, uint256 _powerOutput, uint256 _sharePriceBefore, uint256 _sharePriceAfter, uint256 _timestamp); 

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function drip() public { 
        if(totalSupply > 0 && currentDay() > lastDripTime) { 
            uint256 dividends = (dividendsPool * dripRate) / 1000;
			dividendsPool = SafeMath.sub(dividendsPool, dividends); 
            uint256 investment = (dividends * investmentRate) / 100;
            dividends = SafeMath.sub(dividends, investment); 
			lastDripTime = currentDay();
			profitPerShare = SafeMath.add(profitPerShare, (dividends * MAGNITUDE) / totalSupply);
			investable += investment;
			emit Drip(dividends, investment, now);
        }
    }
    
    modifier hasDripped() {
        drip();
        _;
    }

   constructor() public {
       totalShares = 6000000000;
       sharePrice = totalShares / FACTOR;
   }

    function buyPower(uint256 _powerAmount) hasDripped external  {
        require(_powerAmount > 0);
        require(stakedOf[msg.sender] > 0);
        uint256 balanceBefore = BITCOIN.balanceOf(address(this));
        BITCOIN.transferFrom(msg.sender, address(this), _powerAmount);
        uint256 balanceAfter = BITCOIN.balanceOf(address(this));
        uint256 diff = SafeMath.sub(balanceAfter, balanceBefore);
        require(diff > 0); 
        increasePower(msg.sender, diff);
        dividendsPool += diff;
        emit BuyPower(msg.sender, diff);
    }

    function increasePower(address _userAddr, uint256 _powerAmount) internal {
        uint256 userPower = power[_userAddr] - getNegativePower(_userAddr);
        if(userPower < stakedOf[_userAddr] && stakedOf[_userAddr] > 0) {
            uint256 totalDivs = dividendsOf(_userAddr);
			if(totalDivs > 0) {
				uint256 lostDivs;
				uint256 oldEfficiency = 100 * userPower / stakedOf[_userAddr];
				if (_powerAmount + userPower >= stakedOf[_userAddr]) {
					lostDivs = totalDivs - totalDivs * oldEfficiency / 100;
				} else {
					uint256 newEfficiency = 100 * (_powerAmount + userPower) / stakedOf[_userAddr];
					if(newEfficiency > 0) {
					    lostDivs = totalDivs - totalDivs * oldEfficiency / newEfficiency;
					}
				}  
				payoutsTo[_userAddr] += lostDivs * MAGNITUDE;
				dividendsPool += lostDivs;
				emit Penalty(_userAddr, lostDivs); 
			}
        }  
        if(userPower == 0) {
            power[_userAddr] = _powerAmount;
            stakeStart[_userAddr] = currentDay();
        } else {
            power[_userAddr] += _powerAmount;
        } 
    } 
    
    function stakeBtc(uint256 _btcAmount) hasDripped external  {
        require(_btcAmount > 0);
        uint256 balanceBefore = BITCOIN.balanceOf(address(this));
        BITCOIN.transferFrom(msg.sender, address(this), _btcAmount);
        uint256 balanceAfter = BITCOIN.balanceOf(address(this));
        uint256 diff = SafeMath.sub(balanceAfter, balanceBefore);
        require(diff > 0); 
        _stake(msg.sender, diff);
        emit Deposit(msg.sender, diff);   
    }
    
	function powerToShares(uint256 _powerAmount) public view returns (uint256, uint256) {
		uint256 buySharePrice = sharePrice + _powerAmount / ( FACTOR * sharePrice);
		uint256 sharesOutput = _powerAmount * tradingFee / (buySharePrice * 1000);
		uint256 sharesOutput2 =  _powerAmount * tradingFee / (sharePrice * 1000);
		return (sharesOutput * (10 ** 11), sharesOutput2 * (10 ** 11));
	}

	function sharesToPower(uint256 _amount) public view returns (uint256, uint256) {
		uint256 amount = _amount / (10 ** 11);
		uint256 _totalShares = SafeMath.sub(totalShares, amount);
        uint256 sellSharePrice = _totalShares / FACTOR;
		return (amount * sellSharePrice * tradingFee / 1000, amount * sharePrice * tradingFee / 1000);
	}

    function burn(uint256 _powerAmount) external {
        require(_powerAmount > 0);
        uint256 userPower = power[msg.sender] - getNegativePower(msg.sender);
		require(userPower >= _powerAmount);
		require(stakedOf[msg.sender] > 0);	
		power[msg.sender] -= _powerAmount;
        burns[msg.sender] += _powerAmount;
    }
    
    function buyShares(uint256 _powerAmount, uint256 _price, uint256 _slippageTolerance) external {
        require(_powerAmount > 0);
        require(_slippageTolerance < 1000);
		require(sharePrice * 1000 / _price < (1000 + _slippageTolerance));
        uint256 userPower = power[msg.sender] - getNegativePower(msg.sender);
		require(userPower >= _powerAmount);
		require(userPower >= stakedOf[msg.sender] + _powerAmount);	
		require(stakedOf[msg.sender] > 0);
        uint256 sharePriceBefore = sharePrice;		
		power[msg.sender] -= _powerAmount;
		uint256 buySharePrice = sharePrice + _powerAmount / ( FACTOR * sharePrice);		
		uint256 sharesOutput = _powerAmount * tradingFee / (buySharePrice * 1000);
		require(sharesOutput > 0);
		totalShares += sharesOutput;
        sharePrice = totalShares / FACTOR;
        SHARES.mint(msg.sender, sharesOutput * (10 ** 11));
		emit BuyShares(msg.sender, _powerAmount, sharesOutput * (10 ** 11), sharePriceBefore, sharePrice, now); 
	}
    
    function sellShares(uint256 _amount, uint256 _price, uint256 _slippageTolerance) hasDripped public {
        uint256 sharePriceBefore = sharePrice; 
        require(_slippageTolerance < 1000);
		require( _price * 1000 / sharePrice < (1000 + _slippageTolerance));
        uint256 balanceBefore = SHARES.balanceOf(address(this));
        SHARES.transferFrom(msg.sender, address(this), _amount);        
        uint256 balanceAfter = SHARES.balanceOf(address(this));
		uint256 diff = SafeMath.sub(balanceAfter, balanceBefore) / (10 ** 11);
		require(diff > 0);
		totalShares = SafeMath.sub(totalShares, diff);
        sharePrice = totalShares / FACTOR;
        uint256 powerOutput = diff * sharePrice * tradingFee / 1000;
		SHARES.burn(_amount);
		increasePower(msg.sender, powerOutput);
		emit SellShares(msg.sender, _amount, powerOutput, sharePriceBefore, sharePrice, now);
	}
    
    function mintPower() hasDripped external {
		require(stakedOf[msg.sender] > 0);
		require(power[msg.sender] > 0);
        uint256 userMint = getMintablePower(msg.sender);
        power[msg.sender] = power[msg.sender] - getNegativePower(msg.sender);
        stakeStart[msg.sender] = currentDay();
        increasePower(msg.sender, userMint); 
        emit Mint(userMint);
    }

	function invest() external {
	    uint256 investableAmount = investable;
		investable = 0;
	    BITCOIN.transfer(fundAddress, investableAmount); 
		emit Invest(investableAmount);
	}

    function collectForgottenBtc(address _userAddr) hasDripped external {
        require(power[_userAddr] == getNegativePower(_userAddr));
        require(stakedOf[_userAddr] > 0);
        uint256 totalDivs = dividendsOf(_userAddr);
        payoutsTo[_userAddr] += totalDivs * MAGNITUDE;
        dividendsPool += totalDivs;
        emit Penalty(_userAddr, totalDivs);   
    }
    
    function _stake(address _userAddr, uint256 _value) internal {
		totalSupply += _value;
	    dividendsPool += _value;
	    uint256 powerToMint = _value;
        if(stakedOf[_userAddr] > 0) {
            increasePower(_userAddr, powerToMint + getMintablePower(_userAddr));
            power[_userAddr] = power[_userAddr] - getNegativePower(_userAddr);
        } else {
            power[_userAddr] += powerToMint;            
        }
        stakeStart[_userAddr] = currentDay();
        payoutsTo[_userAddr] += profitPerShare * _value;
        stakedOf[_userAddr] += _value;
    }   

    function reinvest() hasDripped external {
        uint256 divs = dividendsOf(msg.sender);
        require(divs > 0);
        uint256 efficiency = getEfficiency(msg.sender);
        payoutsTo[msg.sender] += divs * MAGNITUDE;
        uint256 earned = divs * efficiency / 100 ;
        _stake(msg.sender, earned);
        uint256 temp = SafeMath.sub(divs, earned); 
        dividendsPool += temp;
    	emit Reinvest(msg.sender, divs, earned);
    }
	
    function withdrawDivs() hasDripped external {
        uint256 divs = dividendsOf(msg.sender);
        require(divs > 0);
        uint256 earned = divs * getEfficiency(msg.sender) / 100 ;
        uint256 powerfee = earned / 10;
        uint256 userPower = power[msg.sender] - getNegativePower(msg.sender);
        require(powerfee <= userPower);
        power[msg.sender] = SafeMath.sub(power[msg.sender], powerfee);
        payoutsTo[msg.sender] += divs * MAGNITUDE;
        uint256 temp = SafeMath.sub(divs, earned);
        dividendsPool += temp; 
        emit WithdrawDivs(msg.sender, divs, earned);
        BITCOIN.transfer(msg.sender, earned);
    }

    function dividendsToPower() hasDripped external {
        uint256 divs = dividendsOf(msg.sender);
        require(divs > 0);
        payoutsTo[msg.sender] += divs * MAGNITUDE;
        uint256 earned = divs * getEfficiency(msg.sender) / 100 ;
        dividendsPool += divs;
        increasePower(msg.sender, earned);
        emit Convert(msg.sender, divs, earned);
    }

	function currentDay() internal view returns (uint256) {
        return (now - LAUNCH_TIME) / 1 days;
    }
 
    function estimateDividendsOf(address _userAddr) internal view returns (uint256) {
        if(totalSupply > 0) {
            uint256 dividends = (currentDay() > lastDripTime) ? ((dividendsPool * dripRate) / 1000) : 0;
            dividends = SafeMath.sub(dividends, (dividends * investmentRate) / 100); 
            uint256 _profitPerShare = profitPerShare + dividends * MAGNITUDE / totalSupply;
            uint256 divs = (_profitPerShare * stakedOf[_userAddr] - payoutsTo[_userAddr]) / MAGNITUDE;
            return divs * getEfficiency(_userAddr) / 100;
        }
        return 0;
    }

    function dividendsOf(address _userAddr) internal view returns (uint256) {
        return (profitPerShare * stakedOf[_userAddr] - payoutsTo[_userAddr]) / MAGNITUDE ;
    }

    function getNegativePower(address _userAddr) internal view returns (uint256) {
        uint256 negativePower = (currentDay() - stakeStart[_userAddr]) * stakedOf[_userAddr] / powerBurnRate;
        return (negativePower > power[_userAddr]) ? power[_userAddr] : negativePower;
    }
	
    function getEfficiency(address _userAddr) internal view returns (uint256) {
        uint256 userPower = power[_userAddr] - getNegativePower(_userAddr);
        if(stakedOf[_userAddr] > 0) {
            uint256 powerBalanceRatio = 100 * userPower / stakedOf[_userAddr] ;
            if (powerBalanceRatio > 100) {
               return 100;
            }
            return powerBalanceRatio;
        }
        return 0;
    }
    
    function getMintablePower(address _userAddr) internal view returns (uint256) {
        uint256 efficiency = getEfficiency(_userAddr);
        uint256 timeStaking = currentDay() - stakeStart[_userAddr];
        if(timeStaking > cycleLength) timeStaking = cycleLength;
        uint256 totalMintable = timeStaking * stakedOf[_userAddr]  / powerBurnRate;
        uint256 finalMintable = totalMintable;    
        if(efficiency < 99) {
            finalMintable = finalMintable * (efficiency ** 3) / (100 ** 3);
        }
        return finalMintable;
    }
    
	function getUserData(address _userAddr) external view returns (uint256[8] memory) {
        return [
            estimateDividendsOf(_userAddr),
            stakedOf[_userAddr],
			getMintablePower(_userAddr),
		    getNegativePower(_userAddr), 
		    power[_userAddr],
		    stakeStart[_userAddr],
		    dividendsOf(_userAddr),
		    burns[_userAddr]
        ];
    }

	function getGlobals() external view returns (uint256[10] memory) {
        return [
            dividendsPool, 
            cycleLength,
            totalSupply, 
            dripRate,
            investmentRate, 
            powerBurnRate,
            currentDay(),
            lastDripTime,
			totalShares,
			sharePrice
        ];
    }

	function setTradingFee(uint32 _tradingFee) onlyOwner external {
	   	require(_tradingFee <= 1000  && _tradingFee >= 900);
	    tradingFee = _tradingFee;
	}	 
 
	function setOwner(address payable _owner) onlyOwner external {
	    owner = _owner;
	}

	function setFundAddress(address payable _fundAddress) onlyOwner external {
	    fundAddress = _fundAddress;
	}
	
	function setPowerBurnRate(uint32 _powerBurnRate) onlyOwner external {
	   	require(_powerBurnRate < 401 && _powerBurnRate > 9);
	    powerBurnRate = _powerBurnRate;
	}	
	
	function setDripRate(uint32 _dripRate) onlyOwner external {
	    require(_dripRate < 101 && _dripRate > 2);
	    dripRate = _dripRate;
	}	
	
	function setInvestmentRate(uint32 _investmentRate) onlyOwner external {
	    require(_investmentRate < 51 && _investmentRate >= 0);
		if(_investmentRate > 20) {
			require(now > 1646676925);
		}
		investmentRate = _investmentRate;
	}
		
	function setCycleLength(uint32 _cycleLength) onlyOwner external {
	    require(_cycleLength < 31 && _cycleLength > 2);
	    cycleLength = _cycleLength;
	}		

}
// UstxDex.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./UpStableToken.sol";
import "./IERC20.sol";
import "./ReentrancyGuard.sol";
import "./Pausable.sol";
import "./AdminRole.sol";
import "./SafeMath.sol";


/// @title Up Stable Token eXperiment DEX
/// @author USTX Team
/// @dev This contract implements the DEX functionality for the USTX token.
contract UstxDEX is ReentrancyGuard,Pausable {

	/***********************************|
	|        Variables && Events        |
	|__________________________________*/

	//Constants
	uint256 private constant MAX_FEE = 200;   //maximum fee in BP (2.5%)
	uint256 private constant MAX_LAUNCH_FEE = 1000;  //maximum fee during launchpad (10%)

	//Variables
	uint256 private _decimals;			// 6
	uint256 private _feeBuy;			//buy fee in basis points
	uint256 private _feeSell;			//sell fee in basis points
	uint256 private _targetRatioExp;	//target reserve ratio for expansion in TH (1000s) to circulating cap
	uint256 private _targetRatioDamp;	//target reserve ratio for damping in TH (1000s) to circulating cap
	uint256 private _expFactor;			//expansion factor in TH
	uint256 private _dampFactor;		//damping factor in TH
	uint256 private _minExp;			//minimum expansion in TH
	uint256 private _maxDamp;			//maximum damping in TH
	uint256 private _collectedFees;		//amount of collected fees
	uint256 private _launchEnabled;		//launchpad mode if >=1
	uint256 private _launchTargetSize;	//number of tokens reserved for launchpad
	uint256 private _launchPrice;		//Launchpad price
	uint256 private _launchBought;		//number of tokens bought so far in Launchpad
	uint256 private _launchMaxLot;		//max number of usdtSold for a single operation during Launchpad
	uint256 private _launchFee;			//Launchpad fee
	address private _launchTeamAddr;	//Launchpad team address

	UpStableToken Token;				// address of the TRC20 token traded on this contract
	IERC20 Tusdt;						// address of the reserve token USDT

	//SafeERC20 not needed for USDT(TRC20) and USTX(TRC20)

	using SafeMath for uint256;

	// Events
	event TokenBuy(address indexed buyer, uint256 indexed usdtSold, uint256 indexed tokensBought, uint256 price);
	event TokenSell(address indexed buyer, uint256 indexed tokensSold, uint256 indexed usdtBought, uint256 price);
	event Snapshot(address indexed operator, uint256 indexed usdtBalance, uint256 indexed tokenBalance);

	/**
	* @dev Constructor
	* @param tradeTokenAddr contract address of the traded token (USTX)
	* @param reserveTokenAddr contract address of the reserve token (USDT)
	*/
	constructor (address tradeTokenAddr, address reserveTokenAddr)
	AdminRole(2)        //at least two administrsators always in charge
	public {
		require(tradeTokenAddr != address(0) && reserveTokenAddr != address(0), "Invalid contract address");
		Token = UpStableToken(tradeTokenAddr);
		Tusdt = IERC20(reserveTokenAddr);
		_launchTeamAddr = _msgSender();
		_decimals = 6;
		_feeBuy = 0;                    //0%
		_feeSell = 100;                 //1%
		_targetRatioExp = 240;          //24%
		_targetRatioDamp = 260;         //26%
		_expFactor = 1000;              //1
		_dampFactor = 1000;             //1
		_minExp = 100;                  //0.1
		_maxDamp = 100;                 //0.1
		_collectedFees = 0;
		_launchEnabled = 0;
	}

	/***********************************|
	|        Exchange Functions         |
	|__________________________________*/

	/**
	* @dev Public function to preview token purchase with exact input in USDT
	* @param usdtSold amount of USDT to sell
	* @return number of tokens that can be purchased with input usdtSold
	*/
	function buyTokenInputPreview(uint256 usdtSold) public view returns (uint256) {
		require(usdtSold > 0, "USDT sold must greater than 0");
		uint256 tokenReserve = Token.balanceOf(address(this));
		uint256 usdtReserve = Tusdt.balanceOf(address(this));

		(uint256 tokensBought,,) = _getBoughtMinted(usdtSold,tokenReserve,usdtReserve);

		return tokensBought;
	}

	/**
	* @dev Public function to preview token sale with exact input in tokens
	* @param tokensSold amount of token to sell
	* @return Amount of USDT that can be bought with input Tokens.
	*/
	function sellTokenInputPreview(uint256 tokensSold) public view returns (uint256) {
		require(tokensSold > 0, "Tokens sold must greater than 0");
		uint256 tokenReserve = Token.balanceOf(address(this));
		uint256 usdtReserve = Tusdt.balanceOf(address(this));

		(uint256 usdtsBought,,) = _getBoughtBurned(tokensSold,tokenReserve,usdtReserve);

		return usdtsBought;
	}

	/**
	* @dev Public function to buy tokens during launchpad
	* @param rSell amount of UDST to sell
	* @param minTokens minimum amount of tokens to buy
	* @return number of tokens bought
	*/
	function  buyTokenLaunchInput(uint256 rSell, uint256 minTokens)  public whenNotPaused returns (uint256)  {
		require(_launchEnabled>0,"Function allowed only during launchpad");
		require(_launchBought<_launchTargetSize,"Launchpad target reached!");
		require(rSell<=_launchMaxLot,"Order too big for Launchpad");
		return _buyLaunchpadInput(rSell, minTokens, _msgSender(), _msgSender());
	}

	/**
	* @dev Public function to buy tokens during launchpad and transfer them to recipient
	* @param rSell amount of UDST to sell
	* @param minTokens minimum amount of tokens to buy
	* @param recipient recipient of the transaction
	* @return number of tokens bought
	*/
	function buyTokenLaunchTransferInput(uint256 rSell, uint256 minTokens, address recipient) public whenNotPaused returns(uint256) {
		require(_launchEnabled>0,"Function allowed only during launchpad");
		require(recipient != address(this) && recipient != address(0),"Recipient cannot be DEX or address 0");
		require(_launchBought<_launchTargetSize,"Launchpad target reached!");
		require(rSell<=_launchMaxLot,"Order too big for Launchpad");
		return _buyLaunchpadInput(rSell, minTokens, _msgSender(), recipient);
	}

	/**
	* @dev Public function to buy tokens
	* @param rSell amount of UDST to sell
	* @param minTokens minimum amount of tokens to buy
	* @return number of tokens bought
	*/
	function  buyTokenInput(uint256 rSell, uint256 minTokens)  public whenNotPaused returns (uint256)  {
		require(_launchEnabled==0,"Function not allowed during launchpad");
		return _buyStableInput(rSell, minTokens, _msgSender(), _msgSender());
	}

	/**
	* @dev Public function to buy tokens and transfer them to recipient
	* @param rSell amount of UDST to sell
	* @param minTokens minimum amount of tokens to buy
	* @param recipient recipient of the transaction
	* @return number of tokens bought
	*/
	function buyTokenTransferInput(uint256 rSell, uint256 minTokens, address recipient) public whenNotPaused returns(uint256) {
		require(_launchEnabled==0,"Function not allowed during launchpad");
		require(recipient != address(this) && recipient != address(0),"Recipient cannot be DEX or address 0");
		return _buyStableInput(rSell, minTokens, _msgSender(), recipient);
	}

	/**
	* @dev Public function to sell tokens
	* @param tokensSold number of tokens to sell
	* @param minUsdts minimum number of UDST to buy
	* @return number of USDTs bought
	*/
	function sellTokenInput(uint256 tokensSold, uint256 minUsdts) public whenNotPaused returns (uint256) {
		require(_launchEnabled==0,"Function not allowed during launchpad");
		return _sellStableInput(tokensSold, minUsdts, _msgSender(), _msgSender());
	}

	/**
	* @dev Public function to sell tokens and trasnfer USDT to recipient
	* @param tokensSold number of tokens to sell
	* @param minUsdts minimum number of UDST to buy
	* @param recipient recipient of the transaction
	* @return number of USDTs bought
	*/
	function sellTokenTransferInput(uint256 tokensSold, uint256 minUsdts, address recipient) public whenNotPaused returns (uint256) {
		require(_launchEnabled==0,"Function not allowed during launchpad");
		require(recipient != address(this) && recipient != address(0),"Recipient cannot be DEX or address 0");
		return _sellStableInput(tokensSold, minUsdts, _msgSender(), recipient);
	}

	/**
	* @dev public function to setup the reserve after launchpad
	* @param startPrice target price
	* @return reserve value
	*/
	function setupReserve(uint256 startPrice) public onlyAdmin whenPaused returns (uint256) {
		require(startPrice>0,"Price cannot be 0");
		uint256 tokenReserve = Token.balanceOf(address(this));
		uint256 usdtReserve = Tusdt.balanceOf(address(this));

		uint256 newReserve = usdtReserve.mul(10**_decimals).div(startPrice);
		uint256 temp;
		if (newReserve>tokenReserve) {
		    temp = newReserve.sub(tokenReserve);
		    Token.mint(address(this),temp);
		} else {
		    temp = tokenReserve.sub(newReserve);
		    Token.burn(temp);
		}
		return newReserve;
	}

	/**
	* @dev Private function to buy tokens with exact input in USDT
	*
	*/
	function _buyStableInput(uint256 usdtSold, uint256 minTokens, address buyer, address recipient) private nonReentrant returns (uint256) {
		require(usdtSold > 0 && minTokens > 0,"USDT sold and min tokens should be higher than 0");
		uint256 tokenReserve = Token.balanceOf(address(this));
		uint256 usdtReserve = Tusdt.balanceOf(address(this));

		(uint256 tokensBought, uint256 minted, uint256 fee) = _getBoughtMinted(usdtSold,tokenReserve,usdtReserve);
		_collectedFees = _collectedFees.add(fee);

		require(tokensBought >= minTokens, "Tokens bought lower than requested minimum amount");
		if (minted>0) {
			Token.mint(address(this),minted);
		}

		Tusdt.transferFrom(buyer, address(this), usdtSold);
		if (fee>0) {
			Tusdt.transfer(_launchTeamAddr,fee);                //transfer fees to team
		}
		Token.transfer(address(recipient),tokensBought);

		tokenReserve = Token.balanceOf(address(this));                //update token reserve
		usdtReserve = Tusdt.balanceOf(address(this));                 //update usdt reserve
		uint256 newPrice = usdtReserve.mul(10**_decimals).div(tokenReserve);   //calc new price
		emit TokenBuy(buyer, usdtSold, tokensBought, newPrice);       //emit TokenBuy event
		emit Snapshot(buyer, usdtReserve, tokenReserve);              //emit Snapshot event

		return tokensBought;
	}

	/**
	* @dev Private function to buy tokens during launchpad with exact input in USDT
	*
	*/
	function _buyLaunchpadInput(uint256 usdtSold, uint256 minTokens, address buyer, address recipient) private nonReentrant returns (uint256) {
		require(usdtSold > 0 && minTokens > 0, "USDT sold and min tokens should be higher than 0");

		uint256 tokensBought = usdtSold.mul(10**_decimals).div(_launchPrice);
		uint256 fee = usdtSold.mul(_launchFee).div(10000);

		require(tokensBought >= minTokens, "Tokens bought lower than requested minimum amount");
		_launchBought = _launchBought.add(tokensBought);
		Token.mint(address(this),tokensBought);                     //mint new tokens

		Tusdt.transferFrom(buyer, address(this), usdtSold);     //add usdtSold to reserve
		Tusdt.transfer(_launchTeamAddr,fee);                //transfer fees to team
		Token.transfer(address(recipient),tokensBought);        //transfer tokens to recipient
		emit TokenBuy(buyer, usdtSold, tokensBought, _launchPrice);
		emit Snapshot(buyer, Tusdt.balanceOf(address(this)), Token.balanceOf(address(this)));

		return tokensBought;
	}

	/**
	* @dev Private function to sell tokens with exact input in tokens
	*
	*/
	function _sellStableInput(uint256 tokensSold, uint256 minUsdts, address buyer, address recipient) private nonReentrant returns (uint256) {
		require(tokensSold > 0 && minUsdts > 0, "Tokens sold and min USDT should be higher than 0");
		uint256 tokenReserve = Token.balanceOf(address(this));
		uint256 usdtReserve = Tusdt.balanceOf(address(this));

		(uint256 usdtsBought, uint256 burned, uint256 fee) = _getBoughtBurned(tokensSold,tokenReserve,usdtReserve);
		_collectedFees = _collectedFees.add(fee);

		require(usdtsBought >= minUsdts, "USDT bought lower than requested minimum amount");
	 	if (burned>0) {
	    	Token.burn(burned);
		}
		Token.transferFrom(buyer, address(this), tokensSold);       //transfer tokens to DEX
		Tusdt.transfer(recipient,usdtsBought);                  //transfer USDT to user
		if (fee>0) {
			Tusdt.transfer(_launchTeamAddr,fee);                //transfer fees to team
		}
		tokenReserve = Token.balanceOf(address(this));                //update token reserve
		usdtReserve = Tusdt.balanceOf(address(this));                 //update usdt reserve
		uint256 newPrice = usdtReserve.mul(10**_decimals).div(tokenReserve);   //calc new price
		emit TokenSell(buyer, tokensSold, usdtsBought, newPrice);     //emit Token event
		emit Snapshot(buyer, usdtReserve, tokenReserve);              //emit Snapshot event

		return usdtsBought;
	}

	/**
	* @dev Private function to get expansion correction
	*
	*/
	function _getExp(uint256 tokenReserve, uint256 usdtReserve) private view returns (uint256,uint256) {
		uint256 tokenCirc = Token.totalSupply();        //total
		tokenCirc = tokenCirc.sub(tokenReserve);
		uint256 price = getPrice();         //multiplied by 10**decimals
		uint256 cirCap = price.mul(tokenCirc);      //multiplied by 10**decimals
		uint256 ratio = usdtReserve.mul(1000000000).div(cirCap);
		uint256 exp = ratio.mul(1000).div(_targetRatioExp);
		if (exp<1000) {
			exp=1000;
		}
		exp = exp.sub(1000);
		exp=exp.mul(_expFactor).div(1000);
		if (exp<_minExp) {
	    	exp=_minExp;
		}
		if (exp>1000) {
	    	exp = 1000;
		}
		return (exp,ratio);
	}

	/**
	* @dev Private function to get k exponential factor for expansion
	*
	*/
	function _getKXe(uint256 pool, uint256 trade, uint256 exp) private pure returns (uint256) {
		uint256 temp = 1000-exp;
		temp = trade.mul(temp);
		temp = temp.div(1000);
		temp = temp.add(pool);
		temp = temp.mul(1000000000);
		uint256 kexp = temp.div(pool);
		return kexp;
	}

	/**
	* @dev Private function to get k exponential factor for damping
	*
	*/
	function _getKXd(uint256 pool, uint256 trade, uint256 exp) private pure returns (uint256) {
		uint256 temp = 1000-exp;
		temp = trade.mul(temp);
		temp = temp.div(1000);
		temp = temp.add(pool);
		uint256 kexp = pool.mul(1000000000).div(temp);
		return kexp;
	}

	/**
	* @dev Private function to get amount of tokens bought and minted
	*
	*/
	function _getBoughtMinted(uint256 usdtSold, uint256 tokenReserve, uint256 usdtReserve) private view returns (uint256,uint256,uint256) {
		uint256 fees = usdtSold.mul(_feeBuy).div(10000);
		uint256 usdtSoldNet = usdtSold.sub(fees);

		(uint256 exp,) = _getExp(tokenReserve,usdtReserve);

		uint256 kexp = _getKXe(usdtReserve,usdtSoldNet,exp);

		uint256 temp = tokenReserve.mul(usdtReserve);       //k
		temp = temp.mul(kexp);
		temp = temp.mul(kexp);
		uint256 kn = temp.div(1000000000000000000);                 //uint256 kn=tokenReserve.mul(usdtReserve).mul(kexp).mul(kexp).div(1000000);

		temp = tokenReserve.mul(usdtReserve);               //k
		usdtReserve = usdtReserve.add(usdtSoldNet);          //uint256 usdtReserveNew= usdtReserve.add(usdtSoldNet);
		temp = temp.div(usdtReserve);                       //USTXamm
		uint256 tokensBought = tokenReserve.sub(temp);      //out=tokenReserve-USTXamm

		temp=kn.div(usdtReserve);                           //USXTPool_n
		uint256 minted=temp.add(tokensBought).sub(tokenReserve);

		return (tokensBought, minted, fees);
	}

	/**
	* @dev Private function to get damping correction
	*
	*/
	function _getDamp(uint256 tokenReserve, uint256 usdtReserve) private view returns (uint256,uint256) {
		uint256 tokenCirc = Token.totalSupply();        //total
		tokenCirc = tokenCirc.sub(tokenReserve);
		uint256 price = getPrice();         //multiplied by 10**decimals
		uint256 cirCap = price.mul(tokenCirc);      //multiplied by 10**decimals
		uint256 ratio = usdtReserve.mul(1000000000).div(cirCap);  //in TH
		if (ratio>_targetRatioDamp) {
	    	ratio=_targetRatioDamp;
		}
		uint256 damp = _targetRatioDamp.sub(ratio);
		damp = damp.mul(_dampFactor).div(_targetRatioDamp);

		if (damp<_maxDamp) {
    		damp=_maxDamp;
		}
		if (damp>1000) {
	    	damp = 1000;
		}
		return (damp,ratio);
	}

	/**
	* @dev Private function to get number of USDT bought and tokens burned
	*
	*/
	function _getBoughtBurned(uint256 tokenSold, uint256 tokenReserve, uint256 usdtReserve) private view returns (uint256,uint256,uint256) {
		(uint256 damp,) = _getDamp(tokenReserve,usdtReserve);

		uint256 kexp = _getKXd(tokenReserve,tokenSold,damp);

		uint256 k = tokenReserve.mul(usdtReserve);           //k
		uint256 temp = k.mul(kexp);
		temp = temp.mul(kexp);
		uint256 kn = temp.div(1000000000000000000);             //uint256 kn=tokenReserve.mul(usdtReserve).mul(kexp).mul(kexp).div(1000000);

		tokenReserve = tokenReserve.add(tokenSold);             //USTXpool_n
		temp = k.div(tokenReserve);                             //USDamm
		uint256 usdtsBought = usdtReserve.sub(temp);            //out
		usdtReserve = temp;

		temp = kn.div(usdtReserve);                             //USTXPool_n

		uint256 burned=tokenReserve.sub(temp);

		temp = usdtsBought.mul(_feeSell).div(10000);       //fee
		usdtsBought = usdtsBought.sub(temp);

		return (usdtsBought, burned, temp);
	}

	/**************************************|
	|     Getter and Setter Functions      |
	|_____________________________________*/

	/**
	* @dev Function to set Token address (only admin)
	* @param tokenAddress address of the traded token contract
	*/
	function setTokenAddr(address tokenAddress) public onlyAdmin {
	    require(tokenAddress != address(0), "INVALID_ADDRESS");
	    Token = UpStableToken(tokenAddress);
	}

	/**
	* @dev Function to set USDT address (only admin)
	* @param reserveAddress address of the reserve token contract
	*/
	function setReserveTokenAddr(address reserveAddress) public onlyAdmin {
		require(reserveAddress != address(0), "INVALID_ADDRESS");
		Tusdt = IERC20(reserveAddress);
	}

	/**
	* @dev Function to set fees (only admin)
	* @param feeBuy fee for buy operations (in basis points)
	* @param feeSell fee for sell operations (in basis points)
	*/
	function setFees(uint256 feeBuy, uint256 feeSell) public onlyAdmin {
		require(feeBuy<=MAX_FEE && feeSell<=MAX_FEE,"Fees cannot be higher than MAX_FEE");
		_feeBuy=feeBuy;
		_feeSell=feeSell;
	}

	/**
	* @dev Function to get fees
	* @return buy and sell fees in basis points
	*
	*/
	function getFees() public view returns (uint256, uint256) {
    	return (_feeBuy, _feeSell);
	}

	/**
	* @dev Function to set target ratio level (only admin)
	* @param ratioExp target reserve ratio for expansion (in thousandths)
	* @param ratioDamp target reserve ratio for damping (in thousandths)
	*/
	function setTargetRatio(uint256 ratioExp, uint256 ratioDamp) public onlyAdmin {
	    require(ratioExp<=1000 && ratioExp>=10 && ratioDamp<=1000 && ratioDamp >=10,"Target ratio must be between 1% and 100%");
	    _targetRatioExp = ratioExp;         //in TH
	    _targetRatioDamp = ratioDamp;       //in TH
	}

	/**
	* @dev Function to get target ratio level
	* return ratioExp and ratioDamp in thousandths
	*
	*/
	function getTargetRatio() public view returns (uint256, uint256) {
    	return (_targetRatioExp, _targetRatioDamp);
	}

	/**
	* @dev Function to get currect reserve ratio level
	* return current ratio in thousandths
	*
	*/
	function getCurrentRatio() public view returns (uint256) {
		uint256 tokenReserve = Token.balanceOf(address(this));
		uint256 usdtReserve = Tusdt.balanceOf(address(this));
		uint256 tokenCirc = Token.totalSupply();        //total
		tokenCirc = tokenCirc.sub(tokenReserve);
		uint256 price = getPrice();         //multiplied by 10**decimals
		uint256 cirCap = price.mul(tokenCirc);      //multiplied by 10**decimals
		uint256 ratio = usdtReserve.mul(1000000000).div(cirCap);  //in TH
		return ratio;
	}

	/**
	* @dev Function to set target expansion factors (only admin)
	* @param expF expansion factor (in thousandths)
	* @param minExp minimum expansion coefficient to use (in thousandths)
	*/
	function setExpFactors(uint256 expF, uint256 minExp) public onlyAdmin {
		require(expF<=10000 && minExp<=1000,"Expansion factor cannot be more than 1000% and the minimum expansion cannot be over 100%");
		_expFactor=expF;
		_minExp=minExp;
	}

	/**
	* @dev Function to get expansion factors
	* @return _expFactor and _minExp in thousandths
	*
	*/
	function getExpFactors() public view returns (uint256, uint256) {
		return (_expFactor,_minExp);
	}

	/**
	* @dev Function to set target damping factors (only admin)
	* @param dampF damping factor (in thousandths)
	* @param maxDamp maximum damping to use (in thousandths)
	*/
	function setDampFactors(uint256 dampF, uint256 maxDamp) public onlyAdmin {
		require(dampF<=1000 && maxDamp<=1000,"Damping factor cannot be more than 100% and the maximum damping be over 100%");
		_dampFactor=dampF;
		_maxDamp=maxDamp;
	}

	/**
	* @dev Function to get damping factors
	* @return _dampFactor and _maxDamp in thousandths
	*
	*/
	function getDampFactors() public view returns (uint256, uint256) {
		return (_dampFactor,_maxDamp);
	}

	/**
	* @dev Function to get current price
	* @return current price
	*
	*/
	function getPrice() public view returns (uint256) {
		if (_launchEnabled>0) {
	    	return (_launchPrice);
		}else {
			uint256 tokenReserve = Token.balanceOf(address(this));
			uint256 usdtReserve = Tusdt.balanceOf(address(this));
			return (usdtReserve.mul(10**_decimals).div(tokenReserve));      //price with decimals
		}
	}

	/**
	* @dev Function to get address of the traded token contract
	* @return Address of token that is traded on this exchange
	*
	*/
	function getTokenAddress() public view returns (address) {
		return address(Token);
	}

	/**
	* @dev Function to get the address of the reserve token contract
	* @return Address of USDT
	*
	*/
	function getReserveAddress() public view returns (address) {
		return address(Tusdt);
	}

	/**
	* @dev Function to get current reserves balance
	* @return USDT reserve, USTX reserve, USTX circulating
	*/
	function getBalances() public view returns (uint256,uint256,uint256,uint256) {
		uint256 tokenReserve = Token.balanceOf(address(this));
		uint256 usdtReserve = Tusdt.balanceOf(address(this));
		uint256 tokenCirc = Token.totalSupply().sub(tokenReserve);
		return (usdtReserve,tokenReserve,tokenCirc,_collectedFees);
	}

	/**
	* @dev Function to enable launchpad (only admin)
	* @param price launchpad fixed price
	* @param target launchpad target USTX sale
	* @param maxLot launchpad maximum purchase size in USDT
	* @param fee launchpad fee for the dev team (in basis points)
	* @return true if launchpad is enabled
	*/
	function enableLaunchpad(uint256 price, uint256 target, uint256 maxLot, uint256 fee) public onlyAdmin returns (bool) {
		require(price>0 && target>0 && maxLot>0 && fee<=MAX_LAUNCH_FEE,"Price, target and max lotsize cannot be 0. Fee must be lower than MAX_LAUNCH_FEE");
		_launchPrice = price;       //in USDT units
		_launchTargetSize = target; //in USTX units
		_launchBought = 0;          //in USTX units
		_launchFee = fee;           //in bp
		_launchMaxLot = maxLot;     //in USDT units
		_launchEnabled = 1;
		return true;
	}

	/**
	* @dev Function to disable launchpad (only admin)
	*
	*
	*/
	function disableLaunchpad() public onlyAdmin {
		_launchEnabled = 0;
	}

	/**
	* @dev Function to get launchpad status (only admin)
	* @return enabled state, price, amount of tokens bought, target tokens, max ourschase lot, fee
	*
	*/
	function getLaunchpadStatus() public view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
		return (_launchEnabled,_launchPrice,_launchBought,_launchTargetSize,_launchMaxLot,_launchFee);
	}

	/**
	* @dev Set team address (only admin)
	* @param team address for collecting fees
	*/
	function setTeamAddress(address team) public onlyAdmin {
		require(team != address(0) && team != address(this), "Invalid team address");
		_launchTeamAddr = team;
	}

	/**
	 * @dev Unregister DEX as admin from USTX contract
	 *
	 */
	 function unregisterAdmin() public onlyAdmin {
	     Token.renounceAdmin();
	 }
}


pragma solidity ^0.6.12;


import "./libraries.sol"


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}



interface IHedgeySwap {
    function hedgeyPutSwap(address originalOwner, uint _p, uint _totalPurchase, address[] memory path) external;
}


interface IHedgeyFactory {
    function isSwapper(address swapper) external view returns (bool);
}

contract HedgeyPuts is ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address hedgeyFactory;
    address public asset; 
    address public pymtCurrency; 
    uint public assetDecimals;
    address public uniPair;
    address payable public constant weth = 0xc778417E063141139Fce010982780140Aa0cD5Ab; //rinkeby weth      
    uint public fee;
    address payable public feeCollector;
    uint public p = 0; 
    address public constant uniFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; //uniswap 
    bool private assetWeth;
    bool private pymtWeth;
    bool public cashCloseOn;
    

    constructor(address _asset, address _pymtCurrency, address payable _feeCollector, uint _fee) public {
        hedgeyFactory = msg.sender;
        require(_asset != _pymtCurrency);
        asset = _asset;
        pymtCurrency = _pymtCurrency;
        feeCollector = _feeCollector;
        fee = _fee;
        assetDecimals = IERC20(_asset).decimals();
        uniPair = IUniswapV2Factory(uniFactory).getPair(_asset, _pymtCurrency);
        if (uniPair != address(0x0)) {
            cashCloseOn = true;
        } 
        if (_asset == weth) {
            assetWeth = true;
            pymtWeth = false;
        } else if (_pymtCurrency == weth) {
            assetWeth = false;
            pymtWeth = true;
        } else {
            assetWeth = false;
            pymtWeth = false;
        }
    }
    

    struct Put {
        address payable short;
        uint assetAmt;
        uint minimumPurchase;
        uint strike;
        uint totalPurch;
        uint price;
        uint expiry;
        bool open;
        bool tradeable;
        address payable long;
        bool exercised;
    }

    mapping (uint => Put) public puts;

    //internal and setup functions

    receive() external payable {    
    }

    function depositPymt(bool _isWeth, address _token, address _sender, uint _amt) internal {
        if (_isWeth) {
            require(msg.value == _amt, "deposit issue: sending in wrong amount of eth");
            IWETH(weth).deposit{value: _amt}();
            assert(IWETH(weth).transfer(address(this), _amt));
        } else {
            SafeERC20.safeTransferFrom(IERC20(_token), _sender, address(this), _amt);
        }
    }

    function withdrawPymt(bool _isWeth, address _token, address payable to, uint _amt) internal {
        if (_isWeth && (!Address.isContract(to))) {
            //if the address is a contract - then we should actually just send WETH out to the contract, else send the wallet eth
            IWETH(weth).withdraw(_amt);
            to.transfer(_amt);
        } else {
            SafeERC20.safeTransfer(IERC20(_token), to, _amt);
        }
    }

    function transferPymt(bool _isWETH, address _token, address from, address payable to, uint _amt) internal {
        if (_isWETH) {
            
            if (!Address.isContract(to)) {
                to.transfer(_amt);
            } else {
                // we want to deliver WETH from ETH here for better handling at contract
                IWETH(weth).deposit{value: _amt}();
                assert(IWETH(weth).transfer(to, _amt));
            }
        } else {
            SafeERC20.safeTransferFrom(IERC20(_token), from, to, _amt);         
        }
    }

    function transferPymtWithFee(bool _isWETH, address _token, address from, address payable to, uint _total) internal {
        uint _fee = (_total * fee).div(1e4);
        uint _amt = _total.sub(_fee);
        if (_isWETH) {
            require(msg.value == _total, "transfer issue: wrong amount of eth sent");
        }
        transferPymt(_isWETH, _token, from, to, _amt); //transfer the stub to recipient
        if (_fee > 0) transferPymt(_isWETH, _token, from, feeCollector, _fee); //transfer fee to fee collector
           
    }


    //admin function to update the fee amount
    function changeFee(uint _fee, address payable _collector) external {
        require(msg.sender == feeCollector, "only fee collector");
        fee = _fee;
        feeCollector = _collector;
    }

    

    function updateAMM() external {
        uniPair = IUniswapV2Factory(uniFactory).getPair(asset, pymtCurrency);
        if (uniPair != address(0x0)) {
            cashCloseOn = true;
        }
        emit AMMUpdate(cashCloseOn);
    }

    
    // PUT FUNCTIONS  **********************************************

    //function for someone wanting to buy a new put
    function newBid(uint _assetAmt, uint _strike, uint _price, uint _expiry) payable external {
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "p: totalPurchase error: too small amount");
        uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= _price, "p: insufficent purchase cash");
        depositPymt(pymtWeth, pymtCurrency, msg.sender, _price); //handles weth and token deposits into contract
        puts[p++] = Put(address(0x0), _assetAmt, _assetAmt, _strike, _totalPurch, _price, _expiry, false, true, msg.sender, false);
        emit NewBid(p.sub(1), _assetAmt, _assetAmt, _strike, _price, _expiry);
    }


    function cancelNewBid(uint _p) external nonReentrant {
        Put storage put = puts[_p];
        require(msg.sender == put.long, "p:only long can cancel a bid");
        require(!put.open, "p: put already open");
        require(!put.exercised, "p: put already exercised");
        require(put.short == address(0x0), "p: not a new bid"); 
        put.tradeable = false;
        put.exercised = true;
        withdrawPymt(pymtWeth, pymtCurrency, put.long, put.price);
        emit OptionCancelled(_p);
    }

    //function for an existing long to sell position to a new bidder
    function sellOpenOptionToNewBid(uint _p, uint _q, uint _price) payable external nonReentrant {
        Put storage openPut = puts[_p];
        Put storage newBid = puts[_q];
        require(_p != _q, "p: wrong sale function");
        require(_price == newBid.price, "p: price changed before execution");
        require(msg.sender == openPut.long, "p: you dont own this");
        require(openPut.strike == newBid.strike, "p: not the right strike");
        require(openPut.assetAmt == newBid.assetAmt, "p: not the right assetAmt");
        require(openPut.expiry == newBid.expiry, "p: not the right expiry");
        require(newBid.short == address(0x0), "p: newBid is not new");
        require(openPut.open && !newBid.open && newBid.tradeable && !openPut.exercised && !newBid.exercised && openPut.expiry > now && newBid.expiry > now, "something is wrong");
        //close out our new bid
        newBid.exercised = true;
        newBid.tradeable = false;
        uint feePymt = (newBid.price * fee).div(1e4);
        uint remainder = newBid.price.sub(feePymt);
        withdrawPymt(pymtWeth, pymtCurrency, openPut.long, remainder);
        SafeERC20.safeTransfer(IERC20(pymtCurrency), feeCollector, feePymt);
        //assign the put.long
        openPut.long = newBid.long;
        openPut.price = newBid.price;
        openPut.tradeable = false;
        emit OpenOptionSold(_p, _q, openPut.long, _price);
    }

    //function for someone to write the put for the open bid
    function sellNewOption(uint _p, uint _assetAmt, uint _strike, uint _price, uint _expiry) payable external nonReentrant {
        Put storage put = puts[_p];
        require(put.strike == _strike && put.assetAmt == _assetAmt && put.price == _price && put.expiry == _expiry, "p details mismatch: something has changed before execution");
        require(put.short == address(0x0));
        require(msg.sender != put.long, "p: you already own this");
        require(put.expiry > now, "p: This is already expired");
        require(put.tradeable, "p: not tradeable");
        require(!put.open, "p: put not open");
        require(!put.exercised, "p: this has been exercised");
        uint feePymt = (put.price * fee).div(1e4);
        uint shortPymt = (put.totalPurch).add(feePymt).sub(put.price); //net amount the short must send into the contract for escrow
        uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= shortPymt, "p: sell new option: insufficent collateral");
        depositPymt(pymtWeth, pymtCurrency, msg.sender, shortPymt);
        if (feePymt > 0) SafeERC20.safeTransfer(IERC20(pymtCurrency), feeCollector, feePymt);
        put.open = true;
        put.short = msg.sender;
        put.tradeable = false;
        emit NewOptionSold(_p);
    }


    function changeNewOption(uint _p, uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry) payable external nonReentrant {
        Put storage put = puts[_p];
        require(put.long == msg.sender, "p: you do not own this put");
        require(!put.exercised, "p: this has been exercised");
        require(!put.open, "p: this is already open");
        require(put.tradeable, "p: this is not a tradeable option");
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "totalPurchase error: too small amount");
        //lets check if this is a new ask or new bid
        //if its a newAsk
        if (msg.sender == put.short) {
            require(_minimumPurchase.mul(_strike).div(10 ** assetDecimals) > 0, "p: minimum purchase error, too small of a minimum");
            require(_assetAmt % _minimumPurchase == 0, "p: asset amount needs to be a multiple of the minimum");
            uint refund = (put.totalPurch > _totalPurch) ? put.totalPurch.sub(_totalPurch) : _totalPurch.sub(put.totalPurch);
            uint oldPurch = put.totalPurch;
            put.strike = _strike;
            put.totalPurch = _totalPurch;
            put.assetAmt = _assetAmt;
            put.minimumPurchase = _minimumPurchase;
            put.price = _price;
            put.expiry = _expiry;
            put.tradeable = true;
            if (oldPurch > _totalPurch) {
                withdrawPymt(pymtWeth, pymtCurrency, put.short, refund);
            } else if (oldPurch < _totalPurch) {
                uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
                require(balCheck >= refund, "p: not enough to change this put option");
                depositPymt(pymtWeth, pymtCurrency, msg.sender, refund);
            }
            emit OptionChanged(_p, _assetAmt, _minimumPurchase, _strike, _price, _expiry);

        } else if (put.short == address(0x0)) {
            //its a newBid
            uint refund = (_price > put.price) ? _price.sub(put.price) : put.price.sub(_price);
            put.assetAmt = _assetAmt;
            put.minimumPurchase = _assetAmt;
            put.strike = _strike;
            put.expiry = _expiry;
            put.totalPurch = _totalPurch;
            put.tradeable = true;
            if (_price > put.price) {
                put.price = _price;
                //we need to pull in more cash
                uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
                require(balCheck >= refund, "p: not enough cash to bid");
                depositPymt(pymtWeth, pymtCurrency, msg.sender, refund);
            } else if (_price < put.price) {
                put.price = _price;
                //need to refund the put bidder
                withdrawPymt(pymtWeth, pymtCurrency, put.long, refund);
            }
            emit OptionChanged(_p, _assetAmt, _assetAmt, _strike, _price, _expiry);
                
        }
           
    }



    //function for submitting a new ask
     function newAsk(uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry) payable external {
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "p totalPurchase error: too small amount");
        require(_minimumPurchase.mul(_strike).div(10 ** assetDecimals) > 0, "p: minimum purchase error, too small of a min");
        require(_assetAmt % _minimumPurchase == 0, "p: asset amount needs to be a multiple of the minimum");
        uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= _totalPurch, "p: you dont have enough collateral to write this option");
        depositPymt(pymtWeth, pymtCurrency, msg.sender, _totalPurch);
        puts[p++] = Put(msg.sender, _assetAmt, _minimumPurchase, _strike, _totalPurch, _price, _expiry, false, true, msg.sender, false);
        emit NewAsk(p.sub(1), _assetAmt, _minimumPurchase, _strike, _price, _expiry);
    }
    
    
    //function to cancel a new ask from writter side
    function cancelNewAsk(uint _p) external nonReentrant {
        Put storage put = puts[_p];
        require(msg.sender == put.short && msg.sender == put.long, "p: only short can change an ask");
        require(!put.open, "p: put already open");
        require(!put.exercised, "p: put already exercised");
        put.tradeable = false; 
        put.exercised = true;
        withdrawPymt(pymtWeth, pymtCurrency, put.short, put.totalPurch);
        emit OptionCancelled(_p);
    }


    //function to purchase the first newly written put
    function buyNewOption(uint _p, uint _assetAmt, uint _strike, uint _price, uint _expiry) payable external {
        Put storage put = puts[_p];
        require(put.strike == _strike && put.expiry == _expiry, "p details mismatch: something has changed before execution");
        require(put.expiry > now, "p: This put is already expired");
        require(!put.exercised, "p: This has already been exercised");
        require(put.tradeable, "p: this is not ready to trade");
        require(msg.sender != put.short, "p: you are the short");
        require(put.short != address(0x0) && put.short == put.long, "p: this is not a newAsk");
        require(!put.open, "p: This put is already open");
        require(_assetAmt >= put.minimumPurchase, "purchase size does not meet minimum");
        if (_assetAmt == put.assetAmt) {
            require(_price == put.price, "p: price mismatch");
            uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
            require(balCheck >= put.price, "p: not enough to buy this put");
            transferPymtWithFee(pymtWeth, pymtCurrency, msg.sender, put.short, _price);
            put.open = true; 
            put.long = msg.sender; 
            put.tradeable = false; 
            emit NewOptionBought(_p);
        } else {
            uint pricePerToken = put.price.mul(10 ** 32).div(put.assetAmt);
            uint proRataPrice = _assetAmt.mul(pricePerToken).div(10 ** 32);
            require(_price == proRataPrice, "p: price doesnt match pro rata price");
            require(put.assetAmt.sub(_assetAmt) >= put.minimumPurchase, "p: remainder too small");
            uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
            require(balCheck >= proRataPrice, "p: not enough to buy this put");
            uint proRataTotalPurchase = _assetAmt.mul(_strike).div(10 ** assetDecimals);
            transferPymtWithFee(pymtWeth, pymtCurrency, msg.sender, put.short, proRataPrice);
            puts[p++] = Put(put.short, _assetAmt, put.minimumPurchase, put.strike, proRataTotalPurchase, _price, _expiry, true, false, msg.sender, false);
            emit PoolOptionBought(_p, p.sub(1), _assetAmt, _strike, _price, _expiry);
            //update the current call to become the remainder
            put.assetAmt -= _assetAmt;
            put.price -= _price;
            put.totalPurch = put.assetAmt.mul(_strike).div(10 ** assetDecimals);
        }
        
    }    


    

    function buyOptionFromAsk(uint _p, uint _q, uint _price) payable external nonReentrant {
        Put storage openShort = puts[_p];
        Put storage ask = puts[_q];
        require(_p != _q);
        require(_price == ask.price);
        require(msg.sender == openShort.short);
        require(ask.tradeable && !ask.exercised && ask.expiry > now);
        require(openShort.open && !openShort.exercised && openShort.expiry > now);
        require(openShort.strike == ask.strike);
        require(openShort.assetAmt == ask.assetAmt);
        require(openShort.expiry == ask.expiry);
        //openShort pays the ask long with their existing escrow balances
        require(openShort.totalPurch > _price);
        uint refund = openShort.totalPurch.sub(_price);
        uint feePymt = (_price * fee).div(1e4);
        withdrawPymt(pymtWeth, pymtCurrency, ask.long, _price.sub(feePymt));
        //send the fee
        if (feePymt > 0) SafeERC20.safeTransfer(IERC20(pymtCurrency), feeCollector, feePymt);
        //if newAsk then ask.long == ask.short, if openAsk then ask.long is the one receiving the payment
        
        ask.exercised = true;
        ask.tradeable = false;
        ask.open = false;
        //now withdraw the openShort's total purchase collateral back to them
        withdrawPymt(pymtWeth, pymtCurrency, openShort.short, refund);
        openShort.short = ask.short;
        emit OpenShortRePurchased( _p, _q, openShort.short, _price); 
    }


    //function to set a price of a put as the long, or to turn the open order off
    function setPrice(uint _p, uint _price, bool _tradeable) external {
        Put storage put = puts[_p];
        require((msg.sender == put.long && msg.sender == put.short && _tradeable) || (msg.sender == put.long && put.open), "p: you cant change the price");
        require(put.expiry > now);
        require(!put.exercised);
        put.price = _price;
        put.tradeable = _tradeable;
        emit PriceSet(_p, _price, _tradeable);
    }

    
    //function for someone to purchase an open option
    function buyOpenOption(uint _p, uint _assetAmt, uint _strike, uint _price, uint _expiry) payable external nonReentrant {
        Put storage put = puts[_p];
        require(put.strike == _strike && put.assetAmt == _assetAmt && put.price == _price && put.expiry == _expiry);
        require(msg.sender != put.long); 
        require(put.open); 
        require(put.expiry >= now);
        require(!put.exercised);
        require(put.tradeable);
        uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= put.price);
        transferPymtWithFee(pymtWeth, pymtCurrency, msg.sender, put.long, _price);
        if (msg.sender == put.short) {
            withdrawPymt(pymtWeth, pymtCurrency, put.short, put.totalPurch);//send the money back to the put writer
            put.exercised = true;
            put.open = false;
        }
        
        put.tradeable = false;
        put.long = msg.sender;
        emit OpenOptionPurchased(_p);
    }

    //function to physiputy exercise
    function exercise(uint _p) payable external nonReentrant {
        Put storage put = puts[_p];
        require(put.open);
        require(put.expiry >= now, "p: This put is already expired");
        require(!put.exercised);
        require(msg.sender == put.long);
        uint balCheck = assetWeth ? msg.value : IERC20(asset).balanceOf(msg.sender);
        require(balCheck >= put.assetAmt);
        put.exercised = true;
        put.open = false;
        put.tradeable = false;
        if (assetWeth) {
            require(msg.value == put.assetAmt);
        }
        transferPymt(assetWeth, asset, msg.sender, put.short, put.assetAmt);
        withdrawPymt(pymtWeth, pymtCurrency, msg.sender, put.totalPurch);
        emit OptionExercised(_p, false);
    }

    //function to cash close with the uniswap flash swaps tool
    function cashClose(uint _p) payable external nonReentrant {
        require(cashCloseOn);
        Put storage put = puts[_p];
        require(put.open);
        require(put.expiry >= now);
        require(!put.exercised);
        require(msg.sender == put.long);
        uint pymtEst = estIn(put.assetAmt);
        require(pymtEst < put.totalPurch, "p: this put is not in the money"); 
        address to = assetWeth ? address(this) : put.short;
        put.exercised = true;
        put.open = false;
        put.tradeable = false;
        swap(pymtCurrency, put.assetAmt, pymtEst, to);
        if (assetWeth) {
            withdrawPymt(assetWeth, asset, put.short, put.assetAmt);
        }
        put.totalPurch -= pymtEst;  
        
        withdrawPymt(pymtWeth, pymtCurrency, put.long, put.totalPurch);
        emit OptionExercised(_p, true);
    }
    


    function returnExpired(uint[] memory _puts) external nonReentrant {
        uint _totalPurchaseLocked;
        for (uint i; i < _puts.length; i++) {
            Put storage put = puts[_puts[i]];
            require(!put.exercised && put.expiry < now && msg.sender == put.short);
            put.exercised = true;
            put.open = false;
            put.tradeable = false;
            _totalPurchaseLocked += put.totalPurch;
            emit OptionReturned(_puts[i]);
        }
        withdrawPymt(pymtWeth, pymtCurrency, msg.sender, _totalPurchaseLocked);
        
    }
    
    function rollExpired(uint[] memory _puts, uint _assetAmount, uint _minimumPurchase, uint _newStrike, uint _newPrice, uint _newExpiry) payable external {
        uint _totalAssetAmount;
        uint _totalPurchaseLocked;
        for (uint i; i < _puts.length; i++) {
            Put storage put = puts[_puts[i]];
            require(!put.exercised && put.expiry < now && msg.sender == put.short);
            put.exercised = true;
            put.open = false;
            put.tradeable = false;
            _totalAssetAmount += put.assetAmt;
            _totalPurchaseLocked += put.totalPurch;
            emit OptionReturned(_puts[i]);
        }
        require(_assetAmount % _minimumPurchase == 0 && _assetAmount >= _totalAssetAmount);
        uint _totalPurch = (_assetAmount).mul(_newStrike).div(10 ** assetDecimals);
        require(_totalPurch > 0 && _minimumPurchase.mul(_newStrike).div(10 ** assetDecimals) > 0);
        require(_newExpiry > block.timestamp);
        //only allow the writer to upsize, and pull in the additional funds required to collateralize
        uint difference = (_totalPurch > _totalPurchaseLocked) ? _totalPurch.sub(_totalPurchaseLocked) : _totalPurchaseLocked.sub(_totalPurch);
        if (_totalPurch > _totalPurchaseLocked) {
            uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
            require(balCheck >= difference);
            depositPymt(pymtWeth, pymtCurrency, msg.sender, difference);
        } else if (_totalPurch < _totalPurchaseLocked) {
            withdrawPymt(pymtWeth, pymtCurrency, msg.sender, difference);
        }
        puts[p++] = Put(msg.sender, _assetAmount, _minimumPurchase, _newStrike, _totalPurch, _newPrice, _newExpiry, false, true, msg.sender, false);
        emit NewAsk(p.sub(1), _assetAmount, _minimumPurchase, _newStrike, _newPrice, _newExpiry);
    }

    
    
    
    //************SWAP SPECIFIC FUNCTIONS USED FOR THE CASH CLOSE METHODS***********************/
    
    
    //function to transfer an owned call (only long) for the primary purpose of leveraging external swap functions to physically exercise in the case of no cash closing
    function transferAndSwap(uint _p, address payable newOwner, address[] memory path) external {
        Put storage put = puts[_p];
        require(put.expiry >= block.timestamp, "p: This put is already expired");
        require(!put.exercised, "p: This has already been exercised!");
        require(put.open, "p: only open puts can be swapped");
        require(msg.sender == put.long, "p: You dont own this put");
        require(newOwner != put.short, "p: you cannot transfer to the short");
        require(!Address.isContract(newOwner) || path.length > 1);
        put.long = newOwner; //set long to new owner
        if (path.length > 1) {
            require(IHedgeyFactory(hedgeyFactory).isSwapper(newOwner));
            //swapping from asset to payment currency - need asset first and payment currency last in the path
            require(path[0] == pymtCurrency && path[path.length - 1] == asset, "your not swapping the right currencies");
            IHedgeySwap(newOwner).hedgeyPutSwap(msg.sender, _p, put.assetAmt, path);
        }
        
        emit OptionTransferred(_p, newOwner);
    }
    

    //function to swap from this contract to uniswap pool
    function swap(address token, uint out, uint _in, address to) internal {
        SafeERC20.safeTransfer(IERC20(token), uniPair, _in); //sends the asset amount in to the swap
        address token0 = IUniswapV2Pair(uniPair).token0();
        if (token == token0) {
            IUniswapV2Pair(uniPair).swap(0, out, to, new bytes(0));
        } else {
            IUniswapV2Pair(uniPair).swap(out, 0, to, new bytes(0));
        }
        
    }
    
    
    function estIn(uint amountOut) public view returns (uint amountIn) {
        (uint resA, uint resB,) = IUniswapV2Pair(uniPair).getReserves();
        address token1 = IUniswapV2Pair(uniPair).token1();
        amountIn = (token1 == asset) ? UniswapV2Library.getAmountIn(amountOut, resA, resB) : UniswapV2Library.getAmountIn(amountOut, resB, resA);
    }


    /***events*****/
    event NewBid(uint _i, uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry);
    event NewAsk(uint _i, uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry);
    event NewOptionSold(uint _i);
    event NewOptionBought(uint _i);
    event OpenOptionSold(uint _i, uint _j, address _long, uint _price);
    event OpenShortRePurchased(uint _i, uint _j, address _short, uint _price);
    event OpenOptionPurchased(uint _i);
    event OptionChanged(uint _i, uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry);
    event PriceSet(uint _i, uint _price, bool _tradeable);
    event OptionExercised(uint _i, bool _cashClosed);
    event OptionReturned(uint _i);
    event OptionCancelled(uint _i);
    event OptionTransferred(uint _i, address _newOwner);
    event PoolOptionBought(uint _i, uint _j, uint _assetAmt, uint _strike, uint _price, uint _expiry);
    event AMMUpdate(bool _cashCloseOn);
}

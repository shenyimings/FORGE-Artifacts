pragma solidity ^0.6.12;

import "./libraries.sol"


interface IHedgeySwap {
    function hedgeyCallSwap(address originalOwner, uint _c, uint _totalPurchase, address[] memory path, bool cashBack) external;
}


interface IHedgeyFactory {
    function isSwapper(address swapper) external view returns (bool);
}

//contract assumes that neither asset nor payment currency is ETH / WETH
contract HedgeyCeloCalls is ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address hedgeyFactory;
    address public asset;
    address public pymtCurrency;
    uint public assetDecimals;
    address public uniPair;
    uint public fee;
    address public feeCollector;
    uint public c = 0;
    address public constant uniFactory = 0x62d5b84bE28a183aBB507E125B384122D2C25fAE; //ubeswap factory
    bool public cashCloseOn;
    uint public lastAssetBalance;
    uint public assetDifference;
    


    constructor(address _asset, address _pymtCurrency, address _feeCollector, uint _fee) public {
        hedgeyFactory = msg.sender;
        require(_asset != _pymtCurrency);
        asset = _asset;
        pymtCurrency = _pymtCurrency;
        feeCollector = _feeCollector;
        fee = _fee;
        assetDecimals = IERC20(_asset).decimals();
        uniPair = IUniswapV2Factory(uniFactory).getPair(asset, pymtCurrency);
        if (uniPair != address(0x0)) {
            cashCloseOn = true;
        }
        
    }


    struct Call {
        address short;
        uint assetAmt;
        uint minimumPurchase;
        uint strike;
        uint totalPurch;
        uint price;
        uint expiry;
        bool open;
        bool tradeable;
        address long;
        bool exercised;
    }

    
    mapping (uint => Call) public calls;

    
    //internal and setup functions

    

    function depositPymt(address _token, address _sender, uint _amt) internal {
        if (_amt > 0) {
            SafeERC20.safeTransferFrom(IERC20(_token), _sender, address(this), _amt);
        }
        
    }

    function withdrawPymt(address _token, address to, uint _amt) internal {
        if (_amt > 0) {
            SafeERC20.safeTransfer(IERC20(_token), to, _amt);
        }
        
    }

    function transferPymt(address _token, address from, address to, uint _amt) internal {
        if (_amt > 0) {
            SafeERC20.safeTransferFrom(IERC20(_token), from, to, _amt);
        }
                 
    }

    function transferPymtWithFee(address _token, address from, address to, uint _total) internal {
        uint _fee = (_total * fee).div(1e4);
        uint _amt = _total.sub(_fee);
        if (_amt > 0) {
            transferPymt(_token, from, to, _amt); //transfer the stub to recipient
        }
        
        if(_fee > 0) {
            transferPymt(_token, from, feeCollector, _fee); //transfer fee to fee collector
        }
            
    }
    
    function calculateLastBalances() internal {
        lastAssetBalance = IERC20(asset).balanceOf(address(this));
    }

    function calculateDifferences() internal {
        assetDifference += IERC20(asset).balanceOf(address(this)).sub(lastAssetBalance);
    }


    //admin function to update the fee amount
    function changeFee(uint _newFee, address _collector) external {
        require(msg.sender == feeCollector, "youre not the collector");
        fee = _newFee;
        feeCollector = _collector;
    }

    function updateAMM() external {
        uniPair = IUniswapV2Factory(uniFactory).getPair(asset, pymtCurrency);
        if (uniPair == address(0x0)) {
            cashCloseOn = false;
        } else {
            cashCloseOn = true;
        }
        emit AMMUpdate(cashCloseOn);
        
    }
    
    function withdrawMTokenExtra() external {
        require(msg.sender == feeCollector);
        calculateDifferences();
        if (assetDifference > 0) {
            SafeERC20.safeTransfer(IERC20(asset), feeCollector, assetDifference);
        }
        assetDifference = 0;
        calculateLastBalances();
        
    }
    
    
    //CALL FUNCTIONS GOING HERE**********************************************************

    //function for someone wanting to buy a new call
    function newBid(uint _assetAmt, uint _strike, uint _price, uint _expiry) external {
        calculateDifferences();
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "c: totalPurch error: too small amount");
        uint balCheck = IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= _price, "c: not enough cash to bid");
        depositPymt(pymtCurrency, msg.sender, _price); 
        calls[c++] = Call(address(0x0), _assetAmt, _assetAmt, _strike, _totalPurch, _price, _expiry, false, true, msg.sender, false);
        emit NewBid(c.sub(1), _assetAmt, _assetAmt, _strike, _price, _expiry);
        calculateLastBalances();
    }
    
    //function to cancel a new bid
    function cancelNewBid(uint _c) external nonReentrant {
        calculateDifferences();
        Call storage call = calls[_c];
        require(msg.sender == call.long, "c: only long can cancel a bid");
        require(!call.open, "c: call already open");
        require(!call.exercised, "c: call already exercised");
        require(call.short == address(0x0), "c: this is not a new bid");
        call.tradeable = false;
        call.exercised = true;
        withdrawPymt(pymtCurrency, call.long, call.price);
        emit OptionCancelled(_c);
        calculateLastBalances();
    }

    
    function sellOpenOptionToNewBid(uint _c, uint _d, uint _price) external nonReentrant {
        calculateDifferences();
        Call storage openCall = calls[_c];
        Call storage newBid = calls[_d];
        require(_c != _d, "c: wrong sale function");
        require(_price == newBid.price, "c: price changed before you could execute");
        require(msg.sender == openCall.long, "c: you dont own this");
        require(openCall.strike == newBid.strike, "c: not the right strike");
        require(openCall.assetAmt == newBid.assetAmt, "c: not the right assetAmt");
        require(openCall.expiry == newBid.expiry, "c: not the right expiry");
        require(newBid.short == address(0x0), "c: this is not a new bid"); //newBid always sets the short address to 0x0
        require(openCall.open && !newBid.open && newBid.tradeable && !openCall.exercised && !newBid.exercised && openCall.expiry > now && newBid.expiry > now, "something is wrong");
        newBid.exercised = true;
        newBid.tradeable = false;
        uint feePymt = (newBid.price * fee).div(1e4);
        uint shortPymt = newBid.price.sub(feePymt);
        withdrawPymt(pymtCurrency, openCall.long, shortPymt);
        if(feePymt > 0) {
            SafeERC20.safeTransfer(IERC20(pymtCurrency), feeCollector, feePymt);
        }
        if (openCall.short == newBid.long) {
            withdrawPymt(asset, openCall.short, openCall.assetAmt);
            openCall.exercised = true;
            openCall.open = false;
            openCall.tradeable = false;
        } else {
            openCall.long = newBid.long;
            openCall.price = newBid.price;
            openCall.tradeable = false;
        }
        
        emit OpenOptionSold( _c, _d, openCall.long, _price);
        calculateLastBalances();
    }

    //function for someone to write the call for the open bid
    //, uint _strike, uint _assetAmt, uint _price, uint _expiry
    function sellNewOption(uint _c, uint _assetAmt, uint _strike, uint _price, uint _expiry) external nonReentrant {
        calculateDifferences();
        Call storage call = calls[_c];
        require(call.strike == _strike && call.assetAmt == _assetAmt && call.price == _price && call.expiry == _expiry, "c details issue: something changed");
        require(call.short == address(0x0));
        require(msg.sender != call.long, "c: you are the long");
        require(call.expiry > now, "c: This is already expired");
        require(call.tradeable, "c: not tradeable");
        require(!call.open, "c: call already open");
        require(!call.exercised, "c: this has been exercised");
        uint feePymt = (call.price * fee).div(1e4);
        uint shortPymt = (call.price).sub(feePymt);
        uint balCheck = IERC20(asset).balanceOf(msg.sender);
        require(balCheck >= call.assetAmt, "c: not enough cash to bid");
        depositPymt(asset, msg.sender, call.assetAmt);
        if (feePymt > 0) {
            SafeERC20.safeTransfer(IERC20(pymtCurrency), feeCollector, feePymt);
        }
        withdrawPymt(pymtCurrency, msg.sender, shortPymt);
        call.short = msg.sender;
        call.tradeable = false;
        call.open = true;
        emit NewOptionSold(_c);
        calculateLastBalances();
    }


    function changeNewOption(uint _c, uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry) external nonReentrant {
        calculateDifferences();
        Call storage call = calls[_c];
        require(call.long == msg.sender, "c: you do not own this call");
        require(!call.exercised, "c: this has been exercised");
        require(!call.open, "c: this is already open");
        require(call.tradeable, "c: this is not a tradeable option");
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "c: totalPurchase error: too small amount");
        require(_minimumPurchase.mul(_strike).div(10 ** assetDecimals) > 0, "c: minimum purchase error, too small of a minimum");
        require(_assetAmt % _minimumPurchase == 0, "c: asset amount needs to be a multiple of the minimum");
        if (msg.sender == call.short) {
            uint refund = (call.assetAmt > _assetAmt) ? call.assetAmt.sub(_assetAmt) : _assetAmt.sub(call.assetAmt);
            call.strike = _strike;
            call.price = _price;
            call.expiry = _expiry;
            call.minimumPurchase = _minimumPurchase;
            call.totalPurch = _totalPurch;
            call.tradeable = true;
            if (call.assetAmt > _assetAmt) {
                call.assetAmt = _assetAmt;
                withdrawPymt(asset, call.short, refund);
            } else if (call.assetAmt < _assetAmt) {
                call.assetAmt = _assetAmt;
                uint balCheck = IERC20(asset).balanceOf(msg.sender);
                require(balCheck >= refund, "c: not enough to change this call option");
                depositPymt(asset, msg.sender, refund);
            }
            
            emit OptionChanged(_c, _assetAmt, _minimumPurchase, _strike, _price, _expiry);
            calculateLastBalances();

        } else if (call.short == address(0x0)) {
            //its a newBid
            uint refund = (_price > call.price) ? _price.sub(call.price) : call.price.sub(_price);
            call.assetAmt = _assetAmt;
            call.minimumPurchase = _assetAmt;
            call.strike = _strike;
            call.expiry = _expiry;
            call.totalPurch = _totalPurch;
            call.tradeable = true;
            if (_price > call.price) {
                call.price = _price;
                uint balCheck = IERC20(pymtCurrency).balanceOf(msg.sender);
                require(balCheck >= refund, "c: not enough cash to bid");
                depositPymt(pymtCurrency, msg.sender, refund);
            } else if (_price < call.price) {
                call.price = _price;
                withdrawPymt(pymtCurrency, call.long, refund);
            }
            
            emit OptionChanged(_c, _assetAmt, _assetAmt, _strike, _price, _expiry);
            calculateLastBalances();
        }
           
    }

    //function to write a new call
    function newAsk(uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry) external {
        calculateDifferences();
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "c: totalPurchase error: too small amount");
        require(_minimumPurchase.mul(_strike).div(10 ** assetDecimals) > 0, "c: minimum purchase error, too small of a min");
        require(_assetAmt % _minimumPurchase == 0, "c: asset amount needs to be a multiple of the minimum");
        uint balCheck = IERC20(asset).balanceOf(msg.sender);
        require(balCheck >= _assetAmt, "c: not enough to sell this call option");
        depositPymt(asset, msg.sender, _assetAmt);
        calls[c++] = Call(msg.sender, _assetAmt, _minimumPurchase, _strike, _totalPurch, _price, _expiry, false, true, msg.sender, false);
        emit NewAsk(c.sub(1), _assetAmt, _minimumPurchase, _strike, _price, _expiry);
        calculateLastBalances();
    }


    //function to cancel a new ask from writter side
    function cancelNewAsk(uint _c) external nonReentrant {
        calculateDifferences();
        Call storage call = calls[_c];
        require(msg.sender == call.short && msg.sender == call.long, "c: only short can change an ask");
        require(!call.open, "c: call already open");
        require(!call.exercised, "c: call already exercised");
        call.tradeable = false;
        call.exercised = true;
        withdrawPymt(asset, call.short, call.assetAmt);
        emit OptionCancelled(_c);
        calculateLastBalances();
    }
    
    //function to purchase a new call that hasn't changed hands yet
    //, uint _strike, uint _assetAmt, uint _price, uint _expiry
    function buyNewOption(uint _c, uint _assetAmt, uint _strike, uint _price, uint _expiry) external {
        Call storage call = calls[_c];
        require(call.strike == _strike && _assetAmt > 0 && call.price == _price && call.expiry == _expiry, "c details issue: something changed");
        require(msg.sender != call.short, "c: you cannot buy this");
        require(call.short != address(0x0) && call.short == call.long, "c: this option is not a new ask");
        require(call.expiry > now, "c: This call is already expired");
        require(!call.exercised, "c: This has already been exercised");
        require(call.tradeable, "c: This isnt tradeable yet");
        require(!call.open, "c: This call is already open");
        //price for purchase amount calculation for buying smaller sizes
        if (_assetAmt == call.assetAmt) {
            require(_price == call.price, "c: price does not match");
            uint balCheck = IERC20(pymtCurrency).balanceOf(msg.sender);
            require(balCheck >= call.price, "c: not enough to sell this call option");
            transferPymtWithFee(pymtCurrency, msg.sender, call.short, _price);
            call.open = true;
            call.long = msg.sender;
            call.tradeable = false;
            emit NewOptionBought(_c);
        } else {
            uint pricePerToken = call.price.mul(10 ** 32).div(call.assetAmt);
            uint proRataPrice = _assetAmt.mul(pricePerToken).div(10 ** 32);
            require(_price == proRataPrice, "c: price doesnt match pro rata price");
            require(call.assetAmt.sub(_assetAmt) >= call.minimumPurchase, "c: remainder too small");
            uint balCheck = IERC20(pymtCurrency).balanceOf(msg.sender);
            require(balCheck >= proRataPrice, "c: not enough to sell this call option");
            uint proRataTotalPurchase = _assetAmt.mul(_strike).div(10 ** assetDecimals);
            transferPymtWithFee(pymtCurrency, msg.sender, call.short, proRataPrice);
            calls[c++] = Call(call.short, _assetAmt, call.minimumPurchase, call.strike, proRataTotalPurchase, _price, _expiry, true, false, msg.sender, false);
            emit PoolOptionBought(_c, c.sub(1), _assetAmt, _strike, _price, _expiry);
            //update the current call to become the remainder
            call.assetAmt -= _assetAmt;
            call.price -= _price;
            call.totalPurch = call.assetAmt.mul(_strike).div(10 ** assetDecimals);
            
        }

    }
    
    
    function buyOptionFromAsk(uint _c, uint _d, uint _price) external nonReentrant {
        calculateDifferences();
        Call storage openShort = calls[_c];
        Call storage ask = calls[_d];
        require(msg.sender == openShort.short, "c: your not the short");
        require(ask.short != address(0x0), "c: this is a newBid");
        require(_price == ask.price);
        require(ask.tradeable && !ask.exercised && ask.expiry > now,"c: ask issue");
        require(openShort.open && !openShort.exercised && openShort.expiry > now, "c: short issue");
        require(openShort.strike == ask.strike, "c: strikes");
        require(openShort.assetAmt == ask.assetAmt, "c: asset");
        require(openShort.expiry == ask.expiry, "c: expiry");
        require(_c != _d);
        //openShort pays the ask
        uint balCheck = IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= ask.price);
        transferPymtWithFee(pymtCurrency, openShort.short, ask.long, _price); //if newAsk then ask.long == ask.short, if openAsk then ask.long is the one receiving the payment
        //all the checks having been matched - now we assign the openAsk short to the openShort short position
        //then we close out the openAsk position
        ask.exercised = true;
        ask.tradeable = false;
        ask.open = false;
        //now withdraw the openShort's asset back to them
        withdrawPymt(asset, openShort.short, openShort.assetAmt);
        if (openShort.long == ask.short) {
            openShort.exercised = true;
            openShort.tradeable = false;
            openShort.open = false;
            withdrawPymt(asset, ask.short, ask.assetAmt);
        } else {
            openShort.short = ask.short;
        }
        emit OpenShortRePurchased( _c, _d, openShort.short, _price);
        calculateLastBalances();
    }
    


    //this function lets the long set a new price on the call - typically used for existing open positions
    function setPrice(uint _c, uint _price, bool _tradeable) external {
        Call storage call = calls[_c];
        require((msg.sender == call.long && msg.sender == call.short && _tradeable) || (msg.sender == call.long && call.open), "c: you cant change the price");
        require(call.expiry > now, "c: already expired");
        require(!call.exercised, "c: already expired");
        call.price = _price; 
        call.tradeable = _tradeable;
        emit PriceSet(_c, _price, _tradeable);
    }



    //use this function to sell existing calls
    //uint _strike, uint _assetAmt, uint _price, uint _expiry
    function buyOpenOption(uint _c, uint _assetAmt, uint _strike, uint _price, uint _expiry) external nonReentrant {
        calculateDifferences();
        Call storage call = calls[_c];
        require(call.strike == _strike && call.assetAmt == _assetAmt && call.price == _price && call.expiry == _expiry, "c: something changed");
        require(msg.sender != call.long, "c: You already own this");
        require(call.open, "c: This call isnt opened yet");
        require(call.expiry >= now, "c:expired");
        require(!call.exercised, "c: exercised");
        require(call.tradeable, "c: !tradeable");
        uint balCheck = IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= call.price);
        transferPymtWithFee(pymtCurrency, msg.sender, call.long, call.price);
        if (msg.sender == call.short) {
            call.exercised = true;
            call.open = false;
            withdrawPymt(asset, call.short, call.assetAmt);
        }
        call.tradeable = false;
        call.long = msg.sender;
        emit OpenOptionPurchased(_c);
        calculateLastBalances();
    }


    //this is the basic exercise execution function that needs to be invoked prior to maturity to receive the physical asset
    function exercise(uint _c) external nonReentrant {
        calculateDifferences();
        Call storage call = calls[_c];
        require(call.open);
        require(call.expiry >= now, "c: expired");
        require(!call.exercised, "c: exercised");
        require(msg.sender == call.long);
        uint balCheck = IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= call.totalPurch);
        call.exercised = true;
        call.open = false;
        call.tradeable = false;
        transferPymt(pymtCurrency, msg.sender, call.short, call.totalPurch);   
        withdrawPymt(asset, call.long, call.assetAmt);
        emit OptionExercised(_c, false);
        calculateLastBalances();
    }


    //this is the exercise alternative for ppl who want to receive payment currency instead of the underlying asset
    function cashClose(uint _c, bool cashBack) external nonReentrant {
        calculateDifferences();
        require(cashCloseOn);
        Call storage call = calls[_c];
        require(call.open);
        require(call.expiry >= now, "c:expired");
        require(!call.exercised, "c: exercised");
        require(msg.sender == call.long);
        uint assetIn = estIn(call.totalPurch);
        require(assetIn < call.assetAmt, "c: not money");
        call.exercised = true;
        call.open = false;
        call.tradeable = false;
        swap(asset, call.totalPurch, assetIn, call.short);     
        call.assetAmt -= assetIn;
        if (cashBack) {
            uint cashEst = estCashOut(call.assetAmt);
            swap(asset, cashEst, call.assetAmt, call.long);
        } else {
            withdrawPymt(asset, call.long, call.assetAmt);
        }
        
        emit OptionExercised(_c, true);
        calculateLastBalances();
    }


    

    //returns an expired call back to the short
    function returnExpired(uint[] memory _calls) external nonReentrant {
        calculateDifferences();
        uint _totalAssetAmount;
        for (uint i; i < _calls.length; i++) {
            Call storage call = calls[_calls[i]];
            require(!call.exercised && call.expiry < now && msg.sender == call.short);
            call.exercised = true;
            call.open = false;
            call.tradeable = false;
            _totalAssetAmount += call.assetAmt;
            emit OptionReturned(_calls[i]);
        }
        withdrawPymt(asset, msg.sender, _totalAssetAmount);
        calculateDifferences();
    }
    
    
    
    function rollExpired(uint[] memory _calls, uint _assetAmount, uint _minimumPurchase, uint _newStrike, uint _newPrice, uint _newExpiry) external {
        calculateDifferences();
        uint _totalAssetAmount;
        for (uint i; i < _calls.length; i++) {
            Call storage call = calls[_calls[i]];
            require(!call.exercised && call.expiry < now && msg.sender == call.short);
            call.exercised = true;
            call.open = false;
            call.tradeable = false;
            _totalAssetAmount += call.assetAmt;
            emit OptionReturned(_calls[i]);
        }
        require(_assetAmount % _minimumPurchase == 0 && _assetAmount >= _totalAssetAmount);
        uint _totalPurch = (_assetAmount).mul(_newStrike).div(10 ** assetDecimals);
        require(_totalPurch > 0 && _minimumPurchase.mul(_newStrike).div(10 ** assetDecimals) > 0);
        require(_newExpiry > block.timestamp);
        //only allow the writer to upsize, and pull in the additional funds required to collateralize
        if (_assetAmount > _totalAssetAmount) {
            require(IERC20(pymtCurrency).balanceOf(msg.sender) >= _assetAmount.sub(_totalAssetAmount));
            depositPymt(asset, msg.sender, _assetAmount.sub(_totalAssetAmount));
        }
        calls[c++] = Call(msg.sender, _assetAmount, _minimumPurchase, _newStrike, _totalPurch, _newPrice, _newExpiry, false, true, msg.sender, false);
        emit NewAsk(c.sub(1), _assetAmount, _minimumPurchase, _newStrike, _newPrice, _newExpiry);
        calculateDifferences();
    }

    

   
    

    //************SWAP SPECIFIC FUNCTIONS USED FOR THE CASH CLOSE METHODS***********************/
    
     //function to transfer an owned call (only long) for the primary purpose of leveraging external swap functions to physically exercise in the case of no cash closing
    function transferAndSwap(uint _c, address newOwner, address[] memory path, bool cashBack) external {
        Call storage call = calls[_c];
        require(call.expiry >= block.timestamp, "c: This call is already expired");
        require(!call.exercised, "c: This has already been exercised!");
        require(call.open, "c: only open calls can be transferred");
        require(msg.sender == call.long, "c: You dont own this call");
        require(newOwner != call.short, "c: you cannot transfer to the short");
        require(!Address.isContract(newOwner) || path.length > 1);
        call.long = newOwner; //set long to new owner
        if (path.length > 1) {
            require(IHedgeyFactory(hedgeyFactory).isSwapper(newOwner)); 
            //swapping from asset to payment currency - need asset first and payment currency last in the path
            require(path[0] == asset && path[path.length - 1] == pymtCurrency, "your not swapping the right currencies");
            IHedgeySwap(newOwner).hedgeyCallSwap(msg.sender, _c, call.totalPurch, path, cashBack);
        }
        
        emit OptionTransferred(_c, newOwner);
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

    function estCashOut(uint amountIn) public view returns (uint amountOut) {
        (uint resA, uint resB,) = IUniswapV2Pair(uniPair).getReserves();
        address token1 = IUniswapV2Pair(uniPair).token1();
        amountOut = (token1 == pymtCurrency) ? UniswapV2Library.getAmountOut(amountIn, resA, resB) : UniswapV2Library.getAmountOut(amountIn, resB, resA);
    }

    function estIn(uint amountOut) public view returns (uint amountIn) {
        (uint resA, uint resB,) = IUniswapV2Pair(uniPair).getReserves();
        address token1 = IUniswapV2Pair(uniPair).token1();
        amountIn = (token1 == pymtCurrency) ? UniswapV2Library.getAmountIn(amountOut, resA, resB) : UniswapV2Library.getAmountIn(amountOut, resB, resA);
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

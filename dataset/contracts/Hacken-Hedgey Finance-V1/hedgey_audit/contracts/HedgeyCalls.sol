pragma solidity ^0.6.12;

import "./libraries.sol"


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}


interface IHedgeySwap {
    function hedgeyCallSwap(address originalOwner, uint _c, uint _totalPurchase, address[] memory path, bool cashBack) external;
}


interface IHedgeyFactory {
    function isSwapper(address swapper) external view returns (bool);
}


contract HedgeyCalls is ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public hedgeyFactory;
    address public asset;
    address public pymtCurrency;
    uint public assetDecimals;
    address public uniPair; 
    address payable public constant weth = 0xc778417E063141139Fce010982780140Aa0cD5Ab; //weth address    
    uint public fee;
    address payable public feeCollector;
    uint public c = 0;
    address public constant uniFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; //AMM factory address
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
        uniPair = IUniswapV2Factory(uniFactory).getPair(asset, pymtCurrency);
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
    
    struct Call {
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

    
    mapping (uint => Call) public calls;

    
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
        require(msg.sender == feeCollector);
        fee = _fee;
        feeCollector = _collector;
    }

    
    //function anyone can call after the contract is set to update if there was no AMM before but now there is
    function updateAMM() external {
        uniPair = IUniswapV2Factory(uniFactory).getPair(asset, pymtCurrency);
        if (uniPair == address(0x0)) {
            cashCloseOn = false;
        } else {
            cashCloseOn = true;
        }
        emit AMMUpdate(cashCloseOn);
        
    }


    //CALL FUNCTIONS GOING HERE**********************************************************

    //function for someone wanting to buy a new call
    function newBid(uint _assetAmt, uint _strike, uint _price, uint _expiry) payable external {
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "c: totalPurchase error: too small amount");
        uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= _price, "c: not enough cash to bid");
        depositPymt(pymtWeth, pymtCurrency, msg.sender, _price); 
        calls[c++] = Call(address(0x0), _assetAmt, _assetAmt, _strike, _totalPurch, _price, _expiry, false, true, msg.sender, false);
        emit NewBid(c.sub(1), _assetAmt, _assetAmt, _strike, _price, _expiry);
    }
    
    //function to cancel a new bid
    function cancelNewBid(uint _c) external nonReentrant {
        Call storage call = calls[_c];
        require(msg.sender == call.long, "c: only long can cancel a bid");
        require(!call.open, "c: call already open");
        require(!call.exercised, "c: call already exercised");
        require(call.short == address(0x0), "c: this is not a new bid");
        call.tradeable = false;
        call.exercised = true;
        withdrawPymt(pymtWeth, pymtCurrency, call.long, call.price);
        emit OptionCancelled(_c);
    }

    
    function sellOpenOptionToNewBid(uint _c, uint _d, uint _price) payable external nonReentrant {
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
        withdrawPymt(pymtWeth, pymtCurrency, openCall.long, shortPymt);
        if (feePymt > 0) SafeERC20.safeTransfer(IERC20(pymtCurrency), feeCollector, feePymt);
        openCall.long = newBid.long;
        openCall.price = newBid.price;
        openCall.tradeable = false;
        emit OpenOptionSold( _c, _d, openCall.long, _price);
    }

    //function for someone to write the call for the open bid
    //, uint _strike, uint _assetAmt, uint _price, uint _expiry
    function sellNewOption(uint _c, uint _assetAmt, uint _strike, uint _price, uint _expiry) payable external nonReentrant {
        Call storage call = calls[_c];
        require(call.strike == _strike && call.assetAmt == _assetAmt && call.price == _price && call.expiry == _expiry, "c details issue");
        require(call.short == address(0x0));
        require(msg.sender != call.long, "c: you are the long");
        require(call.expiry > now, "c: This is already expired");
        require(call.tradeable, "c: not tradeable");
        require(!call.open, "c: call already open");
        require(!call.exercised, "c: this has been exercised");
        uint feePymt = (call.price * fee).div(1e4);
        uint shortPymt = (call.price).sub(feePymt);
        uint balCheck = assetWeth ? msg.value : IERC20(asset).balanceOf(msg.sender);
        require(balCheck >= call.assetAmt, "c: not enough cash to bid");
        depositPymt(assetWeth, asset, msg.sender, call.assetAmt);
        if (feePymt > 0) SafeERC20.safeTransfer(IERC20(pymtCurrency), feeCollector, feePymt);
        withdrawPymt(pymtWeth, pymtCurrency, msg.sender, shortPymt);
        call.short = msg.sender;
        call.tradeable = false;
        call.open = true;
        emit NewOptionSold(_c);
    }

    
    function changeNewOption(uint _c, uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry) payable external nonReentrant {
        Call storage call = calls[_c];
        require(call.long == msg.sender, "c: dont own");
        require(!call.exercised, "c: exercised");
        require(!call.open, "c: open");
        require(call.tradeable, "c: !tradeable");
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "c: totalPurchase err");
        //lets check if this is a new ask or new bid
        //if its a newAsk
        if (msg.sender == call.short) {
            require(_minimumPurchase.mul(_strike).div(10 ** assetDecimals) > 0, "c: min error");
            require(_assetAmt % _minimumPurchase == 0, "c: mod error");
            uint refund = (call.assetAmt > _assetAmt) ? call.assetAmt.sub(_assetAmt) : _assetAmt.sub(call.assetAmt);
            call.strike = _strike;
            call.price = _price;
            call.expiry = _expiry;
            call.minimumPurchase = _minimumPurchase;
            call.totalPurch = _totalPurch;
            call.tradeable = true;
            if (call.assetAmt > _assetAmt) {
                call.assetAmt = _assetAmt;
                withdrawPymt(assetWeth, asset, call.short, refund);
            } else if (call.assetAmt < _assetAmt) {
                call.assetAmt = _assetAmt;
                uint balCheck = assetWeth ? msg.value : IERC20(asset).balanceOf(msg.sender);
                require(balCheck >= refund, "c: short change");
                depositPymt(assetWeth, asset, msg.sender, refund);
            }
            
            emit OptionChanged(_c, _assetAmt, _minimumPurchase, _strike, _price, _expiry);

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
                uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
                require(balCheck >= refund, "c: not enough cash to bid");
                depositPymt(pymtWeth, pymtCurrency, msg.sender, refund);
            } else if (_price < call.price) {
                call.price = _price;
                withdrawPymt(pymtWeth, pymtCurrency, call.long, refund);
            }
            
            emit OptionChanged(_c, _assetAmt, _minimumPurchase, _strike, _price, _expiry);    
        }
           
    } 
    

    //function to write a new call
    function newAsk(uint _assetAmt, uint _minimumPurchase, uint _strike, uint _price, uint _expiry) payable external {
        uint _totalPurch = _assetAmt.mul(_strike).div(10 ** assetDecimals);
        require(_totalPurch > 0, "c: totalPurchase error: too small amount");
        require(_minimumPurchase.mul(_strike).div(10 ** assetDecimals) > 0, "c: minimum purchase error, too small of a min");
        require(_assetAmt % _minimumPurchase == 0, "c: asset amount needs to be a multiple of the minimum");
        uint balCheck = assetWeth ? msg.value : IERC20(asset).balanceOf(msg.sender);
        require(balCheck >= _assetAmt, "c: not enough to sell this call option");
        depositPymt(assetWeth, asset, msg.sender, _assetAmt);
        calls[c++] = Call(msg.sender, _assetAmt, _minimumPurchase, _strike, _totalPurch, _price, _expiry, false, true, msg.sender, false);
        emit NewAsk(c.sub(1), _assetAmt, _minimumPurchase, _strike, _price, _expiry);
    }


    //function to cancel a new ask from writter side
    function cancelNewAsk(uint _c) external nonReentrant {
        Call storage call = calls[_c];
        require(msg.sender == call.short && msg.sender == call.long, "c: only short can change an ask");
        require(!call.open, "c: call already open");
        require(!call.exercised, "c: call already exercised");
        call.tradeable = false;
        call.exercised = true;
        withdrawPymt(assetWeth, asset, call.short, call.assetAmt);
        emit OptionCancelled(_c);
    }
    
    //function to purchase a new call that hasn't changed hands yet
    //, uint _strike, uint _assetAmt, uint _price, uint _expiry
    function buyNewOption(uint _c, uint _assetAmt, uint _strike, uint _price, uint _expiry) payable external {
        Call storage call = calls[_c];
        require(call.strike == _strike && call.expiry == _expiry, "c details issue: something changed");
        require(msg.sender != call.short, "c: you cannot buy this");
        require(call.short != address(0x0) && call.short == call.long, "c: this option is not a new ask");
        require(call.expiry > now, "c: This call is already expired");
        require(!call.exercised, "c: This has already been exercised");
        require(call.tradeable, "c: This isnt tradeable yet");
        require(!call.open, "c: This call is already open");
        require(_assetAmt >= call.minimumPurchase, "purchase size does not meet minimum");
        if (_assetAmt == call.assetAmt) {
            require(_price == call.price, "c: price does not match");
            uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
            require(balCheck >= call.price, "c: not enough to sell this call option");
            transferPymtWithFee(pymtWeth, pymtCurrency, msg.sender, call.short, _price);
            call.open = true;
            call.long = msg.sender;
            call.tradeable = false;
            emit NewOptionBought(_c);
        } else {
            uint pricePerToken = call.price.mul(10 ** 32).div(call.assetAmt);
            uint proRataPrice = _assetAmt.mul(pricePerToken).div(10 ** 32);
            require(_price == proRataPrice, "c: price doesnt match pro rata price");
            require(call.assetAmt.sub(_assetAmt) >= call.minimumPurchase, "c: remainder too small");
            uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
            require(balCheck >= proRataPrice, "c: not enough to sell this call option");
            uint proRataTotalPurchase = _assetAmt.mul(_strike).div(10 ** assetDecimals);
            transferPymtWithFee(pymtWeth, pymtCurrency, msg.sender, call.short, proRataPrice);
            calls[c++] = Call(call.short, _assetAmt, call.minimumPurchase, call.strike, proRataTotalPurchase, _price, _expiry, true, false, msg.sender, false);
            emit PoolOptionBought(_c, c.sub(1), _assetAmt, _strike, _price, _expiry);
            //update the current call to become the remainder
            call.assetAmt -= _assetAmt;
            call.price -= _price;
            call.totalPurch = call.assetAmt.mul(_strike).div(10 ** assetDecimals);
            
        }
        
    }
    
    

    
    /**function to buy an openAsk or newAsk and then replace the long from one position with the long of the other position and remove openShort from obligation */
    function buyOptionFromAsk(uint _c, uint _d, uint _price) payable external nonReentrant {
        Call storage openShort = calls[_c];
        Call storage ask = calls[_d];
        require(msg.sender == openShort.short, "c: your not the short");
        require(ask.short != address(0x0), "c: this is a newBid");
        require(_price == ask.price, "c: price changed before executed");
        require(ask.tradeable && !ask.exercised && ask.expiry > now,"c: ask issue");
        require(openShort.open && !openShort.exercised && openShort.expiry > now, "c: short issue");
        require(openShort.strike == ask.strike, "c: strikes do not match");
        require(openShort.assetAmt == ask.assetAmt, "c: asset amount does not match");
        require(openShort.expiry == ask.expiry, "c: expiry does not match");
        require(_c != _d, "c: wrong function to buyback");
        //openShort pays the ask
        uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= ask.price, "c: not enough to buy this put");
        transferPymtWithFee(pymtWeth, pymtCurrency, openShort.short, ask.long, _price); //if newAsk then ask.long == ask.short, if openAsk then ask.long is the one receiving the payment
        //all the checks having been matched - now we assign the openAsk short to the openShort short position
        //then we close out the openAsk position
        ask.exercised = true;
        ask.tradeable = false;
        ask.open = false;
        //now withdraw the openShort's asset back to them
        withdrawPymt(assetWeth, asset, openShort.short, openShort.assetAmt);
        openShort.short = ask.short;
        emit OpenShortRePurchased( _c, _d, openShort.short, _price);
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
    function buyOpenOption(uint _c, uint _assetAmt, uint _strike, uint _price, uint _expiry) payable external nonReentrant {
        Call storage call = calls[_c];
        require(call.strike == _strike && call.assetAmt == _assetAmt && call.price == _price && call.expiry == _expiry);
        require(msg.sender != call.long);
        require(call.open);
        require(call.expiry >= now);
        require(!call.exercised);
        require(call.tradeable);
        uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= call.price);
        transferPymtWithFee(pymtWeth, pymtCurrency, msg.sender, call.long, call.price);
        if (msg.sender == call.short) {
            call.exercised = true;
            call.open = false;
            withdrawPymt(assetWeth, asset, call.short, call.assetAmt);
        }
        call.tradeable = false;
        call.long = msg.sender;
        emit OpenOptionPurchased(_c);
    }


    //this is the basic exercise execution function that needs to be invoked prior to maturity to receive the physical asset
    function exercise(uint _c) payable external nonReentrant {
        Call storage call = calls[_c];
        require(call.open);
        require(call.expiry >= now);
        require(!call.exercised);
        require(msg.sender == call.long);
        uint balCheck = pymtWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
        require(balCheck >= call.totalPurch);
        call.exercised = true;
        call.open = false;
        call.tradeable = false;
        if(pymtWeth) {
            require(msg.value == call.totalPurch);
        }
        transferPymt(pymtWeth, pymtCurrency, msg.sender, call.short, call.totalPurch);   
        withdrawPymt(assetWeth, asset, call.long, call.assetAmt);
        emit OptionExercised(_c, false);
    }


    //this is the exercise alternative for ppl who want to receive payment currency instead of the underlying asset
    function cashClose(uint _c, bool cashBack) payable external nonReentrant {
        require(cashCloseOn);
        Call storage call = calls[_c];
        require(call.open);
        require(call.expiry >= now);
        require(!call.exercised);
        require(msg.sender == call.long);
   
        uint assetIn = estIn(call.totalPurch);
        require(assetIn < (call.assetAmt), "c: Underlying is not in the money");
        
        address to = pymtWeth ? address(this) : call.short;
        call.exercised = true;
        call.open = false;
        call.tradeable = false;
        swap(asset, call.totalPurch, assetIn, to);
        if (pymtWeth) {
            withdrawPymt(pymtWeth, pymtCurrency, call.short, call.totalPurch);
        }
        
        call.assetAmt -= assetIn;
        
        if (cashBack) {
            
            uint cashEst = estCashOut(call.assetAmt);
            address _to = pymtWeth ? address(this) : call.long;
            swap(asset, cashEst, call.assetAmt, _to);
            if (pymtWeth) {
                withdrawPymt(pymtWeth, pymtCurrency, call.long, cashEst); 
            }
        } else {
            withdrawPymt(assetWeth, asset, call.long, call.assetAmt);
        }
        
        emit OptionExercised(_c, true);
    }


    

    //returns an expired call back to the short
    function returnExpired(uint[] memory _calls) external nonReentrant {
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
        withdrawPymt(assetWeth, asset, msg.sender, _totalAssetAmount);
        
    }
    
    
    
    function rollExpired(uint[] memory _calls, uint _assetAmount, uint _minimumPurchase, uint _newStrike, uint _newPrice, uint _newExpiry) payable external {
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
            uint balCheck = assetWeth ? msg.value : IERC20(pymtCurrency).balanceOf(msg.sender);
            require(balCheck >= _assetAmount.sub(_totalAssetAmount));
            depositPymt(assetWeth, asset, msg.sender, _assetAmount.sub(_totalAssetAmount));
        }
        calls[c++] = Call(msg.sender, _assetAmount, _minimumPurchase, _newStrike, _totalPurch, _newPrice, _newExpiry, false, true, msg.sender, false);
        emit NewAsk(c.sub(1), _assetAmount, _minimumPurchase, _newStrike, _newPrice, _newExpiry);
    }
    
    
   
    
    

    //************SWAP SPECIFIC FUNCTIONS USED FOR THE CASH CLOSE METHODS***********************/
    
    
     //function to transfer an owned call (only long) for the primary purpose of leveraging external swap functions to physically exercise in the case of no cash closing
    function transferAndSwap(uint _c, address payable newOwner, address[] memory path, bool cashBack) external {
        Call storage call = calls[_c];
        require(call.expiry >= block.timestamp);
        require(!call.exercised);
        require(call.open);
        require(msg.sender == call.long);
        require(newOwner != call.short && newOwner);
        require(!Address.isContract(newOwner) || path.length > 1);
        call.long = newOwner; //set long to new owner
        if (path.length > 1) {
            require(IHedgeyFactory(hedgeyFactory).isSwapper(newOwner)); //only whitelisted swapper addresses allowed
            //swapping from asset to payment currency - need asset first and payment currency last in the path
            require(path[0] == asset && path[path.length - 1] == pymtCurrency);
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

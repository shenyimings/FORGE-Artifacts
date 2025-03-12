// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../tokens/interfaces/IMintable.sol";
import "../utils/EnumerableValues.sol";
import "./VaultMSData.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IVaultUtils.sol";
import "../oracle/interfaces/IVaultPriceFeedV3Fast.sol";
import "./interfaces/IVaultStorage.sol";
import "../DID/interfaces/IPSBT.sol";
import "./interfaces/IFeeRouter.sol";

contract Vault is ReentrancyGuard, IVault, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableValues for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;

    uint8 public override baseMode;

    IPSBT public psbt;
    IVaultUtils public vaultUtils;
    address public override vaultStorage;
    address public override priceFeed;
    address public override usdx;
    address public feeRouter;

    mapping(address => bool) public override isManager;
    mapping(address => bool) public override approvedRouters;

    uint256 public override totalTokenWeights;
    EnumerableSet.AddressSet tradingTokens;
    EnumerableSet.AddressSet fundingTokens;
    mapping(address => VaultMSData.TokenBase) tokenBase;
    mapping(address => uint256) public override usdxAmounts;     // usdxAmounts tracks the amount of USDX debt for each whitelisted token
    mapping(address => uint256) public override guaranteedUsd;

    //Fee parameters
    // address public feeToken;
    // uint256 public feeReservesAmount;
    // uint256 public feeReservesDiscountedUSD;
    // mapping(uint256 => uint256) public override feeReservesRecord;  //recorded by timestamp/24hours


    mapping(address => VaultMSData.TradingFee) tradingFee;
    mapping(bytes32 => VaultMSData.Position) positions;
    mapping(address => VaultMSData.TradingRec) tradingRec;
    uint256 public override globalShortSize;
    uint256 public override globalLongSize;


    modifier onlyManager() {
        _validate(isManager[msg.sender], 4);
        _;
    }

    event Swap(address account, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 amountOutAfterFees, uint256 feeBasisPoints);
    event IncreasePosition(bytes32 key, address account, address collateralToken, address indexToken, uint256 collateralDelta, uint256 sizeDelta,bool isLong, uint256 price, int256 fee);
    event DecreasePosition(bytes32 key, VaultMSData.Position position, uint256 collateralDelta, uint256 sizeDelta, uint256 price, int256 fee, uint256 usdOut, uint256 latestCollatral, uint256 prevCollateral);
    event DecreasePositionTransOut( bytes32 key,uint256 transOut);
    event LiquidatePosition(bytes32 key, address account, address collateralToken, address indexToken, bool isLong, uint256 size, uint256 collateral, uint256 reserveAmount, int256 realisedPnl, uint256 markPrice);
    event UpdatePosition(bytes32 key, address account, uint256 size,  uint256 collateral, uint256 averagePrice, uint256 entryFundingRate, uint256 reserveAmount, int256 realisedPnl, uint256 markPrice);
    event ClosePosition(bytes32 key, address account, uint256 size, uint256 collateral, uint256 averagePrice, uint256 entryFundingRate, uint256 reserveAmount, int256 realisedPnl);
    event UpdateFundingRate(address token, uint256 fundingRate);
    event UpdatePnl(bytes32 key, bool hasProfit, uint256 delta, uint256 currentSize, uint256 currentCollateral, uint256 usdOut, uint256 usdOutAfterFee);
    event CollectSwapFees(address token, uint256 feeUsd, uint256 feeTokens);
    event CollectMarginFees(address token, uint256 feeUsd, uint256 feeTokens);
    event DirectPoolDeposit(address token, uint256 amount);
    event IncreasePoolAmount(address token, uint256 amount);
    event DecreasePoolAmount(address token, uint256 amount);
    event IncreaseReservedAmount(address token, uint256 amount);
    event DecreaseReservedAmount(address token, uint256 amount);
    event IncreaseGuaranteedUsd(address token, uint256 amount);
    event DecreaseGuaranteedUsd(address token, uint256 amount);
    // event PayTax(address _account, bytes32 _key, uint256 profit, uint256 usdTax);
    // event UpdateGlobalSize(address _indexToken, uint256 tokenSize, uint256 globalSize, uint256 averagePrice, bool _increase, bool _isLong );
    event CollectPremiumFee(address account,uint256 _size, int256 _entryPremiumRate, int256 _premiumFeeUSD);

    function initialize( address _usdx, address _priceFeed, uint8 _baseMode) external onlyOwner{
        require(baseMode==0, "i0");
        usdx = _usdx;
        priceFeed = _priceFeed;
        require(_baseMode > 0 && _baseMode < 4, "I1");
        baseMode = _baseMode;
    }
    // ---------- owner setting part ----------
    function setAdd(address[] memory _addList) external onlyOwner{
        vaultUtils = IVaultUtils(_addList[0]);
        vaultStorage = _addList[1];
        psbt = IPSBT(_addList[2]);
        priceFeed = _addList[3];
        feeRouter = _addList[4];
    }
    function setManager(address _manager, bool _isManager) external override onlyOwner{
        isManager[_manager] = _isManager;
    }

    function setRouter(address _router, bool _status) external override onlyOwner{
        approvedRouters[_router] = _status;
    }

    function setTokenConfig(address _token, uint256 _tokenWeight, bool _isStable, bool _isFundingToken, bool _isTradingToken) external override onlyOwner{
        if (_isTradingToken && !tradingTokens.contains(_token)) {
            tradingTokens.add(_token);
        }
        if (_isFundingToken && !fundingTokens.contains(_token)) {
            fundingTokens.add(_token);
        }
        VaultMSData.TokenBase storage tBase = tokenBase[_token];
        
        if (_isFundingToken){
            totalTokenWeights = totalTokenWeights.add(_tokenWeight).sub(tBase.weight);
            tBase.weight = _tokenWeight;
        }
        else
            tBase.weight = 0;

        tBase.isStable = _isStable;
        tBase.isFundable = _isFundingToken;
        getMaxPrice(_token);// validate price feed
    }

    function clearTokenConfig(address _token, bool _del) external onlyOwner{
        if (tradingTokens.contains(_token)) {
            tradingTokens.remove(_token);
        }
        if (fundingTokens.contains(_token)) {
            totalTokenWeights = totalTokenWeights.sub(tokenBase[_token].weight);
            fundingTokens.remove(_token);
        }  
        if (_del)
            delete tokenBase[_token];
    }
    // the governance controlling this function should have a timelock
    function upgradeVault(address _newVault, address _token, uint256 _amount) external onlyOwner{
        IERC20(_token).safeTransfer(_newVault, _amount);
    }

    //---------- END OF owner setting part ----------



    //---------- FUNCTIONS FOR MANAGER ----------
    function buyUSD(address _token) external override nonReentrant onlyManager returns (uint256) {
        _validate(fundingTokens.contains(_token), 16);
        uint256 tokenAmount = _transferIn(_token);
        _validate(tokenAmount > 0, 17);
        updateRate(_token);
        uint256 feeBasisPoints = vaultUtils.getBuyLpFeeBasisPoints(_token, tokenToUsdMin(_token, tokenAmount));
        uint256 amountAfterFees = _collectSwapFees(_token, tokenAmount, feeBasisPoints);
        //- fee transfered out inside _collectSwapFees
        _increasePoolAmount(_token, amountAfterFees);
        return tokenToUsdMin(_token, amountAfterFees);
    }

    function sellUSD(address _token, address _receiver,  uint256 _usdAmount) external override nonReentrant onlyManager returns (uint256) {
        _validate(fundingTokens.contains(_token), 19);
        _validate(_usdAmount > 0, 20);
        updateRate(_token);
        uint256 redemptionAmount = usdToTokenMin(_token, _usdAmount);
        _validate(redemptionAmount > 0, 21);
        _decreasePoolAmount(_token, redemptionAmount);
        uint256 feeBasisPoints = vaultUtils.getSellLpFeeBasisPoints(_token, _usdAmount);
        //- fee transfered out inside _collectSwapFees
        uint256 amountOut = _collectSwapFees(_token, redemptionAmount, feeBasisPoints);
        _validate(amountOut > 0, 22);
        _transferOut(_token, amountOut, _receiver);
        updateRate(_token);
        return amountOut;
    }


    //---------------------------------------- TRADING FUNCTIONS --------------------------------------------------
    function swap(address _tokenIn,  address _tokenOut, address _receiver ) external override nonReentrant returns (uint256) {
        _validate(approvedRouters[msg.sender], 41);
        // _validate(IVaultStorage(vaultStorage).isSwapEnabled(), 23); redundent
        return _swap(_tokenIn, _tokenOut, _receiver );
    }

    function increasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external override nonReentrant {
        _validate(approvedRouters[msg.sender], 41);
        
        //update cumulative funding rate
        updateRate(_collateralToken);
        if (_indexToken!= _collateralToken) updateRate(_indexToken);

        bytes32 key = vaultUtils.getPositionKey( _account, _collateralToken, _indexToken, _isLong, 0);
        VaultMSData.Position storage position = positions[key];
        vaultUtils.validateIncreasePosition(_collateralToken, _indexToken, position.size, _sizeDelta ,_isLong);

        uint256 price = _isLong ? getMaxPrice(_indexToken) : getMinPrice(_indexToken);
        price = vaultUtils.getImpactedPrice(_indexToken, 
            _sizeDelta.add(_isLong ? tradingRec[_indexToken].longSize : tradingRec[_indexToken].shortSize), price, _isLong);
            
        if (position.size == 0) {
            position.account = _account;
            position.averagePrice = price;
            position.aveIncreaseTime = block.timestamp;
            position.collateralToken = _collateralToken;
            position.indexToken = _indexToken;
            position.isLong = _isLong;       
        }
        else if (position.size > 0 && _sizeDelta > 0) {
            position.aveIncreaseTime = vaultUtils.getNextIncreaseTime(position.aveIncreaseTime, position.size, _sizeDelta); 
            position.averagePrice = vaultUtils.getPositionNextAveragePrice(position.size, position.averagePrice, price, _sizeDelta, true);
        }
        uint256 collateralDelta = _transferIn(_collateralToken);
        uint256 collateralDeltaUsd = tokenToUsdMin(_collateralToken, collateralDelta);
        position.collateral = position.collateral.add(collateralDeltaUsd);
        position.accCollateral = position.accCollateral.add(collateralDeltaUsd);
        _increaseGuaranteedUsd(_collateralToken, collateralDeltaUsd);
        _increasePoolAmount(_collateralToken,  collateralDelta);//aum = pool + aveProfit - guaranteedUsd
        
        //call updateRate before collect Margin Fees
        int256 fee = _collectMarginFees(key, _sizeDelta); //increase collateral before collectMarginFees
        position.lastUpdateTime = block.timestamp;//attention: after _collectMarginFees
        
        // run after collectMarginFees
        position.entryFundingRateSec = tradingFee[_collateralToken].accumulativefundingRateSec;
        position.entryPremiumRateSec = _isLong ? tradingFee[_indexToken].accumulativeLongRateSec : tradingFee[_indexToken].accumulativeShortRateSec;

        position.size = position.size.add(_sizeDelta);
        _validate(position.size > 0, 30);
        _validatePosition(position.size, position.collateral);

        vaultUtils.validateLiquidation(key, true);

        // reserve tokens to pay profits on the position
        {
            uint256 reserveDelta = vaultUtils.getReserveDelta(position.collateralToken, position.size, position.collateral, position.takeProfitRatio);
            if (position.reserveAmount > 0)
                _decreaseReservedAmount(_collateralToken, position.reserveAmount);
            _increaseReservedAmount(_collateralToken, reserveDelta);
            position.reserveAmount = reserveDelta;
        }
       
        _updateGlobalSize(_isLong, _indexToken, _sizeDelta, price, true);
    
        //update rates according to latest positions and token utilizations
        updateRate(_collateralToken);
        if (_indexToken!= _collateralToken) updateRate(_indexToken);            
        
        IVaultStorage(vaultStorage).addKey(_account,key);
        emit IncreasePosition(key, _account, _collateralToken, _indexToken, collateralDeltaUsd,
            _sizeDelta, _isLong, price, fee);
        emit UpdatePosition( key, _account, position.size, position.collateral, position.averagePrice,
            position.entryFundingRateSec.mul(3600).div(1000000), position.reserveAmount, position.realisedPnl, price );
    }

    function decreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver
        ) external override nonReentrant returns (uint256) {
        _validate(approvedRouters[msg.sender] || _account == msg.sender, 41);
        bytes32 key = vaultUtils.getPositionKey(_account, _collateralToken, _indexToken, _isLong, 0);
        return _decreasePosition(key, _collateralDelta, _sizeDelta, _receiver);
    }

    function _decreasePosition(bytes32 key, uint256 _collateralDelta, uint256 _sizeDelta, address _receiver) private returns (uint256) {
        // bytes32 key = vaultUtils.getPositionKey(_account, _collateralToken, _indexToken, _isLong, 0);
        VaultMSData.Position storage position = positions[key];
        vaultUtils.validateDecreasePosition(position,_sizeDelta, _collateralDelta);
        _updateGlobalSize(position.isLong, position.indexToken, _sizeDelta, position.averagePrice, false);
        uint256 collateral = position.collateral;
        // scrop variables to avoid stack too deep errors
        {
            uint256 reserveDelta = vaultUtils.getReserveDelta(position.collateralToken, position.size.sub(_sizeDelta), position.collateral.sub(_collateralDelta), position.takeProfitRatio);
            // uint256 reserveDelta = position.reserveAmount.mul(_sizeDelta).div(position.size);
            _decreaseReservedAmount(position.collateralToken, position.reserveAmount);
            if (reserveDelta > 0) _increaseReservedAmount(position.collateralToken, reserveDelta);
            position.reserveAmount = reserveDelta;//position.reserveAmount.sub(reserveDelta);
        }
        updateRate(position.collateralToken);
        if (position.indexToken!= position.collateralToken) updateRate(position.indexToken); 
        
        uint256 price = position.isLong ? getMinPrice(position.indexToken) : getMaxPrice(position.indexToken);

        // _collectMarginFees runs inside _reduceCollateral
        (uint256 usdOut, uint256 usdOutAfterFee) = _reduceCollateral(key, _collateralDelta, _sizeDelta, price);
        
    
        // update position entry rate
        position.lastUpdateTime = block.timestamp;  //attention: MUST run after _collectMarginFees (_reduceCollateral)
        position.entryFundingRateSec = tradingFee[position.collateralToken].accumulativefundingRateSec;
        position.entryPremiumRateSec = position.isLong ? tradingFee[position.indexToken].accumulativeLongRateSec : tradingFee[position.indexToken].accumulativeShortRateSec;
        bool _del = false;
        // scrop variables to avoid stack too deep errors
        {
            //do not add spread price impact in decrease position
            emit DecreasePosition( key, position, _collateralDelta, _sizeDelta, price, int256(usdOut) - int256(usdOutAfterFee), usdOut, position.collateral, collateral);
            if (position.size != _sizeDelta) {
                // position.entryFundingRateSec = tradingFee[_collateralToken].accumulativefundingRateSec;
                position.size = position.size.sub(_sizeDelta);
                _validatePosition(position.size, position.collateral);
                vaultUtils.validateLiquidation(key,true);
                emit UpdatePosition(key, position.account, position.size, position.collateral, position.averagePrice, position.entryFundingRateSec,
                    position.reserveAmount, position.realisedPnl, price);
            } else {
                emit ClosePosition(key, position.account,
                    position.size, position.collateral,position.averagePrice, position.entryFundingRateSec.mul(3600).div(1000000), position.reserveAmount, position.realisedPnl);
                position.size = 0;
                _del = true;
            }
        }
        // update global trading size and average prie
        // _updateGlobalSize(position.isLong, position.indexToken, position.size, position.averagePrice, true);

        updateRate(position.collateralToken);
        if (position.indexToken!= position.collateralToken) updateRate(position.indexToken);

        if (usdOutAfterFee > 0) {
            uint256 tkOutAfterFee = 0;
            tkOutAfterFee = usdToTokenMin(position.collateralToken, usdOutAfterFee);
            emit DecreasePositionTransOut(key, tkOutAfterFee);
            _transferOut(position.collateralToken, tkOutAfterFee, _receiver);
            usdOutAfterFee = tkOutAfterFee;
        }
        if (_del) _delPosition(position.account, key);
        return usdOutAfterFee;
    }



    function liquidatePosition(address _account, address _collateralToken, address _indexToken, bool _isLong, address _feeReceiver) external override nonReentrant {
        vaultUtils.validLiq(msg.sender);
        // updateRate(_collateralToken);
        // if (_indexToken!= _collateralToken) updateRate(_indexToken);
        bytes32 key = vaultUtils.getPositionKey(_account, _collateralToken, _indexToken, _isLong, 0);

        VaultMSData.Position memory position = positions[key];
        _validate(position.size > 0, 35);

        (uint256 liquidationState, uint256 marginFees, int256 idxFee) = vaultUtils.validateLiquidation(key, false);
        _validate(liquidationState != 0, 36);
        if (liquidationState > 1) {
            // max leverage exceeded or max takingProfitLine reached
            _decreasePosition(key, 0, position.size, position.account);
            return;
        }

        {
            uint256 liqMarginFee = position.collateral;
            if (idxFee >= 0){
                liqMarginFee = liqMarginFee.add(uint256(idxFee));
            }else{
                liqMarginFee = liqMarginFee > uint256(-idxFee) ? liqMarginFee.sub(uint256(-idxFee)) : 0;
            }
            
            liqMarginFee = liqMarginFee > marginFees ? marginFees : 0;
            _collectFeeResv(_account, _collateralToken, liqMarginFee, usdToTokenMin(_collateralToken, liqMarginFee));
        }

        uint256 markPrice = _isLong ? getMinPrice(_indexToken)  : getMaxPrice(_indexToken);
        emit LiquidatePosition(key, _account,_collateralToken,_indexToken,_isLong,
            position.size, position.collateral, position.reserveAmount, position.realisedPnl, markPrice);

        // if (!_isLong && marginFees < position.collateral) {
        // if ( marginFees < position.collateral) {
        //     uint256 remainingCollateral = position.collateral.sub(marginFees);
        //     remainingCollateral = usdToTokenMin(_collateralToken, remainingCollateral);
        //     _increasePoolAmount(_collateralToken,  remainingCollateral);
        // }

        _decreaseReservedAmount(_collateralToken, position.reserveAmount);
        _updateGlobalSize(_isLong, _indexToken, position.size, position.averagePrice, false);
        _decreaseGuaranteedUsd(_collateralToken, position.collateral);
        _decreasePoolAmount(_collateralToken, usdToTokenMin(_collateralToken, vaultUtils.liquidationFeeUsd()));
        _transferOut(_collateralToken, usdToTokenMin(_collateralToken, vaultUtils.liquidationFeeUsd()), _feeReceiver);

        _delPosition(_account, key);

        updateRate(_collateralToken);
        if (_indexToken!= _collateralToken) updateRate(_indexToken);
        
    }
    
    //---------- PUBLIC FUNCTIONS ----------
    function directPoolDeposit(address _token) external override nonReentrant {
        _validate(fundingTokens.contains(_token), 14);
        uint256 tokenAmount = _transferIn(_token);
        _validate(tokenAmount > 0, 15);
        // _increasePoolAmount(_token, tokenAmount);
        emit DirectPoolDeposit(_token, tokenAmount);
    }
    function tradingTokenList() external view override returns (address[] memory) {
        return tradingTokens.valuesAt(0, tradingTokens.length());
    }
    function fundingTokenList() external view override returns (address[] memory) {
        return fundingTokens.valuesAt(0, fundingTokens.length());
    }
    // function claimableFeeReserves() external view override returns (uint256) {
    //     return feeReservesUSD.sub(feeReservesDiscountedUSD).sub(feeClaimedUSD);
    // }
    function getMaxPrice(address _token) public view override returns (uint256) {
        return IVaultPriceFeedV3Fast(priceFeed).getPrice(_token, true, false, false);
    }
    function getMinPrice(address _token) public view override returns (uint256) {
        return IVaultPriceFeedV3Fast(priceFeed).getPrice(_token, false, false, false);
    }

    function getRedemptionCollateral(address _token) public view returns (uint256) {
        if (tokenBase[_token].isStable) {
            return tokenBase[_token].poolAmount;
        }
        uint256 collateral = usdToTokenMin(_token, guaranteedUsd[_token]);
        return collateral.add(tokenBase[_token].poolAmount).sub(tokenBase[_token].reservedAmount);
    }
    function getRedemptionCollateralUsd(address _token) public view returns (uint256) {
        return tokenToUsdMin(_token, getRedemptionCollateral(_token));
    }

    function tokenToUsdMin(address _token, uint256 _tokenAmount) public view override returns (uint256) {
        uint256 price = getMinPrice(_token);
        return _tokenAmount.mul(price).div(10**IMintable(_token).decimals());
    }
    function usdToTokenMax(address _token, uint256 _usdAmount) public override view returns (uint256) {
        return _usdAmount > 0 ? usdToToken(_token, _usdAmount, getMinPrice(_token)) : 0;
    }
    function usdToTokenMin(address _token, uint256 _usdAmount) public override view returns (uint256) {
        return _usdAmount > 0 ? usdToToken(_token, _usdAmount, getMaxPrice(_token)) : 0;
    }
    function usdToToken( address _token, uint256 _usdAmount, uint256 _price ) public view returns (uint256) {
        // if (_usdAmount == 0)  return 0;
        uint256 decimals = IMintable(_token).decimals();
        require(decimals > 0, "invalid decimal");
        return _usdAmount.mul(10**decimals).div(_price);
    }

    function getPositionStructByKey(bytes32 _key) public override view returns (VaultMSData.Position memory){
        return positions[_key];
    }
    function getPositionStruct(address _account, address _collateralToken, address _indexToken, bool _isLong) public override view returns (VaultMSData.Position memory){
        return positions[vaultUtils.getPositionKey(_account, _collateralToken, _indexToken, _isLong, 0)];
    }
    function getTokenBase(address _token) public override view returns (VaultMSData.TokenBase memory){
        return tokenBase[_token];
    }
    function getTradingRec(address _token) public override view returns (VaultMSData.TradingRec memory){
        return tradingRec[_token];
    }
    function isFundingToken(address _token) public view override returns(bool){
        return fundingTokens.contains(_token);
    }
    function isTradingToken(address _token) public view override returns(bool){
        return tradingTokens.contains(_token);
    }
    function getTradingFee(address _token) public override view returns (VaultMSData.TradingFee memory){
        return tradingFee[_token];
    }
    function getUserKeys(address _account, uint256 _start, uint256 _end) external override view returns (bytes32[] memory){
        return IVaultStorage(vaultStorage).getUserKeys(_account, _start, _end);
    }
    function getKeys(uint256 _start, uint256 _end) external override view returns (bytes32[] memory){
        return IVaultStorage(vaultStorage).getKeys(_start, _end);
    }
    //---------- END OF PUBLIC VIEWS ----------




    //---------------------------------------- PRIVATE Functions --------------------------------------------------
    function updateRate(address _token) public override {
        _validate(tradingTokens.contains(_token) || fundingTokens.contains(_token), 7);
        tradingFee[_token] = vaultUtils.updateRate(_token);
    }

    function _swap(address _tokenIn,  address _tokenOut, address _receiver ) private returns (uint256) {
        _validate(fundingTokens.contains(_tokenIn), 24);
        _validate(fundingTokens.contains(_tokenOut), 25);
        _validate(_tokenIn != _tokenOut, 26);
        updateRate(_tokenIn);
        updateRate(_tokenOut);
        uint256 amountIn = _transferIn(_tokenIn);
        _validate(amountIn > 0, 27);
        _increasePoolAmount(_tokenIn, amountIn);
        uint256 _amountInUsd = tokenToUsdMin(_tokenIn, amountIn);
        uint256 _amountOut = usdToTokenMin(_tokenOut, _amountInUsd);
        uint256 feeBasisPoints = vaultUtils.getSwapFeeBasisPoints(_tokenIn, _tokenOut, _amountInUsd);
        uint256 _amountOutAfterFee = _collectSwapFees(_tokenOut, _amountOut, feeBasisPoints);
        _decreasePoolAmount(_tokenOut, _amountOut);
        _validatePRA(_tokenOut);
        _transferOut(_tokenOut, _amountOutAfterFee, _receiver);
        updateRate(_tokenIn);
        updateRate(_tokenOut);
        emit Swap( _receiver, _tokenIn, _tokenOut, amountIn, _amountOut, _amountOutAfterFee, feeBasisPoints);
        return _amountOutAfterFee;
    }


    function _reduceCollateral(bytes32 _key, uint256 _collateralDelta, uint256 _sizeDelta, uint256 /*_price*/) private returns (uint256, uint256) {
        VaultMSData.Position storage position = positions[_key];

        int256 fee = _collectMarginFees(_key, _sizeDelta);//collateral size updated in _collectMarginFees
        
        // scope variables to avoid stack too deep errors
        bool hasProfit;
        uint256 adjustedDelta;
        {
            (bool _hasProfit, uint256 delta) = vaultUtils.getDelta(position.indexToken, position.size, position.averagePrice, position.isLong, position.aveIncreaseTime, position.collateral);
            hasProfit = _hasProfit;
            adjustedDelta = _sizeDelta.mul(delta).div(position.size);// get the proportional change in pnl
        }

        //update Profit
        uint256 profitUsdOut = 0;
        // transfer profits out
        if (hasProfit && adjustedDelta > 0) {
            profitUsdOut = adjustedDelta;
            position.realisedPnl = position.realisedPnl + int256(adjustedDelta);
            
            uint256 usdTax = vaultUtils.calculateTax(profitUsdOut, position.aveIncreaseTime);
            // pay out realised profits from the pool amount for short positions
            // emit PayTax(position.account, _key, profitUsdOut, usdTax);
            profitUsdOut = profitUsdOut.sub(usdTax); 

            uint256 tokenAmount = usdToTokenMin(position.collateralToken, profitUsdOut);
            _decreasePoolAmount(position.collateralToken, tokenAmount);
            // _decreaseGuaranteedUsd(position.collateralToken, profitUsdOut);
        }
        else if (!hasProfit && adjustedDelta > 0) {
            position.collateral = position.collateral.sub(adjustedDelta);
            // uint256 tokenAmount = usdToTokenMin(position.collateralToken, adjustedDelta);
            // _increasePoolAmount(position.collateralToken, tokenAmount);
            _decreaseGuaranteedUsd(position.collateralToken, adjustedDelta);//decreaseGU = taking position profit by pool
            position.realisedPnl = position.realisedPnl - int256(adjustedDelta);
        }

        uint256 usdOutAfterFee = profitUsdOut;
        // reduce the position's collateral by _collateralDelta
        // transfer _collateralDelta out
        if (_collateralDelta > 0) {
            usdOutAfterFee = usdOutAfterFee.add(_collateralDelta);
            _validate(position.collateral >= _collateralDelta, 33);
            position.collateral = position.collateral.sub(_collateralDelta);
            _decreasePoolAmount(position.collateralToken, usdToTokenMin(position.collateralToken, _collateralDelta));
            _decreaseGuaranteedUsd(position.collateralToken, _collateralDelta); 
        }

        // if the position will be closed, then transfer the remaining collateral out
        if (position.size == _sizeDelta) {
            usdOutAfterFee = usdOutAfterFee.add(position.collateral);
            _decreasePoolAmount(position.collateralToken, usdToTokenMin(position.collateralToken, position.collateral));
            _decreaseGuaranteedUsd(position.collateralToken, position.collateral); 
            position.collateral = 0;
        }

        uint256 usdOut = fee > 0 ? usdOutAfterFee.add(uint256(fee)) :  usdOutAfterFee.sub(uint256(-fee));
        emit UpdatePnl(_key, hasProfit, adjustedDelta, position.size, position.collateral, usdOut, usdOutAfterFee);
        return (usdOut, usdOutAfterFee);
    }

    function _validatePosition(uint256 _size, uint256 _collateral) private view {
        if (_size == 0) {
            _validate(_collateral == 0, 39);
            return;
        }
        _validate(_size >= _collateral, 40);
    }
    
    function _collectSwapFees(address _token, uint256 _amount, uint256 _feeBasisPoints) private returns (uint256) {
        uint256 afterFeeAmount = _amount
            .mul(VaultMSData.COM_RATE_PRECISION.sub(_feeBasisPoints))
            .div(VaultMSData.COM_RATE_PRECISION);
        uint256 feeAmount = _amount.sub(afterFeeAmount);
        // feeReserves[_token] = feeReserves[_token].add(feeAmount);
        // feeReservesUSD = feeReservesUSD.add(_feeUSD);
        // uint256 _tIndex = block.timestamp.div(24 hours);
        // feeReservesRecord[_tIndex] = feeReservesRecord[_tIndex].add(_feeUSD);
        //transfer fee out 
        IERC20(_token).safeTransfer(feeRouter, feeAmount);
        IFeeRouter(feeRouter).pcFee(address(0), _token, feeAmount, 0);

        emit CollectSwapFees(_token, tokenToUsdMin(_token, feeAmount), feeAmount);
        return afterFeeAmount;
    }

    // function _collectMarginFees(address _account, address _collateralToken, address _indexToken,bool _isLong, uint256 _sizeDelta, uint256 _size, uint256 _entryFundingRate 
    function _collectMarginFees(bytes32 _key, uint256 _sizeDelta) private returns (int256) {
        VaultMSData.Position storage _position = positions[_key];
        int256 _premiumFee = vaultUtils.getPremiumFee(_position, tradingFee[_position.indexToken]);
        _position.accPremiumFee += _premiumFee;
        if (_premiumFee > 0){
            _validate(_position.collateral >= uint256(_premiumFee), 29);
            _increaseGuaranteedUsd(_position.collateralToken, uint256(_premiumFee));//increase -> aum ↑
            _position.collateral = _position.collateral.sub(uint256(_premiumFee));
        }else if (_premiumFee <0) {
            _decreaseGuaranteedUsd(_position.collateralToken, uint256(-_premiumFee));//decrease -> aum ↓
            _position.collateral = _position.collateral.add(uint256(-_premiumFee));
        }

        emit CollectPremiumFee(_position.account, _position.size, _position.entryPremiumRateSec, _premiumFee);

        uint256 feeUsd = vaultUtils.getPositionFee(_position, _sizeDelta,tradingFee[_position.indexToken]);
        _position.accPositionFee = _position.accPositionFee.add(feeUsd);
        uint256 fuFee = vaultUtils.getFundingFee(_position, tradingFee[_position.collateralToken]);
        _position.accFundingFee = _position.accFundingFee.add(fuFee);
        feeUsd = feeUsd.add(fuFee);
        uint256 feeTokens = usdToTokenMin(_position.collateralToken, feeUsd);
        _validate(_position.collateral >= feeUsd, 29);
        _position.collateral = _position.collateral.sub(feeUsd);
        
        //decrease pool into fee
        _decreaseGuaranteedUsd(_position.collateralToken, feeUsd);
        _decreasePoolAmount(_position.collateralToken, feeTokens);
        _collectFeeResv(_position.account, _position.collateralToken, feeUsd, feeTokens);


        emit CollectMarginFees(_position.collateralToken, feeUsd, feeTokens);
        return _premiumFee + int256(feeUsd);
    }

    function _collectFeeResv(address _account, address _collateralToken, uint256 _marginFees, uint256 _feeTokens) private {
        // feeReserves[_collateralToken] = feeReserves[_collateralToken].add(_feeTokens);
        // feeReservesUSD = feeReservesUSD.add(_marginFees);
        uint256 _discFee = _feeTokens.mul(psbt.updateFee(_account, _marginFees)).div(_marginFees);
        // feeReservesDiscountedUSD = feeReservesDiscountedUSD.add(_discFee);
        // uint256 _tIndex = block.timestamp.div(24 hours);
        // feeReservesRecord[_tIndex] = feeReservesRecord[_tIndex].add(_marginFees.sub(_discFee));
        IERC20(_collateralToken).safeTransfer(feeRouter,  _feeTokens.sub(_discFee));
        IFeeRouter(feeRouter).pcFee(_account, _collateralToken, _feeTokens, _feeTokens.sub(_discFee));
        emit CollectMarginFees(_collateralToken, _marginFees, _feeTokens);
    }


    function _transferIn(address _token) private returns (uint256) {
        uint256 prevBalance = tokenBase[_token].balance;
        uint256 nextBalance = IERC20(_token).balanceOf(address(this));
        tokenBase[_token].balance = nextBalance;
        return nextBalance.sub(prevBalance);
    }

    function _transferOut( address _token, uint256 _amount, address _receiver ) private {
        IERC20(_token).safeTransfer(_receiver, _amount);
        tokenBase[_token].balance = IERC20(_token).balanceOf(address(this));
    }

    function _increasePoolAmount(address _token, uint256 _amount) private {
        tokenBase[_token].poolAmount = tokenBase[_token].poolAmount.add(_amount);
        // uint256 balance = IERC20(_token).balanceOf(address(this));
        // _validate(tokenBase[_token].poolAmount <= balance, 49);
        emit IncreasePoolAmount(_token, _amount);
    }

    function _decreasePoolAmount(address _token, uint256 _amount) private {
        tokenBase[_token].poolAmount = tokenBase[_token].poolAmount.sub(_amount, "PoolAmount exceeded");
        _validatePRA(_token);
        emit DecreasePoolAmount(_token, _amount);
    }

    function _validatePRA(address _token) private view {
        _validate(tokenBase[_token].poolAmount >= tokenBase[_token].reservedAmount, 50);
    }

    function _increaseReservedAmount(address _token, uint256 _amount) private {
        _validate(_amount > 0, 53);
        tokenBase[_token].reservedAmount = tokenBase[_token].reservedAmount.add(_amount);
        _validate(tokenBase[_token].reservedAmount <= tokenBase[_token].poolAmount, 52);
        emit IncreaseReservedAmount(_token, _amount);
    }

    function _decreaseReservedAmount(address _token, uint256 _amount) private {
        tokenBase[_token].reservedAmount = tokenBase[_token].reservedAmount.sub( _amount, "Vault: insufficient reserve" );
        emit DecreaseReservedAmount(_token, _amount);
    }

    function _validate(bool _condition, uint256 _errorCode) private view {
        require(_condition, vaultUtils.errors(_errorCode));
    }

    function _updateGlobalSize(bool _isLong, address _indexToken, uint256 _sizeDelta, uint256 _price, bool _increase) private {
        VaultMSData.TradingRec storage ttREC = tradingRec[_indexToken];
        if (_isLong) {
            ttREC.longAveragePrice = vaultUtils.getNextAveragePrice(ttREC.longSize,  ttREC.longAveragePrice, _price, _sizeDelta, _increase);
            if (_increase){
                ttREC.longSize = ttREC.longSize.add(_sizeDelta);
                globalLongSize = globalLongSize.add(_sizeDelta);
            }else{
                ttREC.longSize = ttREC.longSize.sub(_sizeDelta);
                globalLongSize = globalLongSize.sub(_sizeDelta);
            }
            // emit UpdateGlobalSize(_indexToken, ttREC.longSize, globalLongSize,ttREC.longAveragePrice, _increase, _isLong );
        } else {
            ttREC.shortAveragePrice = vaultUtils.getNextAveragePrice(ttREC.shortSize,  ttREC.shortAveragePrice, _price, _sizeDelta, _increase);  
            if (_increase){
                ttREC.shortSize = ttREC.shortSize.add(_sizeDelta);
                globalShortSize = globalShortSize.add(_sizeDelta);
            }else{
                ttREC.shortSize = ttREC.shortSize.sub(_sizeDelta);
                globalShortSize = globalShortSize.sub(_sizeDelta);    
            }
            // emit UpdateGlobalSize(_indexToken, ttREC.shortSize, globalShortSize,ttREC.shortAveragePrice, _increase, _isLong );
        }
    }

    function _delPosition(address _account, bytes32 _key) private {
        delete positions[_key];
        IVaultStorage(vaultStorage).delKey(_account, _key);
    }

    function _increaseGuaranteedUsd(address _token, uint256 _usdAmount) private {
        guaranteedUsd[_token] = guaranteedUsd[_token].add(_usdAmount);
        emit IncreaseGuaranteedUsd(_token, _usdAmount);
    }

    function _decreaseGuaranteedUsd(address _token, uint256 _usdAmount)  private {
        guaranteedUsd[_token] = guaranteedUsd[_token] > _usdAmount ?guaranteedUsd[_token].sub(_usdAmount) : 0;
        emit DecreaseGuaranteedUsd(_token, _usdAmount);
    }
}

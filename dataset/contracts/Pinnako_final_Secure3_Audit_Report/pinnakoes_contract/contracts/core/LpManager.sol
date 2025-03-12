// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../utils/EnumerableValues.sol";
import "./VaultMSData.sol";
import "./interfaces/IVault.sol";
import "./interfaces/ILpManager.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../DID/interfaces/IPSBT.sol";


pragma solidity ^0.8.0;

contract LpManager is ReentrancyGuard, Ownable, ILpManager {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;

    address public weth;
    address public psbt;

    EnumerableSet.AddressSet lpTokens;
    mapping(address => address) lpVault;

    event AddLiquidity(address account,address token,uint256 amount, uint256 aumInUsdx, uint256 lpSupply, uint256 usdxAmount, uint256 mintAmount);
    event RemoveLiquidity(address account,address token,uint256 lpAmount, uint256 aumInUsdx,uint256 lpSupply,uint256 usdxAmount,uint256 amountOut);

    constructor(address _weth) {
        weth = _weth;
    }

    receive() external payable {
        require(msg.sender == weth, "invalid sender");
    }
    
    function withdrawToken(address _account, address _token, uint256 _amount) external onlyOwner{
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function setLP(address _lptoken, address _vault) external onlyOwner {
        if (!lpTokens.contains(_lptoken)) {
            lpTokens.add(_lptoken);
        }   
        lpVault[_lptoken] = _vault;
    }

    function delLP(address _lptoken) external onlyOwner {
        if (lpTokens.contains(_lptoken)) {
            lpTokens.remove(_lptoken);
        }   
        lpVault[_lptoken] = address(0);
    }


    function setPSBT(address _psbt) external onlyOwner {
        psbt = _psbt;
    }

    function addLiquidity(address _lp, address _token, uint256 _amount, uint256 _minlp) external override payable nonReentrant returns (uint256) {
        require(isLpToken(_lp), "[LpManager] Not supported lp token" );
        require(IVault(lpVault[_lp]).isFundingToken(_token), "[LpManager] not supported lp token");
        {
            address _fundToken = _token;
            uint256 _fundAmount = _amount;
            if (_token == address(0)){
                _fundToken = weth;
                _fundAmount = msg.value;
                IWETH(weth).deposit{value: msg.value}();
            }else{
                IERC20(_fundToken).safeTransferFrom(msg.sender, address(this), _fundAmount);
            }
            require(_fundAmount > 0, "[LpManager] invalid amount");
            IERC20(_fundToken).safeTransfer(lpVault[_lp], _fundAmount);
        }

        // calculate aum before buyUSD
        uint256 aumInUSD = getAumInUSD(_lp, true);
        uint256 lpSupply = IERC20(_lp).totalSupply();
        uint256 usdAmount = IVault(lpVault[_lp]).buyUSD(_token);
        uint256 mintAmount = aumInUSD == 0 ? usdAmount : usdAmount.mul(lpSupply).div(aumInUSD);
        require(mintAmount >= _minlp, "[LpManager] min output not satisfied");
        IMintable(_lp).mint(msg.sender, mintAmount);
        IPSBT(psbt).updateAddLiqScoreForAccount(msg.sender, lpVault[_lp], usdAmount.div(VaultMSData.USDX_DECIMALS).mul(VaultMSData.PRICE_PRECISION), 0);
        emit AddLiquidity(msg.sender, _token, _amount, aumInUSD, lpSupply, usdAmount, mintAmount); 
        return mintAmount;
    }


    function removeLiquidity(address _lp, uint256 _lpAmount, address _tokenOutOri, uint256 _minOut) external override payable nonReentrant returns (uint256) {
        require(isLpToken(_lp), "[LpManager] Not supported lp token" );
        require(_lpAmount > 0, "[LpManager]: invalid lp amount");
        address _tokenOut = _tokenOutOri==address(0) ? weth : _tokenOutOri;
        require(IVault(lpVault[_lp]).isFundingToken(_tokenOut), "[LpManager] not supported lp token");
        address _account = msg.sender;
        IERC20(_lp).safeTransferFrom(_account, address(this), _lpAmount );
        
        // calculate aum before sellUSD
        uint256 aumInUSD = getAumInUSD(_lp, false);
        uint256 lpSupply = IERC20(_lp).totalSupply();
        uint256 usdAmount = _lpAmount.mul(aumInUSD).div(lpSupply); //30b
        IMintable(_lp).burn(_lpAmount);
        uint256 amountOut = IVault(lpVault[_lp]).sellUSD(_tokenOut, address(this), usdAmount);
        require(amountOut >= _minOut, "LpManager: insufficient output");
        
        if (_tokenOutOri == address(0)){
            IWETH(weth).withdraw(amountOut);
            payable(_account).sendValue(amountOut);
        }else{
            IERC20(_tokenOut).safeTransfer(_account, amountOut);
        }

        IPSBT(psbt).updateAddLiqScoreForAccount(_account, lpVault[_lp], usdAmount.div(VaultMSData.USDX_DECIMALS).mul(VaultMSData.PRICE_PRECISION), 100);
        emit RemoveLiquidity(_account, _tokenOut, _lpAmount, aumInUSD, lpSupply, usdAmount, amountOut);
        return amountOut;
    }


    function getPoolInfo(address _lp) public view returns (uint256[] memory) {
        uint256[] memory poolInfo = new uint256[](4);
        if (isLpToken(_lp)){
            poolInfo[0] = getAum(_lp, true);
            poolInfo[1] = 0;//getAumSimple(true);
            poolInfo[2] = IERC20(_lp).totalSupply();
            poolInfo[3] = 0;
        }
        return poolInfo;
    }


    function getPoolTokenList(address _lp) public view returns (address[] memory) {
        require(isLpToken(_lp), "[LpManager] Not supported lp token");
        return IVault(lpVault[_lp]).fundingTokenList();
    }

    function getAumInUSD(address _lp, bool _maximise) public view returns (uint256) {
        uint256 aum = getAum(_lp, _maximise);
        return aum.mul(VaultMSData.USDX_DECIMALS).div(VaultMSData.PRICE_PRECISION);
    }


    function getAum(address _lp, bool _maximise) public view returns (uint256) {
        require(isLpToken(_lp), "[LpManager] Not supported lp token");
        IVault vault = IVault(lpVault[_lp]);
        address[] memory fundingTokenList = vault.fundingTokenList();
        address[] memory tradingTokenList = vault.tradingTokenList();
        uint256 aum = 0;
        uint256 userShortProfits = 0;
        uint256 userLongProfits = 0;

        for (uint256 i = 0; i < fundingTokenList.length; i++) {
            address token = fundingTokenList[i];
            uint256 price = _maximise ? vault.getMaxPrice(token) : vault.getMinPrice(token);
            VaultMSData.TokenBase memory tBae = vault.getTokenBase(token);
            uint256 poolAmount = tBae.poolAmount;
            uint256 decimals = IMintable(token).decimals();
            poolAmount = poolAmount.mul(price).div(10 ** decimals);
            poolAmount = poolAmount > vault.guaranteedUsd(token) ? poolAmount.sub(vault.guaranteedUsd(token)) : 0;
            aum = aum.add(poolAmount);
        }

        for (uint256 i = 0; i < tradingTokenList.length; i++) {
            address token = tradingTokenList[i];
            VaultMSData.TradingRec memory tradingRec = vault.getTradingRec(token);

            uint256 price = _maximise ? vault.getMaxPrice(token) : vault.getMinPrice(token);
            uint256 shortSize = tradingRec.shortSize;
            if (shortSize > 0){
                uint256 averagePrice = tradingRec.shortAveragePrice;
                uint256 priceDelta = averagePrice > price ? averagePrice.sub(price) : price.sub(averagePrice);
                uint256 delta = shortSize.mul(priceDelta).div(averagePrice);
                if (price > averagePrice) {
                    aum = aum.add(delta);
                } else {
                    userShortProfits = userShortProfits.add(delta);
                }    
            }

            uint256 longSize = tradingRec.longSize;
            if (longSize > 0){
                uint256 averagePrice = tradingRec.longAveragePrice;
                uint256 priceDelta = averagePrice > price ? averagePrice.sub(price) : price.sub(averagePrice);
                uint256 delta = longSize.mul(priceDelta).div(averagePrice);
                if (price < averagePrice) {
                    aum = aum.add(delta);
                } else {
                    userLongProfits = userLongProfits.add(delta);
                }    
            }
        }

        uint256 _totalUserProfits = userLongProfits.add(userShortProfits);
        aum = _totalUserProfits > aum ? 0 : aum.sub(_totalUserProfits);
        return aum;  
    }


    function getLpTokenList() external view returns (address[] memory){
        return lpTokens.valuesAt(0, lpTokens.length());
    }

    function isLpToken(address _token) public view  returns(bool){
        return lpTokens.contains(_token);
    }
}


// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../tokens/interfaces/IWETH.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRouter.sol";
import "../DID/interfaces/IPSBT.sol";
import "../tokens/interfaces/IMintable.sol";


contract Router is IRouter, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public weth;
    address public vault;
    address public PSBT;
    bool public validateContract = true;
    bool public isSwapOpenForPublic = true;

    uint256 public maxSwapAmountPerDay;

    mapping (address => bool) public plugins;
    mapping (address => mapping (address => bool)) public approvedPlugins;
    mapping (address => uint256) public swapMaxRatio;
    mapping (uint256 => uint256) public swapDailyRecord;


    event Swap(address account, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);


    constructor(address _vault, address _weth) {
        vault = _vault;
        weth = _weth;
    }

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }
    
    function setPSBT(address _psbt) external onlyOwner {
        PSBT = _psbt;
    }

    function setIsSwapOpenForPublic(bool status) external onlyOwner{
        isSwapOpenForPublic = status;
    }

    function setMaxSwapRatio(address _token, uint256 _ratio) external onlyOwner{
        swapMaxRatio[_token] = _ratio;
    }
    function setMaxSwapAmountPerDay(uint256 _amount) external onlyOwner{
        maxSwapAmountPerDay = _amount;
    }

    function setValidateContract(bool _valid) external onlyOwner {
        validateContract = _valid;
    }

    function addPlugin(address _plugin) external override onlyOwner {
        plugins[_plugin] = true;
    }

    function removePlugin(address _plugin) external onlyOwner {
        plugins[_plugin] = false;
    }

    function withdrawToken(
        address _account,
        address _token,
        uint256 _amount
    ) external onlyOwner{
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function approvePlugin(address _plugin) external override {
        approvedPlugins[msg.sender][_plugin] = true;
    }

    function denyPlugin(address _plugin) external {
        approvedPlugins[msg.sender][_plugin] = false;
    }

    function pluginTransfer(address _token, address _account, address _receiver, uint256 _amount) external override {
        _validatePlugin(_account);
        require(IVault(vault).isFundingToken(_token), "invalid token");
        IERC20(_token).safeTransferFrom(_account, _receiver, _amount);
    }

    function pluginIncreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external override {
        _validatePlugin(_account);
        IVault(vault).increasePosition(_account, _collateralToken, _indexToken, _sizeDelta, _isLong);
        IPSBT(PSBT).updateTradingScoreForAccount(_account, vault, _sizeDelta, 0);   
    }

    function pluginDecreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external override returns (uint256) {
        _validatePlugin(_account);
        IPSBT(PSBT).updateTradingScoreForAccount(_account, vault, _sizeDelta, 100);   
        return IVault(vault).decreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
    }

    function directPoolDeposit(address _token, uint256 _amount) external {
        IERC20(_token).safeTransferFrom(_sender(), vault, _amount);
        IVault(vault).directPoolDeposit(_token);
    }


    function validSwap(address _token, uint256 _amount) public view returns(bool){
        require(IVault(vault).isFundingToken(_token), "not funding token");
        if (swapMaxRatio[_token] == 0) return true;
        
        address[] memory fundingTokenList = IVault(vault).fundingTokenList();
        uint256 aum = 0;
        uint256 token_mt = 0;
        for (uint256 i = 0; i < fundingTokenList.length; i++) {
            address token = fundingTokenList[i];
            uint256 price =  IVault(vault).getMaxPrice(token);
            VaultMSData.TokenBase memory tBae = IVault(vault).getTokenBase(token);
            uint256 poolAmount = tBae.poolAmount;
            uint256 decimals = IMintable(token).decimals();
            poolAmount = poolAmount.mul(price).div(10 ** decimals);
            if (token == _token){
                uint256 addAmount = _amount.mul(price).div(10 ** decimals);
                if (maxSwapAmountPerDay > 0 && swapDailyRecord[block.timestamp/3600].add(addAmount) > maxSwapAmountPerDay){
                    return false;
                }
                token_mt = token_mt.add(poolAmount).add(addAmount);
            }
            poolAmount = poolAmount > IVault(vault).guaranteedUsd(token) ? poolAmount.sub(IVault(vault).guaranteedUsd(token)) : 0;
            aum = aum.add(poolAmount);
        }
        if (aum == 0) return true;
        return token_mt.mul(1000).div(aum) < swapMaxRatio[_token];
    }





    function swap(address[] memory _path, uint256 _amountIn, uint256 _minOut, address _receiver) public override {
        require(isSwapOpenForPublic, "swap is not open");
        require(validSwap(_path[0], _amountIn), "Swap limit reached.");
        IERC20(_path[0]).safeTransferFrom(_sender(), vault, _amountIn);
        uint256 amountOut = _swap(_path, _minOut, _receiver);
        uint256 price =  IVault(vault).getMaxPrice(_path[0]);
        uint256 decimals = IMintable(_path[0]).decimals();
        swapDailyRecord[block.timestamp/3600] = swapDailyRecord[block.timestamp/3600].add(_amountIn.mul(price).div(10 ** decimals));

        emit Swap(msg.sender, _path[0], _path[_path.length - 1], _amountIn, amountOut);
    }

    function swapETHToTokens(address[] memory _path, uint256 _minOut, address _receiver) external payable {
        require(isSwapOpenForPublic, "swap is not open");
        require(_path[0] == weth, "Router: invalid _path");
        require(validSwap(_path[0], msg.value), "Swap limit reached.");
        uint256 price =  IVault(vault).getMaxPrice(_path[0]);
        uint256 decimals = IMintable(_path[0]).decimals();
        swapDailyRecord[block.timestamp/3600] = swapDailyRecord[block.timestamp/3600].add(msg.value.mul(price).div(10 ** decimals));

        _transferETHToVault();
        uint256 amountOut = _swap(_path, _minOut, _receiver);
        emit Swap(msg.sender, _path[0], _path[_path.length - 1], msg.value, amountOut);
    }

    function swapTokensToETH(address[] memory _path, uint256 _amountIn, uint256 _minOut, address payable _receiver) external {
        require(isSwapOpenForPublic, "swap is not open");
        require(validSwap(_path[0], _amountIn), "Swap limit reached.");
        require(_path[_path.length - 1] == weth, "Router: invalid _path");
        uint256 price =  IVault(vault).getMaxPrice(_path[0]);
        uint256 decimals = IMintable(_path[0]).decimals();
        swapDailyRecord[block.timestamp/3600] = swapDailyRecord[block.timestamp/3600].add(_amountIn.mul(price).div(10 ** decimals));
        IERC20(_path[0]).safeTransferFrom(_sender(), vault, _amountIn);
        uint256 amountOut = _swap(_path, _minOut, address(this));
        _transferOutETH(amountOut, _receiver);
        emit Swap(msg.sender, _path[0], _path[_path.length - 1], _amountIn, amountOut);
    }

    function increasePosition(address[] memory _path, address _indexToken, uint256 _amountIn, uint256 _minOut, uint256 _sizeDelta, bool _isLong, uint256 _price) external {
        if (_amountIn > 0) {
            IERC20(_path[0]).safeTransferFrom(_sender(), vault, _amountIn);
        }
        if (_path.length > 1 && _amountIn > 0) {
            uint256 amountOut = _swap(_path, _minOut, address(this));
            IERC20(_path[_path.length - 1]).safeTransfer(vault, amountOut);
        }
        _increasePosition(_path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function increasePositionETH(address[] memory _path, address _indexToken, uint256 _minOut, uint256 _sizeDelta, bool _isLong, uint256 _price) external payable {
        require(_path[0] == weth, "Router: invalid _path");
        if (msg.value > 0) {
            _transferETHToVault();
        }
        if (_path.length > 1 && msg.value > 0) {
            uint256 amountOut = _swap(_path, _minOut, address(this));
            IERC20(_path[_path.length - 1]).safeTransfer(vault, amountOut);
        }
        _increasePosition(_path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function decreasePosition(address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price) external {
        _decreasePosition(_collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver, _price);
    }

    function decreasePositionETH(address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address payable _receiver, uint256 _price) external {
        uint256 amountOut = _decreasePosition(_collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        _transferOutETH(amountOut, _receiver);
    }

    function decreasePositionAndSwap(address[] memory _path, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price, uint256 _minOut) external {
        uint256 amount = _decreasePosition(_path[0], _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        IERC20(_path[0]).safeTransfer(vault, amount);
        _swap(_path, _minOut, _receiver);
    }

    function decreasePositionAndSwapETH(address[] memory _path, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address payable _receiver, uint256 _price, uint256 _minOut) external {
        require(_path[_path.length - 1] == weth, "Router: invalid _path");
        uint256 amount = _decreasePosition(_path[0], _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        // require(amount > 0, "zero amount Out");
        IERC20(_path[0]).safeTransfer(vault, amount);
        uint256 amountOut = _swap(_path, _minOut, address(this));
        _transferOutETH(amountOut, _receiver);
    }

    function _increasePosition(address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _price) private {
        if (_isLong) {
            require(IVault(vault).getMaxPrice(_indexToken) <= _price, "Router: mark price higher than limit");
        } else {
            require(IVault(vault).getMinPrice(_indexToken) >= _price, "Router: mark price lower than limit");
        }
        address tradeAccount = _sender();
        IVault(vault).increasePosition(tradeAccount, _collateralToken, _indexToken, _sizeDelta, _isLong);
        IPSBT(PSBT).updateTradingScoreForAccount(tradeAccount, vault, _sizeDelta, 0);
    }

    function _decreasePosition(address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price) private returns (uint256) {
        if (_isLong) {
            require(IVault(vault).getMinPrice(_indexToken) >= _price, "Router: mark price lower than limit");
        } else {
            require(IVault(vault).getMaxPrice(_indexToken) <= _price, "Router: mark price higher than limit");
        }

        IPSBT(PSBT).updateTradingScoreForAccount(_receiver, vault, _sizeDelta, 100);
        return IVault(vault).decreasePosition(_sender(), _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
    }

    function _transferETHToVault() private {
        IWETH(weth).deposit{value: msg.value}();
        IERC20(weth).safeTransfer(vault, msg.value);
    }

    function _transferOutETH(uint256 _amountOut, address payable _receiver) private {
        IWETH(weth).withdraw(_amountOut);
        _receiver.sendValue(_amountOut);
    }

    function _swap(address[] memory _path, uint256 _minOut, address _receiver) private returns (uint256) {
        if (_path.length == 2) {
            return _vaultSwap(_path[0], _path[1], _minOut, _receiver);
        }
        if (_path.length == 3) {
            uint256 midOut = _vaultSwap(_path[0], _path[1], 0, address(this));
            IERC20(_path[1]).safeTransfer(vault, midOut);
            return _vaultSwap(_path[1], _path[2], _minOut, _receiver);
        }

        revert("Router: invalid _path.length");
    }

    function _vaultSwap(address _tokenIn, address _tokenOut, uint256 _minOut, address _receiver) private returns (uint256) {
        uint256 amountOut;
        amountOut = IVault(vault).swap(_tokenIn, _tokenOut, _receiver);
        require(amountOut >= _minOut, "Router: amountOut not satisfied.");

        uint256 _priceOut = IVault(vault).getMinPrice(_tokenOut);
        uint256 _decimals = IMintable(_tokenOut).decimals();
        uint256 _sizeDelta = amountOut.mul(_priceOut).div(10 ** _decimals);
        IPSBT(PSBT).updateSwapScoreForAccount(_receiver, vault, _sizeDelta);
        return amountOut;
    }

    function _sender() private view returns (address) {
        return msg.sender;
    }

    function _validatePlugin(address _account) private view {
        require(plugins[msg.sender], "Router: invalid plugin");
        require(approvedPlugins[_account][msg.sender], "Router: plugin not approved");
    }


    function isContract(address addr) private view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

}

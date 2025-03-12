// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../oracle/interfaces/IServerPriceFeed.sol";
import "../tokens/interfaces/IWETH.sol";
import "./interfaces/IVault.sol";
import "../DID/interfaces/IPSBT.sol";
import "../tokens/interfaces/IMintable.sol";

contract RouterSign is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public weth;
    address public vault;
    address public PSBT;
    address public priceFeed;
    bool public freeTrade = true;

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }
    
    function setFreeTrade(bool _isOpen) external onlyOwner{
        freeTrade = _isOpen;
    }

    function initialize(address _vault, address _weth, address _priceFeed, address _psbt) external onlyOwner {
        vault = _vault;
        weth = _weth;
        priceFeed = _priceFeed;
        PSBT = _psbt;
    }

    function setPSBT(address _psbt) external onlyOwner {
        PSBT = _psbt;
    }

    function setPriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
    }

    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    function withdrawToken(
        address _account,
        address _token,
        uint256 _amount
    ) external onlyOwner{
        IERC20(_token).safeTransfer(_account, _amount);
    }
    
    function sendValue(address payable _receiver, uint256 _amount) external onlyOwner {
        _receiver.sendValue(_amount);
    }

    function increasePosition(address[] memory _path, address _indexToken, uint256 _amountIn, uint256 _sizeDelta, bool _isLong, uint256 _price,
            uint256[] memory , uint256 ,  address, bytes memory ) external payable nonReentrant{
        require(freeTrade, "FreeTrade Not Open");
        if (_amountIn > 0) {
            IERC20(_path[0]).safeTransferFrom(_sender(), vault, _amountIn);
        }
        if (_path.length > 1 && _amountIn > 0) {
            uint256 amountOut = _swap(_path, 0, address(this));
            IERC20(_path[_path.length - 1]).safeTransfer(vault, amountOut);
        }
        _increasePosition(_path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function increasePositionETH(address[] memory _path, address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _price,
                uint256[] memory , uint256 ,  address , bytes memory ) external payable nonReentrant{
        require(_path[0] == weth, "Router: invalid _path");
        require(freeTrade, "FreeTrade Not Open");
        if (msg.value > 0) {
            _transferETHToVault();
        }
        if (_path.length > 1 && msg.value > 0) {
            uint256 amountOut = _swap(_path, 0, address(this));
            IERC20(_path[_path.length - 1]).safeTransfer(vault, amountOut);
        }
        _increasePosition(_path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function decreasePosition(address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price,
                uint256[] memory , uint256 ,  address , bytes memory ) external payable nonReentrant  {
        require(freeTrade, "FreeTrade Not Open");
        _decreasePosition(_collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver, _price);
    }

    function decreasePositionETH(address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address payable _receiver, uint256 _price,
                uint256[] memory , uint256 ,  address , bytes memory ) external payable nonReentrant {
        uint256 amountOut = _decreasePosition(_collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        require(freeTrade, "FreeTrade Not Open");
        _transferOutETH(amountOut, _receiver);
    }

    function decreasePositionAndSwap(address[] memory _path, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price, uint256 _minOut,
                uint256[] memory , uint256 ,  address , bytes memory ) external payable nonReentrant {
        require(freeTrade, "FreeTrade Not Open");
        uint256 amount = _decreasePosition(_path[0], _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        IERC20(_path[0]).safeTransfer(vault, amount);
        _swap(_path, _minOut, _receiver);
    }

    function decreasePositionAndSwapETH(address[] memory _path, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address payable _receiver, uint256 _price, uint256 _minOut,
                uint256[] memory , uint256 ,  address , bytes memory ) external payable nonReentrant {
        require(_path[_path.length - 1] == weth, "Router: invalid _path");
        require(freeTrade, "FreeTrade Not Open");
        uint256 amount = _decreasePosition(_path[0], _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        // require(amount > 0, "zero amount Out");
        IERC20(_path[0]).safeTransfer(vault, amount);
        uint256 amountOut = _swap(_path, _minOut, address(this));
        _transferOutETH(amountOut, _receiver);
    }



    function increasePositionAndUpdate(address[] memory _path, address _indexToken, uint256 _amountIn, uint256 _sizeDelta, bool _isLong, uint256 _price,
            uint256[] memory _paras, uint256 _priceTimestamp,  address _updater, bytes memory _updaterSignedMsg) external payable nonReentrant{
        IServerPriceFeed(priceFeed).updateTokenInfo(_updater, _indexToken, _paras, _priceTimestamp, _updaterSignedMsg);
        if (_amountIn > 0) {
            IERC20(_path[0]).safeTransferFrom(_sender(), vault, _amountIn);
        }
        if (_path.length > 1 && _amountIn > 0) {
            uint256 amountOut = _swap(_path, 0, address(this));
            IERC20(_path[_path.length - 1]).safeTransfer(vault, amountOut);
        }
        _increasePosition(_path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function increasePositionETHAndUpdate(address[] memory _path, address _indexToken, uint256 _sizeDelta, bool _isLong, uint256 _price,
                uint256[] memory _paras, uint256 _priceTimestamp,  address _updater, bytes memory _updaterSignedMsg) external payable nonReentrant{
        IServerPriceFeed(priceFeed).updateTokenInfo(_updater, _indexToken, _paras, _priceTimestamp, _updaterSignedMsg);
        require(_path[0] == weth, "Router: invalid _path");
        if (msg.value > 0) {
            _transferETHToVault();
        }
        if (_path.length > 1 && msg.value > 0) {
            uint256 amountOut = _swap(_path, 0, address(this));
            IERC20(_path[_path.length - 1]).safeTransfer(vault, amountOut);
        }
        _increasePosition(_path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function decreasePositionAndUpdate(address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price,
                uint256[] memory _paras, uint256 _priceTimestamp,  address _updater, bytes memory _updaterSignedMsg) external payable nonReentrant  {
        IServerPriceFeed(priceFeed).updateTokenInfo(_updater, _indexToken, _paras, _priceTimestamp, _updaterSignedMsg);
        _decreasePosition(_collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver, _price);
    }

    function decreasePositionETHAndUpdate(address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address payable _receiver, uint256 _price,
                uint256[] memory _paras, uint256 _priceTimestamp,  address _updater, bytes memory _updaterSignedMsg) external payable nonReentrant {
        IServerPriceFeed(priceFeed).updateTokenInfo(_updater, _indexToken, _paras, _priceTimestamp, _updaterSignedMsg);
        uint256 amountOut = _decreasePosition(_collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        _transferOutETH(amountOut, _receiver);
    }

    function decreasePositionAndSwapUpdate(address[] memory _path, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver, uint256 _price, uint256 _minOut,
                uint256[] memory _paras, uint256 _priceTimestamp,  address _updater, bytes memory _updaterSignedMsg) external payable nonReentrant {
        IServerPriceFeed(priceFeed).updateTokenInfo(_updater, _indexToken, _paras, _priceTimestamp, _updaterSignedMsg);
        uint256 amount = _decreasePosition(_path[0], _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        IERC20(_path[0]).safeTransfer(vault, amount);
        _swap(_path, _minOut, _receiver);
    }

    function decreasePositionAndSwapETHUpdate(address[] memory _path, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address payable _receiver, uint256 _price, uint256 _minOut,
                uint256[] memory _paras, uint256 _priceTimestamp,  address _updater, bytes memory _updaterSignedMsg) external payable nonReentrant {
        IServerPriceFeed(priceFeed).updateTokenInfo(_updater, _indexToken, _paras, _priceTimestamp, _updaterSignedMsg);
        require(_path[_path.length - 1] == weth, "Router: invalid _path");
        uint256 amount = _decreasePosition(_path[0], _indexToken, _collateralDelta, _sizeDelta, _isLong, address(this), _price);
        // require(amount > 0, "zero amount Out");
        IERC20(_path[0]).safeTransfer(vault, amount);
        uint256 amountOut = _swap(_path, _minOut, address(this));
        _transferOutETH(amountOut, _receiver);
    }



    //------------------------------ Private Functions ------------------------------
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
        address tradeAccount = _sender();
        IPSBT(PSBT).updateTradingScoreForAccount(tradeAccount, vault, _sizeDelta, 100);
        return IVault(vault).decreasePosition(tradeAccount, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
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


}

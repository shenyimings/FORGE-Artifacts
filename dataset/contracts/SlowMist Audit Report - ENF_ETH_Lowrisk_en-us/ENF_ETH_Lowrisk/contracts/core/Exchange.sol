// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/IRouter.sol";
import "../utils/TransferHelper.sol";

contract Exchange is IExchange, OwnableUpgradeable {
    using SafeMath for uint256;

    string public constant version = "3.0";

    mapping(address => bool) public routerListed;

    mapping(address => bool) public swapCaller;

    address public weth;

    event RouterListed(address router);

    event RouterDelisted(address router);

    event SetSwapCaller(address caller, bool status);

    function initialize(address _weth, address _controller) public initializer {
        __Ownable_init();
        swapCaller[_controller] = true;
        weth = _weth;
    }

    receive() external payable {}

    /**
        Only registered callner can call
     */
    modifier onlyCaller() {
        require(swapCaller[_msgSender()], "ONLY_SWAP_CALLER");
        _;
    }

    function setSwapCaller(address _caller, bool _status) public onlyOwner {
        require(_caller != address(0), "INVALID_ADDRESS");

        swapCaller[_caller] = _status;

        emit SetSwapCaller(_caller, _status);
    }

    /**
        Swap Token Exact Input
     */
    function swapExactTokenInput(
        address _from,
        address _to,
        address _router,
        bytes32 _index,
        uint256 _amount
    ) external override onlyCaller returns (uint256) {
        // Only Listed router can be used
        require(routerListed[_router], "ONLY_LISTED_ROUTER");

        // Transfer token from caller
        TransferHelper.safeTransferFrom(_from, _msgSender(), address(_router), _amount);

        // Swap token using uniswap/sushiswap
        IRouter(_router).swap(_from, _to, _index, _amount);

        // Get Swapped output amount
        uint256 outAmt = getBalance(_to, address(this));

        // Transfer to Controller
        if (_to == weth) TransferHelper.safeTransferETH(_msgSender(), outAmt);
        else TransferHelper.safeTransfer(_to, _msgSender(), outAmt);

        return outAmt;
    }

    /**
        Swap ETH Exact Input
     */
    function swapExactETHInput(
        address _to,
        address _router,
        bytes32 _index,
        uint256 _amount
    ) external payable override onlyCaller returns (uint256) {
        // Only Listed router can be used
        require(routerListed[_router], "ONLY_LISTED_ROUTER");

        require(msg.value >= _amount, "INSUFFICIENT_TRANSFER");
        // Transfer ETH to router
        TransferHelper.safeTransferETH(_router, _amount);

        // Swap token using uniswap/sushiswap
        IRouter(_router).swap(weth, _to, _index, _amount);

        // Get Swapped output amount
        uint256 outAmt = getBalance(_to, address(this));

        console.log("Ex: ", outAmt);
        // Transfer to caller
        TransferHelper.safeTransfer(_to, _msgSender(), outAmt);

        return outAmt;
    }

    function getBalance(address asset, address account) internal view returns (uint256) {
        if (address(asset) == address(weth)) return address(account).balance;
        else return IERC20Upgradeable(asset).balanceOf(account);
    }

    /**
        SET CONFIGURATION
     */
    function listRouter(address router) public onlyOwner {
        routerListed[router] = true;

        emit RouterListed(router);
    }

    function delistRouter(address router) public onlyOwner {
        routerListed[router] = false;

        emit RouterDelisted(router);
    }
}

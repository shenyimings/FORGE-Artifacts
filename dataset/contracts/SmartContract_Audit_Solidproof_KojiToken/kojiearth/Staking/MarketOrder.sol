// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IAuthorized {
    function isAuthorized(address _address) external view returns (bool);
}

contract MarketOrder is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier onlyAuthorized() {
        require(auth.isAuthorized(_msgSender()) || owner() == address(_msgSender()), "Staking not Authorized to MarketOrder");
        _;
    }

    IDEXRouter public router;
    address public WETH;
    uint24 marketBuyGas = 450000;  
    IAuthorized public auth;

     constructor(address _router, address _auth) {

        auth = IAuthorized(_auth);

        router = _router != address(0)
            ? IDEXRouter(_router)
            : IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); //0xCc7aDc94F3D80127849D2b41b6439b7CF1eB4Ae0 pcs test router
        WETH = router.WETH();

    }

    receive() external payable {}

    function marketBuy(address _token, address _recipient) external payable onlyAuthorized nonReentrant returns (uint) {

        payable(this).transfer(msg.value);

        IERC20 token = IERC20(_token); //token to buy

        uint amountpurchased;
        uint balanceBefore = IERC20(token).balanceOf(_recipient); //get prior balance of recipient

        address[] memory path = new address[](2);

        path[0] = WETH;
        path[1] = _token;

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value:msg.value, gas:marketBuyGas}(
            0,
            path,
            address(_recipient),
            block.timestamp
        );

        uint balanceNow = IERC20(_token).balanceOf(_recipient);
      
        amountpurchased += balanceNow.sub(balanceBefore);

        return (amountpurchased);
    }

     function changeMarketBuyGas(uint24 _gas) external onlyAuthorized {
        marketBuyGas = _gas;
    }

        // This will allow to rescue ETH sent to the contract
    function rescueETHFromContract() external onlyAuthorized {
        address payable _owner = payable(_msgSender());
        _owner.transfer(address(this).balance);
    }

    // Function to allow admin to claim *other* ERC20 tokens sent to this contract (by mistake)
    function transferERC20Tokens(address _tokenAddr, address _to, uint _amount) public onlyAuthorized {
        IERC20(_tokenAddr).transfer(_to, _amount);
    }

}

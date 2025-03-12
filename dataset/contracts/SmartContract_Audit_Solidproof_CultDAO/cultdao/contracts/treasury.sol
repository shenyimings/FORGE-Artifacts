// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function WETH() external pure returns (address);

    function factory() external pure returns (address);
}

interface IGovernance {
    function _fundInvestee() external returns(address);
    function nextInvesteeFund() external pure returns(uint256);
    function nextInvestee() external pure returns(uint256);
}

contract Treasury is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public cult;
    address public dao;
    address public router;
    uint256 public totalETH;

    address[] private path;
    function initialize(        
        address _cult,
        address _router
        ) public initializer {
        require(_cult != address(0),"initialize: Invalid address");
        require(_router != address(0),"initialize: Invalid address");
        cult = _cult;
        router = _router;
        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        __Context_init_unchained();
        __Pausable_init_unchained();
        path.push(IUniswapV2Router(router).WETH());
        path.push(cult);
        totalETH = 1 ether;
    }

    function _authorizeUpgrade(address) internal view override {
        require(owner() == msg.sender, "Only owner can upgrade implementation");
    }

    function setDAOAddress(address _dao) external onlyOwner{
        require(_dao != address(0),"setDAOAddress: Invalid address");
        dao = _dao;
    }

    function validatePayout() external{
        uint256 balance = IERC20Upgradeable(cult).balanceOf(address(this));
        uint256[] memory getCultAmountOneETH = IUniswapV2Router(router).getAmountsOut(totalETH, path);
        uint256 totalAmount = getCultAmountOneETH[1].mul(155).div(10);
        if(balance >= totalAmount && IGovernance(dao).nextInvesteeFund()<IGovernance(dao).nextInvestee()){
            fundInvestee(totalAmount,getCultAmountOneETH[1].mul(25).div(10));
        }
    }

    function fundInvestee(uint256 totalAmount,uint burnAmount) internal nonReentrant{
        address investee = IGovernance(dao)._fundInvestee();
        IERC20Upgradeable(cult).transfer(DEAD_ADDRESS,burnAmount);
        IERC20Upgradeable(cult).transfer(investee,totalAmount.sub(burnAmount));
    }

}
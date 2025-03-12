/**

1 If (price > 1000x) 100% to sale
2 else if (LD > $100K) 50% to sale
3 else if (LD > $10K) 25% to sale
4 else 0% to sale
*/

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract SplitFormula is Ownable {
  using SafeMath for uint256;

  IUniswapV2Router02 public Router;
  address public token;
  address public poolPair;
  address public weth;
  address public DAI;

  uint256 public maxPrice;
  uint256 public minLDAmountInDAI;
  uint256 public maxLDAmountInDAI;

  constructor(
    uint256 _initialRate,
    uint256 _minLDAmountInDAI,
    uint256 _maxLDAmountInDAI,
    address _dexRouter,
    address _poolPair,
    address _token,
    address _DAI
  )
    public
  {
    maxPrice = _initialRate.mul(1000);
    minLDAmountInDAI = _minLDAmountInDAI;
    maxLDAmountInDAI = _maxLDAmountInDAI;
    Router = IUniswapV2Router02(_dexRouter);
    poolPair = _poolPair;
    token = _token;
    weth = Router.WETH();
    DAI = _DAI;
  }

  function calculateToSplit(uint256 ethInput)
    public
    view
    returns(uint256 ethPercentTodex, uint256 ethPercentToSale)
  {
    if(getCurrentPrice() >= maxPrice){
      ethPercentTodex = 0;
      ethPercentToSale = 100;
    }
    else{
     (ethPercentTodex, ethPercentToSale) = calculatePercentToSplit(ethInput);
    }
  }


  function calculatePercentToSplit(uint256 ethInput)
    public
    view
    returns(uint256 ethPercentTodex, uint256 ethPercentToSale)
  {
    uint256 LDAmount = getLDAmountInDAI();

    if(LDAmount >= maxLDAmountInDAI){
      ethPercentTodex = 50;
      ethPercentToSale = 50;
    }
    else if(LDAmount >= minLDAmountInDAI){
      ethPercentTodex = 75;
      ethPercentToSale = 25;
    }
    else{
      ethPercentTodex = 100;
      ethPercentToSale = 0;
    }
  }

  function getLDAmountInDAI() public view returns(uint256){
    uint256 wethBalance = IERC20(weth).balanceOf(poolPair);
    address[] memory path = new address[](2);
    path[0] = weth;
    path[1] = DAI;
    uint256[] memory res = Router.getAmountsOut(wethBalance, path);
    return res[1];
  }

  function getCurrentPrice() public view returns(uint256){
    address[] memory path = new address[](2);
    path[0] = address(token);
    path[1] = weth;
    uint256[] memory res = Router.getAmountsOut(1000000000, path);
    return res[1];
  }


  function updateMaxPrice(uint256 _maxPrice) external onlyOwner {
    maxPrice = _maxPrice;
  }

  function updateMinLDAmountInDAI(uint256 _minLDAmountInDAI) external onlyOwner {
    minLDAmountInDAI = _minLDAmountInDAI;
  }

  function updateMaxLDAmountInDAI(uint256 _maxLDAmountInDAI) external onlyOwner {
    maxLDAmountInDAI = _maxLDAmountInDAI;
  }
}

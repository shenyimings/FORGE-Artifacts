pragma solidity ^0.6.2;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IStake.sol";
import "./interfaces/ISale.sol";
import "./interfaces/IWTOKEN.sol";
import "./interfaces/ISplitFormula.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Fetch is Ownable {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  address public WETH;

  address public dexRouter;

  address public tokenSale;

  IWTOKEN public WTOKEN;

  ISplitFormula public splitFormula;

  address public stakeAddress;

  address public token;

  uint256 public cutPercent = 2;

  bool public isCutActive = false;

  address public DAOWallet;

  /**
  * @dev constructor
  *
  * @param _WETH                  address of Wrapped Ethereum token
  * @param _dexRouter             address of Corader DEX
  * @param _stakeAddress          address of claim able stake
  * @param _token                 address of token token
  * @param _tokenSale             address of sale
  * @param _WTOKEN                address of wtoken
  * @param _splitFormula          address of split formula
  * @param _DAOWallet             address of DAOWallet
  */
  constructor(
    address _WETH,
    address _dexRouter,
    address _stakeAddress,
    address _token,
    address _tokenSale,
    address _WTOKEN,
    address _splitFormula,
    address _DAOWallet
    )
    public
  {
    WETH = _WETH;
    dexRouter = _dexRouter;
    stakeAddress = _stakeAddress;
    token = _token;
    tokenSale = _tokenSale;
    WTOKEN = IWTOKEN(_WTOKEN);
    splitFormula = ISplitFormula(_splitFormula);
    DAOWallet = _DAOWallet;
  }


  function deposit() external payable {
    require(msg.value > 0, "zerro eth");
    // swap ETH
    swapETHInput(msg.value);
    // deposit and stake
    _depositFor(msg.sender);
  }


  function depositFor(address receiver) external payable {
    require(msg.value > 0, "zerro eth");
    // swap ETH
    swapETHInput(msg.value);
    // deposit and stake
    _depositFor(receiver);
  }


  /**
  * @dev convert deposited ETH into wtoken and then stake
  */
  function _depositFor(address receiver) internal {
    // check if token received
    uint256 tokenReceived = IERC20(token).balanceOf(address(this));
    require(tokenReceived > 0, "ZERRO TOKEN AMOUNT");

    // swap token to wtoken
    IERC20(token).approve(address(WTOKEN), tokenReceived);
    WTOKEN.deposit(tokenReceived);

    // approve wtoken to stake
    uint256 wtokenReceived = IERC20(address(WTOKEN)).balanceOf(address(this));
    require(wtokenReceived == tokenReceived, "Wrong WTOKEN amount");

    IERC20(address(WTOKEN)).approve(stakeAddress, wtokenReceived);

    if(isCutActive){
      uint256 cutWtoken = wtokenReceived.div(100).mul(cutPercent);
      uint256 sendToWtoken = wtokenReceived.sub(cutWtoken);
      IERC20(address(WTOKEN)).transfer(DAOWallet, cutWtoken);
      // deposit received Wtoken in token vault strategy
      IStake(stakeAddress).stakeFor(sendToWtoken, receiver);
    }else{

    }

    // send remains and shares back to users
    sendRemains(receiver);
  }


 /**
 * @dev send remains back to user
 */
 function sendRemains(address receiver) internal {
    uint256 tokenRemains = IERC20(token).balanceOf(address(this));
    if(tokenRemains > 0)
       IERC20(token).transfer(receiver, tokenRemains);

    uint256 ethRemains = address(this).balance;
    if(ethRemains > 0)
       payable(receiver).transfer(ethRemains);
 }

 /**
 * @dev swap ETH to token via DEX and Sale
 */
 function swapETHInput(uint256 input) internal {
  (uint256 ethTodex,
   uint256 ethToSale) = calculateToSplit(input);

  // SPLIT SALE with dex and Sale
  if(ethTodex > 0)
    swapETHViaDEX(dexRouter, ethTodex);

  if(ethToSale > 0)
    ISale(tokenSale).buy.value(ethToSale)();
 }

 // helper for swap via dex
 function swapETHViaDEX(address routerDEX, uint256 amount) internal {
   // SWAP split % of ETH input to token from Wtoken
   address[] memory path = new address[](2);
   path[0] = WETH;
   path[1] = token;

   IUniswapV2Router02(routerDEX).swapExactETHForTokens.value(amount)(
     1,
     path,
     address(this),
     now + 1800
   );
 }

 /**
 * @dev return split % amount of input
 */
 function calculateToSplit(uint256 ethInput)
   public
   view
   returns(uint256 ethTodex, uint256 ethToSale)
 {
   (uint256 ethPercentTodex,
    uint256 ethPercentToSale) = splitFormula.calculateToSplit(ethInput);

   ethTodex = ethInput.div(100).mul(ethPercentTodex);
   ethToSale = ethInput.div(100).mul(ethPercentToSale);
 }


 /**
 * @dev allow owner set new stakeAddress contract address
 */
 function changeStakeAddress(address _stakeAddress) external onlyOwner {
   stakeAddress = _stakeAddress;
 }

 /**
 * @dev allow owner set burn percent
 */
 function updateCutPercent(uint256 _cutPercent) external onlyOwner {
   require(_cutPercent > 0, "min %");
   require(_cutPercent <= 5, "max %");
   cutPercent = _cutPercent;
 }

 /**
 * @dev allow owner enable/disable burn
 */
 function updateBurnStatus(bool _status) external onlyOwner {
   isCutActive = _status;
 }

 /**
 * @dev allow owner update splitFormula
 */
 function updateSplitFormula(address _splitFormula) external onlyOwner {
   splitFormula = ISplitFormula(_splitFormula);
 }

 /**
 * @dev allow owner update DAOWallet
 */
 function updateDAOWallet(address _DAOWallet) external onlyOwner {
   DAOWallet = _DAOWallet;
 }
}

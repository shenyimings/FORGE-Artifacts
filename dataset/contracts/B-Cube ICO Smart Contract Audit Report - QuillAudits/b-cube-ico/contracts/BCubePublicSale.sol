pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/drafts/SignedSafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/roles/WhitelistedRole.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV3Interface.sol";

contract BCubePublicSale is WhitelistedRole, Pausable {
  using SafeMath for uint256;
  using SignedSafeMath for int256;
  using SafeCast for uint256;
  using SafeERC20 for IERC20;

  /// @dev allowance is # of BCUBE each participant can withdraw from treasury.
  /// @param currentAllowance this allowance is in 4 stages tracked by currentAllowance
  /// @param shareWithdrawn tracks the amount of BCUBE already withdrawn from treasury
  /// @param dollarUnitsPayed 1 dollar = 100,000,000 dollar units. This tracks dollar units payed by user to this contract
  /// @param allocatedBcubePreICO amount of BCUBE allocated to this user during the Pre-ICO stage
  /// @param allocatedBcubeICO amount of BCUBE allocated to this user during the ICO stage
  struct UserInfo {
    uint256 dollarUnitsPayed;
    uint256 allocatedBcubePreICO;
    uint256 allocatedBcubeICO;
    uint256 currentAllowance;
    uint256 shareWithdrawn;
  }

  mapping(address => UserInfo) public bcubeAllocationRegistry;

  /// @dev variables whose instance fetch prices of USDT, ETH from Chainlink oracles
  AggregatorV3Interface internal priceFeedETH;
  AggregatorV3Interface internal priceFeedUSDT;

  /// @dev the Private Sale contract, used to check for private-sale whitelisted users
  WhitelistedRole internal privateSaleWhitelisted;

  IERC20 public usdt;

  uint256 public openingTime;
  uint256 public closingTime;

  uint256 public netSoldBcube;
  uint256 public constant HARD_CAP = 15_000_000e18; // 8m (Pre-ICO) + 7m (ICO)

  // Address where funds are collected
  address payable private wallet;
  
  event LogEtherReceived(address indexed sender, uint256 value);
  event LogBcubeBuyUsingEth(
    address indexed buyer,
    uint256 incomingWei,
    uint256 allocation
  );
  event LogBcubeBuyUsingUsdt(
      address indexed buyer,
      uint256 incomingUsdtUnits,
      uint256 allocation
  );
  event LogETHPriceFeedChange(address indexed newChainlinkETHPriceFeed);
  event LogUSDTPriceFeedChange(address indexed newChainlinkUSDTPriceFeed);
  event LogUSDTInstanceChange(address indexed newUsdtContract);
  event LogPublicSaleTimeExtension(
    uint256 previousClosingTime,
    uint256 newClosingTime
  );
  
  /**
    * @param _openingTime public sale starting time
    * @param _closingTime public sale closing time
    * @param _chainlinkETHPriceFeed address of the ETH price feed
    * @param _chainlinkUSDTPriceFeed address of the USDT price feed
    * @param _usdtContract address of the USDT ERC20 contract
    * @param _privateSale address of the Private Sale contract
    * @param _wallet team wallet: where ETH end USDT will be transferred
    */
  constructor(
    uint256 _openingTime,
    uint256 _closingTime,
    address _chainlinkETHPriceFeed,
    address _chainlinkUSDTPriceFeed,
    address _usdtContract,
    address _privateSale,
    address payable _wallet
  )
    public WhitelistedRole()
  {
    openingTime = _openingTime;
    closingTime = _closingTime;
    priceFeedETH = AggregatorV3Interface(_chainlinkETHPriceFeed);
    priceFeedUSDT = AggregatorV3Interface(_chainlinkUSDTPriceFeed);
    usdt = IERC20(_usdtContract);
    privateSaleWhitelisted = WhitelistedRole(_privateSale);
    wallet = _wallet;
  }

  function setAdmin(address _admin) public onlyWhitelistAdmin {
    // Add new admin for whitelisting, and remove msgSender as admin
    addWhitelistAdmin(_admin);
    renounceWhitelistAdmin();

    // Add new admin for pause, and remove addPauser as pauser
    addPauser(_admin);
    renouncePauser();
  }

  function() external payable {
    emit LogEtherReceived(_msgSender(), msg.value);
  }

  /// @dev public sale is open if current date is between openingTime and closingTime AND the contract is not paused
  function isOpen() public view returns (bool) {
      // solhint-disable-next-line not-rely-on-time
      return block.timestamp >= openingTime && block.timestamp <= closingTime && !paused();
  }

  modifier onlyWhitelisted() {
    require(
      isWhitelisted(_msgSender()) || privateSaleWhitelisted.isWhitelisted(_msgSender()),
      "BCubePublicSale: caller does not have the Whitelisted role"
    );
    _;
  }

  modifier onlyWhileOpen {
    require(isOpen(), "BCubePublicSale: not open");
    _;
  }

  /// @dev ensuring BCUBE allocations in public sale don't exceed 15m
  modifier tokensRemaining() {
    require(netSoldBcube < HARD_CAP, "BCubePublicSale: All tokens sold");
    _;
  }

  function calcRate() private view returns (uint256, uint8) {
    // Two phases, with two different prices
    // Phase 1 - Pre-ICO: the first 8m tokens at 0.15 USD
    // Phase 2 - ICO: the remaining 7m tokens at 0.20 USD

    if (netSoldBcube < 8_000_000e18) {
      return (66666666666, 1);    // Pre-ICO
    } else {
      return (5e10, 2);    // ICO
    }
  }

  /// @dev allowing resetting ETH priceFeed instance, in case current Chainlink contracts upgrade
  function setETHPriceFeed(address _newChainlinkETHPriceFeed)
    external
    onlyWhitelistAdmin
  {
    priceFeedETH = AggregatorV3Interface(_newChainlinkETHPriceFeed);
    emit LogETHPriceFeedChange(_newChainlinkETHPriceFeed);
  }

  /// @dev allowing resetting USDT priceFeed instance, in case current Chainlink contracts upgrade
  function setUSDTPriceFeed(address _newChainlinkUSDTPriceFeed)
    external
    onlyWhitelistAdmin
  {
    priceFeedUSDT = AggregatorV3Interface(_newChainlinkUSDTPriceFeed);
    emit LogUSDTPriceFeedChange(_newChainlinkUSDTPriceFeed);
  }

  /// @dev allowing resetting USDT instance, in case current contract upgrades
  function setUSDTInstance(address _newUsdtContract)
    external
    onlyWhitelistAdmin
  {
    usdt = IERC20(_newUsdtContract);
    emit LogUSDTInstanceChange(_newUsdtContract);
  }

  /// @dev to extend the current closing time of public sale
  function extendClosingTime(uint256 _newClosingTime)
    external
    onlyWhitelistAdmin
  {
    emit LogPublicSaleTimeExtension(closingTime, _newClosingTime);
    closingTime = _newClosingTime;
  }

  /// @dev allowing users to allocate BCUBEs for themselves using ETH
  /// only KYC/AML whitelisted users can call this, while the sale is open and allocation hard cap is not reached
  /// @dev it fetches current price of ETH, multiples that by incoming ETH to calc total incoming dollar units, then
  /// allocates appropriate amount of BCUBE to user based on current rate, stage
  function buyBcubeUsingETH()
    external
    payable
    onlyWhitelisted
    onlyWhileOpen
    tokensRemaining
  {
    uint256 allocation;
    uint256 ethPrice = uint256(fetchETHPrice());
    uint256 dollarUnits = ethPrice.mul(msg.value).div(1e18);
    allocation = executeAllocation(dollarUnits);
    wallet.transfer(msg.value);

    emit LogBcubeBuyUsingEth(_msgSender(), msg.value, allocation);
  }

  /// @dev allowing users to allocate BCUBEs for themselves using USDT
  /// does all things similar to the above function, but for USDT
  function buyBcubeUsingUSDT(uint256 incomingUsdt)
    external
    onlyWhitelisted
    onlyWhileOpen
    tokensRemaining
  {
    uint256 allocation;
    uint256 usdtPrice = uint256(fetchUSDTPrice());
    uint256 dollarUnits = usdtPrice.mul(incomingUsdt).div(1e6);
    allocation = executeAllocation(dollarUnits);
    usdt.safeTransferFrom(_msgSender(), wallet, incomingUsdt);
    
    emit LogBcubeBuyUsingUsdt(_msgSender(), incomingUsdt, allocation);
  }

  /// @dev stageCap is max net BCUBEs allocated until a given stage i.e. 7m, 15m for stages "pre-ico" and "ico"
  /// @dev based on current netSoldBcube, fetches rate from calcRate()
  /// check that contribution is >= 500 USD (minimal contribution)
  /// then calculates BCUBEs allocated to user from #BCUBE = rate * dollarUnits
  /// => #wBCUBE = ((#wBCUBE / unit dollar) for this stage) * dollarUnits
  /// Now, if new netAllocatedBcube does not exceed stageCap, the user is directly assigned their calculated BCUBE share
  /// but if it exceeds the stage cap, then the user's BCUBE share for this stage remains same until stageCap (a1),
  /// and the exceeding allocation is recalculated using rate of the next stage (a2)
  /// then a1 + a2 is allocated to the user
  /// Math for this can be found in the README
  function executeAllocation(uint256 dollarUnits) private returns (uint256) {
    uint256 finalAllocation;
    uint256 bcubeAllocatedToUser;
    uint256 rate;
    uint8 stage;
    uint256 stageCap;
    uint256 a1;
    uint256 a2;
    uint256 dollarUnitsUnused;
    require(
      dollarUnits >= 500e8,
      "BCubePublicSale: Minimal contribution is 500 USD"
    );
    require(
      dollarUnits <= 100000e8,
      "BCubePublicSale: Maximal contribution is 100000 USD"
    );
    (rate, stage) = calcRate();
    if (stage == 1) {
      stageCap = 8_000_000e18;
    } else {
      stageCap = 15_000_000e18;
    }
    bcubeAllocatedToUser = rate.mul(dollarUnits);
    finalAllocation = netSoldBcube.add(bcubeAllocatedToUser);
    require(finalAllocation <= HARD_CAP, "BCubePublicSale: Hard cap exceeded");
    bcubeAllocationRegistry[_msgSender()].dollarUnitsPayed = bcubeAllocationRegistry[_msgSender()].dollarUnitsPayed.add(dollarUnits);
    if (finalAllocation <= stageCap) {
      netSoldBcube = finalAllocation;
      if (stage == 1) {
        bcubeAllocationRegistry[_msgSender()].allocatedBcubePreICO = bcubeAllocationRegistry[_msgSender()].allocatedBcubePreICO.add(bcubeAllocatedToUser);
      } else {
        bcubeAllocationRegistry[_msgSender()].allocatedBcubeICO = bcubeAllocationRegistry[_msgSender()].allocatedBcubeICO.add(bcubeAllocatedToUser);
      }
      return bcubeAllocatedToUser;
    } else {
      uint256 total;
      a1 = stageCap.sub(netSoldBcube);
      dollarUnitsUnused = dollarUnits.sub(a1.div(rate));
      netSoldBcube = stageCap;
      bcubeAllocationRegistry[_msgSender()].allocatedBcubePreICO = bcubeAllocationRegistry[_msgSender()].allocatedBcubePreICO.add(a1);
      (rate, stage) = calcRate();
      a2 = dollarUnitsUnused.mul(rate);
      netSoldBcube = netSoldBcube.add(a2);
      total = a1.add(a2);
      bcubeAllocationRegistry[_msgSender()].allocatedBcubeICO = bcubeAllocationRegistry[_msgSender()].allocatedBcubeICO.add(a2);
      return total;
    }
  }

  /// @dev fetching ETH price from chainlink oracle
  function fetchETHPrice() public view returns (int256) {
    (, int256 price, , , ) = priceFeedETH.latestRoundData();
    return price;
  }

  /// @dev fetching USDT price from chainlink oracle
  function fetchUSDTPrice() public view returns (int256) {
    (, int256 price, , , ) = priceFeedUSDT.latestRoundData();
    int256 ethUSD = fetchETHPrice();
    return price.mul(ethUSD).div(1e18);
  }

}
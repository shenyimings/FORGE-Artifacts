pragma solidity 0.8.9;

// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ArraysUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "./ERC20SnapshotUpgradeableCustom.sol";

interface ISwapRouter {
  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;

  function WETH() external pure returns (address);

  function getAmountsOut(uint256 amountIn, address[] memory path)
    external
    view
    returns (uint256[] memory amounts);

  function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut);
}

interface ISwapFactory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface ISwapPair {
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
  function sync() external;
}

interface IWolfgirlReserve {
  function buyReserveAsset(uint256 amount) external returns (bool);
  function transferAsset(uint256 amount, address to) external returns (bool);
  function emptyETHVault() external returns (bool);
}

interface IWolfgirlNFT {
  function mint(address to, string memory URIPATH) external returns (bool);
}

contract Wolfgirl is ERC20SnapshotUpgradeableCustom, OwnableUpgradeable {
  address public RESERVE;
  address public NFTCONTRACT;
  address public SWAP_ROUTER;
  address public SWAP_FACTORY;
  address public SWAP_PAIR;

  bool public enabled;
  bool public lastIsBuy;

  uint256 public firstBlock;
  uint256 public initialSupply;
  uint256 public baseSupplySnapshot;
  uint256 public assetSupplySnapshot;
  uint256 public reserveManagersIndex;
  uint256 public nextInterimClaimThreshold;
  uint256 public interimSnapshotId;
  uint256 public endSnapshotId;
  uint256 public interimAssetSupplySnapshot;
  uint256 public interimAssetAmountSnapshot;
  uint256 public interimAvailableDate;
  uint256 public priceFloor;
  uint256 public lastPrice;
  uint256 public AINFTCost;
  uint256 public mintCost;

  mapping(address => bool) public whitelist;
  mapping(address => uint256) public interimClaims;
  mapping(address => uint256) public endClaims;

  address[10] public reserveManagers;

  uint256 public constant burnRate = 400; // 4%
  uint256 public constant reserveRate = 800; // 8%
  uint256 public constant reserveThreshold = 1; // 0.01%
  uint256 public constant manageReserveIncentive = 100; // 1%
  uint256 public constant interimClaimPct = 50; // 0.5%

  event ManageReserve(address indexed sender);
  event ClaimInterim(address indexed sender);

  function initialize(
    address _RESERVE,
    address _NFTCONTRACT,
    address _SWAP_ROUTER,
    address _SWAP_FACTORY
  ) external initializer {
    require(_RESERVE != address(0),"ZERO_ADDRESS_DETECTED_RESERVE");
    require(_NFTCONTRACT != address(0),"ZERO_ADDRESS_DETECTED_NFTCONTRACT");
    require(_SWAP_ROUTER != address(0),"ZERO_ADDRESS_DETECTED_SWAP_ROUTER");
    require(_SWAP_FACTORY != address(0),"ZERO_ADDRESS_DETECTED_SWAP_FACTORY");

    __ERC20_init('Wolfgirl', 'WLFGRL');
    __Ownable_init();
    __ERC20Snapshot_init();

    RESERVE = _RESERVE;
    SWAP_ROUTER = _SWAP_ROUTER;
    SWAP_FACTORY = _SWAP_FACTORY;
    NFTCONTRACT = _NFTCONTRACT;

    initialSupply = 1000000000 * 10**decimals();

    enabled = false;

    baseSupplySnapshot = 0;
    assetSupplySnapshot = 0;
    reserveManagersIndex = 0;

    interimSnapshotId = 0;
    endSnapshotId = 0;
    interimAssetSupplySnapshot = 0;
    interimAssetAmountSnapshot = 0;
    AINFTCost = 25000;
    mintCost = 5000;

    nextInterimClaimThreshold = _pct(10000 - interimClaimPct, initialSupply);
	interimAvailableDate = block.timestamp;

    setWhitelist(owner(), true);
    setWhitelist(_RESERVE, true);
    setWhitelist(_SWAP_ROUTER, true);

    _mint(owner(), initialSupply);
  }

  /** PUBLIC FUNCTIONS **/

  function WolfgirlStart() public onlyOwner {
    SWAP_PAIR = ISwapFactory(SWAP_FACTORY).getPair(address(this), ISwapRouter(SWAP_ROUTER).WETH());
    priceFloor = _getEthOutputAmount(address(this),100000 * 10**decimals());
    firstBlock = block.number;
    setWhitelist(owner(), false);
    renounceOwnership();
    enabled = true;
  }

  function setCosts(uint256 aiCost, uint256 mintingCost) public onlyOwner {
    require(aiCost <= 500000,"TOO_HIGH_AI_NFT_COST");
    require(mintingCost <= 100000,"TOO_HIGH_MINTING_NFT_COST");

    AINFTCost = aiCost;
    mintCost = mintingCost;
  }

  function setWhitelist(address addy, bool add) public onlyOwner {
    whitelist[addy] = add;
  }

  function createSnapshot() external onlyOwner returns (uint256) {
    return _snapshot();
  }

  function burn(uint256 amount) external {
    _burn(_msgSender(), amount);
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    _transferHelper(_msgSender(), recipient, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    _transferHelper(sender, recipient, amount);
    approveTransferFrom(sender, amount);
    return true;
  }

  function buyAINFT(string memory jsonURIPath) public returns (bool) {
    uint256 buyerBalance = balanceOf(_msgSender());
    uint256 AICost = AINFTCost * 10**decimals();

    require(buyerBalance >= AICost, 'NOT_ENOUGH_TOKENS_TO_BUY');

    uint256 burnAmountAINFT = _pct(3300, AICost);
    uint256 reserveAmountAINFT = _pct(6700, AICost);

    _burn(_msgSender(),burnAmountAINFT);
    _transfer(_msgSender(),RESERVE,reserveAmountAINFT);

    IWolfgirlNFT(NFTCONTRACT).mint(_msgSender(),jsonURIPath);

    return true;
  }

  function mintNFT(string memory jsonURIPath) public returns (bool) {
    uint256 minterBalance = balanceOf(_msgSender());
    uint256 mCost = mintCost * 10**decimals();

    require(minterBalance >= mCost, 'NOT_ENOUGH_TOKENS_TO_MINT');

    uint256 burnAmountMint = _pct(3300, mCost);
    uint256 reserveAmountMint = _pct(6700, mCost);

    _burn(_msgSender(), burnAmountMint);
    _transfer(_msgSender(),RESERVE,reserveAmountMint);

    IWolfgirlNFT(NFTCONTRACT).mint(_msgSender(),jsonURIPath);

    return true;
  }

  function manageReserve() public {
    uint256 reserveBalance = balanceOf(RESERVE);

    require(reserveBalance > _pct(reserveThreshold, totalSupply()), 'TEMP_RESERVE_LOW');

    require(!_isInReserveManagersList(_msgSender()), 'IN_MANAGE_RES_LIST');

    _addReserveManager(_msgSender());
    _mint(_msgSender(), _pct(manageReserveIncentive, reserveBalance));
    IWolfgirlReserve(RESERVE).buyReserveAsset(reserveBalance);
    if (totalSupply() < nextInterimClaimThreshold) {
      nextInterimClaimThreshold = _pct(10000 - interimClaimPct, totalSupply());

      uint256 currentAssetSupply = address(RESERVE).balance;
      interimAssetAmountSnapshot = _pct(
        2500,
        SafeMath.sub(currentAssetSupply, interimAssetSupplySnapshot)
      );
      interimAssetSupplySnapshot = currentAssetSupply;

      interimSnapshotId = _snapshot();
      interimAvailableDate = block.timestamp;
    }

    emit ManageReserve(_msgSender());
  }

  function claimInterim() public {
    require(interimSnapshotId > 0, 'NO_CLAIM');
    require(interimClaims[_msgSender()] < interimSnapshotId, 'ALREADY_CLAIMED');

    uint256 callerBalance = balanceOfAt(_msgSender(), interimSnapshotId);

    require(callerBalance > 0, 'EMPTY_WALLET_SNAPSHOT');

    uint256 baseSharePct = SafeMath.div(callerBalance * 10**decimals(), totalSupplyAt(interimSnapshotId));
    uint256 assetShareAmount = SafeMath.div(SafeMath.mul(interimAssetAmountSnapshot, baseSharePct), 10**decimals());

    interimClaims[_msgSender()] = interimSnapshotId;

    IWolfgirlReserve(RESERVE).transferAsset(assetShareAmount, _msgSender());

    emit ClaimInterim(_msgSender());
  }

  function resetVault() public returns (bool){
    require(interimAvailableDate+30 days<=block.timestamp,'INTERIM_STILL_VALID');

    IWolfgirlReserve(RESERVE).emptyETHVault();
    uint256 reserveBalance = balanceOf(RESERVE);
    _burn(RESERVE, reserveBalance);
    nextInterimClaimThreshold = _pct(10000 - interimClaimPct, totalSupply());
    _mint(_msgSender(),100000 * 10**decimals());
    return true;
  }

  /** PRIVATE FUNCTIONS **/

  function _transferHelper(
    address sender,
    address recipient,
    uint256 amount
  ) private returns (bool) {

    require(amount <= balanceOf(sender), 'EXCEED_BALANCE');

    if (_isWhitelisted(sender) && !_isLP(sender)) {
      _transfer(sender, recipient, amount);
      return true;
    }

    require(enabled, 'NOT_ENABLED');

    uint256 burnAmount = _pct(burnRate, amount);
    uint256 reserveAmount = _pct(reserveRate, amount);

    if ((block.number-1) <= firstBlock)
    {
      burnAmount = _pct(3000, amount);
      reserveAmount = _pct(6000, amount);
    }

    if (lastIsBuy) {
      uint256 currentPrice = _getEthOutputAmount(address(this),100000 * 10**decimals());
      uint256 priceDifference = SafeMath.sub(currentPrice, lastPrice);
      uint256 addPriceFloor = _pct(1000,priceDifference);
      priceFloor = SafeMath.add(priceFloor,addPriceFloor);
      lastIsBuy = false;
    }

    if (_isLP(sender)) {
      lastPrice = _getEthOutputAmount(address(this),100000 * 10**decimals());
      lastIsBuy = true;
    }

    if (_isLP(recipient)) {

      uint256 reserve0;
      uint256 reserve1;
      (reserve0,reserve1,) = ISwapPair(SWAP_PAIR).getReserves();

      uint256 amountOut = _getEthOutputAmount(address(this),amount);
      uint256 newreserve0 = SafeMath.add(amount,reserve0);
      uint256 newreserve1 = SafeMath.sub(reserve1,amountOut);
      uint256 projectedPrice = ISwapRouter(SWAP_ROUTER).getAmountOut(100000 * 10**decimals(),newreserve0,newreserve1);

      require(priceFloor < projectedPrice, 'WOULD_BREACH_PRICE_FLOOR');
    }

    // burn 5%
    _burn(sender, burnAmount);

    // transfer to temp reserve
    _transfer(sender, RESERVE, reserveAmount);

    // transfer excluding burn amount and reserve
    _transfer(sender, recipient, SafeMath.sub(amount, SafeMath.add(burnAmount, reserveAmount)));

    return true;
  }

  function _isWhitelisted(address addy) private view returns (bool) {
    if (whitelist[addy]) {
      return true;
    }

    if (_isLP(addy)) {
      return true;
    }

    return false;
  }

  function _isLP(address addy) private view returns (bool) {
    if (_getLP() == addy) {
      return true;
    }

    return false;
  }

  function _getLP() private view returns (address) {
    return ISwapFactory(SWAP_FACTORY).getPair(address(this), ISwapRouter(SWAP_ROUTER).WETH());
  }

  function _isInReserveManagersList(address addy) private view returns (bool) {
    if (addy == owner()) {
      return false;
    }

    for (uint256 i = 0; i < reserveManagers.length; i++) {
      if (reserveManagers[i] == addy) {
        return true;
      }
    }

    return false;
  }

  function _addReserveManager(address addy) private {
    reserveManagers[reserveManagersIndex] = addy;
    reserveManagersIndex++;

    if (reserveManagersIndex >= reserveManagers.length) {
      reserveManagersIndex = 0;
    }
  }

  function _pct(uint256 pct100, uint256 amount) private pure returns (uint256) {
    return SafeMath.div(SafeMath.mul(pct100, amount), 10000);
  }

  function _getEthOutputAmount(address _tokenIn, uint256 _amountIn) private view returns (uint256) {
    address[] memory path = new address[](2);
    path[0] = _tokenIn;
    path[1] = ISwapRouter(SWAP_ROUTER).WETH();

    uint256[] memory result = ISwapRouter(SWAP_ROUTER).getAmountsOut(_amountIn, path);

    return result[1];
  }
  //
}
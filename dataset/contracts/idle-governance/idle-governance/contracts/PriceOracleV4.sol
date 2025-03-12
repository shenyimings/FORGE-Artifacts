pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IERC20Detailed.sol";
import "./interfaces/IdleToken.sol";
import "./interfaces/CERC20.sol";
import "./interfaces/AToken.sol";
import "./interfaces/Comptroller.sol";
import "./interfaces/ChainLinkOracle.sol";
import "./interfaces/IAaveIncentivesController.sol";

contract PriceOracleV4 is OwnableUpgradeable {
  using SafeMath for uint256;

  uint256 constant private ONE_18 = 10**18;
  address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address constant public COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
  address constant public WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address constant public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address constant public SUSD = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
  address constant public TUSD = 0x0000000000085d4780B73119b644AE5ecd22b376;
  address constant public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address constant public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address constant public stkAAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
  address constant public RAI = 0x03ab458634910AaD20eF5f1C8ee96F1D6ac54919;
  address constant public FEI = 0x956F47F50A910163D8BF957Cf5846D573E7f87CA;

  uint256 public blocksPerYear;
  uint256 public constant secondsPerYear = 31536000;

  // underlying -> chainlink feed see https://docs.chain.link/docs/reference-contracts
  mapping (address => address) public priceFeedsUSD;
  mapping (address => address) public priceFeedsETH;

  function initialize() public initializer {
    __Ownable_init();

    blocksPerYear = 2371428; // -> blocks per year with ~13.3s block time

    // USD feeds
    priceFeedsUSD[WETH] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // WETH
    priceFeedsUSD[COMP] = 0xdbd020CAeF83eFd542f4De03e3cF0C28A4428bd5; // COMP
    priceFeedsUSD[WBTC] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // wBTC
    priceFeedsUSD[DAI] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9; // DAI
    priceFeedsUSD[stkAAVE] = 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9; // AAVE
    priceFeedsUSD[FEI] = 0x31e0a88fecB6eC0a411DBe0e9E76391498296EE9; // FEI

    // ETH feeds
    priceFeedsETH[WBTC] = 0xdeb288F737066589598e9214E782fa5A8eD689e8; // wBTC
    priceFeedsETH[DAI] = 0x773616E4d11A78F511299002da57A0a94577F1f4; // DAI
    priceFeedsETH[SUSD] = 0x8e0b7e6062272B5eF4524250bFFF8e5Bd3497757; // SUSD
    priceFeedsETH[TUSD] = 0x3886BA987236181D98F2401c507Fb8BeA7871dF2; // TUSD
    priceFeedsETH[USDC] = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4; // USDC
    priceFeedsETH[USDT] = 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46; // USDT
    priceFeedsETH[stkAAVE] = 0x6Df09E975c830ECae5bd4eD9d90f3A95a4f88012; // AAVE
    priceFeedsETH[RAI] = 0x4ad7B025127e89263242aB68F0f9c4E5C033B489; // RAI
    priceFeedsETH[FEI] = 0x7F0D2c2838c6AC24443d13e23d99490017bDe370; // FEI
    priceFeedsETH[COMP] = 0x1B39Ee86Ec5979ba5C322b826B3ECb8C79991699; // COMP
  }

  /// @notice get price in USD for an asset
  function getPriceUSD(address _asset) public view returns (uint256) {
    return _getPriceUSD(_asset); // 1e18
  }
  /// @notice get price in ETH for an asset
  function getPriceETH(address _asset) public view returns (uint256) {
    return _getPriceETH(_asset); // 1e18
  }
  /// @notice get price in a specific token for an asset
  function getPriceToken(address _asset, address _token) public view returns (uint256) {
    return _getPriceToken(_asset, _token); // 1e(_token.decimals())
  }
  /// @notice get price for the underlying token of an idleToken
  function getUnderlyingPrice(address _idleToken) external view returns (uint256) {
    return getPriceUSD(IdleToken(_idleToken).token()); // 1e18
  }
  /// @notice get COMP additional apr for a specific cToken market
  function getCompApr(address _cToken, address _token) external view returns (uint256) {
    CERC20 _ctoken = CERC20(_cToken);
    uint256 compSpeeds = Comptroller(_ctoken.comptroller()).compSupplySpeeds(_cToken);
    uint256 cTokenNAV = _ctoken.exchangeRateStored().mul(IERC20Detailed(_cToken).totalSupply()).div(ONE_18);
    // how much costs 1COMP in token (1e(_token.decimals()))
    uint256 compUnderlyingPrice = getPriceToken(COMP, _token);
    // mul(100) needed to have a result in the format 4.4e18
    return compSpeeds.mul(compUnderlyingPrice).mul(blocksPerYear).mul(100).div(cTokenNAV);
  }

  /// @notice get AAVE additional apr for a specific aToken market
  function getStkAaveApr(address _aToken, address _token) external view returns (uint256) {
    IAaveIncentivesController _ctrl = IAaveIncentivesController(AToken(_aToken).getIncentivesController());
    (,uint256 aavePerSec,) = _ctrl.getAssetData(_aToken);
    uint256 aTokenNAV = IERC20Detailed(_aToken).totalSupply();
    // how much costs 1AAVE in token (1e(_token.decimals()))
    uint256 aaveUnderlyingPrice = getPriceToken(stkAAVE, _token);
    // mul(100) needed to have a result in the format 4.4e18
    return aavePerSec.mul(aaveUnderlyingPrice).mul(secondsPerYear).mul(100).div(aTokenNAV);
  }

  // #### internal
  function _getPriceUSD(address _asset) internal view returns (uint256 price) {
    if (priceFeedsUSD[_asset] != address(0)) {
      price = _getLatestPrice(priceFeedsUSD[_asset]).mul(10**10); // scale it to 1e18
    } else if (priceFeedsETH[_asset] != address(0)) {
      price = _getLatestPrice(priceFeedsETH[_asset]);
      price = price.mul(_getLatestPrice(priceFeedsUSD[WETH]).mul(10**10)).div(ONE_18);
    }
  }
  function _getPriceETH(address _asset) internal view returns (uint256 price) {
    if (priceFeedsETH[_asset] != address(0)) {
      price = _getLatestPrice(priceFeedsETH[_asset]);
    }
  }
  function _getPriceToken(address _asset, address _token) internal view returns (uint256 price) {
    uint256 assetUSD = getPriceUSD(_asset);
    uint256 tokenUSD = getPriceUSD(_token);
    if (tokenUSD == 0) {
      return price;
    }
    return assetUSD.mul(10**(uint256(IERC20Detailed(_token).decimals()))).div(tokenUSD); // 1e(tokenDecimals)
  }

  // #### onlyOwner
  function setBlocksPerYear(uint256 _blocksPerYear) external onlyOwner {
    blocksPerYear = _blocksPerYear;
  }
  // _feed can be address(0) which means disabled
  function updateFeedETH(address _asset, address _feed) external onlyOwner {
    priceFeedsETH[_asset] = _feed;
  }
  function updateFeedUSD(address _asset, address _feed) external onlyOwner {
    priceFeedsUSD[_asset] = _feed;
  }

  function _getLatestPrice(address _priceFeed) internal view returns (uint256) {
    (,int price,,,) = ChainLinkOracle(_priceFeed).latestRoundData();
    return uint256(price);
  }

}

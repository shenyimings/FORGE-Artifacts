pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IdleToken.sol";
import "./interfaces/CERC20.sol";
import "./interfaces/AToken.sol";
import "./interfaces/Comptroller.sol";
import "./interfaces/ChainLinkOracle.sol";
import "./interfaces/IAaveIncentivesController.sol";

contract PriceOracleV2Matic is Ownable {
  using SafeMath for uint256;

  uint256 constant private ONE_18 = 10**18;
  address constant public WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
  address constant public COMP = 0x8505b9d2254A7Ae468c0E9dd10Ccea3A837aef5c;
  address constant public WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
  address constant public DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
  address constant public USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  address constant public USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
  address constant public WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

  uint256 public blocksPerYear = 2371428; // -> blocks per year with ~13.3s block time
  uint256 public constant secondsPerYear = 31536000;
  // underlying -> chainlink feed see https://docs.chain.link/docs/matic-addresses/
  mapping (address => address) public priceFeedsUSD;
  mapping (address => address) public priceFeedsETH;

  constructor() public {
    // USD feeds
    priceFeedsUSD[WETH] = 0xF9680D99D6C9589e2a93a78A04A279e509205945; // WETH (ETH / USD)
    priceFeedsUSD[WBTC] = 0xc907E116054Ad103354f2D350FD2514433D57F6f; // wBTC (BTC / USD)
    priceFeedsUSD[DAI] = 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D; // DAI (DAI / USD)
    priceFeedsUSD[WMATIC] = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0; // WMATIC (MATIC / USD)

    // ETH feeds
    priceFeedsETH[WBTC] = 0xA338e0492B2F944E9F8C0653D3AD1484f2657a37; // wBTC (WBTC / ETH)
    priceFeedsETH[DAI] = 0xFC539A559e170f848323e19dfD66007520510085; // DAI (DAI / ETH)
    priceFeedsETH[USDC] = 0xefb7e6be8356cCc6827799B6A7348eE674A80EaE; // USDC (USDC / ETH)
    priceFeedsETH[USDT] = 0xf9d5AAC6E5572AEFa6bd64108ff86a222F69B64d; // USDT (USDT / ETH)
    priceFeedsETH[WMATIC] = 0x327e23A4855b6F663a28c5161541d69Af8973302; // WMATIC (MATIC / ETH)
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
  /// @notice AAVE on matic distributes WMATIC
  function getStkAaveApr(address _aToken, address _token) external view returns (uint256) {
    IAaveIncentivesController _ctrl = IAaveIncentivesController(AToken(_aToken).getIncentivesController());
    (uint256 aavePerSec,,) = _ctrl.assets(_aToken);
    uint256 aTokenNAV = IERC20(_aToken).totalSupply();
    // how much costs 1AAVE in token (1e(_token.decimals()))
    uint256 aaveUnderlyingPrice = getPriceToken(WMATIC, _token);
    // mul(100) needed to have a result in the format 4.4e18
    return aavePerSec.mul(aaveUnderlyingPrice).mul(secondsPerYear).mul(100).div(aTokenNAV);
  }

  // #### internal
  function _getPriceUSD(address _asset) internal view returns (uint256 price) {
    if (priceFeedsUSD[_asset] != address(0)) {
      price = ChainLinkOracle(priceFeedsUSD[_asset]).latestAnswer().mul(10**10); // scale it to 1e18
    } else if (priceFeedsETH[_asset] != address(0)) {
      price = ChainLinkOracle(priceFeedsETH[_asset]).latestAnswer();
      price = price.mul(ChainLinkOracle(priceFeedsUSD[WETH]).latestAnswer().mul(10**10)).div(ONE_18);
    }
  }
  function _getPriceETH(address _asset) internal view returns (uint256 price) {
    if (priceFeedsETH[_asset] != address(0)) {
      price = ChainLinkOracle(priceFeedsETH[_asset]).latestAnswer();
    }
  }
  function _getPriceToken(address _asset, address _token) internal view returns (uint256 price) {
    uint256 assetUSD = getPriceUSD(_asset);
    uint256 tokenUSD = getPriceUSD(_token);
    if (tokenUSD == 0) {
      return price;
    }
    return assetUSD.mul(10**(uint256(ERC20(_token).decimals()))).div(tokenUSD); // 1e(tokenDecimals)
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
}

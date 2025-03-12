// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../math/SafeMath.sol";
import "../utils/Owned.sol";
import "./UniswapPairOracle.sol";
import "./interface/IChainlinkOracle.sol";

contract GrOracleWrapper is Owned {
    using SafeMath for uint256;

    UniswapPairOracle private priceFeedGrGUST;
    UniswapPairOracle private priceFeedGustBUSD;
    IChainlinkOracle internal priceFeedBNBBUSD;

    uint256 public PRICE_PRECISION = 1e6;
    address public timelock_address;
    address public wbnb;
    address public busd;
    address public gr;
    address public gu;

    /* ========== MODIFIERS ========== */

    modifier onlyByOwnGov() {
        require(msg.sender == owner || msg.sender == timelock_address, "Not owner or timelock");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor (
        address _creator_address,
        address _timelock_address,
        address _gr_gust_oracle,
        address _gust_busd_oracle,
        address _bnb_busd_oracle,
        address _gr,
        address _gu
    ) public Owned(_creator_address) {
        timelock_address = _timelock_address;
        wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        gr = _gr;
        gu = _gu;

        // Gr/GUST
        priceFeedGrGUST = UniswapPairOracle(_gr_gust_oracle);
        // GUST/BUSD
        priceFeedGustBUSD = UniswapPairOracle(_gust_busd_oracle);
        // BNB/USD
        priceFeedBNBBUSD = IChainlinkOracle(_bnb_busd_oracle);
    }

    /* ========== VIEWS ========== */

    function consult(address token, uint amountIn) external view returns (uint amountOut) {
        require(token == wbnb, "must use weth address");
        require(amountIn == 1e6, "must call with 1e6");
        // needs to return it inverted
        // 1 busd = x gr
        uint256 xGr = priceFeedGustBUSD.consult(busd, 1e18).mul(PRICE_PRECISION).div(priceFeedGrGUST.consult(gr, 1e18));
        // 1 bnb = x busd
        int bnbPrice = priceFeedBNBBUSD.getLatestPrice();
        uint256 busd6 = uint256(bnbPrice).mul(PRICE_PRECISION).div(10 ** uint256(priceFeedBNBBUSD.getDecimals()));

        return busd6.mul(xGr).div(PRICE_PRECISION);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setGrGUSTOracle(address gr_gust_oracle) external onlyByOwnGov {
        priceFeedGrGUST = UniswapPairOracle(gr_gust_oracle);
    }

    function setGustBUSDOracle(address gust_busd_oracle) external onlyByOwnGov {
        priceFeedGustBUSD = UniswapPairOracle(gust_busd_oracle);
    }

    function setBNBUSDOracle(address bnb_busd_oracle) external onlyByOwnGov {
        priceFeedBNBBUSD = IChainlinkOracle(bnb_busd_oracle);
    }
}
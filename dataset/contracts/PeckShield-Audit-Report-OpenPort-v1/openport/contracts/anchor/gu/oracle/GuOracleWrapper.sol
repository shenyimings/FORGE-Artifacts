// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../../../utils/Owned.sol";
import "../../../math/SafeMath.sol";
import "../../../oracle/UniswapPairOracle.sol";
import "../../../oracle/interface/IChainlinkOracle.sol";

contract GuOracleWrapper is Owned {
    using SafeMath for uint256;

    UniswapPairOracle private priceFeedGuBUSD;
    IChainlinkOracle internal priceFeedBNBBUSD;

    uint256 public PRICE_PRECISION = 1e6;
    address public timelock_address;
    address public wbnb;
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
        address _gu_busd_oracle,
        address _bnb_busd_oracle,
        address _gu
    ) public Owned(_creator_address) {
        timelock_address = _timelock_address;
        wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        gu = _gu;

        // Gu/BUSD
        priceFeedGuBUSD = UniswapPairOracle(_gu_busd_oracle);

        // BNB/USD
        priceFeedBNBBUSD = IChainlinkOracle(_bnb_busd_oracle);
    }

    /* ========== VIEWS ========== */

    function consult(address token, uint amountIn) external view returns (uint amountOut) {
        require(token == wbnb, "must use weth address");
        require(amountIn == 1e6, "must call with 1e6");

        int bnbPrice = priceFeedBNBBUSD.getLatestPrice();
        uint256 busd18 = uint256(bnbPrice).mul(10 ** 18).div(10 ** uint256(priceFeedBNBBUSD.getDecimals()));
        // needs to return it inverted
        return busd18.mul(PRICE_PRECISION).div(priceFeedGuBUSD.consult(gu, 1e18));
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setGuBUSDOracle(address gu_busd_oracle) external onlyByOwnGov {
        priceFeedGuBUSD = UniswapPairOracle(gu_busd_oracle);
    }

    function setBNBUSDOracle(address bnb_busd_oracle) external onlyByOwnGov {
        priceFeedBNBBUSD = IChainlinkOracle(bnb_busd_oracle);
    }
}
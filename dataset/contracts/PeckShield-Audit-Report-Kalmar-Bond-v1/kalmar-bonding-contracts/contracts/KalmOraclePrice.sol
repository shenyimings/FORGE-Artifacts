// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
* PriceFeed for mainnet deployment, to be connected to Chainlink's live ETH:USD aggregator reference
* contract, and a wrapper contract bandOracle, which connects to BandMaster contract.
*
* The PriceFeed uses Chainlink as primary oracle, and Band as fallback. It contains logic for
* switching oracles based on oracle failures, timeouts, and conditions for returning to the primary
* Chainlink oracle.
*/
contract KalmOraclePrice is Ownable {
    using SafeMath for uint256;

    
    uint256 public factor;
    address public kalmToken;
    uint256 public lastTimestamp;
    
    uint256 constant public PRICE_FACTOR_DIVIDER = 1e4;
    uint256 constant public MAX_PRICE_FACTOR = 3000; // 30%
    // oracle setter
    mapping (address => bool) public oracleSetter;

    uint256 private _fetchPrice;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _kalm
    ) public {
        kalmToken = _kalm;
        factor = 1000; // 10%
    }

    /* ========== MODIFIER ========== */

    /**
     * @notice Checks if the msg.sender is the setter address
     */
    modifier onlyOracleSetter() {
        require(oracleSetter[msg.sender], "Only oracle setter");
        _;
    }

    /* ========== VIEW ========== */

    function kalmPrice() external view returns (uint256)
    {
         return _fetchPrice;
    }

    /* ========== MUTATIVE FUNCTION ========== */

    function updateKalmPrice(uint256 _price) external onlyOracleSetter {
        uint256 factorPrice = _fetchPrice.mul(factor).div(PRICE_FACTOR_DIVIDER);
        if(lastTimestamp == 0){
            _fetchPrice = _price;
            lastTimestamp = block.timestamp;
        }else{
            require(_price > _fetchPrice.sub(factorPrice), "lower price!");
            require(_price <= _fetchPrice.add(factorPrice), "higher price!");
            _fetchPrice = _price;
            lastTimestamp = block.timestamp;
        }
        emit UpdatedPrice(_price);
    }

    function setPriceFactor(uint256 _factor) public onlyOwner
    {
        require(_factor < MAX_PRICE_FACTOR, "Price factor invalid!");
        factor = _factor;
        emit UpdatedFactor(_factor);
    }

    function addOracleSetter(address _setter) public onlyOwner
    {
        oracleSetter[_setter] = true;
        emit AddOracleSetter(_setter);
    }

    function removeOracleSetter(address _setter) public onlyOwner
    {
        oracleSetter[_setter] = false;
        emit RemoveOracleSetter(_setter);
    }


    /* ========== EVENTS ========== */

    event UpdatedPrice(uint256 price);
    event UpdatedFactor(uint256 factor);
    event AddOracleSetter(address setter);
    event RemoveOracleSetter(address setter);
}

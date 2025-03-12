// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Math} from '../Math/Math.sol';
import {SafeMath} from '../Math/SafeMath.sol';
import {IUniswapPairOracle} from './IUniswapPairOracle.sol';
import {IUniswapV2Pair} from '../Uniswap/Interfaces/IUniswapV2Pair.sol';
import {IMetaImplementationUSD} from '../Curve/IMetaImplementationUSD.sol';

/**
 * @title  ReserveTracker.
 * @author MahaDAO.
 *
 * Original code written by:
 * - Travis Moore, Jason Huan, Same Kazemian, Sam Sun.
 *
 * Modified originally from Synthetixio
 * https://raw.githubusercontent.com/Synthetixio/synthetix/develop/contracts/StakingRewards.sol
 */
contract ReserveTracker {
    using SafeMath for uint256;

    /**
     * State variables.
     */

    IUniswapPairOracle public arthxWETHOracle;
    IUniswapPairOracle public arthPriceOracle;
    IMetaImplementationUSD public arthMetaPool;
    IUniswapPairOracle public wethCollateralOracle;

    uint256 public lastTimestamp;
    uint256 public arthxReserves;
    uint256 public CONSULT_ARTH_DEC;
    uint256 public CONSULT_ARTHX_DEC;
    uint256 public wethCollateralDecimals;
    uint256 public arthPairCollateralCecimals;

    address public ownerAddress;
    address public timelock_address;
    address public arthContractAddress;
    address public arthxContractAddress;

    // The pair of which to get ARTHX price from
    address public wethAddress;
    address public arthMetaPoolAddress;
    address public arthxWETHOracleAddress;
    address public wethCollateralOracleAddress;

    // The pair of which to get ARTH price from
    address public arthPriceOracleAddress;
    address public arthPairCollateralAddress;

    // Mapping is also used for faster verification
    mapping(address => bool) public arthxPairs;

    uint256[2] public oldTWAP;
    // Array of pairs for ARTHX.
    address[] public arthxPairsArray;

    /**
     * Modifier.
     */

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == ownerAddress || msg.sender == timelock_address,
            'You are not the owner or the governance timelock'
        );
        _;
    }

    /**
     * Constructor.
     */
    constructor(
        address _arthContractAddress,
        address _arthxContractAddress,
        address _creatorAddress,
        address _timelockAddress
    ) {
        arthContractAddress = _arthContractAddress;
        arthxContractAddress = _arthxContractAddress;
        ownerAddress = _creatorAddress;
        timelock_address = _timelockAddress;
    }

    /**
     * External.
     */

    function setOwner(address _ownerAddress) external onlyByOwnerOrGovernance {
        ownerAddress = _ownerAddress;
    }

    function setTimelock(address newTimelock) external onlyByOwnerOrGovernance {
        timelock_address = newTimelock;
    }

    /**
     * Public.
     */

    // Get the pair of which to price ARTH from
    function setARTHPriceOracle(
        address _arthPriceOracleAddress,
        address _arthPairCollateralAddress,
        uint256 _arthPairCollateralCecimals
    ) public onlyByOwnerOrGovernance {
        arthPriceOracleAddress = _arthPriceOracleAddress;
        arthPairCollateralAddress = _arthPairCollateralAddress;
        arthPairCollateralCecimals = _arthPairCollateralCecimals;
        arthPriceOracle = IUniswapPairOracle(arthPriceOracleAddress);

        CONSULT_ARTH_DEC =
            1e6 *
            (10**(uint256(18).sub(arthPairCollateralCecimals)));
    }

    function setMetapool(address _arthMetaPoolAddress)
        public
        onlyByOwnerOrGovernance
    {
        arthMetaPoolAddress = _arthMetaPoolAddress;
        arthMetaPool = IMetaImplementationUSD(_arthMetaPoolAddress);
    }

    // Get the pair of which to price ARTHX from (using ARTHX-WETH)
    function setARTHXETHOracle(
        address _arthxWETHOracleAddress,
        address _wethAddress
    ) public onlyByOwnerOrGovernance {
        arthxWETHOracleAddress = _arthxWETHOracleAddress;
        wethAddress = _wethAddress;
        arthxWETHOracle = IUniswapPairOracle(arthxWETHOracleAddress);
    }

    function setETHCollateralOracle(
        address _wethCollateralOracleAddress,
        uint256 _collateralDecimals
    ) public onlyByOwnerOrGovernance {
        wethCollateralOracleAddress = _wethCollateralOracleAddress;
        wethCollateralDecimals = _collateralDecimals;
        wethCollateralOracle = IUniswapPairOracle(_wethCollateralOracleAddress);
        CONSULT_ARTHX_DEC = 1e6 * (10**(uint256(18).sub(_collateralDecimals)));
    }

    // Adds collateral addresses supported, such as tether and busd, must be ERC20
    function addARTHXPair(address pariAddress) public onlyByOwnerOrGovernance {
        require(arthxPairs[pariAddress] == false, 'address already exists');
        arthxPairs[pariAddress] = true;
        arthxPairsArray.push(pariAddress);
    }

    // Remove a pool
    function removeARTHXPair(address pariAddress)
        public
        onlyByOwnerOrGovernance
    {
        require(
            arthxPairs[pariAddress] == true,
            "address doesn't exist already"
        );

        // Delete from the mapping
        delete arthxPairs[pariAddress];

        // 'Delete' from the array by setting the address to 0x0
        for (uint256 i = 0; i < arthxPairsArray.length; i++) {
            if (arthxPairsArray[i] == pariAddress) {
                arthxPairsArray[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }
    }

    function getARTHCurvePrice() public returns (uint256) {
        uint256[2] memory newTWAP = arthMetaPool.get_price_cumulative_last();
        uint256[2] memory balances =
            arthMetaPool.get_twap_balances(
                oldTWAP,
                newTWAP,
                block.timestamp - lastTimestamp
            );

        lastTimestamp = block.timestamp;
        oldTWAP = newTWAP;

        uint256 twapPrice =
            arthMetaPool.get_dy(1, 0, 1e18, balances).mul(1e6).div(
                arthMetaPool.get_virtual_price()
            );

        return twapPrice;
    }

    // Returns ARTH price with 6 decimals of precision
    function getARTHPrice() public view returns (uint256) {
        return arthPriceOracle.consult(arthContractAddress, CONSULT_ARTH_DEC);
    }

    // Returns ARTHX price with 6 decimals of precision
    function getARTHXPrice() public view returns (uint256) {
        uint256 arthxWETHPrice =
            arthxWETHOracle.consult(arthxContractAddress, 1e6);

        return
            wethCollateralOracle
                .consult(wethAddress, CONSULT_ARTHX_DEC)
                .mul(arthxWETHPrice)
                .div(1e6);
    }

    function getARTHXReserves() public view returns (uint256) {
        uint256 totalARTHXReserves = 0;

        for (uint256 i = 0; i < arthxPairsArray.length; i++) {
            // Exclude null addresses
            if (arthxPairsArray[i] != address(0)) {
                if (
                    IUniswapV2Pair(arthxPairsArray[i]).token0() ==
                    arthxContractAddress
                ) {
                    (uint256 reserves0, , ) =
                        IUniswapV2Pair(arthxPairsArray[i]).getReserves();
                    totalARTHXReserves = totalARTHXReserves.add(reserves0);
                } else if (
                    IUniswapV2Pair(arthxPairsArray[i]).token1() ==
                    arthxContractAddress
                ) {
                    (, uint256 reserves1, ) =
                        IUniswapV2Pair(arthxPairsArray[i]).getReserves();
                    totalARTHXReserves = totalARTHXReserves.add(reserves1);
                }
            }
        }

        return totalARTHXReserves;
    }
}

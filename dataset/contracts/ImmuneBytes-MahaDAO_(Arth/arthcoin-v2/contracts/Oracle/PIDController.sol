// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IARTH} from '../Arth/IARTH.sol';
import {IARTHX} from '../ARTHX/IARTHX.sol';
import {SafeMath} from '../Math/SafeMath.sol';
import {ReserveTracker} from './ReserveTracker.sol';
import {IARTHController} from '../Arth/IARTHController.sol';
import {IMetaImplementationUSD} from '../Curve/IMetaImplementationUSD.sol';

/**
 * @title  PIDController.
 * @author MahaDAO.
 *
 *  Original code written by:
 *  - Travis Moore, Jason Huan, Same Kazemian, Sam Sun.
 */
contract PIDController {
    using SafeMath for uint256;

    /**
     * State variables.
     */

    IARTH public ARTH;
    IARTHX public ARTHX;
    ReserveTracker public reserveTracker;
    IARTHController private _arthController;
    IMetaImplementationUSD public arthMetaPool;

    address public ownerAddress;
    address public timelockAddress;
    address public arthMetaPoolAddress;
    address public arthContractAddress;
    address public arthxContractAddress;
    address public reserveTrackerAddress;

    bool public isActive;
    uint256 lastUpdate;
    uint256 lastARTHSupply;
    uint256 public arthStep;
    uint256 public GRTopBand;
    uint256 public ARTHTopBand;
    uint256 public growthRatio;
    uint256 public GRBottomBand;
    uint256 public ARTHBottomBand;
    uint256 public internalCooldown;

    uint256[2] public oldTWAP;

    /**
     * Events.
     */

    event ARTHdecollateralize(uint256 newCollateralRatio);
    event ARTHrecollateralize(uint256 newCollateralRatio);

    /**
     * Modifiers.
     */

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == ownerAddress || msg.sender == timelockAddress,
            'PIDController: You are not the owner, _arthController, or the governance timelock'
        );
        _;
    }

    /**
     * Constructor.
     */
    constructor(
        address _arthContractAddress,
        address _arthxContractAddress,
        address _creator_address,
        address _timelockAddress,
        address _reserveTrackerAddress
    ) {
        arthStep = 2500;
        arthContractAddress = _arthContractAddress;
        arthxContractAddress = _arthxContractAddress;
        ownerAddress = _creator_address;
        timelockAddress = _timelockAddress;
        reserveTrackerAddress = _reserveTrackerAddress;
        reserveTracker = ReserveTracker(reserveTrackerAddress);

        ARTH = IARTH(arthContractAddress);
        ARTHX = IARTHX(arthxContractAddress);

        // Upon genesis, if GR changes by more than 1% percent, enable change of collateral ratio
        GRTopBand = 1000;
        isActive = false;
        GRBottomBand = 1000;
    }

    /**
     * External.
     */

    function setReserveTracker(address _reserveTrackerAddress)
        external
        onlyByOwnerOrGovernance
    {
        reserveTrackerAddress = _reserveTrackerAddress;
        reserveTracker = ReserveTracker(_reserveTrackerAddress);
    }

    function setMetapool(address _metaPoolAddress)
        external
        onlyByOwnerOrGovernance
    {
        arthMetaPoolAddress = _metaPoolAddress;
        arthMetaPool = IMetaImplementationUSD(_metaPoolAddress);
    }

    function setCollateralRatio() public onlyByOwnerOrGovernance {
        require(
            block.timestamp - lastUpdate >= internalCooldown,
            'internal cooldown not passed'
        );

        uint256 arthxReserves = reserveTracker.getARTHXReserves();
        uint256 arthxPrice = reserveTracker.getARTHXPrice();

        uint256 arthxLiquidity = (arthxReserves.mul(arthxPrice)); // Has 6 decimals of precision

        uint256 arthSupply = ARTH.totalSupply();
        // uint256 arth_price = reserveTracker.getARTHPrice(); // Using Uniswap
        // Get the ARTH TWAP on Curve Metapool
        uint256[2] memory newTWAP = arthMetaPool.get_price_cumulative_last();
        uint256[2] memory balances =
            arthMetaPool.get_twap_balances(
                oldTWAP,
                newTWAP,
                block.timestamp - lastUpdate
            );

        oldTWAP = newTWAP;
        uint256 arthPrice =
            arthMetaPool.get_dy(1, 0, 1e18, balances).mul(1e6).div(
                arthMetaPool.get_virtual_price()
            );

        uint256 newGrowthRatio = arthxLiquidity.div(arthSupply); // (E18 + E6) / E18

        uint256 lastCollateralRatio =
            _arthController.getGlobalCollateralRatio();
        uint256 newCollateralRatio = lastCollateralRatio;

        // First, check if the price is out of the band
        if (arthPrice > ARTHTopBand) {
            newCollateralRatio = lastCollateralRatio.sub(arthStep);
        } else if (arthPrice < ARTHBottomBand) {
            newCollateralRatio = lastCollateralRatio.add(arthStep);

            // Else, check if the growth ratio has increased or decreased since last update
        } else {
            if (newGrowthRatio > growthRatio.mul(1e6 + GRTopBand).div(1e6)) {
                newCollateralRatio = lastCollateralRatio.sub(arthStep);
            } else if (
                newGrowthRatio < growthRatio.mul(1e6 - GRBottomBand).div(1e6)
            ) {
                newCollateralRatio = lastCollateralRatio.add(arthStep);
            }
        }

        // No need for checking CR under 0 as the lastCollateralRatio.sub(arthStep) will throw
        // an error above in that case
        if (newCollateralRatio > 1e6) {
            newCollateralRatio = 1e6;
        }

        // For testing purposes
        if (isActive) {
            uint256 deltaCollateralRatio;

            if (newCollateralRatio > lastCollateralRatio) {
                deltaCollateralRatio = newCollateralRatio - lastCollateralRatio;
                _arthController.setPriceTarget(0); // Set to zero to increase CR

                emit ARTHdecollateralize(newCollateralRatio);
            } else if (newCollateralRatio < lastCollateralRatio) {
                deltaCollateralRatio = lastCollateralRatio - newCollateralRatio;
                _arthController.setPriceTarget(1000e6); // Set to high value to decrease CR

                emit ARTHrecollateralize(newCollateralRatio);
            }

            _arthController.setArthStep(deltaCollateralRatio); // Change by the delta
            uint256 cooldownBefore = _arthController.getRefreshCooldown(); // Note the existing cooldown period
            _arthController.setRefreshCooldown(0); // Unlock the CR cooldown

            _arthController.refreshCollateralRatio(); // Refresh CR

            // Reset params
            _arthController.setArthStep(0);
            // Set the cooldown period to what it was before, or until next _arthController refresh
            _arthController.setRefreshCooldown(cooldownBefore);
            _arthController.setPriceTarget(1e6);
        }

        growthRatio = newGrowthRatio;
        lastUpdate = block.timestamp;
    }

    function activate(bool _state) external onlyByOwnerOrGovernance {
        isActive = _state;
    }

    // As a percentage added/subtracted from the previous; e.g. top_band = 4000 = 0.4% -> will decollat if GR increases by 0.4% or more
    function setGrowthRatioBands(uint256 _GRTopBand, uint256 _GRBottomBand)
        external
        onlyByOwnerOrGovernance
    {
        GRTopBand = _GRTopBand;
        GRBottomBand = _GRBottomBand;
    }

    function setInternalCooldown(uint256 _internalCooldown)
        external
        onlyByOwnerOrGovernance
    {
        internalCooldown = _internalCooldown;
    }

    function setArthStep(uint256 _newStep) external onlyByOwnerOrGovernance {
        arthStep = _newStep;
    }

    function setPriceBands(uint256 _topBand, uint256 _bottomBand)
        external
        onlyByOwnerOrGovernance
    {
        ARTHTopBand = _topBand;
        ARTHBottomBand = _bottomBand;
    }

    function setOwner(address _ownerAddress) external onlyByOwnerOrGovernance {
        ownerAddress = _ownerAddress;
    }

    function setTimelock(address newTimelock) external onlyByOwnerOrGovernance {
        timelockAddress = newTimelock;
    }
}

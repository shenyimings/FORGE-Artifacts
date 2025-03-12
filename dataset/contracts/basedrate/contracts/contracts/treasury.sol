// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/Operator.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IBoardroom.sol";

library Babylonian {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }
}

contract ContractGuard {
    mapping(uint256 => mapping(address => bool)) private _status;

    function checkSameOriginReentranted() internal view returns (bool) {
        return _status[block.number][tx.origin];
    }

    function checkSameSenderReentranted() internal view returns (bool) {
        return _status[block.number][msg.sender];
    }

    modifier onlyOneBlock() {
        require(
            !checkSameOriginReentranted(),
            "ContractGuard: one block, one function"
        );
        require(
            !checkSameSenderReentranted(),
            "ContractGuard: one block, one function"
        );

        _;

        _status[block.number][tx.origin] = true;
        _status[block.number][msg.sender] = true;
    }
}

interface IBasisAsset {
    function mint(address recipient, uint256 amount) external returns (bool);

    function burn(uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;

    function isOperator() external returns (bool);

    function operator() external view returns (address);

    function transferOperator(address newOperator_) external;
}

contract Treasury is ContractGuard, Operator {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========= CONSTANT VARIABLES ======== */

    uint256 public constant PERIOD = 6 hours;

    /* ========== STATE VARIABLES ========== */

    // flags
    bool public initialized = false;

    // epoch
    uint256 public startTime;
    uint256 public epoch = 0;
    uint256 public epochSupplyContractionLeft = 0;

    // exclusions from total supply
    address[] public excludedFromTotalSupply;

    // core components
    address public baseRate;
    address public bbond;

    address public boardroom;
    address public baseOracle;

    // price
    uint256 public baseRatePriceOne;
    uint256 public baseRatePriceCeiling;

    uint256 public seigniorageSaved;

    uint256[] public supplyTiers;
    uint256[] public maxExpansionTiers;

    uint256 public maxSupplyExpansionPercent;
    uint256 public bondDepletionFloorPercent;
    uint256 public seigniorageExpansionFloorPercent;
    uint256 public maxSupplyContractionPercent;
    uint256 public maxDebtRatioPercent;
    uint256 public bootstrapEpochs;
    uint256 public bootstrapSupplyExpansionPercent;

    /* =================== Added variables =================== */
    uint256 public previousEpochBaseRatePrice;
    uint256 public maxDiscountRate; // when purchasing bond
    uint256 public maxPremiumRate; // when redeeming bond
    uint256 public discountPercent;
    uint256 public premiumThreshold;
    uint256 public premiumPercent;
    uint256 public mintingFactorForPayingDebt; // print extra BRATE during debt phase

    address public daoFund;
    uint256 public daoFundSharedPercent;

    address public devFund;
    uint256 public devFundSharedPercent;

    /* =================== Events =================== */

    event Initialized(address indexed executor, uint256 at);
    event BurnedBonds(address indexed from, uint256 bondAmount);
    event RedeemedBonds(
        address indexed from,
        uint256 baseRateAmount,
        uint256 bondAmount
    );
    event BoughtBonds(
        address indexed from,
        uint256 baseRateAmount,
        uint256 bondAmount
    );
    event TreasuryFunded(uint256 timestamp, uint256 seigniorage);
    event BoardroomFunded(uint256 timestamp, uint256 seigniorage);
    event DaoFundFunded(uint256 timestamp, uint256 seigniorage);
    event DevFundFunded(uint256 timestamp, uint256 seigniorage);

    /* =================== Modifier =================== */
    modifier checkCondition() {
        require(block.timestamp >= startTime, "Treasury: not started yet");

        _;
    }

    modifier checkEpoch() {
        require(
            block.timestamp >= nextEpochPoint(),
            "Treasury: not opened yet"
        );

        _;

        epoch = epoch.add(1);
        epochSupplyContractionLeft = (getBaseRatePrice() > baseRatePriceCeiling)
            ? 0
            : getBaseRateCirculatingSupply()
                .mul(maxSupplyContractionPercent)
                .div(10000);
    }

    modifier checkOperator() {
        require(
            IBasisAsset(baseRate).operator() == address(this) &&
                IBasisAsset(bbond).operator() == address(this) &&
                Operator(boardroom).operator() == address(this),
            "Treasury: need more permission"
        );

        _;
    }

    modifier notInitialized() {
        require(!initialized, "Treasury: already initialized");

        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function isInitialized() public view returns (bool) {
        return initialized;
    }

    // epoch
    function nextEpochPoint() public view returns (uint256) {
        return startTime.add(epoch.mul(PERIOD));
    }

    // oracle
    function getBaseRatePrice() public view returns (uint256 baseRatePrice) {
        try IOracle(baseOracle).consult(baseRate, 1e18) returns (
            uint144 price
        ) {
            return uint256(price);
        } catch {
            revert(
                "Treasury: failed to consult baseRate price from the oracle"
            );
        }
    }

    function getBaseRateUpdatedPrice()
        public
        view
        returns (uint256 _baseRatePrice)
    {
        try IOracle(baseOracle).twap(baseRate, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert(
                "Treasury: failed to consult baseRate price from the oracle"
            );
        }
    }

    // budget
    function getReserve() public view returns (uint256) {
        return seigniorageSaved;
    }

    function getBurnableBaseRateLeft()
        public
        view
        returns (uint256 _burnableBaseRateLeft)
    {
        uint256 _baseRatePrice = getBaseRatePrice();
        if (_baseRatePrice <= baseRatePriceOne) {
            uint256 _baseRateSupply = getBaseRateCirculatingSupply();
            uint256 _bondMaxSupply = _baseRateSupply
                .mul(maxDebtRatioPercent)
                .div(10000);
            uint256 _bondSupply = IERC20(bbond).totalSupply();
            if (_bondMaxSupply > _bondSupply) {
                uint256 _maxMintableBond = _bondMaxSupply.sub(_bondSupply);
                uint256 _maxBurnableBaseRate = _maxMintableBond
                    .mul(_baseRatePrice)
                    .div(1e18);
                _burnableBaseRateLeft = Math.min(
                    epochSupplyContractionLeft,
                    _maxBurnableBaseRate
                );
            }
        }
    }

    function getRedeemableBonds()
        public
        view
        returns (uint256 _redeemableBonds)
    {
        uint256 _baseRatePrice = getBaseRatePrice();
        if (_baseRatePrice > baseRatePriceCeiling) {
            uint256 _totalBaseRate = IERC20(baseRate).balanceOf(address(this));
            uint256 _rate = getBondPremiumRate();
            if (_rate > 0) {
                _redeemableBonds = _totalBaseRate.mul(1e18).div(_rate);
            }
        }
    }

    function getBondDiscountRate() public view returns (uint256 _rate) {
        uint256 _baseRatePrice = getBaseRatePrice();
        if (_baseRatePrice <= baseRatePriceOne) {
            if (discountPercent == 0) {
                // no discount
                _rate = baseRatePriceOne;
            } else {
                uint256 _bondAmount = baseRatePriceOne.mul(1e18).div(
                    _baseRatePrice
                ); // to burn 1 BRATE
                uint256 _discountAmount = _bondAmount
                    .sub(baseRatePriceOne)
                    .mul(discountPercent)
                    .div(10000);
                _rate = baseRatePriceOne.add(_discountAmount);
                if (maxDiscountRate > 0 && _rate > maxDiscountRate) {
                    _rate = maxDiscountRate;
                }
            }
        }
    }

    function getBondPremiumRate() public view returns (uint256 _rate) {
        uint256 _baseRatePrice = getBaseRatePrice();
        if (_baseRatePrice > baseRatePriceCeiling) {
            uint256 _baseRatePricePremiumThreshold = baseRatePriceOne
                .mul(premiumThreshold)
                .div(100);
            if (_baseRatePrice >= _baseRatePricePremiumThreshold) {
                //Price > 1.10
                uint256 _premiumAmount = _baseRatePrice
                    .sub(baseRatePriceOne)
                    .mul(premiumPercent)
                    .div(10000);
                _rate = baseRatePriceOne.add(_premiumAmount);
                if (maxPremiumRate > 0 && _rate > maxPremiumRate) {
                    _rate = maxPremiumRate;
                }
            } else {
                // no premium bonus
                _rate = baseRatePriceOne;
            }
        }
    }

    /* ========== GOVERNANCE ========== */

    function initialize(
        address _baseRate,
        address _bbond,
        address _baseOracle,
        address _boardroom,
        uint256 _startTime
    ) public notInitialized {
        baseRate = _baseRate;
        bbond = _bbond;
        baseOracle = _baseOracle;
        boardroom = _boardroom;
        startTime = _startTime;

        baseRatePriceOne = 10 ** 18; // This is to allow a PEG of 1 BRATE per 1 ETH
        baseRatePriceCeiling = baseRatePriceOne.mul(101).div(100);

        // Dynamic max expansion percent
        supplyTiers = [
            0 ether,
            100 ether,
            120 ether,
            150 ether,
            200 ether,
            220 ether,
            250 ether,
            270 ether,
            300 ether
        ];
        maxExpansionTiers = [250, 200, 175, 160, 120, 100, 90, 80, 75];

        maxSupplyExpansionPercent = 400; // Upto 4.0% supply for expansion

        bondDepletionFloorPercent = 10000; // 100% of Bond supply for depletion floor
        seigniorageExpansionFloorPercent = 3500; // At least 35% of expansion reserved for boardroom
        maxSupplyContractionPercent = 300; // Upto 3.0% supply for contraction (to burn BRATE and mint BBOND)
        maxDebtRatioPercent = 4000; // Upto 40% supply of BBOND to purchase

        premiumThreshold = 110;
        premiumPercent = 7000;

        // First 12 epochs with 2.5% expansion
        bootstrapEpochs = 12;
        bootstrapSupplyExpansionPercent = 250; //2.5% to account for baseRate reward emissions during this time

        // set seigniorageSaved to it's balance
        seigniorageSaved = IERC20(baseRate).balanceOf(address(this));

        initialized = true;
        emit Initialized(msg.sender, block.number);
    }

    function isAdded(address _address) private view returns (bool) {
        for (uint256 i = 0; i < excludedFromTotalSupply.length; i++) {
            if (excludedFromTotalSupply[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function find(address _address) private view returns (uint256) {
        for (uint256 i = 0; i < excludedFromTotalSupply.length; i++) {
            if (excludedFromTotalSupply[i] == _address) {
                return i;
            }
        }

        revert("Address not found");
    }

    function addToExcludedFromTotalSupply(
        address _address
    ) public onlyOperator {
        require(!isAdded(_address), "Address already added");
        excludedFromTotalSupply.push(_address);
    }

    function removeFromExcludedFromTotalSupply(
        address _address
    ) public onlyOperator {
        uint256 index = find(_address);
        require(index < excludedFromTotalSupply.length, "Address not found");
        for (uint256 i = index; i < excludedFromTotalSupply.length - 1; i++) {
            excludedFromTotalSupply[i] = excludedFromTotalSupply[i + 1];
        }
        excludedFromTotalSupply.pop();
    }

    function setBoardroom(address _boardroom) external onlyOperator {
        boardroom = _boardroom;
    }

    function setBaseOracle(address _baseOracle) external onlyOperator {
        baseOracle = _baseOracle;
    }

    function setBaseRatePriceCeiling(
        uint256 _baseRatePriceCeiling
    ) external onlyOperator {
        require(
            _baseRatePriceCeiling >= baseRatePriceOne &&
                _baseRatePriceCeiling <= baseRatePriceOne.mul(120).div(100),
            "out of range"
        ); // [$1.0, $1.2]
        baseRatePriceCeiling = _baseRatePriceCeiling;
    }

    function setMaxSupplyExpansionPercents(
        uint256 _maxSupplyExpansionPercent
    ) external onlyOperator {
        require(
            _maxSupplyExpansionPercent >= 10 &&
                _maxSupplyExpansionPercent <= 1000,
            "_maxSupplyExpansionPercent: out of range"
        ); // [0.1%, 10%]
        maxSupplyExpansionPercent = _maxSupplyExpansionPercent;
    }

    function setSupplyTiersEntry(
        uint8 _index,
        uint256 _value
    ) external onlyOperator returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < 9, "Index has to be lower than count of tiers");
        if (_index > 0) {
            require(_value > supplyTiers[_index - 1]);
        }
        if (_index < 8) {
            require(_value < supplyTiers[_index + 1]);
        }
        supplyTiers[_index] = _value;
        return true;
    }

    function setMaxExpansionTiersEntry(
        uint8 _index,
        uint256 _value
    ) external onlyOperator returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < 9, "Index has to be lower than count of tiers");
        require(_value >= 10 && _value <= 1000, "_value: out of range"); // [0.1%, 10%]
        maxExpansionTiers[_index] = _value;
        return true;
    }

    function setBondDepletionFloorPercent(
        uint256 _bondDepletionFloorPercent
    ) external onlyOperator {
        require(
            _bondDepletionFloorPercent >= 500 &&
                _bondDepletionFloorPercent <= 10000,
            "out of range"
        ); // [5%, 100%]
        bondDepletionFloorPercent = _bondDepletionFloorPercent;
    }

    function setMaxSupplyContractionPercent(
        uint256 _maxSupplyContractionPercent
    ) external onlyOperator {
        require(
            _maxSupplyContractionPercent >= 100 &&
                _maxSupplyContractionPercent <= 1500,
            "out of range"
        ); // [0.1%, 15%]
        maxSupplyContractionPercent = _maxSupplyContractionPercent;
    }

    function setMaxDebtRatioPercent(
        uint256 _maxDebtRatioPercent
    ) external onlyOperator {
        require(
            _maxDebtRatioPercent >= 1000 && _maxDebtRatioPercent <= 10000,
            "out of range"
        ); // [10%, 100%]
        maxDebtRatioPercent = _maxDebtRatioPercent;
    }

    function setBootstrap(
        uint256 _bootstrapEpochs,
        uint256 _bootstrapSupplyExpansionPercent
    ) external onlyOperator {
        require(_bootstrapEpochs <= 120, "_bootstrapEpochs: out of range"); // <= 1 month
        require(
            _bootstrapSupplyExpansionPercent >= 100 &&
                _bootstrapSupplyExpansionPercent <= 1000,
            "_bootstrapSupplyExpansionPercent: out of range"
        ); // [1%, 10%]
        bootstrapEpochs = _bootstrapEpochs;
        bootstrapSupplyExpansionPercent = _bootstrapSupplyExpansionPercent;
    }

    function setExtraFunds(
        address _daoFund,
        uint256 _daoFundSharedPercent,
        address _devFund,
        uint256 _devFundSharedPercent
    ) external onlyOperator {
        require(_daoFund != address(0), "zero");
        require(_daoFundSharedPercent <= 3000, "out of range"); // <= 30%
        require(_devFund != address(0), "zero");
        require(_devFundSharedPercent <= 1000, "out of range"); // <= 10%
        daoFund = _daoFund;
        daoFundSharedPercent = _daoFundSharedPercent;
        devFund = _devFund;
        devFundSharedPercent = _devFundSharedPercent;
    }

    function setMaxDiscountRate(
        uint256 _maxDiscountRate
    ) external onlyOperator {
        maxDiscountRate = _maxDiscountRate;
    }

    function setMaxPremiumRate(uint256 _maxPremiumRate) external onlyOperator {
        maxPremiumRate = _maxPremiumRate;
    }

    function setDiscountPercent(
        uint256 _discountPercent
    ) external onlyOperator {
        require(_discountPercent <= 20000, "_discountPercent is over 200%");
        discountPercent = _discountPercent;
    }

    function setPremiumThreshold(
        uint256 _premiumThreshold
    ) external onlyOperator {
        require(
            _premiumThreshold >= baseRatePriceCeiling,
            "_premiumThreshold exceeds baseRatePriceCeiling"
        );
        require(
            _premiumThreshold <= 150,
            "_premiumThreshold is higher than 1.5"
        );
        premiumThreshold = _premiumThreshold;
    }

    function setPremiumPercent(uint256 _premiumPercent) external onlyOperator {
        require(_premiumPercent <= 20000, "_premiumPercent is over 200%");
        premiumPercent = _premiumPercent;
    }

    function setMintingFactorForPayingDebt(
        uint256 _mintingFactorForPayingDebt
    ) external onlyOperator {
        require(
            _mintingFactorForPayingDebt >= 10000 &&
                _mintingFactorForPayingDebt <= 20000,
            "_mintingFactorForPayingDebt: out of range"
        ); // [100%, 200%]
        mintingFactorForPayingDebt = _mintingFactorForPayingDebt;
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    // function _updateBaseRatePrice() internal {
    //     try IOracle(baseOracle).update() {} catch {}
    // }

    function getBaseRateCirculatingSupply() public view returns (uint256) {
        IERC20 baseRateErc20 = IERC20(baseRate);
        uint256 totalSupply = baseRateErc20.totalSupply();
        uint256 balanceExcluded = 0;
        for (
            uint8 entryId = 0;
            entryId < excludedFromTotalSupply.length;
            ++entryId
        ) {
            balanceExcluded = balanceExcluded.add(
                baseRateErc20.balanceOf(excludedFromTotalSupply[entryId])
            );
        }
        return totalSupply.sub(balanceExcluded);
    }

    function buyBonds(
        uint256 _baseRateAmount,
        uint256 targetPrice
    ) external onlyOneBlock checkCondition checkOperator {
        require(
            _baseRateAmount > 0,
            "Treasury: cannot purchase bonds with zero amount"
        );

        uint256 baseRatePrice = getBaseRatePrice();
        require(baseRatePrice == targetPrice, "Treasury: BRATE price moved");
        require(
            baseRatePrice < baseRatePriceOne, // price < $1
            "Treasury: baseRatePrice not eligible for bond purchase"
        );

        require(
            _baseRateAmount <= epochSupplyContractionLeft,
            "Treasury: not enough bond left to purchase"
        );

        uint256 _rate = getBondDiscountRate();
        require(_rate > 0, "Treasury: invalid bond rate");

        uint256 _bondAmount = _baseRateAmount.mul(_rate).div(1e18);
        uint256 baseRateSupply = getBaseRateCirculatingSupply();
        uint256 newBondSupply = IERC20(bbond).totalSupply().add(_bondAmount);
        require(
            newBondSupply <= baseRateSupply.mul(maxDebtRatioPercent).div(10000),
            "over max debt ratio"
        );

        IBasisAsset(baseRate).burnFrom(msg.sender, _baseRateAmount);
        IBasisAsset(bbond).mint(msg.sender, _bondAmount);

        epochSupplyContractionLeft = epochSupplyContractionLeft.sub(
            _baseRateAmount
        );
        // _updateBaseRatePrice();

        emit BoughtBonds(msg.sender, _baseRateAmount, _bondAmount);
    }

    function redeemBonds(
        uint256 _bondAmount,
        uint256 targetPrice
    ) external onlyOneBlock checkCondition checkOperator {
        require(
            _bondAmount > 0,
            "Treasury: cannot redeem bonds with zero amount"
        );

        uint256 baseRatePrice = getBaseRatePrice();
        require(baseRatePrice == targetPrice, "Treasury: BRATE price moved");
        require(
            baseRatePrice > baseRatePriceCeiling, // price > $1.01
            "Treasury: baseRatePrice not eligible for bond purchase"
        );

        uint256 _rate = getBondPremiumRate();
        require(_rate > 0, "Treasury: invalid bond rate");

        uint256 _baseRateAmount = _bondAmount.mul(_rate).div(1e18);
        require(
            IERC20(baseRate).balanceOf(address(this)) >= _baseRateAmount,
            "Treasury: treasury has no more budget"
        );

        seigniorageSaved = seigniorageSaved.sub(
            Math.min(seigniorageSaved, _baseRateAmount)
        );

        IBasisAsset(bbond).burnFrom(msg.sender, _bondAmount);
        IERC20(baseRate).safeTransfer(msg.sender, _baseRateAmount);

        // _updateBaseRatePrice();

        emit RedeemedBonds(msg.sender, _baseRateAmount, _bondAmount);
    }

    function _sendToBoardroom(uint256 _amount) internal {
        IBasisAsset(baseRate).mint(address(this), _amount);

        uint256 _daoFundSharedAmount = 0;
        if (daoFundSharedPercent > 0) {
            _daoFundSharedAmount = _amount.mul(daoFundSharedPercent).div(10000);
            IERC20(baseRate).transfer(daoFund, _daoFundSharedAmount);
            emit DaoFundFunded(block.timestamp, _daoFundSharedAmount);
        }

        uint256 _devFundSharedAmount = 0;
        if (devFundSharedPercent > 0) {
            _devFundSharedAmount = _amount.mul(devFundSharedPercent).div(10000);
            IERC20(baseRate).transfer(devFund, _devFundSharedAmount);
            emit DevFundFunded(block.timestamp, _devFundSharedAmount);
        }

        _amount = _amount.sub(_daoFundSharedAmount).sub(_devFundSharedAmount);

        IERC20(baseRate).safeApprove(boardroom, 0);
        IERC20(baseRate).safeApprove(boardroom, _amount);
        IBoardroom(boardroom).allocateSeigniorage(_amount);
        emit BoardroomFunded(block.timestamp, _amount);
    }

    function _calculateMaxSupplyExpansionPercent(
        uint256 _baseRateSupply
    ) internal returns (uint256) {
        for (uint8 tierId = 8; tierId >= 0; --tierId) {
            if (_baseRateSupply >= supplyTiers[tierId]) {
                maxSupplyExpansionPercent = maxExpansionTiers[tierId];
                break;
            }
        }
        return maxSupplyExpansionPercent;
    }

    function allocateSeigniorage()
        external
        onlyOneBlock
        checkCondition
        checkEpoch
        checkOperator
    {
        // _updateBaseRatePrice();
        previousEpochBaseRatePrice = getBaseRatePrice();
        uint256 baseRateSupply = getBaseRateCirculatingSupply().sub(
            seigniorageSaved
        );
        if (epoch < bootstrapEpochs) {
            // 28 first epochs with 4.5% expansion
            _sendToBoardroom(
                baseRateSupply.mul(bootstrapSupplyExpansionPercent).div(10000)
            );
        } else {
            if (previousEpochBaseRatePrice > baseRatePriceCeiling) {
                // Expansion ($BRATE Price > 1 $MIM): there is some seigniorage to be allocated
                uint256 bondSupply = IERC20(bbond).totalSupply();
                uint256 _percentage = previousEpochBaseRatePrice.sub(
                    baseRatePriceOne
                );
                uint256 _savedForBond;
                uint256 _savedForBoardroom;
                uint256 _mse = _calculateMaxSupplyExpansionPercent(
                    baseRateSupply
                ).mul(1e14);
                if (_percentage > _mse) {
                    _percentage = _mse;
                }
                if (
                    seigniorageSaved >=
                    bondSupply.mul(bondDepletionFloorPercent).div(10000)
                ) {
                    // saved enough to pay debt, mint as usual rate
                    _savedForBoardroom = baseRateSupply.mul(_percentage).div(
                        1e18
                    );
                } else {
                    // have not saved enough to pay debt, mint more
                    uint256 _seigniorage = baseRateSupply.mul(_percentage).div(
                        1e18
                    );
                    _savedForBoardroom = _seigniorage
                        .mul(seigniorageExpansionFloorPercent)
                        .div(10000);
                    _savedForBond = _seigniorage.sub(_savedForBoardroom);
                    if (mintingFactorForPayingDebt > 0) {
                        _savedForBond = _savedForBond
                            .mul(mintingFactorForPayingDebt)
                            .div(10000);
                    }
                }
                if (_savedForBoardroom > 0) {
                    _sendToBoardroom(_savedForBoardroom);
                }
                if (_savedForBond > 0) {
                    seigniorageSaved = seigniorageSaved.add(_savedForBond);
                    IBasisAsset(baseRate).mint(address(this), _savedForBond);
                    emit TreasuryFunded(block.timestamp, _savedForBond);
                }
            }
        }
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        // do not allow to drain core tokens
        require(address(_token) != address(baseRate), "baseRate");
        require(address(_token) != address(bbond), "bond");
        _token.safeTransfer(_to, _amount);
    }

    function boardroomSetOperator(address _operator) external onlyOperator {
        IBoardroom(boardroom).setOperator(_operator);
    }

    function boardroomSetLockUp(
        uint256 _withdrawLockupEpochs,
        uint256 _rewardLockupEpochs
    ) external onlyOperator {
        IBoardroom(boardroom).setLockUp(
            _withdrawLockupEpochs,
            _rewardLockupEpochs
        );
    }

    function boardroomAllocateSeigniorage(
        uint256 amount
    ) external onlyOperator {
        IBoardroom(boardroom).allocateSeigniorage(amount);
    }

    function boardroomGovernanceRecoverUnsupported(
        address _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        IBoardroom(boardroom).governanceRecoverUnsupported(
            _token,
            _amount,
            _to
        );
    }
}

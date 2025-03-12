// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../interfaces/IDollar.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IPool.sol";
import "../interfaces/ICollateralReserve.sol";
import "../interfaces/IBasisAsset.sol";

contract Pool is OwnableUpgradeSafe, ReentrancyGuard, IPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== ADDRESSES ================ */
    address[] public collaterals;
    address public dollar;
    address public dark;
    address public share;
    address public treasury;

    address public oracleDollar;
    address public oracleDark;
    address public oracleShare;
    address[] public oracleCollaterals;

    /* ========== STATE VARIABLES ========== */

    mapping(address => uint256) public redeem_dark_balances;
    mapping(address => uint256) public redeem_share_balances;
    mapping(address => mapping(uint256 => uint256)) public redeem_collateral_balances;

    uint256[] private unclaimed_pool_collaterals_;
    uint256 private unclaimed_pool_dark_;
    uint256 private unclaimed_pool_share_;

    mapping(address => uint256) public last_redeemed;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;

    // Number of decimals needed to get to 18
    uint256[] private missing_decimals;

    // Number of seconds to wait before being able to collectRedemption()
    uint256 public redemption_delay;

    // AccessControl state variables
    bool public mint_paused = false;
    bool public redeem_paused = false;
    bool public contract_allowed = false;
    mapping(address => bool) public whitelisted;

    uint256 private targetCollateralRatio_;
    uint256 private targetDarkOverDarkShareRatio_;

    uint256 public updateStepTargetCR;
    uint256 public updateStepTargetDODSR;

    uint256 public updateCoolingTimeTargetCR;
    uint256 public updateCoolingTimeTargetDODSR;

    uint256 public lastUpdatedTargetCR;
    uint256 public lastUpdatedTargetDODSR;

    mapping(address => bool) public strategist;

    uint256 public constant T_ZERO_TIMESTAMP = 1646092800; // (Tuesday, 1 March 2022 00:00:00 GMT+0)

    mapping(uint256 => uint256) public totalMintedHourly; // hour_index => total_minted
    mapping(uint256 => uint256) public totalMintedDaily; // day_index => total_minted
    mapping(uint256 => uint256) public totalRedeemedHourly; // hour_index => total_redeemed
    mapping(uint256 => uint256) public totalRedeemedDaily; // day_index => total_redeemed

    uint256 private mintingLimitOnce_;
    uint256 private mintingLimitHourly_;
    uint256 private mintingLimitDaily_;

    address private shareFarmingPool_ = address(0x63Df75d039f7d7A8eE4A9276d6A9fE7990D7A6C5);

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    // ...

    /* ========== EVENTS ========== */

    event TreasuryUpdated(address indexed newTreasury);
    event StrategistStatusUpdated(address indexed account, bool status);
    event MintPausedUpdated(bool mint_paused);
    event RedeemPausedUpdated(bool redeem_paused);
    event ContractAllowedUpdated(bool contract_allowed);
    event WhitelistedUpdated(address indexed account, bool whitelistedStatus);
    event SetMintingLimits(uint256 _mintingLimitOnce, uint256 _mintingLimitHourly, uint256 _mintingLimitDaily);
    event SetOracleDollar(address _oracleDollar);
    event SetOracleDark(address _oracleDark);
    event SetOracleShare(address _oracleShare);
    event SetOracleCollaterals(address[] _oracleCollaterals);
    event SetOracleCollateral(uint256 _index, address _oracleCollateral);
    event SetRedemptionDelay(uint256 _redemption_delay);
    event SetTargetCollateralRatioConfig(uint256 _updateStepTargetCR, uint256 _updateCoolingTimeTargetCR);
    event SetTargetDarkOverShareRatioConfig(uint256 _updateStepTargetDODSR, uint256 _updateCoolingTimeTargetDODSR);
    event TargetCollateralRatioUpdated(uint256 targetCollateralRatio_);
    event TargetDarkOverShareRatioUpdated(uint256 targetDarkOverDarkShareRatio_);
    event Mint(address indexed account, uint256 dollarAmount, uint256[] collateralAmounts, uint256 darkAmount, uint256 shareAmount, uint256 darkFee, uint256 shareFee);
    event Redeem(address indexed account, uint256 dollarAmount, uint256[] collateralAmounts, uint256 darkAmount, uint256 shareAmount, uint256 darkFee, uint256 shareFee);
    event CollectRedemption(address indexed account, uint256[] collateralAmounts, uint256 darkAmount, uint256 shareAmount);

    /* ========== MODIFIERS ========== */

    modifier onlyTreasury() {
        require(msg.sender == treasury, "!treasury");
        _;
    }

    modifier onlyTreasuryOrOwner() {
        require(msg.sender == treasury || msg.sender == owner(), "!treasury && !owner");
        _;
    }

    modifier onlyStrategist() {
        require(strategist[msg.sender] || msg.sender == treasury || msg.sender == owner(), "!strategist && !treasury && !owner");
        _;
    }

    modifier checkContract() {
        if (!contract_allowed && !whitelisted[msg.sender]) {
            uint256 size;
            address addr = msg.sender;
            assembly {
                size := extcodesize(addr)
            }
            require(size == 0, "contract not allowed");
            require(tx.origin == msg.sender, "contract not allowed");
        }
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _dollar,
        address _dark,
        address _share,
        address[] memory _collaterals,
        address _treasury
    ) external initializer {
        require(_collaterals.length == 3, "invalid collaterals length");
        OwnableUpgradeSafe.__Ownable_init();

        dollar = _dollar; // DUSD
        dark = _dark; // DARK
        share = _share; // NESS
        collaterals = _collaterals; // USDC, USDT, DAI
        treasury = _treasury;
        oracleCollaterals = new address[](3);
        unclaimed_pool_collaterals_ = new uint256[](3);
        unclaimed_pool_dark_ = 0;
        unclaimed_pool_share_ = 0;
        missing_decimals = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            missing_decimals[i] = uint256(18).sub(uint256(IBasisAsset(_collaterals[i]).decimals()));
            unclaimed_pool_collaterals_[i] = 0;
        }

        targetCollateralRatio_ = 9000; // 90%
        targetDarkOverDarkShareRatio_ = 5000; // 50/50

        lastUpdatedTargetCR = block.timestamp;
        lastUpdatedTargetDODSR = block.timestamp;

        updateStepTargetCR = 25; // 0.25%
        updateStepTargetDODSR = 100; // 1%

        updateCoolingTimeTargetCR = 3000; // update every hour
        updateCoolingTimeTargetDODSR = 13800; // update every 4 hours

        mintingLimitOnce_ = 50000 ether;
        mintingLimitHourly_ = 100000 ether;
        mintingLimitDaily_ = 1000000 ether;

        redemption_delay = 30;
        mint_paused = false;
        redeem_paused = false;
        contract_allowed = false;
    }

    /* ========== VIEWS ========== */

    function info()
        external
        view
        returns (
            uint256[] memory,
            uint256,
            uint256,
            uint256,
            bool,
            bool
        )
    {
        return (
            unclaimed_pool_collaterals_, // unclaimed amount of COLLATERALs
            unclaimed_pool_dark_, // unclaimed amount of DARK
            unclaimed_pool_share_, // unclaimed amount of SHARE
            PRICE_PRECISION, // collateral price
            mint_paused,
            redeem_paused
        );
    }

    function targetCollateralRatio() external override view returns (uint256) {
        return targetCollateralRatio_;
    }

    function targetDarkOverDarkShareRatio() external override view returns (uint256) {
        return targetDarkOverDarkShareRatio_;
    }

    function unclaimed_pool_collateral(uint256 _index) external override view returns (uint256) {
        return unclaimed_pool_collaterals_[_index];
    }

    function unclaimed_pool_dark() external override view returns (uint256) {
        return unclaimed_pool_dark_;
    }

    function unclaimed_pool_share() external override view returns (uint256) {
        return unclaimed_pool_share_;
    }

    function collateralReserve() public view returns (address) {
        return ITreasury(treasury).collateralReserve();
    }

    function getCollateralPrice(uint256 _index) public view override returns (uint256) {
        address _oracle = oracleCollaterals[_index];
        return (_oracle == address(0)) ? PRICE_PRECISION : IOracle(_oracle).consult();
    }

    function getDollarPrice() public view override returns (uint256) {
        address _oracle = oracleDollar;
        return (_oracle == address(0)) ? PRICE_PRECISION : IOracle(_oracle).consult(); // DOLLAR: default = 1$
    }

    function getDarkPrice() public view override returns (uint256) {
        address _oracle = oracleDark;
        return (_oracle == address(0)) ? PRICE_PRECISION / 2 : IOracle(_oracle).consult(); // DARK: default = 0.5$
    }

    function getSharePrice() public view override returns (uint256) {
        address _oracle = oracleShare;
        return (_oracle == address(0)) ? PRICE_PRECISION * 2 / 5 : IOracle(_oracle).consult(); // NESS: default = 0.4$
    }

    function getTrueSharePrice() public view returns (uint256) {
        address _oracle = oracleShare;
        return (_oracle == address(0)) ? PRICE_PRECISION / 5 : IOracle(_oracle).consultTrue(); // NESS: default = 0.2$
    }

    function getRedemptionOpenTime(address _account) public view override returns (uint256) {
        uint256 _last_redeemed = last_redeemed[_account];
        return (_last_redeemed == 0) ? 0 : _last_redeemed.add(redemption_delay);
    }

    function mintingLimitOnce() public view returns (uint256 _limit) {
        _limit = mintingLimitOnce_;
        if (_limit > 0) {
            _limit = Math.max(_limit, IERC20(dollar).totalSupply().mul(25).div(10000)); // Max(50k, 0.25% of total supply)
        }
    }

    function mintingLimitHourly() public override view returns (uint256 _limit) {
        _limit = mintingLimitHourly_;
        if (_limit > 0) {
            _limit = Math.max(_limit, IERC20(dollar).totalSupply().mul(50).div(10000)); // Max(100K, 0.5% of total supply)
        }
    }

    function mintingLimitDaily() public override view returns (uint256 _limit) {
        _limit = mintingLimitDaily_;
        if (_limit > 0) {
            _limit = Math.max(_limit, IERC20(dollar).totalSupply().mul(500).div(10000)); // Max(1M, 5% of total supply)
        }
    }

    function calcMintableDollarHourly() public override view returns (uint256 _limit) {
        uint256 _mintingLimitHourly = mintingLimitHourly();
        if (_mintingLimitHourly == 0) {
            _limit = 1000000 ether;
        } else {
            uint256 _hourIndex = block.timestamp.sub(T_ZERO_TIMESTAMP).div(1 hours);
            uint256 _totalMintedHourly = totalMintedHourly[_hourIndex];
            if (_totalMintedHourly < _mintingLimitHourly) {
                _limit = _mintingLimitHourly.sub(_totalMintedHourly);
            }
        }
    }

    function calcMintableDollarDaily() public override view returns (uint256 _limit) {
        uint256 _mintingLimitDaily = mintingLimitDaily();
        if (_mintingLimitDaily == 0) {
            _limit = 1000000 ether;
        } else {
            uint256 _dayIndex = block.timestamp.sub(T_ZERO_TIMESTAMP).div(1 days);
            uint256 _totalMintedDaily = totalMintedDaily[_dayIndex];
            if (_totalMintedDaily < _mintingLimitDaily) {
                _limit = _mintingLimitDaily.sub(_totalMintedDaily);
            }
        }
    }

    function calcMintableDollar() public override view returns (uint256 _dollarAmount) {
        uint256 _mintingLimitOnce = mintingLimitOnce();
        _dollarAmount = (_mintingLimitOnce == 0) ? 1000000 ether : _mintingLimitOnce;
        if (_dollarAmount > 0) _dollarAmount = Math.min(_dollarAmount, calcMintableDollarHourly());
        if (_dollarAmount > 0) _dollarAmount = Math.min(_dollarAmount, calcMintableDollarDaily());
    }

    function calcRedeemableDollarHourly() public override view returns (uint256 _limit) {
        uint256 _mintingLimitHourly = mintingLimitHourly();
        if (_mintingLimitHourly == 0) {
            _limit = 1000000 ether;
        } else {
            uint256 _hourIndex = block.timestamp.sub(T_ZERO_TIMESTAMP).div(1 hours);
            uint256 _totalRedeemedHourly = totalRedeemedHourly[_hourIndex];
            if (_totalRedeemedHourly < _mintingLimitHourly) {
                _limit = _mintingLimitHourly.sub(_totalRedeemedHourly);
            }
        }
    }

    function calcRedeemableDollarDaily() public override view returns (uint256 _limit) {
        uint256 _mintingLimitDaily = mintingLimitDaily();
        if (_mintingLimitDaily == 0) {
            _limit = 1000000 ether;
        } else {
            uint256 _dayIndex = block.timestamp.sub(T_ZERO_TIMESTAMP).div(1 days);
            uint256 _totalRedeemedDaily = totalRedeemedDaily[_dayIndex];
            if (_totalRedeemedDaily < _mintingLimitDaily) {
                _limit = _mintingLimitDaily.sub(_totalRedeemedDaily);
            }
        }
    }

    function calcRedeemableDollar() public override view returns (uint256 _dollarAmount) {
        uint256 _mintingLimitOnce = mintingLimitOnce();
        _dollarAmount = (_mintingLimitOnce == 0) ? 1000000 ether : _mintingLimitOnce;
        if (_dollarAmount > 0) _dollarAmount = Math.min(_dollarAmount, calcRedeemableDollarHourly());
        if (_dollarAmount > 0) _dollarAmount = Math.min(_dollarAmount, calcRedeemableDollarDaily());
    }

    function calcTotalCollateralValue(uint256[] memory _collateralAmounts) public view returns (uint256 _totalCollateralValue) {
        for (uint256 i = 0; i < 3; i++) {
            _totalCollateralValue = _totalCollateralValue.add(_collateralAmounts[i].mul(10 ** missing_decimals[i]).mul(getCollateralPrice(i)).div(PRICE_PRECISION));
        }
    }

    function calcTotalMainCollateralAmount(uint256[] memory _collateralAmounts) public view returns (uint256 _totalMainCollateralAmount) {
        uint256 _totalCollateralValue = calcTotalCollateralValue(_collateralAmounts);
        _totalMainCollateralAmount = _totalCollateralValue.mul(PRICE_PRECISION).div(getCollateralPrice(0)).div(10 ** missing_decimals[0]);
    }

    function calcMintInput(uint256 _dollarAmount) public view override returns (uint256 _mainCollateralAmount, uint256 _darkAmount, uint256 _shareAmount,
        uint256 _darkFee, uint256 _shareFee) {
        uint256 _collateral_price = getCollateralPrice(0);
        uint256 _dark_price = getDarkPrice();
        uint256 _share_price = getTrueSharePrice();
        uint256 _targetCollateralRatio = targetCollateralRatio_;

        uint256 _dollarFullValue = _dollarAmount.mul(_collateral_price).div(PRICE_PRECISION);
        uint256 _collateralFullValue = _dollarFullValue.mul(_targetCollateralRatio).div(10000);
        _mainCollateralAmount = _collateralFullValue.mul(PRICE_PRECISION).div(_collateral_price).div(10 ** missing_decimals[0]);

        uint256 _required_darkShareValue = _dollarFullValue.sub(_collateralFullValue);

        uint256 _required_darkValue = _required_darkShareValue.mul(targetDarkOverDarkShareRatio_).div(10000);
        uint256 _required_shareValue = _required_darkShareValue.sub(_required_darkValue);

        uint256 _mintingFee = ITreasury(treasury).minting_fee();
        uint256 _feePercentOnDarkShare = _mintingFee.mul(10000).div(uint256(10000).sub(_targetCollateralRatio));
        {
            uint256 _required_darkAmount = _required_darkValue.mul(PRICE_PRECISION).div(_dark_price);
            _darkFee = _required_darkAmount.mul(_feePercentOnDarkShare).div(10000);
            _darkAmount = _required_darkAmount.add(_darkFee);
        }
        {
            uint256 _required_shareAmount = _required_shareValue.mul(PRICE_PRECISION).div(_share_price);
            _shareFee = _required_shareAmount.mul(_feePercentOnDarkShare).div(10000);
            _shareAmount = _required_shareAmount.add(_shareFee);
        }
    }

    function calcMintOutputFromCollaterals(uint256[] memory _collateralAmounts) public view override returns (uint256 _dollarAmount, uint256 _darkAmount, uint256 _shareAmount,
        uint256 _darkFee, uint256 _shareFee) {
        uint256 _collateral_price = getCollateralPrice(0);
        uint256 _dark_price = getDarkPrice();
        uint256 _share_price = getTrueSharePrice();
        uint256 _targetCollateralRatio = targetCollateralRatio_;

        uint256 _collateralFullValue = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint256 _collateralAmount = _collateralAmounts[i];
            _collateralFullValue = _collateralFullValue.add(_collateralAmount.mul(10 ** missing_decimals[i]).mul(getCollateralPrice(i)).div(PRICE_PRECISION));
        }

        uint256 _dollarFullValue = _collateralFullValue.mul(10000).div(_targetCollateralRatio);
        _dollarAmount = _dollarFullValue.mul(PRICE_PRECISION).div(_collateral_price);

        uint256 _required_darkShareValue = _dollarFullValue.sub(_collateralFullValue);

        uint256 _required_darkValue = _required_darkShareValue.mul(targetDarkOverDarkShareRatio_).div(10000);
        uint256 _required_shareValue = _required_darkShareValue.sub(_required_darkValue);
        uint256 _mintingFee = ITreasury(treasury).minting_fee();
        uint256 _feePercentOnDarkShare = _mintingFee.mul(10000).div(uint256(10000).sub(_targetCollateralRatio));
        {
            uint256 _required_darkAmount = _required_darkValue.mul(PRICE_PRECISION).div(_dark_price);
            _darkFee = _required_darkAmount.mul(_feePercentOnDarkShare).div(10000);
            _darkAmount = _required_darkAmount.add(_darkFee);
        }
        {
            uint256 _required_shareAmount = _required_shareValue.mul(PRICE_PRECISION).div(_share_price);
            _shareFee = _required_shareAmount.mul(_feePercentOnDarkShare).div(10000);
            _shareAmount = _required_shareAmount.add(_shareFee);
        }
    }

    function calcMintOutputFromDark(uint256 _darkAmount) public view override returns (uint256 _dollarAmount, uint256 _mainCollateralAmount, uint256 _shareAmount,
        uint256 _darkFee, uint256 _shareFee) {
        if (_darkAmount > 0) {
            uint256 _dark_price = getDarkPrice();
            uint256 _share_price = getTrueSharePrice();
            {
                uint256 _required_darkValue = _darkAmount.mul(_dark_price).div(PRICE_PRECISION);
                uint256 _required_darkShareValue = _required_darkValue.mul(10000).div(targetDarkOverDarkShareRatio_);
                uint256 _required_shareValue = _required_darkShareValue.sub(_required_darkValue);
                _shareAmount = _required_shareValue.mul(PRICE_PRECISION).div(_share_price).add(1);
            }
            uint256 _targetReverseCR = uint256(10000).sub(targetCollateralRatio_);
            uint256 _darkShareFullValueWithoutFee;
            {
                uint256 _feePercentOnDarkShare = ITreasury(treasury).minting_fee().mul(10000).div(_targetReverseCR);
                uint256 _darkAmountWithoutFee = _darkAmount.mul(10000).div(_feePercentOnDarkShare.add(10000));
                if (_darkAmountWithoutFee > 1) _darkAmountWithoutFee = _darkAmountWithoutFee - 1;
                _darkFee = _darkAmount.sub(_darkAmountWithoutFee);
                uint256 _darkFullValueWithoutFee = _darkAmountWithoutFee.mul(_dark_price).div(PRICE_PRECISION);
                _darkShareFullValueWithoutFee = _darkFullValueWithoutFee.mul(10000).div(targetDarkOverDarkShareRatio_);
                uint256 _shareFullValueWithoutFee = _darkShareFullValueWithoutFee.sub(_darkFullValueWithoutFee);
                _shareFee = _shareAmount.sub(_shareFullValueWithoutFee.mul(PRICE_PRECISION).div(_share_price));
            }
            {
                uint256 _dollarFullValue = _darkShareFullValueWithoutFee.mul(10000).div(_targetReverseCR);
                uint256 _collateral_price = getCollateralPrice(0);
                _dollarAmount = _dollarFullValue.mul(PRICE_PRECISION).div(_collateral_price);

                uint256 _collateralFullValue = _dollarFullValue.sub(_darkShareFullValueWithoutFee);
                _mainCollateralAmount = _collateralFullValue.div(10 ** missing_decimals[0]).mul(PRICE_PRECISION).div(_collateral_price);
            }
        }
    }

    function calcMintOutputFromShare(uint256 _shareAmount) public view override returns (uint256 _dollarAmount, uint256 _mainCollateralAmount, uint256 _darkAmount,
        uint256 _darkFee, uint256 _shareFee) {
        if (_shareAmount > 0) {
            uint256 _dark_price = getDarkPrice();
            uint256 _share_price = getTrueSharePrice();
            uint256 _targetShareOverDarkShareRatio = uint256(10000).sub(targetDarkOverDarkShareRatio_);
            {
                uint256 _required_shareValue = _shareAmount.mul(_share_price).div(PRICE_PRECISION);
                uint256 _required_darkShareValue = _required_shareValue.mul(10000).div(_targetShareOverDarkShareRatio);
                uint256 _required_darkValue = _required_darkShareValue.sub(_required_shareValue);
                _darkAmount = _required_darkValue.mul(PRICE_PRECISION).div(_dark_price).add(1);
            }
            uint256 _targetReverseCR = uint256(10000).sub(targetCollateralRatio_);
            uint256 _darkShareFullValueWithoutFee;
            {
                uint256 _feePercentOnDarkShare = ITreasury(treasury).minting_fee().mul(10000).div(_targetReverseCR);
                uint256 _shareAmountWithoutFee = _shareAmount.mul(10000);
                _shareAmountWithoutFee = _shareAmountWithoutFee.div(_feePercentOnDarkShare.add(10000));
                if (_shareAmountWithoutFee > 1) _shareAmountWithoutFee = _shareAmountWithoutFee - 1;
                _shareFee = _shareAmount.sub(_shareAmountWithoutFee);
                uint256 _shareFullValueWithoutFee = _shareAmountWithoutFee.mul(_share_price).div(PRICE_PRECISION);
                _darkShareFullValueWithoutFee = _shareFullValueWithoutFee.mul(10000).div(_targetShareOverDarkShareRatio);
                uint256 _darkFullValueWithoutFee = _darkShareFullValueWithoutFee.sub(_shareFullValueWithoutFee);
                _darkFee = _darkAmount.sub(_darkFullValueWithoutFee.mul(PRICE_PRECISION).div(_dark_price));
            }
            {
                uint256 _dollarFullValue = _darkShareFullValueWithoutFee.mul(10000).div(_targetReverseCR);
                uint256 _collateral_price = getCollateralPrice(0);
                _dollarAmount = _dollarFullValue.mul(PRICE_PRECISION).div(_collateral_price);

                uint256 _collateralFullValue = _dollarFullValue.sub(_darkShareFullValueWithoutFee);
                _mainCollateralAmount = _collateralFullValue.div(10 ** missing_decimals[0]).mul(PRICE_PRECISION).div(_collateral_price);
            }
        }
    }

    function calcRedeemOutput(uint256 _dollarAmount) public view override returns (uint256[] memory _collateralAmounts, uint256 _darkAmount, uint256 _shareAmount,
        uint256 _darkFee, uint256 _shareFee) {
        uint256 _outputRatio = _dollarAmount.mul(1e18).div(IERC20(dollar).totalSupply());
        uint256 _collateralFullValue = 0;
        {
            _collateralAmounts = new uint256[](3);
            for (uint256 i = 0; i < 3; i++) {
                uint256 _collateral_bal = ITreasury(treasury).globalCollateralBalance(i);
                uint256 _collateralAmount = _collateral_bal.mul(_outputRatio).div(1e18);
                _collateralAmounts[i] = _collateralAmount;
                _collateralFullValue = _collateralFullValue.add(_collateralAmount.mul(10 ** missing_decimals[i]).mul(getCollateralPrice(i)).div(PRICE_PRECISION));
            }
        }
        uint256 _currentReverseCR;
        {
            uint256 _dollarFullValue = _dollarAmount.mul(getCollateralPrice(0)).div(PRICE_PRECISION);
            _currentReverseCR = (_dollarFullValue <= _collateralFullValue) ? 0 : _dollarFullValue.sub(_collateralFullValue).mul(10000).div(_dollarFullValue);
        }

        uint256 _dark_bal = ITreasury(treasury).globalDarkBalance();
        uint256 _share_bal = ITreasury(treasury).globalShareBalance();
        uint256 _dark_out = _dark_bal.mul(_outputRatio).div(1e18);
        uint256 _share_out = _share_bal.mul(_outputRatio).div(1e18);

        uint256 _redemptionFee = ITreasury(treasury).redemption_fee();
        if (_currentReverseCR == 0) {
            _darkFee = _dark_out;
            _shareFee = _share_out;
        } else {
            uint256 _feePercentOnDarkShare = _redemptionFee.mul(10000).div(_currentReverseCR);

            _darkFee = _dark_out.mul(_feePercentOnDarkShare).div(10000);
            _shareFee = _share_out.mul(_feePercentOnDarkShare).div(10000);
            _darkAmount = _dark_out.sub(_darkFee);
            _shareAmount = _share_out.sub(_shareFee);
        }
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _increaseMintedStats(uint256 _dollarAmount) internal {
        uint256 _hourIndex = block.timestamp.sub(T_ZERO_TIMESTAMP).div(1 hours);
        uint256 _dayIndex = block.timestamp.sub(T_ZERO_TIMESTAMP).div(1 days);
        totalMintedHourly[_hourIndex] = totalMintedHourly[_hourIndex].add(_dollarAmount);
        totalMintedDaily[_dayIndex] = totalMintedDaily[_dayIndex].add(_dollarAmount);
    }

    function _increaseRedeemedStats(uint256 _dollarAmount) internal {
        uint256 _hourIndex = block.timestamp.sub(T_ZERO_TIMESTAMP).div(1 hours);
        uint256 _dayIndex = block.timestamp.sub(T_ZERO_TIMESTAMP).div(1 days);
        totalRedeemedHourly[_hourIndex] = totalRedeemedHourly[_hourIndex].add(_dollarAmount);
        totalRedeemedDaily[_dayIndex] = totalRedeemedDaily[_dayIndex].add(_dollarAmount);
    }

    function mint(
        uint256[] memory _collateralAmounts,
        uint256 _darkAmount,
        uint256 _shareAmount,
        uint256 _dollarOutMin
    ) external checkContract nonReentrant returns (uint256 _dollarOut, uint256[] memory _required_collateralAmounts, uint256 _required_darkAmount, uint256 _required_shareAmount,
        uint256 _darkFee, uint256 _shareFee) {
        require(mint_paused == false, "Minting is paused");
        uint256 _mintableDollarLimit = calcMintableDollar().add(100);
        require(_dollarOutMin < _mintableDollarLimit, "over minting cap");
        trimExtraToTreasury();
        uint256 _totalMainCollateralAmount = calcTotalMainCollateralAmount(_collateralAmounts);
        uint256 _mainCollateralAmount;

        (_dollarOut, _required_darkAmount, _required_shareAmount, _darkFee, _shareFee) = calcMintOutputFromCollaterals(_collateralAmounts);
        if (_required_shareAmount >= _shareAmount.add(100)) {
            (_dollarOut, _mainCollateralAmount, _required_darkAmount, _darkFee, _shareFee) = calcMintOutputFromShare(_shareAmount);
            require(_mainCollateralAmount <= _totalMainCollateralAmount, "invalid input quantities");
        }
        require(_dollarOut >= _dollarOutMin, "slippage");
        require(_dollarOut < _mintableDollarLimit, "over minting cap");

        (_mainCollateralAmount, _required_darkAmount, _required_shareAmount, _darkFee, _shareFee) = calcMintInput(_dollarOut);
        require(_mainCollateralAmount <= _totalMainCollateralAmount, "Not enough _collateralAmount"); // plus some dust for overflow
        require(_mainCollateralAmount.mul(13000).div(10000) >= _totalMainCollateralAmount, "_totalMainCollateralAmount is too big for _dollarOut");
        require(_required_darkAmount <= _darkAmount.add(100), "Not enough _darkAmount"); // plus some dust for overflow
        require(_required_shareAmount <= _shareAmount.add(100), "Not enough _shareAmount"); // plus some dust for overflow
        require(_dollarOut <= _totalMainCollateralAmount.mul(10 ** missing_decimals[0]).mul(13000).div(10000), "Insanely big _dollarOut"); // double check - we dont want to mint too much dollar

        _required_collateralAmounts = new uint256[](3);
        uint256 _slippageAmount = _totalMainCollateralAmount.sub(_mainCollateralAmount);
        if (_collateralAmounts[0] > _slippageAmount) {
            _required_collateralAmounts[0] = _collateralAmounts[0].sub(_slippageAmount);
        }
        _required_collateralAmounts[1] = _collateralAmounts[1];
        _required_collateralAmounts[2] = _collateralAmounts[2];

        for (uint256 i = 0; i < 3; i++) {
            _transferToReserve(collaterals[i], msg.sender, _required_collateralAmounts[i], 0);
        }
        _transferToReserve(dark, msg.sender, _required_darkAmount, _darkFee);
        _transferToReserve(share, msg.sender, _required_shareAmount, _shareFee);
        IDollar(dollar).poolMint(msg.sender, _dollarOut);
        _increaseMintedStats(_dollarOut);
        emit Mint(msg.sender, _dollarOut, _required_collateralAmounts, _required_darkAmount, _required_shareAmount, _darkFee, _shareFee);
    }

    function redeem(
        uint256 _dollarAmount,
        uint256[] memory _collateral_out_mins,
        uint256 _dark_out_min,
        uint256 _share_out_min
    ) external checkContract nonReentrant returns (uint256[] memory _collateral_outs, uint256 _dark_out, uint256 _share_out,
        uint256 _darkFee, uint256 _shareFee) {
        require(redeem_paused == false, "Redeeming is paused");
        uint256 _redeemableDollarLimit = calcRedeemableDollar().add(100);
        require(_dollarAmount < _redeemableDollarLimit, "over redeeming cap");
        trimExtraToTreasury();

        (_collateral_outs, _dark_out, _share_out, _darkFee, _shareFee) = calcRedeemOutput(_dollarAmount);
        require(_dark_out >= _dark_out_min, "short of dark");
        require(_share_out >= _share_out_min, "short of share");
        uint256 _totalCollateralValue = calcTotalCollateralValue(_collateral_outs);
        require(_totalCollateralValue <= _dollarAmount.mul(10100).div(10000), "Insanely big _collateral_out"); // double check - we dont want to redeem too much collateral

        for (uint256 i = 0; i < 3; i++) {
            uint256 _collateral_out = _collateral_outs[i];
            require(_collateral_out >= _collateral_out_mins[i], "short of collateral");
            redeem_collateral_balances[msg.sender][i] = redeem_collateral_balances[msg.sender][i].add(_collateral_out);
            unclaimed_pool_collaterals_[i] = unclaimed_pool_collaterals_[i].add(_collateral_out);
        }

        if (_dark_out > 0) {
            redeem_dark_balances[msg.sender] = redeem_dark_balances[msg.sender].add(_dark_out);
            unclaimed_pool_dark_ = unclaimed_pool_dark_.add(_dark_out);
        }

        if (_share_out > 0) {
            redeem_share_balances[msg.sender] = redeem_share_balances[msg.sender].add(_share_out);
            unclaimed_pool_share_ = unclaimed_pool_share_.add(_share_out);
        }

        IDollar(dollar).poolBurnFrom(msg.sender, _dollarAmount);

        ITreasury _treasury = ITreasury(treasury);
        _treasury.requestBurnShare(_shareFee);
        _treasury.requestTransferDarkFee(_darkFee);

        last_redeemed[msg.sender] = block.timestamp;
        _increaseRedeemedStats(_dollarAmount);
        emit Redeem(msg.sender, _dollarAmount, _collateral_outs, _dark_out, _share_out, _darkFee, _shareFee);
    }

    function collectRedemption() external {
        require(getRedemptionOpenTime(msg.sender) <= block.timestamp, "too early");
        trimExtraToTreasury();

        uint256[] memory _collateralAmounts = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            uint256 _collateralAmount = redeem_collateral_balances[msg.sender][i];
            _collateralAmounts[i] = _collateralAmount;
            if (_collateralAmount > 0) {
                redeem_collateral_balances[msg.sender][i] = 0;
                unclaimed_pool_collaterals_[i] = unclaimed_pool_collaterals_[i].sub(_collateralAmount);
                _requestTransferFromReserve(collaterals[i], msg.sender, _collateralAmount);
            }
        }

        uint256 _darkAmount = redeem_dark_balances[msg.sender];
        if (_darkAmount > 0) {
            redeem_dark_balances[msg.sender] = 0;
            unclaimed_pool_dark_ = unclaimed_pool_dark_.sub(_darkAmount);
            _requestTransferFromReserve(dark, msg.sender, _darkAmount);
        }

        uint256 _shareAmount = redeem_share_balances[msg.sender];
        if (_shareAmount > 0) {
            redeem_share_balances[msg.sender] = 0;
            unclaimed_pool_share_ = unclaimed_pool_share_.sub(_shareAmount);
            _requestTransferFromReserve(share, msg.sender, _shareAmount);
        }

        emit CollectRedemption(msg.sender, _collateralAmounts, _darkAmount, _shareAmount);
    }

    function trimExtraToTreasury() public returns (uint256 _collateralAmount, uint256 _darkAmount, uint256 _shareAmount) {
        uint256 _collateral_price = getCollateralPrice(0);
        uint256 _total_dollar_FullValue = IERC20(dollar).totalSupply().mul(_collateral_price).div(PRICE_PRECISION);
        ITreasury _treasury = ITreasury(treasury);
        uint256 _totalCollateralValue = _treasury.globalCollateralTotalValue();
        uint256 _dark_bal = _treasury.globalDarkBalance();
        uint256 _share_bal = _treasury.globalShareBalance();
        address _profitSharingFund = _treasury.profitSharingFund();
        if (_totalCollateralValue > _total_dollar_FullValue) {
            _collateralAmount = _totalCollateralValue.sub(_total_dollar_FullValue).div(10 ** missing_decimals[0]).mul(PRICE_PRECISION).div(_collateral_price);
            if (_collateralAmount > 0) {
                uint256 _mainCollateralBal = _treasury.globalCollateralBalance(0);
                if (_collateralAmount > _mainCollateralBal) _collateralAmount = _mainCollateralBal;
                _requestTransferFromReserve(collaterals[0], _profitSharingFund, _collateralAmount);
            }
            if (_dark_bal > 0) {
                _darkAmount = _dark_bal;
                _requestTransferFromReserve(dark, _profitSharingFund, _darkAmount);
            }
            if (_share_bal > 0) {
                _shareAmount = _share_bal;
                _requestTransferFromReserve(share, _profitSharingFund, _shareAmount);
            }
        } else {
            uint256 _dark_price = getDarkPrice();
            uint256 _share_price = getTrueSharePrice();
            uint256 _total_reserve_value = _totalCollateralValue.add(_dark_bal.mul(_dark_price).div(PRICE_PRECISION)).add(_share_bal.mul(_share_price).div(PRICE_PRECISION));
            if (_total_reserve_value > _total_dollar_FullValue) {
                uint256 _extra_value_from_reserve = _total_reserve_value.sub(_total_dollar_FullValue);
                _shareAmount = _extra_value_from_reserve.mul(PRICE_PRECISION).div(_share_price);
                if (_shareAmount <= _share_bal) {
                    _requestTransferFromReserve(share, _profitSharingFund, _shareAmount);
                } else {
                    _shareAmount = _share_bal;
                    _requestTransferFromReserve(share, _profitSharingFund, _share_bal);
                    {
                        uint256 _transferred_value_of_share = _share_bal.mul(_share_price).div(PRICE_PRECISION);
                        _darkAmount = _extra_value_from_reserve.sub(_transferred_value_of_share).mul(PRICE_PRECISION).div(_dark_price);
                    }
                    if (_darkAmount > _dark_bal) _darkAmount = _dark_bal;
                    _requestTransferFromReserve(dark, _profitSharingFund, _darkAmount);
                }
            }
        }
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _transferToReserve(address _token, address _sender, uint256 _amount, uint256 _fee) internal {
        if (_amount > 0) {
            address _reserve = collateralReserve();
            require(_reserve != address(0), "zero");
            IERC20(_token).safeTransferFrom(_sender, _reserve, _amount);
            if (_token == share) {
                ITreasury _treasury = ITreasury(treasury);
                _treasury.requestBurnShare(_fee);
                _treasury.reserveReceiveShare(_amount.sub(_fee));
            } else if (_token == dark) {
                ITreasury _treasury = ITreasury(treasury);
                _treasury.requestTransferDarkFee(_fee);
                _treasury.reserveReceiveDark(_amount.sub(_fee));
            }
        }
    }

    function _requestTransferFromReserve(address _token, address _receiver, uint256 _amount) internal {
        if (_amount > 0 && _receiver != address(0)) {
            ITreasury(treasury).requestTransfer(_token, _receiver, _amount);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "zero");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function setStrategistStatus(address _account, bool _status) external onlyOwner {
        strategist[_account] = _status;
        emit StrategistStatusUpdated(_account, _status);
    }

    function toggleMinting() external onlyOwner {
        mint_paused = !mint_paused;
        emit MintPausedUpdated(mint_paused);
    }

    function toggleRedeeming() external onlyOwner {
        redeem_paused = !redeem_paused;
        emit RedeemPausedUpdated(redeem_paused);
    }

    function toggleContractAllowed() external onlyOwner {
        contract_allowed = !contract_allowed;
        emit ContractAllowedUpdated(contract_allowed);
    }

    function toggleWhitelisted(address _account) external onlyOwner {
        whitelisted[_account] = !whitelisted[_account];
        emit WhitelistedUpdated(_account, whitelisted[_account]);
    }

    function setMintingLimits(uint256 _mintingLimitOnce, uint256 _mintingLimitHourly, uint256 _mintingLimitDaily) external onlyOwner {
        if (_mintingLimitOnce > 0) mintingLimitOnce_ = _mintingLimitOnce;
        if (_mintingLimitHourly > 0) mintingLimitHourly_ = _mintingLimitHourly;
        if (_mintingLimitDaily > 0) mintingLimitDaily_ = _mintingLimitDaily;
        emit SetMintingLimits(_mintingLimitOnce, _mintingLimitHourly, _mintingLimitDaily);
    }

    function setOracleDollar(address _oracleDollar) external onlyOwner {
        require(_oracleDollar != address(0), "Invalid address");
        oracleDollar = _oracleDollar;
        emit SetOracleDollar(_oracleDollar);
    }

    function setOracleDark(address _oracleDark) external onlyOwner {
        require(_oracleDark != address(0), "Invalid address");
        oracleDark = _oracleDark;
        emit SetOracleDark(_oracleDark);
    }

    function setOracleShare(address _oracleShare) external onlyOwner {
        require(_oracleShare != address(0), "Invalid address");
        oracleShare = _oracleShare;
        emit SetOracleShare(_oracleShare);
    }

    function setOracleCollaterals(address[] memory _oracleCollaterals) external onlyOwner {
        require(_oracleCollaterals.length == 3, "invalid oracleCollaterals length");
        delete oracleCollaterals;
        for (uint256 i = 0; i < 3; i++) {
            oracleCollaterals.push(_oracleCollaterals[i]);
        }
        emit SetOracleCollaterals(_oracleCollaterals);
    }

    function setOracleCollateral(uint256 _index, address _oracleCollateral) external onlyOwner {
        require(_oracleCollateral != address(0), "invalidAddress");
        oracleCollaterals[_index] = _oracleCollateral;
        emit SetOracleCollateral(_index, _oracleCollateral);
    }

    function setRedemptionDelay(uint256 _redemption_delay) external onlyOwner {
        redemption_delay = _redemption_delay;
        emit SetRedemptionDelay(_redemption_delay);
    }

    function setTargetCollateralRatioConfig(uint256 _updateStepTargetCR, uint256 _updateCoolingTimeTargetCR) external onlyOwner {
        updateStepTargetCR = _updateStepTargetCR;
        updateCoolingTimeTargetCR = _updateCoolingTimeTargetCR;
        emit SetTargetCollateralRatioConfig(_updateStepTargetCR, _updateCoolingTimeTargetCR);
    }

    function setTargetDarkOverShareRatioConfig(uint256 _updateStepTargetDODSR, uint256 _updateCoolingTimeTargetDODSR) external onlyOwner {
        updateStepTargetDODSR = _updateStepTargetDODSR;
        updateCoolingTimeTargetDODSR = _updateCoolingTimeTargetDODSR;
        emit SetTargetDarkOverShareRatioConfig(_updateStepTargetDODSR, _updateCoolingTimeTargetDODSR);
    }

    function setTargetCollateralRatio(uint256 _targetCollateralRatio) external onlyTreasuryOrOwner {
        require(_targetCollateralRatio <= 9500 && _targetCollateralRatio >= 7000, "OoR");
        lastUpdatedTargetCR = block.timestamp;
        targetCollateralRatio_ = _targetCollateralRatio;
        emit TargetCollateralRatioUpdated(_targetCollateralRatio);
    }

    function setTargetDarkOverDarkShareRatio(uint256 _targetDarkOverDarkShareRatio) external onlyTreasuryOrOwner {
        require(_targetDarkOverDarkShareRatio <= 8000 && _targetDarkOverDarkShareRatio >= 2000, "OoR");
        lastUpdatedTargetDODSR = block.timestamp;
        targetDarkOverDarkShareRatio_ = _targetDarkOverDarkShareRatio;
        emit TargetDarkOverShareRatioUpdated(_targetDarkOverDarkShareRatio);
    }

    function updateTargetCollateralRatio() external override onlyStrategist {
        if (lastUpdatedTargetCR.add(updateCoolingTimeTargetCR) <= block.timestamp) { // to avoid update too frequent
            lastUpdatedTargetCR = block.timestamp;
            uint256 _dollarPrice = getDollarPrice();
            if (_dollarPrice > PRICE_PRECISION) {
                // When DUSD is at or above $1, meaning the market’s demand for DUSD is high,
                // the system should be in de-collateralize mode by decreasing the collateral ratio, minimum to 70%
                targetCollateralRatio_ = Math.max(7000, targetCollateralRatio_.sub(updateStepTargetCR));
            } else {
                // When the price of DUSD is below $1, the function increases the collateral ratio, maximum to 95%
                targetCollateralRatio_ = Math.min(9500, targetCollateralRatio_.add(updateStepTargetCR));
            }
            emit TargetCollateralRatioUpdated(targetCollateralRatio_);
        }
    }

    function updateTargetDarkOverShareRatio() external override onlyStrategist {
        if (lastUpdatedTargetDODSR.add(updateCoolingTimeTargetDODSR) <= block.timestamp) { // to avoid update too frequent
            lastUpdatedTargetDODSR = block.timestamp;
            uint256 _darkCap = getDarkPrice().mul(IERC20(dark).totalSupply());
            IERC20 _share = IERC20(share);
            uint256 _shareCap = getSharePrice().mul(_share.totalSupply().sub(_share.balanceOf(shareFarmingPool_)));
            uint256 _targetRatio = _darkCap.mul(10000).div(_darkCap.add(_shareCap));
            uint256 _targetDarkOverDarkShareRatio = targetDarkOverDarkShareRatio_;
            // At the beginning the ratio between DARK/NESS will be 50%/50% and it will increase/decrease depending on Market cap of DARK and NESS.
            // The ratio will be updated every 4 hours by a step of 1%. Minimum and maximum ratio is 20%/80% and 80%/20% accordingly.
            if (_targetDarkOverDarkShareRatio < 8000 && _targetDarkOverDarkShareRatio.add(100) <= _targetRatio) {
                targetDarkOverDarkShareRatio_ = _targetDarkOverDarkShareRatio.add(100);
                emit TargetDarkOverShareRatioUpdated(targetDarkOverDarkShareRatio_);
            } else if (_targetDarkOverDarkShareRatio > 2000 && _targetDarkOverDarkShareRatio >= _targetRatio.add(100)) {
                targetDarkOverDarkShareRatio_ = _targetDarkOverDarkShareRatio.sub(100);
                emit TargetDarkOverShareRatioUpdated(targetDarkOverDarkShareRatio_);
            }
        }
    }

    /* ========== EMERGENCY ========== */

    function rescueStuckErc20(address _token) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }
}

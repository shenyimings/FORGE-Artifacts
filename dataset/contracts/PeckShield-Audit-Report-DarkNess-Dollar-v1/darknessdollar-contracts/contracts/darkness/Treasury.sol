// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../interfaces/IBasisAsset.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IPool.sol";
import "../interfaces/ITreasuryPolicy.sol";
import "../interfaces/ICollateralReserve.sol";

contract Treasury is ITreasury, OwnableUpgradeSafe, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // addresses
    address private collateralReserve_;
    address public dollar;
    address public dark;
    address public share;
    address[] public collaterals;
    address public treasuryPolicy;
    address private profitSharingFund_;
    address private darkInsuranceFund_;

    address public oracleDollar;
    address public oracleDark;
    address public oracleShare;
    address[] public oracleCollaterals;

    // pools
    address[] public pools_array;
    mapping(address => bool) public pools;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;

    // Number of decimals needed to get to 18
    uint256[] private missing_decimals;

    mapping(address => bool) public strategist;

    /* ========== EVENTS ========== */

    event PoolAdded(address indexed pool);
    event PoolRemoved(address indexed pool);
    event TreasuryPolicyUpdated(address _treasuryPolicy);
    event OracleDollarUpdated(address _oracleDollar);
    event OracleDarkUpdated(address _oracleDark);
    event OracleShareUpdated(address _oracleShare);
    event OracleCollateralsUpdated(address[] _oracleCollaterals);
    event OracleCollateralUpdated(uint256 _index, address _oracleCollateral);
    event CollateralReserveUpdated(address _collateralReserve);
    event ProfitSharingFundUpdated(address _profitSharingFund);
    event DarkInsuranceFundUpdated(address _darkInsuranceFund);
    event UpdateProtocol();
    event StrategistStatusUpdated(address indexed account, bool status);

    /* ========== MODIFIERS ========== */

    modifier onlyPool {
        require(pools[msg.sender], "!pool");
        _;
    }

    modifier onlyStrategist() {
        require(strategist[msg.sender] || msg.sender == owner(), "!strategist && !owner");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _dollar,
        address _dark,
        address _share,
        address[] memory _collaterals,
        address _treasuryPolicy,
        address _collateralReserve,
        address _profitSharingFund,
        address _darkInsuranceFund
    ) external initializer {
        require(_dollar != address(0), "zero");
        require(_dark != address(0), "zero");
        require(_share != address(0), "zero");
        require(_collaterals.length == 3, "Invalid collateral length");

        OwnableUpgradeSafe.__Ownable_init();

        dollar = _dollar;
        dark = _dark; // DARK
        share = _share; // NESS
        collaterals = _collaterals; // USDC, USDT, DAI

        oracleCollaterals = new address[](3);
        missing_decimals = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            missing_decimals[i] = uint256(18).sub(uint256(IBasisAsset(_collaterals[i]).decimals()));
        }

        setTreasuryPolicy(_treasuryPolicy);
        setCollateralReserve(_collateralReserve);
        setProfitSharingFund(_profitSharingFund);
        setDarkInsuranceFund(_darkInsuranceFund);
    }

    /* ========== VIEWS ========== */

    function dollarPrice() public view returns (uint256) {
        return IOracle(oracleDollar).consult();
    }

    function darkPrice() public view returns (uint256) {
        return IOracle(oracleDark).consult();
    }

    function sharePrice() public view returns (uint256) {
        return IOracle(oracleShare).consult();
    }

    function collateralPrice(uint256 _index) public view returns (uint256) {
        address _oracle = oracleCollaterals[_index];
        return (_oracle == address(0)) ? PRICE_PRECISION : IOracle(_oracle).consult();
    }

    function hasPool(address _address) external view override returns (bool) {
        return pools[_address] == true;
    }

    function minting_fee() public override view returns (uint256) {
        return ITreasuryPolicy(treasuryPolicy).minting_fee();
    }

    function redemption_fee() public override view returns (uint256) {
        return ITreasuryPolicy(treasuryPolicy).redemption_fee();
    }

    function reserve_share_state() public override view returns (uint8) {
        return ITreasuryPolicy(treasuryPolicy).reserve_share_state();
    }

    function collateralReserve() public override view returns (address) {
        return collateralReserve_;
    }

    function profitSharingFund() public override view returns (address) {
        return profitSharingFund_;
    }

    function darkInsuranceFund() public override view returns (address) {
        return darkInsuranceFund_;
    }

    function info()
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint8
        )
    {
        return (
            dollarPrice(),
            sharePrice(),
            IERC20(dollar).totalSupply(),
            globalCollateralTotalValue(),
            minting_fee(),
            redemption_fee(),
            reserve_share_state()
        );
    }

    function globalCollateralBalance(uint256 _index) public view override returns (uint256) {
        return IERC20(collaterals[_index]).balanceOf(collateralReserve_).sub(totalUnclaimedCollateral(_index));
    }

    function globalCollateralValue(uint256 _index) public view override returns (uint256) {
        return globalCollateralBalance(_index).mul(collateralPrice(_index)).mul(10 ** missing_decimals[_index]).div(PRICE_PRECISION);
    }

    function globalCollateralTotalValue() public view override returns (uint256) {
        return globalCollateralValue(0).add(globalCollateralValue(1)).add(globalCollateralValue(2));
    }

    function globalDarkBalance() public view override returns (uint256) {
        return IERC20(dark).balanceOf(collateralReserve_).sub(totalUnclaimedDark());
    }

    function globalDarkValue() public view override returns (uint256) {
        return globalDarkBalance().mul(darkPrice()).div(PRICE_PRECISION);
    }

    function globalShareBalance() public view override returns (uint256) {
        return IERC20(share).balanceOf(collateralReserve_).sub(totalUnclaimedShare());
    }

    function globalShareValue() public view override returns (uint256) {
        return globalShareBalance().mul(sharePrice()).div(PRICE_PRECISION);
    }

    // Iterate through all pools and calculate all unclaimed collaterals in all pools globally
    function totalUnclaimedCollateral(uint256 _index) public view returns (uint256 _totalUnclaimed) {
        uint256 _length = pools_array.length;
        for (uint256 i = 0; i < _length; i++) {
            address _pool = pools_array[i];
            if (_pool != address(0)) {
                _totalUnclaimed = _totalUnclaimed.add((IPool(_pool).unclaimed_pool_collateral(_index)));
            }
        }
    }

    function totalUnclaimedDark() public view returns (uint256 _totalUnclaimed) {
        uint256 _length = pools_array.length;
        for (uint256 i = 0; i < _length; i++) {
            address _pool = pools_array[i];
            if (_pool != address(0)) {
                _totalUnclaimed = _totalUnclaimed.add((IPool(_pool).unclaimed_pool_dark()));
            }
        }
    }

    function totalUnclaimedShare() public view returns (uint256 _totalUnclaimed) {
        uint256 _length = pools_array.length;
        for (uint256 i = 0; i < _length; i++) {
            address _pool = pools_array[i];
            if (_pool != address(0)) {
                _totalUnclaimed = _totalUnclaimed.add((IPool(_pool).unclaimed_pool_share()));
            }
        }
    }

    function getEffectiveCollateralRatio() external view override returns (uint256) {
        uint256 _total_collateral_value = globalCollateralTotalValue();
        uint256 _total_dollar_value = IERC20(dollar).totalSupply().mul(dollarPrice()).div(PRICE_PRECISION);
        return _total_collateral_value.mul(10000).div(_total_dollar_value);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setStrategistStatus(address _account, bool _status) external onlyOwner {
        strategist[_account] = _status;
        emit StrategistStatusUpdated(_account, _status);
    }

    function requestTransfer(
        address _token,
        address _receiver,
        uint256 _amount
    ) external override onlyPool {
        ICollateralReserve(collateralReserve_).transferTo(_token, _receiver, _amount);
    }

    function requestBurnShare(uint256 _fee) external override onlyPool {
        ICollateralReserve(collateralReserve_).burnToken(share, _fee);
    }

    function requestTransferDarkFee(uint256 _fee) external override onlyPool {
        uint256 _amt = _fee.mul(45).div(100); // 10% stayed, 45% forwarded to profitSharingFund, 45% forwarded to darkInsuranceFund
        ICollateralReserve(collateralReserve_).transferTo(dark, profitSharingFund_, _amt);
        ICollateralReserve(collateralReserve_).transferTo(dark, darkInsuranceFund_, _amt);
    }

    function reserveReceiveDark(uint256 _amount) external override onlyPool {
        ICollateralReserve(collateralReserve_).receiveDarks(_amount);
    }

    function reserveReceiveShare(uint256 _amount) external override onlyPool {
        ICollateralReserve(collateralReserve_).receiveShares(_amount);
    }

    // Add new Pool
    function addPool(address pool_address) public onlyOwner {
        require(pools[pool_address] == false, "poolExisted");
        pools[pool_address] = true;
        pools_array.push(pool_address);
        emit PoolAdded(pool_address);
    }

    // Remove a pool
    function removePool(address pool_address) public onlyOwner {
        require(pools[pool_address] == true, "!pool");
        // Delete from the mapping
        delete pools[pool_address];
        // 'Delete' from the array by setting the address to 0x0
        for (uint256 i = 0; i < pools_array.length; i++) {
            if (pools_array[i] == pool_address) {
                pools_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }
        emit PoolRemoved(pool_address);
    }

    function setTreasuryPolicy(address _treasuryPolicy) public onlyOwner {
        require(_treasuryPolicy != address(0), "zero");
        treasuryPolicy = _treasuryPolicy;
        emit TreasuryPolicyUpdated(_treasuryPolicy);
    }

    function setOracleDollar(address _oracleDollar) external onlyOwner {
        require(_oracleDollar != address(0), "zero");
        oracleDollar = _oracleDollar;
        emit OracleDollarUpdated(_oracleDollar);
    }

    function setOracleDark(address _oracleDark) external onlyOwner {
        require(_oracleDark != address(0), "zero");
        oracleDark = _oracleDark;
        emit OracleDarkUpdated(_oracleDark);
    }

    function setOracleShare(address _oracleShare) external onlyOwner {
        require(_oracleShare != address(0), "zero");
        oracleShare = _oracleShare;
        emit OracleShareUpdated(_oracleShare);
    }

    function setOracleCollaterals(address[] memory _oracleCollaterals) external onlyOwner {
        require(_oracleCollaterals.length == 3, "invalid oracleCollaterals length");
        delete oracleCollaterals;
        for (uint256 i = 0; i < 3; i++) {
            oracleCollaterals.push(_oracleCollaterals[i]);
        }
        emit OracleCollateralsUpdated(_oracleCollaterals);
    }

    function setOracleCollateral(uint256 _index, address _oracleCollateral) external onlyOwner {
        require(_oracleCollateral != address(0), "zero");
        oracleCollaterals[_index] = _oracleCollateral;
        emit OracleCollateralUpdated(_index, _oracleCollateral);
    }

    function setCollateralReserve(address _collateralReserve) public onlyOwner {
        require(_collateralReserve != address(0), "zero");
        collateralReserve_ = _collateralReserve;
        emit CollateralReserveUpdated(_collateralReserve);
    }

    function setProfitSharingFund(address _profitSharingFund) public onlyOwner {
        require(_profitSharingFund != address(0), "zero");
        profitSharingFund_ = _profitSharingFund;
        emit ProfitSharingFundUpdated(_profitSharingFund);
    }

    function setDarkInsuranceFund(address _darkInsuranceFund) public onlyOwner {
        require(_darkInsuranceFund != address(0), "zero");
        darkInsuranceFund_ = _darkInsuranceFund;
        emit DarkInsuranceFundUpdated(_darkInsuranceFund);
    }

    function updateProtocol() external onlyStrategist {
        if (dollarPrice() > PRICE_PRECISION) {
            ITreasuryPolicy(treasuryPolicy).setMintingFee(20);
            ITreasuryPolicy(treasuryPolicy).setRedemptionFee(80);
        } else {
            ITreasuryPolicy(treasuryPolicy).setMintingFee(40);
            ITreasuryPolicy(treasuryPolicy).setRedemptionFee(40);
        }
        for (uint256 i = 0; i < pools_array.length; i++) {
            address _pool = pools_array[i];
            if (_pool != address(0)) {
                IPool(_pool).updateTargetCollateralRatio();
                IPool(_pool).updateTargetDarkOverShareRatio();
            }
        }
        address _oracle = oracleCollaterals[1];
        if (_oracle != address(0)) IOracle(_oracle).update();
        _oracle = oracleCollaterals[2];
        if (_oracle != address(0)) IOracle(_oracle).update();
        _oracle = oracleShare;
        if (_oracle != address(0)) IOracle(_oracle).update();
        _oracle = oracleDollar;
        if (_oracle != address(0)) IOracle(_oracle).update();
        emit UpdateProtocol();
    }

    /* ========== EMERGENCY ========== */

    function rescueStuckErc20(address _token) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }
}

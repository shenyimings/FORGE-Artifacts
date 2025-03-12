// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";
import "@overnight-contracts/common/contracts/libraries/WadRayMath.sol";
import "./interfaces/IPortfolioManager.sol";
import "./interfaces/IMark2Market.sol";

import "./interfaces/IRebaseToken.sol";

import "hardhat/console.sol";

contract InsuranceExchange is Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    using WadRayMath for uint256;

    bytes32 public constant PORTFOLIO_AGENT_ROLE = keccak256("PORTFOLIO_AGENT_ROLE");
    bytes32 public constant TRUST_ROLE = keccak256("TRUST_ROLE");
    bytes32 public constant FREE_RIDER_ROLE = keccak256("FREE_RIDER_ROLE");
    bytes32 public constant INSURANCE_HOLDER_ROLE = keccak256("INSURANCE_HOLDER_ROLE");
    bytes32 public constant UNIT_ROLE = keccak256("UNIT_ROLE");

    IERC20 public asset;
    IRebaseToken public rebase;
    IPortfolioManager public pm;
    IMark2Market public m2m;

    uint256 public mintFee;
    uint256 public mintFeeDenominator;

    uint256 public redeemFee;
    uint256 public redeemFeeDenominator;

    uint256 public lastBlockNumber;

    uint256 public nextPayoutTime;
    uint256 public payoutPeriod;
    uint256 public payoutTimeRange;

    mapping(address => uint256) public withdrawRequests;
    uint256 public requestWaitPeriod;
    uint256 public withdrawPeriod;

    struct SetUpParams {
        address asset;
        address rebase;
        address pm;
        address m2m;
    }

    struct InputMint {
        uint256 amount;
    }

    struct InputRedeem {
        uint256 amount;
    }

    event PayoutEvent(int256 profit, uint256 newLiquidityIndex);
    event MintBurn(string label, uint256 amount, uint256 fee, address sender);
    event NextPayoutTime(uint256 nextPayoutTime);

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public  {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        mintFee = 0;
        // ~ 100 %
        mintFeeDenominator = 100000;

        redeemFee = 0;
        // ~ 100 %
        redeemFeeDenominator = 100000;

        // 1637193600 = 2021-11-18T00:00:00Z
        nextPayoutTime = 1637193600;
        payoutPeriod = 24 * 60 * 60;
        payoutTimeRange = 15 * 60;

        // 3 day in seconds
        requestWaitPeriod = 259200;

        // 4 day in seconds
        withdrawPeriod = 345600;

        _setRoleAdmin(FREE_RIDER_ROLE, PORTFOLIO_AGENT_ROLE);
        _setRoleAdmin(UNIT_ROLE, PORTFOLIO_AGENT_ROLE);
    }

    function changeAdminRoles() external onlyAdmin {
        _setRoleAdmin(FREE_RIDER_ROLE, PORTFOLIO_AGENT_ROLE);
        _setRoleAdmin(UNIT_ROLE, PORTFOLIO_AGENT_ROLE);
    }


    function _authorizeUpgrade(address newImplementation)
    internal
    onlyAdmin
    override
    {}

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Restricted to admins");
        _;
    }

    modifier onlyTrust() {
        require(hasRole(TRUST_ROLE, msg.sender), "Restricted to Trust");
        _;
    }

    modifier onlyInsuranceHolder() {
        require(hasRole(INSURANCE_HOLDER_ROLE, msg.sender), "Restricted to Insurance Holder");
        _;
    }

    modifier onlyPortfolioAgent() {
        require(hasRole(PORTFOLIO_AGENT_ROLE, msg.sender), "Restricted to Portfolio Agent");
        _;
    }

    modifier onlyUnit(){
        require(hasRole(UNIT_ROLE, msg.sender), "Restricted to Unit");
        _;
    }

    modifier oncePerBlock() {
        if (!hasRole(FREE_RIDER_ROLE, msg.sender)) {
            require(lastBlockNumber < block.number, "Only once in block");
        }
        lastBlockNumber = block.number;
        _;
    }


    function setUpParams(SetUpParams calldata params) external onlyAdmin {
        asset = IERC20(params.asset);
        rebase = IRebaseToken(params.rebase);
        pm = IPortfolioManager(params.pm);
        m2m = IMark2Market(params.m2m);
    }

    function setPayoutTimes(
        uint256 _nextPayoutTime,
        uint256 _payoutPeriod,
        uint256 _payoutTimeRange
    ) external onlyPortfolioAgent {
        require(_nextPayoutTime != 0, "Zero _nextPayoutTime not allowed");
        require(_payoutPeriod != 0, "Zero _payoutPeriod not allowed");
        require(_nextPayoutTime > _payoutTimeRange, "_nextPayoutTime shoud be more than _payoutTimeRange");
        nextPayoutTime = _nextPayoutTime;
        payoutPeriod = _payoutPeriod;
        payoutTimeRange = _payoutTimeRange;
    }

    function setMintFee(uint256 _fee, uint256 _feeDenominator) external onlyPortfolioAgent {
        require(_feeDenominator != 0, "Zero denominator not allowed");
        mintFee = _fee;
        mintFeeDenominator = _feeDenominator;
    }

    function setRedeemFee(uint256 _fee, uint256 _feeDenominator) external onlyPortfolioAgent {
        require(_feeDenominator != 0, "Zero denominator not allowed");
        redeemFee = _fee;
        redeemFeeDenominator = _feeDenominator;
    }

    function setWithdrawPeriod(uint256 _requestWaitPeriod, uint256 _withdrawPeriod) external onlyPortfolioAgent {
        requestWaitPeriod = _requestWaitPeriod;
        withdrawPeriod = _withdrawPeriod;
    }

    function mint(InputMint calldata input) external whenNotPaused oncePerBlock {
        _mint(input.amount);
    }

    function _mint(uint256 _amount) internal {
        require(_amount > 0, "Amount of asset is zero");
        require(asset.balanceOf(msg.sender) >= _amount, "Not enough tokens to mint");


        asset.transferFrom(msg.sender, address(pm), _amount);
        pm.deposit(asset, _amount);

        uint256 rebaseAmount = _assetToRebaseAmount(_amount);
        uint256 fee;
        (rebaseAmount, fee) = _takeFee(rebaseAmount, true);

        require(rebaseAmount > 0, "Rebase Amount is zero");
        rebase.mint(msg.sender, rebaseAmount);

        delete withdrawRequests[msg.sender];
        emit MintBurn('mint', rebaseAmount, fee, msg.sender);
    }

    function _takeFee(uint256 _amount, bool isMint) internal view returns (uint256, uint256){

        uint256 fee = isMint ? mintFee : redeemFee;
        uint256 feeDenominator = isMint ? mintFeeDenominator : redeemFeeDenominator;

        uint256 feeAmount;
        uint256 resultAmount;
        if (!hasRole(FREE_RIDER_ROLE, msg.sender)) {
            feeAmount = (_amount * fee) / feeDenominator;
            resultAmount = _amount - feeAmount;
        } else {
            resultAmount = _amount;
        }

        return (resultAmount, feeAmount);
    }


    function redeem(InputRedeem calldata input) external whenNotPaused oncePerBlock {
        _redeem(input.amount);
    }

    function _redeem(uint256 _amount) internal {
        require(_amount > 0, "Amount of asset is zero");
        require(rebase.balanceOf(msg.sender) >= _amount, "Not enough tokens to redeem");

        checkWithdraw();

        uint256 fee;
        uint256 amountFee;
        (amountFee, fee) = _takeFee(_amount, false);

        uint256 assetAmount = _rebaseAmountToAsset(amountFee);
        require(assetAmount > 0, "Amount of asset is zero");

        pm.withdraw(asset, assetAmount);

        require(asset.balanceOf(address(this)) >= assetAmount, "Not enough for transfer");

        asset.transfer(msg.sender, assetAmount);
        rebase.burn(msg.sender, _amount);

        delete withdrawRequests[msg.sender];
        emit MintBurn('redeem', _amount, fee, msg.sender);
    }

    function _assetToRebaseAmount(uint256 _assetAmount) internal returns (uint256) {
        uint256 rebaseDecimals = rebase.decimals();
        uint256 assetDecimals = IERC20Metadata(address(asset)).decimals();

        uint256 _rebaseAmount;
        if (assetDecimals > rebaseDecimals) {
            _rebaseAmount = _assetAmount / (10 ** (assetDecimals - rebaseDecimals));
        } else {
            _rebaseAmount = _assetAmount * (10 ** (rebaseDecimals - assetDecimals));
        }
        return _rebaseAmount;

    }

    function _rebaseAmountToAsset(uint256 _rebaseAmount) internal returns (uint256) {

        uint256 _assetAmount;
        uint256 assetDecimals = IERC20Metadata(address(asset)).decimals();
        uint256 rebaseDecimals = rebase.decimals();
        if (assetDecimals > rebaseDecimals) {
            _assetAmount = _rebaseAmount * (10 ** (assetDecimals - rebaseDecimals));
        } else {
            _assetAmount = _rebaseAmount / (10 ** (rebaseDecimals - assetDecimals));
        }
        return _assetAmount;

    }


    function requestWithdraw() external whenNotPaused {
        withdrawRequests[msg.sender] = block.timestamp + requestWaitPeriod;
    }

    function checkWithdraw() public view {

        if (hasRole(TRUST_ROLE, msg.sender)) {
            return;
        }

        uint256 date = withdrawRequests[msg.sender];
        uint256 currentDate = block.timestamp;

        uint256 withdrawDate = date + withdrawPeriod;

        require(date != 0, 'need withdraw request');
        require(date < currentDate, 'requestWaitPeriod');
        require(withdrawDate > currentDate, 'withdrawPeriod');
    }


    function premium(uint256 _assetAmount) external onlyInsuranceHolder {
        require(asset.balanceOf(address(this)) >= _assetAmount, "Not enough for transfer");
        asset.transfer(address(pm), _assetAmount);
    }

    function compensate(uint256 _assetAmount, address _to) external onlyInsuranceHolder {
        pm.withdraw(asset, _assetAmount);
        require(asset.balanceOf(address(this)) >= _assetAmount, "Not enough for transfer");
        asset.transfer(_to, _assetAmount);
    }


    function payout() public whenNotPaused oncePerBlock onlyUnit {

        if (block.timestamp + payoutTimeRange < nextPayoutTime) {
            return;
        }

        pm.claimAndBalance();

        uint256 totalAsset = m2m.totalNetAssets();
        totalAsset = _assetToRebaseAmount(totalAsset);

        int256 profit = int256(totalAsset) - int256(rebase.totalSupply());

        uint256 newLiquidityIndex = totalAsset.wadToRay().rayDiv(rebase.scaledTotalSupply());
        rebase.setLiquidityIndex(newLiquidityIndex);

        emit PayoutEvent(profit, newLiquidityIndex);

        // update next payout time. Cycle for preventing gaps
        for (; block.timestamp >= nextPayoutTime - payoutTimeRange;) {
            nextPayoutTime = nextPayoutTime + payoutPeriod;
        }
        emit NextPayoutTime(nextPayoutTime);
    }


}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../pool/IPool.sol";
import "../../oracle/interface/IChainlinkOracle.sol";
import "../../oracle/interface/IUniswapPairOracle.sol";

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

// gu => usd
// anchor : Anchor the object
// synth : Synthetic on-chain assets
contract GuStablecoin is Initializable, ContextUpgradeable, AccessControlUpgradeable, ERC20Upgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    /* ========== STATE VARIABLES ========== */
    enum PriceChoice { Gu, Gr }

    // BNB and anchor price predictor, one BNB= how much anchor
    IChainlinkOracle private bnb_anchor_pricer;
    uint8 private bnb_anchor_pricer_decimals;

    IUniswapPairOracle private guBnbOracle;
    IUniswapPairOracle private grBnbOracle;
    address public creator_address;
    address public timelock_address; // Governance timelock address
    address public controller_address; // Controller contract to dynamically adjust system parameters automatically
    address public gr_address;
    address public gu_bnb_oracle_address;
    address public gr_bnb_oracle_address;
    address public wbnb_address;
    address public bnb_anchor_consumer_address;
    uint256 public constant genesis_supply = 500e18; // 2M Gu (only for testing, genesis supply will be 5k on Mainnet). This is to help with establishing the Uniswap pools, as they need liquidity

    // The addresses in this array are added by the oracle and these contracts are able to mint Gu
    address[] public synth_pools_array;

    // Mapping is also used for faster verification
    mapping(address => bool) public synth_pools;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;

    uint256 public global_collateral_ratio; // 6 decimals of precision, e.g. 924102 = 0.924102
    uint256 public redemption_fee; // 6 decimals of precision, divide by 1000000 in calculations for fee
    uint256 public minting_fee; // 6 decimals of precision, divide by 1000000 in calculations for fee
    uint256 public synth_step; // Amount to change the collateralization ratio by upon refreshCollateralRatio()
    uint256 public refresh_cooldown; // Seconds to wait before being able to run refreshCollateralRatio() again
    uint256 public price_target; // The price of Gu at which the collateral ratio will respond to; this value is only used for the collateral ratio mechanism and not for minting and redeeming which are hardcoded at $1
    uint256 public price_band; // The bound above and below the price target at which the refreshCollateralRatio() will not change the collateral ratio
    uint256 public min_collateral_ratio; // Minimum mortgage rate

    address public DEFAULT_ADMIN_ADDRESS;
    bytes32 public constant COLLATERAL_RATIO_PAUSER = keccak256("COLLATERAL_RATIO_PAUSER");
    bool public collateral_ratio_paused;

    uint256 public last_call_time; // Last time the refreshCollateralRatio function was called

    /* ========== MODIFIERS ========== */

    modifier onlyCollateralRatioPauser() {
        require(hasRole(COLLATERAL_RATIO_PAUSER, msg.sender));
        _;
    }

    modifier onlyPools() {
        require(synth_pools[msg.sender] == true, "Only Gu pools can call this function");
        _;
    }

    modifier onlyByOwnerGovernanceOrController() {
        require(msg.sender == owner() || msg.sender == timelock_address || msg.sender == controller_address, "Not the owner, controller, or the governance timelock");
        _;
    }

    modifier onlyByOwnerGovernanceOrPool() {
        require(
            msg.sender == owner()
            || msg.sender == timelock_address
            || synth_pools[msg.sender] == true,
            "Not the owner, the governance timelock, or a pool");
        _;
    }

    /* ========== initialize ========== */

    function initialize(
        string memory _name,
        string memory _symbol,
        address _timelock_address
    ) public initializer {
        require(_timelock_address != address(0), "Zero address detected");

        __Context_init();
        __Ownable_init();
        __ERC20_init(_name, _symbol);
        __AccessControl_init();

        creator_address = _msgSender();
        timelock_address = _timelock_address;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        DEFAULT_ADMIN_ADDRESS = _msgSender();
        _mint(creator_address, genesis_supply);
        grantRole(COLLATERAL_RATIO_PAUSER, creator_address);
        grantRole(COLLATERAL_RATIO_PAUSER, timelock_address);
        synth_step = 2500; // 6 decimals of precision, equal to 0.25%
        global_collateral_ratio = 1000000; // Gu system starts off fully collateralized (6 decimals of precision)
        refresh_cooldown = 3600; // Refresh cooldown period is set to 1 hour (3600 seconds) at genesis
        price_target = 1000000; // Collateral ratio will adjust according to the $1 price target at genesis
        price_band = 5000; // Collateral ratio will not adjust if between $0.995 and $1.005 at genesis
        min_collateral_ratio = 800000; // The mortgage rate is 90 percent at genesis
        collateral_ratio_paused = false;
    }

    /* ========== VIEWS ========== */

    // Choice = 'Gu' or 'Gr' for now
    function oracle_price(PriceChoice choice) internal view returns (uint256) {
        // Get the BNB / Anchor price first, and cut it down to 1e6 precision
        uint256 _bnb_anchor_price = uint256(bnb_anchor_pricer.getLatestPrice()).mul(PRICE_PRECISION).div(uint256(10) ** bnb_anchor_pricer_decimals);
        uint256 price_vs_bnb = 0;

        if (choice == PriceChoice.Gu) {
            price_vs_bnb = uint256(guBnbOracle.consult(wbnb_address, PRICE_PRECISION)); // How much Gu if you put in PRICE_PRECISION WBNB
        }
        else if (choice == PriceChoice.Gr) {
            price_vs_bnb = uint256(grBnbOracle.consult(wbnb_address, PRICE_PRECISION)); // How much Gr if you put in PRICE_PRECISION WBNB
        }
        else revert("INVALID PRICE CHOICE. Needs to be either 0 (Gu) or 1 (Gr)");

        // Will be in 1e6 format
        return _bnb_anchor_price.mul(PRICE_PRECISION).div(price_vs_bnb);
    }

    // Returns  1 Gu = X Anchor
    function gu_price() public view returns (uint256) {
        return oracle_price(PriceChoice.Gu);
    }

    // Returns  1 Gu = X Anchor
    function synth_price() public view returns (uint256) {
        return oracle_price(PriceChoice.Gu);
    }

    // Returns  1 Gr = X Anchor
    function gr_price()  public view returns (uint256) {
        return oracle_price(PriceChoice.Gr);
    }

    function bnb_anchor_price() public view returns (uint256) {
        return uint256(bnb_anchor_pricer.getLatestPrice()).mul(PRICE_PRECISION).div(uint256(10) ** bnb_anchor_pricer_decimals);
    }

    // This is needed to avoid costly repeat calls to different getter functions
    // It is cheaper gas-wise to just dump everything and only use some of the info
    function synth_info() public view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
        oracle_price(PriceChoice.Gu), // Gu_price()
        oracle_price(PriceChoice.Gr), // gr_price()
        totalSupply(), // totalSupply()
        global_collateral_ratio, // global_collateral_ratio()
        globalCollateralValue(), // globalCollateralValue
        minting_fee, // minting_fee()
        redemption_fee, // redemption_fee()
        uint256(bnb_anchor_pricer.getLatestPrice()).mul(PRICE_PRECISION).div(uint256(10) ** bnb_anchor_pricer_decimals) //bnb_anchor_price
        );
    }

    // Iterate through all Gu pools and calculate all value of collateral in all pools globally
    function globalCollateralValue() public view returns (uint256) {
        uint256 total_collateral_value_d18 = 0;

        for (uint i = 0; i < synth_pools_array.length; i++){
            // Exclude null addresses
            if (synth_pools_array[i] != address(0)){
                total_collateral_value_d18 = total_collateral_value_d18.add(IPool(synth_pools_array[i]).collatAnchorBalance());
            }

        }
        return total_collateral_value_d18;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function canRefreshRatio() public view returns (bool) {
        if (block.timestamp - last_call_time >= refresh_cooldown && collateral_ratio_paused == false){
            return true;
        }
       return false;
    }

    // There needs to be a time interval that this can be called. Otherwise it can be called multiple times per expansion.
    function refreshCollateralRatio() public {
        require(collateral_ratio_paused == false, "Collateral Ratio has been paused");
        uint256 gu_price_cur = gu_price();
        require(block.timestamp - last_call_time >= refresh_cooldown, "Must wait for the refresh cooldown since last refresh");

        // Step increments are 0.25% (upon genesis, changable by setGuStep())

        if (gu_price_cur > price_target.add(price_band)) { //decrease collateral ratio
            if(global_collateral_ratio <= min_collateral_ratio){ //if within a step of 90%, go to 90%
                global_collateral_ratio = min_collateral_ratio;
            } else {
                global_collateral_ratio = global_collateral_ratio.sub(synth_step);
            }
        } else if (gu_price_cur < price_target.sub(price_band)) { //increase collateral ratio
            if(global_collateral_ratio.add(synth_step) >= 1000000){
                global_collateral_ratio = 1000000; // cap collateral ratio at 1.000000
            } else {
                global_collateral_ratio = global_collateral_ratio.add(synth_step);
            }
        }

        last_call_time = block.timestamp; // Set the time of the last expansion

        emit CollateralRatioRefreshed(global_collateral_ratio);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Used by pools when user redeems
    function pool_burn_from(address b_address, uint256 b_amount) public onlyPools {
        super._burn(b_address, b_amount);
        super._approve(b_address, _msgSender(), allowance(b_address, _msgSender()).sub(b_amount, "ERC20: burn amount exceeds allowance"));
        emit GuBurned(b_address, msg.sender, b_amount);
    }

    // This function is what other Gu pools will call to mint new Gu
    function pool_mint(address m_address, uint256 m_amount) public onlyPools {
        super._mint(m_address, m_amount);
        emit GuMinted(msg.sender, m_address, m_amount);
    }

    // Adds collateral addresses supported, such as tether and busd, must be ERC20 
    function addPool(address pool_address) public onlyByOwnerGovernanceOrController {
        require(pool_address != address(0), "Zero address detected");

        require(synth_pools[pool_address] == false, "Address already exists");
        synth_pools[pool_address] = true;
        synth_pools_array.push(pool_address);

        emit PoolAdded(pool_address);
    }

    // Remove a pool 
    function removePool(address pool_address) public onlyByOwnerGovernanceOrController {
        require(pool_address != address(0), "Zero address detected");
        require(synth_pools[pool_address] == true, "Address nonexistant");

        // Delete from the mapping
        delete synth_pools[pool_address];

        // 'Delete' from the array by setting the address to 0x0
        for (uint i = 0; i < synth_pools_array.length; i++){
            if (synth_pools_array[i] == pool_address) {
                synth_pools_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }

        emit PoolRemoved(pool_address);
    }

    function setRedemptionFee(uint256 red_fee) public onlyByOwnerGovernanceOrController {
        redemption_fee = red_fee;

        emit RedemptionFeeSet(red_fee);
    }

    function setMintingFee(uint256 min_fee) public onlyByOwnerGovernanceOrController {
        minting_fee = min_fee;

        emit MintingFeeSet(min_fee);
    }

    function setSynthStep(uint256 _new_step) public onlyByOwnerGovernanceOrController {
        synth_step = _new_step;

        emit SynthStepSet(_new_step);
    }

    function setPriceTarget (uint256 _new_price_target) public onlyByOwnerGovernanceOrController {
        price_target = _new_price_target;

        emit PriceTargetSet(_new_price_target);
    }

    function setRefreshCooldown(uint256 _new_cooldown) public onlyByOwnerGovernanceOrController {
        refresh_cooldown = _new_cooldown;

        emit RefreshCooldownSet(_new_cooldown);
    }

    function setGrAddress(address _gr_address) public onlyByOwnerGovernanceOrController {
        require(_gr_address != address(0), "Zero address detected");

        gr_address = _gr_address;

        emit GrAddressSet(_gr_address);
    }

    function setBNBAnchorOracle(address _bnb_anchor_consumer_address) public onlyByOwnerGovernanceOrController {
        require(_bnb_anchor_consumer_address != address(0), "Zero address detected");

        bnb_anchor_consumer_address = _bnb_anchor_consumer_address;
        bnb_anchor_pricer = IChainlinkOracle(bnb_anchor_consumer_address);
        bnb_anchor_pricer_decimals = bnb_anchor_pricer.getDecimals();

        emit BNBAnchorOracleSet(_bnb_anchor_consumer_address);
    }

    function setTimelock(address new_timelock) external onlyByOwnerGovernanceOrController {
        require(new_timelock != address(0), "Zero address detected");

        timelock_address = new_timelock;

        emit TimelockSet(new_timelock);
    }

    function setController(address _controller_address) external onlyByOwnerGovernanceOrController {
        require(_controller_address != address(0), "Zero address detected");

        controller_address = _controller_address;

        emit ControllerSet(_controller_address);
    }

    function setPriceBand(uint256 _price_band) external onlyByOwnerGovernanceOrController {
        price_band = _price_band;

        emit PriceBandSet(_price_band);
    }

    function setMinCollateralRatio(uint256 _min_collateral_ratio) external onlyByOwnerGovernanceOrController {
        min_collateral_ratio = _min_collateral_ratio;

        emit MinCollateralRatioSet(_min_collateral_ratio);
    }

    // Sets the Gu_BNB Uniswap oracle address
    function setSynthBnbOracle(address gu_oracle_addr, address _wbnb_address) public onlyByOwnerGovernanceOrController {
        require((gu_oracle_addr != address(0)) && (_wbnb_address != address(0)), "Zero address detected");
        gu_bnb_oracle_address = gu_oracle_addr;
        guBnbOracle = IUniswapPairOracle(gu_oracle_addr);
        wbnb_address = _wbnb_address;

        emit GuBNBOracleSet(gu_oracle_addr, _wbnb_address);
    }

    // Sets the Gr_BNB Uniswap oracle address
    function setGrBnbOracle(address _gr_oracle_addr, address _wbnb_address) public onlyByOwnerGovernanceOrController {
        require((_gr_oracle_addr != address(0)) && (_wbnb_address != address(0)), "Zero address detected");

        gr_bnb_oracle_address = _gr_oracle_addr;
        grBnbOracle = IUniswapPairOracle(_gr_oracle_addr);
        wbnb_address = _wbnb_address;

        emit GrBnbOracleSet(_gr_oracle_addr, _wbnb_address);
    }

    function toggleCollateralRatio() public onlyCollateralRatioPauser {
        collateral_ratio_paused = !collateral_ratio_paused;

        emit CollateralRatioToggled(collateral_ratio_paused);
    }

    /* ========== EVENTS ========== */

    // Track Gu burned
    event GuBurned(address indexed from, address indexed to, uint256 amount);

    // Track Gu minted
    event GuMinted(address indexed from, address indexed to, uint256 amount);

    event CollateralRatioRefreshed(uint256 global_collateral_ratio);
    event PoolAdded(address pool_address);
    event PoolRemoved(address pool_address);
    event RedemptionFeeSet(uint256 red_fee);
    event MintingFeeSet(uint256 min_fee);
    event SynthStepSet(uint256 new_step);
    event PriceTargetSet(uint256 new_price_target);
    event RefreshCooldownSet(uint256 new_cooldown);
    event GrAddressSet(address _gr_address);
    event BNBAnchorOracleSet(address bnb_anchor_consumer_address);
    event TimelockSet(address new_timelock);
    event ControllerSet(address controller_address);
    event PriceBandSet(uint256 price_band);
    event MinCollateralRatioSet(uint256 min_collateral_ratio);
    event GuBNBOracleSet(address gu_oracle_addr, address wbnb_address);
    event GrBnbOracleSet(address gr_oracle_addr, address wbnb_address);
    event CollateralRatioToggled(bool collateral_ratio_paused);
}
